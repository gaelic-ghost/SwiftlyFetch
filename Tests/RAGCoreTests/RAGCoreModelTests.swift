import Foundation
import Testing
@testable import RAGCore

@Suite("RAGCore Metadata Filters")
struct MetadataFilterTests {
    @Test("Metadata filters evaluate typed values, string matching, and logical composition")
    func metadataFiltersMatchTypedValues() {
        let metadata: ChunkMetadata = [
            "category": .string("guide"),
            "path": .string("Docs/Guide.md"),
            "priority": .int(3),
            "rating": .double(4.5),
            "published": .bool(true),
            "updatedAt": .date(Date(timeIntervalSince1970: 1_700_000_000)),
        ]

        #expect(MetadataFilter.equals("priority", .int(3)).matches(metadata))
        #expect(MetadataFilter.contains("category", "gui").matches(metadata))
        #expect(MetadataFilter.startsWith("path", "docs").matches(metadata))
        #expect(MetadataFilter.endsWith("path", ".MD").matches(metadata))
        #expect(MetadataFilter.hasKey("published").matches(metadata))
        #expect(MetadataFilter.not(.equals("published", .bool(false))).matches(metadata))
        #expect(!MetadataFilter.not(.contains("category", "gui")).matches(metadata))
        #expect(!MetadataFilter.equals("priority", .int(2)).matches(metadata))
    }

    @Test("Metadata filters compare int, double, and date values with ordered predicates")
    func metadataFiltersSupportOrderedComparisons() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata: ChunkMetadata = [
            "priority": .int(3),
            "rating": .double(4.5),
            "updatedAt": .date(referenceDate),
        ]

        #expect(MetadataFilter.lessThan("priority", .int(5)).matches(metadata))
        #expect(MetadataFilter.lessThanOrEqual("priority", .double(3.0)).matches(metadata))
        #expect(MetadataFilter.greaterThan("rating", .int(4)).matches(metadata))
        #expect(MetadataFilter.greaterThanOrEqual("rating", .double(4.5)).matches(metadata))
        #expect(MetadataFilter.greaterThan("updatedAt", .date(referenceDate.addingTimeInterval(-60))).matches(metadata))
        #expect(MetadataFilter.lessThanOrEqual("updatedAt", .date(referenceDate)).matches(metadata))
        #expect(!MetadataFilter.lessThan("updatedAt", .date(referenceDate.addingTimeInterval(-60))).matches(metadata))
        #expect(!MetadataFilter.greaterThan("priority", .string("4")).matches(metadata))
    }
}

@Suite("RAGCore Embedding Vectors")
struct EmbeddingVectorTests {
    @Test("Embedding vectors normalize and compare by cosine similarity")
    func embeddingVectorNormalizationAndSimilarity() {
        let lhs = EmbeddingVector([3, 4])
        let rhs = EmbeddingVector([6, 8])

        #expect(lhs.normalized().values == [0.6, 0.8])
        #expect(abs(lhs.cosineSimilarity(to: rhs) - 1.0) < 0.000_001)
    }
}
