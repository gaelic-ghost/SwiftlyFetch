import Foundation

public enum FetchIndexChange: Hashable, Codable, Sendable {
    case upsert(FetchIndexDocument)
    case remove(FetchDocumentID)
}

public struct FetchPendingIndexSyncID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    public var description: String {
        rawValue
    }
}

public struct FetchPendingIndexSync: Hashable, Codable, Sendable {
    public let id: FetchPendingIndexSyncID
    public let changeset: FetchIndexingChangeset
    public let createdAt: Date

    public init(
        id: FetchPendingIndexSyncID,
        changeset: FetchIndexingChangeset,
        createdAt: Date = .now
    ) {
        self.id = id
        self.changeset = changeset
        self.createdAt = createdAt
    }

    public var affectedDocumentIDs: [FetchDocumentID] {
        let upsertedIDs = changeset.upsertedDocuments.map(\.id)
        let removedIDs = changeset.removedDocumentIDs
        var seen = Set<FetchDocumentID>()
        return (upsertedIDs + removedIDs).filter { seen.insert($0).inserted }
    }
}

public struct FetchStoreMutationResult: Hashable, Codable, Sendable {
    public let pendingIndexSync: FetchPendingIndexSync?

    public init(pendingIndexSync: FetchPendingIndexSync?) {
        self.pendingIndexSync = pendingIndexSync
    }

    public var affectedDocumentIDs: [FetchDocumentID] {
        pendingIndexSync?.affectedDocumentIDs ?? []
    }

    public var isEmpty: Bool {
        pendingIndexSync?.changeset.isEmpty ?? true
    }
}

public struct FetchIndexingChangeset: Hashable, Codable, Sendable {
    public let changes: [FetchIndexChange]

    public init(_ changes: [FetchIndexChange]) {
        self.changes = changes
    }

    public var isEmpty: Bool {
        changes.isEmpty
    }

    public var upsertedDocuments: [FetchIndexDocument] {
        changes.compactMap { change in
            guard case .upsert(let document) = change else {
                return nil
            }
            return document
        }
    }

    public var removedDocumentIDs: [FetchDocumentID] {
        changes.compactMap { change in
            guard case .remove(let id) = change else {
                return nil
            }
            return id
        }
    }
}
