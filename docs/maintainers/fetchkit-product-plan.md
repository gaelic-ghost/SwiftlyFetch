# FetchKit Product Plan

## Purpose

This document defines the intended direction for the traditional-search side of the `SwiftlyFetch` family.

The short version:

- `RAGKit` is the semantic retrieval package family.
- `FetchKit` is the conventional document-search package family.
- `SwiftlyFetch` is the umbrella product that should make both feel like one coherent local search story for Apple apps.

## Product Job

`FetchKit` should make it easy to hand the system a corpus of local documents and get back a real document search engine.

That means:

- store document records and related app data durably
- build and maintain a searchable full-text index
- run traditional keyword and phrase search
- return document hits, snippets, and metadata
- stay pleasant to use from ordinary Swift app code

In plain language: `FetchKit` is the "search engine over my local corpus" side of `SwiftlyFetch`, while `RAGKit` is the "semantic retrieval over my local corpus" side.

## Architectural Model

The intended storage and indexing model is:

- Core Data is the durable local source of truth for documents, metadata, relationships, and app-owned state
- Search Kit is the macOS full-text indexing and lookup engine
- `FetchKit` owns the sync between stored documents and the search index

That means `FetchKit` should not treat Search Kit as the database. Core Data remains the durable store. Search Kit is the derived full-text index that powers conventional search.

This is an inference from Apple's framework surfaces rather than a single Apple document that describes the whole stack directly:

- [Search Kit](https://developer.apple.com/documentation/coreservices/search_kit) describes the indexing and search framework
- [Core Data](https://developer.apple.com/documentation/coredata/) describes the persistence layer for model objects and relationships

## Package Family Direction

The intended split is:

- `FetchCore` for stable, portable document-search models and protocols
- `FetchKit` for the Apple implementation layer
- a macOS-first Search Kit backend inside `FetchKit`

`FetchCore` should stay portable and boring.

Its job should be to define things like:

- document record identifiers
- searchable document representations
- document field metadata
- search queries for exact, prefix, phrase, and boolean-style lookup
- document search results and match ranges
- snippet and ranking support types
- indexing and storage protocols where they need to be public

`FetchKit` should be the opinionated implementation layer.

Its near-term job should be to provide:

- a Core Data-backed document store
- a Search Kit-backed full-text index on macOS
- simple facades for indexing, updating, deleting, and searching
- result packaging that feels natural in SwiftUI and AppKit apps

## Platform Direction

`FetchCore` should remain cross-Apple from the start.

`FetchKit` should be honest about the implementation reality:

- macOS should be first-class immediately
- iOS should remain a first-class product target at the umbrella level
- iOS may need a different indexing backend later because the first planned full-text path is Search Kit on macOS

In practical terms, that means:

- do not bake Search Kit types or assumptions into `FetchCore`
- do let `FetchKit` start macOS-first if that is the cleanest real backend
- keep room for a different iOS indexing backend later without redefining the `FetchCore` vocabulary

## Relationship To RAGKit

`FetchKit` and `RAGKit` should complement each other, not compete for ownership.

`RAGKit` owns:

- chunking
- embeddings
- semantic indexing
- semantic retrieval
- retrieval-context assembly

`FetchKit` owns:

- document records
- durable corpus storage
- full-document indexing
- keyword and phrase search
- snippet extraction
- conventional search ranking

The same app should eventually be able to use both against the same underlying corpus without needing to think of them as unrelated products.

That is the practical value of `SwiftlyFetch` as the umbrella: one local corpus, two complementary search modes.

## Near-Term Milestone Shape

The first `FetchKit` milestone should stay docs-first and vocabulary-first.

That should include:

- define the package-family boundary clearly in public and maintainer docs
- design `FetchCore` value types and protocols before adding a backend
- decide the first Core Data document model shape
- decide the sync boundary between Core Data records and the Search Kit index
- only then add the first macOS Search Kit implementation work

## Non-Goals For The First FetchKit Pass

Do not begin with:

- semantic retrieval features that belong in `RAGKit`
- remote search services
- cloud sync
- cross-process index daemons
- PDF or connector ingestion
- iOS backend abstraction before the macOS-first path is concrete

The first job is to define a clean local document-search model, not to solve every search backend at once.
