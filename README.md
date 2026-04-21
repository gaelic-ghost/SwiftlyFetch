# SwiftlyFetch

A Swift Package Manager library scaffold targeting macOS 15+ and iOS 18+.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

This project is in early development.

### What This Project Is

TBD. Gale should replace this with a user-authored description of the package's concrete shipped surface and audience.

### Motivation

TBD. Gale should replace this with a user-authored explanation of why this package exists and what it should make easier.

## Quick Start

This repository is still at the bootstrap stage, so there is not a meaningful end-user quick start yet. If you want to work on the package now, use the setup and validation commands in [Development](#development).

## Usage

The current public surface is intentionally minimal while the package takes shape:

```swift
import SwiftlyFetch

let client = SwiftlyFetchClient()
_ = client
```

## Development

### Setup

1. Install a Swift 6.3-era toolchain or newer.
2. Clone the repository.
3. Run `swift build` once to resolve the package and confirm the local toolchain matches the manifest.

### Workflow

Use `Package.swift` as the source of truth for package structure, targets, and dependencies. The repo-maintenance toolkit lives under `scripts/repo-maintenance/`, and ordinary package work should stay on the default SwiftPM path unless Xcode-managed behavior is explicitly needed.

### Validation

Use the standard package checks for day-to-day work:

```sh
swift build
swift test
scripts/repo-maintenance/validate-all.sh
```

## Repo Structure

```text
.
├── Package.swift
├── Sources/
│   └── SwiftlyFetch/
├── Tests/
│   └── SwiftlyFetchTests/
├── scripts/
│   └── repo-maintenance/
└── .github/
    └── workflows/
```

## Release Notes

Tagged releases should be created with `scripts/repo-maintenance/release.sh`, and each published tag should get matching GitHub release notes that summarize what changed and how it was verified.

## License

See [LICENSE](./LICENSE) for the current repository licensing status.
