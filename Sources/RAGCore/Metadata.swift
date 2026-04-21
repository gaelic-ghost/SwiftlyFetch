import Foundation

public enum MetadataValue: Hashable, Codable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
}

public struct DocumentMetadata: Hashable, Codable, Sendable, ExpressibleByDictionaryLiteral {
    public private(set) var values: [String: MetadataValue]

    public init(_ values: [String: MetadataValue] = [:]) {
        self.values = values
    }

    public init(dictionaryLiteral elements: (String, MetadataValue)...) {
        self.values = Dictionary(uniqueKeysWithValues: elements)
    }

    public subscript(key: String) -> MetadataValue? {
        get { values[key] }
        set { values[key] = newValue }
    }

    public var isEmpty: Bool {
        values.isEmpty
    }
}

public struct ChunkMetadata: Hashable, Codable, Sendable, ExpressibleByDictionaryLiteral {
    public private(set) var values: [String: MetadataValue]

    public init(_ values: [String: MetadataValue] = [:]) {
        self.values = values
    }

    public init(dictionaryLiteral elements: (String, MetadataValue)...) {
        self.values = Dictionary(uniqueKeysWithValues: elements)
    }

    public init(inheriting documentMetadata: DocumentMetadata, overrides: [String: MetadataValue] = [:]) {
        self.values = documentMetadata.values.merging(overrides) { _, new in new }
    }

    public subscript(key: String) -> MetadataValue? {
        get { values[key] }
        set { values[key] = newValue }
    }

    public var isEmpty: Bool {
        values.isEmpty
    }
}
