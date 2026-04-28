#if os(macOS)
@preconcurrency import CoreServices
import FetchCore
import Foundation

public actor SearchKitFetchIndex: FetchIndex {
    public struct Configuration: Hashable, Sendable {
        public enum Storage: Hashable, Sendable {
            case inMemory
            case file(URL)
        }

        public var storage: Storage
        public var indexNamePrefix: String

        public init(
            storage: Storage,
            indexNamePrefix: String = "SwiftlyFetch"
        ) {
            self.storage = storage
            self.indexNamePrefix = indexNamePrefix
        }

        public static let inMemory = Configuration(storage: .inMemory)
    }

    public enum IndexError: Error, LocalizedError {
        case createFailed(String)
        case flushFailed(String)
        case metadataStoreFailed(String)

        public var errorDescription: String? {
            switch self {
            case let .createFailed(message):
                "FetchKit could not create or open the Search Kit index. \(message)"
            case let .flushFailed(message):
                "FetchKit could not flush pending Search Kit index updates. \(message)"
            case let .metadataStoreFailed(message):
                "FetchKit could not load or persist the Search Kit sidecar metadata store. \(message)"
            }
        }
    }

    private let titleIndex: ManagedIndex
    private let bodyIndex: ManagedIndex
    private let metadataFileURL: URL?
    private var documentsByID: [FetchDocumentID: FetchDocument]

    public init(configuration: Configuration = .inMemory) throws {
        self.titleIndex = try ManagedIndex(
            configuration: configuration,
            field: .title
        )
        self.bodyIndex = try ManagedIndex(
            configuration: configuration,
            field: .body
        )

        switch configuration.storage {
        case .inMemory:
            self.metadataFileURL = nil
            self.documentsByID = [:]
        case let .file(url):
            self.metadataFileURL = Self.metadataFileURL(for: url)
            self.documentsByID = try Self.loadMetadataStore(from: self.metadataFileURL)
        }
    }

    public func apply(_ changeset: FetchIndexingChangeset) async throws {
        guard !changeset.isEmpty else {
            return
        }

        var updatedDocuments = documentsByID

        for change in changeset.changes {
            switch change {
            case let .upsert(document):
                try upsert(document, into: titleIndex, field: .title)
                try upsert(document, into: bodyIndex, field: .body)
                updatedDocuments[document.id] = document.searchDocument
            case let .remove(id):
                remove(id, from: titleIndex)
                remove(id, from: bodyIndex)
                updatedDocuments[id] = nil
            }
        }

        guard SKIndexFlush(titleIndex.index), SKIndexFlush(bodyIndex.index) else {
            throw IndexError.flushFailed("Search Kit reported that one or more field indexes could not be flushed after applying changes.")
        }

        documentsByID = updatedDocuments
        try persistMetadataStore()
    }

    public func removeAllDocuments() async throws {
        let documentIDs = Set(documentsByID.keys)

        for documentID in documentIDs {
            remove(documentID, from: titleIndex)
            remove(documentID, from: bodyIndex)
        }

        guard SKIndexFlush(titleIndex.index), SKIndexFlush(bodyIndex.index) else {
            throw IndexError.flushFailed("Search Kit reported that one or more field indexes could not be flushed after removing all documents.")
        }

        documentsByID.removeAll()
        try persistMetadataStore()
    }

    public func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult] {
        let normalizedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty, query.limit > 0 else {
            return []
        }

        let indexes = indexes(for: query.fields)
        let searchString = searchString(for: normalizedQuery, kind: query.kind)
        var resultsByID: [FetchDocumentID: FetchSearchResult] = [:]

        for (field, managedIndex) in indexes {
            for match in try search(
                searchString,
                in: managedIndex,
                field: field,
                limit: query.limit
            ) {
                let existing = resultsByID[match.document.id]
                resultsByID[match.document.id] = merged(existing: existing, new: match)
            }
        }

        return Array(resultsByID.values)
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.document.id.rawValue < rhs.document.id.rawValue
                }

                return lhs.score > rhs.score
            }
            .prefix(query.limit)
            .map { $0 }
    }

    private func indexes(for fields: Set<FetchSearchField>) -> [(FetchSearchField, ManagedIndex)] {
        var selected: [(FetchSearchField, ManagedIndex)] = []

        if fields.contains(.title) {
            selected.append((.title, titleIndex))
        }

        if fields.contains(.body) {
            selected.append((.body, bodyIndex))
        }

        return selected
    }

    private func searchString(for text: String, kind: FetchSearchKind) -> String {
        switch kind {
        case .naturalLanguage:
            text
        case .allTerms:
            text
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .joined(separator: " & ")
        case .exactPhrase:
            "\"\(text.replacingOccurrences(of: "\"", with: "\\\""))\""
        case .prefix:
            text
                .split(whereSeparator: \.isWhitespace)
                .map { "\($0)*" }
                .joined(separator: " & ")
        }
    }

    private func upsert(
        _ document: FetchIndexDocument,
        into managedIndex: ManagedIndex,
        field: FetchSearchField
    ) throws {
        let skDocument = makeSearchKitDocument(id: document.id)
        let text = indexedText(for: document, field: field)

        if text.isEmpty {
            _ = SKIndexRemoveDocument(managedIndex.index, skDocument)
            return
        }

        _ = SKIndexAddDocumentWithText(
            managedIndex.index,
            skDocument,
            text as CFString,
            true
        )
    }

    private func remove(
        _ documentID: FetchDocumentID,
        from managedIndex: ManagedIndex
    ) {
        let skDocument = makeSearchKitDocument(id: documentID)
        _ = SKIndexRemoveDocument(managedIndex.index, skDocument)
    }

    private func indexedText(
        for document: FetchIndexDocument,
        field: FetchSearchField
    ) -> String {
        switch field {
        case .title:
            document.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case .body:
            document.body.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func search(
        _ searchString: String,
        in managedIndex: ManagedIndex,
        field: FetchSearchField,
        limit: Int
    ) throws -> [FetchSearchResult] {
        guard let search = SKSearchCreate(
            managedIndex.index,
            searchString as CFString,
            SKSearchOptions(kSKSearchOptionDefault)
        )?.takeRetainedValue() else {
            return []
        }

        var results: [FetchSearchResult] = []
        let fetchCount = max(limit, 16)

        while results.count < limit {
            var documentIDs = Array<SKDocumentID>(repeating: 0, count: fetchCount)
            var scores = Array<Float>(repeating: 0, count: fetchCount)
            var foundCount: CFIndex = 0

            let hasMore = SKSearchFindMatches(
                search,
                fetchCount,
                &documentIDs,
                &scores,
                0.05,
                &foundCount
            )

            guard foundCount > 0 else {
                break
            }

            for offset in 0..<foundCount {
                guard let result = try makeSearchResult(
                    from: managedIndex,
                    documentID: documentIDs[offset],
                    score: Double(scores[offset]),
                    field: field,
                    query: searchString
                ) else {
                    continue
                }

                results.append(result)
                if results.count == limit {
                    break
                }
            }

            if !hasMore {
                break
            }
        }

        return results
    }

    private func makeSearchResult(
        from managedIndex: ManagedIndex,
        documentID: SKDocumentID,
        score: Double,
        field: FetchSearchField,
        query: String
    ) throws -> FetchSearchResult? {
        guard let document = SKIndexCopyDocumentForDocumentID(
            managedIndex.index,
            documentID
        )?.takeRetainedValue() else {
            return nil
        }

        guard
            let rawName = SKDocumentGetName(document)?.takeUnretainedValue() as String?,
            let fetchDocument = documentsByID[FetchDocumentID(rawName)]
        else {
            return nil
        }

        let snippetSource = field == .title ? (fetchDocument.title ?? fetchDocument.body) : fetchDocument.body
        return FetchSearchResult(
            document: fetchDocument,
            score: score,
            snippet: makeSnippet(from: snippetSource, query: query)
        )
    }

    private func makeSnippet(from text: String, query: String) -> FetchSnippet? {
        let terms = query
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "&", with: " ")
            .replacingOccurrences(of: "*", with: "")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        guard let term = terms.first else {
            return nil
        }

        let lowercaseText = text.lowercased()
        guard let range = lowercaseText.range(of: term.lowercased()) else {
            return FetchSnippet(text: String(text.prefix(80)))
        }

        let lowerBound = lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)
        let upperBound = lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound)
        let snippetRange = snippetBounds(for: text, lowerBound: lowerBound, upperBound: upperBound)
        let snippetText = String(text[snippetRange])
        let highlightLowerBound = text.distance(
            from: snippetRange.lowerBound,
            to: text.index(text.startIndex, offsetBy: lowerBound)
        )
        let highlightUpperBound = text.distance(
            from: snippetRange.lowerBound,
            to: text.index(text.startIndex, offsetBy: upperBound)
        )

        return FetchSnippet(
            text: snippetText,
            matchRanges: [
                FetchMatchRange(
                    lowerBound: highlightLowerBound,
                    upperBound: highlightUpperBound
                ),
            ]
        )
    }

    private func snippetBounds(
        for text: String,
        lowerBound: Int,
        upperBound: Int
    ) -> Range<String.Index> {
        let start = text.index(text.startIndex, offsetBy: max(0, lowerBound - 24))
        let end = text.index(text.startIndex, offsetBy: min(text.count, upperBound + 24))
        return start..<end
    }

    private func merged(
        existing: FetchSearchResult?,
        new: FetchSearchResult
    ) -> FetchSearchResult {
        guard let existing else {
            return new
        }

        let score = max(existing.score, new.score)
        let snippet = existing.snippet ?? new.snippet
        return FetchSearchResult(
            document: existing.document,
            score: score,
            snippet: snippet
        )
    }

    private func makeSearchKitDocument(id: FetchDocumentID) -> SKDocument {
        SKDocumentCreate(
            "swiftlyfetch" as CFString,
            nil,
            id.rawValue as CFString
        ).takeRetainedValue()
    }

    private func persistMetadataStore() throws {
        guard let metadataFileURL else {
            return
        }

        do {
            let data = try JSONEncoder().encode(documentsByID)
            try FileManager.default.createDirectory(
                at: metadataFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: metadataFileURL, options: .atomic)
        } catch {
            throw IndexError.metadataStoreFailed(error.localizedDescription)
        }
    }

    private static func metadataFileURL(for indexFileURL: URL) -> URL {
        indexFileURL.deletingPathExtension()
            .appendingPathExtension("metadata.json")
    }

    private static func loadMetadataStore(from fileURL: URL?) throws -> [FetchDocumentID: FetchDocument] {
        guard
            let fileURL,
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([FetchDocumentID: FetchDocument].self, from: data)
        } catch {
            throw IndexError.metadataStoreFailed(error.localizedDescription)
        }
    }
}

