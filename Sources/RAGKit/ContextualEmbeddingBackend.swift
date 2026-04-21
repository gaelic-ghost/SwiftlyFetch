import RAGCore

protocol ContextualEmbeddingBackend: Sendable {
    func embed(text: String) async throws -> EmbeddingVector
}
