import FetchCore
import FetchKit
import Foundation

@main
struct SwiftlyFetchCorpusAudit {
    static func main() async {
        do {
            let configuration = AuditConfiguration(environment: ProcessInfo.processInfo.environment)
            let auditor = CorpusAuditor(configuration: configuration)
            try await auditor.run()
        } catch {
            fputs("ERROR: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

private struct AuditConfiguration {
    var tinyStoriesLength: Int
    var simpleWikipediaLength: Int
    var gutenbergPoetryLength: Int
    var requestTimeout: TimeInterval
    var token: String?

    init(environment: [String: String]) {
        tinyStoriesLength = Self.boundedLength(
            environment["HF_CORPUS_AUDIT_TINYSTORIES_LENGTH"],
            defaultValue: 60
        )
        simpleWikipediaLength = Self.boundedLength(
            environment["HF_CORPUS_AUDIT_SIMPLEWIKI_LENGTH"],
            defaultValue: 30
        )
        gutenbergPoetryLength = Self.boundedLength(
            environment["HF_CORPUS_AUDIT_POETRY_LENGTH"],
            defaultValue: 80
        )
        requestTimeout = TimeInterval(
            Self.positiveInteger(environment["HF_CORPUS_AUDIT_TIMEOUT_SECONDS"], defaultValue: 30)
        )
        token = environment["HF_TOKEN"].flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func boundedLength(_ value: String?, defaultValue: Int) -> Int {
        min(100, positiveInteger(value, defaultValue: defaultValue))
    }

    private static func positiveInteger(_ value: String?, defaultValue: Int) -> Int {
        guard let value, let intValue = Int(value), intValue > 0 else {
            return defaultValue
        }

        return intValue
    }
}

private struct CorpusAuditor {
    var configuration: AuditConfiguration

    func run() async throws {
        print("Running Hugging Face corpus audit with bounded Dataset Viewer slices.")
        let client = DatasetViewerClient(
            token: configuration.token,
            requestTimeout: configuration.requestTimeout
        )

        async let tinyStoriesRows = client.rows(
            dataset: "roneneldan/TinyStories",
            config: "default",
            split: "train",
            offset: 0,
            length: configuration.tinyStoriesLength
        )
        async let simpleWikipediaRows = client.rows(
            dataset: "juno-labs/simple_wikipedia",
            config: "default",
            split: "train",
            offset: 0,
            length: configuration.simpleWikipediaLength
        )
        async let poetryRows = client.rows(
            dataset: "biglam/gutenberg-poetry-corpus",
            config: "default",
            split: "train",
            offset: 0,
            length: configuration.gutenbergPoetryLength
        )

        let records = try await CorpusMapper.records(
            tinyStoriesRows: tinyStoriesRows,
            simpleWikipediaRows: simpleWikipediaRows,
            poetryRows: poetryRows
        )

        guard !records.isEmpty else {
            throw AuditError.noRecords
        }

        let library = FetchKitLibrary()
        try await library.addDocuments(records)

        let checks = AuditCheck.defaults
        var failures: [String] = []

        print("Indexed \(records.count) documents from \(uniqueDatasetCount(in: records)) datasets.")

        for check in checks {
            do {
                try await run(check, library: library)
            } catch {
                failures.append(error.localizedDescription)
            }
        }

        if !failures.isEmpty {
            throw AuditError.failedChecks(failures)
        }

        print("Hugging Face corpus audit passed \(checks.count) checks.")
    }

    private func run(_ check: AuditCheck, library: FetchKitLibrary) async throws {
        let results = try await library.search(check.query)

        guard let firstResult = results.first else {
            throw AuditError.checkFailed(
                "\(check.name) returned no results for query '\(check.query.text)'."
            )
        }

        let dataset = firstResult.document.id.rawValue.components(separatedBy: "-").prefix(2).joined(separator: "-")
        guard firstResult.document.id.rawValue.hasPrefix(check.expectedIDPrefix) else {
            throw AuditError.checkFailed(
                "\(check.name) expected top document prefix '\(check.expectedIDPrefix)' but got '\(firstResult.document.id.rawValue)'."
            )
        }

        guard let snippet = firstResult.snippet, !snippet.text.isEmpty else {
            throw AuditError.checkFailed(
                "\(check.name) top result '\(firstResult.document.id.rawValue)' did not include a snippet."
            )
        }

        for expectedText in check.expectedSnippetTerms {
            guard snippet.text.localizedCaseInsensitiveContains(expectedText) else {
                throw AuditError.checkFailed(
                    "\(check.name) top result '\(firstResult.document.id.rawValue)' snippet did not include '\(expectedText)'."
                )
            }
        }

        let snippetPreview = snippet.text.replacingOccurrences(of: "\n", with: " ")
        print(
            "[pass] \(check.name): \(dataset) \(firstResult.document.id.rawValue) score=\(String(format: "%.3f", firstResult.score)) field=\(firstResult.snippetField?.rawValue ?? "none") snippet=\"\(snippetPreview.prefix(120))\""
        )
    }

    private func uniqueDatasetCount(in records: [FetchDocumentRecord]) -> Int {
        Set(records.compactMap { $0.metadata["hf.dataset"] }).count
    }
}

private struct AuditCheck {
    var name: String
    var query: FetchSearchQuery
    var expectedIDPrefix: String
    var expectedSnippetTerms: [String]

    static let defaults: [AuditCheck] = [
        AuditCheck(
            name: "TinyStories sewing retrieval",
            query: FetchSearchQuery("needle sew shirt", kind: .allTerms, fields: [.title, .body], limit: 5),
            expectedIDPrefix: "hf-tinystories-0",
            expectedSnippetTerms: ["needle"]
        ),
        AuditCheck(
            name: "TinyStories toy retrieval",
            query: FetchSearchQuery("triangle puddle toy", kind: .allTerms, fields: [.title, .body], limit: 5),
            expectedIDPrefix: "hf-tinystories-6",
            expectedSnippetTerms: ["triangle"]
        ),
        AuditCheck(
            name: "Simple Wikipedia calendar retrieval",
            query: FetchSearchQuery("april leap year flowers", kind: .allTerms, fields: [.title, .body], limit: 5),
            expectedIDPrefix: "hf-simplewiki-0",
            expectedSnippetTerms: ["April"]
        ),
        AuditCheck(
            name: "Simple Wikipedia rhetoric retrieval",
            query: FetchSearchQuery("against person weak argument", kind: .allTerms, fields: [.title, .body], limit: 5),
            expectedIDPrefix: "hf-simplewiki-18",
            expectedSnippetTerms: []
        ),
        AuditCheck(
            name: "Gutenberg poetry northland retrieval",
            query: FetchSearchQuery("great lakes northland ojibways", kind: .allTerms, fields: [.title, .body], limit: 5),
            expectedIDPrefix: "hf-poetry-19-lines",
            expectedSnippetTerms: ["Northland"]
        ),
    ]
}

private struct DatasetViewerClient {
    var token: String?
    var requestTimeout: TimeInterval

    func rows(
        dataset: String,
        config: String,
        split: String,
        offset: Int,
        length: Int
    ) async throws -> [DatasetRow] {
        var components = URLComponents(string: "https://datasets-server.huggingface.co/rows")
        components?.queryItems = [
            URLQueryItem(name: "dataset", value: dataset),
            URLQueryItem(name: "config", value: config),
            URLQueryItem(name: "split", value: split),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "length", value: String(length)),
        ]

        guard let url = components?.url else {
            throw AuditError.invalidURL("Could not build a Dataset Viewer URL for \(dataset).")
        }

        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "GET"

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuditError.network("Dataset Viewer did not return an HTTP response for \(dataset).")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AuditError.network(
                "Dataset Viewer returned HTTP \(httpResponse.statusCode) for \(dataset). \(body.prefix(240))"
            )
        }

        return try JSONDecoder().decode(DatasetRowsResponse.self, from: data).rows
    }
}

private struct DatasetRowsResponse: Decodable {
    var rows: [DatasetRow]
}

private struct DatasetRow: Decodable {
    var rowIdx: Int
    var row: [String: JSONValue]

    enum CodingKeys: String, CodingKey {
        case rowIdx = "row_idx"
        case row
    }
}

private enum JSONValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        switch self {
            case let .string(value):
                value
            case let .int(value):
                String(value)
            case let .double(value):
                String(value)
            case let .bool(value):
                String(value)
            case .null:
                nil
        }
    }
}

private enum CorpusMapper {
    static func records(
        tinyStoriesRows: [DatasetRow],
        simpleWikipediaRows: [DatasetRow],
        poetryRows: [DatasetRow]
    ) -> [FetchDocumentRecord] {
        tinyStoriesRecords(from: tinyStoriesRows)
            + simpleWikipediaRecords(from: simpleWikipediaRows)
            + poetryRecords(from: poetryRows)
    }

