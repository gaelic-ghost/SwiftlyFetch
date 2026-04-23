import Foundation
import Markdown
import RAGCore

struct MarkdownChunkSection {
    let headingPath: [String]
    let bodyText: String
    let sourceRange: Range<String.Index>
    let preservesBodyAsSingleChunk: Bool
    let metadataOverrides: [String: MetadataValue]
}

enum MarkdownChunkSectionScanner {
    private static let blockQuotePromotionThreshold = 1.0 / 3.0

    static func sections(
        in text: String,
        linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode = .omit
    ) -> [MarkdownChunkSection] {
        var collector = MarkdownSectionCollector(
            source: text,
            linkDestinationMetadataMode: linkDestinationMetadataMode
        )
        let document = Markdown.Document(parsing: text)
        collector.visit(document)
        return promotedSections(from: collector.sections)
    }

    private static func promotedSections(from sections: [MarkdownChunkSectionCandidate]) -> [MarkdownChunkSection] {
        let primaryBlockCount = sections.filter { $0.blockKind != .blockQuote }.count
        let quoteBlockCount = sections.filter { $0.blockKind == .blockQuote }.count
        let totalChunkableBlockCount = primaryBlockCount + quoteBlockCount

        guard totalChunkableBlockCount > 0 else {
            return []
        }

        let quoteProportion = Double(quoteBlockCount) / Double(totalChunkableBlockCount)
        let promoteBlockQuotes = quoteProportion > blockQuotePromotionThreshold

        return sections.compactMap { section in
            if section.blockKind == .blockQuote, !promoteBlockQuotes {
                return nil
            }
            return section.withoutBlockKind()
        }
    }
}

private struct MarkdownSectionCollector: MarkupWalker {
    let source: String
    private let sourceMap: MarkdownSourceMap
    private let linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode
    fileprivate private(set) var sections: [MarkdownChunkSectionCandidate] = []
    private var headingPath: [(level: Int, title: String)] = []
    private var lastLeadInParagraphByHeadingPath: [[String]: String] = [:]

    init(
        source: String,
        linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode
    ) {
        self.source = source
        self.sourceMap = MarkdownSourceMap(source: source)
        self.linkDestinationMetadataMode = linkDestinationMetadataMode
    }

    mutating func visitHeading(_ heading: Heading) {
        let title = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return
        }

        headingPath.removeAll { $0.level >= heading.level }
        headingPath.append((level: heading.level, title: title))
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        let bodyText = paragraph.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bodyText.isEmpty else {
            return
        }

        guard let sourceRange = paragraph.range.flatMap(sourceMap.range(for:)) else {
            return
        }

        let insideBlockQuote = isInsideBlockQuote(paragraph)

        if let listContext = listContext(for: paragraph) {
            let itemText = (listContext.itemPrefix ?? "") + bodyText
            let combinedBodyText = [listContext.leadInText, itemText]
                .compactMap { text in
                    guard let text, !text.isEmpty else {
                        return nil
                    }
                    return text
                }
                .joined(separator: "\n\n")

            sections.append(
                MarkdownChunkSectionCandidate(
                    headingPath: headingPath.map(\.title),
                    bodyText: combinedBodyText,
                    sourceRange: sourceRange,
                    preservesBodyAsSingleChunk: true,
                    blockKind: insideBlockQuote ? .blockQuote : .listItem,
                    metadataOverrides: metadataByAddingLinkDestinations(
                        to: listContext.metadataOverrides,
                        from: paragraph
                    )
                )
            )
            return
        }

        sections.append(
            MarkdownChunkSectionCandidate(
                headingPath: headingPath.map(\.title),
                bodyText: bodyText,
                sourceRange: sourceRange,
                preservesBodyAsSingleChunk: false,
                blockKind: insideBlockQuote ? .blockQuote : .paragraph,
                metadataOverrides: metadataByAddingLinkDestinations(
                    to: [:],
                    from: paragraph
                )
            )
        )

        if !insideBlockQuote {
            lastLeadInParagraphByHeadingPath[headingPath.map(\.title)] = bodyText
        }
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {}

