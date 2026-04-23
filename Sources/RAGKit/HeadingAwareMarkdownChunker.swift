import Foundation
import RAGCore

public enum MarkdownLinkDestinationMetadataMode: Sendable {
    case omit
    case include
}

public struct HeadingAwareMarkdownChunker: Chunker, Sendable {
    private let paragraphChunker: ParagraphChunker
    private let linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode

    public init(
        paragraphChunker: ParagraphChunker = ParagraphChunker(),
        linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode = .omit
    ) {
        self.paragraphChunker = paragraphChunker
        self.linkDestinationMetadataMode = linkDestinationMetadataMode
    }

    public func chunks(for document: Document) throws -> [Chunk] {
        guard case .markdown(let text) = document.content else {
            return try paragraphChunker.chunks(for: document)
        }

        let scanResult = MarkdownChunkSectionScanner.scan(
            in: text,
            linkDestinationMetadataMode: linkDestinationMetadataMode
        )
        let sections = scanResult.sections
        guard !sections.isEmpty else {
            guard scanResult.shouldFallbackToParagraphChunker else {
                return []
            }
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

        if chunks.isEmpty {
            return scanResult.shouldFallbackToParagraphChunker
                ? try paragraphChunker.chunks(for: document)
                : []
        }

        return chunks
    }
}
