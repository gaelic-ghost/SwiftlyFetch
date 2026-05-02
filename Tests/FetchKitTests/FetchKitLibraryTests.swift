import Foundation
import Testing
import FetchCore
@testable import FetchKit

@Suite("FetchKitLibrary", .serialized)
struct FetchKitLibraryTests {
    @Test("FetchKitLibrary adds documents through the store and index")
    func fetchKitLibraryAddsDocuments() async throws {
        let store = RecordingFetchDocumentStore()
        let index = RecordingFetchIndex()
        let library = FetchKitLibrary(documentStore: store, index: index)
        let records = [
            FetchDocumentRecord(
                id: "doc-apple",
                title: "Apple Guide",
                body: "Apples are bright and crisp.",
                contentType: .markdown,
                kind: .guide,
                language: "en"
            ),
        ]

        let result = try await library.addDocuments(records)

        let storedRecords = await store.upsertedRecords
        let appliedChangesets = await index.appliedChangesets

        #expect(result == .init(documentIDs: ["doc-apple"]))
        #expect(storedRecords == records)
        #expect(appliedChangesets.count == 1)
        #expect(appliedChangesets[0].upsertedDocuments == records.map(\.indexDocument))
    }

    @Test("FetchKitLibrary exposes singular convenience methods")
    func fetchKitLibrarySupportsSingularOperations() async throws {
        let store = RecordingFetchDocumentStore()
        let index = RecordingFetchIndex()
        let library = FetchKitLibrary(documentStore: store, index: index)
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        let addResult = try await library.addDocument(record)
        let fetchedRecord = try await library.document(withID: "doc-apple")
        let removeResult = try await library.removeDocument(withID: "doc-apple")

        #expect(addResult == .init(documentIDs: ["doc-apple"]))
        #expect(fetchedRecord == record)
        #expect(removeResult == .init(documentIDs: ["doc-apple"]))
    }

    @Test("FetchKitLibrary removes documents through the store and index")
    func fetchKitLibraryRemovesDocuments() async throws {
        let store = RecordingFetchDocumentStore()
        let index = RecordingFetchIndex()
        let library = FetchKitLibrary(documentStore: store, index: index)

        let result = try await library.removeDocuments(["doc-apple", "doc-orange"])

        let removedIDs = await store.removedDocumentIDs
        let appliedChangesets = await index.appliedChangesets

        #expect(result == .init(documentIDs: ["doc-apple", "doc-orange"]))
        #expect(removedIDs == ["doc-apple", "doc-orange"])
        #expect(appliedChangesets.count == 1)
        #expect(appliedChangesets[0].removedDocumentIDs == ["doc-apple", "doc-orange"])
    }

    @Test("FetchKitLibrary search convenience builds queries and delegates to the index")
    func fetchKitLibrarySearchConvenienceDelegates() async throws {
        let store = RecordingFetchDocumentStore()
        let expectedResult = FetchSearchResult(
            document: FetchDocument(
                id: "doc-apple",
                title: "Apple Guide",
                body: "Apples are bright and crisp.",
                contentType: .markdown
            ),
            score: 0.9
        )
        let index = RecordingFetchIndex(searchResults: [expectedResult])
        let library = FetchKitLibrary(documentStore: store, index: index)

        let results = try await library.search(
            "apple guide",
            kind: .allTerms,
            fields: [.title],
            limit: 3
        )

        let queries = await index.receivedQueries

        #expect(results == [expectedResult])
        #expect(queries.count == 1)
        #expect(queries[0] == FetchSearchQuery("apple guide", kind: .allTerms, fields: [.title], limit: 3))
    }

    @Test("FetchKitLibrary default construction uses an in-memory backend")
    func fetchKitLibraryDefaultConstructionUsesInMemoryBackend() async throws {
        let library = FetchKitLibrary()
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        let addResult = try await library.addDocument(record)
        let fetchedRecord = try await library.document(withID: "doc-apple")
        let results = try await library.search("bright apple", fields: [.body], limit: 1)

        #expect(addResult == .init(documentIDs: ["doc-apple"]))
        #expect(fetchedRecord == record)
        #expect(results.count == 1)
        #expect(results[0].document.id == "doc-apple")
        #expect(results[0].snippet?.text.contains("bright") == true)
        #expect(results[0].matchedFields == [.body])
        #expect(results[0].snippetField == .body)
    }

    @Test("FetchKitLibrary prefers title matches over body-only matches")
    func fetchKitLibraryPrefersTitleMatches() async throws {
        let library = FetchKitLibrary()

        try await library.addDocuments([
            FetchDocumentRecord(
                id: "doc-title",
                title: "Apple Guide",
                body: "General orchard notes."
            ),
            FetchDocumentRecord(
                id: "doc-body",
                title: "Orchard Notes",
                body: "This document talks about apple harvest timing."
            ),
        ])

        let results = try await library.search("apple", fields: [.title, .body], limit: 5)

        #expect(results.count == 2)
        #expect(results.map(\.document.id) == ["doc-title", "doc-body"])
        #expect(results[0].matchedFields == [.title])
        #expect(results[0].snippetField == .title)
        #expect(results[1].matchedFields == [.body])
        #expect(results[1].snippetField == .body)
    }