    mutating func visitTable(_ table: Table) {
        let headers = Array(table.head.cells.map {
            $0.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        })

        for (rowIndex, row) in table.body.rows.enumerated() {
            guard let sourceRange = row.range.flatMap(sourceMap.range(for:)) else {
                continue
            }

            let cells = Array(row.cells)
            var renderedColumns: [String] = []

            for (index, cell) in cells.enumerated() {
                let value = cell.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else {
                    continue
                }

                let header = index < headers.count ? headers[index] : ""
                if header.isEmpty {
                    renderedColumns.append(value)
                } else {
                    renderedColumns.append("\(header): \(value)")
                }
            }

            let bodyText = renderedColumns.joined(separator: "\n")
            guard !bodyText.isEmpty else {
                continue
            }

            var metadata: [String: MetadataValue] = [
                "rag.blockKind": .string("tableRow"),
                "rag.tableRowIndex": .int(rowIndex),
            ]

            let nonEmptyHeaders = headers.filter { !$0.isEmpty }
            if !nonEmptyHeaders.isEmpty {
                metadata["rag.tableHeaders"] = .string(nonEmptyHeaders.joined(separator: " | "))
            }

            let headingTitles = headingPath.map(\.title)
            if !headingTitles.isEmpty {
                metadata["rag.headingPath"] = .string(headingTitles.joined(separator: " > "))
            }

            sections.append(
                MarkdownChunkSectionCandidate(
                    headingPath: headingTitles,
                    bodyText: bodyText,
                    sourceRange: sourceRange,
                    preservesBodyAsSingleChunk: true,
                    blockKind: .tableRow,
                    metadataOverrides: metadata
                )
            )
        }
    }

    private func listContext(for paragraph: Paragraph) -> ListContext? {
        guard let listItem = ancestor(of: paragraph, as: ListItem.self) else {
            return nil
        }

        let currentHeadingPath = headingPath.map(\.title)
        let leadInText = previousSiblingParagraph(for: listItem)?.plainText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? lastLeadInParagraphByHeadingPath[currentHeadingPath]

        if let orderedList = listItem.parent as? OrderedList {
            let ordinal = Int(orderedList.startIndex) + listItem.indexInParent
            return ListContext(
                leadInText: leadInText,
                itemPrefix: "\(ordinal). ",
                metadataOverrides: listMetadata(
                    leadInText: leadInText,
                    kind: "ordered",
                    ordinal: ordinal
                )
            )
        }

        return ListContext(
            leadInText: leadInText,
            itemPrefix: nil,
            metadataOverrides: listMetadata(
                leadInText: leadInText,
                kind: "unordered",
                ordinal: nil
            )
        )
    }

    private func listMetadata(
        leadInText: String?,
        kind: String,
        ordinal: Int?
    ) -> [String: MetadataValue] {
        var metadata: [String: MetadataValue] = [
            "rag.blockKind": .string("listItem"),
            "rag.listKind": .string(kind),
        ]

        if let leadInText, !leadInText.isEmpty {
            metadata["rag.listLeadIn"] = .string(leadInText)
        }

        if let ordinal {
            metadata["rag.listOrdinal"] = .int(ordinal)
        }

        let headingTitles = headingPath.map(\.title)
        if !headingTitles.isEmpty {
            metadata["rag.headingPath"] = .string(headingTitles.joined(separator: " > "))
        }

        return metadata
    }

    private func metadataByAddingLinkDestinations(
        to metadata: [String: MetadataValue],
        from markup: Markup
    ) -> [String: MetadataValue] {
        guard linkDestinationMetadataMode == .include else {
            return metadata
        }

        let destinations = linkDestinations(in: markup)
        guard !destinations.isEmpty else {
            return metadata
        }

        var updatedMetadata = metadata
        updatedMetadata["rag.linkDestinationCount"] = .int(destinations.count)
        updatedMetadata["rag.linkDestinations"] = .string(destinations.joined(separator: "\n"))
        return updatedMetadata
    }

    private func linkDestinations(in markup: Markup) -> [String] {
        var collector = LinkDestinationCollector()
        collector.visit(markup)
        return collector.destinations
    }

