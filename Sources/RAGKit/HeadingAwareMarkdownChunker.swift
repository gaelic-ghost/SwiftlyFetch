import Foundation
import RAGCore

public struct HeadingAwareMarkdownChunker: Chunker, Sendable {
    private let paragraphChunker: ParagraphChunker

    public init(paragraphChunker: ParagraphChunker = ParagraphChunker()) {
        self.paragraphChunker = paragraphChunker
    }

    public func chunks(for document: Document) throws -> [Chunk] {
        guard case .markdown(let text) = document.content else {
            return try paragraphChunker.chunks(for: document)
        }

        let sections = markdownSections(in: text)
        guard !sections.isEmpty else {
            return try paragraphChunker.chunks(for: document)
        }

        var chunks: [Chunk] = []
        var chunkIndex = 0

        for section in sections {
            let bodyText = String(text[section.bodyRange])
            let paragraphRanges = ChunkingSupport.paragraphRanges(in: bodyText)

            if paragraphRanges.isEmpty {
                continue
            }

            for localRange in paragraphRanges {
                let paragraphText = String(bodyText[localRange])
                let headingContext = section.headingPath.joined(separator: "\n")
                let chunkText = headingContext.isEmpty ? paragraphText : "\(headingContext)\n\n\(paragraphText)"

                let globalStartOffset = section.bodyRange.lowerBound.utf16Offset(in: text) + localRange.lowerBound.utf16Offset(in: bodyText)
                let globalEndOffset = section.bodyRange.lowerBound.utf16Offset(in: text) + localRange.upperBound.utf16Offset(in: bodyText)

                chunks.append(
                    Chunk(
                        id: ChunkID("\(document.id.rawValue)#\(chunkIndex)"),
                        documentID: document.id,
                        text: chunkText,
                        metadata: ChunkMetadata(inheriting: document.metadata),
                        position: ChunkPosition(
                            documentID: document.id,
                            chunkIndex: chunkIndex,
                            startOffset: globalStartOffset,
                            endOffset: globalEndOffset
                        )
                    )
                )
                chunkIndex += 1
            }
        }

        return chunks.isEmpty ? try paragraphChunker.chunks(for: document) : chunks
    }

    private func markdownSections(in text: String) -> [MarkdownSection] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let headingPattern = /^(#{1,6})\s+(.+?)\s*$/

        var markers: [HeadingMarker] = []
        var headingStack: [(level: Int, title: String)] = []

        nsText.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, substringRange, enclosingRange, _ in
            let line = nsText.substring(with: substringRange)

            guard let match = line.firstMatch(of: headingPattern) else {
                return
            }

            let level = match.1.count
            let title = String(match.2)

            headingStack.removeAll { $0.level >= level }
            headingStack.append((level: level, title: title))

            let lineStart = String.Index(utf16Offset: enclosingRange.location, in: text)
            let bodyStart = String.Index(utf16Offset: enclosingRange.location + enclosingRange.length, in: text)

            markers.append(
                HeadingMarker(
                    headingStart: lineStart,
                    bodyStart: bodyStart,
                    headingPath: headingStack.map(\.title)
                )
            )
        }

        guard !markers.isEmpty else {
            return []
        }

        var sections: [MarkdownSection] = []

        if let firstHeading = markers.first, text.startIndex < firstHeading.headingStart {
            let preambleRange = text.startIndex..<firstHeading.headingStart
            if let trimmed = ChunkingSupport.trimmedRange(in: text, range: preambleRange) {
                sections.append(MarkdownSection(headingPath: [], bodyRange: trimmed))
            }
        }

        for (index, marker) in markers.enumerated() {
            let nextHeadingStart = index + 1 < markers.count ? markers[index + 1].headingStart : text.endIndex
            guard marker.bodyStart < nextHeadingStart else {
                continue
            }

            let rawRange = marker.bodyStart..<nextHeadingStart
            guard let trimmed = ChunkingSupport.trimmedRange(in: text, range: rawRange) else {
                continue
            }

            sections.append(
                MarkdownSection(
                    headingPath: marker.headingPath,
                    bodyRange: trimmed
                )
            )
        }

        return sections
    }
}

private struct HeadingMarker {
    let headingStart: String.Index
    let bodyStart: String.Index
    let headingPath: [String]
}

private struct MarkdownSection {
    let headingPath: [String]
    let bodyRange: Range<String.Index>
}
