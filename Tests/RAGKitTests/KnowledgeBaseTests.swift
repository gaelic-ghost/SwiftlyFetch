import Testing
import RAGCore
@testable import RAGKit

@Test("KnowledgeBase adds documents, searches them, and removes them deterministically")
func knowledgeBaseIndexesSearchesAndRemovesDocuments() async throws {
    let knowledgeBase = KnowledgeBase(
        chunker: ParagraphChunker(),
        embedder: FixedEmbedder(
            chunkEmbeddingsByText: [
                "Apples are bright and crisp.": EmbeddingVector([1, 0]).normalized(),
                "Bananas are soft and sweet.": EmbeddingVector([0, 1]).normalized(),
                "Oranges are juicy and bright.": EmbeddingVector([0.9, 0.1]).normalized(),
            ],
            queryEmbeddingsByText: [
                "bright fruit": EmbeddingVector([1, 0]).normalized(),
            ]
        ),
        index: InMemoryVectorIndex()
    )

    try await knowledgeBase.addDocuments([
        Document(
            id: "doc-apples",
            content: .text("Apples are bright and crisp.\n\nBananas are soft and sweet."),
            metadata: ["category": .string("fruit")]
        ),
        Document(
            id: "doc-oranges",
            content: .markdown("Oranges are juicy and bright."),
            metadata: ["category": .string("citrus")]
        ),
    ])

    let results = try await knowledgeBase.search("bright fruit", limit: 2)
    #expect(results.count == 2)
    #expect(results.first?.chunk.documentID == "doc-apples")
    #expect(results.last?.chunk.documentID == "doc-oranges")

    try await knowledgeBase.removeDocument("doc-apples")
    let remainingResults = try await knowledgeBase.search("bright fruit", limit: 5)
    #expect(remainingResults.map(\.chunk.documentID) == ["doc-oranges"])
}

@Test("KnowledgeBase makeContext renders plain and annotated snippets within budget")
func knowledgeBaseMakeContextRendersDeterministicContext() async throws {
    let knowledgeBase = KnowledgeBase(
        chunker: ParagraphChunker(),
        embedder: FixedEmbedder(
            chunkEmbeddingsByText: [
                "First paragraph about apples.": EmbeddingVector([1, 0]).normalized(),
                "Second paragraph about oranges.": EmbeddingVector([0.8, 0.2]).normalized(),
            ],
            queryEmbeddingsByText: [
                "fruit summary": EmbeddingVector([1, 0]).normalized(),
            ]
        ),
        index: InMemoryVectorIndex()
    )

    try await knowledgeBase.addDocument(
        Document(
            id: "doc-fruit",
            content: .text("First paragraph about apples.\n\nSecond paragraph about oranges."),
            metadata: ["category": .string("fruit")]
        )
    )

    let plainContext = try await knowledgeBase.makeContext(
        for: "fruit summary",
        limit: 2,
        budget: .characters(40),
        style: .plain
    )

    let annotatedContext = try await knowledgeBase.makeContext(
        for: "fruit summary",
        limit: 1,
        budget: .unlimited,
        style: .annotated
    )

    #expect(plainContext == "First paragraph about apples.\n\nSecond…")
    #expect(annotatedContext.contains("[Document: doc-fruit | Chunk: doc-fruit#0 | Score:"))
    #expect(annotatedContext.contains("First paragraph about apples."))
}

private struct FixedEmbedder: Embedder, Sendable {
    let chunkEmbeddingsByText: [String: EmbeddingVector]
    let queryEmbeddingsByText: [String: EmbeddingVector]

    func embed(chunks: [Chunk]) async throws -> [EmbeddingVector] {
        chunks.map { chunkEmbeddingsByText[$0.text] ?? EmbeddingVector([0, 0]) }
    }

    func embed(query: SearchQuery) async throws -> EmbeddingVector {
        queryEmbeddingsByText[query.text] ?? EmbeddingVector([0, 0])
    }
}
