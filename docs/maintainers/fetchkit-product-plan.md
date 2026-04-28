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

The public-facing wording should stay simple:

- `SwiftlyFetch` means "give the family a corpus and get back real local search"
- `FetchKit` means conventional full-document search over that corpus
- `RAGKit` means semantic retrieval over that corpus

That wording matters because the family should read like one product with two complementary search modes, not like unrelated packages that happen to share a repository.

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

Current status:

- `FetchCore` now exists as the first portable vocabulary target in the package
- the initial code surface covers document identifiers, durable document records, indexable document views, search queries, search results, snippets, match ranges, store/index protocols, and an explicit indexing changeset boundary
- the durable record shape now promotes typed lifecycle and source fields such as `kind`, `language`, `createdAt`, `updatedAt`, `sourceURI`, and `lastIndexedAt`, while keeping the freeform metadata bag string-based for now
- the store-to-index boundary now uses a richer index-facing payload instead of dropping typed record fields through the sync changeset
- `FetchKitLibrary` now offers a default in-memory construction path plus explicit dependency injection for custom store and index implementations
- the public facade now includes singular and batch document verbs, a tighter `document(withID:)` lookup surface, and typed batch results for write operations
- `FetchKit` now has its first Core Data-backed `FetchDocumentStore` implementation, built from a programmatic Core Data model that matches the current durable record shape
- the store side now produces explicit `FetchIndexingChangeset` values through `FetchStoreMutationResult`, so the index-sync boundary is derived from real store writes instead of being reconstructed ad hoc in the facade
- pending index-sync work is now persisted by the store itself and can be retried later through the `FetchKitLibrary` facade, so a failed index apply no longer relies only on an in-memory thrown error for recovery
- the first thin Search Kit backend now exists behind `FetchIndex`, and its direct tests now sit behind XCTest-style opt-in gating so the default package path can stay clean
- the Search Kit crash isolation pass found that `SKIndex` teardown needed unretained adoption on create/open, and the direct opt-in Search Kit verification lane is green again under both `swift test` and `xcodebuild test`
- that Search Kit verification lane is still local-only for now, while the repo defers any dedicated CI story for it
- Search Kit is still intentionally deferred until the durable corpus store and record mapping prove themselves in code

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
- iOS will likely need a different indexing backend because Apple documents Search Kit as the Mac-side indexing and search framework, while Core Spotlight is the more natural Apple-side search/indexing surface on iOS

In practical terms, that means:

- do not bake Search Kit types or assumptions into `FetchCore`
- do let `FetchKit` start macOS-first if that is the cleanest real backend
- keep room for a different iOS indexing backend later without redefining the `FetchCore` vocabulary

So "iOS is first-class" should mean:

- the family product story includes iOS from the start
- `FetchCore` stays portable enough to support iOS cleanly
- public docs should avoid implying that the first macOS Search Kit backend already solves iOS
- when iOS backend work starts, it should land as a real backend decision rather than as compatibility wording

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

## First Core Data Entity Shape

The first Core Data model should stay deliberately small.

Start with one primary entity:

- `FetchStoredDocument`

Its durable attributes should map closely to `FetchDocumentRecord`:

- `id: String`
- `title: String?`
- `body: String`
- `contentTypeRaw: String`
- `kindRaw: String?`
- `language: String?`
- `sourceURI: String?`
- `createdAt: Date?`
- `updatedAt: Date?`
- `lastIndexedAt: Date?`

For the freeform metadata bag, the first model should avoid a transformable blob unless a concrete need proves it is worth the opacity. The cleaner first pass is a second entity:

- `FetchStoredDocumentMetadataEntry`

with:

- `key: String`
- `value: String`
- relationship back to `FetchStoredDocument`

That keeps the durable schema explicit, queryable, and migration-friendly.

This follows Apple’s Core Data guidance that the real object graph should be modeled through explicit entities, attributes, and relationships in the model rather than hidden in opaque storage by default.

References:

- [Core Data model](https://developer.apple.com/documentation/coredata/core-data-model)
- [Modeling data](https://developer.apple.com/documentation/coredata/modeling-data)
- [Configuring Entities](https://developer.apple.com/documentation/coredata/configuring-entities)

## First Sync Semantics

The first Search Kit sync flow should be one-way and derived:

1. `FetchDocumentStore` persists `FetchDocumentRecord`-shaped data in Core Data.
2. Store-side change observation determines which stored records need indexing work.
3. Those record changes are converted into `FetchIndexingChangeset`.
4. The changeset carries `FetchIndexDocument` values into the Search Kit index.
5. When indexing succeeds, `lastIndexedAt` is written back to the stored document record.

In plain language: Core Data is the source of truth, Search Kit is a derived full-text cache, and `lastIndexedAt` is the durable marker that tells us whether the cache is caught up.

The first pass should not try to make Search Kit authoritative for anything. Rebuildability matters more than clever bidirectional sync.

## First Indexing Rules

The first Search Kit backend should index:

- `title`
- `body`

It may also use these typed fields as indexing or ranking hints:

- `kind`
- `language`
- `sourceURI`
- `createdAt`
- `updatedAt`

The metadata-entry relationship should stay available for later indexing decisions, but the first backend does not need to dump every metadata key into full-text search immediately.

## First Non-Goals For The Entity Model

Do not add these in the first Core Data shape:

- attachment or blob storage
- separate version-history entities
- tag-normalization entities unless repeated real queries justify them
- denormalized semantic-chunk storage that belongs in `RAGKit`
- bidirectional index bookkeeping beyond `lastIndexedAt`

The first model should prove the corpus store and Search Kit sync path, not solve every future content-management feature.

## Non-Goals For The First FetchKit Pass

Do not begin with:

- semantic retrieval features that belong in `RAGKit`
- remote search services
- cloud sync
- cross-process index daemons
- PDF or connector ingestion
- iOS backend abstraction before the macOS-first path is concrete

The first job is to define a clean local document-search model, not to solve every search backend at once.
