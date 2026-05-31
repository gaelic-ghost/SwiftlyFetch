import FetchCore
import FetchKit
import Foundation
import RAGCore
import RAGKit
import SwiftlyFetch
import SwiftlyFetchTestFixtures
import Testing

@Suite(.serialized)
struct SwiftlyFetchLibraryTests {
    @Test("Default facade ingests one document into conventional and semantic search")
    func defaultFacadeIngestsOneDocumentIntoBothSearchModes() async throws {
        let library = try await SwiftlyFetchLibrary.default()
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown,
            kind: .guide,
            language: "en"
        )

        let mutation = try await library.addDocument(record)
        let conventionalResults = try await library.search(FetchSearchQuery("apple guide", fields: [.title]))
        let semanticResults = try await library.retrieve(SearchQuery("bright crisp fruit", limit: 1))

        #expect(mutation.documentIDs == ["doc-apple"])
        #expect(mutation.conventional.status == .succeeded)
        #expect(mutation.semantic.status == .succeeded)
        #expect(conventionalResults.first?.document.id == "doc-apple")
        #expect(semanticResults.first?.chunk.documentID == "doc-apple")
    }

    @Test("Semantic indexing failure queues an index retry after the corpus write succeeds")
    func semanticIndexingFailureQueuesRetry() async throws {
        let fetchLibrary = FetchKitLibrary()
        let retryStore = InMemorySwiftlyFetchSemanticRetryStore()
        let failingKnowledgeBase = KnowledgeBase(
            chunker: ThrowingChunker(),
            embedder: HashingEmbedder(),
            index: InMemoryVectorIndex()
        )
        let library = SwiftlyFetchLibrary(
            fetchLibrary: fetchLibrary,
            knowledgeBase: failingKnowledgeBase,
            retryStore: retryStore
        )
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        let mutation = try await library.addDocument(record)
        let storedRecord = try await fetchLibrary.document(withID: "doc-apple")
        let retries = try await retryStore.pendingRetries()

        #expect(mutation.conventional.status == .succeeded)
        #expect(mutation.semantic.status == .queuedRetry)
        #expect(mutation.semantic.retry?.operation == .indexDocument)
        #expect(storedRecord == record)
        #expect(retries.map(\.documentID) == ["doc-apple"])
        #expect(retries.first?.operation == .indexDocument)
    }

    @Test("Semantic retry re-reads the latest corpus record")
    func semanticRetryReadsLatestCorpusRecord() async throws {
        let fetchLibrary = FetchKitLibrary()
        let retryStore = InMemorySwiftlyFetchSemanticRetryStore()
        try await fetchLibrary.addDocument(
            FetchDocumentRecord(
                id: "doc-apple",
                title: "Apple Guide",
                body: "Apples are bright and crisp."
            )
        )
        try await retryStore.upsert(
            SwiftlyFetchSemanticRetry(
                documentID: "doc-apple",
                operation: .indexDocument,
                reason: "Test retry"
            )
        )
        let library = try SwiftlyFetchLibrary(
            fetchLibrary: fetchLibrary,
            knowledgeBase: await KnowledgeBase.hashingDefault(),
            retryStore: retryStore
        )

        let retryResult = try await library.retrySemanticIndexing()
        let semanticResults = try await library.retrieve(SearchQuery("bright crisp", limit: 1))
        let retriesAfterRetry = try await retryStore.pendingRetries()

        #expect(retryResult.completedDocumentIDs == ["doc-apple"])
        #expect(retryResult.failedRetries.isEmpty)
        #expect(retriesAfterRetry.isEmpty)
        #expect(semanticResults.first?.chunk.documentID == "doc-apple")
    }

    @Test("Semantic retry skips records until their next retry date")
    func semanticRetrySkipsRecordsUntilNextRetryDate() async throws {
        let fetchLibrary = FetchKitLibrary()
        let retryStore = InMemorySwiftlyFetchSemanticRetryStore()
        try await fetchLibrary.addDocument(
            FetchDocumentRecord(
                id: "doc-due",
                title: "Due Apple Guide",
                body: "Due apples are bright and crisp."
            )
        )
        try await fetchLibrary.addDocument(
            FetchDocumentRecord(
                id: "doc-deferred",
                title: "Deferred Apple Guide",
                body: "Deferred apples are bright and crisp."
            )
        )
        try await retryStore.upsert(
            SwiftlyFetchSemanticRetry(
                documentID: "doc-deferred",
                operation: .indexDocument,
                reason: "Test deferred retry",
                nextRetryAt: Date().addingTimeInterval(3600)
            )
        )
        try await retryStore.upsert(
            SwiftlyFetchSemanticRetry(
                documentID: "doc-due",
                operation: .indexDocument,
                reason: "Test due retry",
                nextRetryAt: Date().addingTimeInterval(-60)
            )
        )
        let library = try SwiftlyFetchLibrary(
            fetchLibrary: fetchLibrary,
            knowledgeBase: await KnowledgeBase.hashingDefault(),
            retryStore: retryStore
        )

        let retryResult = try await library.retrySemanticIndexing()
        let retriesAfterRetry = try await retryStore.pendingRetries()

        #expect(retryResult.completedDocumentIDs == ["doc-due"])
        #expect(retryResult.deferredDocumentIDs == ["doc-deferred"])
        #expect(retryResult.failedRetries.isEmpty)
        #expect(retriesAfterRetry.map(\.documentID) == ["doc-deferred"])
    }

    @Test("Failed semantic retries wait for their next retry date")
    func failedSemanticRetriesWaitForNextRetryDate() async throws {
        let fetchLibrary = FetchKitLibrary()
        let retryStore = InMemorySwiftlyFetchSemanticRetryStore()
        try await fetchLibrary.addDocument(
            FetchDocumentRecord(
                id: "doc-apple",
                title: "Apple Guide",
                body: "Apples are bright and crisp."
            )
        )
        try await retryStore.upsert(
            SwiftlyFetchSemanticRetry(
                documentID: "doc-apple",
                operation: .indexDocument,
                reason: "Test retry"
            )
        )
        let library = SwiftlyFetchLibrary(
            fetchLibrary: fetchLibrary,
            knowledgeBase: KnowledgeBase(
                chunker: ThrowingChunker(),
                embedder: HashingEmbedder(),
                index: InMemoryVectorIndex()
            ),
            retryStore: retryStore
        )

        let firstRetryResult = try await library.retrySemanticIndexing()
        let retriesAfterFailure = try await retryStore.pendingRetries()
        let retryAfterFailure = try #require(retriesAfterFailure.first)
        let secondRetryResult = try await library.retrySemanticIndexing()
        let retriesAfterDeferral = try await retryStore.pendingRetries()
        let retryAfterDeferral = try #require(retriesAfterDeferral.first)

        #expect(firstRetryResult.completedDocumentIDs.isEmpty)
        #expect(firstRetryResult.failedRetries.map(\.documentID) == ["doc-apple"])
        #expect(firstRetryResult.deferredDocumentIDs.isEmpty)
        #expect(retryAfterFailure.attemptCount == 1)
        #expect(retryAfterFailure.nextRetryAt != nil)
        #expect(secondRetryResult.completedDocumentIDs.isEmpty)
        #expect(secondRetryResult.failedRetries.isEmpty)
        #expect(secondRetryResult.deferredDocumentIDs == ["doc-apple"])
        #expect(retryAfterDeferral.attemptCount == 1)
    }

    @Test("Semantic remove failure queues a remove retry")
    func semanticRemoveFailureQueuesRemoveRetry() async throws {
        let fetchLibrary = FetchKitLibrary()
        let retryStore = InMemorySwiftlyFetchSemanticRetryStore()
        let library = SwiftlyFetchLibrary(
            fetchLibrary: fetchLibrary,
            knowledgeBase: KnowledgeBase(
                chunker: DefaultChunker(),
                embedder: HashingEmbedder(),
                index: RemoveFailingVectorIndex()
            ),
            retryStore: retryStore
        )
        try await fetchLibrary.addDocument(
            FetchDocumentRecord(
                id: "doc-apple",
                body: "Apples are bright and crisp."
            )
        )

        let mutation = try await library.removeDocument(withID: "doc-apple")
        let retries = try await retryStore.pendingRetries()

        #expect(mutation.conventional.status == .succeeded)
        #expect(mutation.semantic.status == .queuedRetry)
        #expect(mutation.semantic.retry?.operation == .removeDocument)
        #expect(retries.first?.operation == .removeDocument)
    }

    @Test("Semantic state read failures do not queue semantic retries")
    func semanticStateReadFailuresDoNotQueueRetries() async throws {
        let fetchLibrary = FetchKitLibrary()
        let retryStore = InMemorySwiftlyFetchSemanticRetryStore()
        let library = SwiftlyFetchLibrary(
            fetchLibrary: fetchLibrary,
            knowledgeBase: KnowledgeBase(
                chunker: DefaultChunker(),
                embedder: HashingEmbedder(),
                index: StateReadFailingVectorIndex()
            ),
            retryStore: retryStore
        )
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        let addMutation = try await library.addDocument(record)
        let removeMutation = try await library.removeDocument(withID: "doc-apple")
        let retries = try await retryStore.pendingRetries()

        #expect(addMutation.semantic.status == .succeeded)
        #expect(addMutation.semantic.state == nil)
        #expect(removeMutation.semantic.status == .succeeded)
        #expect(removeMutation.semantic.state == nil)
        #expect(retries.isEmpty)
    }

    @Test("Retry removes missing index retries")
    func retryRemovesMissingIndexRetries() async throws {
        let retryStore = InMemorySwiftlyFetchSemanticRetryStore()
        try await retryStore.upsert(
            SwiftlyFetchSemanticRetry(
                documentID: "doc-missing",
                operation: .indexDocument,
                reason: "Test retry"
            )
        )
        let library = try SwiftlyFetchLibrary(
            fetchLibrary: FetchKitLibrary(),
            knowledgeBase: await KnowledgeBase.hashingDefault(),
            retryStore: retryStore
        )

        let result = try await library.retrySemanticIndexing()
        let retries = try await retryStore.pendingRetries()

        #expect(result.removedMissingDocumentIDs == ["doc-missing"])
        #expect(retries.isEmpty)
    }

    @Test("Facade returns conventional and semantic corpus results side by side")
    func facadeReturnsConventionalAndSemanticCorpusResultsSideBySide() async throws {
        let library = try await indexedFixtureLibrary()

        let botanyResult = try await library.searchAndRetrieve(
            conventional: FetchSearchQuery(
                "storage food seeds",
                kind: .allTerms,
                fields: [.body],
                limit: 3
            ),
            semantic: SearchQuery("food stored inside seeds for growing plants", limit: 3)
        )
        let storyResult = try await library.searchAndRetrieve(
            conventional: FetchSearchQuery(
                "needle sew shirt",
                kind: .allTerms,
                fields: [.title, .body],
                limit: 3
            ),
            semantic: SearchQuery("a child and mother fix a shirt with a needle", limit: 3)
        )

        #expect(botanyResult.conventional.first?.document.id == "gutenberg-78430-chapter-1")
        #expect(botanyResult.semantic.map(\.chunk.documentID).contains("gutenberg-78430-chapter-1"))
        #expect(storyResult.conventional.first?.document.id == "tinystories-row-0-needle")
        #expect(storyResult.semantic.map(\.chunk.documentID).contains("tinystories-row-0-needle"))
    }

