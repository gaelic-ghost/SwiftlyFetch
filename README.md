# SwiftlyFetch

An Apple-first Swift Package family for local document search and semantic retrieval.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Package Status](#package-status)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

`v0.1.2` is the current tagged package release and is stable enough to try locally.

### What This Project Is

SwiftlyFetch is the umbrella product direction for a small family of Apple-first local search packages. The product goal is simple: hand the system a local corpus and get back a real search engine, with conventional search and semantic retrieval both living under one coherent Swift-native story. In practical terms, SwiftlyFetch is the family for "drop in a corpus, get back local search," with `FetchKit` covering conventional full-document search and `RAGKit` covering semantic retrieval over the same broader corpus model.

Today, the package exposes shipped semantic retrieval work through `RAGCore` and `RAGKit`, plus the first conventional-search foundation through `FetchCore` and `FetchKit`. `FetchCore` now owns the portable conventional-search vocabulary, the durable document-record model, and the indexing-changeset boundary. That record model carries first-class typed lifecycle and source fields like `kind`, `language`, `createdAt`, `updatedAt`, `sourceURI`, and `lastIndexedAt`, while leaving the freeform metadata bag string-based. `FetchCore` also distinguishes between the durable stored record, the lean search-facing document view, and the richer index-facing payload used by the sync boundary. `FetchKitLibrary` now supports a default in-memory construction path, and `FetchKit` includes a Core Data-backed `FetchDocumentStore`, a persisted pending-sync queue, and the first thin macOS SearchKit-backed index. Conventional-search results also carry field evidence through `matchedFields` and `snippetField`, so UI code can tell whether a result matched title text, body text, or both.

The intended family split is:

- `RAGKit` for semantic retrieval, knowledge-base assembly, and the retrieval-quality chunking, embedding, and indexing work that supports that job
- `FetchCore` for the portable document-search vocabulary that will stay backend-agnostic as `FetchKit` grows
- `FetchKit` for traditional search, with `FetchKitLibrary` as the first public facade and Core Data plus SearchKit as the intended Apple implementation model
- `SwiftlyFetch` as the umbrella story tying those sibling package surfaces together over time

That intended split does not change the current package boundary: `RAGKit` still owns semantic retrieval work, not conventional document search. The next family step is refinement, not first existence: improve conventional-search ranking and snippets, keep the persistent library surface polished, and continue making it realistic for one local corpus to support both traditional search and semantic retrieval without forcing those jobs into one module.

Platform-wise, the family target is still "macOS and iOS are both first-class," but the first concrete full-text backend is intentionally macOS-first. Apple documents Search Kit as a Mac app indexing and search framework, while Core Spotlight is the more obvious Apple-side indexing/search direction for iOS later. That means the current plan is not to pretend one backend fits both platforms immediately. Instead, `FetchCore` stays portable, `FetchKit` starts with the honest macOS path, and iOS remains a first-class family target through a future sibling backend rather than through fake cross-platform wording.

### Motivation

The goal is to make local search feel native and pleasant in Swift apps without turning the package into a chat framework or a giant AI abstraction layer.

## Quick Start

The package is still early, but the retrieval surface is real enough to try locally:

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

The current public surface centers on four library products:

```swift
import FetchCore
import FetchKit
import RAGCore
import RAGKit

let localKB = try await KnowledgeBase.hashingDefault()
let appleKB = try await KnowledgeBase.naturalLanguageDefault(languageHint: "en")
let fetchQuery = FetchSearchQuery("apple guide", kind: .allTerms)
let library = FetchKitLibrary()
```

The conventional-search side is still early, but the intended top-level shape is already visible:

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

`matchedFields` identifies every indexed field that contributed to a search result. `snippetField` identifies the field used to build the returned snippet. Title-only hits intentionally keep the title as the snippet source, so simple result lists still have an immediate explanation for why the result appeared, while richer UIs can render title evidence differently from body evidence.

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
- metadata filtering supports explicit exclusions, ordered comparisons for `int`, `double`, and `date`, plus case-insensitive `startsWith` and `endsWith` string matching
- markdown list items keep heading and immediate lead-in context in chunk text, and also carry structured chunk metadata for list kind, lead-in, ordinal, and heading path
- markdown block quotes stay secondary by default, but are promoted into the primary retrieval stream when they make up more than one third of the document's chunkable block structure
- markdown code blocks stay secondary by default, but promoted code-heavy documents emit code chunks with language metadata, and all chunks from a document can carry document-level code-language metadata
- markdown thematic breaks act as section-boundary hints, carrying a short lead-in into the next chunk instead of becoming their own retrieval chunks
- markdown images keep alt text primary in chunk text while recording image references as chunk metadata, and whitelisted HTML blocks currently cover `img` plus `details` / `summary`
- markdown fallback is selective: ordinary supported prose still chunks normally, but policy-rejected markdown like unsupported raw-HTML-only or reference-definition-only content does not fall back through the plain paragraph chunker
- conventional search now uses modest field-aware ranking, prefers title hits over body-only hits when both are relevant, and builds query-aware snippets with multi-term highlights instead of a single fixed-width first-term window
- conventional-search results report `matchedFields` and `snippetField`, keeping title-only snippets visible while letting consumers distinguish title evidence from body evidence
- `makeContext(...)` suppresses redundant same-document chunk text, groups annotated output by document, and skips annotated sections that only have room for labels

Supported today:

- build a local knowledge base from plain text and markdown documents
- use deterministic hashing embeddings for tests, previews, and fully local examples
- use Apple Natural Language embeddings for on-device semantic retrieval on supported platforms
- use `FetchKitLibrary()` with a default in-memory backend or inject custom `FetchDocumentStore` and `FetchIndex` implementations explicitly
- use a real Core Data-backed `FetchDocumentStore` in `FetchKit` with the first thin macOS SearchKit index backend
- persist and retry pending index-sync work through `FetchKitLibrary.pendingIndexSyncs()` and `retryPendingIndexSyncs(...)`
- return conventional-search results with query-aware snippets, field-aware ranking, matched-field metadata, and snippet-source metadata across title and body matches
- narrow retrieval with typed metadata filters
- preserve meaningful markdown structure for retrieval, including heading paths, list semantics, quote-heavy documents, code-heavy documents, short section breaks, images, and a narrow raw-HTML whitelist
- turn ranked search results into plain or annotated context text for downstream UI or model consumers

## Package Status

SwiftlyFetch is usable today as a local Apple-first package family, but it is still early in the broader product arc.

Good current fits:

- app-level semantic retrieval over local plain-text and markdown corpora
- conventional-search experimentation through the first `FetchCore` and `FetchKit` surfaces
- Apple-first local search prototypes where Core Data, SearchKit, and on-device retrieval matter

Current constraints:

- the SearchKit backend is macOS-first
- Natural Language asset-backed verification runs in local maintainer validation by default, but stays out of the default GitHub-hosted CI lane because hosted macOS still stalls in the asset-backed step
- the package family direction is broader than the currently shipped polished surface, especially on the `FetchKit` side

If you want to contribute to the package itself, use [CONTRIBUTING.md](./CONTRIBUTING.md). Maintainer planning and architecture notes live under [docs/maintainers/](./docs/maintainers/).

## Release Notes

Tagged releases should be created with `scripts/repo-maintenance/release.sh`, and each published tag should get matching GitHub release notes that summarize what changed and how it was verified. Maintainer planning and architecture notes live under `docs/maintainers/`.

## License

Licensed under the Apache License 2.0. See [LICENSE](./LICENSE).
