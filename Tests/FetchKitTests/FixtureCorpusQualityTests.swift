import FetchCore
@testable import FetchKit
import SwiftlyFetchTestFixtures
import Testing

@Suite(.serialized)
struct FixtureCorpusQualityTests {
    @Test("Fixture corpus records carry source attribution")
    func fixtureCorpusRecordsCarrySourceAttribution() {
        #expect(GutenbergMiniCorpus.source.datasetID == "zkeown/gutenberg-corpus")
        #expect(GutenbergMiniCorpus.source.config == "chapters")
        #expect(GutenbergMiniCorpus.source.split == "train")
        #expect(GutenbergMiniCorpus.records.allSatisfy { $0.sourceURI == GutenbergMiniCorpus.source.url })
        #expect(GutenbergMiniCorpus.records.allSatisfy { $0.metadata["fixture.dataset"] == GutenbergMiniCorpus.source.datasetID })
        #expect(TinyStoriesMiniCorpus.source.datasetID == "roneneldan/TinyStories")
        #expect(TinyStoriesMiniCorpus.source.config == "default")
        #expect(TinyStoriesMiniCorpus.source.split == "train")
        #expect(TinyStoriesMiniCorpus.records.allSatisfy { $0.sourceURI == TinyStoriesMiniCorpus.source.url })
        #expect(TinyStoriesMiniCorpus.records.allSatisfy { $0.metadata["fixture.dataset"] == TinyStoriesMiniCorpus.source.datasetID })
        #expect(HuggingFaceAuditCorpus.records.count == 10)
        #expect(HuggingFaceAuditCorpus.tinyStoriesRecords.allSatisfy { $0.sourceURI == HuggingFaceAuditCorpus.tinyStoriesSource.url })
        #expect(HuggingFaceAuditCorpus.simpleWikipediaRecords.allSatisfy { $0.sourceURI == HuggingFaceAuditCorpus.simpleWikipediaSource.url })
        #expect(HuggingFaceAuditCorpus.gutenbergPoetryRecords.allSatisfy { $0.sourceURI == HuggingFaceAuditCorpus.gutenbergPoetrySource.url })
        #expect(HuggingFaceAuditCorpus.records.allSatisfy { $0.metadata["fixture.dataset"] != nil })
    }

    @Test("Fixture corpus retrieves a body-driven chapter hit")
    func fixtureCorpusRetrievesBodyDrivenChapterHit() async throws {
        let library = try await indexedFixtureLibrary()

        let results = try await library.search(
            "storage food seeds",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 3
        )
        let firstResult = try #require(results.first)

        #expect(firstResult.document.id == "gutenberg-78430-chapter-1")
        #expect(firstResult.snippet?.text.localizedCaseInsensitiveContains("storage") == true)
        #expect(firstResult.snippet?.text.localizedCaseInsensitiveContains("food") == true)
        #expect(firstResult.snippet?.text.localizedCaseInsensitiveContains("seeds") == true)
        #expect((firstResult.snippet?.matchRanges.count ?? 0) >= 3)
        #expect(firstResult.matchedFields == [.body])
        #expect(firstResult.snippetField == .body)
    }

