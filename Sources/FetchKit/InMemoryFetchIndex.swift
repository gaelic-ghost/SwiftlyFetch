import FetchCore
import Foundation

actor InMemoryFetchIndex: FetchIndex {
    private var indexedDocuments: [FetchDocumentID: FetchIndexDocument] = [:]

    func apply(_ changeset: FetchIndexingChangeset) async throws {
        for change in changeset.changes {
            switch change {
            case let .upsert(document):
                indexedDocuments[document.id] = document
            case let .remove(id):
                indexedDocuments[id] = nil
            }
        }
    }

    func removeAllDocuments() async throws {
        indexedDocuments.removeAll()
    }

    func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult] {
        let normalizedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty, query.limit > 0 else {
            return []
        }

        let matches = indexedDocuments.values.compactMap { document in
            makeResult(for: document, query: query, normalizedQuery: normalizedQuery)
        }

        return Array(
            matches
                .sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.document.id.rawValue < rhs.document.id.rawValue
                    }

                    return lhs.score > rhs.score
                }
                .prefix(query.limit)
        )
    }

    private func makeResult(
        for document: FetchIndexDocument,
        query: FetchSearchQuery,
        normalizedQuery: String
    ) -> FetchSearchResult? {
        let matches = candidateTexts(for: document, fields: query.fields).compactMap { field, text in
            match(
                field: field,
                text: text,
                query: query,
                normalizedQuery: normalizedQuery
            )
        }

        guard !matches.isEmpty else {
            return nil
        }

        let score = matches.reduce(0) { $0 + $1.score }
        let snippetMatch = preferredSnippetMatch(from: matches)

        return FetchSearchResult(
            document: document.searchDocument,
            score: score,
            snippet: snippetMatch.flatMap { match in
                FetchSearchSupport.buildSnippet(from: match.text, query: query)
            }
        )
    }

    private func candidateTexts(
        for document: FetchIndexDocument,
        fields: Set<FetchSearchField>
    ) -> [(FetchSearchField, String)] {
        var texts: [(FetchSearchField, String)] = []

        if fields.contains(.title), let title = document.title, !title.isEmpty {
            texts.append((.title, title))
        }

        if fields.contains(.body), !document.body.isEmpty {
            texts.append((.body, document.body))
        }

        return texts
    }

    private func match(
        field: FetchSearchField,
        text: String,
        query: FetchSearchQuery,
        normalizedQuery: String
    ) -> SearchMatch? {
        let lowercaseText = text.lowercased()
        let lowercaseQuery = normalizedQuery.lowercased()

        switch query.kind {
        case .exactPhrase:
            guard lowercaseText.range(of: lowercaseQuery) != nil else {
                return nil
            }

            return SearchMatch(
                field: field,
                text: text,
                score: boostedScore(base: 1.0, field: field)
            )
        case .prefix:
            return prefixMatch(field: field, text: text, lowercaseText: lowercaseText, lowercaseQuery: lowercaseQuery)
        case .allTerms, .naturalLanguage:
            return allTermsMatch(field: field, text: text, lowercaseText: lowercaseText, lowercaseQuery: lowercaseQuery)
        }
    }

    private func prefixMatch(
        field: FetchSearchField,
        text: String,
        lowercaseText: String,
        lowercaseQuery: String
    ) -> SearchMatch? {
        let words = lowercaseText.split(whereSeparator: \.isWhitespace)
        guard words.contains(where: { $0.hasPrefix(lowercaseQuery) }) else {
            return nil
        }

        guard lowercaseText.range(of: lowercaseQuery) != nil else {
            return nil
        }

        return SearchMatch(
            field: field,
            text: text,
            score: boostedScore(base: 0.9, field: field)
        )
    }

    private func allTermsMatch(
        field: FetchSearchField,
        text: String,
        lowercaseText: String,
        lowercaseQuery: String
    ) -> SearchMatch? {
        let terms = lowercaseQuery
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else {
            return nil
        }

        guard terms.allSatisfy({ lowercaseText.contains($0) }) else {
            return nil
        }

        guard let firstTerm = terms.first, lowercaseText.range(of: firstTerm) != nil else {
            return nil
        }

        return SearchMatch(
            field: field,
            text: text,
            score: boostedScore(base: 0.8 + (0.02 * Double(terms.count)), field: field)
        )
    }

    private func boostedScore(base: Double, field: FetchSearchField) -> Double {
        base * FetchSearchSupport.fieldWeight(for: field)
    }

    private func preferredSnippetMatch(from matches: [SearchMatch]) -> SearchMatch? {
        matches.max {
            if $0.field == $1.field {
                return $0.score < $1.score
            }

            if $0.field == .body {
                return false
            }

            if $1.field == .body {
                return true
            }

            return $0.score < $1.score
        }
    }
}

private struct SearchMatch {
    let field: FetchSearchField
    let text: String
    let score: Double
}
