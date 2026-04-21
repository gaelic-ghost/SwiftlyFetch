import RAGCore

public struct DefaultChunker: Chunker, Sendable {
    private let paragraphChunker: ParagraphChunker
    private let markdownChunker: HeadingAwareMarkdownChunker

    public init(
        paragraphChunker: ParagraphChunker = ParagraphChunker(),
        markdownChunker: HeadingAwareMarkdownChunker = HeadingAwareMarkdownChunker()
    ) {
        self.paragraphChunker = paragraphChunker
        self.markdownChunker = markdownChunker
    }

    public func chunks(for document: Document) throws -> [Chunk] {
        switch document.content {
        case .text:
            return try paragraphChunker.chunks(for: document)
        case .markdown:
            return try markdownChunker.chunks(for: document)
        }
    }
}
