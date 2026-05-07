import FetchCore
import Foundation
import RAGCore

public struct SwiftlyFetchDocumentMapper: Hashable, Sendable {
    public init() {}

    public func documentID(for fetchDocumentID: FetchDocumentID) -> DocumentID {
        DocumentID(fetchDocumentID.rawValue)
    }

    public func document(from record: FetchDocumentRecord) -> Document {
        Document(
            id: documentID(for: record.id),
            content: content(from: record),
            metadata: metadata(from: record)
        )
    }

    private func content(from record: FetchDocumentRecord) -> DocumentContent {
        let body = semanticSourceText(from: record)

        switch record.contentType {
            case .plainText:
                return .text(body)
            case .markdown:
                return .markdown(body)
        }
    }

    private func semanticSourceText(from record: FetchDocumentRecord) -> String {
        guard let title = normalizedTitle(from: record) else {
            return record.body
        }

        switch record.contentType {
            case .plainText:
                return "Title: \(title)\n\n\(record.body)"
            case .markdown:
                return "# \(title)\n\n\(record.body)"
        }
    }

    private func metadata(from record: FetchDocumentRecord) -> DocumentMetadata {
        var values = record.metadata.mapValues(MetadataValue.string)
        values["contentType"] = .string(record.contentType.rawValue)

        if let title = normalizedTitle(from: record) {
            values["title"] = .string(title)
        }

        if let kind = record.kind {
            values["kind"] = .string(kind.rawValue)
        }

        if let language = record.language {
            values["language"] = .string(language)
        }

        if let sourceURI = record.sourceURI {
            values["sourceURI"] = .string(sourceURI)
        }

        if let createdAt = record.createdAt {
            values["createdAt"] = .date(createdAt)
        }

        if let updatedAt = record.updatedAt {
            values["updatedAt"] = .date(updatedAt)
        }

        return DocumentMetadata(values)
    }

    private func normalizedTitle(from record: FetchDocumentRecord) -> String? {
        guard let title = record.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty
        else {
            return nil
        }

        return title
    }
}
