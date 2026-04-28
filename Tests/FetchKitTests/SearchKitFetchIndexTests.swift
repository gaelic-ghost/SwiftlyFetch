#if os(macOS)
import Foundation
import XCTest
import FetchCore
@testable import FetchKit

final class SearchKitFetchIndexTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_SEARCHKIT_TESTS"] == "1",
            "Enable Search Kit tests with RUN_SEARCHKIT_TESTS=1."
        )
    }

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

        let storeURL = temporaryDirectory.appendingPathComponent("fetch.sqlite")
        let indexURL = temporaryDirectory.appendingPathComponent("searchkit.index")
        let library = try await FetchKitLibrary.macOSPersistentLibrary(
            configuration: .init(
                store: .init(store: .sqlite(storeURL)),
                index: .init(
                    storage: .file(indexURL),
                    indexNamePrefix: "SearchKitFetchIndexTests-\(UUID().uuidString)"
                )
            )
        )

        let pendingSyncs = try await library.pendingIndexSyncs()

        XCTAssertTrue(pendingSyncs.isEmpty)
    }
}
#endif
