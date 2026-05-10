import FetchCore
import RAGKit

public enum SwiftlyFetchMutationStageStatus: String, Hashable, Codable, Sendable {
    case succeeded
    case skipped
    case queuedRetry
    case failed
}

public struct SwiftlyFetchMutationStage: Hashable, Codable, Sendable {
    public var status: SwiftlyFetchMutationStageStatus
    public var failureDescription: String?

    public init(
        status: SwiftlyFetchMutationStageStatus,
        failureDescription: String? = nil
    ) {
        self.status = status
        self.failureDescription = failureDescription
    }

    public static let succeeded = SwiftlyFetchMutationStage(status: .succeeded)
    public static let skipped = SwiftlyFetchMutationStage(status: .skipped)
}

public struct SwiftlyFetchSemanticMutationStage: Hashable, Codable, Sendable {
    public var status: SwiftlyFetchMutationStageStatus
    public var state: SemanticIndexState?
    public var retry: SwiftlyFetchSemanticRetry?
    public var failureDescription: String?

    public init(
        status: SwiftlyFetchMutationStageStatus,
        state: SemanticIndexState? = nil,
        retry: SwiftlyFetchSemanticRetry? = nil,
        failureDescription: String? = nil
    ) {
        self.status = status
        self.state = state
        self.retry = retry
        self.failureDescription = failureDescription
    }

    public static func succeeded(state: SemanticIndexState? = nil) -> SwiftlyFetchSemanticMutationStage {
        SwiftlyFetchSemanticMutationStage(status: .succeeded, state: state)
    }

    public static let skipped = SwiftlyFetchSemanticMutationStage(status: .skipped)
}

public struct SwiftlyFetchMutationResult: Hashable, Codable, Sendable {
    public var documentIDs: [FetchDocumentID]
    public var conventional: SwiftlyFetchMutationStage
    public var semantic: SwiftlyFetchSemanticMutationStage

    public init(
        documentIDs: [FetchDocumentID],
        conventional: SwiftlyFetchMutationStage,
        semantic: SwiftlyFetchSemanticMutationStage
    ) {
        self.documentIDs = documentIDs
        self.conventional = conventional
        self.semantic = semantic
    }
}
