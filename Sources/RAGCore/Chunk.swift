public struct ChunkPosition: Hashable, Codable, Sendable {
    public let documentID: DocumentID
    public let chunkIndex: Int
    public let startOffset: Int
    public let endOffset: Int

    public init(
        documentID: DocumentID,
        chunkIndex: Int,
        startOffset: Int,
        endOffset: Int
    ) {
        self.documentID = documentID
        self.chunkIndex = chunkIndex
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

public struct Chunk: Hashable, Codable, Sendable {
    public let id: ChunkID
    public let documentID: DocumentID
    public let text: String
    public var metadata: ChunkMetadata
    public let position: ChunkPosition

    public init(
        id: ChunkID,
        documentID: DocumentID,
        text: String,
        metadata: ChunkMetadata = ChunkMetadata(),
        position: ChunkPosition
    ) {
        self.id = id
        self.documentID = documentID
        self.text = text
        self.metadata = metadata
        self.position = position
    }
}
