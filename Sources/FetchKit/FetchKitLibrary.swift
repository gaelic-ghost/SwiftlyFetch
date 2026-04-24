import FetchCore

public actor FetchKitLibrary {
    public struct Configuration: Hashable, Sendable {
        public enum Backend: String, Hashable, Codable, Sendable {
            case inMemory
        }

        public var backend: Backend

        public init(backend: Backend = .inMemory) {
            self.backend = backend
        }

        public static let `default` = Configuration()
    }

    public struct BatchResult: Hashable, Sendable {
        public let documentIDs: [FetchDocumentID]

        public init(documentIDs: [FetchDocumentID]) {
            self.documentIDs = documentIDs
        }

        public var count: Int {
            documentIDs.count
        }
    }

    private let documentStore: any FetchDocumentStore
    private let index: any FetchIndex

    public init(configuration: Configuration = .default) {
        switch configuration.backend {
        case .inMemory:
            self.documentStore = InMemoryFetchDocumentStore()
            self.index = InMemoryFetchIndex()
        }
    }

    public init(
        documentStore: any FetchDocumentStore,
        index: any FetchIndex
    ) {
        self.documentStore = documentStore
        self.index = index
    }

    public static func `default`() -> FetchKitLibrary {
        FetchKitLibrary()
    }

    @discardableResult
    public func addDocument(_ record: FetchDocumentRecord) async throws -> BatchResult {
        try await addDocuments([record])
    }

    @discardableResult
    public func addDocuments(_ records: [FetchDocumentRecord]) async throws -> BatchResult {
        try await upsertDocuments(records)
    }

    @discardableResult
    public func updateDocument(_ record: FetchDocumentRecord) async throws -> BatchResult {
        try await updateDocuments([record])
    }

    @discardableResult
    public func updateDocuments(_ records: [FetchDocumentRecord]) async throws -> BatchResult {
        try await upsertDocuments(records)
    }

    public func document(withID id: FetchDocumentID) async throws -> FetchDocumentRecord? {
        try await documentStore.document(id: id)
    }

    @discardableResult
    public func removeDocument(withID id: FetchDocumentID) async throws -> BatchResult {
        try await removeDocuments([id])
    }

    @discardableResult
    public func removeDocuments(_ ids: [FetchDocumentID]) async throws -> BatchResult {
        guard !ids.isEmpty else {
            return BatchResult(documentIDs: [])
        }

        try await documentStore.removeDocuments(withIDs: ids)
        try await index.apply(
            FetchIndexingChangeset(
                ids.map { .remove($0) }
            )
        )
        return BatchResult(documentIDs: ids)
    }

    public func removeAllDocuments() async throws {
        try await documentStore.removeAllDocuments()
        try await index.removeAllDocuments()
    }

    public func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult] {
        try await index.search(query)
    }

    public func search(
        _ text: String,
        kind: FetchSearchKind = .naturalLanguage,
        fields: Set<FetchSearchField> = Set(FetchSearchField.allCases),
        limit: Int = 10
    ) async throws -> [FetchSearchResult] {
        try await search(
            FetchSearchQuery(
                text,
                kind: kind,
                fields: fields,
                limit: limit
            )
        )
    }

    private func upsertDocuments(_ records: [FetchDocumentRecord]) async throws -> BatchResult {
        guard !records.isEmpty else {
            return BatchResult(documentIDs: [])
        }

        try await documentStore.upsert(records)
        try await index.apply(
            FetchIndexingChangeset(
                records.map { .upsert($0.indexDocument) }
            )
        )
        return BatchResult(documentIDs: records.map(\.id))
    }
}
