public protocol FetchDocumentStore: Sendable {
    func upsert(_ records: [FetchDocumentRecord]) async throws -> FetchStoreMutationResult
    func document(id: FetchDocumentID) async throws -> FetchDocumentRecord?
    func removeDocuments(withIDs ids: [FetchDocumentID]) async throws -> FetchStoreMutationResult
    func removeAllDocuments() async throws -> FetchStoreMutationResult
}

public protocol FetchIndex: Sendable {
    func apply(_ changeset: FetchIndexingChangeset) async throws
    func removeAllDocuments() async throws
    func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult]
}
