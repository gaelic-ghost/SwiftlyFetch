# Fixture Corpus Notes

## Purpose

This note records the first checked-in fixture corpus used for `FetchKit` conventional-search quality tests.

The job of this fixture is deliberately narrow: give the default `FetchKitLibrary` tests enough title/body variety to characterize ranking and snippet behavior without making local or hosted CI download a dataset.

## Current Fixture Source

The first mini corpus is derived from the [`zkeown/gutenberg-corpus`](https://huggingface.co/datasets/zkeown/gutenberg-corpus) dataset on Hugging Face.

Why this source fits the first pass:

- the source material is Project Gutenberg text marked public domain in the USA
- the dataset card reports Apache-2.0 packaging metadata
- the `books` config has title, author, language, rights, and text fields
- the `chapters` config has chapter titles and chapter text, which is a useful shape for document-search quality tests
- the corpus can be inspected through the Hugging Face Dataset Viewer APIs without adding a Swift dependency

The fixture records live in `Tests/FetchKitTests/Fixtures/GutenbergMiniCorpus.swift`. Each record carries dataset, config, split, row, and Gutenberg ID metadata so the sample remains attributable and replaceable.

## Hugging Face Dependency Boundary

Do not add a Hugging Face Swift dependency for the default fixture lane yet. The current checked-in fixture keeps CI deterministic and avoids adding a network, token, cache, or package-resolution requirement to ordinary tests.

[`swift-transformers`](https://github.com/huggingface/swift-transformers) is worth tracking for future tokenization or model-adjacent work, but it is broader than this fixture-corpus job. Its README describes tokenizers, Hub downloads, model utilities, and Core ML helpers, which would move this package closer to model tooling than the current retrieval/search fixture need.

If future work needs live Hub dataset downloads from Swift, evaluate [`swift-huggingface`](https://github.com/huggingface/swift-huggingface) separately. Hugging Face describes it as the newer Swift Hub client for models, datasets, spaces, file downloads, cache behavior, and authentication. That would be a durable dependency decision, not a test-fixture detail.

## Dataset Viewer Commands

The fixture was inspected with read-only Dataset Viewer calls:

```bash
curl -s 'https://datasets-server.huggingface.co/splits?dataset=zkeown/gutenberg-corpus'
curl -s 'https://datasets-server.huggingface.co/rows?dataset=zkeown/gutenberg-corpus&config=books&split=train&offset=1&length=5'
curl -s 'https://datasets-server.huggingface.co/rows?dataset=zkeown/gutenberg-corpus&config=chapters&split=train&offset=1&length=3'
```

Hugging Face documents dataset parquet discovery through the Dataset Viewer service in the [`huggingface_hub` CLI guide](https://huggingface.co/docs/huggingface_hub/guides/cli) and the Dataset Viewer [Parquet conversion guide](https://huggingface.co/docs/dataset-viewer/parquet).

## Next Use

Use this fixture to settle the remaining Milestone 4 questions:

- whether the current ranking and snippet heuristics are enough for ordinary app callers
- whether title-only hits should keep using title snippets, suppress snippets, or grow a different presentation policy in the public facade
- whether the first fixture corpus should also cover the macOS SearchKit-backed path directly, or whether the existing SearchKit tests plus the default-library corpus tests are enough for now
