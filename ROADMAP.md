# Project Roadmap

Use this roadmap to track milestone-level delivery through checklist sections.

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 0: Foundation](#milestone-0-foundation)
- [Milestone 1: Retrieval Defaults](#milestone-1-retrieval-defaults)
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
- Milestone 1: Retrieval Defaults - In Progress

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

## Backlog Candidates

- [ ] Decide how the future `FetchCore` and `FetchKit` family should relate to the eventual umbrella `SwiftlyFetch` product without distorting the current retrieval-first package scope.
- [ ] Add an optional separate CI lane for Apple-asset integration coverage once a reliable asset-enabled runner strategy exists.

## History

- Initial roadmap scaffold created.
- Recorded the bootstrap foundation work for the first package setup pass.
- Published the initial public GitHub repository and pushed the bootstrap commit.
- Refactored the package into `RAGCore` and `RAGKit` and added the first retrieval implementations plus deterministic tests.
- Synchronized `AGENTS.md` into the broader canonical maintainer shape while preserving the Swift package workflow section.
- Added the heading-aware markdown chunker, default markdown-aware chunking, and an opt-in Natural Language integration test target.
- Marked the README product wording work complete.
- Strengthened the Apple-backed integration assertions, aligned CI with the supported Swift toolchain, and tightened retrieval defaults through richer metadata filters plus smarter grouped context assembly.
