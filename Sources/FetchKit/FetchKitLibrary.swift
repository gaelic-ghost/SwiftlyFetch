import FetchCore

public actor FetchKitLibrary {
    public struct IndexSyncError: Error, Sendable {
        public let pendingIndexSync: FetchPendingIndexSync
        public let underlyingErrorDescription: String

        public init(pendingIndexSync: FetchPendingIndexSync, underlyingError: Error) {
            self.pendingIndexSync = pendingIndexSync
            self.underlyingErrorDescription = String(describing: underlyingError)
        }
    }

    public struct IndexSyncRetryResult: Hashable, Sendable {
        public let completedSyncIDs: [FetchPendingIndexSyncID]
        public let affectedDocumentIDs: [FetchDocumentID]

        public init(
            completedSyncIDs: [FetchPendingIndexSyncID],
            affectedDocumentIDs: [FetchDocumentID]
        ) {
            self.completedSyncIDs = completedSyncIDs
            self.affectedDocumentIDs = affectedDocumentIDs
        }

        public var count: Int {
            completedSyncIDs.count
        }
    }

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

        let mutation = try await documentStore.removeDocuments(withIDs: ids)
        try await applyIndexingChanges(for: mutation)
        return BatchResult(documentIDs: mutation.affectedDocumentIDs)
    }

    public func removeAllDocuments() async throws {
        let mutation = try await documentStore.removeAllDocuments()
        try await applyIndexingChanges(for: mutation)
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

    public func pendingIndexSyncs() async throws -> [FetchPendingIndexSync] {
        try await documentStore.pendingIndexSyncs()
    }

    @discardableResult
    public func retryPendingIndexSyncs(limit: Int? = nil) async throws -> IndexSyncRetryResult {
        let pendingSyncs = try await documentStore.pendingIndexSyncs()
        let slice = limit.map { Array(pendingSyncs.prefix(max(0, $0))) } ?? pendingSyncs

        var completedSyncIDs: [FetchPendingIndexSyncID] = []
        var affectedDocumentIDs: [FetchDocumentID] = []

        for pendingSync in slice {
            do {
                try await index.apply(pendingSync.changeset)
                try await documentStore.removePendingIndexSyncs(withIDs: [pendingSync.id])
                completedSyncIDs.append(pendingSync.id)
                affectedDocumentIDs.append(contentsOf: pendingSync.affectedDocumentIDs)
            } catch {
                throw IndexSyncError(
                    pendingIndexSync: pendingSync,
                    underlyingError: error
                )
            }
        }

        var seen = Set<FetchDocumentID>()
        let uniqueAffectedDocumentIDs = affectedDocumentIDs.filter { seen.insert($0).inserted }

        return IndexSyncRetryResult(
            completedSyncIDs: completedSyncIDs,
            affectedDocumentIDs: uniqueAffectedDocumentIDs
        )
    }

    private func upsertDocuments(_ records: [FetchDocumentRecord]) async throws -> BatchResult {
        guard !records.isEmpty else {
            return BatchResult(documentIDs: [])
        }

        let mutation = try await documentStore.upsert(records)
        try await applyIndexingChanges(for: mutation)
        return BatchResult(documentIDs: mutation.affectedDocumentIDs)
    }

    private func applyIndexingChanges(for mutation: FetchStoreMutationResult) async throws {
        guard let pendingIndexSync = mutation.pendingIndexSync else {
            return
        }

        do {
            try await index.apply(pendingIndexSync.changeset)
            try await documentStore.removePendingIndexSyncs(withIDs: [pendingIndexSync.id])
        } catch {
            throw IndexSyncError(
                pendingIndexSync: pendingIndexSync,
                underlyingError: error
            )
        }
    }
}
