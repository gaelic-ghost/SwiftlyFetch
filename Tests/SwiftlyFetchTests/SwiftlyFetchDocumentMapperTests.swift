import FetchCore
import Foundation
import RAGCore
import SwiftlyFetch
import Testing

struct SwiftlyFetchDocumentMapperTests {
    @Test("Mapper includes title in markdown source text and typed metadata")
    func mapperIncludesTitleInMarkdownSourceAndMetadata() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let mapper = SwiftlyFetchDocumentMapper()
        let record = FetchDocumentRecord(
            id: "doc-guide",
            title: "Apple Guide",
            body: "Apples are bright and crisp.",
            contentType: .markdown,
            kind: .guide,
            language: "en",
            sourceURI: "file:///Guides/apple.md",
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: ["section": "fruit"]
        )

        let document = mapper.document(from: record)

        #expect(document.id == "doc-guide")
        #expect(document.content == .markdown("# Apple Guide\n\nApples are bright and crisp."))
        #expect(document.metadata["title"] == .string("Apple Guide"))
        #expect(document.metadata["contentType"] == .string("markdown"))
        #expect(document.metadata["kind"] == .string("guide"))
        #expect(document.metadata["language"] == .string("en"))
        #expect(document.metadata["sourceURI"] == .string("file:///Guides/apple.md"))
        #expect(document.metadata["createdAt"] == .date(createdAt))
        #expect(document.metadata["updatedAt"] == .date(updatedAt))
        #expect(document.metadata["section"] == .string("fruit"))
    }

    @Test("Mapper preserves plain text body when title is empty")
    func mapperPreservesPlainTextBodyWhenTitleIsEmpty() {
        let mapper = SwiftlyFetchDocumentMapper()
        let record = FetchDocumentRecord(
            id: "doc-note",
            title: "   ",
            body: "A standalone note.",
            contentType: .plainText
        )

        let document = mapper.document(from: record)

        #expect(document.content == .text("A standalone note."))
        #expect(document.metadata["title"] == nil)
        #expect(document.metadata["contentType"] == .string("plainText"))
    }
}
