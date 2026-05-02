# Fixture Corpus Notes

## Purpose

This note records the first checked-in fixture corpus used for `FetchKit` conventional-search quality tests.

The job of this fixture is deliberately narrow: give the default `FetchKitLibrary` and macOS SearchKit tests enough title/body variety to characterize ranking, snippet, and result-evidence behavior without making local or hosted CI download a dataset.

## Current Fixture Source

The first mini corpus is derived from the [`zkeown/gutenberg-corpus`](https://huggingface.co/datasets/zkeown/gutenberg-corpus) dataset on Hugging Face.

Why this source fits the first pass:

- the source material is Project Gutenberg text marked public domain in the USA
- the dataset card reports Apache-2.0 packaging metadata
- the `books` config has title, author, language, rights, and text fields
- the `chapters` config has chapter titles and chapter text, which is a useful shape for document-search quality tests
- the corpus can be inspected through the Hugging Face Dataset Viewer APIs without adding a Swift dependency

The fixture records live in `Tests/FetchKitTests/Fixtures/GutenbergMiniCorpus.swift`. Each record carries dataset, config, split, row, and Gutenberg ID metadata so the sample remains attributable and replaceable.

## Result Evidence Policy

The first fixture pass settled the title-only snippet policy for the current public surface:

- keep title snippets for title-only hits
- report all contributing fields through `FetchSearchResult.matchedFields`
- report the field used for the returned snippet through `FetchSearchResult.snippetField`
- cover the same title/body expectations in both the default in-memory index path and the macOS SearchKit-backed path

In practical terms, simple result lists can keep rendering a snippet for every explained hit, while richer consumers can avoid treating a title snippet as body evidence.

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

Use this fixture to keep the settled Milestone 4 result-evidence behavior honest while broader quality work continues:

- whether the current ranking and snippet heuristics are enough for ordinary app callers
- whether a larger fixture corpus exposes ranking or snippet gaps that the mini corpus cannot show
- whether future extended snippets should be backed by precomputed summaries for larger documents rather than by foreground search-time work
