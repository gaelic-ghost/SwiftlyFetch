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
        #expect(result.matchedFields.isEmpty)
        #expect(result.snippetField == nil)
    }

    @Test("Fetch search results can describe matched fields and snippet source")
    func fetchSearchResultsDescribeMatchedFields() {
        let document = FetchDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )
        let result = FetchSearchResult(
            document: document,
            score: 0.9,
            snippet: FetchSnippet(text: "Apple Guide"),
            matchedFields: [.title],
            snippetField: .title
        )

        #expect(result.matchedFields == [.title])
        #expect(result.snippetField == .title)
    }

    @Test("Fetch document records keep durable metadata separate from search and index views")
    func fetchDocumentRecordSeparatesDurableStateFromDerivedViews() {
        let createdAt = Date(timeIntervalSince1970: 1_699_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_699_500_000)
        let indexedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown,
            kind: .guide,
            language: "en",
            sourceURI: "file:///docs/apple.md",
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: [
                "category": "fruit",
                "workspace": "docs",
            ],
            lastIndexedAt: indexedAt
        )

        #expect(record.id == "doc-apple")
        #expect(record.kind == .guide)
        #expect(record.language == "en")
        #expect(record.sourceURI == "file:///docs/apple.md")
        #expect(record.createdAt == createdAt)
        #expect(record.updatedAt == updatedAt)
        #expect(record.metadata["category"] == "fruit")
        #expect(record.lastIndexedAt == indexedAt)

        let searchDocument = record.searchDocument
        #expect(searchDocument.id == "doc-apple")
        #expect(searchDocument.title == "Apple Guide")
        #expect(searchDocument.body == "Apples are bright and crisp.")
        #expect(searchDocument.contentType == FetchDocumentContentType.markdown)

        let indexDocument = record.indexDocument
        #expect(indexDocument.id == "doc-apple")
        #expect(indexDocument.kind == .guide)
        #expect(indexDocument.language == "en")
        #expect(indexDocument.sourceURI == "file:///docs/apple.md")
        #expect(indexDocument.createdAt == createdAt)
        #expect(indexDocument.updatedAt == updatedAt)
        #expect(indexDocument.metadata["workspace"] == "docs")
    }

    @Test("Fetch documents can be constructed from document records")
    func fetchDocumentInitializesFromRecord() {
        let record = FetchDocumentRecord(
            id: "doc-orange",
            title: "Orange Guide",
            body: "Oranges are juicy and sweet.",
            contentType: .plainText,
            kind: .reference,
            language: "en",
            sourceURI: "file:///docs/orange.txt",
            createdAt: Date(timeIntervalSince1970: 1_700_100_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_200_000),
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
        let apple = FetchIndexDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            kind: .guide,
            language: "en"
        )
        let orange = FetchIndexDocument(
            id: "doc-orange",
            title: "Orange Guide",
            body: "Oranges are juicy and sweet.",
            kind: .reference,
            language: "en"
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

    @Test("Fetch index documents can still be reduced to search documents")
    func fetchIndexDocumentCanProduceSearchDocument() {
        let document = FetchIndexDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown,
            kind: .guide,
            language: "en",
            sourceURI: "file:///docs/apple.md",
            metadata: ["category": "fruit"]
        )

        let searchDocument = document.searchDocument

        #expect(searchDocument.id == "doc-apple")
        #expect(searchDocument.title == "Apple Guide")
        #expect(searchDocument.body == "Apples are bright and crisp.")
        #expect(searchDocument.contentType == .markdown)
    }

    @Test("Fetch indexing changesets report empty state")
    func fetchIndexingChangesetReportsEmptyState() {
        let changeset = FetchIndexingChangeset([])

        #expect(changeset.isEmpty)
        #expect(changeset.upsertedDocuments.isEmpty)
        #expect(changeset.removedDocumentIDs.isEmpty)
    }

    @Test("Fetch store mutation results expose affected document IDs from the indexing changeset")
    func fetchStoreMutationResultExposesAffectedDocumentIDs() {
        let apple = FetchIndexDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )
        let result = FetchStoreMutationResult(
            pendingIndexSync: FetchPendingIndexSync(
                id: "sync-1",
                changeset: FetchIndexingChangeset([
                    .upsert(apple),
                    .remove("doc-apple"),
                    .remove("doc-orange"),
                ])
            )
        )

        #expect(result.affectedDocumentIDs == ["doc-apple", "doc-orange"])
        #expect(!result.isEmpty)
    }
}
