import Foundation
import Testing
@testable import FetchCore

@Suite("FetchCore Search Models")
struct FetchCoreSearchModelTests {
    @Test("Fetch search queries keep a stable default shape")
    func fetchSearchQueryDefaults() {
        let query = FetchSearchQuery("apple guide")

        #expect(query.text == "apple guide")
        #expect(query.kind == .naturalLanguage)
        #expect(query.fields == Set(FetchSearchField.allCases))
        #expect(query.limit == 10)
    }

    @Test("Fetch search queries normalize empty fields and nonpositive limits")
    func fetchSearchQueryNormalizesFieldsAndLimit() {
        let query = FetchSearchQuery(
            "apple",
            kind: .exactPhrase,
            fields: [],
            limit: -4
        )

        #expect(query.kind == .exactPhrase)
        #expect(query.fields == Set(FetchSearchField.allCases))
        #expect(query.limit == 0)
    }

    @Test("Fetch match ranges clamp invalid bounds")
    func fetchMatchRangeClampsBounds() {
        let range = FetchMatchRange(lowerBound: -3, upperBound: 1)
        let inverted = FetchMatchRange(lowerBound: 8, upperBound: 2)

        #expect(range.lowerBound == 0)
        #expect(range.upperBound == 1)
        #expect(inverted.lowerBound == 8)
        #expect(inverted.upperBound == 8)
    }

    @Test("Fetch search results carry documents and optional snippets")
    func fetchSearchResultCarriesDocumentAndSnippet() {
        let document = FetchDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown
        )
        let snippet = FetchSnippet(
            text: "Apples are bright and crisp.",
            matchRanges: [FetchMatchRange(lowerBound: 0, upperBound: 6)]
        )
        let result = FetchSearchResult(document: document, score: 0.9, snippet: snippet)

        #expect(result.document.id == "doc-apple")
        #expect(result.document.title == "Apple Guide")
        #expect(result.document.contentType == .markdown)
        #expect(result.score == 0.9)
        #expect(result.snippet?.text == "Apples are bright and crisp.")
        #expect(result.snippet?.matchRanges == [FetchMatchRange(lowerBound: 0, upperBound: 6)])
    }

    @Test("Fetch document records keep durable metadata separate from the indexable document view")
    func fetchDocumentRecordSeparatesDurableStateFromIndexableView() {
        let indexedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown,
            sourceURI: "file:///docs/apple.md",
            metadata: [
                "category": "fruit",
                "workspace": "docs",
            ],
            lastIndexedAt: indexedAt
        )

        #expect(record.id == "doc-apple")
        #expect(record.sourceURI == "file:///docs/apple.md")
        #expect(record.metadata["category"] == "fruit")
        #expect(record.lastIndexedAt == indexedAt)

        let document = record.indexableDocument
        #expect(document.id == "doc-apple")
        #expect(document.title == "Apple Guide")
        #expect(document.body == "Apples are bright and crisp.")
        #expect(document.contentType == FetchDocumentContentType.markdown)
    }

    @Test("Fetch documents can be constructed from document records")
    func fetchDocumentInitializesFromRecord() {
        let record = FetchDocumentRecord(
            id: "doc-orange",
            title: "Orange Guide",
            body: "Oranges are juicy and sweet.",
            contentType: .plainText,
            sourceURI: "file:///docs/orange.txt",
            metadata: ["category": "citrus"]
        )

        let document = FetchDocument(record: record)

        #expect(document.id == "doc-orange")
        #expect(document.title == "Orange Guide")
        #expect(document.body == "Oranges are juicy and sweet.")
        #expect(document.contentType == FetchDocumentContentType.plainText)
    }

    @Test("Fetch indexing changesets separate upserts from removals")
    func fetchIndexingChangesetSeparatesUpsertsAndRemovals() {
        let apple = FetchDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )
        let orange = FetchDocument(
            id: "doc-orange",
            title: "Orange Guide",
            body: "Oranges are juicy and sweet."
        )
        let changeset = FetchIndexingChangeset([
            .upsert(apple),
            .remove("doc-old"),
            .upsert(orange),
        ])

        #expect(!changeset.isEmpty)
        #expect(changeset.upsertedDocuments == [apple, orange])
        #expect(changeset.removedDocumentIDs == ["doc-old"])
    }

    @Test("Fetch indexing changesets report empty state")
    func fetchIndexingChangesetReportsEmptyState() {
        let changeset = FetchIndexingChangeset([])

        #expect(changeset.isEmpty)
        #expect(changeset.upsertedDocuments.isEmpty)
        #expect(changeset.removedDocumentIDs.isEmpty)
    }
}
