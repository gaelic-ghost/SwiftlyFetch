public struct EmbeddingVector: Hashable, Codable, Sendable {
    public let values: [Double]

    public init(_ values: [Double]) {
        self.values = values
    }

    public var dimension: Int {
        values.count
    }

    public var isEmpty: Bool {
        values.isEmpty
    }

    public func normalized() -> EmbeddingVector {
        let magnitudeSquared = values.reduce(into: 0.0) { partialResult, value in
            partialResult += value * value
        }

        guard magnitudeSquared > 0 else {
            return self
        }

        let magnitude = magnitudeSquared.squareRoot()
        return EmbeddingVector(values.map { $0 / magnitude })
    }

    public func cosineSimilarity(to other: EmbeddingVector) -> Double {
        guard dimension == other.dimension, !isEmpty, !other.isEmpty else {
            return 0
        }

        let lhs = normalized().values
        let rhs = other.normalized().values
        return zip(lhs, rhs).reduce(into: 0.0) { partialResult, pair in
            partialResult += pair.0 * pair.1
        }
    }
}

public struct IndexedChunk: Hashable, Codable, Sendable {
    public let chunk: Chunk
    public let embedding: EmbeddingVector

    public init(chunk: Chunk, embedding: EmbeddingVector) {
        self.chunk = chunk
        self.embedding = embedding
    }
}
