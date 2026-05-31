# Hugging Face Corpus Audit Findings

## 2026-05-31 Larger Bounded Slice

### Command

```bash
HF_CORPUS_AUDIT_TINYSTORIES_LENGTH=100 \
HF_CORPUS_AUDIT_SIMPLEWIKI_LENGTH=100 \
HF_CORPUS_AUDIT_POETRY_LENGTH=100 \
scripts/repo-maintenance/run-huggingface-corpus-audit.sh
```

### Corpus

The live audit lane downloaded the largest currently supported bounded Dataset Viewer slices from the three configured Hugging Face corpus families:

- `roneneldan/TinyStories`, `default`, `train`, offset `0`, length `100`
- `juno-labs/simple_wikipedia`, `default`, `train`, offset `0`, length `100`
- `biglam/gutenberg-poetry-corpus`, `default`, `train`, offset `0`, length `100`

The audit indexed `209` temporary `FetchDocumentRecord` values. The final document count is lower than the requested row count because the importer intentionally skips rows that cannot produce a usable title/body search record from the available dataset fields.

### Result

All five larger-slice quality checks passed:

```text
[pass] TinyStories sewing retrieval: hf-tinystories hf-tinystories-0 score=0.903 field=body snippet="...we can share the needle and fix your shirt."  Together, they shared the needle and sewed the button on Lily's shirt. It"
[pass] TinyStories toy retrieval: hf-tinystories hf-tinystories-6 score=0.881 field=body snippet="...always sad because she lost her favorite toy, a triangle. She looked everywhere in her house but could not find it.  On"
[pass] Simple Wikipedia calendar retrieval: hf-simplewiki hf-simplewiki-0 score=0.882 field=body snippet="...and in years immediately before leap years, [June](401) of the following year. In years immediately before common years"
[pass] Simple Wikipedia rhetoric retrieval: hf-simplewiki hf-simplewiki-18 score=0.885 field=body snippet="...Translated to English, _ad hominem_ means _against the person_. In other words, when someone makes an ad hominem, they "
[pass] Gutenberg poetry northland retrieval: hf-poetry hf-poetry-19-lines-36-47 score=0.942 field=body snippet="...the forests and the prairies, From the great lakes of the Northland, From the land of the Ojibways, From the land of th"
```

### Decision

The current `FetchKitLibrary` ranking and snippet behavior is good enough for the v1 conventional-search refinement milestone against this bounded live corpus. No ranking change, snippet redesign, or extended-snippet API has earned implementation from this audit alone.

Keep the live Hugging Face lane as an opt-in maintainer audit. Do not move it into default `swift test` or default GitHub CI while it depends on live network access, Hugging Face Dataset Viewer availability, and dataset field stability.

### Limits

This is a quality smoke audit, not a full relevance benchmark. It covers the first 100 rows requested from each configured dataset, the current five hand-authored probes, and the current importer field mapping. It does not stand in for a real app's private corpus, localized content, attachment-heavy records, or user-specific query logs.

The better next signal is a caller-owned corpus once a real app starts exercising the `FetchKitLibrary` facade. Until then, keep public API polish and construction/search ergonomics under review without adding a larger ranking or snippet surface speculatively.
