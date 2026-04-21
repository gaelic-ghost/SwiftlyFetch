import RAGCore

extension KnowledgeBase {
    public static func hashingDefault(dimension: Int = 64) async throws -> KnowledgeBase {
        KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: HashingEmbedder(dimension: dimension),
            index: InMemoryVectorIndex()
        )
    }

    public static func naturalLanguageDefault(languageHint: String? = nil) async throws -> KnowledgeBase {
        try KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: NaturalLanguageEmbedder(languageHint: languageHint),
            index: InMemoryVectorIndex()
        )
    }
}
