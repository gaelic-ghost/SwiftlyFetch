import RAGCore
@testable import RAGKit

actor FakeContextualEmbeddingBackend: ContextualEmbeddingBackend {
    private let vectorsByText: [String: EmbeddingVector]
    private(set) var embeddedTexts: [String]

    init(vectorsByText: [String: EmbeddingVector]) {
        self.vectorsByText = vectorsByText
        self.embeddedTexts = []
    }

    func embed(text: String) async throws -> EmbeddingVector {
        embeddedTexts.append(text)
        return vectorsByText[text] ?? EmbeddingVector([])
    }

    func recordedTexts() -> [String] {
        embeddedTexts
    }
}
