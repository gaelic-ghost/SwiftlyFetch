import RAGCore

public actor InMemoryVectorIndex: VectorIndex {
    private var chunksByID: [ChunkID: IndexedChunk]
    private var chunkIDsByDocumentID: [DocumentID: Set<ChunkID>]

    public init() {
        self.chunksByID = [:]
        self.chunkIDsByDocumentID = [:]
    }

    public func upsert(_ chunks: [IndexedChunk]) async throws {
        for indexedChunk in chunks {
            if let previous = chunksByID[indexedChunk.chunk.id] {
                chunkIDsByDocumentID[previous.chunk.documentID]?.remove(indexedChunk.chunk.id)
            }

            chunksByID[indexedChunk.chunk.id] = indexedChunk
            chunkIDsByDocumentID[indexedChunk.chunk.documentID, default: []].insert(indexedChunk.chunk.id)
        }
    }

    public func search(_ query: SearchQuery, embedding: EmbeddingVector) async throws -> [SearchResult] {
        let ranked = chunksByID.values.compactMap { indexedChunk -> SearchResult? in
            if let filter = query.filter, !filter.matches(indexedChunk.chunk.metadata) {
                return nil
            }

            let score = embedding.cosineSimilarity(to: indexedChunk.embedding)
            return SearchResult(chunk: indexedChunk.chunk, score: score)
        }

        return ranked
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.chunk.id.rawValue < rhs.chunk.id.rawValue
                }

                return lhs.score > rhs.score
            }
            .prefix(query.limit)
            .map { $0 }
    }

    public func removeChunks(for documentID: DocumentID) async throws {
        guard let chunkIDs = chunkIDsByDocumentID.removeValue(forKey: documentID) else {
            return
        }

        for chunkID in chunkIDs {
            chunksByID.removeValue(forKey: chunkID)
        }
    }

    public func removeAll() async throws {
        chunksByID.removeAll()
        chunkIDsByDocumentID.removeAll()
    }
}
