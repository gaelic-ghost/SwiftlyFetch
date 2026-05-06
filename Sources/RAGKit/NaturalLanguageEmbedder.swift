import RAGCore

public struct NaturalLanguageEmbedder: Embedder, Sendable {
    let languageHint: String?
    private let backend: any ContextualEmbeddingBackend

    public init(languageHint: String? = nil) throws {
        self.languageHint = languageHint
        backend = try AppleContextualEmbeddingBackend(languageHint: languageHint)
    }

    init(backend: any ContextualEmbeddingBackend) {
        languageHint = nil
        self.backend = backend
    }

    public func embed(chunks: [Chunk]) async throws -> [EmbeddingVector] {
        var embeddings: [EmbeddingVector] = []
        embeddings.reserveCapacity(chunks.count)

        for chunk in chunks {
            let embedding = try await backend.embed(text: chunk.text)
            embeddings.append(embedding)
        }

        return embeddings
    }

    public func embed(query: SearchQuery) async throws -> EmbeddingVector {
        try await backend.embed(text: query.text)
    }
}
