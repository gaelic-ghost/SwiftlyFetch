import Foundation
import RAGCore

public enum KnowledgeBaseError: Error, Sendable {
    case embedderReturnedUnexpectedVectorCount(expected: Int, actual: Int)
}

public actor KnowledgeBase {
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

        for result in results {
            let section = render(result: result, style: style)
            let separatorCount = renderedSections.isEmpty ? 0 : 2
            let remainingBudget = remainingCharacters(for: budget, currentCharacterCount: currentCharacterCount, separatorCount: separatorCount)
            guard remainingBudget != 0 else {
                break
            }

            let fittedSection = fittedText(section, limit: remainingBudget)
            guard !fittedSection.isEmpty else {
                continue
            }

            let sectionWithSeparator = renderedSections.isEmpty ? fittedSection : "\n\n\(fittedSection)"
            renderedSections.append(sectionWithSeparator)
            currentCharacterCount += sectionWithSeparator.count

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

    private func render(result: SearchResult, style: ContextStyle) -> String {
        switch style {
        case .plain:
            return result.chunk.text
        case .annotated:
            let score = String(format: "%.4f", result.score)
            return """
            [Document: \(result.chunk.documentID.rawValue) | Chunk: \(result.chunk.id.rawValue) | Score: \(score)]
            \(result.chunk.text)
            """
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
