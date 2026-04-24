import Foundation

public enum FetchDocumentContentType: String, Hashable, Codable, Sendable {
    case plainText
    case markdown
}

public enum FetchDocumentKind: String, Hashable, Codable, Sendable {
    case note
    case article
    case reference
    case guide
    case record
}

public struct FetchDocumentRecord: Hashable, Codable, Sendable {
    public let id: FetchDocumentID
    public var title: String?
    public var body: String
    public var contentType: FetchDocumentContentType
    public var kind: FetchDocumentKind?
    public var language: String?
    public var sourceURI: String?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var metadata: [String: String]
    public var lastIndexedAt: Date?

    public init(
        id: FetchDocumentID,
        title: String? = nil,
        body: String,
        contentType: FetchDocumentContentType = .plainText,
        kind: FetchDocumentKind? = nil,
        language: String? = nil,
        sourceURI: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        metadata: [String: String] = [:],
        lastIndexedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.contentType = contentType
        self.kind = kind
        self.language = language
        self.sourceURI = sourceURI
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.lastIndexedAt = lastIndexedAt
    }

    public var searchDocument: FetchDocument {
        FetchDocument(
            id: id,
            title: title,
            body: body,
            contentType: contentType
        )
    }

    public var indexDocument: FetchIndexDocument {
        FetchIndexDocument(
            id: id,
            title: title,
            body: body,
            contentType: contentType,
            kind: kind,
            language: language,
            sourceURI: sourceURI,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata
        )
    }
}

public struct FetchDocument: Hashable, Codable, Sendable {
    public let id: FetchDocumentID
    public var title: String?
    public var body: String
    public var contentType: FetchDocumentContentType

    public init(
        id: FetchDocumentID,
        title: String? = nil,
        body: String,
        contentType: FetchDocumentContentType = .plainText
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.contentType = contentType
    }

    public init(record: FetchDocumentRecord) {
        self.init(
            id: record.id,
            title: record.title,
            body: record.body,
            contentType: record.contentType
        )
    }
}

public struct FetchIndexDocument: Hashable, Codable, Sendable {
    public let id: FetchDocumentID
    public var title: String?
    public var body: String
    public var contentType: FetchDocumentContentType
    public var kind: FetchDocumentKind?
    public var language: String?
    public var sourceURI: String?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var metadata: [String: String]

    public init(
        id: FetchDocumentID,
        title: String? = nil,
        body: String,
        contentType: FetchDocumentContentType = .plainText,
        kind: FetchDocumentKind? = nil,
        language: String? = nil,
        sourceURI: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.contentType = contentType
        self.kind = kind
        self.language = language
        self.sourceURI = sourceURI
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }

    public var searchDocument: FetchDocument {
        FetchDocument(
            id: id,
            title: title,
            body: body,
            contentType: contentType
        )
    }
}
