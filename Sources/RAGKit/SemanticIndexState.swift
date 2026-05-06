import Foundation
import RAGCore

public enum SemanticIndexStatus: String, Hashable, Codable, Sendable {
    case missing
    case indexing
    case current
    case stale
    case failed
}

public struct SemanticIndexFingerprint: Hashable, Codable, Sendable {
    public var source: String
    public var chunker: String
    public var embedder: String

    public init(
        source: String,
        chunker: String,
        embedder: String
    ) {
        self.source = source
        self.chunker = chunker
        self.embedder = embedder
    }
}

public struct SemanticIndexState: Hashable, Codable, Sendable {
    public var documentID: DocumentID
    public var status: SemanticIndexStatus
    public var fingerprint: SemanticIndexFingerprint?
    public var lastIndexedAt: Date?
    public var lastFailure: String?
    public var updatedAt: Date

    public init(
        documentID: DocumentID,
        status: SemanticIndexStatus,
        fingerprint: SemanticIndexFingerprint? = nil,
        lastIndexedAt: Date? = nil,
        lastFailure: String? = nil,
        updatedAt: Date = .now
    ) {
        self.documentID = documentID
        self.status = status
        self.fingerprint = fingerprint
        self.lastIndexedAt = lastIndexedAt
        self.lastFailure = lastFailure
        self.updatedAt = updatedAt
    }
}

public protocol SemanticIndexStateStore: Sendable {
    func state(for documentID: DocumentID) async throws -> SemanticIndexState?
    func states(for documentIDs: [DocumentID]) async throws -> [SemanticIndexState]
    func markIndexing(documentID: DocumentID, fingerprint: SemanticIndexFingerprint) async throws
    func markCurrent(documentID: DocumentID, fingerprint: SemanticIndexFingerprint) async throws
    func markStale(documentID: DocumentID, reason: String?) async throws
    func markFailed(
        documentID: DocumentID,
        fingerprint: SemanticIndexFingerprint?,
        reason: String
    ) async throws
}

public protocol SemanticFingerprintProviding: Sendable {
    var semanticFingerprint: String { get }
}
