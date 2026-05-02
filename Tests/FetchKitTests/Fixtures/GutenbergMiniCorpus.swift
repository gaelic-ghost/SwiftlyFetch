import FetchCore

enum GutenbergMiniCorpus {
    struct Source: Hashable, Sendable {
        let datasetID: String
        let config: String
        let split: String
        let license: String
        let url: String
    }

    static let source = Source(
        datasetID: "zkeown/gutenberg-corpus",
        config: "chapters",
        split: "train",
        license: "Apache-2.0 dataset packaging; source texts marked public domain in the USA",
        url: "https://huggingface.co/datasets/zkeown/gutenberg-corpus"
    )

    static let records: [FetchDocumentRecord] = [
        FetchDocumentRecord(
            id: "gutenberg-78430-chapter-1",
            title: "A practical course in botany: Chapter I. The Seed",
            body: """
            I. The storage of food in seeds.

            Material. In addition to the four food tests described in the course, provide raw starch, grape sugar, the white of a hard-boiled egg, and a fatty substance such as lard or oil. Living material includes grains of corn and wheat, and seeds of some kind of bean.
            """,
            kind: .reference,
            language: "en",
            sourceURI: source.url,
            metadata: [
                "fixture.dataset": source.datasetID,
                "fixture.config": source.config,
                "fixture.split": source.split,
                "fixture.row": "2",
                "fixture.gutenbergID": "78430",
            ]
        ),
        FetchDocumentRecord(
            id: "gutenberg-78430-chapter-2",
            title: "A practical course in botany: Chapter II. Germination and Growth",
            body: """
            Processes accompanying germination.

            Material includes corn, peas, beans, or any quickly germinating seed. Before taking up the study of germinating seeds, it is important to learn from what sources the organic substances used by the growing plant are derived.
            """,
            kind: .reference,
            language: "en",
            sourceURI: source.url,
            metadata: [
                "fixture.dataset": source.datasetID,
                "fixture.config": source.config,
                "fixture.split": source.split,
                "fixture.row": "3",
                "fixture.gutenbergID": "78430",
            ]
        ),
        FetchDocumentRecord(
            id: "gutenberg-78431-book",
            title: "Always Another Dawn: The Story of a Rocket Test Pilot",
            body: """
            Transcriber's Note: Italicized text is surrounded by underscores. The opening material identifies A. Scott Crossfield with Clay Blair, Jr. and includes publisher front matter before the main narrative begins.
            """,
            kind: .article,
            language: "en",
            sourceURI: source.url,
            metadata: [
                "fixture.dataset": source.datasetID,
                "fixture.config": "books",
                "fixture.split": "train",
                "fixture.row": "2",
                "fixture.gutenbergID": "78431",
            ]
        ),
        FetchDocumentRecord(
            id: "gutenberg-78432-book",
            title: "The young pioneers of the North-west",
            body: """
            Transcriber's note: Unusual and inconsistent spelling is as printed. The frontier series opening material introduces a juvenile fiction setting around pioneer children, conduct of life, and frontier life.
            """,
            kind: .article,
            language: "en",
            sourceURI: source.url,
            metadata: [
                "fixture.dataset": source.datasetID,
                "fixture.config": "books",
                "fixture.split": "train",
                "fixture.row": "3",
                "fixture.gutenbergID": "78432",
            ]
        ),
    ]
}
