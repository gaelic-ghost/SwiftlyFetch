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

## Package Family Direction

The intended family split is:

- `RAGCore` and `RAGKit` for semantic retrieval
- `FetchCore` and `FetchKit` for traditional document search, with Core Data as the durable corpus store and SearchKit as the first macOS full-text indexing backend
- `SwiftlyFetch` as the umbrella product story tying those sibling package surfaces together

In plain language: `RAGKit` is where semantic retrieval and its related chunking, embedding, indexing, and knowledge-base behavior should keep growing. `FetchKit` is the home for conventional search responsibilities, with Core Data holding the corpus and SearchKit providing the first full-text indexing path on macOS. `SwiftlyFetch` is the name that should describe the whole family rather than forcing those two jobs into one package surface.

The more detailed conventional-search plan now lives in [fetchkit-product-plan.md](./fetchkit-product-plan.md).

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
- markdown chunking now uses a parser-backed internal section model built on [swift-markdown](https://github.com/swiftlang/swift-markdown) instead of the earlier line-based heading scanner
- list-item chunks now preserve immediate lead-in context in chunk text and also expose chunk metadata for block kind, list kind, lead-in, ordinal, and heading path
- block quotes stay secondary by default but are promoted into the primary retrieval stream when they make up more than one third of the document's chunkable block structure
- code blocks stay secondary by default but are promoted into the primary retrieval stream when they make up more than one third of a document's chunkable block structure, and code languages are exposed through chunk and document-level metadata
- thematic breaks act as section-boundary hints that can carry a short lead-in into the next retrieval chunk instead of becoming standalone chunk text
- markdown images keep alt text primary while carrying image-reference metadata, and raw HTML only contributes retrieval chunks for a narrow whitelist that currently includes `img` plus `details` / `summary`
- markdown fallback is now selective, so parser-backed policy decisions remain authoritative instead of automatically dropping back to plain paragraph chunking for rejected markdown-only inputs
- markdown tables now produce one retrieval chunk per body row with header-aware text and table-row metadata
- inline links and reference links now default to visible anchor text in chunk text, while raw destinations and reference definitions stay secondary and do not become standalone retrieval chunks unless a caller explicitly opts into chunk metadata for destinations
- deterministic tests cover the main retrieval flow and the Natural Language wrapper seam
- a real Natural Language integration test target exists, now runs in default local maintainer validation, and remains out of the default GitHub-hosted lane because the hosted `macos-15` path stalled in the Natural Language step

Still intentionally incomplete:

- markdown policy refinement for additional block kinds and future evolution
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
- heading-aware markdown chunking is implemented, parser-backed, and now backs the default markdown path
- list semantics are preserved in both chunk text and chunk metadata for retrieval quality and downstream indexing use
- quote-heavy documents can promote block quotes into the primary retrieval stream when quoted material is a substantial share of the document structure
- code-heavy documents can promote code blocks into the primary retrieval stream while still exposing language metadata on all chunks from the document
- thematic breaks can carry short section lead-ins into the next retrieval chunk without becoming standalone chunks
- markdown images and a narrow raw-HTML whitelist now have explicit retrieval behavior instead of falling through generic plain-text rendering
- policy-rejected markdown-only inputs no longer fall back to plain paragraph chunking
- markdown tables now produce header-aware row chunks for retrieval
- link destinations can now be recorded in chunk metadata through an explicit opt-in mode, while default chunk text stays anchor-text-first
- the next chunking work is policy refinement beyond the current links-and-references baseline, not first-parser adoption

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
- the Natural Language integration target exists
- real Apple-backed integration coverage now checks semantic retrieval behavior rather than only non-empty normalized vectors
- default CI proves `swift build` and `swift test` on the ordinary macOS path, while the asset-backed Natural Language integration target stays outside GitHub-hosted CI for now

Current CI position:

- keep the default validation job free of Apple asset requirements
- keep the Natural Language integration lane in default local maintainer validation, but do not make GitHub-hosted CI run it unless an explicit hosted experiment is being performed
- record that the GitHub-hosted `macos-15` attempt started successfully but remained stuck in the Natural Language integration step until the job timeout
- record that a later hosted GitHub experiment still remained stuck in that asset-backed step for several minutes even though the same local lane completed in only a few seconds
- if asset-backed automation becomes important later, prefer a self-hosted macOS runner with known asset state over retrying the same hosted setup unchanged

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

## Package Family Note

The repository has already grown beyond the original retrieval-only module plan.

The current family direction is:

- `RAGCore` and `RAGKit` stay responsible for semantic retrieval: chunking, embeddings, vector indexing, semantic search, filtering, and context assembly
- `FetchCore` is the low-level document and traditional full-text-search core
- `FetchKit` is the higher-level document/search implementation layer, centered on Core Data as the durable store and SearchKit-backed indexing and retrieval on macOS first
- `SwiftlyFetch` is the umbrella product story that can eventually sit above both the semantic retrieval and traditional search families

In plain language: `RAGKit` should not slowly become the home for conventional document search just because the repository name is broad. The intended model is sibling families with different search jobs, not one module family that tries to own everything.

That family split is now real code, not just future-facing package-family planning. It still should not distort the retrieval-first scope of this document, but it should continue guiding naming and boundary decisions so later `FetchKit` work does not force conventional search concerns into the RAG modules.

## Implementation Sequence

The first concrete implementation pass should happen in this order:

1. Define the core model types and protocols in `RAGCore`. Completed.
2. Implement a paragraph chunker in `RAGKit`. Completed.
3. Implement an in-memory cosine-similarity vector index in `RAGKit`. Completed.
4. Implement a deterministic hashing or fake embedder in `RAGKit`. Completed.
5. Implement the `KnowledgeBase` actor facade. Completed.
6. Add `NaturalLanguageEmbedder` backed by `NLContextualEmbedding`. Completed.
7. Add tests that target the public wrapper while injecting a fake backend. Completed.
8. Add opt-in integration tests for real Natural Language embedding behavior. Completed.
9. Add a heading-aware markdown chunker as the first major retrieval-quality improvement. Completed.
10. Strengthen the real Natural Language integration assertions so asset-enabled runs prove useful similarity behavior, not just vector-shape correctness. Completed.
11. Tighten retrieval defaults around metadata filtering and context assembly without widening the package into chat or generation concerns. Completed with explicit exclusion filters, ordered typed comparisons, grouped annotated output, smarter duplicate suppression, and refined budget handling.
12. Keep default GitHub-hosted CI focused on `swift build` and `swift test`, while running Apple-asset integration coverage in local maintainer validation until a better runner strategy exists.

That sequence matters because it gets a fully testable retrieval loop working before the repo takes on Apple asset-management complexity.

## Markdown Refinement Direction

The current heading-aware markdown chunker already uses a real parser through [swift-markdown](https://github.com/swiftlang/swift-markdown), which was the right call for the first public release.

That does not mean markdown policy is finished. It means the remaining work should build on the parser-backed structure instead of drifting back toward ad hoc local parsing rules.

The practical decision rule should be:

- use a real markdown parser to understand markdown structure
- keep retrieval-specific chunking policy in this package
- avoid rebuilding markdown parsing rules locally unless a parser-backed approach is clearly unworkable for the retrieval job

In plain language: parsing markdown syntax and deciding how retrieval chunks should be assembled are different jobs. The package should prefer borrowing the parsing job from a well-maintained parser and keep owning only the retrieval policy built on top of that structure.

The `swift-markdown` adoption should be treated as an intentional scope tradeoff: one external dependency in exchange for significantly stronger markdown correctness and less parser maintenance risk in this package.

Current outcome:

- the package now uses `swift-markdown` as the parsing layer for markdown chunking
- chunk text still carries the local structure the embedder needs for high-quality retrieval
- chunk metadata now also carries structured list and heading information for downstream fetching, indexing, or filtering work
- block quotes are still not first-class by default, but quote-heavy documents can promote them into the primary retrieval stream when they cross the current one-third block-structure threshold
- code blocks are still secondary by default, but code-heavy documents can promote them into the primary retrieval stream and carry code-language metadata
- thematic breaks can turn a short preceding paragraph into section context for the next chunk instead of becoming retrieval text themselves
- image alt text stays primary, image sources and titles stay in metadata, and raw HTML remains whitelist-only so layout wrappers do not pollute retrieval text
- fallback now acts as a rescue path instead of a second markdown policy, so rejected markdown-only content returns no chunks instead of sneaking back in as plain text

## Tables And Links Direction

The next markdown policy surface should focus on tables first and links second.

### Tables

The preferred table model is:

- treat each table body row as the primary retrieval chunk unit
- render row chunks with header-aware text so the embedder sees the column meaning, not only the raw cell values
- add chunk metadata that marks the chunk as a table row and preserves enough table structure for downstream indexing or fetching work

In plain language: a table row should not become a bare `"Qwen | Retrieval"` string if the real meaning is `"Model: Qwen"` and `"Use: Retrieval"`.

Current outcome:

- markdown tables now produce one retrieval chunk per body row
- each row chunk renders header-aware text so the embedder sees the column meaning directly
- chunk metadata marks table rows and preserves row index plus header context for downstream indexing or fetching work

### Links And References

The preferred link model is:

- keep visible anchor text primary in chunk text
- keep raw destinations secondary by default
- prefer structured metadata for destinations if downstream consumers need them later
- do not promote reference-link definitions into standalone retrieval chunks unless a concrete retrieval use case proves they matter

In plain language: the words around a link usually matter more for retrieval than the URL itself.

Current outcome:

- inline links and reference links now default to anchor-text-only chunk text
- raw destinations do not pollute chunk text by default
- reference-link definitions do not become standalone retrieval chunks
- callers can now opt into chunk-scoped destination metadata when downstream indexing or fetch-oriented work needs it
- any future link work should focus on whether additional structured link metadata is worth carrying, not on putting URLs into chunk text

## Markdown Refactor Execution Plan

The markdown refactor should happen in deliberately staged passes instead of one big rewrite.

### Phase 1: Characterize Current And Desired Behavior

Before changing implementation, add deterministic tests that pin both the currently desired retrieval behavior and the cases the current scanner is likely to mishandle.

That test pass should cover:

- preamble text before the first heading
- nested heading paths across multiple heading depths
- consecutive headings with empty sections
- fenced code blocks that contain `#` characters which should not be treated as headings
- block quotes and list items under headings
- heading-only sections with no body
- source-offset expectations for produced chunk positions

The goal of this phase is not to freeze every current bug forever. The goal is to make the upcoming parser change measurable instead of intuitive.

### Phase 2: Add An Internal Markdown Structure Seam

Before adopting a parser dependency, introduce an internal representation for markdown-derived retrieval sections.

That internal seam should be narrow and package-private. It should model only what the chunker needs:

- the extracted body text or source range
- the active heading path for that body
- the source offsets needed to produce stable `ChunkPosition` values

This is a local implementation detail, not a public API change. The practical effect is that the line-based scanner and any future parser-backed implementation can target the same internal shape.

### Phase 3: Evaluate A Parser-Backed Implementation

Once the internal seam exists and the tests are in place, spike a parser-backed implementation with [swift-markdown](https://github.com/swiftlang/swift-markdown).

The relevant documented behavior we are relying on is:

- Swift `Markdown` is a Swift package for parsing, building, editing, and analyzing Markdown documents
- it parses through `Document(parsing:)`
- it is powered by `cmark-gfm`, so it follows GitHub-flavored Markdown closely

In practical terms, that means the parser can own syntax understanding while this package still owns retrieval-specific chunk policy.

### Phase 4: Choose Retrieval Policy Explicitly

The parser does not answer the retrieval policy questions by itself. Before the final swap, make the following decisions explicit in code and tests:

- whether heading text stays a prefix on chunk text as it does today
- whether list items should merge into nearby prose or split into their own chunks
- how fenced code blocks should behave for retrieval and promotion
- whether block quotes should stay inline with surrounding text or become separate chunk material
- how preamble text before the first heading should behave

The default recommendation is conservative:

- keep heading-prefix context
- preserve preamble text as chunks without heading context
- treat ordinary prose and list content as chunkable text
- keep code blocks secondary by default, but promote them when they are a meaningful share of the document
- treat thematic breaks as section-boundary hints rather than standalone retrieval chunks

### Phase 5: Swap The Chunker Behind The Existing Public API

Only after the previous phases are green should `HeadingAwareMarkdownChunker` switch from the current scanner-backed implementation to the chosen internal structure provider.

The public contract should stay stable:

- markdown documents still go through a markdown-aware chunker
- plain text still falls back to paragraph chunking
- produced chunks still carry inherited metadata and stable chunk identifiers

### Phase 6: Validate Offsets And Retrieval Quality

The highest-risk part of the refactor is source-offset fidelity.

The current scanner computes offsets directly from the source string. A parser-backed implementation must prove that `ChunkPosition.startOffset` and `endOffset` still correspond to meaningful source ranges in the original markdown text.

This validation should include:

- deterministic tests for offsets on representative markdown samples
- a retrieval smoke test showing that heading-context behavior still helps search results surface the intended section

### Recommended Commit Shape

Prefer landing this work in small focused commits:

1. maintainer docs and roadmap alignment
2. markdown characterization tests
3. internal markdown section seam
4. parser dependency and parser-backed implementation, if adopted
5. follow-up heuristics only if the parser-backed path still needs retrieval-specific refinement

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