    @Test("FetchKitLibrary snippets highlight multiple query terms")
    func fetchKitLibraryHighlightsMultipleQueryTerms() async throws {
        let library = FetchKitLibrary()

        try await library.addDocument(
            FetchDocumentRecord(
                id: "doc-apple",
                title: "Apple Guide",
                body: "Apples stay bright and crisp through the fall harvest season."
            )
        )

        let results = try await library.search("bright crisp", fields: [.body], limit: 1)
        let snippet = try #require(results.first?.snippet)

        #expect(snippet.text.localizedCaseInsensitiveContains("bright"))
        #expect(snippet.text.localizedCaseInsensitiveContains("crisp"))
        #expect(snippet.matchRanges.count >= 2)
        #expect(results.first?.matchedFields == [.body])
        #expect(results.first?.snippetField == .body)
    }

    @Test("FetchKitLibrary snippets show truncation markers when context is cropped")
    func fetchKitLibrarySnippetShowsTruncationMarkers() async throws {
        let library = FetchKitLibrary()

        try await library.addDocument(
            FetchDocumentRecord(
                id: "doc-apple",
                title: "Apple Guide",
                body: "Introductory orchard notes cover storage, pruning, rootstock selection, irrigation strategy, and pollination planning before the bright apple section becomes especially relevant for fall harvest planning and storage."
            )
        )

        let results = try await library.search("bright apple section", fields: [.body], limit: 1)
        let snippet = try #require(results.first?.snippet)

        #expect(snippet.text.hasPrefix("…"))
        #expect(snippet.text.hasSuffix("…"))
    }

    @Test("FetchKitLibrary exact phrase queries outrank prefix-style body matches")
    func fetchKitLibraryExactPhraseOutranksPrefixMatches() async throws {
        let library = FetchKitLibrary()

        try await library.addDocuments([
            FetchDocumentRecord(
                id: "doc-phrase",
                title: "Harvest Guide",
                body: "The exact bright apple phrase appears together here."
            ),
            FetchDocumentRecord(
                id: "doc-prefix",
                title: "Harvest Guide",
                body: "Bright fruit notes mention apples nearby but not as an exact phrase."
            ),
        ])

        let results = try await library.search("\"bright apple\"", kind: .exactPhrase, fields: [.body], limit: 5)

        #expect(results.map(\.document.id) == ["doc-phrase"])
    }

    @Test("FetchKitLibrary surfaces pending indexing changes when the index apply step fails")
    func fetchKitLibrarySurfacesPendingIndexingChanges() async throws {
        let store = RecordingFetchDocumentStore()
        let index = FailingFetchIndex()
        let library = FetchKitLibrary(documentStore: store, index: index)
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        do {
            _ = try await library.addDocument(record)
            Issue.record("Expected FetchKitLibrary to surface an index sync error.")
        } catch let error as FetchKitLibrary.IndexSyncError {
            #expect(error.pendingIndexSync.changeset.upsertedDocuments == [record.indexDocument])
        } catch {
            Issue.record("Expected FetchKitLibrary.IndexSyncError but received \(String(describing: error)).")
        }

        let fetchedRecord = try await library.document(withID: "doc-apple")
        let pendingSyncs = try await library.pendingIndexSyncs()

        #expect(fetchedRecord == record)
        #expect(pendingSyncs.count == 1)
        #expect(pendingSyncs[0].changeset.upsertedDocuments == [record.indexDocument])
    }

    @Test("FetchKitLibrary retries pending index syncs and clears them after success")
    func fetchKitLibraryRetriesPendingIndexSyncs() async throws {
        let store = RecordingFetchDocumentStore()
        let failingIndex = FailingFetchIndex()
        let library = FetchKitLibrary(documentStore: store, index: failingIndex)
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        do {
            _ = try await library.addDocument(record)
            Issue.record("Expected the first add attempt to leave a pending sync behind.")
        } catch {}

        let retryingIndex = RecordingFetchIndex()
        let retryingLibrary = FetchKitLibrary(documentStore: store, index: retryingIndex)
        let retryResult = try await retryingLibrary.retryPendingIndexSyncs()
        let pendingSyncsAfterRetry = try await retryingLibrary.pendingIndexSyncs()
        let appliedChangesets = await retryingIndex.appliedChangesets

        #expect(retryResult.count == 1)
        #expect(retryResult.affectedDocumentIDs == ["doc-apple"])
        #expect(pendingSyncsAfterRetry.isEmpty)
        #expect(appliedChangesets.count == 1)
        #expect(appliedChangesets[0].upsertedDocuments == [record.indexDocument])
    }

