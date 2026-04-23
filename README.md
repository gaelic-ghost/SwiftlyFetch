# SwiftlyFetch

An Apple-first Swift Package family for local document search and semantic retrieval.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

`v0.1.0` is the first retrieval-first package release. The current shipped surface covers local document ingestion for plain text and markdown, chunking, embeddings, in-memory indexing, metadata filtering, retrieval, and deterministic context assembly.

### What This Project Is

SwiftlyFetch is the umbrella product direction for a small family of Apple-first local search packages. The product goal is simple: hand the system a local corpus and get back a real search engine, with conventional search and semantic retrieval both living under one coherent Swift-native story.

Today, the shipped public package surface is split into `RAGCore` for the typed retrieval models and protocols, and `RAGKit` for the default chunking, embedding, indexing, and `KnowledgeBase` implementations that power semantic retrieval.

The intended family split is:

- `RAGKit` for semantic retrieval, knowledge-base assembly, and the retrieval-quality chunking, embedding, and indexing work that supports that job
- `FetchKit` for traditional search, with Core Data as the durable document store and SearchKit as the first planned macOS full-text indexing backend
- `SwiftlyFetch` as the umbrella story tying those sibling package surfaces together over time

That intended split does not change the current package boundary: `RAGKit` still owns semantic retrieval work, not conventional document search. The next family step is to define `FetchCore` and `FetchKit` cleanly enough that the same local corpus can eventually power both traditional search and semantic retrieval without forcing those jobs into one module.

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

The current public surface centers on two library products:

```swift
import RAGCore
import RAGKit

let localKB = try await KnowledgeBase.hashingDefault()
let appleKB = try await KnowledgeBase.naturalLanguageDefault(languageHint: "en")
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
- `makeContext(...)` suppresses redundant same-document chunk text, groups annotated output by document, and skips annotated sections that only have room for labels

Supported today:

- build a local knowledge base from plain text and markdown documents
- use deterministic hashing embeddings for tests, previews, and fully local examples
- use Apple Natural Language embeddings for on-device semantic retrieval on supported platforms
- narrow retrieval with typed metadata filters
- preserve meaningful markdown structure for retrieval, including heading paths, list semantics, quote-heavy documents, code-heavy documents, short section breaks, images, and a narrow raw-HTML whitelist
- turn ranked search results into plain or annotated context text for downstream UI or model consumers

## Development

### Setup

1. Install a Swift 6.1-era toolchain or newer.
2. Clone the repository.
3. Run `swift build` once to resolve the package and confirm the local toolchain matches the manifest.

### Workflow

Use `Package.swift` as the source of truth for package structure, targets, and dependencies. The repo-maintenance toolkit lives under `scripts/repo-maintenance/`, and ordinary package work should stay on the default SwiftPM path unless Xcode-managed behavior is explicitly needed. The current code surface lives primarily under `Sources/RAGCore/` and `Sources/RAGKit/`.

### Validation

Use the standard package checks for day-to-day work:

```sh
swift build
swift test
scripts/repo-maintenance/validate-all.sh
```

Opt-in Natural Language integration coverage is available when you explicitly enable it:

```sh
RUN_NL_INTEGRATION_TESTS=1 swift test --filter NaturalLanguageEmbedderIntegrationTests
```

That Natural Language verification is local-only for now. A GitHub-hosted `macos-15` lane was able to start the asset-backed test path, but the hosted run sat in the Natural Language integration step until the job timeout, so the default GitHub Actions workflow stays asset-independent.

## Repo Structure

```text
.
├── Package.swift
├── Sources/
│   ├── RAGCore/
│   └── RAGKit/
├── Tests/
│   ├── RAGCoreTests/
│   ├── RAGKitTests/
│   └── RAGKitIntegrationTests/
├── docs/
│   └── maintainers/
├── scripts/
│   └── repo-maintenance/
└── .github/
    └── workflows/
```

## Release Notes

Tagged releases should be created with `scripts/repo-maintenance/release.sh`, and each published tag should get matching GitHub release notes that summarize what changed and how it was verified. Maintainer planning and architecture notes live under `docs/maintainers/`.

## License

Licensed under the Apache License 2.0. See [LICENSE](./LICENSE).