    private func previousSiblingParagraph(for markup: Markup) -> Paragraph? {
        guard let parent = markup.parent, markup.indexInParent > 0 else {
            return nil
        }

        return parent.child(at: markup.indexInParent - 1) as? Paragraph
    }

    private func isInsideBlockQuote(_ markup: Markup) -> Bool {
        ancestor(of: markup, as: BlockQuote.self) != nil
    }

    private func ancestor<T: Markup>(of markup: Markup, as _: T.Type) -> T? {
        var current = markup.parent
        while let node = current {
            if let typed = node as? T {
                return typed
            }
            current = node.parent
        }
        return nil
    }
}

private struct ListContext {
    let leadInText: String?
    let itemPrefix: String?
    let metadataOverrides: [String: MetadataValue]
}

private struct LinkDestinationCollector: MarkupWalker {
    fileprivate private(set) var destinations: [String] = []
    private var seenDestinations: Set<String> = []

    mutating func visitLink(_ link: Link) {
        let destination = link.destination?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !destination.isEmpty, !seenDestinations.contains(destination) else {
            descendInto(link)
            return
        }

        destinations.append(destination)
        seenDestinations.insert(destination)
        descendInto(link)
    }
}

private enum MarkdownBlockKind {
    case paragraph
    case listItem
    case blockQuote
    case tableRow
}

private struct MarkdownChunkSectionCandidate {
    let headingPath: [String]
    let bodyText: String
    let sourceRange: Range<String.Index>
    let preservesBodyAsSingleChunk: Bool
    let blockKind: MarkdownBlockKind
    let metadataOverrides: [String: MetadataValue]

    func withoutBlockKind() -> MarkdownChunkSection {
        var mergedMetadata = metadataOverrides
        if mergedMetadata["rag.blockKind"] == nil {
            switch blockKind {
            case .paragraph:
                mergedMetadata["rag.blockKind"] = .string("paragraph")
            case .listItem:
                mergedMetadata["rag.blockKind"] = .string("listItem")
            case .blockQuote:
                mergedMetadata["rag.blockKind"] = .string("blockQuote")
            case .tableRow:
                mergedMetadata["rag.blockKind"] = .string("tableRow")
            }
        }

        if !headingPath.isEmpty, mergedMetadata["rag.headingPath"] == nil {
            mergedMetadata["rag.headingPath"] = .string(headingPath.joined(separator: " > "))
        }

        return MarkdownChunkSection(
            headingPath: headingPath,
            bodyText: bodyText,
            sourceRange: sourceRange,
            preservesBodyAsSingleChunk: preservesBodyAsSingleChunk,
            metadataOverrides: mergedMetadata
        )
    }
}

private struct MarkdownSourceMap {
    let source: String
    let lineStarts: [String.Index]

    init(source: String) {
        self.source = source

        var starts: [String.Index] = [source.startIndex]
        var cursor = source.startIndex
        while cursor < source.endIndex {
            if source[cursor] == "\n" {
                let next = source.index(after: cursor)
                if next <= source.endIndex {
                    starts.append(next)
                }
            }
            cursor = source.index(after: cursor)
        }
        self.lineStarts = starts
    }

    func range(for sourceRange: SourceRange) -> Range<String.Index>? {
        guard let lowerBound = index(for: sourceRange.lowerBound),
              let upperBound = index(for: sourceRange.upperBound),
              lowerBound <= upperBound
        else {
            return nil
        }

        return lowerBound..<upperBound
    }

    private func index(for location: SourceLocation) -> String.Index? {
        let lineIndex = location.line - 1
        guard lineIndex >= 0, lineIndex < lineStarts.count else {
            return nil
        }

        let lineStart = lineStarts[lineIndex]
        let utf8Start = lineStart.samePosition(in: source.utf8) ?? source.utf8.startIndex
        let utf8Offset = max(0, location.column - 1)
        guard let utf8Index = source.utf8.index(utf8Start, offsetBy: utf8Offset, limitedBy: source.utf8.endIndex),
              let stringIndex = String.Index(utf8Index, within: source)
        else {
            return nil
        }

        return stringIndex
    }
}
