import FetchCore
import Foundation

actor InMemoryFetchDocumentStore: FetchDocumentStore {
    private var storedDocuments: [FetchDocumentID: FetchDocumentRecord] = [:]
    private var pendingSyncs: [FetchPendingIndexSyncID: FetchPendingIndexSync] = [:]
    private var pendingSyncOrder: [FetchPendingIndexSyncID] = []

    func upsert(_ records: [FetchDocumentRecord]) async throws -> FetchStoreMutationResult {
        let changeset = FetchIndexingChangeset(
            records.map { .upsert($0.indexDocument) }
        )
        for record in records {
            storedDocuments[record.id] = record
        }

        let pendingSync = makePendingSyncIfNeeded(changeset: changeset)
        return FetchStoreMutationResult(pendingIndexSync: pendingSync)
    }

    func document(id: FetchDocumentID) async throws -> FetchDocumentRecord? {
        storedDocuments[id]
    }

    func removeDocuments(withIDs ids: [FetchDocumentID]) async throws -> FetchStoreMutationResult {
        let changeset = FetchIndexingChangeset(
            ids.map { .remove($0) }
        )
        for id in ids {
            storedDocuments[id] = nil
        }

        let pendingSync = makePendingSyncIfNeeded(changeset: changeset)
        return FetchStoreMutationResult(pendingIndexSync: pendingSync)
    }

    func removeAllDocuments() async throws -> FetchStoreMutationResult {
        let removedIDs = Array(storedDocuments.keys)
        let changeset = FetchIndexingChangeset(
            removedIDs.map { .remove($0) }
        )
        storedDocuments.removeAll()

        let pendingSync = makePendingSyncIfNeeded(changeset: changeset)
        return FetchStoreMutationResult(pendingIndexSync: pendingSync)
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

    private func makePendingSyncIfNeeded(changeset: FetchIndexingChangeset) -> FetchPendingIndexSync? {
        guard !changeset.isEmpty else {
            return nil
        }

        let pendingSync = FetchPendingIndexSync(
            id: FetchPendingIndexSyncID(UUID().uuidString),
            changeset: changeset
        )
        pendingSyncs[pendingSync.id] = pendingSync
        pendingSyncOrder.append(pendingSync.id)
        return pendingSync
    }
}
