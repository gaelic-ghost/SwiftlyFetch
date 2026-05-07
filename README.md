# SwiftlyFetch

Apple-first local search and semantic retrieval for Swift apps.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Package Status](#package-status)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

SwiftlyFetch is a Swift package family for apps that need to index local documents, search them, and assemble useful retrieval context without sending the job to a remote service. The current package is early, but useful: it ships semantic retrieval through `RAGCore` and `RAGKit`, conventional search through `FetchCore` and `FetchKit`, and the first umbrella `SwiftlyFetch` facade for one-corpus ingestion.

Use SwiftlyFetch when you want:

- local semantic retrieval over plain text and markdown
- deterministic hashing embeddings for tests, previews, and examples
- Apple Natural Language embeddings on supported Apple platforms
- persistent semantic chunks and embeddings through Core Data
- coordinated one-corpus ingestion through `SwiftlyFetchLibrary`
- conventional document search with title/body evidence, query-aware snippets, and a macOS SearchKit-backed index path
- one package family that keeps retrieval, indexing, and context assembly separate from chat, generation, agents, and remote-provider workflows

The package family is intentionally split by job:

- `RAGCore` defines semantic retrieval vocabulary.
- `RAGKit` provides the default semantic retrieval implementation and `KnowledgeBase` actor.
- `FetchCore` defines portable conventional-search models.
- `FetchKit` provides the first conventional-search facade, Core Data document storage, pending index-sync tracking, and a macOS SearchKit backend.
- `SwiftlyFetch` composes both sibling package families so callers can add a document once, then use conventional search and semantic retrieval over the same corpus.

`v0.1.2` is the current tagged release and is stable enough to try locally. The umbrella `SwiftlyFetch` surface is now implemented on the development branch and will be part of a future tagged release.

SwiftlyFetch is not a chat framework, LLM SDK, agent runtime, or remote-provider abstraction. Its job is local retrieval: document preparation, indexing, search, filtering, and context assembly.

## Quick Start

The package is still early, but the retrieval surface is real enough to try locally. For the coordinated corpus surface, import `SwiftlyFetch`:

```swift
import FetchCore
import RAGCore
import SwiftlyFetch

let library = try await SwiftlyFetchLibrary.default()

try await library.addDocument(
    FetchDocumentRecord(
        id: "guide",
        title: "Fruit Guide",
        body: "Apples are bright and crisp.",
        contentType: .markdown,
        kind: .guide,
        language: "en"
    )
)

let searchResults = try await library.search(FetchSearchQuery("fruit guide"))
let semanticResults = try await library.retrieve(SearchQuery("bright fruit"))
```

For lower-level semantic retrieval, import `RAGCore` and `RAGKit` directly:

```swift
import RAGCore
import RAGKit

let kb = try await KnowledgeBase.hashingDefault()

try await kb.addDocument(
    Document(
        id: "guide",
        content: .markdown(
            """
            # Fruit Guide

            ## Apples

            Apples are bright and crisp.
            """
        )
    )
)

let results = try await kb.search("bright fruit")
let context = try await kb.makeContext(for: "bright fruit")
```

## Usage

The current public surface centers on five library products: `RAGCore`, `RAGKit`, `FetchCore`, `FetchKit`, and `SwiftlyFetch`.

For coordinated one-corpus ingestion, use `SwiftlyFetchLibrary` from `SwiftlyFetch`:

```swift
import FetchCore
import RAGCore
import SwiftlyFetch

let library = try await SwiftlyFetchLibrary.default()

let mutation = try await library.addDocument(
    FetchDocumentRecord(
        id: "guide",
        title: "Apple Guide",
        body: "Apples are bright and crisp.",
        contentType: .markdown
    )
)

let conventionalResults = try await library.search(FetchSearchQuery("apple guide"))
let semanticResults = try await library.retrieve(SearchQuery("bright crisp"))
let sideBySideResults = try await library.searchAndRetrieve(
    conventional: FetchSearchQuery("apple guide"),
    semantic: SearchQuery("bright crisp")
)
```

`SwiftlyFetchMutationResult` reports conventional and semantic outcomes separately. If the corpus write succeeds but semantic indexing fails, the facade queues a semantic retry instead of pretending the whole write failed.
`searchAndRetrieve(...)` returns conventional and semantic results side by side without combining scores; ranked hybrid search remains future work.

For semantic retrieval, use `KnowledgeBase` from `RAGKit`:

```swift
import RAGCore
import RAGKit

let localKB = try await KnowledgeBase.hashingDefault()
let appleKB = try await KnowledgeBase.naturalLanguageDefault(languageHint: "en")
let semanticStore = FileManager.default
    .temporaryDirectory
    .appendingPathComponent("SwiftlyFetchSemantic.sqlite")
let persistentKB = try await KnowledgeBase.persistentHashingDefault(
    configuration: .init(store: .sqlite(semanticStore))
)
```

For conventional search, use `FetchKitLibrary` from `FetchKit`:

```swift
import FetchCore
import FetchKit

let library = FetchKitLibrary()

try await library.addDocument(
    FetchDocumentRecord(
        id: "guide",
        title: "Apple Guide",
        body: "Apples are bright and crisp.",
        contentType: .markdown,
        kind: .guide,
        language: "en"
    )
)

let results = try await library.search("apple guide")
let firstResult = results.first
let matchedFields = firstResult?.matchedFields
let snippetField = firstResult?.snippetField
```

`matchedFields` identifies every indexed field that contributed to a search result. `snippetField` identifies the field used to build the returned snippet. Simple result lists can show why a result appeared immediately, while richer UIs can render title evidence differently from body evidence.

On macOS, the persistent conventional-search surface is now also shaped around one library storage location instead of separate store and index URLs:

```swift
import FetchKit

let persistentLibrary = try await FetchKitLibrary.macOSPersistentLibrary()
let previewLibrary = try await FetchKitLibrary.macOSPersistentLibrary(
    at: URL(fileURLWithPath: "/tmp/SwiftlyFetchPreview", isDirectory: true)
)
```

If a caller needs raw markdown link destinations for downstream indexing or fetch-oriented work, opt in at the chunker boundary instead of widening default chunk text:

```swift
import RAGKit

let chunker = HeadingAwareMarkdownChunker(linkDestinationMetadataMode: .include)
```

Current defaults:

- plain text uses paragraph chunking
- markdown uses parser-backed heading-aware chunking
- markdown link destinations stay out of chunk text by default, but `HeadingAwareMarkdownChunker(linkDestinationMetadataMode: .include)` can record raw destinations in chunk metadata when downstream indexing or fetch-oriented work needs them
- `hashingDefault()` gives a deterministic local path for tests and examples
- `naturalLanguageDefault()` uses the Apple Natural Language backend on supported platforms
- `persistentHashingDefault(configuration:dimension:)` and `persistentNaturalLanguageDefault(configuration:languageHint:)` use the same retrieval defaults with a Core Data-backed semantic vector index
- metadata filtering supports explicit exclusions, ordered comparisons for `int`, `double`, and `date`, plus case-insensitive `startsWith` and `endsWith` string matching
- markdown list items keep heading and immediate lead-in context in chunk text, and also carry structured chunk metadata for list kind, lead-in, ordinal, and heading path
- markdown block quotes stay secondary by default, but are promoted into the primary retrieval stream when they make up more than one third of the document's chunkable block structure
- markdown code blocks stay secondary by default, but promoted code-heavy documents emit code chunks with language metadata, and all chunks from a document can carry document-level code-language metadata
- markdown thematic breaks act as section-boundary hints, carrying a short lead-in into the next chunk instead of becoming their own retrieval chunks
- markdown images keep alt text primary in chunk text while recording image references as chunk metadata, and whitelisted HTML blocks currently cover `img` plus `details` / `summary`
- markdown fallback is selective: ordinary supported prose still chunks normally, but policy-rejected markdown like unsupported raw-HTML-only or reference-definition-only content does not fall back through the plain paragraph chunker
- conventional search now uses modest field-aware ranking, prefers title hits over body-only hits when both are relevant, and builds query-aware snippets with multi-term highlights instead of a single fixed-width first-term window
- in-memory all-term search gives a small boost to compact evidence, so focused passages rank ahead of scattered near-matches when they satisfy the same query terms
- conventional-search results report `matchedFields` and `snippetField`, keeping title-only snippets visible while letting consumers distinguish title evidence from body evidence
- `makeContext(...)` suppresses redundant same-document chunk text, groups annotated output by document, and skips annotated sections that only have room for labels

## Package Status

SwiftlyFetch is usable today as a local Apple-first package family, but it is still early in the broader product arc.

Good current fits:

- app-level semantic retrieval over local plain-text and markdown corpora
- conventional-search experimentation through `FetchCore` and `FetchKit`
- Apple-first local search prototypes where Core Data, SearchKit, and on-device retrieval matter
- downstream UI or model features that need ranked search results or assembled context, but do not need SwiftlyFetch to own generation

Current constraints:

- the SearchKit backend is macOS-first
- Natural Language asset-backed verification runs in local maintainer validation by default, but stays out of the default GitHub-hosted CI lane because hosted macOS still stalls in the asset-backed step
- the package family direction is broader than the currently shipped polished surface, especially on the `FetchKit` side
- hybrid search still waits on follow-up result-shape work; the umbrella facade currently exposes conventional `search` and semantic `retrieve` separately
- conventional-search quality coverage uses a small checked-in Project Gutenberg fixture corpus plus synthetic near-miss and longer-body records; larger app-like corpora are still future validation work

For contributor setup, branch workflow, verification commands, and review expectations, use [CONTRIBUTING.md](./CONTRIBUTING.md). Maintainer planning and architecture notes live under [docs/maintainers/](./docs/maintainers/).

## Release Notes

See the repository's GitHub releases for published package notes. Release workflow details belong in [CONTRIBUTING.md](./CONTRIBUTING.md) and the maintainer docs, not in this user-facing README.

## License

Licensed under the Apache License 2.0. See [LICENSE](./LICENSE).
