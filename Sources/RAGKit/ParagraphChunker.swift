import Foundation
import RAGCore

public struct ParagraphChunker: Chunker, Sendable {
    public init() {}

    public func chunks(for document: Document) throws -> [Chunk] {
        let text = document.content.rawText
        let paragraphs = ChunkingSupport.paragraphRanges(in: text)

        return paragraphs.enumerated().map { index, range in
            let paragraphText = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let position = ChunkPosition(
                documentID: document.id,
                chunkIndex: index,
                startOffset: range.lowerBound.utf16Offset(in: text),
                endOffset: range.upperBound.utf16Offset(in: text)
            )

            return Chunk(
                id: ChunkID("\(document.id.rawValue)#\(index)"),
                documentID: document.id,
                text: paragraphText,
                metadata: ChunkMetadata(inheriting: document.metadata),
                position: position
            )
        }
    }
}
