import Foundation
import Testing
import RAGCore
@testable import RAGKit

@Test("NaturalLanguageEmbedder produces non-empty normalized vectors when integration coverage is enabled")
func naturalLanguageEmbedderProducesVectorsWhenEnabled() async throws {
    guard ProcessInfo.processInfo.environment["RUN_NL_INTEGRATION_TESTS"] == "1" else {
        return
    }

    let embedder = try NaturalLanguageEmbedder(languageHint: "en")
    let documentID = DocumentID("integration-doc")
    let chunks = [
        Chunk(
            id: ChunkID("integration-doc#0"),
            documentID: documentID,
            text: "Local retrieval should feel native in Swift apps.",
            position: ChunkPosition(documentID: documentID, chunkIndex: 0, startOffset: 0, endOffset: 44)
        )
    ]

    let chunkEmbeddings = try await embedder.embed(chunks: chunks)
    let queryEmbedding = try await embedder.embed(query: SearchQuery("native Swift retrieval"))

    #expect(chunkEmbeddings.count == 1)
    #expect(!chunkEmbeddings[0].isEmpty)
    #expect(chunkEmbeddings[0].dimension == queryEmbedding.dimension)
    #expect(abs(queryEmbedding.cosineSimilarity(to: queryEmbedding) - 1.0) < 0.000_001)
}
