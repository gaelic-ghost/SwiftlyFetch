import RAGCore

public extension KnowledgeBase {
    static func hashingDefault(dimension: Int = 64) async throws -> KnowledgeBase {
        KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: HashingEmbedder(dimension: dimension),
            index: InMemoryVectorIndex()
        )
    }

    static func naturalLanguageDefault(languageHint: String? = nil) async throws -> KnowledgeBase {
        try KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: NaturalLanguageEmbedder(languageHint: languageHint),
            index: InMemoryVectorIndex()
        )
    }

    static func persistentHashingDefault(
        configuration: CoreDataVectorIndex.Configuration,
        dimension: Int = 64
    ) async throws -> KnowledgeBase {
        try await KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: HashingEmbedder(dimension: dimension),
            index: CoreDataVectorIndex(configuration: configuration)
        )
    }

    static func persistentNaturalLanguageDefault(
        configuration: CoreDataVectorIndex.Configuration,
        languageHint: String? = nil
    ) async throws -> KnowledgeBase {
        try await KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: NaturalLanguageEmbedder(languageHint: languageHint),
            index: CoreDataVectorIndex(configuration: configuration)
        )
    }
}