#if os(macOS)
    @Test("Persistent facade reopens conventional and semantic state")
    func persistentFacadeReopensConventionalAndSemanticState() async throws {
        let directory = try temporaryDirectory()
        defer {
            cleanupTemporaryDirectory(directory)
        }

        do {
            let firstLibrary = try await SwiftlyFetchLibrary.macOSPersistentLibrary(at: directory)
            try await firstLibrary.addDocument(
                FetchDocumentRecord(
                    id: "doc-apple",
                    title: "Apple Guide",
                    body: "Apples are bright and crisp.",
                    contentType: .markdown
                )
            )
        }

        let reopenedLibrary = try await SwiftlyFetchLibrary.macOSPersistentLibrary(at: directory)
        let conventionalResults = try await reopenedLibrary.search(FetchSearchQuery("apple guide", fields: [.title]))
        let semanticResults = try await reopenedLibrary.retrieve(SearchQuery("bright crisp", limit: 1))

        #expect(conventionalResults.first?.document.id == "doc-apple")
        #expect(semanticResults.first?.chunk.documentID == "doc-apple")
    }

    @Test("Core Data semantic retry store reopens pending retries")
    func coreDataSemanticRetryStoreReopensPendingRetries() async throws {
        let directory = try temporaryDirectory()
        defer {
            cleanupTemporaryDirectory(directory)
        }
        let storeURL = directory.appendingPathComponent("SemanticRetries.sqlite")
        let olderDate = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let newerDate = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 2)))

        do {
            let store = try await CoreDataSwiftlyFetchSemanticRetryStore(
                configuration: .init(store: .sqlite(storeURL))
            )
            try await store.upsert(
                SwiftlyFetchSemanticRetry(
                    documentID: "doc-newer",
                    operation: .removeDocument,
                    reason: "Test persisted remove retry",
                    attemptCount: 2,
                    createdAt: newerDate,
                    lastAttemptAt: newerDate,
                    nextRetryAt: newerDate.addingTimeInterval(60),
                    lastFailure: "Test remove failed."
                )
            )
            try await store.upsert(
                SwiftlyFetchSemanticRetry(
                    documentID: "doc-older",
                    operation: .indexDocument,
                    reason: "Test persisted index retry",
                    createdAt: olderDate,
                    lastFailure: "Test indexing failed."
                )
            )
        }

        let reopenedStore = try await CoreDataSwiftlyFetchSemanticRetryStore(
            configuration: .init(store: .sqlite(storeURL))
        )
        let pendingRetries = try await reopenedStore.pendingRetries()
        let limitedRetries = try await reopenedStore.pendingRetries(limit: 1)

        #expect(pendingRetries.map(\.documentID) == ["doc-older", "doc-newer"])
        #expect(pendingRetries.first?.operation == .indexDocument)
        #expect(pendingRetries.first?.reason == "Test persisted index retry")
        #expect(pendingRetries.first?.lastFailure == "Test indexing failed.")
        #expect(pendingRetries.last?.operation == .removeDocument)
        #expect(pendingRetries.last?.attemptCount == 2)
        #expect(pendingRetries.last?.lastFailure == "Test remove failed.")
        #expect(limitedRetries.map(\.documentID) == ["doc-older"])

        try await reopenedStore.removeRetries(for: ["doc-older"])

        let finalStore = try await CoreDataSwiftlyFetchSemanticRetryStore(
            configuration: .init(store: .sqlite(storeURL))
        )
        let finalRetries = try await finalStore.pendingRetries()

        #expect(finalRetries.map(\.documentID) == ["doc-newer"])
    }
