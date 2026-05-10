import RAGCore
@testable import RAGKit
import XCTest

final class CoreDataVectorIndexTests: XCTestCase {
    func testCoreDataVectorIndexPersistsChunksAcrossReopen() async throws {
        let storeURL = temporaryStoreURL()
        let documentID = DocumentID("doc-fruit")
        let indexedChunks = [
            makeIndexedChunk(
                id: "doc-fruit#0",
                documentID: documentID,
                text: "Apples are bright and crisp.",
                embedding: [1, 0, 0],
                metadata: ["kind": .string("guide")]
            ),
            makeIndexedChunk(
                id: "doc-fruit#1",
                documentID: documentID,
                text: "Oranges are juicy and sweet.",
                embedding: [0, 1, 0],
                metadata: ["kind": .string("guide")]
            ),
        ]

        let index = try await CoreDataVectorIndex(
            configuration: .init(store: .sqlite(storeURL))
        )
        try await index.upsert(indexedChunks)

        let reopenedIndex = try await CoreDataVectorIndex(
            configuration: .init(store: .sqlite(storeURL))
        )
        let results = try await reopenedIndex.search(
            SearchQuery("fruit", limit: 2),
            embedding: EmbeddingVector([1, 0, 0])
        )

        XCTAssertEqual(results.map(\.chunk.id), ["doc-fruit#0", "doc-fruit#1"])
        XCTAssertEqual(results.first?.chunk.text, "Apples are bright and crisp.")
        XCTAssertEqual(results.first?.chunk.metadata["kind"], .string("guide"))
    }

    func testCoreDataVectorIndexReplacesExistingChunks() async throws {
        let index = try await CoreDataVectorIndex()
        let original = makeIndexedChunk(
            id: "doc-fruit#0",
            documentID: "doc-fruit",
            text: "Original apple text.",
            embedding: [1, 0]
        )
        let replacement = makeIndexedChunk(
            id: "doc-fruit#0",
            documentID: "doc-fruit",
            text: "Updated orange text.",
            embedding: [0, 1]
        )

        try await index.upsert([original])
        try await index.upsert([replacement])

        let appleResults = try await index.search(
            SearchQuery("apple", limit: 1),
            embedding: EmbeddingVector([1, 0])
        )
        let orangeResults = try await index.search(
            SearchQuery("orange", limit: 1),
            embedding: EmbeddingVector([0, 1])
        )

        XCTAssertEqual(appleResults.first?.chunk.text, "Updated orange text.")
        XCTAssertEqual(orangeResults.first?.chunk.text, "Updated orange text.")
        XCTAssertEqual(orangeResults.first?.score, 1.0)
    }

    func testCoreDataVectorIndexFiltersAndRemovesByDocumentID() async throws {
        let index = try await CoreDataVectorIndex()
        try await index.upsert([
            makeIndexedChunk(
                id: "doc-guide#0",
                documentID: "doc-guide",
                text: "Apples are bright and crisp.",
                embedding: [1, 0],
                metadata: ["kind": .string("guide")]
            ),
            makeIndexedChunk(
                id: "doc-note#0",
                documentID: "doc-note",
                text: "Oranges are juicy and sweet.",
                embedding: [0, 1],
                metadata: ["kind": .string("note")]
            ),
        ])

        let filteredResults = try await index.search(
            SearchQuery(
                "fruit",
                limit: 5,
                filter: .equals("kind", .string("guide"))
            ),
            embedding: EmbeddingVector([1, 0])
        )

        XCTAssertEqual(filteredResults.map(\.chunk.documentID), ["doc-guide"])

        try await index.removeChunks(for: "doc-guide")
        let remainingResults = try await index.search(
            SearchQuery("fruit", limit: 5),
            embedding: EmbeddingVector([1, 0])
        )

        XCTAssertEqual(remainingResults.map(\.chunk.documentID), ["doc-note"])
    }

    func testCoreDataVectorIndexRemoveAllClearsPersistedChunks() async throws {
        let storeURL = temporaryStoreURL()
        let index = try await CoreDataVectorIndex(
            configuration: .init(store: .sqlite(storeURL))
        )
        try await index.upsert([
            makeIndexedChunk(
                id: "doc-fruit#0",
                documentID: "doc-fruit",
                text: "Apples are bright and crisp.",
                embedding: [1, 0]
            ),
        ])

        try await index.removeAll()

        let reopenedIndex = try await CoreDataVectorIndex(
            configuration: .init(store: .sqlite(storeURL))
        )
        let results = try await reopenedIndex.search(
            SearchQuery("fruit", limit: 5),
            embedding: EmbeddingVector([1, 0])
        )

        XCTAssertTrue(results.isEmpty)
    }

    func testPersistentKnowledgeBaseConvenienceReusesStoredSemanticIndex() async throws {
        let storeURL = temporaryStoreURL()
        let configuration = CoreDataVectorIndex.Configuration(store: .sqlite(storeURL))
        let knowledgeBase = try await KnowledgeBase.persistentHashingDefault(
            configuration: configuration
        )

        try await knowledgeBase.addDocument(
            Document(
                id: "doc-fruit",
                content: .markdown(
                    """
                    # Fruit Guide

                    ## Apples

                    Apples are bright and crisp.
                    """
                )
            )
        )

        let reopenedKnowledgeBase = try await KnowledgeBase.persistentHashingDefault(
            configuration: configuration
        )
        let results = try await reopenedKnowledgeBase.search("bright fruit", limit: 1)

        XCTAssertEqual(results.first?.chunk.documentID, "doc-fruit")
        XCTAssertEqual(results.first?.chunk.text, "Fruit Guide\nApples\n\nApples are bright and crisp.")
    }

