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

struct MarkdownChunkScanResult {
    let sections: [MarkdownChunkSection]
    let shouldFallbackToParagraphChunker: Bool
}

enum MarkdownChunkSectionScanner {
    private static let blockQuotePromotionThreshold = 1.0 / 3.0
    private static let codeBlockPromotionThreshold = 1.0 / 3.0

    static func scan(
        in text: String,
        linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode = .omit
    ) -> MarkdownChunkScanResult {
        var collector = MarkdownSectionCollector(
            source: text,
            linkDestinationMetadataMode: linkDestinationMetadataMode
        )
        let document = Markdown.Document(parsing: text)
        collector.visit(document)
        let sections = promotedSections(from: collector.sections)

        return MarkdownChunkScanResult(
            sections: sections,
            shouldFallbackToParagraphChunker: shouldFallbackToParagraphChunker(
                for: text,
                collector: collector,
                sections: sections
            )
        )
    }

    static func sections(
        in text: String,
        linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode = .omit
    ) -> [MarkdownChunkSection] {
        scan(
            in: text,
            linkDestinationMetadataMode: linkDestinationMetadataMode
        ).sections
    }

    private static func promotedSections(from sections: [MarkdownChunkSectionCandidate]) -> [MarkdownChunkSection] {
        let primaryBlockCount = sections.filter { $0.blockKind != .blockQuote }.count
        let quoteBlockCount = sections.filter { $0.blockKind == .blockQuote }.count
        let codeBlockCount = sections.filter { $0.blockKind == .codeBlock }.count
        let totalChunkableBlockCount = primaryBlockCount + quoteBlockCount

        guard totalChunkableBlockCount > 0 else {
            return []
        }

        let quoteProportion = Double(quoteBlockCount) / Double(totalChunkableBlockCount)
        let promoteBlockQuotes = quoteProportion > blockQuotePromotionThreshold
        let codeBlockProportion = Double(codeBlockCount) / Double(totalChunkableBlockCount)
        let promoteCodeBlocks = codeBlockProportion > codeBlockPromotionThreshold
        let documentMetadataOverrides = documentMetadataOverrides(from: sections)

        return sections.compactMap { section in
            if section.blockKind == .blockQuote, !promoteBlockQuotes {
                return nil
            }
            if section.blockKind == .codeBlock, !promoteCodeBlocks {
                return nil
            }
            return section.withoutBlockKind(documentMetadataOverrides: documentMetadataOverrides)
        }
    }

    private static func documentMetadataOverrides(
        from sections: [MarkdownChunkSectionCandidate]
    ) -> [String: MetadataValue] {
        let codeLanguages = Set<String>(
            sections.compactMap { section in
                guard case .codeBlock = section.blockKind,
                      let language = section.metadataOverrides["rag.codeLanguage"],
                      case .string(let rawLanguage) = language
                else {
                    return nil
                }

                let normalized = rawLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
                return normalized.isEmpty ? nil : normalized
            }
        )
        .sorted()

        guard !codeLanguages.isEmpty else {
            return [:]
        }

        return [
            "rag.hasCodeBlocks": .bool(true),
            "rag.codeBlockLanguageCount": .int(codeLanguages.count),
            "rag.codeBlockLanguages": .string(codeLanguages.joined(separator: " | ")),
        ]
    }

    private static func shouldFallbackToParagraphChunker(
        for text: String,
        collector: MarkdownSectionCollector,
        sections: [MarkdownChunkSection]
    ) -> Bool {
        guard sections.isEmpty else {
            return false
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return false
        }

        if collector.sawRecognizedMarkdownStructure || collector.sawPolicyRejectedContent {
            return false
        }

        if containsStandaloneReferenceDefinitions(in: text) {
            return false
        }

        return true
    }

    private static func containsStandaloneReferenceDefinitions(in text: String) -> Bool {
        text.range(
            of: #"(?m)^\s{0,3}\[[^\]]+\]:\s+\S+"#,
            options: .regularExpression
        ) != nil
    }
}

