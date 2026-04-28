# Contributing to SwiftlyFetch

Use this guide when preparing changes so the package stays understandable, runnable, and reviewable for the next contributor.

## Table of Contents

- [Overview](#overview)
- [Contribution Workflow](#contribution-workflow)
- [Local Setup](#local-setup)
- [Development Expectations](#development-expectations)
- [Pull Request Expectations](#pull-request-expectations)
- [Communication](#communication)
- [License and Contribution Terms](#license-and-contribution-terms)

## Overview

### Who This Guide Is For

This guide is for people changing the Swift package itself: maintainers, contributors, and anyone editing `Package.swift`, source targets under `Sources/`, tests under `Tests/`, or the maintainer docs and repo-maintenance surfaces that ship with the repository.

### Before You Start

Read [AGENTS.md](./AGENTS.md), [ROADMAP.md](./ROADMAP.md), and the relevant maintainer notes under [docs/maintainers/](./docs/maintainers/) before changing architecture, workflow, or product-facing wording. `Package.swift` is the source of truth for package structure, and this repo expects Apple-docs-first reasoning for Swift, SwiftPM, Core Data, SearchKit, and other Apple framework decisions.

## Contribution Workflow

### Choosing Work

Keep work bounded to one coherent concern at a time. Good units here are things like retrieval-policy refinement, `FetchKit` backend work, maintainer-doc alignment, repo-maintenance updates, or release follow-up fixes. If a change starts widening the package toward chat, generation, remote providers, or unrelated app behavior, stop and realign scope before editing.

### Making Changes

Work from a feature branch instead of `main`. Keep code, docs, roadmap state, and maintainer guidance in sync when the implementation meaningfully changes. For Swift package work, prefer the normal SwiftPM path first and treat Xcode-managed behavior as an explicit exception rather than the default workflow.

### Asking For Review

Ask for review once the package builds, tests, and the nearby docs tell the same story as the code. Call out any intentionally deferred follow-up work plainly, especially when a change settles policy or architecture without finishing every later refinement.

## Local Setup

### Runtime Config

This repository does not require secrets or `.env` files for ordinary package development. The important local configuration surfaces are the installed repo-maintenance profile at `scripts/repo-maintenance/config/profile.env`, the managed formatter and lint config in `.swiftformat` and `.swiftlint.yml`, and any opt-in environment flags used by specific test lanes:

```bash
RUN_NL_INTEGRATION_TESTS=1
RUN_SEARCHKIT_TESTS=1
TEST_RUNNER_RUN_SEARCHKIT_TESTS=1
```

### Runtime Behavior

Most work is ordinary SwiftPM package work, so the main signal that the repo is healthy is that the local package and maintainer validation paths run cleanly:

```bash
swift build
swift test
scripts/repo-maintenance/validate-all.sh
```

For the local SearchKit-only verification lane on macOS, use:

```bash
scripts/repo-maintenance/run-searchkit-tests.sh
```

If you are touching the opt-in Natural Language asset path, use:

```bash
RUN_NL_INTEGRATION_TESTS=1 swift test --filter NaturalLanguageEmbedderIntegrationTests
```

## Development Expectations

### Naming Conventions

Match the current family vocabulary exactly. `SwiftlyFetch` is the umbrella story, `RAGCore` and `RAGKit` own semantic retrieval, and `FetchCore` plus `FetchKit` own conventional search. Prefer typed Swift surfaces, direct names, and Apple-style API wording over stringly or overly abstract helper layers.

### Accessibility Expectations

This repository is a package-first codebase and does not currently ship a dedicated `ACCESSIBILITY.md`. Even so, contributors should still treat accessibility and clarity as normal quality requirements for any user-facing surface they touch, including docs, API naming, diagnostics, sample code, and any future UI-facing examples or app integrations. If the repo grows a real UI surface or needs a durable accessibility contract, add that documentation in the same pass instead of leaving the expectation implicit.

### Verification

Use the repo-owned validation paths, and keep the checks you ran grounded in the changed surface:

```bash
swift build
swift test
scripts/repo-maintenance/validate-all.sh
scripts/repo-maintenance/run-searchkit-tests.sh
```

Not every change needs every optional lane, but package, maintainer, and release-affecting work should leave the default validation path green before review.

## Pull Request Expectations

Summarize what changed, why it changed, and what reviewers should look at first. If a PR settles a policy or workflow question, mention the corresponding `AGENTS.md`, roadmap, or maintainer-doc update in the same description so reviewers can see the repo contract stayed aligned.

## Communication

Raise uncertainty early when scope starts drifting, especially around package boundaries, Core Data or SearchKit backend behavior, CI policy, or release workflow changes. Short, concrete notes about what changed, what was verified, and what still needs a decision are more useful here than broad status summaries.

## License and Contribution Terms

Contributions to this repository are covered by the project license in [LICENSE](./LICENSE). There are no extra sign-off or CLA steps documented for this package at the moment.
