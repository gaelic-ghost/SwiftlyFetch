# AGENTS.md

Use this file for durable repo-local guidance that Codex should follow before changing code, docs, or project workflow surfaces in this repository.

## Repository Scope

### What This File Covers

This root `AGENTS.md` governs the whole `SwiftlyFetch` Swift package repository. It covers the retrieval package code in `Sources/`, the tests in `Tests/`, maintainer planning docs in `docs/maintainers/`, and the repo-maintenance scripts and workflow surfaces that keep the package healthy.

### Where To Look First

Check these surfaces before reading broadly:

- `Package.swift` for the source-of-truth package layout, products, targets, platforms, and language mode.
- `docs/maintainers/retrieval-package-plan.md` for the intended product identity, architecture, and implementation sequence.
- `ROADMAP.md` for the currently committed milestone shape and what is still intentionally unfinished.
- `Sources/RAGCore/` and `Sources/RAGKit/` for the current code surface.

## Working Rules

### Change Scope

Keep work retrieval-first and Apple-first. If a change starts pulling the repo toward answer generation, chat orchestration, agents, remote APIs, persistence layers, or connector-heavy ingestion, stop and surface that scope change explicitly before implementing it.

### Source of Truth

Treat `Package.swift` as the package structure source of truth. Treat `docs/maintainers/retrieval-package-plan.md` and `ROADMAP.md` as the maintainer-facing architecture and planning sources of truth. When code and docs drift, reconcile them instead of silently following the newer-looking one.

### Communication and Escalation

Escalate before widening the public API surface, changing package naming, adding new module families, or introducing a new storage or backend layer that changes the repository’s near-term direction. If a task implies architectural drift, say what concrete behavior is forcing that change before proceeding.

## Commands

### Setup

```bash
swift build
```

### Validation

```bash
swift test
scripts/repo-maintenance/validate-all.sh
```

### Optional Project Commands

```bash
scripts/repo-maintenance/release.sh --help
```

## Review and Delivery

### Review Expectations

Ground changes in the actual retrieval package plan and current code. When handing work back, call out behavior changes, verification run, and any roadmap or maintainer-doc updates that were required to keep the repo coherent. If a change leaves intentionally unfinished follow-up work, say exactly what is left and why it was not pulled into the same pass.

### Definition of Done

Work is done when the package still builds and tests cleanly, repo-maintenance validation passes, and nearby maintainer docs stay aligned with the code when the implementation meaningfully changes. For architecture-facing work, update `docs/maintainers/` or `ROADMAP.md` when the repo’s intended direction or current milestone state changes.

## Safety Boundaries

### Never Do

- Never widen this package into generation, chat orchestration, agents, PDF ingestion, persistence layers, or remote provider APIs without explicit approval.
- Never make the main test suite depend on downloaded Apple embedding assets.
- Never add external dependencies for this v1 retrieval package without explicit approval.
- Never hand-edit generated package-manager outputs such as `Package.resolved` if they appear later.

### Ask Before

- Ask before changing product naming in a way that affects the future `SwiftlyFetch` umbrella direction.
- Ask before adding a new module family beyond the current retrieval-focused `RAGCore` and `RAGKit` split.
- Ask before changing the metadata-filter surface in a way that turns it into a larger query language.

## Local Overrides

There are no deeper `AGENTS.md` files in the current repository tree. If more specific guidance files are added later under subdirectories, they should refine this root file for work happening in that subtree.

## Swift Package Workflow

- Use `swift build` and `swift test` as the default first-pass validation commands for this package.
- Use `bootstrap-swift-package` when a new Swift package repo still needs to be created from scratch.
- Use `sync-swift-package-guidance` when the repo guidance for this package drifts and needs to be refreshed or merged forward.
- Re-run `sync-swift-package-guidance` after substantial package-workflow or plugin updates so local guidance stays aligned.
- Use `swift-package-build-run-workflow` for manifest, dependency, plugin, resource, Metal-distribution, build, and run work when `Package.swift` is the source of truth.
- Use `swift-package-testing-workflow` for Swift Testing, XCTest holdouts, `.xctestplan`, fixtures, and package test diagnosis.
- Use `scripts/repo-maintenance/validate-all.sh` for local maintainer validation, `scripts/repo-maintenance/sync-shared.sh` for repo-local sync steps, and `scripts/repo-maintenance/release.sh` for releases.
- Treat `scripts/repo-maintenance/config/profile.env` as the installed `maintain-project-repo` profile marker, and keep it on the `swift-package` profile for plain package repos.
- Read relevant SwiftPM, Swift, and Apple documentation before proposing package-structure, dependency, manifest, concurrency, or architecture changes.
- Prefer Dash or local Swift docs first, then official Swift or Apple docs when local docs are insufficient.
- Prefer the simplest correct Swift that is easiest to read and reason about.
- Prefer synthesized and framework-provided behavior over extra wrappers and boilerplate.
- Keep data flow straight and dependency direction unidirectional.
- Treat `Package.swift` as the source of truth for package structure, targets, products, and dependencies.
- Prefer `swift package` subcommands for structural package edits before manually editing `Package.swift`.
- Edit `Package.swift` intentionally and keep it readable; agents may modify it when package structure, targets, products, or dependencies need to change, and should try to keep package graph updates consolidated in one change when possible.
- Keep `Package.swift` explicit about its package-wide Swift language mode. On current Swift 6-era manifests, prefer `swiftLanguageModes: [.v6]` as the default declaration, treat `swiftLanguageVersions` as a legacy alias used only when an older manifest surface requires it, and remember that lowering the manifest's `// swift-tools-version:` from the bootstrap default is often appropriate when the package should support an older Swift 6 toolchain, but never below `6.0`.
- Avoid adding unnecessary dependency-provenance detail or switching to branch/revision-based requirements unless the user explicitly asks for that level of control.
- Treat `Package.resolved` and similar package-manager outputs as generated files; do not hand-edit them.
- Prefer Swift Testing by default unless an external constraint requires XCTest.
- Prefer a checked-in repo-root `.swiftformat` file as the Swift formatting source of truth.
- Prefer a pre-commit hook such as `scripts/repo-maintenance/hooks/pre-commit.sample` that formats staged Swift sources and then verifies them with `swiftformat --lint` before commit.
- Treat SwiftLint as an optional complementary signal layer for clarity, safety, and maintainability after SwiftFormat owns formatting shape.
- Use `apple-ui-accessibility-workflow` when the package work crosses into SwiftUI accessibility semantics, Apple UI accessibility review, or UIKit/AppKit accessibility bridge behavior.
- Keep package resources under the owning target tree, declare them intentionally with `Resource.process(...)`, `Resource.copy(...)`, `Resource.embedInCode(...)`, and load them through `Bundle.module`.
- Keep test fixtures as test-target resources instead of relying on the working directory.
- Bundle precompiled Metal artifacts such as `.metallib` files as explicit resources when they ship with the package, and prefer `xcode-build-run-workflow` when shader compilation or Apple-managed Metal toolchain behavior matters.
- Validate both Debug and Release paths when optimization or packaging differences matter, and treat tagged releases as a cue to verify the Release artifact path before publishing.
- Prefer `xcode-build-run-workflow` or `xcode-testing-workflow` only when package work needs Xcode-managed SDK, toolchain, or test behavior.
- Keep runtime UI accessibility verification and XCUITest follow-through in `xcode-testing-workflow` rather than treating package-side testing as a substitute for live UI verification.
