public enum FetchIndexChange: Hashable, Codable, Sendable {
    case upsert(FetchIndexDocument)
    case remove(FetchDocumentID)
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
