@preconcurrency import CoreData
import Foundation
import RAGCore

public actor CoreDataVectorIndex: VectorIndex, SemanticIndexStateStore {
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
        case encodeFailed(String)
        case decodeFailed(String)

        public var errorDescription: String? {
            switch self {
                case let .loadFailed(message):
                    "RAGKit could not load the Core Data vector index store. \(message)"
                case let .encodeFailed(message):
                    "RAGKit could not encode a semantic index record for persistence. \(message)"
                case let .decodeFailed(message):
                    "RAGKit could not decode a persisted semantic index record. \(message)"
            }
        }
    }

    private static let modelName = "RAGKitVectorIndex"

    private let persistentContainer: NSPersistentContainer
    private let managedObjectContext: NSManagedObjectContext

    public init(configuration: Configuration = .inMemory) async throws {
        let persistentContainer = try await Self.makePersistentContainer(configuration: configuration)
        self.persistentContainer = persistentContainer
        managedObjectContext = Self.makeManagedObjectContext(using: persistentContainer)
    }

    private static func fetchStoredChunks(
        matching ids: [String],
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.indexedChunk.rawValue)
        request.predicate = NSPredicate(format: "%K IN %@", StoredChunkProperty.id.rawValue, ids)
        return try context.fetch(request)
    }

    private static func apply(
        indexedChunk: IndexedChunk,
        to storedChunk: NSManagedObject
    ) throws {
        storedChunk.setValue(indexedChunk.chunk.id.rawValue, forKey: StoredChunkProperty.id.rawValue)
        storedChunk.setValue(indexedChunk.chunk.documentID.rawValue, forKey: StoredChunkProperty.documentID.rawValue)
        storedChunk.setValue(indexedChunk.chunk.text, forKey: StoredChunkProperty.text.rawValue)
        storedChunk.setValue(Int64(indexedChunk.chunk.position.chunkIndex), forKey: StoredChunkProperty.chunkIndex.rawValue)
        storedChunk.setValue(Int64(indexedChunk.chunk.position.startOffset), forKey: StoredChunkProperty.startOffset.rawValue)
        storedChunk.setValue(Int64(indexedChunk.chunk.position.endOffset), forKey: StoredChunkProperty.endOffset.rawValue)
        try storedChunk.setValue(encode(indexedChunk.chunk.metadata), forKey: StoredChunkProperty.metadataData.rawValue)
        try storedChunk.setValue(encode(indexedChunk.embedding), forKey: StoredChunkProperty.embeddingData.rawValue)
        storedChunk.setValue(Date(), forKey: StoredChunkProperty.updatedAt.rawValue)
    }

    private static func makeIndexedChunk(from storedChunk: NSManagedObject) throws -> IndexedChunk {
        guard
            let id = storedChunk.value(forKey: StoredChunkProperty.id.rawValue) as? String,
            let documentID = storedChunk.value(forKey: StoredChunkProperty.documentID.rawValue) as? String,
            let text = storedChunk.value(forKey: StoredChunkProperty.text.rawValue) as? String,
            let metadataData = storedChunk.value(forKey: StoredChunkProperty.metadataData.rawValue) as? Data,
            let embeddingData = storedChunk.value(forKey: StoredChunkProperty.embeddingData.rawValue) as? Data
        else {
            throw StoreError.decodeFailed("A persisted semantic chunk is missing one or more required fields.")
        }

        let chunkIndex = intValue(for: StoredChunkProperty.chunkIndex, in: storedChunk)
        let startOffset = intValue(for: StoredChunkProperty.startOffset, in: storedChunk)
        let endOffset = intValue(for: StoredChunkProperty.endOffset, in: storedChunk)
        let documentIDValue = DocumentID(documentID)

        let chunk = try Chunk(
            id: ChunkID(id),
            documentID: documentIDValue,
            text: text,
            metadata: decode(ChunkMetadata.self, from: metadataData),
            position: ChunkPosition(
                documentID: documentIDValue,
                chunkIndex: chunkIndex,
                startOffset: startOffset,
                endOffset: endOffset
            )
        )

        return try IndexedChunk(
            chunk: chunk,
            embedding: decode(EmbeddingVector.self, from: embeddingData)
        )
    }

    private static func fetchStoredState(
        for documentID: DocumentID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.semanticState.rawValue)
        request.fetchLimit = 1
        request.predicate = NSPredicate(
            format: "%K == %@",
            SemanticStateProperty.documentID.rawValue,
            documentID.rawValue
        )
        return try context.fetch(request).first
    }

    private static func fetchStoredStates(
        for documentIDs: [DocumentID],
        in context: NSManagedObjectContext
    ) throws -> [NSManagedObject] {
        guard !documentIDs.isEmpty else {
            return []
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.semanticState.rawValue)
        request.predicate = NSPredicate(
            format: "%K IN %@",
            SemanticStateProperty.documentID.rawValue,
            documentIDs.map(\.rawValue)
        )
        return try context.fetch(request)
    }

    private static func upsertState(
        documentID: DocumentID,
        status: SemanticIndexStatus,
        fingerprint: SemanticIndexFingerprint?,
        lastIndexedAt: Date?,
        lastFailure: String?,
        in context: NSManagedObjectContext
    ) throws {
        let storedState = try fetchStoredState(for: documentID, in: context)
            ?? NSEntityDescription.insertNewObject(
                forEntityName: EntityName.semanticState.rawValue,
                into: context
            )

        storedState.setValue(documentID.rawValue, forKey: SemanticStateProperty.documentID.rawValue)
        storedState.setValue(status.rawValue, forKey: SemanticStateProperty.statusRaw.rawValue)
        try storedState.setValue(fingerprint.map(encode), forKey: SemanticStateProperty.fingerprintData.rawValue)
        storedState.setValue(lastIndexedAt, forKey: SemanticStateProperty.lastIndexedAt.rawValue)
        storedState.setValue(lastFailure, forKey: SemanticStateProperty.lastFailure.rawValue)
        storedState.setValue(Date(), forKey: SemanticStateProperty.updatedAt.rawValue)
    }

    private static func makeSemanticIndexState(from storedState: NSManagedObject) throws -> SemanticIndexState {
        guard
            let documentID = storedState.value(forKey: SemanticStateProperty.documentID.rawValue) as? String,
            let statusRaw = storedState.value(forKey: SemanticStateProperty.statusRaw.rawValue) as? String
        else {
            throw StoreError.decodeFailed("A persisted semantic index state is missing one or more required fields.")
        }

        let fingerprint: SemanticIndexFingerprint?
        if let fingerprintData = storedState.value(forKey: SemanticStateProperty.fingerprintData.rawValue) as? Data {
            fingerprint = try decode(SemanticIndexFingerprint.self, from: fingerprintData)
        } else {
            fingerprint = nil
        }

        let status = SemanticIndexStatus(rawValue: statusRaw) ?? .failed
        let updatedAt = (storedState.value(forKey: SemanticStateProperty.updatedAt.rawValue) as? Date) ?? .distantPast

        return SemanticIndexState(
            documentID: DocumentID(documentID),
            status: status,
            fingerprint: fingerprint,
            lastIndexedAt: storedState.value(forKey: SemanticStateProperty.lastIndexedAt.rawValue) as? Date,
            lastFailure: storedState.value(forKey: SemanticStateProperty.lastFailure.rawValue) as? String,
            updatedAt: updatedAt
        )
    }

    private static func intValue(
        for property: StoredChunkProperty,
        in storedChunk: NSManagedObject
    ) -> Int {
        if let value = storedChunk.value(forKey: property.rawValue) as? Int {
            return value
        }

        if let value = storedChunk.value(forKey: property.rawValue) as? Int64 {
            return Int(value)
        }

        return 0
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw StoreError.encodeFailed(error.localizedDescription)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
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

        let indexedChunkEntity = NSEntityDescription()
        indexedChunkEntity.name = EntityName.indexedChunk.rawValue
        indexedChunkEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        indexedChunkEntity.properties = [
            makeAttribute(name: StoredChunkProperty.id.rawValue, type: .stringAttributeType),
            makeAttribute(name: StoredChunkProperty.documentID.rawValue, type: .stringAttributeType),
            makeAttribute(name: StoredChunkProperty.text.rawValue, type: .stringAttributeType),
            makeAttribute(name: StoredChunkProperty.metadataData.rawValue, type: .binaryDataAttributeType),
            makeAttribute(name: StoredChunkProperty.embeddingData.rawValue, type: .binaryDataAttributeType),
            makeAttribute(name: StoredChunkProperty.chunkIndex.rawValue, type: .integer64AttributeType),
            makeAttribute(name: StoredChunkProperty.startOffset.rawValue, type: .integer64AttributeType),
            makeAttribute(name: StoredChunkProperty.endOffset.rawValue, type: .integer64AttributeType),
            makeAttribute(name: StoredChunkProperty.updatedAt.rawValue, type: .dateAttributeType),
        ]
        indexedChunkEntity.uniquenessConstraints = [[StoredChunkProperty.id.rawValue]]

        let semanticStateEntity = NSEntityDescription()
        semanticStateEntity.name = EntityName.semanticState.rawValue
        semanticStateEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        semanticStateEntity.properties = [
            makeAttribute(name: SemanticStateProperty.documentID.rawValue, type: .stringAttributeType),
            makeAttribute(name: SemanticStateProperty.statusRaw.rawValue, type: .stringAttributeType),
            makeAttribute(name: SemanticStateProperty.fingerprintData.rawValue, type: .binaryDataAttributeType, isOptional: true),
            makeAttribute(name: SemanticStateProperty.lastIndexedAt.rawValue, type: .dateAttributeType, isOptional: true),
            makeAttribute(name: SemanticStateProperty.lastFailure.rawValue, type: .stringAttributeType, isOptional: true),
            makeAttribute(name: SemanticStateProperty.updatedAt.rawValue, type: .dateAttributeType),
        ]
        semanticStateEntity.uniquenessConstraints = [[SemanticStateProperty.documentID.rawValue]]

        model.entities = [indexedChunkEntity, semanticStateEntity]
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

    public func upsert(_ chunks: [IndexedChunk]) async throws {
        guard !chunks.isEmpty else {
            return
        }

        try await performWrite { context in
            let existingChunks = try Self.fetchStoredChunks(
                matching: chunks.map(\.chunk.id.rawValue),
                in: context
            )
            var existingByID: [String: NSManagedObject] = Dictionary(
                uniqueKeysWithValues: existingChunks.compactMap { storedChunk in
                    guard let id = storedChunk.value(forKey: StoredChunkProperty.id.rawValue) as? String else {
                        return nil
                    }

                    return (id, storedChunk)
                }
            )

            for indexedChunk in chunks {
                let storedChunk = existingByID[indexedChunk.chunk.id.rawValue]
                    ?? NSEntityDescription.insertNewObject(
                        forEntityName: EntityName.indexedChunk.rawValue,
                        into: context
                    )
                existingByID[indexedChunk.chunk.id.rawValue] = storedChunk
                try Self.apply(indexedChunk: indexedChunk, to: storedChunk)
            }
        }
    }

    public func search(_ query: SearchQuery, embedding: EmbeddingVector) async throws -> [SearchResult] {
        guard query.limit > 0 else {
            return []
        }

        let indexedChunks = try await performRead { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.indexedChunk.rawValue)
            return try context.fetch(request).map(Self.makeIndexedChunk)
        }

        let ranked = indexedChunks.compactMap { indexedChunk -> SearchResult? in
            if let filter = query.filter, !filter.matches(indexedChunk.chunk.metadata) {
                return nil
            }

            let score = embedding.cosineSimilarity(to: indexedChunk.embedding)
            return SearchResult(chunk: indexedChunk.chunk, score: score)
        }

        return ranked
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.chunk.id.rawValue < rhs.chunk.id.rawValue
                }

                return lhs.score > rhs.score
            }
            .prefix(query.limit)
            .map { $0 }
    }

    public func removeChunks(for documentID: DocumentID) async throws {
        try await performWrite { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.indexedChunk.rawValue)
            request.predicate = NSPredicate(
                format: "%K == %@",
                StoredChunkProperty.documentID.rawValue,
                documentID.rawValue
            )

            for storedChunk in try context.fetch(request) {
                context.delete(storedChunk)
            }

            try Self.upsertState(
                documentID: documentID,
                status: .missing,
                fingerprint: nil,
                lastIndexedAt: nil,
                lastFailure: nil,
                in: context
            )
        }
    }

    public func removeAll() async throws {
        try await performWrite { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: EntityName.indexedChunk.rawValue)
            for storedChunk in try context.fetch(request) {
                context.delete(storedChunk)
            }

            let stateRequest = NSFetchRequest<NSManagedObject>(entityName: EntityName.semanticState.rawValue)
            for storedState in try context.fetch(stateRequest) {
                context.delete(storedState)
            }
        }
    }

    public func state(for documentID: DocumentID) async throws -> SemanticIndexState? {
        try await performRead { context in
            try Self.fetchStoredState(for: documentID, in: context).map(Self.makeSemanticIndexState)
        }
    }

    public func states(for documentIDs: [DocumentID]) async throws -> [SemanticIndexState] {
        try await performRead { context in
            try Self.fetchStoredStates(for: documentIDs, in: context)
                .map(Self.makeSemanticIndexState)
                .sorted { $0.documentID.rawValue < $1.documentID.rawValue }
        }
    }

    public func markIndexing(documentID: DocumentID, fingerprint: SemanticIndexFingerprint) async throws {
        try await performWrite { context in
            try Self.upsertState(
                documentID: documentID,
                status: .indexing,
                fingerprint: fingerprint,
                lastIndexedAt: nil,
                lastFailure: nil,
                in: context
            )
        }
    }

    public func markCurrent(documentID: DocumentID, fingerprint: SemanticIndexFingerprint) async throws {
        try await performWrite { context in
            try Self.upsertState(
                documentID: documentID,
                status: .current,
                fingerprint: fingerprint,
                lastIndexedAt: Date(),
                lastFailure: nil,
                in: context
            )
        }
    }

    public func markStale(documentID: DocumentID, reason: String?) async throws {
        try await performWrite { context in
            let currentState = try Self.fetchStoredState(for: documentID, in: context)
                .map(Self.makeSemanticIndexState)
            try Self.upsertState(
                documentID: documentID,
                status: .stale,
                fingerprint: currentState?.fingerprint,
                lastIndexedAt: currentState?.lastIndexedAt,
                lastFailure: reason,
                in: context
            )
        }
    }

    public func markFailed(
        documentID: DocumentID,
        fingerprint: SemanticIndexFingerprint?,
        reason: String
    ) async throws {
        try await performWrite { context in
            let currentState = try Self.fetchStoredState(for: documentID, in: context)
                .map(Self.makeSemanticIndexState)
            try Self.upsertState(
                documentID: documentID,
                status: .failed,
                fingerprint: fingerprint ?? currentState?.fingerprint,
                lastIndexedAt: currentState?.lastIndexedAt,
                lastFailure: reason,
                in: context
            )
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
}

private enum EntityName: String {
    case indexedChunk = "RAGIndexedChunk"
    case semanticState = "RAGSemanticIndexState"
}

private enum StoredChunkProperty: String {
    case id
    case documentID
    case text
    case metadataData
    case embeddingData
    case chunkIndex
    case startOffset
    case endOffset
    case updatedAt
}

private enum SemanticStateProperty: String {
    case documentID
    case statusRaw
    case fingerprintData
    case lastIndexedAt
    case lastFailure
    case updatedAt
}