private struct MarkdownSectionCollector: MarkupWalker {
    let source: String
    private let sourceMap: MarkdownSourceMap
    private let linkDestinationMetadataMode: MarkdownLinkDestinationMetadataMode
    fileprivate private(set) var sections: [MarkdownChunkSectionCandidate] = []
    fileprivate private(set) var sawRecognizedMarkdownStructure = false
    fileprivate private(set) var sawPolicyRejectedContent = false
    private var headingPath: [(level: Int, title: String)] = []
    private var lastLeadInParagraphByHeadingPath: [[String]: String] = [:]
    private var pendingSectionLeadInByHeadingPath: [[String]: String] = [:]

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

        sawRecognizedMarkdownStructure = true
        headingPath.removeAll { $0.level >= heading.level }
        headingPath.append((level: heading.level, title: title))
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if isUnsupportedRawHTMLParagraph(paragraph) {
            sawPolicyRejectedContent = true
            return
        }

        let paragraphText = renderedInlineText(for: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !paragraphText.isEmpty else {
            return
        }

        guard let sourceRange = paragraph.range.flatMap(sourceMap.range(for:)) else {
            return
        }

        let currentHeadingPath = headingPath.map(\.title)
        let insideBlockQuote = isInsideBlockQuote(paragraph)
        let sectionLeadIn = consumePendingSectionLeadIn(for: currentHeadingPath)
        let bodyText = combinedBodyText(
            leadInText: sectionLeadIn,
            bodyText: paragraphText
        )
        let paragraphMetadata = paragraphMetadata(
            headingTitles: currentHeadingPath,
            sectionLeadIn: sectionLeadIn
        )

        if let listContext = listContext(for: paragraph) {
            let itemText = (listContext.itemPrefix ?? "") + bodyText
            let combinedBodyText = combinedBodyText(
                leadInText: listContext.leadInText,
                bodyText: itemText
            )

            sections.append(
                MarkdownChunkSectionCandidate(
                    headingPath: currentHeadingPath,
                    bodyText: combinedBodyText,
                    sourceRange: sourceRange,
                    preservesBodyAsSingleChunk: true,
                    blockKind: insideBlockQuote ? .blockQuote : .listItem,
                    metadataOverrides: enrichedInlineMetadata(
                        baseMetadata: listContext.metadataOverrides,
                        markup: paragraph
                    )
                )
            )
            return
        }

        sections.append(
            MarkdownChunkSectionCandidate(
                headingPath: currentHeadingPath,
                bodyText: bodyText,
                sourceRange: sourceRange,
                preservesBodyAsSingleChunk: sectionLeadIn != nil,
                blockKind: insideBlockQuote ? .blockQuote : .paragraph,
                metadataOverrides: enrichedInlineMetadata(
                    baseMetadata: paragraphMetadata,
                    markup: paragraph
                )
            )
        )

        if !insideBlockQuote {
            lastLeadInParagraphByHeadingPath[currentHeadingPath] = paragraphText
        }
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let rawCode = codeBlock.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawCode.isEmpty,
              let sourceRange = codeBlock.range.flatMap(sourceMap.range(for:))
        else {
            return
        }

        sawRecognizedMarkdownStructure = true
        let currentHeadingPath = headingPath.map(\.title)
        let sectionLeadIn = consumePendingSectionLeadIn(for: currentHeadingPath)
        let normalizedLanguage = normalizedCodeLanguage(codeBlock.language)
        let codeText: String
        if let normalizedLanguage {
            codeText = "Language: \(normalizedLanguage)\n\n\(rawCode)"
        } else {
            codeText = rawCode
        }

        let bodyText = combinedBodyText(
            leadInText: sectionLeadIn,
            bodyText: codeText
        )

        var metadata: [String: MetadataValue] = [
            "rag.blockKind": .string("codeBlock"),
        ]
        if let normalizedLanguage {
            metadata["rag.codeLanguage"] = .string(normalizedLanguage)
        }
        if let sectionLeadIn {
            metadata["rag.sectionLeadIn"] = .string(sectionLeadIn)
        }
        if !currentHeadingPath.isEmpty {
            metadata["rag.headingPath"] = .string(currentHeadingPath.joined(separator: " > "))
        }

        sections.append(
            MarkdownChunkSectionCandidate(
                headingPath: currentHeadingPath,
                bodyText: bodyText,
                sourceRange: sourceRange,
                preservesBodyAsSingleChunk: true,
                blockKind: .codeBlock,
                metadataOverrides: metadata
            )
        )
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        sawRecognizedMarkdownStructure = true
        let currentHeadingPath = headingPath.map(\.title)
        guard let sectionLeadIn = sectionLeadInCandidate(for: currentHeadingPath) else {
            return
        }

        pendingSectionLeadInByHeadingPath[currentHeadingPath] = sectionLeadIn
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) {
        let rawHTML = htmlBlock.rawHTML.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawHTML.isEmpty,
              let sourceRange = htmlBlock.range.flatMap(sourceMap.range(for:))
        else {
            return
        }

        guard let htmlMetadata = htmlMetadata(for: rawHTML) else {
            sawPolicyRejectedContent = true
            return
        }

        sawRecognizedMarkdownStructure = true
        let currentHeadingPath = headingPath.map(\.title)
        let sectionLeadIn = consumePendingSectionLeadIn(for: currentHeadingPath)
        let bodyText = combinedBodyText(
            leadInText: sectionLeadIn,
            bodyText: htmlMetadata.bodyText
        )
        guard !bodyText.isEmpty else {
            return
        }

        var metadata = htmlMetadata.metadataOverrides
        if let sectionLeadIn {
            metadata["rag.sectionLeadIn"] = .string(sectionLeadIn)
        }
        if !currentHeadingPath.isEmpty {
            metadata["rag.headingPath"] = .string(currentHeadingPath.joined(separator: " > "))
        }

        sections.append(
            MarkdownChunkSectionCandidate(
                headingPath: currentHeadingPath,
                bodyText: bodyText,
                sourceRange: sourceRange,
                preservesBodyAsSingleChunk: true,
                blockKind: .paragraph,
                metadataOverrides: metadata
            )
        )
    }

