@preconcurrency import CoreData
import FetchCore
import Foundation

public actor CoreDataFetchDocumentStore: FetchDocumentStore {
    public struct Configuration: Hashable, Sendable {
        public enum Store: Hashable, Sendable {
            case inMemory
            case sqlite(URL)
        }

        public var store: Store

        public init(store: Store = .inMemory) {
            self.store = store
        }

        public static let inMemory = Configuration()
    }

    public enum StoreError: Error, LocalizedError {
        case loadFailed(String)
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
            case let .loadFailed(message):
                "FetchKit could not load the Core Data persistent store. \(message)"
            case let .decodeFailed(message):
                "FetchKit could not decode a persisted pending index sync operation. \(message)"
            }
        }
    }

    private static let modelName = "FetchKitStore"

    private let persistentContainer: NSPersistentContainer
    private let managedObjectContext: NSManagedObjectContext

    public init(configuration: Configuration = .inMemory) async throws {
        let persistentContainer = try await Self.makePersistentContainer(configuration: configuration)
        self.persistentContainer = persistentContainer
        self.managedObjectContext = Self.makeManagedObjectContext(using: persistentContainer)
    }

    public func upsert(_ records: [FetchDocumentRecord]) async throws -> FetchStoreMutationResult {
        guard !records.isEmpty else {
            return FetchStoreMutationResult(pendingIndexSync: nil)
        }

        let changeset = FetchIndexingChangeset(
            records.map { .upsert($0.indexDocument) }
        )

        let pendingSync = FetchPendingIndexSync(
            id: FetchPendingIndexSyncID(UUID().uuidString),
            changeset: changeset
        )

        try await performWrite { context in
            let existingDocuments = try Self.fetchStoredDocuments(
                matching: records.map(\.id.rawValue),
                in: context
            )
            var existingByID: [String: NSManagedObject] = Dictionary(
                uniqueKeysWithValues: existingDocuments.compactMap { document in
                    guard let id = document.value(forKey: StoredDocumentProperty.id.rawValue) as? String else {
                        return nil
                    }

                    return (id, document)
                }
            )

            for record in records {
                let document = existingByID[record.id.rawValue]
                    ?? NSEntityDescription.insertNewObject(
                        forEntityName: EntityName.document.rawValue,
                        into: context
                    )
                existingByID[record.id.rawValue] = document
                try Self.apply(record: record, to: document, in: context)
            }

            try Self.insertPendingSync(pendingSync, in: context)
        }

        return FetchStoreMutationResult(pendingIndexSync: pendingSync)
    }

    public func document(id: FetchDocumentID) async throws -> FetchDocumentRecord? {
        try await performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.document.rawValue)
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "%K == %@", StoredDocumentProperty.id.rawValue, id.rawValue)

            guard let document = try context.fetch(request).first else {
                return nil
            }

            return try Self.makeRecord(from: document)
        }
    }

    public func removeDocuments(withIDs ids: [FetchDocumentID]) async throws -> FetchStoreMutationResult {
        guard !ids.isEmpty else {
            return FetchStoreMutationResult(pendingIndexSync: nil)
        }

        let pendingSync = FetchPendingIndexSync(
            id: FetchPendingIndexSyncID(UUID().uuidString),
            changeset: FetchIndexingChangeset(
                ids.map { .remove($0) }
            )
        )

        try await performWrite { context in
            let documents = try Self.fetchStoredDocuments(
                matching: ids.map(\.rawValue),
                in: context
            )

            for document in documents {
                context.delete(document)
            }

            try Self.insertPendingSync(pendingSync, in: context)
        }

        return FetchStoreMutationResult(pendingIndexSync: pendingSync)
    }

    public func removeAllDocuments() async throws -> FetchStoreMutationResult {
        let removedIDs = try await performRead { context in
            let request = NSFetchRequest<NSDictionary>(entityName: EntityName.document.rawValue)
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = [StoredDocumentProperty.id.rawValue]

            let rows = try context.fetch(request)
            return rows.compactMap { row in
                (row[StoredDocumentProperty.id.rawValue] as? String).map { FetchDocumentID($0) }
            }
        }

        let pendingSync = removedIDs.isEmpty ? nil : FetchPendingIndexSync(
            id: FetchPendingIndexSyncID(UUID().uuidString),
            changeset: FetchIndexingChangeset(
                removedIDs.map { FetchIndexChange.remove($0) }
            )
        )

        try await performWrite { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.document.rawValue)
            let documents = try context.fetch(request)

            for document in documents {
                context.delete(document)
            }

            if let pendingSync {
                try Self.insertPendingSync(pendingSync, in: context)
            }
        }

        return FetchStoreMutationResult(pendingIndexSync: pendingSync)
    }

    public func pendingIndexSyncs() async throws -> [FetchPendingIndexSync] {
        try await performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.pendingSync.rawValue)
            request.sortDescriptors = [
                NSSortDescriptor(key: PendingSyncProperty.createdAt.rawValue, ascending: true),
            ]

            return try context.fetch(request).map(Self.makePendingSync)
        }
    }

    public func removePendingIndexSyncs(withIDs ids: [FetchPendingIndexSyncID]) async throws {
        guard !ids.isEmpty else {
            return
        }

        try await performWrite { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.pendingSync.rawValue)
            request.predicate = NSPredicate(
                format: "%K IN %@",
                PendingSyncProperty.id.rawValue,
                ids.map(\.rawValue)
            )

            for pendingSync in try context.fetch(request) {
                context.delete(pendingSync)
            }
        }
    }

    private func performRead<T: Sendable>(
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = managedObjectContext
        return try await context.perform {
            try operation(context)
        }
    }

    private func performWrite(
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void
    ) async throws {
        let context = managedObjectContext
        try await context.perform {
            do {
                try operation(context)

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    private static func fetchStoredDocuments(
        matching ids: [String],
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.document.rawValue)
        request.predicate = NSPredicate(format: "%K IN %@", StoredDocumentProperty.id.rawValue, ids)
        return try context.fetch(request)
    }

    private static func apply(
        record: FetchDocumentRecord,
        to document: NSManagedObject,
        in context: NSManagedObjectContext
    ) throws {
        document.setValue(record.id.rawValue, forKey: StoredDocumentProperty.id.rawValue)
        document.setValue(record.title, forKey: StoredDocumentProperty.title.rawValue)
        document.setValue(record.body, forKey: StoredDocumentProperty.body.rawValue)
        document.setValue(record.contentType.rawValue, forKey: StoredDocumentProperty.contentTypeRaw.rawValue)
        document.setValue(record.kind?.rawValue, forKey: StoredDocumentProperty.kindRaw.rawValue)
        document.setValue(record.language, forKey: StoredDocumentProperty.language.rawValue)
        document.setValue(record.sourceURI, forKey: StoredDocumentProperty.sourceURI.rawValue)
        document.setValue(record.createdAt, forKey: StoredDocumentProperty.createdAt.rawValue)
        document.setValue(record.updatedAt, forKey: StoredDocumentProperty.updatedAt.rawValue)
        document.setValue(record.lastIndexedAt, forKey: StoredDocumentProperty.lastIndexedAt.rawValue)

        let metadataSet = document.mutableSetValue(forKey: StoredDocumentProperty.metadataEntries.rawValue)
        for case let existingEntry as NSManagedObject in metadataSet {
            context.delete(existingEntry)
        }
        metadataSet.removeAllObjects()

        for key in record.metadata.keys.sorted() {
            let entry = NSEntityDescription.insertNewObject(
                forEntityName: EntityName.metadataEntry.rawValue,
                into: context
            )
            entry.setValue(key, forKey: MetadataEntryProperty.key.rawValue)
            entry.setValue(record.metadata[key], forKey: MetadataEntryProperty.value.rawValue)
            entry.setValue(document, forKey: MetadataEntryProperty.document.rawValue)
        }
    }

    private static func makeRecord(from document: NSManagedObject) throws -> FetchDocumentRecord {
        let metadataEntries = (document.value(forKey: StoredDocumentProperty.metadataEntries.rawValue) as? Set<NSManagedObject>) ?? []
        let metadata: [String: String] = Dictionary(uniqueKeysWithValues: metadataEntries.compactMap { entry in
            guard
                let key = entry.value(forKey: MetadataEntryProperty.key.rawValue) as? String,
                let value = entry.value(forKey: MetadataEntryProperty.value.rawValue) as? String
            else {
                return nil
            }

            return (key, value)
        })

        let contentTypeRaw = (document.value(forKey: StoredDocumentProperty.contentTypeRaw.rawValue) as? String) ?? FetchDocumentContentType.plainText.rawValue
        let kindRaw = document.value(forKey: StoredDocumentProperty.kindRaw.rawValue) as? String

        return FetchDocumentRecord(
            id: FetchDocumentID((document.value(forKey: StoredDocumentProperty.id.rawValue) as? String) ?? ""),
            title: document.value(forKey: StoredDocumentProperty.title.rawValue) as? String,
            body: (document.value(forKey: StoredDocumentProperty.body.rawValue) as? String) ?? "",
            contentType: FetchDocumentContentType(rawValue: contentTypeRaw) ?? .plainText,
            kind: kindRaw.flatMap(FetchDocumentKind.init(rawValue:)),
            language: document.value(forKey: StoredDocumentProperty.language.rawValue) as? String,
            sourceURI: document.value(forKey: StoredDocumentProperty.sourceURI.rawValue) as? String,
            createdAt: document.value(forKey: StoredDocumentProperty.createdAt.rawValue) as? Date,
            updatedAt: document.value(forKey: StoredDocumentProperty.updatedAt.rawValue) as? Date,
            metadata: metadata,
            lastIndexedAt: document.value(forKey: StoredDocumentProperty.lastIndexedAt.rawValue) as? Date
        )
    }

    private static func insertPendingSync(
        _ pendingSync: FetchPendingIndexSync,
        in context: NSManagedObjectContext
    ) throws {
        let entry = NSEntityDescription.insertNewObject(
            forEntityName: EntityName.pendingSync.rawValue,
            into: context
        )
        entry.setValue(pendingSync.id.rawValue, forKey: PendingSyncProperty.id.rawValue)
        entry.setValue(pendingSync.createdAt, forKey: PendingSyncProperty.createdAt.rawValue)
        entry.setValue(
            try JSONEncoder().encode(pendingSync.changeset),
            forKey: PendingSyncProperty.changesetData.rawValue
        )
    }

    private static func makePendingSync(from object: NSManagedObject) throws -> FetchPendingIndexSync {
        guard
            let id = object.value(forKey: PendingSyncProperty.id.rawValue) as? String,
            let createdAt = object.value(forKey: PendingSyncProperty.createdAt.rawValue) as? Date,
            let data = object.value(forKey: PendingSyncProperty.changesetData.rawValue) as? Data
        else {
            throw StoreError.decodeFailed("A pending sync entry is missing one or more required fields.")
        }

        do {
            return FetchPendingIndexSync(
                id: FetchPendingIndexSyncID(id),
                changeset: try JSONDecoder().decode(FetchIndexingChangeset.self, from: data),
                createdAt: createdAt
            )
        } catch {
            throw StoreError.decodeFailed(error.localizedDescription)
        }
    }

    private static func makePersistentContainer(configuration: Configuration) async throws -> NSPersistentContainer {
        let container = NSPersistentContainer(
            name: modelName,
            managedObjectModel: makeManagedObjectModel()
        )

        let description = NSPersistentStoreDescription()
        description.shouldAddStoreAsynchronously = false
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true

        switch configuration.store {
        case .inMemory:
            description.type = NSInMemoryStoreType
        case let .sqlite(url):
            description.type = NSSQLiteStoreType
            description.url = url
        }

        container.persistentStoreDescriptions = [description]

        return try await withCheckedThrowingContinuation { continuation in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(
                        throwing: StoreError.loadFailed(
                            error.localizedDescription
                        )
                    )
                } else {
                    continuation.resume(returning: container)
                }
            }
        }
    }

    private static func makeManagedObjectContext(using container: NSPersistentContainer) -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return context
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let documentEntity = NSEntityDescription()
        documentEntity.name = EntityName.document.rawValue
        documentEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        documentEntity.properties = [
            makeAttribute(name: StoredDocumentProperty.id.rawValue, type: .stringAttributeType),
            makeAttribute(name: StoredDocumentProperty.title.rawValue, type: .stringAttributeType, isOptional: true),
            makeAttribute(name: StoredDocumentProperty.body.rawValue, type: .stringAttributeType),
            makeAttribute(name: StoredDocumentProperty.contentTypeRaw.rawValue, type: .stringAttributeType),
            makeAttribute(name: StoredDocumentProperty.kindRaw.rawValue, type: .stringAttributeType, isOptional: true),
            makeAttribute(name: StoredDocumentProperty.language.rawValue, type: .stringAttributeType, isOptional: true),
            makeAttribute(name: StoredDocumentProperty.sourceURI.rawValue, type: .stringAttributeType, isOptional: true),
            makeAttribute(name: StoredDocumentProperty.createdAt.rawValue, type: .dateAttributeType, isOptional: true),
            makeAttribute(name: StoredDocumentProperty.updatedAt.rawValue, type: .dateAttributeType, isOptional: true),
            makeAttribute(name: StoredDocumentProperty.lastIndexedAt.rawValue, type: .dateAttributeType, isOptional: true),
        ]
        documentEntity.uniquenessConstraints = [[StoredDocumentProperty.id.rawValue]]

        let metadataEntryEntity = NSEntityDescription()
        metadataEntryEntity.name = EntityName.metadataEntry.rawValue
        metadataEntryEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        metadataEntryEntity.properties = [
            makeAttribute(name: MetadataEntryProperty.key.rawValue, type: .stringAttributeType),
            makeAttribute(name: MetadataEntryProperty.value.rawValue, type: .stringAttributeType),
        ]

        let metadataEntriesRelationship = NSRelationshipDescription()
        metadataEntriesRelationship.name = StoredDocumentProperty.metadataEntries.rawValue
        metadataEntriesRelationship.destinationEntity = metadataEntryEntity
        metadataEntriesRelationship.minCount = 0
        metadataEntriesRelationship.maxCount = 0
        metadataEntriesRelationship.deleteRule = .cascadeDeleteRule
        metadataEntriesRelationship.isOptional = true

        let documentRelationship = NSRelationshipDescription()
        documentRelationship.name = MetadataEntryProperty.document.rawValue
        documentRelationship.destinationEntity = documentEntity
        documentRelationship.minCount = 0
        documentRelationship.maxCount = 1
        documentRelationship.deleteRule = .nullifyDeleteRule
        documentRelationship.isOptional = true

        metadataEntriesRelationship.inverseRelationship = documentRelationship
        documentRelationship.inverseRelationship = metadataEntriesRelationship

        documentEntity.properties.append(metadataEntriesRelationship)
        metadataEntryEntity.properties.append(documentRelationship)

        let pendingSyncEntity = NSEntityDescription()
        pendingSyncEntity.name = EntityName.pendingSync.rawValue
        pendingSyncEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        pendingSyncEntity.properties = [
            makeAttribute(name: PendingSyncProperty.id.rawValue, type: .stringAttributeType),
            makeAttribute(name: PendingSyncProperty.createdAt.rawValue, type: .dateAttributeType),
            makeAttribute(name: PendingSyncProperty.changesetData.rawValue, type: .binaryDataAttributeType),
        ]
        pendingSyncEntity.uniquenessConstraints = [[PendingSyncProperty.id.rawValue]]

        model.entities = [documentEntity, metadataEntryEntity, pendingSyncEntity]
        return model
    }

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        isOptional: Bool = false
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        return attribute
    }
}

private enum EntityName: String {
    case document = "FetchStoredDocument"
    case metadataEntry = "FetchStoredDocumentMetadataEntry"
    case pendingSync = "FetchPendingIndexSyncOperation"
}

private enum StoredDocumentProperty: String {
    case id
    case title
    case body
    case contentTypeRaw
    case kindRaw
    case language
    case sourceURI
    case createdAt
    case updatedAt
    case lastIndexedAt
    case metadataEntries
}

private enum MetadataEntryProperty: String {
    case key
    case value
    case document
}

private enum PendingSyncProperty: String {
    case id
    case createdAt
    case changesetData
}
