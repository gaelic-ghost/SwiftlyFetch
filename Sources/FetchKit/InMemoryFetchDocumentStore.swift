import FetchCore

actor InMemoryFetchDocumentStore: FetchDocumentStore {
    private var storedDocuments: [FetchDocumentID: FetchDocumentRecord] = [:]

    func upsert(_ records: [FetchDocumentRecord]) async throws {
        for record in records {
            storedDocuments[record.id] = record
        }
    }

    func document(id: FetchDocumentID) async throws -> FetchDocumentRecord? {
        storedDocuments[id]
    }

    func removeDocuments(withIDs ids: [FetchDocumentID]) async throws {
        for id in ids {
            storedDocuments[id] = nil
        }
    }

    func removeAllDocuments() async throws {
        storedDocuments.removeAll()
    }
}