    #if os(macOS)
    @Test("Persistent FetchKitLibrary configuration resolves a concrete directory layout")
    func persistentConfigurationResolvesConcreteDirectoryLayout() throws {
        let directoryURL = URL(fileURLWithPath: "/tmp/SwiftlyFetchTests", isDirectory: true)
        let configuration = FetchKitLibrary.PersistentConfiguration(
            location: .directory(directoryURL),
            storeFileName: "Corpus.sqlite",
            indexFileName: "Corpus.searchindex",
            indexNamePrefix: "SearchTests"
        )

        let paths = try configuration.resolvedPaths()

        #expect(paths.directoryURL == directoryURL)
        #expect(paths.storeURL == directoryURL.appendingPathComponent("Corpus.sqlite"))
        #expect(paths.indexURL == directoryURL.appendingPathComponent("Corpus.searchindex"))
    }

    @Test("Persistent FetchKitLibrary configuration defaults into Application Support")
    func persistentConfigurationDefaultsIntoApplicationSupport() throws {
        let configuration = FetchKitLibrary.PersistentConfiguration.default

        let paths = try configuration.resolvedPaths()

        #expect(paths.directoryURL.path.contains("/Library/Application Support/"))
        #expect(paths.directoryURL.lastPathComponent == "FetchKit")
        #expect(paths.storeURL.lastPathComponent == "FetchKit.sqlite")
        #expect(paths.indexURL.lastPathComponent == "FetchKit.searchindex")
    }
    #endif
}

private actor RecordingFetchDocumentStore: FetchDocumentStore {
    private(set) var upsertedRecords: [FetchDocumentRecord] = []
    private(set) var removedDocumentIDs: [FetchDocumentID] = []
    private(set) var storedDocuments: [FetchDocumentID: FetchDocumentRecord] = [:]
    private(set) var pendingSyncs: [FetchPendingIndexSyncID: FetchPendingIndexSync] = [:]
    private(set) var pendingSyncOrder: [FetchPendingIndexSyncID] = []

    func upsert(_ records: [FetchDocumentRecord]) async throws -> FetchStoreMutationResult {
        upsertedRecords.append(contentsOf: records)
        for record in records {
            storedDocuments[record.id] = record
        }

        return FetchStoreMutationResult(
            pendingIndexSync: makePendingSync(
                changeset: FetchIndexingChangeset(
                    records.map { .upsert($0.indexDocument) }
                )
            )
        )
    }

    func document(id: FetchDocumentID) async throws -> FetchDocumentRecord? {
        storedDocuments[id]
    }

    func removeDocuments(withIDs ids: [FetchDocumentID]) async throws -> FetchStoreMutationResult {
        removedDocumentIDs.append(contentsOf: ids)
        for id in ids {
            storedDocuments[id] = nil
        }

        return FetchStoreMutationResult(
            pendingIndexSync: makePendingSync(
                changeset: FetchIndexingChangeset(
                    ids.map { .remove($0) }
                )
            )
        )
    }

    func removeAllDocuments() async throws -> FetchStoreMutationResult {
        let removedIDs = Array(storedDocuments.keys)
        storedDocuments.removeAll()
        upsertedRecords.removeAll()
        removedDocumentIDs.removeAll()

        return FetchStoreMutationResult(
            pendingIndexSync: removedIDs.isEmpty ? nil : makePendingSync(
                changeset: FetchIndexingChangeset(
                    removedIDs.map { .remove($0) }
                )
            )
        )
    }

    func pendingIndexSyncs() async throws -> [FetchPendingIndexSync] {
        pendingSyncOrder.compactMap { pendingSyncs[$0] }
    }

    func removePendingIndexSyncs(withIDs ids: [FetchPendingIndexSyncID]) async throws {
        for id in ids {
            pendingSyncs[id] = nil
        }
        pendingSyncOrder.removeAll { ids.contains($0) }
    }

    private func makePendingSync(changeset: FetchIndexingChangeset) -> FetchPendingIndexSync {
        let pendingSync = FetchPendingIndexSync(
            id: FetchPendingIndexSyncID(UUID().uuidString),
            changeset: changeset
        )
        pendingSyncs[pendingSync.id] = pendingSync
        pendingSyncOrder.append(pendingSync.id)
        return pendingSync
    }
}

private actor RecordingFetchIndex: FetchIndex {
    private(set) var appliedChangesets: [FetchIndexingChangeset] = []
    private(set) var receivedQueries: [FetchSearchQuery] = []
    private let searchResults: [FetchSearchResult]

    init(searchResults: [FetchSearchResult] = []) {
        self.searchResults = searchResults
    }

    func apply(_ changeset: FetchIndexingChangeset) async throws {
        appliedChangesets.append(changeset)
    }

    func removeAllDocuments() async throws {
        appliedChangesets.removeAll()
        receivedQueries.removeAll()
    }

    func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult] {
        receivedQueries.append(query)
        return searchResults
    }
}

private actor FailingFetchIndex: FetchIndex {
    struct Failure: Error {}

    func apply(_ changeset: FetchIndexingChangeset) async throws {
        throw Failure()
    }

    func removeAllDocuments() async throws {}

    func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult] {
        []
    }
}
