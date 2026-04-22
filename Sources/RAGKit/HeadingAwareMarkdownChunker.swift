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

        let sections = MarkdownChunkSectionScanner.sections(in: text)
        guard !sections.isEmpty else {
            return try paragraphChunker.chunks(for: document)
        }

        var chunks: [Chunk] = []
        var chunkIndex = 0

        for section in sections {
            let bodyText = section.bodyText
            let paragraphRanges: [Range<String.Index>]
            if section.preservesBodyAsSingleChunk {
                paragraphRanges = [bodyText.startIndex..<bodyText.endIndex]
            } else {
                paragraphRanges = ChunkingSupport.paragraphRanges(in: bodyText)
            }

            if paragraphRanges.isEmpty {
                continue
            }

            for localRange in paragraphRanges {
                let paragraphText = String(bodyText[localRange])
                let headingContext = section.headingPath.joined(separator: "\n")
                let chunkText = headingContext.isEmpty ? paragraphText : "\(headingContext)\n\n\(paragraphText)"

                let globalStartOffset = section.sourceRange.lowerBound.utf16Offset(in: text)
                let globalEndOffset = section.sourceRange.upperBound.utf16Offset(in: text)

                chunks.append(
                    Chunk(
                        id: ChunkID("\(document.id.rawValue)#\(chunkIndex)"),
                        documentID: document.id,
                        text: chunkText,
                        metadata: ChunkMetadata(
                            inheriting: document.metadata,
                            overrides: section.metadataOverrides
                        ),
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
}
