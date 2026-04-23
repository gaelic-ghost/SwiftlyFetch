public enum FetchSearchKind: Hashable, Codable, Sendable {
    case naturalLanguage
    case allTerms
    case exactPhrase
    case prefix
}

public enum FetchSearchField: String, Hashable, Codable, Sendable, CaseIterable {
    case title
    case body
}

public struct FetchSearchQuery: Hashable, Codable, Sendable {
    public let text: String
    public let kind: FetchSearchKind
    public let fields: Set<FetchSearchField>
    public let limit: Int

    public init(
        _ text: String,
        kind: FetchSearchKind = .naturalLanguage,
        fields: Set<FetchSearchField> = Set(FetchSearchField.allCases),
        limit: Int = 10
    ) {
        self.text = text
        self.kind = kind
        self.fields = fields.isEmpty ? Set(FetchSearchField.allCases) : fields
        self.limit = max(0, limit)
    }
}

public struct FetchMatchRange: Hashable, Codable, Sendable {
    public let lowerBound: Int
    public let upperBound: Int

    public init(lowerBound: Int, upperBound: Int) {
        self.lowerBound = max(0, lowerBound)
        self.upperBound = max(self.lowerBound, upperBound)
    }
}

public struct FetchSnippet: Hashable, Codable, Sendable {
    public let text: String
    public let matchRanges: [FetchMatchRange]

    public init(text: String, matchRanges: [FetchMatchRange] = []) {
        self.text = text
        self.matchRanges = matchRanges
    }
}

public struct FetchSearchResult: Hashable, Codable, Sendable {
    public let document: FetchDocument
    public let score: Double
    public let snippet: FetchSnippet?

    public init(
        document: FetchDocument,
        score: Double,
        snippet: FetchSnippet? = nil
    ) {
        self.document = document
        self.score = score
        self.snippet = snippet
    }
}
