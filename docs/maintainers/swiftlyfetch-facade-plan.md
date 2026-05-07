# SwiftlyFetch Facade Plan

## Purpose

This note defines the first umbrella facade for the package family.

The goal is one consumer-facing surface that accepts a corpus document once and keeps both conventional search and semantic retrieval current.

The facade should not erase the package-family boundaries:

- `FetchKit` owns durable corpus storage and conventional full-text search.
- `RAGKit` owns semantic chunks, embeddings, vector search, and semantic index health.
- `SwiftlyFetch` coordinates one ingestion surface, semantic retry scheduling, and later hybrid search.

In plain language: app code should be able to say "add this document" once, then use keyword search, semantic retrieval, and eventually hybrid search over the same corpus.

## New Package Surface

Add a new library product and target named `SwiftlyFetch`.

The target should depend on:

- `FetchCore`
- `FetchKit`
- `RAGCore`
- `RAGKit`

This is a durable building-block change. The practical effect is that consumers can import one umbrella module when they want the coordinated experience, while still being able to import the sibling packages directly for lower-level control.

Do not move existing `FetchKit` or `RAGKit` APIs into the umbrella target. The facade should compose them.

## First Public Facade

Add a `SwiftlyFetchLibrary` actor.

Its first job is coordinated corpus ingestion and separate search entry points:

```swift
public actor SwiftlyFetchLibrary {
    public func addDocument(_ record: FetchDocumentRecord) async throws -> SwiftlyFetchMutationResult
    public func updateDocument(_ record: FetchDocumentRecord) async throws -> SwiftlyFetchMutationResult
    public func removeDocument(withID id: FetchDocumentID) async throws -> SwiftlyFetchMutationResult

    public func search(_ query: FetchSearchQuery) async throws -> [FetchSearchResult]
    public func retrieve(_ query: SearchQuery) async throws -> [SearchResult]
}
```

Use `search` for conventional search and `retrieve` for semantic retrieval. Do not add `hybridSearch` in the first facade slice. Hybrid ranking should wait until the one-corpus ingestion path and retry behavior are stable.

## Construction Shape

The facade should support dependency injection first:

```swift
public init(
    fetchLibrary: FetchKitLibrary,
    knowledgeBase: KnowledgeBase,
    retryStore: any SwiftlyFetchSemanticRetryStore
)
```

Then add a default in-memory constructor for tests and examples:

```swift
public static func `default`() async throws -> SwiftlyFetchLibrary
```

On macOS, add a persistent constructor after the injected path is proven:

```swift
public static func macOSPersistentLibrary(
    configuration: SwiftlyFetchPersistentConfiguration = .default
) async throws -> SwiftlyFetchLibrary
```

The persistent constructor should create:

- `FetchKitLibrary.macOSPersistentLibrary(...)`
- a persistent `KnowledgeBase` backed by `CoreDataVectorIndex`
- an umbrella-owned semantic retry store

The persistent configuration should be shaped around one storage root rather than asking callers to assemble separate store URLs for every internal component.

## Document Mapping

The bridge from `FetchDocumentRecord` to `RAGCore.Document` belongs in the `SwiftlyFetch` target.

`FetchCore` should not import `RAGCore`, and `RAGKit` should not import `FetchCore`.

First mapping policy:

- `FetchDocumentRecord.id.rawValue` maps to `DocumentID`.
- `.plainText` maps to `.text`.
- `.markdown` maps to `.markdown`.
- string metadata maps into `DocumentMetadata` string values.
- `kind`, `language`, `sourceURI`, `createdAt`, and `updatedAt` map into semantic metadata when present.
- `title` should be included in semantic metadata.
- `title` should also be included in semantic source text by default.

Title text should be part of semantic source text because many local corpus records are title-heavy. If the title only exists in metadata, semantic retrieval can miss the same document that conventional title search finds easily.

Recommended first text shaping:

```text
Title: <title>

<body>
```

For markdown records, use a markdown heading:

```markdown
# <title>

<body>
```

This title policy must be part of the source fingerprint, because changing it changes semantic derived state.

## Mutation Flow

For add and update:

1. Write the `FetchDocumentRecord` through `FetchKitLibrary`.
2. Map the stored record into a `RAGCore.Document`.
3. Ask `KnowledgeBase` to index the semantic document.
4. Return a mutation result with separate conventional and semantic outcomes.
5. If semantic indexing fails after the corpus write succeeds, enqueue a semantic retry by document ID and return a degraded mutation result rather than pretending the whole corpus write failed.

For remove:

1. Remove the document through `FetchKitLibrary`.
2. Remove semantic chunks through `KnowledgeBase`.
3. Remove any pending semantic retry for that document.
4. Return a mutation result with separate conventional and semantic outcomes.

The facade should make partial success explicit. A durable corpus write followed by a semantic indexing failure is not the same failure as a rejected corpus write.

The first facade should stay singular-only. Batch mutation APIs can follow after the single-document result model proves useful and readable.

## Mutation Result Shape

The first result should expose separate summaries rather than one flattened success flag.

Suggested shape:

```swift
public struct SwiftlyFetchMutationResult: Hashable, Sendable {
    public var documentIDs: [FetchDocumentID]
    public var conventional: SwiftlyFetchMutationStage
    public var semantic: SwiftlyFetchSemanticMutationStage
}
```

