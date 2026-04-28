import FetchCore
import Foundation
import XCTest
@testable import FetchKit

final class CoreDataFetchDocumentStoreTests: XCTestCase {
    func testCoreDataFetchDocumentStoreRoundTripsRecord() async throws {
        let store = try await CoreDataFetchDocumentStore()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let lastIndexedAt = Date(timeIntervalSince1970: 1_700_000_200)
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown,
            kind: .guide,
            language: "en",
            sourceURI: "file:///guides/apple.md",
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: [
                "category": "fruit",
                "series": "orchard",
            ],
            lastIndexedAt: lastIndexedAt
        )

        let mutation = try await store.upsert([record])
        let fetched = try await store.document(id: "doc-apple")
        let pendingSyncs = try await store.pendingIndexSyncs()

        XCTAssertEqual(fetched, record)
        XCTAssertEqual(mutation.pendingIndexSync?.changeset.upsertedDocuments, [record.indexDocument])
        XCTAssertEqual(pendingSyncs.count, 1)
    }

    func testCoreDataFetchDocumentStoreReplacesMetadataOnUpsert() async throws {
        let store = try await CoreDataFetchDocumentStore()
        let original = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown,
            metadata: [
                "category": "fruit",
                "series": "orchard",
            ]
        )
        let updated = FetchDocumentRecord(
            id: "doc-apple",
            title: "Updated Apple Guide",
            body: "Apples can be sweet or tart.",
            contentType: .plainText,
            kind: .reference,
            metadata: [
                "category": "reference",
            ]
        )

        _ = try await store.upsert([original])
        _ = try await store.upsert([updated])
        let fetched = try await store.document(id: "doc-apple")

        XCTAssertEqual(fetched, updated)
    }

    func testCoreDataFetchDocumentStoreHandlesDuplicateIDsInOneBatch() async throws {
        let store = try await CoreDataFetchDocumentStore()
        let original = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )
        let updated = FetchDocumentRecord(
            id: "doc-apple",
            title: "Updated Apple Guide",
            body: "Apples can be sweet or tart."
        )

        let mutation = try await store.upsert([original, updated])
        let fetched = try await store.document(id: "doc-apple")
        let pendingSyncs = try await store.pendingIndexSyncs()

        XCTAssertEqual(mutation.affectedDocumentIDs, ["doc-apple"])
        XCTAssertEqual(fetched, updated)
        XCTAssertEqual(pendingSyncs.count, 1)
    }

    func testCoreDataFetchDocumentStoreRemovesSelectedDocuments() async throws {
        let store = try await CoreDataFetchDocumentStore()
        _ = try await store.upsert([
            FetchDocumentRecord(id: "doc-apple", body: "Apple"),
            FetchDocumentRecord(id: "doc-orange", body: "Orange"),
        ])

        _ = try await store.removeDocuments(withIDs: ["doc-apple"])

        let removed = try await store.document(id: "doc-apple")
        let retained = try await store.document(id: "doc-orange")

        XCTAssertNil(removed)
        XCTAssertEqual(retained?.id, "doc-orange")
    }

    func testCoreDataFetchDocumentStoreRemovesAllDocuments() async throws {
        let store = try await CoreDataFetchDocumentStore()
        _ = try await store.upsert([
            FetchDocumentRecord(id: "doc-apple", body: "Apple"),
            FetchDocumentRecord(id: "doc-orange", body: "Orange"),
        ])

        _ = try await store.removeAllDocuments()

        let removedApple = try await store.document(id: "doc-apple")
        let removedOrange = try await store.document(id: "doc-orange")

        XCTAssertNil(removedApple)
        XCTAssertNil(removedOrange)
    }

    func testCoreDataFetchDocumentStorePersistsPendingSyncQueue() async throws {
        let store = try await CoreDataFetchDocumentStore()
        let record = FetchDocumentRecord(
            id: "doc-apple",
            title: "Apple Guide",
            body: "Apples are bright and crisp."
        )

        let mutation = try await store.upsert([record])
        let pendingBeforeAck = try await store.pendingIndexSyncs()

        XCTAssertEqual(pendingBeforeAck.count, 1)
        XCTAssertEqual(pendingBeforeAck[0].changeset.upsertedDocuments, [record.indexDocument])

        guard let pendingSync = mutation.pendingIndexSync else {
            XCTFail("Expected the store mutation to create a pending index sync.")
            return
        }

        try await store.removePendingIndexSyncs(withIDs: [pendingSync.id])

        let pendingAfterAck = try await store.pendingIndexSyncs()
        XCTAssertTrue(pendingAfterAck.isEmpty)
    }
}
