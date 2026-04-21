public enum ContextBudget: Hashable, Codable, Sendable {
    case characters(Int)
    case unlimited

    public func allows(_ currentCharacterCount: Int, adding nextCharacterCount: Int) -> Bool {
        switch self {
        case .characters(let limit):
            return currentCharacterCount + nextCharacterCount <= limit
        case .unlimited:
            return true
        }
    }
}

public enum ContextStyle: Hashable, Codable, Sendable {
    case plain
    case annotated
}
