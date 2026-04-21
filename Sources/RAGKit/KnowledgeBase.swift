import Foundation
import RAGCore

public enum KnowledgeBaseError: Error, Sendable {
    case embedderReturnedUnexpectedVectorCount(expected: Int, actual: Int)
}

public actor KnowledgeBase {
    private struct ContextSection {
        let text: String
        let comparisonText: String
    }

    private let chunker: any Chunker
    private let embedder: any Embedder
    private let index: any VectorIndex

    public init(
        chunker: any Chunker,
        embedder: any Embedder,
        index: any VectorIndex
    ) {
        self.chunker = chunker
        self.embedder = embedder
        self.index = index
    }

    public func addDocuments(_ documents: [Document]) async throws {
        for document in documents {
            try await addDocument(document)
        }
    }

    public func addDocument(_ document: Document) async throws {
        let chunks = try chunker.chunks(for: document)
        let embeddings = try await embedder.embed(chunks: chunks)

        guard chunks.count == embeddings.count else {
            throw KnowledgeBaseError.embedderReturnedUnexpectedVectorCount(
                expected: chunks.count,
                actual: embeddings.count
            )
        }

        let indexedChunks = zip(chunks, embeddings).map { chunk, embedding in
            IndexedChunk(chunk: chunk, embedding: embedding)
        }

        try await index.removeChunks(for: document.id)
        try await index.upsert(indexedChunks)
    }

    public func removeDocument(_ documentID: DocumentID) async throws {
        try await index.removeChunks(for: documentID)
    }

    public func search(_ query: SearchQuery) async throws -> [SearchResult] {
        let embedding = try await embedder.embed(query: query)
        return try await index.search(query, embedding: embedding)
    }

    public func search(
        _ query: String,
        limit: Int = 5,
        filter: MetadataFilter? = nil
    ) async throws -> [SearchResult] {
        try await search(SearchQuery(query, limit: limit, filter: filter))
    }

    public func makeContext(
        for query: SearchQuery,
        budget: ContextBudget = .characters(4_000),
        style: ContextStyle = .plain
    ) async throws -> String {
        let results = try await search(query)
        var renderedSections: [String] = []
        var currentCharacterCount = 0
        var lastIncludedDocumentID: DocumentID?
        var lastIncludedComparisonText: String?

        for result in results {
            let startsNewDocument = lastIncludedDocumentID != result.chunk.documentID
            let separator = separator(
                startsNewDocument: startsNewDocument,
                hasRenderedSections: !renderedSections.isEmpty
            )
            let remainingBudget = remainingCharacters(
                for: budget,
                currentCharacterCount: currentCharacterCount,
                separatorCount: separator.count
            )
            guard remainingBudget != 0 else {
                break
            }

            guard let section = renderSection(
                result: result,
                style: style,
                startsNewDocument: startsNewDocument,
                limit: remainingBudget
            ) else {
                continue
            }

            if let lastIncludedComparisonText,
               lastIncludedDocumentID == result.chunk.documentID,
               isRedundant(candidate: section.comparisonText, previous: lastIncludedComparisonText) {
                continue
            }

            let sectionWithSeparator = renderedSections.isEmpty ? section.text : "\(separator)\(section.text)"
            renderedSections.append(sectionWithSeparator)
            currentCharacterCount += sectionWithSeparator.count
            lastIncludedDocumentID = result.chunk.documentID
            lastIncludedComparisonText = section.comparisonText

            if !budget.allows(currentCharacterCount, adding: 0) {
                break
            }
        }

        return renderedSections.joined()
    }

    public func makeContext(
        for query: String,
        limit: Int = 5,
        filter: MetadataFilter? = nil,
        budget: ContextBudget = .characters(4_000),
        style: ContextStyle = .plain
    ) async throws -> String {
        try await makeContext(
            for: SearchQuery(query, limit: limit, filter: filter),
            budget: budget,
            style: style
        )
    }

    private func renderSection(
        result: SearchResult,
        style: ContextStyle,
        startsNewDocument: Bool,
        limit: Int?
    ) -> ContextSection? {
        switch style {
        case .plain:
            let fittedBody = fittedText(result.chunk.text, limit: limit)
            guard !fittedBody.isEmpty else {
                return nil
            }

            return ContextSection(
                text: fittedBody,
                comparisonText: normalizedComparisonText(result.chunk.text)
            )
        case .annotated:
            let score = String(format: "%.4f", result.score)
            let header = annotatedHeader(
                for: result,
                score: score,
                startsNewDocument: startsNewDocument
            )
            guard let fittedBody = fittedAnnotatedBody(
                result.chunk.text,
                prefix: header,
                limit: limit
            ) else {
                return nil
            }

            return ContextSection(
                text: "\(header)\n\(fittedBody)",
                comparisonText: normalizedComparisonText(result.chunk.text)
            )
        }
    }

    private func remainingCharacters(
        for budget: ContextBudget,
        currentCharacterCount: Int,
        separatorCount: Int
    ) -> Int? {
        switch budget {
        case .characters(let limit):
            return max(0, limit - currentCharacterCount - separatorCount)
        case .unlimited:
            return nil
        }
    }

    private func separator(
        startsNewDocument: Bool,
        hasRenderedSections: Bool
    ) -> String {
        guard hasRenderedSections else {
            return ""
        }

        if startsNewDocument {
            return "\n\n"
        }

        return "\n"
    }

    private func annotatedHeader(
        for result: SearchResult,
        score: String,
        startsNewDocument: Bool
    ) -> String {
        let chunkLine = "[Chunk: \(result.chunk.id.rawValue) | Score: \(score)]"

        if startsNewDocument {
            return """
            [Document: \(result.chunk.documentID.rawValue)]
            \(chunkLine)
            """
        }

        return chunkLine
    }

    private func fittedAnnotatedBody(
        _ body: String,
        prefix: String,
        limit: Int?
    ) -> String? {
        guard let limit else {
            return body
        }

        let minimumBodyCharacterCount = 12
        let availableBodyCharacters = limit - prefix.count - 1
        guard availableBodyCharacters >= minimumBodyCharacterCount else {
            return nil
        }

        let fittedBody = fittedText(body, limit: availableBodyCharacters)
        guard normalizedComparisonText(fittedBody).count >= minimumBodyCharacterCount else {
            return nil
        }

        return fittedBody
    }

    private func isRedundant(candidate: String, previous: String) -> Bool {
        guard !candidate.isEmpty, !previous.isEmpty else {
            return false
        }

        if candidate == previous {
            return true
        }

        let longer: String
        let shorter: String

        if candidate.count >= previous.count {
            longer = candidate
            shorter = previous
        } else {
            longer = previous
            shorter = candidate
        }

        guard longer.contains(shorter) else {
            return false
        }

        return Double(shorter.count) / Double(longer.count) >= 0.85
    }

    private func normalizedComparisonText(_ text: String) -> String {
        let normalizedScalars = text.lowercased().unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(String(scalar))
            }

            return " "
        }

        let normalized = String(normalizedScalars)
        return normalized
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fittedText(_ text: String, limit: Int?) -> String {
        guard let limit else {
            return text
        }

        guard limit > 0 else {
            return ""
        }

        if text.count <= limit {
            return text
        }

        if limit <= 1 {
            return String(text.prefix(limit))
        }

        let rawPrefix = String(text.prefix(limit - 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawPrefix.isEmpty else {
            return ""
        }

        if let lastWhitespace = rawPrefix.lastIndex(where: \.isWhitespace) {
            let wordBoundaryPrefix = rawPrefix[..<lastWhitespace].trimmingCharacters(in: .whitespacesAndNewlines)
            if !wordBoundaryPrefix.isEmpty {
                return "\(wordBoundaryPrefix)…"
            }
        }

        return "\(rawPrefix)…"
    }
}
