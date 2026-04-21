public struct SearchQuery: Hashable, Codable, Sendable {
    public let text: String
    public let limit: Int
    public let filter: MetadataFilter?

    public init(
        _ text: String,
        limit: Int = 5,
        filter: MetadataFilter? = nil
    ) {
        self.text = text
        self.limit = max(0, limit)
        self.filter = filter
    }
}

public struct SearchResult: Hashable, Codable, Sendable {
    public let chunk: Chunk
    public let score: Double

    public init(chunk: Chunk, score: Double) {
        self.chunk = chunk
        self.score = score
    }
}

public indirect enum MetadataFilter: Hashable, Codable, Sendable {
    case hasKey(String)
    case equals(String, MetadataValue)
    case contains(String, String)
    case not(MetadataFilter)
    case any([MetadataFilter])
    case all([MetadataFilter])

    public func matches(_ metadata: DocumentMetadata) -> Bool {
        matches(metadata.values)
    }

    public func matches(_ metadata: ChunkMetadata) -> Bool {
        matches(metadata.values)
    }

    private func matches(_ values: [String: MetadataValue]) -> Bool {
        switch self {
        case .hasKey(let key):
            return values[key] != nil
        case .equals(let key, let expected):
            return values[key] == expected
        case .contains(let key, let fragment):
            guard case .string(let value)? = values[key] else {
                return false
            }
            return value.localizedCaseInsensitiveContains(fragment)
        case .not(let filter):
            return !filter.matches(values)
        case .any(let filters):
            return filters.contains { $0.matches(values) }
        case .all(let filters):
            return filters.allSatisfy { $0.matches(values) }
        }
    }
}
