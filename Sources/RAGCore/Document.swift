public enum DocumentContent: Hashable, Codable, Sendable {
    case text(String)
    case markdown(String)

    public var rawText: String {
        switch self {
        case .text(let value), .markdown(let value):
            value
        }
    }
}

public struct Document: Hashable, Codable, Sendable {
    public let id: DocumentID
    public let content: DocumentContent
    public var metadata: DocumentMetadata

    public init(
        id: DocumentID,
        content: DocumentContent,
        metadata: DocumentMetadata = DocumentMetadata()
    ) {
        self.id = id
        self.content = content
        self.metadata = metadata
    }
}
