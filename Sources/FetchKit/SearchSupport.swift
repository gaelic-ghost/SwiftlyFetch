import FetchCore
import Foundation

enum FetchSearchSupport {
    static func normalizedTerms(from query: FetchSearchQuery) -> [String] {
        let normalizedText = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return []
        }

        let cleaned = normalizedText
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "&", with: " ")
            .replacingOccurrences(of: "*", with: " ")

        var seen = Set<String>()
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func exactPhraseText(from query: FetchSearchQuery) -> String {
        query.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .lowercased()
    }

    static func fieldWeight(for field: FetchSearchField) -> Double {
        switch field {
        case .title:
            1.2
        case .body:
            1.0
        }
    }

    static func queryKindWeight(for kind: FetchSearchKind) -> Double {
        switch kind {
        case .exactPhrase:
            1.3
        case .prefix:
            1.1
        case .allTerms:
            1.0
        case .naturalLanguage:
            0.95
        }
    }

    static func buildSnippet(
        from text: String,
        query: FetchSearchQuery,
        preferredLength: Int = 120,
        leadingContext: Int = 36
    ) -> FetchSnippet? {
        let terms = normalizedTerms(from: query)
        guard !terms.isEmpty else {
            return nil
        }

        let matches = allMatches(in: text, terms: terms)
        guard !matches.isEmpty else {
            return FetchSnippet(text: fallbackSnippetText(from: text, limit: preferredLength))
        }

        let snippetBounds = bestSnippetBounds(
            in: text,
            matches: matches,
            preferredLength: preferredLength,
            leadingContext: leadingContext
        )
        let snippetText = truncatedSnippetText(
            from: text,
            bounds: snippetBounds
        )
        let matchRanges = matches.compactMap { snippetRange(for: $0, within: snippetBounds, in: text) }

        return FetchSnippet(
            text: snippetText,
            matchRanges: matchRanges
        )
    }

    private static func allMatches(in text: String, terms: [String]) -> [TermMatch] {
        let lowercaseText = text.lowercased()
        var matches: [TermMatch] = []

        for term in terms {
            var searchStart = lowercaseText.startIndex

            while searchStart < lowercaseText.endIndex,
                  let range = lowercaseText.range(of: term, range: searchStart..<lowercaseText.endIndex) {
                let lowerBound = lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound)
                let upperBound = lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound)
                matches.append(
                    TermMatch(
                        term: term,
                        lowerBound: lowerBound,
                        upperBound: upperBound
                    )
                )
                searchStart = range.upperBound
            }
        }

        return matches.sorted {
            if $0.lowerBound == $1.lowerBound {
                return $0.upperBound < $1.upperBound
            }

            return $0.lowerBound < $1.lowerBound
        }
    }

    private static func bestSnippetBounds(
        in text: String,
        matches: [TermMatch],
        preferredLength: Int,
        leadingContext: Int
    ) -> Range<String.Index> {
        let textCount = text.count
        var bestWindow: SnippetWindow?

        for anchor in matches {
            let proposedStart = max(0, anchor.lowerBound - leadingContext)
            let proposedEnd = min(textCount, max(anchor.upperBound, proposedStart + preferredLength))
            let candidate = evaluateWindow(
                in: text,
                matches: matches,
                startOffset: proposedStart,
                endOffset: proposedEnd
            )

            if bestWindow.map({ candidate.isBetter(than: $0) }) ?? true {
                bestWindow = candidate
            }
        }

        let selected = bestWindow ?? evaluateWindow(
            in: text,
            matches: matches,
            startOffset: 0,
            endOffset: min(textCount, preferredLength)
        )

        return selected.range
    }

    private static func evaluateWindow(
        in text: String,
        matches: [TermMatch],
        startOffset: Int,
        endOffset: Int
    ) -> SnippetWindow {
        let adjustedStart = adjustSnippetStart(in: text, offset: startOffset)
        let adjustedEnd = adjustSnippetEnd(in: text, offset: endOffset)
        let range = text.index(text.startIndex, offsetBy: adjustedStart)..<text.index(text.startIndex, offsetBy: adjustedEnd)
        let includedMatches = matches.filter { $0.lowerBound < adjustedEnd && $0.upperBound > adjustedStart }
        let distinctTerms = Set(includedMatches.map(\.term)).count

        return SnippetWindow(
            range: range,
            startOffset: adjustedStart,
            endOffset: adjustedEnd,
            distinctTermCount: distinctTerms,
            totalMatchCount: includedMatches.count
        )
    }

    private static func adjustSnippetStart(in text: String, offset: Int) -> Int {
        guard offset > 0 else {
            return 0
        }

        var current = offset
        while current > 0 {
            let index = text.index(text.startIndex, offsetBy: current)
            let character = text[text.index(before: index)]
            if character.isWhitespace || character.isSentenceBoundaryPunctuation {
                break
            }
            current -= 1
        }

        return current
    }

    private static func adjustSnippetEnd(in text: String, offset: Int) -> Int {
        guard offset < text.count else {
            return text.count
        }

        var current = offset
        while current < text.count {
            let index = text.index(text.startIndex, offsetBy: current)
            let character = text[index]
            if character.isWhitespace || character.isSentenceBoundaryPunctuation {
                break
            }
            current += 1
        }

        return current
    }

    private static func snippetRange(
        for match: TermMatch,
        within snippetBounds: Range<String.Index>,
        in text: String
    ) -> FetchMatchRange? {
        let snippetStartOffset = text.distance(from: text.startIndex, to: snippetBounds.lowerBound)
        let snippetEndOffset = text.distance(from: text.startIndex, to: snippetBounds.upperBound)

        guard match.lowerBound < snippetEndOffset, match.upperBound > snippetStartOffset else {
            return nil
        }

        let clampedLower = max(match.lowerBound, snippetStartOffset)
        let clampedUpper = min(match.upperBound, snippetEndOffset)

        return FetchMatchRange(
            lowerBound: clampedLower - snippetStartOffset,
            upperBound: clampedUpper - snippetStartOffset
        )
    }

    private static func fallbackSnippetText(from text: String, limit: Int) -> String {
        let prefix = String(text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else {
            return prefix
        }

        return prefix + "…"
    }

    private static func truncatedSnippetText(
        from text: String,
        bounds: Range<String.Index>
    ) -> String {
        let hasLeadingOmission = bounds.lowerBound > text.startIndex
        let hasTrailingOmission = bounds.upperBound < text.endIndex
        let base = String(text[bounds]).trimmingCharacters(in: .whitespacesAndNewlines)

        var snippet = base
        if hasLeadingOmission {
            snippet = "…" + snippet
        }
        if hasTrailingOmission {
            snippet += "…"
        }

        return snippet
    }
}

private struct TermMatch {
    let term: String
    let lowerBound: Int
    let upperBound: Int
}

private struct SnippetWindow {
    let range: Range<String.Index>
    let startOffset: Int
    let endOffset: Int
    let distinctTermCount: Int
    let totalMatchCount: Int

    func isBetter(than other: SnippetWindow) -> Bool {
        if distinctTermCount != other.distinctTermCount {
            return distinctTermCount > other.distinctTermCount
        }

        if totalMatchCount != other.totalMatchCount {
            return totalMatchCount > other.totalMatchCount
        }

        if startOffset != other.startOffset {
            return startOffset < other.startOffset
        }

        return (endOffset - startOffset) < (other.endOffset - other.startOffset)
    }
}

private extension Character {
    var isSentenceBoundaryPunctuation: Bool {
        self == "." || self == "," || self == ":" || self == ";" || self == "!" || self == "?"
    }
}
