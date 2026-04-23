import Testing
import RAGCore
@testable import RAGKit

@Suite("RAGKit Chunkers")
struct ChunkerTests {
    @Test("HeadingAwareMarkdownChunker carries heading context into markdown chunks")
    func headingAwareMarkdownChunkerIncludesHeadingContext() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-markdown",
            content: .markdown(
                """
                # Fruit Guide

                ## Apples

                Bright and crisp.

                ## Oranges

                Juicy and sweet.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Fruit Guide\nApples\n\nBright and crisp.")
        #expect(chunks[1].text == "Fruit Guide\nOranges\n\nJuicy and sweet.")
    }

    @Test("HeadingAwareMarkdownChunker keeps preamble text and nested heading context distinct")
    func headingAwareMarkdownChunkerIncludesPreambleAndNestedHeadings() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let source = """
        Intro paragraph before any headings.

        # Fruit Guide

        ## Citrus

        ### Oranges

        Juicy and sweet.
        """
        let document = Document(
            id: "doc-preamble",
            content: .markdown(source)
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Intro paragraph before any headings.")
        #expect(chunks[1].text == "Fruit Guide\nCitrus\nOranges\n\nJuicy and sweet.")
    }

    @Test("HeadingAwareMarkdownChunker keeps chunk body offsets tied to original markdown source")
    func headingAwareMarkdownChunkerPreservesBodyOffsets() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let source = """
        # Fruit Guide

        ## Apples

        Bright and crisp.
        """
        let document = Document(
            id: "doc-offsets",
            content: .markdown(source)
        )

        let chunks = try chunker.chunks(for: document)
        let chunk = try #require(chunks.first)
        let start = String.Index(utf16Offset: chunk.position.startOffset, in: source)
        let end = String.Index(utf16Offset: chunk.position.endOffset, in: source)

        #expect(String(source[start..<end]) == "Bright and crisp.")
        #expect(chunk.text == "Fruit Guide\nApples\n\nBright and crisp.")
    }

    @Test("HeadingAwareMarkdownChunker ignores heading-like lines inside fenced code blocks")
    func headingAwareMarkdownChunkerIgnoresHeadingsInsideCodeBlocks() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-code-fence",
            content: .markdown(
                """
                # Fruit Guide

                Intro paragraph before the code block.

                ```markdown
                ## Not A Real Heading
                ```

                Real paragraph after the code block.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Fruit Guide\n\nIntro paragraph before the code block.")
        #expect(chunks[1].text == "Fruit Guide\n\nReal paragraph after the code block.")
    }