    mutating func visitTable(_ table: Table) {
        sawRecognizedMarkdownStructure = true
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

    private func paragraphMetadata(
        headingTitles: [String],
        sectionLeadIn: String?
    ) -> [String: MetadataValue] {
        var metadata: [String: MetadataValue] = [:]

        if let sectionLeadIn {
            metadata["rag.sectionLeadIn"] = .string(sectionLeadIn)
        }

        if !headingTitles.isEmpty {
            metadata["rag.headingPath"] = .string(headingTitles.joined(separator: " > "))
        }

        return metadata
    }

    private mutating func consumePendingSectionLeadIn(for headingPath: [String]) -> String? {
        let leadIn = pendingSectionLeadInByHeadingPath[headingPath]
        pendingSectionLeadInByHeadingPath[headingPath] = nil
        return leadIn
    }

    private func sectionLeadInCandidate(for headingPath: [String]) -> String? {
        guard let lastLeadIn = lastLeadInParagraphByHeadingPath[headingPath] else {
            return nil
        }

        let trimmedLeadIn = lastLeadIn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLeadIn.isEmpty,
              isShortSectionLeadIn(trimmedLeadIn)
        else {
            return nil
        }

        return trimmedLeadIn
    }

    private func isShortSectionLeadIn(_ text: String) -> Bool {
        text.count <= 80 && !text.contains("\n")
    }

    private func combinedBodyText(
        leadInText: String?,
        bodyText: String
    ) -> String {
        [leadInText, bodyText]
            .compactMap { text in
                guard let text, !text.isEmpty else {
                    return nil
                }
                return text
            }
            .joined(separator: "\n\n")
    }

    private func normalizedCodeLanguage(_ language: String?) -> String? {
        guard let language else {
            return nil
        }

        let normalizedLanguage = language.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLanguage.isEmpty
        else {
            return nil
        }

        return normalizedLanguage.lowercased()
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

    private func enrichedInlineMetadata(
        baseMetadata: [String: MetadataValue],
        markup: Markup
    ) -> [String: MetadataValue] {
        let withLinks = metadataByAddingLinkDestinations(
            to: baseMetadata,
            from: markup
        )
        return metadataByAddingImageReferences(
            to: withLinks,
            from: markup
        )
    }

    private func metadataByAddingImageReferences(
        to metadata: [String: MetadataValue],
        from markup: Markup
    ) -> [String: MetadataValue] {
        let references = imageReferences(in: markup)
        guard !references.isEmpty else {
            return metadata
        }

        let sources = references.compactMap(\.source)
        let uniqueSources = Array(Set(sources)).sorted()
        let altTexts = references.compactMap(\.altText).filter { !$0.isEmpty }
        let titles = references.compactMap(\.title).filter { !$0.isEmpty }

        var updatedMetadata = metadata
        updatedMetadata["rag.hasImages"] = .bool(true)
        updatedMetadata["rag.imageReferenceCount"] = .int(references.count)
        if !uniqueSources.isEmpty {
            updatedMetadata["rag.imageSourceCount"] = .int(uniqueSources.count)
            updatedMetadata["rag.imageSources"] = .string(uniqueSources.joined(separator: "\n"))
        }
        if !altTexts.isEmpty {
            updatedMetadata["rag.imageAltTexts"] = .string(altTexts.joined(separator: "\n"))
        }
        if !titles.isEmpty {
            updatedMetadata["rag.imageTitles"] = .string(titles.joined(separator: "\n"))
        }
        return updatedMetadata
    }

    private func imageReferences(in markup: Markup) -> [ImageReference] {
        var collector = ImageReferenceCollector()
        collector.visit(markup)
        return collector.references
    }

    private func renderedInlineText(for markup: Markup) -> String {
        var collector = InlineTextCollector()
        collector.visit(markup)
        return collector.renderedText
    }

    private func isUnsupportedRawHTMLParagraph(_ paragraph: Paragraph) -> Bool {
        let rawParagraph = paragraph.format().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawParagraph.isEmpty,
              rawParagraph.hasPrefix("<"),
              rawParagraph.hasSuffix(">")
        else {
            return false
        }

        if htmlMetadata(for: rawParagraph) != nil {
            return false
        }

        return rawParagraph.range(of: #"^<([A-Za-z][A-Za-z0-9-]*)(\s[^>]*)?>.*</\1>$"#, options: .regularExpression) != nil
            || rawParagraph.range(of: #"^<([A-Za-z][A-Za-z0-9-]*)(\s[^>]*)?/\s*>$"#, options: .regularExpression) != nil
    }

    private func htmlMetadata(for rawHTML: String) -> HTMLMetadata? {
        if let imageReference = imageReference(fromHTMLImage: rawHTML) {
            let bodyText = [imageReference.altText, imageReference.title]
                .compactMap { text in
                    guard let text, !text.isEmpty else { return nil }
                    return text
                }
                .joined(separator: "\n\n")

            guard !bodyText.isEmpty else {
                return nil
            }

            var metadata: [String: MetadataValue] = [
                "rag.blockKind": .string("image"),
                "rag.hasImages": .bool(true),
                "rag.imageReferenceCount": .int(1),
            ]
            if let source = imageReference.source {
                metadata["rag.imageSourceCount"] = .int(1)
                metadata["rag.imageSources"] = .string(source)
            }
            if let altText = imageReference.altText, !altText.isEmpty {
                metadata["rag.imageAltTexts"] = .string(altText)
            }
            if let title = imageReference.title, !title.isEmpty {
                metadata["rag.imageTitles"] = .string(title)
            }

            return HTMLMetadata(bodyText: bodyText, metadataOverrides: metadata)
        }

        if let detailsMetadata = detailsMetadata(fromHTMLDetails: rawHTML) {
            return detailsMetadata
        }

        return nil
    }

    private func imageReference(fromHTMLImage rawHTML: String) -> ImageReference? {
        guard rawHTML.range(of: "<img", options: .caseInsensitive) != nil else {
            return nil
        }

        return ImageReference(
            source: htmlAttributeValue("src", in: rawHTML),
            title: htmlAttributeValue("title", in: rawHTML),
            altText: htmlAttributeValue("alt", in: rawHTML)
        )
    }

    private func detailsMetadata(fromHTMLDetails rawHTML: String) -> HTMLMetadata? {
        guard rawHTML.range(of: "<details", options: .caseInsensitive) != nil else {
            return nil
        }

        let summaryText = htmlFirstTagContents("summary", in: rawHTML)?
            .strippingHTMLTags()
            .collapsingWhitespace()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let detailsBody = rawHTML
            .removingHTMLTagBlock("summary")
            .strippingHTMLTags()
            .collapsingWhitespace()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let bodyText = [summaryText, detailsBody]
            .compactMap { text in
                guard let text, !text.isEmpty else { return nil }
                return text
            }
            .joined(separator: "\n\n")

        guard !bodyText.isEmpty else {
            return nil
        }

        var metadata: [String: MetadataValue] = [
            "rag.blockKind": .string("htmlDetails"),
        ]
        if let summaryText, !summaryText.isEmpty {
            metadata["rag.htmlSummary"] = .string(summaryText)
        }

        return HTMLMetadata(bodyText: bodyText, metadataOverrides: metadata)
    }

    private func htmlAttributeValue(_ attribute: String, in rawHTML: String) -> String? {
        let pattern = attribute + #"[\s]*=[\s]*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML)
        guard let match = regex.firstMatch(in: rawHTML, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: rawHTML)
        else {
            return nil
        }

        let value = String(rawHTML[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func htmlFirstTagContents(_ tag: String, in rawHTML: String) -> String? {
        let pattern = "<" + tag + #"\b[^>]*>(.*?)</"# + tag + ">"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return nil
        }

        let range = NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML)
        guard let match = regex.firstMatch(in: rawHTML, options: [], range: range),
              let contentRange = Range(match.range(at: 1), in: rawHTML)
        else {
            return nil
        }

        return String(rawHTML[contentRange])
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

private struct ImageReference {
    let source: String?
    let title: String?
    let altText: String?
}

private struct HTMLMetadata {
    let bodyText: String
    let metadataOverrides: [String: MetadataValue]
}

private struct ImageReferenceCollector: MarkupWalker {
    fileprivate private(set) var references: [ImageReference] = []

    mutating func visitImage(_ image: Image) {
        let altText = image.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = image.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = image.source?.trimmingCharacters(in: .whitespacesAndNewlines)

        references.append(
            ImageReference(
                source: source?.isEmpty == true ? nil : source,
                title: title?.isEmpty == true ? nil : title,
                altText: altText.isEmpty ? nil : altText
            )
        )
        descendInto(image)
    }
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

private struct InlineTextCollector: MarkupWalker {
    private var fragments: [String] = []

    var renderedText: String {
        fragments
            .joined()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func visitText(_ text: Text) {
        fragments.append(text.string)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        fragments.append(inlineCode.code)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        fragments.append(" ")
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        fragments.append(" ")
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) {}

    mutating func visitImage(_ image: Image) {
        let altText = image.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !altText.isEmpty {
            fragments.append(altText)
        }
    }
}

private enum MarkdownBlockKind {
    case paragraph
    case listItem
    case blockQuote
    case tableRow
    case codeBlock
}

private struct MarkdownChunkSectionCandidate {
    let headingPath: [String]
    let bodyText: String
    let sourceRange: Range<String.Index>
    let preservesBodyAsSingleChunk: Bool
    let blockKind: MarkdownBlockKind
    let metadataOverrides: [String: MetadataValue]

    func withoutBlockKind(
        documentMetadataOverrides: [String: MetadataValue] = [:]
    ) -> MarkdownChunkSection {
        var mergedMetadata = documentMetadataOverrides.merging(metadataOverrides) { _, new in new }
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
            case .codeBlock:
                mergedMetadata["rag.blockKind"] = .string("codeBlock")
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

private extension String {
    func collapsingWhitespace() -> String {
        split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    func strippingHTMLTags() -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else {
            return self
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: " ")
    }

    func removingHTMLTagBlock(_ tag: String) -> String {
        let pattern = "<" + tag + #"\b[^>]*>.*?</"# + tag + ">"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return self
        }

        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: " ")
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
