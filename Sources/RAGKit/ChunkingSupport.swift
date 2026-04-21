import Foundation

enum ChunkingSupport {
    static func paragraphRanges(in text: String) -> [Range<String.Index>] {
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
            if let trimmedRange = trimmedRange(in: text, range: rawRange) {
                ranges.append(trimmedRange)
            }

            index = cursor
        }

        return ranges
    }

    static func trimmedRange(in text: String, range: Range<String.Index>) -> Range<String.Index>? {
        let trimmedLowerBound = text[range].firstIndex(where: { !$0.isWhitespace }) ?? range.lowerBound
        let trimmedUpperBound = text[range].lastIndex(where: { !$0.isWhitespace }).map { text.index(after: $0) } ?? range.upperBound

        guard trimmedLowerBound < trimmedUpperBound else {
            return nil
        }

        return trimmedLowerBound..<trimmedUpperBound
    }
}
