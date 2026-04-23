import Foundation

public enum FetchDocumentContentType: String, Hashable, Codable, Sendable {
    case plainText
    case markdown
}

public struct FetchDocumentRecord: Hashable, Codable, Sendable {
    public let id: FetchDocumentID
    public var title: String?
    public var body: String
    public var contentType: FetchDocumentContentType
    public var sourceURI: String?
    public var metadata: [String: String]
    public var lastIndexedAt: Date?

    public init(
        id: FetchDocumentID,
        title: String? = nil,
        body: String,
        contentType: FetchDocumentContentType = .plainText,
        sourceURI: String? = nil,
        metadata: [String: String] = [:],
        lastIndexedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.contentType = contentType
        self.sourceURI = sourceURI
        self.metadata = metadata
        self.lastIndexedAt = lastIndexedAt
    }

    public var indexableDocument: FetchDocument {
        FetchDocument(
            id: id,
            title: title,
            body: body,
            contentType: contentType
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
