import FetchCore
import FetchKit
import Foundation
import RAGCore
import RAGKit
import SwiftlyFetch
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

#if os(macOS)
    @Test("Persistent facade reopens conventional and semantic state")
    func persistentFacadeReopensConventionalAndSemanticState() async throws {
        let directory = try temporaryDirectory()

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
#endif
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

private enum TestFailure: Error, CustomStringConvertible {
    case chunkingFailed
    case semanticRemoveFailed

    var description: String {
        switch self {
            case .chunkingFailed:
                "Test chunker intentionally failed while building semantic chunks."
            case .semanticRemoveFailed:
                "Test vector index intentionally failed while removing semantic chunks."
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
#endif
