import FetchCore
import Foundation

public enum SwiftlyFetchSemanticRetryOperation: String, Hashable, Codable, Sendable {
    case indexDocument
    case removeDocument
}

public struct SwiftlyFetchSemanticRetry: Hashable, Codable, Sendable {
    public var documentID: FetchDocumentID
    public var operation: SwiftlyFetchSemanticRetryOperation
    public var reason: String
    public var attemptCount: Int
    public var createdAt: Date
    public var lastAttemptAt: Date?
    public var nextRetryAt: Date?
    public var lastFailure: String?

    public init(
        documentID: FetchDocumentID,
        operation: SwiftlyFetchSemanticRetryOperation,
        reason: String,
        attemptCount: Int = 0,
        createdAt: Date = .now,
        lastAttemptAt: Date? = nil,
        nextRetryAt: Date? = nil,
        lastFailure: String? = nil
    ) {
        self.documentID = documentID
        self.operation = operation
        self.reason = reason
        self.attemptCount = max(0, attemptCount)
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.nextRetryAt = nextRetryAt
        self.lastFailure = lastFailure
    }
}

public protocol SwiftlyFetchSemanticRetryStore: Sendable {
    func upsert(_ retry: SwiftlyFetchSemanticRetry) async throws
    func pendingRetries(limit: Int?) async throws -> [SwiftlyFetchSemanticRetry]
    func removeRetries(for documentIDs: [FetchDocumentID]) async throws
}

public actor InMemorySwiftlyFetchSemanticRetryStore: SwiftlyFetchSemanticRetryStore {
    private var retriesByDocumentID: [FetchDocumentID: SwiftlyFetchSemanticRetry] = [:]
    private var documentIDOrder: [FetchDocumentID] = []

    public init() {}

    public func upsert(_ retry: SwiftlyFetchSemanticRetry) async throws {
        if retriesByDocumentID[retry.documentID] == nil {
            documentIDOrder.append(retry.documentID)
        }

        retriesByDocumentID[retry.documentID] = retry
    }

    public func pendingRetries(limit: Int? = nil) async throws -> [SwiftlyFetchSemanticRetry] {
        let retries = documentIDOrder.compactMap { retriesByDocumentID[$0] }
        return limit.map { Array(retries.prefix(max(0, $0))) } ?? retries
    }

    public func removeRetries(for documentIDs: [FetchDocumentID]) async throws {
        let documentIDSet = Set(documentIDs)

        for documentID in documentIDSet {
            retriesByDocumentID[documentID] = nil
        }

        documentIDOrder.removeAll { documentIDSet.contains($0) }
    }
}

public struct SwiftlyFetchSemanticRetryResult: Hashable, Codable, Sendable {
    public var completedDocumentIDs: [FetchDocumentID]
    public var removedMissingDocumentIDs: [FetchDocumentID]
    public var deferredDocumentIDs: [FetchDocumentID]
    public var failedRetries: [SwiftlyFetchSemanticRetry]

    public init(
        completedDocumentIDs: [FetchDocumentID],
        removedMissingDocumentIDs: [FetchDocumentID] = [],
        deferredDocumentIDs: [FetchDocumentID] = [],
        failedRetries: [SwiftlyFetchSemanticRetry] = []
    ) {
        self.completedDocumentIDs = completedDocumentIDs
        self.removedMissingDocumentIDs = removedMissingDocumentIDs
        self.deferredDocumentIDs = deferredDocumentIDs
        self.failedRetries = failedRetries
    }

    public var count: Int {
        completedDocumentIDs.count + removedMissingDocumentIDs.count
    }
}
