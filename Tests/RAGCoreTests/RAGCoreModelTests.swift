import Testing
@testable import RAGCore

@Test("Metadata filters evaluate typed metadata values")
func metadataFiltersMatchTypedValues() {
    let metadata: ChunkMetadata = [
        "category": .string("guide"),
        "priority": .int(3),
        "published": .bool(true),
    ]

    #expect(MetadataFilter.equals("priority", .int(3)).matches(metadata))
    #expect(MetadataFilter.contains("category", "gui").matches(metadata))
    #expect(MetadataFilter.hasKey("published").matches(metadata))
    #expect(MetadataFilter.not(.equals("published", .bool(false))).matches(metadata))
    #expect(!MetadataFilter.not(.contains("category", "gui")).matches(metadata))
    #expect(!MetadataFilter.equals("priority", .int(2)).matches(metadata))
}

@Test("Embedding vectors normalize and compare by cosine similarity")
func embeddingVectorNormalizationAndSimilarity() {
    let lhs = EmbeddingVector([3, 4])
    let rhs = EmbeddingVector([6, 8])

    #expect(lhs.normalized().values == [0.6, 0.8])
    #expect(abs(lhs.cosineSimilarity(to: rhs) - 1.0) < 0.000_001)
}
