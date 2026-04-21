import Foundation
import RAGCore

public struct HashingEmbedder: Embedder, Sendable {
    public let dimension: Int

    public init(dimension: Int = 64) {
        self.dimension = max(1, dimension)
    }

    public func embed(chunks: [Chunk]) async throws -> [EmbeddingVector] {
        chunks.map { embedding(for: $0.text) }
    }

    public func embed(query: SearchQuery) async throws -> EmbeddingVector {
        embedding(for: query.text)
    }

    private func embedding(for text: String) -> EmbeddingVector {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else {
            return EmbeddingVector(Array(repeating: 0, count: dimension))
        }

        var values = Array(repeating: 0.0, count: dimension)

        for token in tokens {
            let hash = fnv1a64(token)
            let bucket = Int(hash % UInt64(dimension))
            let sign = (hash & 1) == 0 ? 1.0 : -1.0
            values[bucket] += sign
        }

        return EmbeddingVector(values).normalized()
    }

    private func tokenize(_ text: String) -> [Substring] {
        let lowercased = text.lowercased()
        let pieces = lowercased.split { character in
            !character.isLetter && !character.isNumber
        }

        if pieces.isEmpty, !lowercased.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [Substring(lowercased)]
        }

        return pieces
    }

    private func fnv1a64<S: StringProtocol>(_ text: S) -> UInt64 {
        let offsetBasis: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        return text.utf8.reduce(offsetBasis) { partialResult, byte in
            (partialResult ^ UInt64(byte)) &* prime
        }
    }
}