private final class ManagedIndex {
    let index: SKIndex
    private let mutableData: CFMutableData?

    init(
        configuration: SearchKitFetchIndex.Configuration,
        field: FetchSearchField
    ) throws {
        let indexName = "\(configuration.indexNamePrefix)-\(field.rawValue)" as CFString

        switch configuration.storage {
        case .inMemory:
            let data = CFDataCreateMutable(nil, 0)
            guard
                let data,
                // Search Kit owns the index lifetime behind SKIndexClose(_:) on teardown.
                // Taking an extra retained value here causes the xctest path to crash in deinit.
                let index = SKIndexCreateWithMutableData(
                    data,
                    indexName,
                    kSKIndexInverted,
                    nil
                )?.takeUnretainedValue()
            else {
                throw SearchKitFetchIndex.IndexError.createFailed("Search Kit could not create the in-memory \(field.rawValue) index.")
            }

            self.mutableData = data
            self.index = index
        case let .file(url):
            let cfURL = url as CFURL
            if let opened = SKIndexOpenWithURL(cfURL, indexName, true)?.takeUnretainedValue() {
                self.mutableData = nil
                self.index = opened
            } else if let created = SKIndexCreateWithURL(
                cfURL,
                indexName,
                kSKIndexInverted,
                nil
            )?.takeUnretainedValue() {
                self.mutableData = nil
                self.index = created
            } else {
                throw SearchKitFetchIndex.IndexError.createFailed("Search Kit could not open or create the persistent \(field.rawValue) index at \(url.path).")
            }
        }
    }

    deinit {
        SKIndexClose(index)
        _ = mutableData
    }
}
#endif
