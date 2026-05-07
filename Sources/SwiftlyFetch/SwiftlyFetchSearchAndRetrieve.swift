import FetchCore
import RAGCore

public struct SwiftlyFetchSearchAndRetrieveQuery: Hashable, Codable, Sendable {
    public var conventional: FetchSearchQuery
    public var semantic: SearchQuery

    public init(
        conventional: FetchSearchQuery,
        semantic: SearchQuery
    ) {
        self.conventional = conventional
        self.semantic = semantic
    }
}

public struct SwiftlyFetchSearchAndRetrieveResult: Hashable, Codable, Sendable {
    public var conventional: [FetchSearchResult]
    public var semantic: [SearchResult]

    public init(
        conventional: [FetchSearchResult],
        semantic: [SearchResult]
    ) {
        self.conventional = conventional
        self.semantic = semantic
    }
}