    @Test("Fixture corpus keeps closely related chapters separate")
    func fixtureCorpusKeepsRelatedChaptersSeparate() async throws {
        let library = try await indexedFixtureLibrary()

        let foodStorageResults = try await library.search(
            "storage food seeds",
            kind: .allTerms,
            fields: [.body],
            limit: 4
        )
        let germinationResults = try await library.search(
            "germinating seed organic",
            kind: .allTerms,
            fields: [.body],
            limit: 4
        )

        #expect(foodStorageResults.map(\.document.id).prefix(2) == [
            "gutenberg-78430-chapter-1",
            "fixture-botany-near-miss",
        ])
        #expect(germinationResults.map(\.document.id) == ["gutenberg-78430-chapter-2"])
    }

    @Test("Fixture corpus title-only hits use the title as the current snippet source")
    func fixtureCorpusTitleOnlyHitUsesTitleSnippet() async throws {
        let library = try await indexedFixtureLibrary()

        let results = try await library.search(
            "rocket test pilot",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 3
        )
        let firstResult = try #require(results.first)
        let snippet = try #require(firstResult.snippet)

        #expect(firstResult.document.id == "gutenberg-78431-book")
        #expect(firstResult.matchedFields == [.title])
        #expect(firstResult.snippetField == .title)
        #expect(snippet.text.localizedCaseInsensitiveContains("rocket test pilot"))
        #expect(!snippet.text.localizedCaseInsensitiveContains("Transcriber's Note"))
    }

    @Test("Fixture corpus ranks focused body evidence over near misses")
    func fixtureCorpusRanksFocusedBodyEvidenceOverNearMisses() async throws {
        let library = try await indexedFixtureLibrary()

        let results = try await library.search(
            "storage food seeds",
            kind: .allTerms,
            fields: [.body],
            limit: 4
        )

        #expect(results.map(\.document.id).prefix(2) == [
            "gutenberg-78430-chapter-1",
            "fixture-botany-near-miss",
        ])
        #expect(results.first?.snippet?.text.localizedCaseInsensitiveContains("storage of food in seeds") == true)
    }

    @Test("Fixture corpus selects useful snippets from longer bodies")
    func fixtureCorpusSelectsUsefulSnippetsFromLongerBodies() async throws {
        let library = try await indexedFixtureLibrary()

        let results = try await library.search(
            "pioneer chores neighbors cooperation",
            kind: .allTerms,
            fields: [.body],
            limit: 4
        )
        let firstResult = try #require(results.first)
        let snippet = try #require(firstResult.snippet)

        #expect(firstResult.document.id == "fixture-long-frontier-body")
        #expect(snippet.text.localizedCaseInsensitiveContains("pioneer children"))
        #expect(snippet.text.localizedCaseInsensitiveContains("cooperation"))
        #expect(snippet.text.hasPrefix("…"))
        #expect(snippet.text.hasSuffix("…"))
        #expect(firstResult.snippetField == .body)
    }

    @Test("Fixture corpus includes a second text source for simple story searches")
    func fixtureCorpusIncludesSecondTextSource() async throws {
        let library = try await indexedFixtureLibrary()

        let sewingResults = try await library.search(
            "needle sew shirt",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )
        let fuelResults = try await library.search(
            "healthy fuel car",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )

        #expect(sewingResults.first?.document.id == "tinystories-row-0-needle")
        #expect(sewingResults.first?.snippet?.text.localizedCaseInsensitiveContains("needle") == true)
        #expect(fuelResults.first?.document.id == "tinystories-row-1-beep")
        #expect(fuelResults.first?.matchedFields.contains(.body) == true)
    }

    @Test("Hugging Face audit corpus retrieves distinct content families")
    func huggingFaceAuditCorpusRetrievesDistinctContentFamilies() async throws {
        let library = try await indexedAuditLibrary()

        let calendarResults = try await library.search(
            "april leap year flowers",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )
        let rhetoricResults = try await library.search(
            "against person weak argument",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )
        let storyResults = try await library.search(
            "triangle puddle troubled toy",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )
        let poetryResults = try await library.search(
            "great lakes northland ojibways",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )

        #expect(calendarResults.first?.document.id == "hf-simplewiki-april")
        #expect(calendarResults.first?.snippet?.text.localizedCaseInsensitiveContains("leap years") == true)
        #expect(rhetoricResults.first?.document.id == "hf-simplewiki-ad-hominem")
        #expect(rhetoricResults.first?.snippet?.text.localizedCaseInsensitiveContains("weak") == true)
        #expect(rhetoricResults.first?.snippet?.text.localizedCaseInsensitiveContains("argument") == true)
        #expect(storyResults.first?.document.id == "hf-tinystories-row-6-triangle")
        #expect(storyResults.first?.snippet?.text.localizedCaseInsensitiveContains("puddle") == true)
        #expect(poetryResults.first?.document.id == "hf-poetry-hiawatha-northland")
        #expect(poetryResults.first?.snippet?.text.localizedCaseInsensitiveContains("great lakes") == true)
    }

    @Test("Hugging Face audit corpus exposes useful snippet fields")
    func huggingFaceAuditCorpusExposesUsefulSnippetFields() async throws {
        let library = try await indexedAuditLibrary()

        let titleResults = try await library.search(
            "angel",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )
        let bodyResults = try await library.search(
            "cobweb spider castle",
            kind: .allTerms,
            fields: [.title, .body],
            limit: 4
        )

        #expect(titleResults.first?.document.id == "hf-simplewiki-angels")
        #expect(titleResults.first?.matchedFields.contains(.title) == true)
        #expect(bodyResults.first?.document.id == "hf-tinystories-row-4-cobweb")
        #expect(bodyResults.first?.matchedFields.contains(.body) == true)
        #expect(bodyResults.first?.snippetField == .body)
    }

    private func indexedFixtureLibrary() async throws -> FetchKitLibrary {
        let library = FetchKitLibrary()
        try await library.addDocuments(GutenbergMiniCorpus.records + TinyStoriesMiniCorpus.records)
        return library
    }

    private func indexedAuditLibrary() async throws -> FetchKitLibrary {
        let library = FetchKitLibrary()
        try await library.addDocuments(
            GutenbergMiniCorpus.records
                + TinyStoriesMiniCorpus.records
                + HuggingFaceAuditCorpus.records
        )
        return library
    }
}
