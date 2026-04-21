# Retrieval Package Plan

## Purpose

This document tightens the current product direction for `SwiftlyFetch` into a concrete maintainer plan. The goal is to keep the repository disciplined as a retrieval package for Apple-platform Swift apps, not let it drift into a general AI framework, and sequence the work so the first useful version lands quickly.

## Product Identity

`SwiftlyFetch` should be a Swift-native, Apple-first retrieval layer for local knowledge bases.

That means:

- It should feel natural inside Swift apps.
- It should default to local, on-device behavior where Apple already provides good primitives.
- It should optimize for ingestion, indexing, search, filtering, and context assembly.
- It should avoid owning generation, chat orchestration, agents, tool calling, or provider churn in v1.

This package is not trying to become:

- "LangChain in Swift"
- a universal LLM SDK
- a chat framework
- an agent runtime
- a giant abstraction layer over every model provider

The durable value is retrieval. Generation surfaces churn quickly; retrieval workflows, document preparation, indexing, and result packaging are much more likely to remain stable.

## Why This Still Makes Sense

Swift and Apple platforms now have enough building blocks for a real local-first retrieval package, but the space still looks fragmented rather than settled.

The current opening appears to be:

- there are packages that cover end-to-end on-device RAG or semantic search
- there are packages that wrap Apple embeddings or generic vector search
- there still is not one obvious default package that feels like the clean Swift-native retrieval layer for Apple apps

The opportunity is not to out-feature every other package. The opportunity is to offer a package with:

- excellent Swift ergonomics
- clear package boundaries
- strong Apple-platform fit
- local-first defaults
- a small, obvious happy path

## Framework Constraint We Are Relying On

Apple's Natural Language framework now exposes `NLContextualEmbedding`, which is the right default real embedding backend for this package.

The documented behavior that matters for this plan is:

- `NLContextualEmbedding` is available on Apple platforms and supports contextual embeddings as a sequence of token vectors, not a single ready-made sentence vector.
- The framework exposes `hasAvailableAssets`, `requestAssets()`, `load()`, `unload()`, and `embeddingResult(for:language:)`, so the real embedding flow includes asset availability checks, possible over-the-air model download, explicit model loading, then embedding.
- `NLContextualEmbeddingResult` exposes `sequenceLength` and token-vector enumeration APIs, which means package-level pooling is our responsibility if we want one vector per chunk or query.

In plain language: Apple gives us the real on-device embedding engine, but not the retrieval-layer API we want. The package still needs to decide how to pool vectors, how to hide asset-management complexity, and how to present a stable retrieval surface to app code.

References:

