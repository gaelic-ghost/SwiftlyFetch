# SwiftlyFetch

An Apple-first Swift Package for local retrieval, document chunking, embeddings, and knowledge-base search.

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

This project is in early development.

### What This Project Is

SwiftlyFetch is a retrieval-first Swift package for Apple-platform apps. The current public package surface is split into `RAGCore` for the typed retrieval models and protocols, and `RAGKit` for the default chunking, embedding, indexing, and `KnowledgeBase` implementations.

### Motivation

The goal is to make local knowledge-base retrieval feel native and pleasant in Swift apps without turning the package into a chat framework or a giant AI abstraction layer.

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

Current defaults:

- plain text uses paragraph chunking
- markdown uses heading-aware chunking
- `hashingDefault()` gives a deterministic local path for tests and examples
- `naturalLanguageDefault()` uses the Apple Natural Language backend on supported platforms

## Development

### Setup

1. Install a Swift 6.3-era toolchain or newer.
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
