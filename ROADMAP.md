# Project Roadmap

Use this roadmap to track milestone-level delivery through checklist sections.

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 0: Foundation](#milestone-0-foundation)
- [Milestone 1: Retrieval Defaults](#milestone-1-retrieval-defaults)
- [Milestone 2: Post-v0.1.0 Refinement](#milestone-2-post-v010-refinement)
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

- [ ] Replace or significantly strengthen the current markdown chunking implementation so it handles real markdown structure without widening ingestion scope beyond plain text and markdown.
- [ ] Record the sibling-family architecture clearly: `RAGKit` for semantic retrieval, `FetchKit` for traditional document and full-text search, and `SwiftlyFetch` as the umbrella product story.
- [ ] Decide whether Apple-asset integration coverage should stay local or move to an optional CI lane, without making fresh GitHub-hosted macOS runners a required gate.

### Tickets

- [x] Evaluate replacing the current line-based heading scanner with a real markdown parser, with [`swift-markdown`](https://github.com/swiftlang/swift-markdown) as the first candidate.
- [x] Add edge-case tests for heading-aware markdown chunking and paragraph splitting that cover the chosen parser-backed or scanner-backed design explicitly.
- [x] Add an internal markdown-structure seam so the current scanner and any future parser-backed implementation can target the same chunk-construction shape.
- [x] Preserve list semantics in both chunk text and chunk metadata so lead-in context, ordered-list ordinals, and heading path are available to retrieval and downstream consumers.
- [x] Keep block quotes secondary by default, but promote them when quote-heavy documents would otherwise hide a meaningful share of the retrieval surface.
- [ ] Record the package-family direction in maintainer docs so future `FetchCore` and `FetchKit` work does not leak conventional search responsibilities into `RAGKit`.
- [ ] Evaluate an optional asset-enabled verification path for `RUN_NL_INTEGRATION_TESTS=1`, while keeping required GitHub-hosted CI on the default non-asset path.

### Exit Criteria

- [ ] The markdown ingestion path is materially more correct and better covered, while still staying retrieval-first and Apple-first.
- [ ] Markdown chunk metadata and chunk text both carry enough local structure to support high-quality retrieval and downstream fetching or indexing work.
- [ ] The package family and responsibility split are documented clearly enough to guide follow-on API decisions.
- [ ] The team has a settled decision on whether asset-enabled integration coverage belongs in optional CI, self-hosted CI, or local-only verification, and why.

## Backlog Candidates

- [ ] If parser-backed markdown chunking still leaves retrieval-quality gaps, add retrieval-specific chunking heuristics on top of the chosen markdown parser instead of rebuilding markdown parsing rules locally.
- [ ] Add an optional separate CI lane for Apple-asset integration coverage once a reliable asset-enabled runner strategy exists, most likely on self-hosted macOS or another runner with preinstalled assets.

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
