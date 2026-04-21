# Project Roadmap

Use this roadmap to track milestone-level delivery through checklist sections.

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 0: Foundation](#milestone-0-foundation)
- [Backlog Candidates](#backlog-candidates)
- [History](#history)

## Vision

- Deliver a small, dependable Apple-platform Swift package with a clear public library surface and a maintainable repo workflow from the start.

## Product Principles

- Keep the package manifest explicit about supported platforms, products, and Swift language mode.
- Prefer simple, readable Swift and Swift Testing over extra scaffolding.
- Keep README, roadmap, and maintainer workflow guidance in sync with the actual repo state.

## Milestone Progress

- Milestone 0: Foundation - In Progress

## Milestone 0: Foundation

### Status

In Progress

### Scope

- [x] Establish the root Swift package scaffold for a library product.
- [x] Pin the initial deployment floors to macOS 15 and iOS 18.
- [x] Put baseline maintainer docs and repo-maintenance tooling in place.
- [ ] Define the first real package feature beyond the bootstrap client placeholder.

### Tickets

- [x] Initialize the package with Swift Testing enabled.
- [x] Add canonical `README.md` and `ROADMAP.md` structure.
- [x] Add repo guidance and validation scripts.
- [x] Create the public GitHub repository and push the initial bootstrap state.

### Exit Criteria

- [x] The package builds and tests successfully on the local Swift 6 toolchain.
- [x] The repository has maintainer-facing workflow guidance and canonical starter docs.
- [ ] The package exposes at least one real fetch-oriented API surface beyond bootstrap scaffolding.

## Backlog Candidates

- [ ] Replace the bootstrap client placeholder with the first concrete fetch API design.
- [ ] Decide on final package positioning and replace the README `TBD` overview text with user-authored project language.
- [ ] Add CI checks that prove the package stays green on the intended supported toolchain.

## History

- Initial roadmap scaffold created.
- Recorded the bootstrap foundation work for the first package setup pass.
- Published the initial public GitHub repository and pushed the bootstrap commit.
