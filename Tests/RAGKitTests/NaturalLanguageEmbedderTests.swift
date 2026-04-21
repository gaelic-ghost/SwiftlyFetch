import Testing
import RAGCore
@testable import RAGKit

@Suite("NaturalLanguageEmbedder")
struct NaturalLanguageEmbedderTests {
    @Test("NaturalLanguageEmbedder delegates chunk and query embedding through its backend")
    func naturalLanguageEmbedderDelegatesToBackend() async throws {
        let backend = FakeContextualEmbeddingBackend(
            vectorsByText: [
                "First chunk": EmbeddingVector([1, 0, 0]),
                "Second chunk": EmbeddingVector([0, 1, 0]),
                "Find this": EmbeddingVector([0, 0, 1]),
            ]
        )

        let embedder = NaturalLanguageEmbedder(backend: backend)
        let documentID = DocumentID("doc-1")
        let chunks = [
            Chunk(
                id: ChunkID("doc-1#0"),
                documentID: documentID,
                text: "First chunk",
                position: ChunkPosition(documentID: documentID, chunkIndex: 0, startOffset: 0, endOffset: 11)
            ),
            Chunk(
                id: ChunkID("doc-1#1"),
                documentID: documentID,
                text: "Second chunk",
                position: ChunkPosition(documentID: documentID, chunkIndex: 1, startOffset: 12, endOffset: 24)
            ),
        ]

        let chunkEmbeddings = try await embedder.embed(chunks: chunks)
        let queryEmbedding = try await embedder.embed(query: SearchQuery("Find this"))

        #expect(chunkEmbeddings == [EmbeddingVector([1, 0, 0]), EmbeddingVector([0, 1, 0])])
        #expect(queryEmbedding == EmbeddingVector([0, 0, 1]))
        #expect(await backend.recordedTexts() == ["First chunk", "Second chunk", "Find this"])
    }
}