    @Test("HeadingAwareMarkdownChunker keeps code block language metadata even when code stays secondary")
    func headingAwareMarkdownChunkerKeepsCodeLanguageMetadataWhenCodeStaysSecondary() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-code-metadata",
            content: .markdown(
                """
                # Fruit Guide

                Apples are bright and crisp.

                ```swift
                struct AppleGuide {}
                ```

                Oranges are juicy and sweet.

                Bananas are soft and mellow.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 3)
        #expect(chunks.map(\.text) == [
            "Fruit Guide\n\nApples are bright and crisp.",
            "Fruit Guide\n\nOranges are juicy and sweet.",
            "Fruit Guide\n\nBananas are soft and mellow.",
        ])
        #expect(chunks.allSatisfy { $0.metadata["rag.hasCodeBlocks"] == .bool(true) })
        #expect(chunks.allSatisfy { $0.metadata["rag.codeBlockLanguageCount"] == .int(1) })
        #expect(chunks.allSatisfy { $0.metadata["rag.codeBlockLanguages"] == .string("swift") })
    }

    @Test("HeadingAwareMarkdownChunker promotes code blocks when they are a large share of chunkable blocks")
    func headingAwareMarkdownChunkerPromotesCodeHeavyDocuments() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-code-heavy",
            content: .markdown(
                """
                # Fruit Tools

                Intro paragraph.

                ```swift
                struct AppleTool {}
                ```

                ```python
                def orange_tool():
                    return "citrus"
                ```
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 3)
        #expect(chunks[0].text == "Fruit Tools\n\nIntro paragraph.")
        #expect(chunks[1].text == "Fruit Tools\n\nLanguage: swift\n\nstruct AppleTool {}")
        #expect(chunks[2].text == "Fruit Tools\n\nLanguage: python\n\ndef orange_tool():\n    return \"citrus\"")
        #expect(chunks[1].metadata["rag.blockKind"] == .string("codeBlock"))
        #expect(chunks[1].metadata["rag.codeLanguage"] == .string("swift"))
        #expect(chunks[2].metadata["rag.codeLanguage"] == .string("python"))
        #expect(chunks.allSatisfy { $0.metadata["rag.codeBlockLanguageCount"] == .int(2) })
        #expect(chunks.allSatisfy { $0.metadata["rag.codeBlockLanguages"] == .string("python | swift") })
    }

    @Test("HeadingAwareMarkdownChunker treats thematic breaks as section lead-in boundaries")
    func headingAwareMarkdownChunkerTreatsThematicBreaksAsSectionLeadIns() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-thematic-break",
            content: .markdown(
                """
                # Fruit Guide

                Quick note

                ---

                Apples are bright and crisp.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Fruit Guide\n\nQuick note")
        #expect(chunks[1].text == "Fruit Guide\n\nQuick note\n\nApples are bright and crisp.")
        #expect(chunks[1].metadata["rag.sectionLeadIn"] == .string("Quick note"))
    }

    @Test("HeadingAwareMarkdownChunker keeps image alt text primary and records image metadata")
    func headingAwareMarkdownChunkerKeepsImageAltTextPrimary() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-inline-image",
            content: .markdown(
                """
                # Fruit Guide

                Review the ![apple diagram](images/apple.png "Apple Diagram") before setup.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nReview the apple diagram before setup.")
        #expect(chunks[0].metadata["rag.hasImages"] == .bool(true))
        #expect(chunks[0].metadata["rag.imageReferenceCount"] == .int(1))
        #expect(chunks[0].metadata["rag.imageSourceCount"] == .int(1))
        #expect(chunks[0].metadata["rag.imageSources"] == .string("images/apple.png"))
        #expect(chunks[0].metadata["rag.imageAltTexts"] == .string("apple diagram"))
        #expect(chunks[0].metadata["rag.imageTitles"] == .string("Apple Diagram"))
    }

    @Test("HeadingAwareMarkdownChunker preserves reference-style image metadata")
    func headingAwareMarkdownChunkerPreservesReferenceStyleImageMetadata() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-reference-image",
            content: .markdown(
                """
                # Fruit Guide

                Review the ![apple diagram][apple-image] before setup.

                [apple-image]: images/apple.png "Apple Diagram"
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nReview the apple diagram before setup.")
        #expect(chunks[0].metadata["rag.hasImages"] == .bool(true))
        #expect(chunks[0].metadata["rag.imageReferenceCount"] == .int(1))
        #expect(chunks[0].metadata["rag.imageSourceCount"] == .int(1))
        #expect(chunks[0].metadata["rag.imageSources"] == .string("images/apple.png"))
        #expect(chunks[0].metadata["rag.imageAltTexts"] == .string("apple diagram"))
        #expect(chunks[0].metadata["rag.imageTitles"] == .string("Apple Diagram"))
    }

    @Test("HeadingAwareMarkdownChunker ignores inline HTML tags in primary chunk text")
    func headingAwareMarkdownChunkerIgnoresInlineHTMLTagsInPrimaryChunkText() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-inline-html",
            content: .markdown(
                """
                # Fruit Guide

                Keep <span class="callout">this note</span> handy.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nKeep this note handy.")
        #expect(!chunks[0].text.contains("<span"))
    }

    @Test("HeadingAwareMarkdownChunker promotes whitelisted HTML image blocks into retrieval chunks")
    func headingAwareMarkdownChunkerPromotesHTMLImageBlocks() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-html-image",
            content: .markdown(
                """
                # Fruit Guide

                <img src="images/apple.png" alt="Apple Diagram" title="Cutaway">
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nApple Diagram\n\nCutaway")
        #expect(chunks[0].metadata["rag.blockKind"] == .string("image"))
        #expect(chunks[0].metadata["rag.hasImages"] == .bool(true))
        #expect(chunks[0].metadata["rag.imageReferenceCount"] == .int(1))
        #expect(chunks[0].metadata["rag.imageSources"] == .string("images/apple.png"))
        #expect(chunks[0].metadata["rag.imageAltTexts"] == .string("Apple Diagram"))
        #expect(chunks[0].metadata["rag.imageTitles"] == .string("Cutaway"))
    }

    @Test("HeadingAwareMarkdownChunker handles case-insensitive HTML image tags and attributes")
    func headingAwareMarkdownChunkerHandlesCaseInsensitiveHTMLImageTags() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-html-image-uppercase",
            content: .markdown(
                """
                # Fruit Guide

                <IMG SRC='images/apple.png' ALT='Apple Diagram' TITLE='Cutaway' />
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nApple Diagram\n\nCutaway")
        #expect(chunks[0].metadata["rag.blockKind"] == .string("image"))
        #expect(chunks[0].metadata["rag.imageSources"] == .string("images/apple.png"))
        #expect(chunks[0].metadata["rag.imageAltTexts"] == .string("Apple Diagram"))
        #expect(chunks[0].metadata["rag.imageTitles"] == .string("Cutaway"))
    }

    @Test("HeadingAwareMarkdownChunker promotes whitelisted HTML details blocks into retrieval chunks")
    func headingAwareMarkdownChunkerPromotesHTMLDetailsBlocks() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-html-details",
            content: .markdown(
                """
                # Fruit Guide

                <details>
                <summary>Storage tips</summary>
                Keep apples cold and dry.
                </details>
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nStorage tips\n\nKeep apples cold and dry.")
        #expect(chunks[0].metadata["rag.blockKind"] == .string("htmlDetails"))
        #expect(chunks[0].metadata["rag.htmlSummary"] == .string("Storage tips"))
    }

    @Test("HeadingAwareMarkdownChunker strips nested markup inside HTML details summaries")
    func headingAwareMarkdownChunkerStripsNestedMarkupInsideHTMLDetailsSummaries() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-html-details-nested",
            content: .markdown(
                """
                # Fruit Guide

                <details>
                <summary><strong>Storage tips</strong></summary>
                Keep <em>apples</em> cold and dry.
                </details>
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nStorage tips\n\nKeep apples cold and dry.")
        #expect(chunks[0].metadata["rag.blockKind"] == .string("htmlDetails"))
        #expect(chunks[0].metadata["rag.htmlSummary"] == .string("Storage tips"))
    }

    @Test("HeadingAwareMarkdownChunker keeps unsupported HTML blocks out of retrieval chunks")
    func headingAwareMarkdownChunkerKeepsUnsupportedHTMLBlocksOutOfRetrievalChunks() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-html-unsupported",
            content: .markdown(
                """
                # Fruit Guide

                Apples are bright and crisp.

                <div class="layout-only">Decorative wrapper</div>
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nApples are bright and crisp.")
    }

    @Test("HeadingAwareMarkdownChunker does not fall back for unsupported HTML only markdown")
    func headingAwareMarkdownChunkerDoesNotFallbackForUnsupportedHTMLOnlyMarkdown() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-html-only",
            content: .markdown(
                """
                <div class="layout-only">Decorative wrapper</div>
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.isEmpty)
    }

    @Test("HeadingAwareMarkdownChunker does not fall back for heading-only markdown")
    func headingAwareMarkdownChunkerDoesNotFallbackForHeadingOnlyMarkdown() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-heading-only",
            content: .markdown(
                """
                # Fruit Guide
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.isEmpty)
    }

    @Test("HeadingAwareMarkdownChunker does not fall back for reference-definition-only markdown")
    func headingAwareMarkdownChunkerDoesNotFallbackForReferenceDefinitionOnlyMarkdown() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-reference-definitions-only",
            content: .markdown(
                """
                [swift-guide]: https://swift.org/documentation
                [apple-docs]: https://developer.apple.com/documentation
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.isEmpty)
    }

    @Test("HeadingAwareMarkdownChunker ignores empty headings when building heading context")
    func headingAwareMarkdownChunkerIgnoresEmptyHeadings() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-empty-headings",
            content: .markdown(
                """
                # Fruit Guide

                ##

                ###

                Apples are bright and crisp.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\n\nApples are bright and crisp.")
    }

    @Test("HeadingAwareMarkdownChunker skips heading-only sections without disturbing the next section path")
    func headingAwareMarkdownChunkerSkipsHeadingOnlySections() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-heading-only-section",
            content: .markdown(
                """
                # Fruit Guide

                ## Empty Section

                ## Apples

                Bright and crisp.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "Fruit Guide\nApples\n\nBright and crisp.")
    }

    @Test("HeadingAwareMarkdownChunker keeps consecutive thematic breaks from duplicating section lead-ins")
    func headingAwareMarkdownChunkerDoesNotDuplicateLeadInsAcrossConsecutiveThematicBreaks() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-consecutive-breaks",
            content: .markdown(
                """
                # Fruit Guide

                Quick note

                ---

                ---

                Apples are bright and crisp.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Fruit Guide\n\nQuick note")
        #expect(chunks[1].text == "Fruit Guide\n\nQuick note\n\nApples are bright and crisp.")
        #expect(chunks[1].metadata["rag.sectionLeadIn"] == .string("Quick note"))
    }

    @Test("HeadingAwareMarkdownChunker composes code image and details policies in mixed markdown documents")
    func headingAwareMarkdownChunkerComposesMixedMarkdownPolicies() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-mixed-markdown",
            content: .markdown(
                """
                # Fruit Guide

                ![apple diagram](images/apple.png "Apple Diagram")

                ```swift
                struct AppleGuide {}
                ```

                ```python
                def orange_guide():
                    return "citrus"
                ```

                <details>
                <summary>Storage tips</summary>
                Keep apples cold and dry.
                </details>
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 4)
        #expect(chunks[0].text == "Fruit Guide\n\napple diagram")
        #expect(chunks[0].metadata["rag.hasImages"] == .bool(true))
        #expect(chunks[0].metadata["rag.imageSources"] == .string("images/apple.png"))
        #expect(chunks[1].metadata["rag.blockKind"] == .string("codeBlock"))
        #expect(chunks[1].metadata["rag.codeLanguage"] == .string("swift"))
        #expect(chunks[2].metadata["rag.blockKind"] == .string("codeBlock"))
        #expect(chunks[2].metadata["rag.codeLanguage"] == .string("python"))
        #expect(chunks[3].text == "Fruit Guide\n\nStorage tips\n\nKeep apples cold and dry.")
        #expect(chunks[3].metadata["rag.blockKind"] == .string("htmlDetails"))
        #expect(chunks.allSatisfy { $0.metadata["rag.hasCodeBlocks"] == .bool(true) })
        #expect(chunks.allSatisfy { $0.metadata["rag.codeBlockLanguageCount"] == .int(2) })
        #expect(chunks.allSatisfy { $0.metadata["rag.codeBlockLanguages"] == .string("python | swift") })
    }

    @Test("HeadingAwareMarkdownChunker splits list items into retrieval-friendly chunks")
    func headingAwareMarkdownChunkerSplitsListItems() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-list",
            content: .markdown(
                """
                # Fruit Guide

                ## Shopping

                - Apples are crisp.
                - Oranges are juicy.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Fruit Guide\nShopping\n\nApples are crisp.")
        #expect(chunks[1].text == "Fruit Guide\nShopping\n\nOranges are juicy.")
    }

    @Test("HeadingAwareMarkdownChunker carries immediate lead-in context into list item chunks")
    func headingAwareMarkdownChunkerCarriesLeadInContextIntoListItems() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-list-leadin",
            content: .markdown(
                """
                # Fruit Guide

                ## Shopping

                Pick one of these options:

                - Apples are crisp.
                - Oranges are juicy.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 3)
        #expect(chunks[0].text == "Fruit Guide\nShopping\n\nPick one of these options:")
        #expect(chunks[1].text == "Fruit Guide\nShopping\n\nPick one of these options:\n\nApples are crisp.")
        #expect(chunks[2].text == "Fruit Guide\nShopping\n\nPick one of these options:\n\nOranges are juicy.")
        #expect(chunks[1].metadata["rag.blockKind"] == .string("listItem"))
        #expect(chunks[1].metadata["rag.listKind"] == .string("unordered"))
        #expect(chunks[1].metadata["rag.listLeadIn"] == .string("Pick one of these options:"))
        #expect(chunks[1].metadata["rag.headingPath"] == .string("Fruit Guide > Shopping"))
    }

    @Test("HeadingAwareMarkdownChunker preserves ordered list sequence in chunk text")
    func headingAwareMarkdownChunkerPreservesOrderedListSequence() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-ordered-list",
            content: .markdown(
                """
                # Setup

                ## Steps

                Follow these steps:

                1. Install Swift.
                2. Build the package.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 3)
        #expect(chunks[1].text == "Setup\nSteps\n\nFollow these steps:\n\n1. Install Swift.")
        #expect(chunks[2].text == "Setup\nSteps\n\nFollow these steps:\n\n2. Build the package.")
        #expect(chunks[1].metadata["rag.listKind"] == .string("ordered"))
        #expect(chunks[1].metadata["rag.listOrdinal"] == .int(1))
        #expect(chunks[2].metadata["rag.listOrdinal"] == .int(2))
    }

    @Test("HeadingAwareMarkdownChunker keeps block quote content secondary to surrounding prose")
    func headingAwareMarkdownChunkerKeepsBlockQuotesSecondaryToProse() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-block-quote",
            content: .markdown(
                """
                # Fruit Guide

                Main explanation paragraph.

                > Supporting quote that should not become its own retrieval chunk.

                Closing paragraph.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Fruit Guide\n\nMain explanation paragraph.")
        #expect(chunks[1].text == "Fruit Guide\n\nClosing paragraph.")
    }

    @Test("HeadingAwareMarkdownChunker promotes block quotes when they are a large share of chunkable blocks")
    func headingAwareMarkdownChunkerPromotesQuoteHeavyDocuments() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-quote-heavy",
            content: .markdown(
                """
                # Quotes

                Intro paragraph.

                > Important quoted idea.

                > Another quoted idea.

                Closing paragraph.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 4)
        #expect(chunks[1].text == "Quotes\n\nImportant quoted idea.")
        #expect(chunks[1].metadata["rag.blockKind"] == .string("blockQuote"))
        #expect(chunks[2].text == "Quotes\n\nAnother quoted idea.")
        #expect(chunks[2].metadata["rag.blockKind"] == .string("blockQuote"))
    }

    @Test("HeadingAwareMarkdownChunker renders table rows with header-aware text and metadata")
    func headingAwareMarkdownChunkerRendersTableRowsWithHeaders() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-table",
            content: .markdown(
                """
                # Models

                | Name | Use |
                | --- | --- |
                | Qwen | Retrieval |
                | Llama | Summaries |
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 2)
        #expect(chunks[0].text == "Models\n\nName: Qwen\nUse: Retrieval")
        #expect(chunks[1].text == "Models\n\nName: Llama\nUse: Summaries")
        #expect(chunks[0].metadata["rag.blockKind"] == .string("tableRow"))
        #expect(chunks[0].metadata["rag.tableHeaders"] == .string("Name | Use"))
        #expect(chunks[0].metadata["rag.tableRowIndex"] == .int(0))
        #expect(chunks[1].metadata["rag.tableRowIndex"] == .int(1))
    }

    @Test("HeadingAwareMarkdownChunker keeps link anchor text primary and omits raw destinations from chunk text")
    func headingAwareMarkdownChunkerKeepsLinkAnchorTextPrimary() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-links",
            content: .markdown(
                """
                # References

                Read the [Swift documentation](https://swift.org/documentation) for details.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "References\n\nRead the Swift documentation for details.")
        #expect(!chunks[0].text.contains("https://swift.org/documentation"))
        #expect(chunks[0].metadata["rag.linkDestinations"] == nil)
        #expect(chunks[0].metadata["rag.linkDestinationCount"] == nil)
    }

    @Test("HeadingAwareMarkdownChunker can opt in to link destinations as chunk metadata")
    func headingAwareMarkdownChunkerCanOptIntoLinkDestinationMetadata() throws {
        let chunker = HeadingAwareMarkdownChunker(linkDestinationMetadataMode: .include)
        let document = Document(
            id: "doc-link-metadata",
            content: .markdown(
                """
                # References

                Read the [Swift documentation](https://swift.org/documentation) and the [Apple docs](https://developer.apple.com/documentation) for details.
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "References\n\nRead the Swift documentation and the Apple docs for details.")
        #expect(!chunks[0].text.contains("https://swift.org/documentation"))
        #expect(chunks[0].metadata["rag.linkDestinationCount"] == .int(2))
        #expect(
            chunks[0].metadata["rag.linkDestinations"] ==
                .string("https://swift.org/documentation\nhttps://developer.apple.com/documentation")
        )
    }

    @Test("HeadingAwareMarkdownChunker does not emit standalone chunks for reference link definitions")
    func headingAwareMarkdownChunkerSkipsReferenceLinkDefinitionsAsChunks() throws {
        let chunker = HeadingAwareMarkdownChunker()
        let document = Document(
            id: "doc-reference-links",
            content: .markdown(
                """
                # References

                Read the [Swift guide][swift-guide] for details.

                [swift-guide]: https://swift.org/documentation
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "References\n\nRead the Swift guide for details.")
        #expect(!chunks[0].text.contains("swift-guide"))
        #expect(!chunks[0].text.contains("https://swift.org/documentation"))
    }

    @Test("HeadingAwareMarkdownChunker records reference-link destinations in metadata when opted in")
    func headingAwareMarkdownChunkerRecordsReferenceLinkDestinationsWhenOptedIn() throws {
        let chunker = HeadingAwareMarkdownChunker(linkDestinationMetadataMode: .include)
        let document = Document(
            id: "doc-reference-link-metadata",
            content: .markdown(
                """
                # References

                Read the [Swift guide][swift-guide] for details.

                [swift-guide]: https://swift.org/documentation
                """
            )
        )

        let chunks = try chunker.chunks(for: document)

        #expect(chunks.count == 1)
        #expect(chunks[0].text == "References\n\nRead the Swift guide for details.")
        #expect(chunks[0].metadata["rag.linkDestinationCount"] == .int(1))
        #expect(chunks[0].metadata["rag.linkDestinations"] == .string("https://swift.org/documentation"))
    }
}

@Suite("KnowledgeBase Retrieval")
struct KnowledgeBaseRetrievalTests {
    @Test("KnowledgeBase adds documents, searches them, and removes them deterministically")
    func knowledgeBaseIndexesSearchesAndRemovesDocuments() async throws {
        let knowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: FixedEmbedder(
                chunkEmbeddingsByText: [
                    "Apples are bright and crisp.": EmbeddingVector([1, 0]).normalized(),
                    "Bananas are soft and sweet.": EmbeddingVector([0, 1]).normalized(),
                    "Citrus Notes\nOranges\n\nOranges are juicy and bright.": EmbeddingVector([0.9, 0.1]).normalized(),
                ],
                queryEmbeddingsByText: [
                    "bright fruit": EmbeddingVector([1, 0]).normalized(),
                ]
            ),
            index: InMemoryVectorIndex()
        )

        try await knowledgeBase.addDocuments([
            Document(
                id: "doc-apples",
                content: .text("Apples are bright and crisp.\n\nBananas are soft and sweet."),
                metadata: ["category": .string("fruit")]
            ),
            Document(
                id: "doc-oranges",
                content: .markdown(
                    """
                    # Citrus Notes

                    ## Oranges

                    Oranges are juicy and bright.
                    """
                ),
                metadata: ["category": .string("citrus")]
            ),
        ])

        let results = try await knowledgeBase.search("bright fruit", limit: 2)
        #expect(results.count == 2)
        #expect(results.first?.chunk.documentID == "doc-apples")
        #expect(results.last?.chunk.documentID == "doc-oranges")

        try await knowledgeBase.removeDocument("doc-apples")
        let remainingResults = try await knowledgeBase.search("bright fruit", limit: 5)
        #expect(remainingResults.map(\.chunk.documentID) == ["doc-oranges"])
    }

    @Test("KnowledgeBase hashingDefault uses heading-aware markdown chunking by default")
    func knowledgeBaseHashingDefaultPrefersMarkdownAwareChunking() async throws {
        let knowledgeBase = try await KnowledgeBase.hashingDefault(dimension: 32)

        try await knowledgeBase.addDocument(
            Document(
                id: "doc-defaults",
                content: .markdown(
                    """
                    # Retrieval Defaults

                    ## Markdown

                    Heading aware chunking should help searches surface the right section.
                    """
                )
            )
        )

        let results = try await knowledgeBase.search("markdown section", limit: 1)
        #expect(results.count == 1)
        #expect(results[0].chunk.text.contains("Retrieval Defaults"))
        #expect(results[0].chunk.text.contains("Markdown"))
    }
}

@Suite("KnowledgeBase Context Assembly")
struct KnowledgeBaseContextAssemblyTests {
    @Test("KnowledgeBase makeContext renders grouped annotated snippets and same-document plain snippets within budget")
    func knowledgeBaseMakeContextRendersDeterministicContext() async throws {
        let knowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: FixedEmbedder(
                chunkEmbeddingsByText: [
                    "First paragraph about apples.": EmbeddingVector([1, 0]).normalized(),
                    "Second paragraph about oranges.": EmbeddingVector([0.8, 0.2]).normalized(),
                ],
                queryEmbeddingsByText: [
                    "fruit summary": EmbeddingVector([1, 0]).normalized(),
                ]
            ),
            index: InMemoryVectorIndex()
        )

        try await knowledgeBase.addDocument(
            Document(
                id: "doc-fruit",
                content: .text("First paragraph about apples.\n\nSecond paragraph about oranges."),
                metadata: ["category": .string("fruit")]
            )
        )

        let plainContext = try await knowledgeBase.makeContext(
            for: "fruit summary",
            limit: 2,
            budget: .characters(40),
            style: .plain
        )

        let annotatedContext = try await knowledgeBase.makeContext(
            for: "fruit summary",
            limit: 2,
            budget: .unlimited,
            style: .annotated
        )

        #expect(plainContext == "First paragraph about apples.\nSecond…")
        #expect(annotatedContext.contains("[Document: doc-fruit]"))
        #expect(annotatedContext.contains("[Chunk: doc-fruit#0 | Score:"))
        #expect(annotatedContext.contains("[Chunk: doc-fruit#1 | Score:"))
        #expect(annotatedContext.contains("First paragraph about apples."))
        #expect(annotatedContext.contains("Second paragraph about oranges."))
        #expect(annotatedContext.components(separatedBy: "[Document: doc-fruit]").count == 2)
    }

    @Test("KnowledgeBase makeContext suppresses adjacent repeated content beyond exact text matches")
    func knowledgeBaseMakeContextSuppressesDuplicateAdjacentChunks() async throws {
        let knowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: FixedEmbedder(
                chunkEmbeddingsByText: [
                    "Alpha detail.": EmbeddingVector([1, 0]).normalized(),
                    "Alpha detail": EmbeddingVector([0.95, 0.05]).normalized(),
                    "Alpha detail. More context.": EmbeddingVector([0.9, 0.1]).normalized(),
                    "Gamma outside.": EmbeddingVector([0.8, 0.2]).normalized(),
                ],
                queryEmbeddingsByText: [
                    "alpha summary": EmbeddingVector([1, 0]).normalized(),
                ]
            ),
            index: InMemoryVectorIndex()
        )

        try await knowledgeBase.addDocuments([
            Document(
                id: "doc-primary",
                content: .text("Alpha detail.\n\nAlpha detail\n\nAlpha detail. More context.")
            ),
            Document(
                id: "doc-secondary",
                content: .text("Gamma outside.")
            ),
        ])

        let plainContext = try await knowledgeBase.makeContext(
            for: "alpha summary",
            limit: 4,
            budget: .unlimited,
            style: .plain
        )

        #expect(plainContext == "Alpha detail.\nAlpha detail. More context.\n\nGamma outside.")
    }

    @Test("KnowledgeBase makeContext skips annotated sections that do not have room for meaningful body text")
    func knowledgeBaseMakeContextRefinesAnnotatedBudgetBehavior() async throws {
        let knowledgeBase = KnowledgeBase(
            chunker: DefaultChunker(),
            embedder: FixedEmbedder(
                chunkEmbeddingsByText: [
                    "A very detailed paragraph about apples and oranges together.": EmbeddingVector([1, 0]).normalized(),
                    "Backup details for the same document.": EmbeddingVector([0.9, 0.1]).normalized(),
                ],
                queryEmbeddingsByText: [
                    "fruit detail": EmbeddingVector([1, 0]).normalized(),
                ]
            ),
            index: InMemoryVectorIndex()
        )

        try await knowledgeBase.addDocument(
            Document(
                id: "doc-budget",
                content: .text("A very detailed paragraph about apples and oranges together.\n\nBackup details for the same document.")
            )
        )

        let tinyAnnotatedContext = try await knowledgeBase.makeContext(
            for: "fruit detail",
            limit: 2,
            budget: .characters(40),
            style: .annotated
        )

        let usefulAnnotatedContext = try await knowledgeBase.makeContext(
            for: "fruit detail",
            limit: 2,
            budget: .characters(110),
            style: .annotated
        )

        #expect(tinyAnnotatedContext.isEmpty)
        #expect(usefulAnnotatedContext.contains("[Document: doc-budget]"))
        #expect(usefulAnnotatedContext.contains("[Chunk: doc-budget#0 | Score:"))
        #expect(usefulAnnotatedContext.contains("A very detailed"))
    }
}

private struct FixedEmbedder: Embedder, Sendable {
    let chunkEmbeddingsByText: [String: EmbeddingVector]
    let queryEmbeddingsByText: [String: EmbeddingVector]

    func embed(chunks: [Chunk]) async throws -> [EmbeddingVector] {
        chunks.map { chunkEmbeddingsByText[$0.text] ?? EmbeddingVector([0, 0]) }
    }

    func embed(query: SearchQuery) async throws -> EmbeddingVector {
        queryEmbeddingsByText[query.text] ?? EmbeddingVector([0, 0])
    }
}