- [NLContextualEmbedding](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding)
- [requestAssets()](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding/requestassets%28completionhandler%3A%29)
- [embeddingResult(for:language:)](https://developer.apple.com/documentation/naturallanguage/nlcontextualembedding/embeddingresult%28for%3Alanguage%3A%29)
- [NLContextualEmbeddingResult](https://developer.apple.com/documentation/naturallanguage/nlcontextualembeddingresult)

## Architectural Direction

The repository should remain one Swift package, but it should grow into two main library products:

- `RAGCore`
- `RAGKit`

This is a durable building-block change, not a temporary organization trick. The practical effect is that the package can keep its core retrieval vocabulary and protocols stable while letting the default implementation layer move faster.

### RAGCore

`RAGCore` should be the boring, stable, low-level layer.

Its job is to define:

- core model types
- retrieval-facing protocols
- small supporting value types for configuration and filtering

This module should stay:

- strongly typed
- `Sendable`
- async-friendly
- independent of Apple framework details
- easy to unit test without platform assets

The initial target surface should include types along these lines:

- `DocumentID`
- `ChunkID`
- `Document`
- `Chunk`
- `EmbeddingVector`
- `IndexedChunk`
- `SearchQuery`
- `SearchResult`
- `MetadataFilter`
- `ContextBudget`
- `Chunker`
- `Embedder`
- `VectorIndex`

### RAGKit

`RAGKit` should be the opinionated default implementation layer.

Its job is to give users the obvious path:

- create a knowledge base
- add text or markdown documents
- search
- optionally assemble context from top results

The main facade should be a `KnowledgeBase` actor.

The public API should favor a tiny happy path over configurable pipeline builders. The intended feeling is:

```swift
let kb = try await KnowledgeBase.naturalLanguageDefault()
try await kb.addDocuments(...)
let results = try await kb.search("...")
let context = try await kb.makeContext(for: "...")
```

The package should resist introducing builder-heavy abstractions unless a real extension point proves they are necessary.

## Current Implementation Snapshot

The repository has already moved beyond pure planning.

Implemented today:

- `RAGCore` contains the typed identifiers, documents, chunks, embeddings, search models, metadata filtering, context budget/style types, and the core `Chunker`, `Embedder`, and `VectorIndex` protocols.
- `RAGKit` contains:
  - `ParagraphChunker`
  - `HeadingAwareMarkdownChunker`
  - `DefaultChunker`
  - `InMemoryVectorIndex`
  - `HashingEmbedder`
  - `KnowledgeBase`
  - `NaturalLanguageEmbedder`
  - `AppleContextualEmbeddingBackend`
  - convenience constructors for `hashingDefault()` and `naturalLanguageDefault()`
- deterministic tests cover the main retrieval flow and the Natural Language wrapper seam
- an opt-in integration test target exists for real Natural Language embedding coverage and stays non-blocking unless explicitly enabled

Still intentionally incomplete:

- more markdown chunker coverage for edge cases and future evolution
- optional future retrieval-default refinements only if concrete caller needs emerge beyond the current exclusion, ordered-comparison, and grouped-context defaults

## v1 Scope

Version 1 should focus on retrieval only.

Include:

- document ingestion for plain text and markdown
- chunking
- embedding
- indexing
- retrieval
- metadata filtering
- deterministic context assembly

Do not include:

- answer generation
- chat sessions
- prompt management
- tool calling
- agents
- workflow orchestration
- connector-heavy ingestion
- PDF ingestion
- remote provider abstraction layers

The most important discipline here is to keep retrieval as the owned surface and treat generation as an eventual downstream consumer, not as part of the package's main job.

## Ingestion Plan

For v1, support only:

- plain text
- markdown

This is a conscious scope cut, not a missing feature accident.

The practical reasoning:

- plain text gives us the minimum viable ingestion surface
- markdown matters early because heading structure is one of the biggest likely retrieval-quality wins
- PDFs and external connectors introduce parsing, metadata, and extraction complexity that would slow down the core retrieval API work

The chunking rollout should be:

1. paragraph chunker first
2. heading-aware markdown chunker immediately after the basic scaffold is working

That second step should be treated as a near-term quality improvement, not a distant backlog nice-to-have.

Current status:

- paragraph chunking is implemented
- heading-aware markdown chunking is implemented and now backs the default markdown path
- the next chunking work is test-depth and behavior refinement, not the first implementation

## Embedding Plan

### Public Shape

The public `Embedder` protocol in `RAGCore` should stay small and backend-agnostic.

It should describe the job in retrieval terms:

- embed chunks
- embed queries
- return package-owned vector types

It should not expose Apple framework objects, asset-management details, or Natural Language-specific result shapes.

### Default Real Backend

The default real backend in `RAGKit` should be `NaturalLanguageEmbedder`, backed by Apple's `NLContextualEmbedding`.

This choice fits the package identity because it is:

- Apple-first
- local-first
- privacy-friendly
- already integrated with platform asset management

### Internal Backend Isolation

`NaturalLanguageEmbedder` should sit on top of a small internal backend protocol, such as `ContextualEmbeddingBackend`.

That internal seam exists to isolate Apple-specific behavior:

- asset availability checks
- asset download requests
- model loading and unloading
- token-vector enumeration
- language and script handling

This is a durable building-block change. The practical effect is that the public retrieval surface stays stable even if we later add:

- `MLXEmbedder`
- remote API embedders
- test doubles
- newer Apple embedding backends

It also makes tests simpler because the public wrapper can be exercised against a fake backend without requiring downloaded Natural Language assets.

### Pooling Strategy

Because Apple returns a sequence of token vectors instead of a single vector for the whole input, v1 should:

- mean-pool token vectors into one embedding vector per chunk or query
- normalize the pooled vector before indexing and comparison

This should be described as the initial package policy, not as a claim that Apple already provides sentence-level pooling for us.

## Indexing Plan

Version 1 should not try to be a vector database.

Start with a simple in-memory cosine-similarity index that conforms to `VectorIndex`.

It only needs to support:

- upsert
- search
- remove by document identifier
- wipe all

This is a conscious stopgap in implementation depth, but not a stopgap in API shape. The point is to prove the retrieval flow and type design first, while leaving room for better index backends later.

The first implementation should optimize for:

- clarity
- testability
- determinism
- obvious behavior

It should not optimize for:

- approximate nearest neighbor performance
- persistence
- compression
- multi-process coordination

## KnowledgeBase Role

`KnowledgeBase` should be an actor in `RAGKit` that owns:

- a `Chunker`
- an `Embedder`
- a `VectorIndex`

Its public role is simple: it is the package's default retrieval facade.

The initial public methods should be:

- `addDocuments`
- `addDocument`
- `removeDocument`
- `search`
- `makeContext`

`makeContext` should remain deliberately small and deterministic. It should:

- select top results
- pack them into either a plain or annotated snippet format
- respect a simple context-budget type
- avoid any generation or answer-synthesis behavior

That keeps the package focused on assembling useful retrieval context for downstream consumers, whether that consumer is a UI, a local model, or a remote model call outside this package.

## Testing Strategy

The first scaffold should include a deterministic non-Apple embedder so the package can be exercised immediately and repeatedly in tests.

The practical v1 testing split should be:

- unit tests against package-owned protocols and value types
- deterministic tests using a fake or hashing embedder
- separate opt-in Apple integration tests for real `NLContextualEmbedding`

The package should not make ordinary tests depend on:

- downloaded Apple language assets
- network conditions for asset download
- platform-specific asset availability
- framework behavior that may differ across environments

That means:

- the public embedder wrapper should be unit-tested with a fake backend
- real Natural Language integration tests should be separate and opt-in
- examples and starter flows should work with a deterministic fallback backend

Current status:

- the deterministic wrapper and knowledge-base tests are in place
- the opt-in Natural Language integration target exists
- real Apple-backed integration coverage now checks semantic retrieval behavior rather than only non-empty normalized vectors
- default CI should prove `swift build` and `swift test` on the ordinary macOS path, while Apple-asset integration coverage stays opt-in until a reliable asset-enabled runner story exists

## Package Structure Target

The intended package shape after the first real refactor should be:

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
└── docs/
    └── maintainers/
```

The initial `Package.swift` target state should expose:

- library product `RAGCore`
- library product `RAGKit`
- test targets for both

Keep dependencies at zero for the first pass.

If later expansion is useful, adapters can live in a separate module such as `RAGIntegrations`, but that module should not exist in v1.

## Future Package Family Note

There is already a likely future expansion path beyond the retrieval modules in this document.

If the repository later grows a document and full-text-search family, the intended direction is:

- `FetchCore` as the low-level document and full-text-search core
- `FetchKit` as the higher-level document/search implementation layer
- `SwiftlyFetch` as a future umbrella product that becomes the shared public entry point across both the RAG and fetch surfaces

That is future-facing package-family planning, not a v1 implementation requirement. It should not distort the current retrieval-first scope, but it should be remembered when choosing names and public package boundaries now.

## Implementation Sequence

The first concrete implementation pass should happen in this order:

1. Define the core model types and protocols in `RAGCore`. Completed.
2. Implement a paragraph chunker in `RAGKit`. Completed.
3. Implement an in-memory cosine-similarity vector index in `RAGKit`. Completed.
4. Implement a deterministic hashing or fake embedder in `RAGKit`. Completed.
5. Implement the `KnowledgeBase` actor facade. Completed.
6. Add `NaturalLanguageEmbedder` backed by `NLContextualEmbedding`. Completed.
7. Add tests that target the public wrapper while injecting a fake backend. Completed.
8. Add opt-in integration tests for real Natural Language embedding behavior. Partially completed; the target exists and basic assertions are in place, but the semantic assertions should be strengthened.
9. Add a heading-aware markdown chunker as the first major retrieval-quality improvement. Completed.
10. Strengthen the real Natural Language integration assertions so asset-enabled runs prove useful similarity behavior, not just vector-shape correctness. Completed.
11. Tighten retrieval defaults around metadata filtering and context assembly without widening the package into chat or generation concerns. Completed with explicit exclusion filters, ordered typed comparisons, grouped annotated output, smarter duplicate suppression, and refined budget handling.
12. Keep default CI focused on `swift build` and `swift test`, and treat Apple-asset integration coverage as a separate opt-in verification path until the runner and asset story are stable.

That sequence matters because it gets a fully testable retrieval loop working before the repo takes on Apple asset-management complexity.

## Quality Bar For v1

Version 1 should feel:

- tiny
- obvious
- local-first
- Swift-native
- pleasant to read

The right success condition is not "supports everything." The right success condition is:

- a Swift app can create a knowledge base
- add markdown or text
- search it
- get predictable results
- assemble context for downstream use

If the package does that cleanly, it has a real foundation.

## Risks To Watch

- public API drift toward chat or generation concepts
- over-abstraction before the first useful retrieval flow exists
- leaking Apple-specific embedding details into `RAGCore`
- making tests depend on downloaded Natural Language assets
- turning `KnowledgeBase` into a generic orchestration layer instead of a retrieval facade
- widening ingestion scope too early with PDFs or connectors

## Immediate Follow-Up Work

- Strengthen the opt-in `NaturalLanguageEmbedder` integration test so it proves semantic retrieval behavior with a tiny corpus and ranking expectations, not just vector shape.
- Keep GitHub Actions green on the default macOS path with explicit `swift build` and `swift test` coverage.
- Keep [retrieval-defaults-follow-up.md](./retrieval-defaults-follow-up.md) as the remaining scope note for any future optional retrieval-default polish, and keep that work retrieval-first rather than drifting into answer synthesis or query-language design.

## Open Questions

- Should `SwiftlyFetch` remain the repository and umbrella package identity while the library products are `RAGCore` and `RAGKit`, or should the public product names stay closer to the repo name?
- Should metadata filtering begin with a small typed equality/filter set only, or should v1 include a slightly richer predicate surface?
- Should `KnowledgeBase.naturalLanguageDefault()` require explicit asset-availability handling by the caller, or should it offer a convenience path that can request assets automatically?
- Should integration tests for `NLContextualEmbedding` live behind a custom environment flag, a separate test target, or both?
