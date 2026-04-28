#if os(macOS)
import Foundation
import XCTest
import FetchCore
@testable import FetchKit

final class SearchKitFetchIndexTests: XCTestCase {
    func testSearchKitFetchIndexIndexesAndSearchesText() async throws {
        let index = try SearchKitFetchIndex(
            configuration: .init(
                storage: .inMemory,
                indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
            )
        )
        let apple = FetchIndexDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown
        )
        let orange = FetchIndexDocument(
            id: "doc-orange",
            title: "Orange Guide",
            body: "Oranges are juicy and sweet.",
            contentType: .plainText
        )

        try await index.apply(
            FetchIndexingChangeset([
                .upsert(apple),
                .upsert(orange),
            ])
        )

        let titleResults = try await index.search(
            FetchSearchQuery("Apple", kind: .naturalLanguage, fields: [.title], limit: 5)
        )
        let bodyResults = try await index.search(
            FetchSearchQuery("juicy", kind: .naturalLanguage, fields: [.body], limit: 5)
        )

        XCTAssertEqual(titleResults.map(\.document.id), ["doc-apple"])
        XCTAssertEqual(bodyResults.map(\.document.id), ["doc-orange"])
        XCTAssertEqual(bodyResults.first?.snippet?.text.contains("juicy"), true)
    }

    func testSearchKitFetchIndexPrefersTitleMatchesOverBodyOnlyMatches() async throws {
        let index = try SearchKitFetchIndex(
            configuration: .init(
                storage: .inMemory,
                indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
            )
        )

        try await index.apply(
            FetchIndexingChangeset([
                .upsert(
                    FetchIndexDocument(
                        id: "doc-title",
                        title: "Apple Guide",
                        body: "General orchard notes."
                    )
                ),
                .upsert(
                    FetchIndexDocument(
                        id: "doc-body",
                        title: "Orchard Notes",
                        body: "This document covers apple harvest timing."
                    )
                ),
            ])
        )

        let results = try await index.search(
            FetchSearchQuery("apple", kind: .naturalLanguage, fields: [.title, .body], limit: 5)
        )

        XCTAssertEqual(results.map(\.document.id), ["doc-title", "doc-body"])
    }

    func testSearchKitFetchIndexHighlightsMultipleQueryTermsInSnippets() async throws {
        let index = try SearchKitFetchIndex(
            configuration: .init(
                storage: .inMemory,
                indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
            )
        )

        try await index.apply(
            FetchIndexingChangeset([
                .upsert(
                    FetchIndexDocument(
                        id: "doc-apple",
                        title: "Apple Guide",
                        body: "Apples stay bright and crisp through the fall harvest season."
                    )
                ),
            ])
        )

        let results = try await index.search(
            FetchSearchQuery("bright crisp", kind: .naturalLanguage, fields: [.body], limit: 1)
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.snippet?.text.localizedCaseInsensitiveContains("bright"), true)
        XCTAssertEqual(results.first?.snippet?.text.localizedCaseInsensitiveContains("crisp"), true)
        XCTAssertGreaterThanOrEqual(results.first?.snippet?.matchRanges.count ?? 0, 2)
    }

    func testSearchKitFetchIndexShowsSnippetTruncationMarkers() async throws {
        let index = try SearchKitFetchIndex(
            configuration: .init(
                storage: .inMemory,
                indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
            )
        )

        try await index.apply(
            FetchIndexingChangeset([
                .upsert(
                    FetchIndexDocument(
                        id: "doc-apple",
                        title: "Apple Guide",
                        body: "Introductory orchard notes cover storage, pruning, rootstock selection, irrigation strategy, and pollination planning before the bright apple section becomes especially relevant for fall harvest planning and storage."
                    )
                ),
            ])
        )

        let results = try await index.search(
            FetchSearchQuery("bright apple section", kind: .naturalLanguage, fields: [.body], limit: 1)
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.snippet?.text.hasPrefix("…"), true)
        XCTAssertEqual(results.first?.snippet?.text.hasSuffix("…"), true)
    }

    func testSearchKitFetchIndexExactPhraseQueriesPreferExactPhraseDocuments() async throws {
        let index = try SearchKitFetchIndex(
            configuration: .init(
                storage: .inMemory,
                indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
            )
        )

        try await index.apply(
            FetchIndexingChangeset([
                .upsert(
                    FetchIndexDocument(
                        id: "doc-phrase",
                        title: "Harvest Guide",
                        body: "The exact bright apple phrase appears together here."
                    )
                ),
                .upsert(
                    FetchIndexDocument(
                        id: "doc-prefix",
                        title: "Harvest Guide",
                        body: "Bright fruit notes mention apples nearby but not as an exact phrase."
                    )
                ),
            ])
        )

        let results = try await index.search(
            FetchSearchQuery("bright apple", kind: .exactPhrase, fields: [.body], limit: 5)
        )

        XCTAssertEqual(results.map(\.document.id), ["doc-phrase"])
    }

    func testSearchKitFetchIndexRemovesDocumentsFromSearchResults() async throws {
        let index = try SearchKitFetchIndex(
            configuration: .init(
                storage: .inMemory,
                indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
            )
        )
        let apple = FetchIndexDocument(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        try await index.apply(FetchIndexingChangeset([.upsert(apple)]))
        try await index.apply(FetchIndexingChangeset([.remove("doc-apple")]))

        let results = try await index.search(
            FetchSearchQuery("Apple", kind: .naturalLanguage, fields: [.title], limit: 5)
        )

        XCTAssertTrue(results.isEmpty)
    }

    func testFetchKitLibraryBuildsPersistentPair() async throws {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let library = try await FetchKitLibrary.macOSPersistentLibrary(
            at: temporaryDirectory,
            indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
        )

        let pendingSyncs = try await library.pendingIndexSyncs()

        XCTAssertTrue(pendingSyncs.isEmpty)
    }
}
#endif
