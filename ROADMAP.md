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
- Milestone 2: Post-v0.1.0 Refinement - Planned
- Milestone 3: FetchKit Foundation - Planned

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

Planned

### Scope

- [ ] Finish the remaining markdown-policy refinement work now that the package has a parser-backed chunking implementation.
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

- [ ] The markdown ingestion path is materially more correct and better covered, while still staying retrieval-first and Apple-first.
- [ ] Markdown chunk metadata and chunk text both carry enough local structure to support high-quality retrieval and downstream fetching or indexing work.
- [x] The package family and responsibility split are documented clearly enough to guide follow-on API decisions.
- [x] The team has a settled decision on whether asset-enabled integration coverage belongs in optional CI, self-hosted CI, or local-only verification, and why.

## Milestone 3: FetchKit Foundation

### Status

Planned

### Scope

- [ ] Define the product boundary and maintainer plan for `FetchCore` and `FetchKit`.
- [ ] Establish `FetchCore` as the portable vocabulary for conventional document search.
- [ ] Design a macOS-first `FetchKit` architecture with Core Data as the durable corpus store and SearchKit as the full-text indexing backend.
- [ ] Keep the overall `SwiftlyFetch` story coherent so one local corpus can eventually support both semantic retrieval and conventional search.

### Tickets

- [ ] Add maintainer-facing `FetchKit` architecture guidance that explains the Core Data plus SearchKit model and its relationship to `RAGKit`.
- [x] Define the first `FetchCore` model and protocol candidates for document records, queries, search results, snippets, and index synchronization.
- [x] Add the first explicit `FetchCore` indexing changeset boundary so later `FetchKit` work can sync Core Data updates into a full-text index without ad hoc write paths.
- [x] Define the first durable `FetchDocumentRecord` shape so Core Data-backed corpus storage can stay distinct from derived full-text indexing views.
- [x] Promote the first typed lifecycle and source fields on `FetchDocumentRecord` while keeping freeform metadata string-based.
- [x] Split the derived search document view from the richer index-facing payload so typed record fields can cross the store-to-index boundary cleanly.
- [x] Decide the first Core Data document model shape and the sync boundary between stored records and the SearchKit index.
- [ ] Decide the first public-facing `SwiftlyFetch` product wording for the family once `FetchKit` work begins landing in code.
- [ ] Decide what iOS-first-class support means at the family level while the first concrete full-text backend remains macOS-first.

### Exit Criteria

- [ ] The repo has a clear maintainer plan for `FetchCore` and `FetchKit` before backend code starts landing.
- [ ] The package-family story explains how `RAGKit`, `FetchKit`, and `SwiftlyFetch` relate without overlapping ownership.
- [ ] The first `FetchKit` implementation pass has a concrete storage-and-indexing model instead of a vague "traditional search later" placeholder.

## Backlog Candidates

- [ ] If parser-backed markdown chunking still leaves retrieval-quality gaps, add retrieval-specific chunking heuristics on top of the chosen markdown parser instead of rebuilding markdown parsing rules locally.
- [ ] If asset-backed automation becomes important again, evaluate a self-hosted macOS runner with prewarmed assets before retrying a hosted GitHub Actions lane.
- [ ] When `FetchKit` moves from docs into code, decide whether the first backend should live behind a SearchKit-specific module seam immediately or only after the first macOS implementation proves the stable `FetchCore` shape.

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
- Recorded that the GitHub-hosted `macos-15` Natural Language verification attempt timed out, so Apple-asset coverage stays local-only for now.
