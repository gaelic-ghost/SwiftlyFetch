import Foundation
import RAGCore

public struct ParagraphChunker: Chunker, Sendable {
    public init() {}

    public func chunks(for document: Document) throws -> [Chunk] {
        let text = document.content.rawText
        let paragraphs = paragraphRanges(in: text)

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

    private func paragraphRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var index = text.startIndex

        while index < text.endIndex {
            while index < text.endIndex, text[index].isWhitespace {
                index = text.index(after: index)
            }

            guard index < text.endIndex else {
                break
            }

            let paragraphStart = index
            var paragraphEnd = text.endIndex
            var cursor = index

            while cursor < text.endIndex {
                guard let newlineIndex = text[cursor...].firstIndex(of: "\n") else {
                    paragraphEnd = text.endIndex
                    cursor = text.endIndex
                    break
                }

                let lineEnd = newlineIndex
                let nextLineStart = text.index(after: newlineIndex)

                if nextLineStart == text.endIndex {
                    paragraphEnd = lineEnd
                    cursor = nextLineStart
                    break
                }

                let secondLineEnd = text[nextLineStart...].firstIndex(of: "\n") ?? text.endIndex
                let blankLine = text[nextLineStart..<secondLineEnd].allSatisfy(\.isWhitespace)

                if blankLine {
                    paragraphEnd = lineEnd
                    cursor = secondLineEnd
                    break
                }

                cursor = nextLineStart
                paragraphEnd = text.endIndex
            }

            let rawRange = paragraphStart..<paragraphEnd
            let trimmedLowerBound = text[rawRange].firstIndex(where: { !$0.isWhitespace }) ?? rawRange.lowerBound
            let trimmedUpperBound = text[rawRange].lastIndex(where: { !$0.isWhitespace }).map { text.index(after: $0) } ?? rawRange.upperBound

            if trimmedLowerBound < trimmedUpperBound {
                ranges.append(trimmedLowerBound..<trimmedUpperBound)
            }

            index = cursor
        }

        return ranges
    }
}
