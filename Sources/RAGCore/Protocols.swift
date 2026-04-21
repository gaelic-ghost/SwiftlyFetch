public protocol Chunker: Sendable {
    func chunks(for document: Document) throws -> [Chunk]
}

public protocol Embedder: Sendable {
    func embed(chunks: [Chunk]) async throws -> [EmbeddingVector]
    func embed(query: SearchQuery) async throws -> EmbeddingVector
}

public protocol VectorIndex: Sendable {
    func upsert(_ chunks: [IndexedChunk]) async throws
    func search(_ query: SearchQuery, embedding: EmbeddingVector) async throws -> [SearchResult]
    func removeChunks(for documentID: DocumentID) async throws
    func removeAll() async throws
}
