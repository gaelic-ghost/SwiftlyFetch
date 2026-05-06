import Foundation
import RAGCore

extension ParagraphChunker: SemanticFingerprintProviding {
    public var semanticFingerprint: String {
        "ragkit.paragraph-chunker.v1"
    }
}

extension HeadingAwareMarkdownChunker: SemanticFingerprintProviding {
    public var semanticFingerprint: String {
        switch linkDestinationMetadataMode {
            case .omit:
                "ragkit.heading-aware-markdown.v1.links-omit"
            case .include:
                "ragkit.heading-aware-markdown.v1.links-include"
        }
    }
}

extension DefaultChunker: SemanticFingerprintProviding {
    public var semanticFingerprint: String {
        "\(paragraphChunker.semanticFingerprint)|\(markdownChunker.semanticFingerprint)"
    }
}

extension HashingEmbedder: SemanticFingerprintProviding {
    public var semanticFingerprint: String {
        "ragkit.hashing.\(dimension)"
    }
}

extension NaturalLanguageEmbedder: SemanticFingerprintProviding {
    public var semanticFingerprint: String {
        let language = languageHint ?? "automatic"
        return "ragkit.apple-natural-language.\(language)"
    }
}

enum SemanticFingerprintFactory {
    static func fingerprint(
        for document: Document,
        chunker: any Chunker,
        embedder: any Embedder
    ) -> SemanticIndexFingerprint {
        SemanticIndexFingerprint(
            source: sourceFingerprint(for: document),
            chunker: componentFingerprint(for: chunker, fallbackPrefix: "chunker"),
            embedder: componentFingerprint(for: embedder, fallbackPrefix: "embedder")
        )
    }

    private static func componentFingerprint(
        for component: Any,
        fallbackPrefix: String
    ) -> String {
        if let provider = component as? any SemanticFingerprintProviding {
            return provider.semanticFingerprint
        }

        return "custom.\(fallbackPrefix).\(String(reflecting: type(of: component)))"
    }

    private static func sourceFingerprint(for document: Document) -> String {
        var hasher = StableFNV1A64()
        hasher.append("document-id")
        hasher.append(document.id.rawValue)
        hasher.append("content-kind")

        switch document.content {
            case let .text(text):
                hasher.append("text")
                hasher.append(text)
            case let .markdown(markdown):
                hasher.append("markdown")
                hasher.append(markdown)
        }

        hasher.append("metadata")
        for key in document.metadata.values.keys.sorted() {
            hasher.append(key)
            hasher.append(metadataValueDescription(document.metadata.values[key]))
        }

        return hasher.hexDigest
    }

    private static func metadataValueDescription(_ value: MetadataValue?) -> String {
        guard let value else {
            return "nil"
        }

        switch value {
            case let .string(string):
                return "string:\(string)"
            case let .int(int):
                return "int:\(int)"
            case let .double(double):
                return "double:\(double)"
            case let .bool(bool):
                return "bool:\(bool)"
            case let .date(date):
                return "date:\(date.timeIntervalSince1970)"
        }
    }
}

private struct StableFNV1A64 {
    private var value: UInt64 = 14_695_981_039_346_656_037

    var hexDigest: String {
        String(format: "%016llx", value)
    }

    mutating func append(_ text: String) {
        for byte in text.utf8 {
            value = (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
        value = (value ^ 0xFF) &* 1_099_511_628_211
    }
}