    private static func tinyStoriesRecords(from rows: [DatasetRow]) -> [FetchDocumentRecord] {
        rows.compactMap { row in
            guard let text = row.row["text"]?.stringValue, !text.isEmpty else {
                return nil
            }

            return FetchDocumentRecord(
                id: FetchDocumentID("hf-tinystories-\(row.rowIdx)"),
                title: title(from: text, fallback: "TinyStories row \(row.rowIdx)"),
                body: text,
                kind: .article,
                language: "en",
                sourceURI: "https://huggingface.co/datasets/roneneldan/TinyStories",
                metadata: metadata(dataset: "roneneldan/TinyStories", row: row.rowIdx)
            )
        }
    }

    private static func simpleWikipediaRecords(from rows: [DatasetRow]) -> [FetchDocumentRecord] {
        rows.compactMap { row in
            guard
                let title = row.row["title"]?.stringValue,
                let content = row.row["content"]?.stringValue,
                !content.isEmpty
            else {
                return nil
            }

            return FetchDocumentRecord(
                id: FetchDocumentID("hf-simplewiki-\(row.rowIdx)"),
                title: title,
                body: limited(content, maxCharacters: 12_000),
                contentType: .markdown,
                kind: .reference,
                language: "en",
                sourceURI: "https://huggingface.co/datasets/juno-labs/simple_wikipedia",
                metadata: metadata(dataset: "juno-labs/simple_wikipedia", row: row.rowIdx)
            )
        }
    }

