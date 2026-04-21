import RAGCore

extension KnowledgeBase {
    public static func naturalLanguageDefault(languageHint: String? = nil) async throws -> KnowledgeBase {
        try KnowledgeBase(
            chunker: ParagraphChunker(),
            embedder: NaturalLanguageEmbedder(languageHint: languageHint),
            index: InMemoryVectorIndex()
        )
    }
}
