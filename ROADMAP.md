# Project Roadmap

Use this roadmap to track milestone-level delivery through checklist sections.

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 0: Foundation](#milestone-0-foundation)
- [Milestone 1: Retrieval Defaults](#milestone-1-retrieval-defaults)
- [Milestone 2: Post-v0.1.0 Refinement](#milestone-2-post-v010-refinement)
- [Milestone 3: FetchKit Foundation](#milestone-3-fetchkit-foundation)
- [Milestone 4: FetchKit Refinement](#milestone-4-fetchkit-refinement)
- [Milestone 5: FetchKit Platform And CI Decisions](#milestone-5-fetchkit-platform-and-ci-decisions)
- [Backlog Candidates](#backlog-candidates)
- [History](#history)

## Vision

- Deliver a small, dependable Apple-platform Swift package with a clear public library surface and a maintainable repo workflow from the start.

## Product Principles

- Keep the package manifest explicit about supported platforms, products, and Swift language mode.
- Prefer simple, readable Swift and Swift Testing over extra scaffolding.
- Keep README, roadmap, and maintainer workflow guidance in sync with the actual repo state.

## Milestone Progress

- Milestone 0: Foundation - Completed
- Milestone 1: Retrieval Defaults - Completed
- Milestone 2: Post-v0.1.0 Refinement - Completed
- Milestone 3: FetchKit Foundation - Completed
- Milestone 4: FetchKit Refinement - In Progress
- Milestone 5: FetchKit Platform And CI Decisions - Planned

## Milestone 0: Foundation

### Status

Completed

### Scope

- [x] Establish the root Swift package scaffold for a library product.
- [x] Pin the initial deployment floors to macOS 15 and iOS 18.
- [x] Put baseline maintainer docs and repo-maintenance tooling in place.
- [x] Define the first real retrieval package surface through `RAGCore` and `RAGKit`.
- [x] Bring maintainer guidance and roadmap checkpoints fully in line with the new retrieval package shape.

### Tickets

- [x] Initialize the package with Swift Testing enabled.
- [x] Add canonical `README.md` and `ROADMAP.md` structure.
- [x] Add repo guidance and validation scripts.
- [x] Create the public GitHub repository and push the initial bootstrap state.
- [x] Refactor the package into `RAGCore` and `RAGKit`.
- [x] Add the first retrieval implementations and deterministic tests.
- [x] Sync `AGENTS.md` into the broader canonical maintainer shape while preserving Swift package workflow guidance.

### Exit Criteria

- [x] The package builds and tests successfully on the local Swift 6 toolchain.
- [x] The repository has maintainer-facing workflow guidance and canonical starter docs.
- [x] The package exposes a real retrieval-oriented API surface beyond bootstrap scaffolding.
- [x] The maintainer docs, roadmap, and AGENTS guidance all reflect the current retrieval package architecture.

## Milestone 1: Retrieval Defaults

### Status

Completed

### Scope

- [x] Verify the real Apple-backed embedding path beyond the current deterministic and seam-level coverage.
- [x] Improve retrieval quality through markdown-aware chunking and tighter retrieval defaults.
- [x] Keep the package ergonomic for Apple-platform app developers while preserving retrieval-first boundaries and zero external dependencies.

### Tickets

- [x] Add the heading-aware markdown chunker as the next retrieval-quality improvement after the current paragraph chunker.
- [x] Add an opt-in `RAGKitIntegrationTests` target for real `NaturalLanguageEmbedder` coverage without making the default suite depend on Apple assets.
- [x] Strengthen the real `NaturalLanguageEmbedder` assertions so asset-enabled runs prove useful similarity behavior, not just vector-shape correctness.
- [x] Tighten metadata filtering and context assembly only as far as needed for a clean retrieval-first v1.
- [x] Add CI checks that run `swift build` and `swift test` on the default macOS path without making Apple-asset integration coverage mandatory.
- [x] Replace the README overview placeholder text with settled project language.

### Exit Criteria

- [x] The package has a clean default local retrieval flow with both deterministic coverage and verified Apple-backed embedding behavior.
- [x] Markdown-aware chunking is available for the main ingestion surface.
- [x] Maintainer docs clearly describe the current architecture and v1 boundaries.

## Milestone 2: Post-v0.1.0 Refinement

### Status

Completed

### Scope

- [x] Finish the remaining markdown-policy refinement work now that the package has a parser-backed chunking implementation.
- [x] Record the sibling-family architecture clearly: `RAGKit` for semantic retrieval, `FetchKit` for traditional document and full-text search over SearchKit and Core Data, and `SwiftlyFetch` as the umbrella product story.
- [x] Record that Apple-asset integration coverage remains local-only for now because the GitHub-hosted macOS attempt timed out in the Natural Language verification step.

### Tickets

- [x] Evaluate replacing the current line-based heading scanner with a real markdown parser, with [`swift-markdown`](https://github.com/swiftlang/swift-markdown) as the first candidate.
- [x] Add edge-case tests for heading-aware markdown chunking and paragraph splitting that cover the chosen parser-backed or scanner-backed design explicitly.
- [x] Add an internal markdown-structure seam so the current scanner and any future parser-backed implementation can target the same chunk-construction shape.
- [x] Preserve list semantics in both chunk text and chunk metadata so lead-in context, ordered-list ordinals, and heading path are available to retrieval and downstream consumers.
- [x] Keep block quotes secondary by default, but promote them when quote-heavy documents would otherwise hide a meaningful share of the retrieval surface.
- [x] Add table-row chunking with header-aware text and chunk metadata so markdown tables carry usable retrieval structure.
- [x] Decide the default link and reference policy so visible anchor text stays primary and raw destinations remain secondary unless a concrete retrieval need proves otherwise.
- [x] Add opt-in, chunk-scoped link-destination metadata without widening default chunk text.
- [x] Record the package-family direction in maintainer docs and public docs so future `FetchCore` and `FetchKit` work does not leak conventional search responsibilities into `RAGKit`.
- [x] Record that `RUN_NL_INTEGRATION_TESTS=1` remains explicit local-only verification because the GitHub-hosted `macos-15` run timed out in that step.

### Exit Criteria

- [x] The markdown ingestion path is materially more correct and better covered, while still staying retrieval-first and Apple-first.
- [x] Markdown chunk metadata and chunk text both carry enough local structure to support high-quality retrieval and downstream fetching or indexing work.
- [x] The package family and responsibility split are documented clearly enough to guide follow-on API decisions.
- [x] The team has a settled decision on whether asset-enabled integration coverage belongs in optional CI, self-hosted CI, or local-only verification, and why.

## Milestone 3: FetchKit Foundation

### Status

Completed

### Scope

- [x] Define the product boundary and maintainer plan for `FetchCore` and `FetchKit`.
- [x] Establish `FetchCore` as the portable vocabulary for conventional document search.
- [x] Design a macOS-first `FetchKit` architecture with Core Data as the durable corpus store and SearchKit as the full-text indexing backend.
- [x] Keep the overall `SwiftlyFetch` story coherent so one local corpus can eventually support both semantic retrieval and conventional search.

### Tickets

- [x] Add maintainer-facing `FetchKit` architecture guidance that explains the Core Data plus SearchKit model and its relationship to `RAGKit`.
- [x] Define the first `FetchCore` model and protocol candidates for document records, queries, search results, snippets, and index synchronization.
- [x] Add the first explicit `FetchCore` indexing changeset boundary so later `FetchKit` work can sync Core Data updates into a full-text index without ad hoc write paths.
- [x] Define the first durable `FetchDocumentRecord` shape so Core Data-backed corpus storage can stay distinct from derived full-text indexing views.
- [x] Promote the first typed lifecycle and source fields on `FetchDocumentRecord` while keeping freeform metadata string-based.
- [x] Split the derived search document view from the richer index-facing payload so typed record fields can cross the store-to-index boundary cleanly.
- [x] Decide the first Core Data document model shape and the sync boundary between stored records and the SearchKit index.
- [x] Draft the first `FetchKitLibrary` facade with typed add, update, remove, document, and search entry points over the `FetchCore` store/index protocols.
- [x] Add a first `FetchKitLibrary` configuration/default-construction story so top-level callers do not need to live on raw store/index injection forever.
- [x] Review the `FetchKitLibrary` method naming and result shapes for a tighter Cocoa-style API, including the document lookup surface and whether write operations should return typed summaries.
- [x] Decide the first public-facing `SwiftlyFetch` product wording for the family once `FetchKit` work begins landing in code.
- [x] Decide what iOS-first-class support means at the family level while the first concrete full-text backend remains macOS-first.
- [x] Add the first Core Data-backed `FetchDocumentStore` implementation in `FetchKit`, keeping the current in-memory index as the search companion for now.
- [x] Add the first explicit store-write to indexing-changeset seam so future index backends can consume real store mutations instead of facade-reconstructed writes.
- [x] Add a persisted pending index-sync queue so failed index applies can be retried after the original write call returns or the process restarts.
- [x] Add the first thin Search Kit-backed `FetchIndex` implementation on macOS, with direct Search Kit tests kept opt-in on a dedicated local macOS lane.
- [x] Add a small repo-maintenance helper so the focused Search Kit lane is one obvious command instead of a hand-written `xcodebuild` invocation.
- [x] Tighten the persistent `FetchKitLibrary` construction surface so store and index locations feel polished and Cocoa-style for real app callers.
- [x] Audit the first Core Data-backed store path on GitHub-hosted macOS, record the Swift Testing executor-assumption failure, move the Core Data verification lane to XCTest, and align the store implementation with a private-queue Core Data context plus async `perform`.

### Exit Criteria

- [x] The repo has a clear maintainer plan for `FetchCore` and `FetchKit` before backend code starts landing.
- [x] The package-family story explains how `RAGKit`, `FetchKit`, and `SwiftlyFetch` relate without overlapping ownership.
- [x] The first `FetchKit` implementation pass has a concrete storage-and-indexing model instead of a vague "traditional search later" placeholder.

## Milestone 4: FetchKit Refinement

### Status

In Progress

### Scope

- [x] Refine conventional-search ranking and snippet behavior now that the first SearchKit backend works end to end.
- [ ] Validate whether the current refinement pass is enough for ordinary app callers or whether another real-corpus quality pass is needed.
- [ ] Keep the public `FetchKitLibrary` surface polished as the conventional-search side moves from foundation into quality work.

### Tickets

- [x] Refine ranking behavior for conventional search so the first SearchKit backend feels less like a raw index adapter and more like a library product.
- [x] Improve snippet behavior and result presentation without bloating `FetchCore` into a larger query or rendering DSL.
- [ ] Audit real-corpus result quality now that field-aware ranking, phrase weighting, truncation cues, and multi-term snippets are in place.
- [ ] Decide whether title-only hits should suppress body snippets or use a different presentation policy in the public facade.
- [ ] Keep the persistent `FetchKitLibrary` construction and search API surface under review as real callers exercise the current design.

### Exit Criteria

- [x] Conventional-search results feel intentionally ranked and include useful snippet behavior for ordinary app callers.
- [x] The SearchKit-backed path runs in normal local validation and the default GitHub CI lane.
- [ ] `FetchKitLibrary` still reads like a small Swift-native facade instead of exposing backend detail drift.

## Milestone 5: FetchKit Platform And CI Decisions

### Status

Planned

### Scope

- [ ] Decide the long-term verification story for the Apple-asset Natural Language lane.
- [ ] Decide what first-class iOS support means for conventional search beyond the current portable `FetchCore` surface.
- [ ] Keep the product-family docs honest about what is already shippable versus what is still macOS-first or local-only.

### Tickets

- [ ] Revisit whether Natural Language asset-backed verification should stay local-only, move to self-hosted CI, or remain intentionally opt-in.
- [ ] Explore the first real iOS conventional-search backend direction, with Core Spotlight as the most likely Apple-native candidate.
- [ ] Decide whether future platform/backend work belongs in `FetchKit` directly or should earn a clearer backend seam only once the next real implementation lands.

### Exit Criteria

- [ ] The repo has a stable, explicitly chosen verification story for its remaining framework-heavy optional lane.
- [ ] The family docs describe macOS-first and iOS-first-class support without implying a backend that does not exist yet.
- [ ] The next backend or CI experiment has been narrowed to one concrete path instead of an open-ended backlog note.

## Backlog Candidates

- [ ] If parser-backed markdown chunking still leaves retrieval-quality gaps, add retrieval-specific chunking heuristics on top of the chosen markdown parser instead of rebuilding markdown parsing rules locally.
- [ ] If asset-backed automation becomes important again, evaluate a self-hosted macOS runner with prewarmed assets before retrying a hosted GitHub Actions lane.
- [ ] Consider a follow-on conventional-search quality pass only if real corpora show ranking, snippet, or result-presentation gaps beyond the current field-aware heuristics.

## History

- Initial roadmap scaffold created.
- Recorded the bootstrap foundation work for the first package setup pass.
- Published the initial public GitHub repository and pushed the bootstrap commit.
- Refactored the package into `RAGCore` and `RAGKit` and added the first retrieval implementations plus deterministic tests.
- Synchronized `AGENTS.md` into the broader canonical maintainer shape while preserving the Swift package workflow section.
- Added the heading-aware markdown chunker, default markdown-aware chunking, and an opt-in Natural Language integration test target.
- Marked the README product wording work complete.
- Strengthened the Apple-backed integration assertions, aligned CI with the supported Swift toolchain, and tightened retrieval defaults through richer metadata filters plus smarter grouped context assembly.
- Marked the retrieval-defaults milestone complete, opened the post-`v0.1.0` refinement milestone, and prepared the first public release.
- Switched markdown chunking onto a parser-backed implementation, added broader markdown-structure tests, preserved list semantics in chunk text and metadata, and added quote-heavy promotion for block quotes.
- Added header-aware table-row chunking and moved the next markdown policy focus to links and references.
- Settled the default link/reference policy so anchor text stays primary, raw destinations stay secondary, and reference definitions do not become standalone retrieval chunks.
- Added opt-in chunk-scoped link-destination metadata while keeping raw destinations out of default chunk text.
- Added document-level code-language metadata, code-block promotion for code-heavy documents, and thematic-break section lead-ins.
- Added image-reference metadata, alt-text-first markdown image handling, and a narrow raw-HTML whitelist for `img` plus `details` / `summary`.
- Tightened markdown fallback so policy-rejected markdown does not re-enter retrieval through the plain paragraph chunker.
- Documented the `RAGKit` / `FetchKit` / `SwiftlyFetch` family split as the intended longer-term package direction.
- Added a dedicated `FetchKit` product-plan pass and opened the docs-first foundation milestone for the conventional-search side of the family.
- Added the first `FetchCore` target with portable document-search models, queries, results, snippets, and store/index protocols.
- Added an explicit `FetchCore` indexing changeset model so future `FetchKit` backends can apply corpus updates through one sync boundary.
- Added the first durable `FetchDocumentRecord` model so stored corpus state and derived indexable documents are separate in `FetchCore`.
- Promoted `kind`, `language`, `createdAt`, and `updatedAt` onto `FetchDocumentRecord` as first-class typed fields.
- Split `FetchDocument`, `FetchIndexDocument`, and `FetchDocumentRecord` into clearer search, index, and durable-record roles.
- Defined the first `FetchKit` Core Data entity shape and one-way Core Data to Search Kit sync model in maintainer docs.
- Added the first `FetchKitLibrary` facade so conventional search now has a small typed public API surface in code.
- Added the first `FetchKitLibrary` configuration and API-polish pass with a default in-memory backend, singular conveniences, and typed batch results.
- Settled the first public `SwiftlyFetch` family wording and clarified that iOS stays first-class through portable `FetchCore` plus a later backend, while the first full-text backend remains macOS-first.
- Added the first Core Data-backed `FetchDocumentStore` implementation and tests, while keeping the current in-memory index as the conventional-search companion backend.
- Added the first store-produced indexing-changeset seam and surfaced pending index updates when the apply step fails.
- Added a persisted pending index-sync queue plus retry APIs so failed index applies can be acknowledged later instead of being recoverable only from the immediate thrown error.
- Added the first thin macOS Search Kit index backend and moved the direct Search Kit suite onto XCTest-style opt-in gating.
- Fixed Search Kit index ownership during teardown so the Search Kit verification lane is green again under both `swift test` and `xcodebuild test`.
- Added a dedicated repo-maintenance helper for the focused Search Kit test lane and recorded persistent-surface polish plus ranking/snippet refinement as the next FetchKit work.
- Tightened the persistent `FetchKitLibrary` surface around one resolved storage location, with Application Support defaults plus a direct directory override for local callers.
- Recorded that the GitHub-hosted `macos-15` Natural Language verification attempt timed out, so Apple-asset coverage stays local-only for now.
- Audited the Core Data-backed `FetchKit` store after a GitHub-hosted Swift Testing crash, recorded the executor-assumption findings, moved Core Data verification onto XCTest, and switched the durable store over to a private-queue Core Data context with the framework's async `perform` path.
- Refined conventional-search result quality with modest field-aware ranking plus query-aware multi-term snippets across the in-memory and SearchKit-backed `FetchKit` paths.
- Polished conventional-search result presentation with stronger phrase weighting and visible snippet truncation cues, then shipped that refinement as `v0.1.2`.
- Promoted the SearchKit-backed test suite from a local opt-in lane into normal XCTest validation and the default GitHub CI path once the lane proved fast and stable enough.
- Opened the next roadmap phase around SearchKit/Natural Language verification strategy, iOS conventional-search backend direction, and another caller-driven `FetchKitLibrary` polish pass if real usage shows it is needed.
