import FetchCore
import FetchKit
import Foundation
import RAGCore
import RAGKit

public actor SwiftlyFetchLibrary {
    private let fetchLibrary: FetchKitLibrary
    private let knowledgeBase: KnowledgeBase
    private let retryStore: any SwiftlyFetchSemanticRetryStore
    private let documentMapper: SwiftlyFetchDocumentMapper

    public init(
        fetchLibrary: FetchKitLibrary,
        knowledgeBase: KnowledgeBase,
        retryStore: any SwiftlyFetchSemanticRetryStore,
        documentMapper: SwiftlyFetchDocumentMapper = SwiftlyFetchDocumentMapper()
    ) {
        self.fetchLibrary = fetchLibrary
        self.knowledgeBase = knowledgeBase
        self.retryStore = retryStore
        self.documentMapper = documentMapper
    }

    public static func `default`() async throws -> SwiftlyFetchLibrary {
        try await SwiftlyFetchLibrary(
            fetchLibrary: .default(),
            knowledgeBase: .hashingDefault(),
            retryStore: InMemorySwiftlyFetchSemanticRetryStore()
        )
    }

    @discardableResult
    public func addDocument(_ record: FetchDocumentRecord) async throws -> SwiftlyFetchMutationResult {
        let conventionalResult = try await fetchLibrary.addDocument(record)
        return try await indexSemantics(
            record,
            conventionalResult: conventionalResult
        )
    }

    @discardableResult
    public func updateDocument(_ record: FetchDocumentRecord) async throws -> SwiftlyFetchMutationResult {
        let conventionalResult = try await fetchLibrary.updateDocument(record)
        return try await indexSemantics(
            record,
            conventionalResult: conventionalResult
        )
    }

    @discardableResult
    public func removeDocument(withID id: FetchDocumentID) async throws -> SwiftlyFetchMutationResult {
        let conventionalResult = try await fetchLibrary.removeDocument(withID: id)
        let semanticDocumentID = documentMapper.documentID(for: id)

        do {
            try await knowledgeBase.removeDocument(semanticDocumentID)
            try await retryStore.removeRetries(for: [id])

            return try SwiftlyFetchMutationResult(
                documentIDs: conventionalResult.documentIDs,
                conventional: .succeeded,
                semantic: .succeeded(state: await semanticIndexState(for: id))
            )
        } catch {
            let retry = SwiftlyFetchSemanticRetry(
                documentID: id,
                operation: .removeDocument,
                reason: "SwiftlyFetch removed the corpus record, but semantic chunk cleanup failed.",
                lastFailure: String(describing: error)
            )
            try await retryStore.upsert(retry)

            return try SwiftlyFetchMutationResult(
                documentIDs: conventionalResult.documentIDs,
                conventional: .succeeded,
                semantic: SwiftlyFetchSemanticMutationStage(
                    status: .queuedRetry,
                    state: await semanticIndexState(for: id),
                    retry: retry,
                    failureDescription: retry.lastFailure
                )
            )
        }
    }

    public func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult] {
        try await fetchLibrary.search(query)
    }

    public func retrieve(_ query: SearchQuery) async throws -> [SearchResult] {
        try await knowledgeBase.search(query)
    }

    public func searchAndRetrieve(
        _ query: SwiftlyFetchSearchAndRetrieveQuery
    ) async throws -> SwiftlyFetchSearchAndRetrieveResult {
        let conventionalResults = try await search(query.conventional)
        let semanticResults = try await retrieve(query.semantic)

        return SwiftlyFetchSearchAndRetrieveResult(
            conventional: conventionalResults,
            semantic: semanticResults
        )
    }

    public func searchAndRetrieve(
        conventional conventionalQuery: FetchSearchQuery,
        semantic semanticQuery: SearchQuery
    ) async throws -> SwiftlyFetchSearchAndRetrieveResult {
        try await searchAndRetrieve(
            SwiftlyFetchSearchAndRetrieveQuery(
                conventional: conventionalQuery,
                semantic: semanticQuery
            )
        )
    }

    @discardableResult
    public func retrySemanticIndexing(limit: Int? = nil) async throws -> SwiftlyFetchSemanticRetryResult {
        let retries = try await retryStore.pendingRetries(limit: limit)
        var completedDocumentIDs: [FetchDocumentID] = []
        var removedMissingDocumentIDs: [FetchDocumentID] = []
        var failedRetries: [SwiftlyFetchSemanticRetry] = []

        for retry in retries {
            do {
                switch retry.operation {
                    case .indexDocument:
                        guard let record = try await fetchLibrary.document(withID: retry.documentID) else {
                            try await retryStore.removeRetries(for: [retry.documentID])
                            removedMissingDocumentIDs.append(retry.documentID)
                            continue
                        }

                        try await knowledgeBase.addDocument(documentMapper.document(from: record))
                    case .removeDocument:
                        try await knowledgeBase.removeDocument(documentMapper.documentID(for: retry.documentID))
                }

                try await retryStore.removeRetries(for: [retry.documentID])
                completedDocumentIDs.append(retry.documentID)
            } catch {
                let failedRetry = failedSemanticRetry(from: retry, error: error)
                try await retryStore.upsert(failedRetry)
                failedRetries.append(failedRetry)
            }
        }

        return SwiftlyFetchSemanticRetryResult(
            completedDocumentIDs: uniqueDocumentIDs(completedDocumentIDs),
            removedMissingDocumentIDs: uniqueDocumentIDs(removedMissingDocumentIDs),
            failedRetries: failedRetries
        )
    }

    private func indexSemantics(
        _ record: FetchDocumentRecord,
        conventionalResult: FetchKitLibrary.BatchResult
    ) async throws -> SwiftlyFetchMutationResult {
        let storedRecord = try await fetchLibrary.document(withID: record.id) ?? record

        do {
            try await knowledgeBase.addDocument(documentMapper.document(from: storedRecord))
            try await retryStore.removeRetries(for: [record.id])

            return try SwiftlyFetchMutationResult(
                documentIDs: conventionalResult.documentIDs,
                conventional: .succeeded,
                semantic: .succeeded(state: await semanticIndexState(for: record.id))
            )
        } catch {
            let retry = SwiftlyFetchSemanticRetry(
                documentID: record.id,
                operation: .indexDocument,
                reason: "SwiftlyFetch stored the corpus record, but semantic indexing failed.",
                lastFailure: String(describing: error)
            )
            try await retryStore.upsert(retry)

            return try SwiftlyFetchMutationResult(
                documentIDs: conventionalResult.documentIDs,
                conventional: .succeeded,
                semantic: SwiftlyFetchSemanticMutationStage(
                    status: .queuedRetry,
                    state: await semanticIndexState(for: record.id),
                    retry: retry,
                    failureDescription: retry.lastFailure
                )
            )
        }
    }

    private func semanticIndexState(for fetchDocumentID: FetchDocumentID) async throws -> SemanticIndexState? {
        try await knowledgeBase.semanticIndexState(
            for: documentMapper.documentID(for: fetchDocumentID)
        )
    }

    private func failedSemanticRetry(
        from retry: SwiftlyFetchSemanticRetry,
        error: Error
    ) -> SwiftlyFetchSemanticRetry {
        let now = Date()
        var failedRetry = retry
        failedRetry.attemptCount += 1
        failedRetry.lastAttemptAt = now
        failedRetry.nextRetryAt = now.addingTimeInterval(60)
        failedRetry.lastFailure = String(describing: error)
        return failedRetry
    }

    private func uniqueDocumentIDs(_ documentIDs: [FetchDocumentID]) -> [FetchDocumentID] {
        var seen = Set<FetchDocumentID>()
        return documentIDs.filter { seen.insert($0).inserted }
    }
}
