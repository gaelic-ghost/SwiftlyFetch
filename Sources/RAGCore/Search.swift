import Foundation

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
    case startsWith(String, String)
    case endsWith(String, String)
    case lessThan(String, MetadataValue)
    case lessThanOrEqual(String, MetadataValue)
    case greaterThan(String, MetadataValue)
    case greaterThanOrEqual(String, MetadataValue)
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
        case .startsWith(let key, let prefix):
            guard case .string(let value)? = values[key] else {
                return false
            }
            return value.lowercased().hasPrefix(prefix.lowercased())
        case .endsWith(let key, let suffix):
            guard case .string(let value)? = values[key] else {
                return false
            }
            return value.lowercased().hasSuffix(suffix.lowercased())
        case .lessThan(let key, let expected):
            guard let actual = values[key], let ordering = ordering(between: actual, and: expected) else {
                return false
            }
            return ordering == .orderedAscending
        case .lessThanOrEqual(let key, let expected):
            guard let actual = values[key], let ordering = ordering(between: actual, and: expected) else {
                return false
            }
            return ordering == .orderedAscending || ordering == .orderedSame
        case .greaterThan(let key, let expected):
            guard let actual = values[key], let ordering = ordering(between: actual, and: expected) else {
                return false
            }
            return ordering == .orderedDescending
        case .greaterThanOrEqual(let key, let expected):
            guard let actual = values[key], let ordering = ordering(between: actual, and: expected) else {
                return false
            }
            return ordering == .orderedDescending || ordering == .orderedSame
        case .not(let filter):
            return !filter.matches(values)
        case .any(let filters):
            return filters.contains { $0.matches(values) }
        case .all(let filters):
            return filters.allSatisfy { $0.matches(values) }
        }
    }

    private func ordering(between lhs: MetadataValue, and rhs: MetadataValue) -> ComparisonResult? {
        if let lhsNumeric = numericValue(lhs), let rhsNumeric = numericValue(rhs) {
            if lhsNumeric < rhsNumeric {
                return .orderedAscending
            }

            if lhsNumeric > rhsNumeric {
                return .orderedDescending
            }

            return .orderedSame
        }

        if case .date(let lhsDate) = lhs, case .date(let rhsDate) = rhs {
            return lhsDate.compare(rhsDate)
        }

        return nil
    }

    private func numericValue(_ value: MetadataValue) -> Double? {
        switch value {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        default:
            return nil
        }
    }
}
