import NaturalLanguage
import RAGCore

enum AppleContextualEmbeddingBackendError: Error, Sendable {
    case couldNotCreateEmbeddingModel(languageHint: String?)
    case assetsUnavailable(languageHint: String?)
    case noTokenVectors(text: String)
}

actor AppleContextualEmbeddingBackend: ContextualEmbeddingBackend {
    private let model: NLContextualEmbedding
    private let languageHint: NLLanguage?
    private let languageHintIdentifier: String?

    init(languageHint: String? = nil) throws {
        let normalizedLanguage = languageHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedLanguage = normalizedLanguage.flatMap(NLLanguage.init(_:))

        if let resolvedLanguage, let model = NLContextualEmbedding(language: resolvedLanguage) {
            self.model = model
            self.languageHint = resolvedLanguage
            self.languageHintIdentifier = normalizedLanguage
            return
        }

        if let model = NLContextualEmbedding(script: .latin) {
            self.model = model
            self.languageHint = resolvedLanguage
            self.languageHintIdentifier = normalizedLanguage
            return
        }

        throw AppleContextualEmbeddingBackendError.couldNotCreateEmbeddingModel(languageHint: normalizedLanguage)
    }

    func embed(text: String) async throws -> EmbeddingVector {
        try await ensureAssetsAreAvailable()
        try model.load()
        defer { model.unload() }

        let result = try model.embeddingResult(for: text, language: languageHint)
        let pooledValues = try pooledNormalizedValues(from: result)
        return EmbeddingVector(pooledValues)
    }

    private func ensureAssetsAreAvailable() async throws {
        guard !model.hasAvailableAssets else {
            return
        }

        let result = try await model.requestAssets()
        guard result == .available, model.hasAvailableAssets else {
            throw AppleContextualEmbeddingBackendError.assetsUnavailable(languageHint: languageHintIdentifier)
        }
    }

    private func pooledNormalizedValues(from result: NLContextualEmbeddingResult) throws -> [Double] {
        var tokenVectors: [[Double]] = []
        let fullRange = result.string.startIndex..<result.string.endIndex

        result.enumerateTokenVectors(in: fullRange) { vector, _ in
            tokenVectors.append(vector)
            return true
        }

        guard let first = tokenVectors.first else {
            throw AppleContextualEmbeddingBackendError.noTokenVectors(text: result.string)
        }

        var pooled = Array(repeating: 0.0, count: first.count)

        for vector in tokenVectors {
            for (index, value) in vector.enumerated() {
                pooled[index] += value
            }
        }

        let count = Double(tokenVectors.count)
        let meanPooled = pooled.map { $0 / count }
        return EmbeddingVector(meanPooled).normalized().values
    }
}