    func testKnowledgeBaseMarksSemanticStateCurrentAfterIndexing() async throws {
        let index = try await CoreDataVectorIndex()
        let knowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: HashingEmbedder(dimension: 16),
            index: index
        )

        try await knowledgeBase.addDocument(
            Document(
                id: "doc-fruit",
                content: .text("Apples are bright and crisp."),
                metadata: ["kind": .string("guide")]
            )
        )

        let state = try await index.state(for: "doc-fruit")

        XCTAssertEqual(state?.status, .current)
        XCTAssertEqual(state?.documentID, "doc-fruit")
        XCTAssertEqual(state?.fingerprint?.chunker, "ragkit.paragraph-chunker.v1|ragkit.heading-aware-markdown.v1.links-omit")
        XCTAssertEqual(state?.fingerprint?.embedder, "ragkit.hashing.16")
        XCTAssertNotNil(state?.fingerprint?.source)
        XCTAssertNotNil(state?.lastIndexedAt)
        XCTAssertNil(state?.lastFailure)
    }

    func testKnowledgeBaseMarksSemanticStateFailedWhenEmbeddingFails() async throws {
        let index = try await CoreDataVectorIndex()
        let knowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: FailingEmbedder(),
            index: index
        )

        do {
            try await knowledgeBase.addDocument(
                Document(
                    id: "doc-fruit",
                    content: .text("Apples are bright and crisp.")
                )
            )
            XCTFail("Expected semantic indexing to surface the embedding failure.")
        } catch {}

        let state = try await index.state(for: "doc-fruit")

        XCTAssertEqual(state?.status, .failed)
        XCTAssertTrue(state?.fingerprint?.embedder.hasPrefix("custom.embedder.") == true)
        XCTAssertTrue(state?.fingerprint?.embedder.contains("FailingEmbedder") == true)
        XCTAssertEqual(state?.lastFailure, "embeddingUnavailable")
        XCTAssertNil(state?.lastIndexedAt)
    }

    func testCoreDataVectorIndexCanMarkStateStale() async throws {
        let index = try await CoreDataVectorIndex()
        let fingerprint = SemanticIndexFingerprint(
            source: "source-a",
            chunker: "chunker-a",
            embedder: "embedder-a"
        )

        try await index.markCurrent(documentID: "doc-fruit", fingerprint: fingerprint)
        try await index.markStale(
            documentID: "doc-fruit",
            reason: "Source fingerprint changed."
        )

        let state = try await index.state(for: "doc-fruit")

        XCTAssertEqual(state?.status, .stale)
        XCTAssertEqual(state?.fingerprint, fingerprint)
        XCTAssertEqual(state?.lastFailure, "Source fingerprint changed.")
        XCTAssertNotNil(state?.lastIndexedAt)
    }

    func testSemanticSourceFingerprintChangesWithDocumentContent() async throws {
        let index = try await CoreDataVectorIndex()
        let firstKnowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: HashingEmbedder(),
            index: index
        )
        try await firstKnowledgeBase.addDocument(
            Document(
                id: "doc-fruit",
                content: .text("Apples are bright and crisp.")
            )
        )
        let firstFingerprint = try await index.state(for: "doc-fruit")?.fingerprint?.source

        let secondKnowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: HashingEmbedder(),
            index: index
        )
        try await secondKnowledgeBase.addDocument(
            Document(
                id: "doc-fruit",
                content: .text("Oranges are juicy and sweet.")
            )
        )
        let secondFingerprint = try await index.state(for: "doc-fruit")?.fingerprint?.source

        XCTAssertNotNil(firstFingerprint)
        XCTAssertNotNil(secondFingerprint)
        XCTAssertNotEqual(firstFingerprint, secondFingerprint)
    }

    private func makeIndexedChunk(
        id: ChunkID,
        documentID: DocumentID,
        text: String,
        embedding: [Double],
        metadata: ChunkMetadata = ChunkMetadata(),
        chunkIndex: Int = 0
    ) -> IndexedChunk {
        IndexedChunk(
            chunk: Chunk(
                id: id,
                documentID: documentID,
                text: text,
                metadata: metadata,
                position: ChunkPosition(
                    documentID: documentID,
                    chunkIndex: chunkIndex,
                    startOffset: 0,
                    endOffset: text.count
                )
            ),
            embedding: EmbeddingVector(embedding)
        )
    }

    private func temporaryStoreURL(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> URL {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("SwiftlyFetchTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            XCTFail(
                "RAGKit could not create a temporary Core Data vector index test directory. \(error.localizedDescription)",
                file: file,
                line: line
            )
        }

        return directory.appendingPathComponent("RAGKitVectorIndex.sqlite")
    }
}

private struct FailingEmbedder: Embedder {
    enum Failure: Error, CustomStringConvertible {
        case embeddingUnavailable

        var description: String {
            "embeddingUnavailable"
        }
    }

    func embed(chunks _: [Chunk]) async throws -> [EmbeddingVector] {
        throw Failure.embeddingUnavailable
    }

    func embed(query _: SearchQuery) async throws -> EmbeddingVector {
        throw Failure.embeddingUnavailable
    }
}
