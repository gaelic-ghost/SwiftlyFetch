import FetchCore
import Testing
@testable import FetchKit

@Suite("FetchKit fixture corpus quality", .serialized)
struct FixtureCorpusQualityTests {
    @Test("Fixture corpus records carry source attribution")
    func fixtureCorpusRecordsCarrySourceAttribution() {
        #expect(GutenbergMiniCorpus.source.datasetID == "zkeown/gutenberg-corpus")
        #expect(GutenbergMiniCorpus.source.config == "chapters")
        #expect(GutenbergMiniCorpus.source.split == "train")
        #expect(GutenbergMiniCorpus.records.allSatisfy { $0.sourceURI == GutenbergMiniCorpus.source.url })
        #expect(GutenbergMiniCorpus.records.allSatisfy { $0.metadata["fixture.dataset"] == GutenbergMiniCorpus.source.datasetID })
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

        #expect(foodStorageResults.map(\.document.id) == ["gutenberg-78430-chapter-1"])
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
        #expect(snippet.text.localizedCaseInsensitiveContains("rocket test pilot"))
        #expect(!snippet.text.localizedCaseInsensitiveContains("Transcriber's Note"))
    }

    private func indexedFixtureLibrary() async throws -> FetchKitLibrary {
        let library = FetchKitLibrary()
        try await library.addDocuments(GutenbergMiniCorpus.records)
        return library
    }
}