#endif
}

private func indexedFixtureLibrary() async throws -> SwiftlyFetchLibrary {
    let library = try await SwiftlyFetchLibrary.default()

    for record in GutenbergMiniCorpus.records + TinyStoriesMiniCorpus.records {
        try await library.addDocument(record)
    }

    return library
}

private struct ThrowingChunker: Chunker {
    func chunks(for document: Document) throws -> [Chunk] {
        throw TestFailure.chunkingFailed
    }
}

private actor RemoveFailingVectorIndex: VectorIndex {
    func upsert(_ chunks: [IndexedChunk]) async throws {}

    func search(_ query: SearchQuery, embedding: EmbeddingVector) async throws -> [SearchResult] {
        []
    }

    func removeChunks(for documentID: DocumentID) async throws {
        throw TestFailure.semanticRemoveFailed
    }

    func removeAll() async throws {}
}

private actor StateReadFailingVectorIndex: VectorIndex, SemanticIndexStateStore {
    private var chunksByDocumentID: [DocumentID: [IndexedChunk]] = [:]

    func upsert(_ chunks: [IndexedChunk]) async throws {
        for chunk in chunks {
            chunksByDocumentID[chunk.chunk.documentID, default: []].append(chunk)
        }
    }

    func search(_ query: SearchQuery, embedding: EmbeddingVector) async throws -> [SearchResult] {
        []
    }

    func removeChunks(for documentID: DocumentID) async throws {
        chunksByDocumentID[documentID] = nil
    }

    func removeAll() async throws {
        chunksByDocumentID.removeAll()
    }

    func state(for documentID: DocumentID) async throws -> SemanticIndexState? {
        throw TestFailure.semanticStateReadFailed
    }

    func states(for documentIDs: [DocumentID]) async throws -> [SemanticIndexState] {
        throw TestFailure.semanticStateReadFailed
    }

    func markIndexing(documentID: DocumentID, fingerprint: SemanticIndexFingerprint) async throws {}

    func markCurrent(documentID: DocumentID, fingerprint: SemanticIndexFingerprint) async throws {}

    func markStale(documentID: DocumentID, reason: String?) async throws {}

    func markFailed(
        documentID: DocumentID,
        fingerprint: SemanticIndexFingerprint?,
        reason: String
    ) async throws {}
}

private enum TestFailure: Error, CustomStringConvertible {
    case chunkingFailed
    case semanticRemoveFailed
    case semanticStateReadFailed

    var description: String {
        switch self {
            case .chunkingFailed:
                "Test chunker intentionally failed while building semantic chunks."
            case .semanticRemoveFailed:
                "Test vector index intentionally failed while removing semantic chunks."
            case .semanticStateReadFailed:
                "Test semantic index state store intentionally failed while reading state."
        }
    }
}

#if os(macOS)
private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default
        .temporaryDirectory
        .appendingPathComponent("SwiftlyFetchTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )

    return directory
}

private func cleanupTemporaryDirectory(_ directory: URL) {
    do {
        try FileManager.default.removeItem(at: directory)
    } catch {
        Issue.record(
            "SwiftlyFetch could not remove a temporary test directory at \(directory.path). \(error.localizedDescription)"
        )
    }
}
#endif