Where conventional and semantic stages can say:

- succeeded
- skipped
- queuedRetry
- failed

The semantic stage should carry the semantic index state when available. This lets callers show that conventional search is current while semantic retrieval is queued or degraded.

Conventional failures should throw before semantic work starts. Semantic failures after a successful corpus write should return `queuedRetry` and include the semantic failure detail instead of flattening the whole operation into one success flag.

## Semantic Retry Ownership

The umbrella facade owns retry scheduling.

RAGKit owns semantic health truth, but it does not know how to fetch the latest durable corpus record. The facade can fetch the latest `FetchDocumentRecord` from `FetchKit`, map it into a `RAGCore.Document`, and ask `KnowledgeBase` to index it again.

Add an umbrella-owned retry store protocol:

```swift
public protocol SwiftlyFetchSemanticRetryStore: Sendable {
    func upsert(_ retry: SwiftlyFetchSemanticRetry) async throws
    func pendingRetries(limit: Int?) async throws -> [SwiftlyFetchSemanticRetry]
    func removeRetries(for documentIDs: [FetchDocumentID]) async throws
}
```

Suggested retry record:

```swift
public struct SwiftlyFetchSemanticRetry: Hashable, Codable, Sendable {
    public var documentID: FetchDocumentID
    public var operation: SwiftlyFetchSemanticRetryOperation
    public var reason: String
    public var attemptCount: Int
    public var createdAt: Date
    public var lastAttemptAt: Date?
    public var nextRetryAt: Date?
    public var lastFailure: String?
}
```

The retry operation should distinguish semantic indexing from semantic removal. Index retries re-read the latest durable corpus record before mapping and indexing. Removal retries cannot re-read a deleted corpus record; they should retry semantic chunk cleanup by document ID and then clear any pending retry on success.

Add a retry entry point:

```swift
public func retrySemanticIndexing(limit: Int? = nil) async throws -> SwiftlyFetchSemanticRetryResult
```

Retry behavior:

1. Read pending retry records.
2. For index retries, fetch the latest document record from `FetchKitLibrary`.
3. If an index retry's document no longer exists, remove the retry.
4. Map the record to a semantic document.
5. Ask `KnowledgeBase` to index it.
6. For remove retries, ask `KnowledgeBase` to remove semantic chunks for the document ID.
7. On success, remove the retry.
8. On failure, update attempt count, last attempt date, next retry date, and last failure.

Use a simple first retry schedule. Exponential backoff can come later if real use demands it.

The default in-memory constructor should use the deterministic hashing semantic backend. Do not make `SwiftlyFetchLibrary.default()` depend on Apple Natural Language assets.

## Search Surface

The first facade should expose separate conventional and semantic calls:

- `search(_:)` returns `FetchSearchResult` from `FetchKit`.
- `retrieve(_:)` returns `SearchResult` from `RAGKit`.

Do not combine scores yet. Conventional scores and semantic cosine scores do not mean the same thing.

Once one-corpus ingestion and retry are stable, add either:

- a side-by-side hybrid response containing conventional and semantic result arrays, or
- a ranked hybrid response with an explicit score-combination policy.

Side-by-side should be the first hybrid experiment unless a concrete caller needs one ranked list immediately.

## First Implementation Slices

### Slice 1: Package Surface And Mapping

- Add the `SwiftlyFetch` product and target.
- Add the `SwiftlyFetchTests` target.
- Add `SwiftlyFetchDocumentMapper`.
- Cover title/body/content-type/metadata mapping.
- Update README and roadmap to name the umbrella target.

### Slice 2: Facade With In-Memory Dependencies

- Add `SwiftlyFetchLibrary`.
- Add injected construction.
- Add default in-memory construction.
- Implement add, update, remove, `search`, and `retrieve`.
- Return separate conventional and semantic mutation outcomes.
- Cover successful one-corpus ingestion into both `FetchKit` and `RAGKit`.

### Slice 3: Retry Store

- Add `SwiftlyFetchSemanticRetryStore`.
- Add an in-memory retry store.
- Add a Core Data retry store for persistent facade construction.
- Queue retry when semantic indexing fails after corpus write succeeds.
- Add `retrySemanticIndexing(limit:)`.
- Cover success, failed retry update, and missing-document cleanup.

### Slice 4: Persistent Construction

- Add `SwiftlyFetchLibrary.macOSPersistentLibrary(...)`.
- Shape configuration around one storage root.
- Create persistent conventional search, semantic vector index, and retry store under that root.
- Cover persistent reopen behavior.

### Slice 5: Hybrid Search Planning

- Inspect the first facade result behavior against a small corpus.
- Decide whether the first hybrid response should be side-by-side or ranked.
- Add hybrid search only after the ingestion and retry model is stable.

## Definition Of Done For First Facade Milestone

- A caller can add one document once and query both conventional and semantic search.
- Conventional and semantic mutation outcomes are visible separately.
- Semantic indexing failures after corpus writes are queued for retry.
- RAG-owned semantic state reports current or failed state for documents touched by the facade.
- Retry fetches the latest corpus record before re-indexing.
- README, roadmap, and maintainer docs describe the split honestly.

## Non-Goals

Do not add these in the first facade milestone:

- hybrid ranking
- answer generation
- chat sessions
- agents
- PDF ingestion
- remote search or embedding providers
- connector-heavy ingestion
- a broad query language
