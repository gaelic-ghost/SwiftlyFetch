import FetchCore

actor InMemoryFetchDocumentStore: FetchDocumentStore {
    private var storedDocuments: [FetchDocumentID: FetchDocumentRecord] = [:]

    func upsert(_ records: [FetchDocumentRecord]) async throws -> FetchStoreMutationResult {
        for record in records {
            storedDocuments[record.id] = record
        }

        return FetchStoreMutationResult(
            indexingChangeset: FetchIndexingChangeset(
                records.map { .upsert($0.indexDocument) }
            )
        )
    }

    func document(id: FetchDocumentID) async throws -> FetchDocumentRecord? {
        storedDocuments[id]
    }

    func removeDocuments(withIDs ids: [FetchDocumentID]) async throws -> FetchStoreMutationResult {
        for id in ids {
            storedDocuments[id] = nil
        }

        return FetchStoreMutationResult(
            indexingChangeset: FetchIndexingChangeset(
                ids.map { .remove($0) }
            )
        )
    }

    func removeAllDocuments() async throws -> FetchStoreMutationResult {
        let removedIDs = Array(storedDocuments.keys)
        storedDocuments.removeAll()

        return FetchStoreMutationResult(
            indexingChangeset: FetchIndexingChangeset(
                removedIDs.map { .remove($0) }
            )
        )
    }
}