    private static func poetryRecords(from rows: [DatasetRow]) -> [FetchDocumentRecord] {
        let groupedRows = Dictionary(grouping: rows) { row in
            row.row["gutenberg_id"]?.stringValue ?? "unknown"
        }

        return groupedRows.keys.sorted().flatMap { gutenbergID in
            let rows = (groupedRows[gutenbergID] ?? []).sorted { $0.rowIdx < $1.rowIdx }
            return rows.chunked(into: 12).compactMap { chunk -> FetchDocumentRecord? in
                let lines = chunk.compactMap { $0.row["line"]?.stringValue }.filter { !$0.isEmpty }
                guard !lines.isEmpty, let firstRow = chunk.first?.rowIdx, let lastRow = chunk.last?.rowIdx else {
                    return nil
                }

                return FetchDocumentRecord(
                    id: FetchDocumentID("hf-poetry-\(gutenbergID)-lines-\(firstRow)-\(lastRow)"),
                    title: "Gutenberg Poetry \(gutenbergID): lines \(firstRow)-\(lastRow)",
                    body: lines.joined(separator: "\n"),
                    kind: .article,
                    language: "en",
                    sourceURI: "https://huggingface.co/datasets/biglam/gutenberg-poetry-corpus",
                    metadata: metadata(dataset: "biglam/gutenberg-poetry-corpus", row: "\(firstRow)-\(lastRow)")
                )
            }
        }
    }

    private static func title(from text: String, fallback: String) -> String {
        let firstLine = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? fallback
        return String(firstLine.prefix(72))
    }

    private static func limited(_ text: String, maxCharacters: Int) -> String {
        guard text.count > maxCharacters else {
            return text
        }

        return String(text.prefix(maxCharacters))
    }

    private static func metadata(dataset: String, row: some CustomStringConvertible) -> [String: String] {
        [
            "hf.dataset": dataset,
            "hf.row": row.description,
        ]
    }
}

private enum AuditError: LocalizedError {
    case invalidURL(String)
    case network(String)
    case noRecords
    case checkFailed(String)
    case failedChecks([String])

    var errorDescription: String? {
        switch self {
            case let .invalidURL(message), let .network(message), let .checkFailed(message):
                message
            case .noRecords:
                "The Hugging Face corpus audit could not build any FetchKit records from the downloaded dataset slices."
            case let .failedChecks(messages):
                "The Hugging Face corpus audit failed \(messages.count) check(s):\n- \(messages.joined(separator: "\n- "))"
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { start in
            Array(self[start ..< Swift.min(start + size, count)])
        }
    }
}
