# Hybrid Search Persistence Plan

## Purpose

This note records the persistence direction for the package-family step where `SwiftlyFetch` becomes one local corpus with both conventional and semantic search.

The chosen direction is:

- `FetchKit` owns the durable corpus store.
- `FetchKit` derives and maintains the conventional full-text index.
- `RAGKit` owns the semantic chunk and vector index as a derived store.
- A future umbrella surface coordinates one ingestion call across both search modes.

In plain language: app code should eventually add a document once, then get both keyword search and semantic retrieval over that same corpus. Internally, the two search systems should remain sibling derived indexes instead of being forced into one module.

## Current Problem

The package already has durable conventional-search storage and sync recovery through `FetchKit`.

The semantic side has had the right public protocol shape through `VectorIndex`, but the default implementation was memory-only. That meant an app could persist its conventional search corpus and SearchKit index, while semantic retrieval had to be rebuilt after restart by re-chunking and re-embedding the corpus.

That asymmetry is the concrete behavior this plan fixes.

## Ownership Model

### FetchKit

`FetchKit` owns the durable source corpus.

Its responsibilities are:

- store document records
- expose typed document mutation and lookup operations
- derive conventional full-text indexing changes
- keep SearchKit or future conventional-search backends current

`FetchKit` should not start owning semantic chunks, embeddings, or vector search behavior.

### RAGKit

`RAGKit` owns semantic derived state.

Its responsibilities are:

- chunk source documents
- embed chunks and queries
- persist semantic chunks and vectors
- persist per-document semantic index health
- search vectors through the `VectorIndex` protocol
- remove semantic chunks by document identifier

The first persisted semantic backend is `CoreDataVectorIndex`. Core Data is a practical first backend because it is already part of the package's Apple-first persistence story, but the public contract remains `VectorIndex` so a future backend can replace it without changing `KnowledgeBase`.

The semantic index state model is RAG-owned, not umbrella-owned. It records whether a document's semantic derived state is:

- `missing`
- `indexing`
- `current`
- `stale`
- `failed`

That state carries a semantic fingerprint made from:

- a source fingerprint for the document content and retrieval-relevant metadata
- a chunker fingerprint for the chunking policy
- an embedder fingerprint for the embedding policy

This lets `RAGKit` answer whether its own semantic index is trustworthy without needing to inspect a future retry queue.

### Future Umbrella Surface

The future umbrella surface should coordinate the two sibling systems.

Its job should be:

- accept one app-level document ingestion call
- write the durable corpus record through `FetchKit`
- update the conventional search index
- derive the semantic document input for `RAGKit`
- update the semantic vector index
- enqueue document IDs for semantic retry if semantic indexing fails after the corpus write succeeds
- expose conventional, semantic, and later hybrid search entry points

That facade should land after the semantic index is persistent. Otherwise it would hide a real durability mismatch behind a nicer API.

The umbrella facade should own retry scheduling because retry needs to fetch the latest corpus record from `FetchKit` before re-indexing. `RAGKit` should own semantic health truth because it knows whether its chunks and vectors are current, stale, failed, or missing.

## First Implementation Slice

The first slice adds `CoreDataVectorIndex` in `RAGKit`.

It persists:

- chunk ID
- document ID
- chunk text
- chunk metadata
- chunk position
- embedding vector
- update timestamp
- per-document semantic index status
- semantic index fingerprint
- last indexed timestamp
- last failure description

This is a durable building-block change. It gives `KnowledgeBase` restart-safe semantic retrieval without changing `RAGCore.VectorIndex` or making `FetchCore` depend on `RAGCore`.

The first convenience constructors are:

- `KnowledgeBase.persistentHashingDefault(configuration:dimension:)`
- `KnowledgeBase.persistentNaturalLanguageDefault(configuration:languageHint:)`

These constructors keep the same chunker and embedder defaults as the in-memory defaults while swapping in the Core Data-backed vector index.

## Follow-Up Design Work

The next architecture work should focus on shared corpus ingestion rather than another standalone index backend. The detailed umbrella plan lives in [swiftlyfetch-facade-plan.md](./swiftlyfetch-facade-plan.md).

Recommended order:

1. Expand and harden the existing bridge from `FetchDocumentRecord` to `RAGCore.Document`.
2. Extend the umbrella library facade ingestion lifecycle beyond one-corpus add/search/retrieve basics.
3. Evolve the umbrella-owned semantic retry queue policy with attempt strategy, cooldown tuning, and backlog management.
4. Add hybrid result packaging only after conventional and semantic result paths are each independently durable.

## Open Questions

- Should the umbrella facade return one combined mutation result or separate conventional and semantic mutation summaries?
- Should hybrid search combine scores inside the umbrella facade, or should it expose side-by-side result sets first?

## Non-Goals

Do not use this work to add:

- generation
- chat orchestration
- agents
- remote embedding providers
- PDF ingestion
- connector-heavy ingestion
- a broad query language

The owned job is still local search and retrieval over app-owned corpora.
