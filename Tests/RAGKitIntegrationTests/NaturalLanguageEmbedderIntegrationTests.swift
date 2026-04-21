import Foundation
import Testing
import RAGCore
@testable import RAGKit

@Suite(
    "NaturalLanguageEmbedder Integration",
    .enabled(if: ProcessInfo.processInfo.environment["RUN_NL_INTEGRATION_TESTS"] == "1")
)
struct NaturalLanguageEmbedderIntegrationTests {
    @Test("NaturalLanguageEmbedder integration coverage proves useful retrieval ranking when enabled")
    func naturalLanguageEmbedderSupportsSemanticRetrievalWhenEnabled() async throws {
        let knowledgeBase = try await KnowledgeBase.naturalLanguageDefault(languageHint: "en")

        try await knowledgeBase.addDocuments([
            Document(
                id: "doc-apples",
                content: .text("Apples are crisp orchard fruit that grow on trees and taste sweet.")
            ),
            Document(
                id: "doc-space",
                content: .text("Astronomers use telescopes to study galaxies, stars, and distant nebulae.")
            ),
            Document(
                id: "doc-swift",
                content: .text("Swift packages build reusable modules, tests, and command line tools.")
            ),
        ])

        let orchardResults = try await knowledgeBase.search("sweet orchard apple fruit", limit: 3)
        let astronomyResults = try await knowledgeBase.search("distant galaxies seen through a telescope", limit: 3)

        #expect(orchardResults.count == 3)
        #expect(astronomyResults.count == 3)

        #expect(orchardResults[0].chunk.documentID == "doc-apples")
        #expect(astronomyResults[0].chunk.documentID == "doc-space")

        #expect(orchardResults[0].score > orchardResults[1].score)
        #expect(astronomyResults[0].score > astronomyResults[1].score)

        let appleResult = try #require(orchardResults.first { $0.chunk.documentID == "doc-apples" })
        let spaceResult = try #require(orchardResults.first { $0.chunk.documentID == "doc-space" })
        let astronomyResult = try #require(astronomyResults.first { $0.chunk.documentID == "doc-space" })
        let swiftResult = try #require(astronomyResults.first { $0.chunk.documentID == "doc-swift" })

        #expect(!appleResult.chunk.text.isEmpty)
        #expect(!astronomyResult.chunk.text.isEmpty)
        #expect(appleResult.score > spaceResult.score)
        #expect(astronomyResult.score > swiftResult.score)

        let embedder = try NaturalLanguageEmbedder(languageHint: "en")
        let queryEmbedding = try await embedder.embed(query: SearchQuery("sweet orchard apple fruit"))
        let comparisonChunks = [
            Chunk(
                id: ChunkID("comparison#0"),
                documentID: DocumentID("comparison"),
                text: "Apples are crisp orchard fruit that grow on trees and taste sweet.",
                position: ChunkPosition(documentID: DocumentID("comparison"), chunkIndex: 0, startOffset: 0, endOffset: 66)
            ),
            Chunk(
                id: ChunkID("comparison#1"),
                documentID: DocumentID("comparison"),
                text: "Astronomers use telescopes to study galaxies, stars, and distant nebulae.",
                position: ChunkPosition(documentID: DocumentID("comparison"), chunkIndex: 1, startOffset: 0, endOffset: 74)
            ),
        ]

        let comparisonEmbeddings = try await embedder.embed(chunks: comparisonChunks)

        #expect(comparisonEmbeddings.count == 2)
        #expect(!comparisonEmbeddings[0].isEmpty)
        #expect(comparisonEmbeddings[0].dimension == queryEmbedding.dimension)
        #expect(queryEmbedding.cosineSimilarity(to: comparisonEmbeddings[0]) > queryEmbedding.cosineSimilarity(to: comparisonEmbeddings[1]))
        #expect(abs(queryEmbedding.cosineSimilarity(to: queryEmbedding) - 1.0) < 0.000_001)
    }
}
