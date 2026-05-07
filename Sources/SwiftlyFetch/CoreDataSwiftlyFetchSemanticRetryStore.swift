import CoreData
import FetchCore
import Foundation

public actor CoreDataSwiftlyFetchSemanticRetryStore: SwiftlyFetchSemanticRetryStore {
    public struct Configuration: Hashable, Sendable {
        public enum Store: Hashable, Sendable {
            case inMemory
            case sqlite(URL)
        }

        public var store: Store

        public init(store: Store = .inMemory) {
            self.store = store
        }

        public static let inMemory = Configuration(store: .inMemory)
    }

    public enum StoreError: Error, LocalizedError {
        case loadFailed(String)
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
                case let .loadFailed(message):
                    "SwiftlyFetch could not load the semantic retry Core Data store. \(message)"
                case let .decodeFailed(message):
                    "SwiftlyFetch could not decode a persisted semantic retry record. \(message)"
            }
        }
    }

    private static let modelName = "SwiftlyFetchSemanticRetryStore"

    private let persistentContainer: NSPersistentContainer
    private let managedObjectContext: NSManagedObjectContext

    public init(configuration: Configuration = .inMemory) async throws {
        let persistentContainer = try await Self.makePersistentContainer(configuration: configuration)
        self.persistentContainer = persistentContainer
        managedObjectContext = Self.makeManagedObjectContext(using: persistentContainer)
    }

    private static func fetchStoredRetry(
        for documentID: FetchDocumentID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.retry.rawValue)
        request.predicate = NSPredicate(
            format: "%K == %@",
            RetryProperty.documentID.rawValue,
            documentID.rawValue
        )
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func makeRetry(from storedRetry: NSManagedObject) throws -> SwiftlyFetchSemanticRetry {
        guard let documentID = storedRetry.value(forKey: RetryProperty.documentID.rawValue) as? String,
              let operationRaw = storedRetry.value(forKey: RetryProperty.operation.rawValue) as? String,
              let operation = SwiftlyFetchSemanticRetryOperation(rawValue: operationRaw),
              let reason = storedRetry.value(forKey: RetryProperty.reason.rawValue) as? String,
              let createdAt = storedRetry.value(forKey: RetryProperty.createdAt.rawValue) as? Date
        else {
            throw StoreError.decodeFailed("A semantic retry entry is missing its document ID, operation, reason, or creation date.")
        }

        let attemptCount = (storedRetry.value(forKey: RetryProperty.attemptCount.rawValue) as? Int64).map(Int.init) ?? 0

        return SwiftlyFetchSemanticRetry(
            documentID: FetchDocumentID(documentID),
            operation: operation,
            reason: reason,
            attemptCount: attemptCount,
            createdAt: createdAt,
            lastAttemptAt: storedRetry.value(forKey: RetryProperty.lastAttemptAt.rawValue) as? Date,
            nextRetryAt: storedRetry.value(forKey: RetryProperty.nextRetryAt.rawValue) as? Date,
            lastFailure: storedRetry.value(forKey: RetryProperty.lastFailure.rawValue) as? String
        )
    }

    private static func retryEntity(in context: NSManagedObjectContext) -> NSEntityDescription {
        NSEntityDescription.entity(forEntityName: EntityName.retry.rawValue, in: context)!
    }

    private static func makeManagedObjectContext(using container: NSPersistentContainer) -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return context
    }

    private static func makePersistentContainer(configuration: Configuration) async throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: modelName, managedObjectModel: makeModel())
        let description: NSPersistentStoreDescription

        switch configuration.store {
            case .inMemory:
                description = NSPersistentStoreDescription()
                description.type = NSInMemoryStoreType
            case let .sqlite(url):
                description = NSPersistentStoreDescription(url: url)
                description.type = NSSQLiteStoreType
        }

        container.persistentStoreDescriptions = [description]

        return try await withCheckedThrowingContinuation { continuation in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(
                        throwing: StoreError.loadFailed(String(describing: error))
                    )
                } else {
                    continuation.resume(returning: container)
                }
            }
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let retryEntity = NSEntityDescription()
        retryEntity.name = EntityName.retry.rawValue
        retryEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        retryEntity.properties = [
            stringAttribute(RetryProperty.documentID.rawValue),
            stringAttribute(RetryProperty.operation.rawValue),
            stringAttribute(RetryProperty.reason.rawValue),
            integerAttribute(RetryProperty.attemptCount.rawValue),
            dateAttribute(RetryProperty.createdAt.rawValue),
            dateAttribute(RetryProperty.lastAttemptAt.rawValue, optional: true),
            dateAttribute(RetryProperty.nextRetryAt.rawValue, optional: true),
            stringAttribute(RetryProperty.lastFailure.rawValue, optional: true),
        ]
        retryEntity.uniquenessConstraints = [[RetryProperty.documentID.rawValue]]
        model.entities = [retryEntity]
        return model
    }

    private static func stringAttribute(_ name: String, optional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .stringAttributeType
        attribute.isOptional = optional
        return attribute
    }

    private static func integerAttribute(_ name: String) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .integer64AttributeType
        attribute.isOptional = false
        attribute.defaultValue = 0
        return attribute
    }

    private static func dateAttribute(_ name: String, optional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = .dateAttributeType
        attribute.isOptional = optional
        return attribute
    }

    public func upsert(_ retry: SwiftlyFetchSemanticRetry) async throws {
        try await performWrite { context in
            let storedRetry = try Self.fetchStoredRetry(for: retry.documentID, in: context)
                ?? NSManagedObject(entity: Self.retryEntity(in: context), insertInto: context)

            storedRetry.setValue(retry.documentID.rawValue, forKey: RetryProperty.documentID.rawValue)
            storedRetry.setValue(retry.operation.rawValue, forKey: RetryProperty.operation.rawValue)
            storedRetry.setValue(retry.reason, forKey: RetryProperty.reason.rawValue)
            storedRetry.setValue(Int64(retry.attemptCount), forKey: RetryProperty.attemptCount.rawValue)
            storedRetry.setValue(retry.createdAt, forKey: RetryProperty.createdAt.rawValue)
            storedRetry.setValue(retry.lastAttemptAt, forKey: RetryProperty.lastAttemptAt.rawValue)
            storedRetry.setValue(retry.nextRetryAt, forKey: RetryProperty.nextRetryAt.rawValue)
            storedRetry.setValue(retry.lastFailure, forKey: RetryProperty.lastFailure.rawValue)
        }
    }

    public func pendingRetries(limit: Int? = nil) async throws -> [SwiftlyFetchSemanticRetry] {
        try await performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.retry.rawValue)
            request.sortDescriptors = [
                NSSortDescriptor(key: RetryProperty.createdAt.rawValue, ascending: true),
                NSSortDescriptor(key: RetryProperty.documentID.rawValue, ascending: true),
            ]

            if let limit {
                request.fetchLimit = max(0, limit)
            }

            return try context.fetch(request).map(Self.makeRetry(from:))
        }
    }

    public func removeRetries(for documentIDs: [FetchDocumentID]) async throws {
        let uniqueIDs = Set(documentIDs)
        guard !uniqueIDs.isEmpty else {
            return
        }

        try await performWrite { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.retry.rawValue)
            request.predicate = NSPredicate(
                format: "%K IN %@",
                RetryProperty.documentID.rawValue,
                uniqueIDs.map(\.rawValue)
            )

            for storedRetry in try context.fetch(request) {
                context.delete(storedRetry)
            }
        }
    }

    private func performRead<T>(_ work: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        try await managedObjectContext.perform { [self] in
            try work(self.managedObjectContext)
        }
    }

    private func performWrite(_ work: @escaping @Sendable (NSManagedObjectContext) throws -> Void) async throws {
        try await managedObjectContext.perform { [self] in
            try work(self.managedObjectContext)
            if self.managedObjectContext.hasChanges {
                try self.managedObjectContext.save()
            }
        }
    }
}

private enum EntityName: String {
    case retry = "SwiftlyFetchSemanticRetry"
}

private enum RetryProperty: String {
    case documentID
    case operation
    case reason
    case attemptCount
    case createdAt
    case lastAttemptAt
    case nextRetryAt
    case lastFailure
}
