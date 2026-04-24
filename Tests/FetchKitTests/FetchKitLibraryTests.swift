import Testing
import FetchCore
@testable import FetchKit

@Suite("FetchKitLibrary")
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
    }
}

private actor RecordingFetchDocumentStore: FetchDocumentStore {
    private(set) var upsertedRecords: [FetchDocumentRecord] = []
    private(set) var removedDocumentIDs: [FetchDocumentID] = []
    private(set) var storedDocuments: [FetchDocumentID: FetchDocumentRecord] = [:]

    func upsert(_ records: [FetchDocumentRecord]) async throws {
        upsertedRecords.append(contentsOf: records)
        for record in records {
            storedDocuments[record.id] = record
        }
    }

    func document(id: FetchDocumentID) async throws -> FetchDocumentRecord? {
        storedDocuments[id]
    }

    func removeDocuments(withIDs ids: [FetchDocumentID]) async throws {
        removedDocumentIDs.append(contentsOf: ids)
        for id in ids {
            storedDocuments[id] = nil
        }
    }

    func removeAllDocuments() async throws {
        storedDocuments.removeAll()
        upsertedRecords.removeAll()
        removedDocumentIDs.removeAll()
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
