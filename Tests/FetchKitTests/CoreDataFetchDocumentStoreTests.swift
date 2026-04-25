import Foundation
import Testing
import FetchCore
@testable import FetchKit

@Suite("CoreDataFetchDocumentStore")
struct CoreDataFetchDocumentStoreTests {
    @Test("CoreDataFetchDocumentStore round-trips durable records with typed fields and metadata")
    func coreDataFetchDocumentStoreRoundTripsRecord() async throws {
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

        _ = try await store.upsert([record])
        let fetched = try await store.document(id: "doc-apple")

        #expect(fetched == record)
    }

    @Test("CoreDataFetchDocumentStore replaces metadata and field values on upsert")
    func coreDataFetchDocumentStoreReplacesMetadataOnUpsert() async throws {
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

        #expect(fetched == updated)
    }

    @Test("CoreDataFetchDocumentStore reuses one document row when the same ID appears twice in one batch")
    func coreDataFetchDocumentStoreHandlesDuplicateIDsInOneBatch() async throws {
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

        #expect(mutation.affectedDocumentIDs == ["doc-apple"])
        #expect(fetched == updated)
    }

    @Test("CoreDataFetchDocumentStore removes selected documents")
    func coreDataFetchDocumentStoreRemovesSelectedDocuments() async throws {
        let store = try await CoreDataFetchDocumentStore()
        _ = try await store.upsert([
            FetchDocumentRecord(id: "doc-apple", body: "Apple"),
            FetchDocumentRecord(id: "doc-orange", body: "Orange"),
        ])

        _ = try await store.removeDocuments(withIDs: ["doc-apple"])

        let removed = try await store.document(id: "doc-apple")
        let retained = try await store.document(id: "doc-orange")

        #expect(removed == nil)
        #expect(retained?.id == "doc-orange")
    }

    @Test("CoreDataFetchDocumentStore removes all stored documents")
    func coreDataFetchDocumentStoreRemovesAllDocuments() async throws {
        let store = try await CoreDataFetchDocumentStore()
        _ = try await store.upsert([
            FetchDocumentRecord(id: "doc-apple", body: "Apple"),
            FetchDocumentRecord(id: "doc-orange", body: "Orange"),
        ])

        _ = try await store.removeAllDocuments()

        #expect(try await store.document(id: "doc-apple") == nil)
        #expect(try await store.document(id: "doc-orange") == nil)
    }
}
