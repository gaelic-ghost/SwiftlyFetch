# Retrieval Defaults Follow-Up

Use this note to guide any future retrieval-quality pass after the first broad retrieval-defaults and markdown-policy work has landed.

## Purpose

This package has already completed its first broad retrieval-defaults refinement pass. The current default surface now includes:

- `MetadataFilter.not(...)` for ordinary exclusions
- ordered comparisons for `int`, `double`, and `date`
- case-insensitive `startsWith` and `endsWith` string matching
- grouped annotated context output with document-level labeling
- smarter same-document duplicate suppression
- annotated budget handling that avoids label-only sections

Any next package-improvement step in this area should remain narrow. The job is still to make the package more useful for ordinary app-side retrieval without widening it into a larger query language, answer-generation layer, or orchestration surface.

This is a durable scope note for v1 planning, not a mandate to build every idea listed here in one change.

## What This Work Is Actually For

In practical terms, this pass is about two things:

- making metadata filters expressive enough for common app-side retrieval narrowing
- making assembled context more predictable and useful as a downstream input to UI or model calls outside this package

The point is not to make `KnowledgeBase` smarter in a chat or agent sense. The point is to make its retrieval output easier to trust and easier to consume.

## Current State

The package already has a good small baseline:

- `MetadataFilter` supports key presence, typed equality, string containment, string prefix/suffix matching, ordered typed comparisons, and logical composition
- `KnowledgeBase.makeContext(...)` assembles top results into plain or annotated text with grouped document labeling, duplicate suppression, and deterministic budget handling
- the current behavior is deterministic and easy to reason about

That is enough for the first useful retrieval loop. What remains now is less about obvious missing structure and more about deciding whether real corpora expose retrieval-quality gaps worth another focused pass.

## Desired Outcome

The desired outcome for this pass is:

- ordinary app code can narrow searches by simple metadata facts without inventing its own wrapper layer
- context assembly produces predictable, compact output that preserves retrieval value without pretending to synthesize an answer
- markdown chunking stays parser-backed and retrieval-first instead of regressing into ad hoc local markdown parsing rules
- markdown chunk text and chunk metadata both preserve enough local structure to support high-quality retrieval plus downstream search, indexing, and fetching work
- the public API still feels small and obvious

## Markdown Chunking Scope

### Keep

Keep markdown work retrieval-first.

That means the package still owns:

- how markdown content turns into retrieval chunks
- how heading context or other structural hints should influence chunk text
- which local structure belongs in chunk metadata as well as chunk text
- how chunk boundaries should behave for retrieval quality

### Prefer

Keep the parser-backed markdown path built on [swift-markdown](https://github.com/swiftlang/swift-markdown) unless a concrete regression forces a rethink.

### Avoid

Avoid drifting back toward an ad hoc markdown parser.

That means avoiding piecemeal local parsing rules for increasingly many markdown cases such as:

- heading syntax edge cases
- fenced code blocks
- block quotes
- lists
- thematic breaks
- link-reference structure

If the package needs to understand more markdown structure, build on the parser-backed section model instead of reintroducing line-oriented special cases.

### Next Markdown Priorities

The next markdown-policy questions should be driven by real caller pressure, not by a desire to enumerate every markdown block kind. The most likely remaining work is deciding whether any additional raw-HTML or image-adjacent structure is genuinely useful for downstream indexing or fetch-oriented consumers beyond the current whitelist and metadata behavior.

## Metadata Filtering Scope

### Keep

Keep the current filter model centered on small typed predicates and explicit composition.

That means preserving:

- `hasKey`
- typed `equals`
- string `contains`
- boolean composition through `any` and `all`

### Likely Additions Worth Considering

Any next pass may justify one or two additions if they clearly remove real app-side boilerplate:

- additional typed predicates only if a real retrieval use case needs them beyond the current comparison set
- small convenience APIs layered on top of the existing filter cases, if they truly reduce caller repetition without introducing a larger query language

### Avoid

Avoid turning `MetadataFilter` into a general query language.

Do not add:

- parser-driven filter syntax
- arbitrary expression strings
- regex-heavy matching surfaces
- nested field addressing conventions
- backend-specific query translation concepts

If a proposed filter feature starts sounding like "search DSL", that is already outside the intended v1 line.

## Context Assembly Scope

### Keep

`makeContext(...)` should remain a deterministic retrieval packaging helper.

Its job is still:

- take ranked results
- render chunk text in a predictable style
- respect an explicit budget
- return retrieval context for some downstream consumer

### Likely Improvements Worth Considering

Any next pass should focus on practical output quality improvements such as:

- small rendering polish for downstream readability if a concrete caller needs it
- limited duplicate heuristics only if repeated real-world retrieval traces still show noisy context after the current same-document suppression

### Avoid

Do not let context assembly drift into answer generation.

That means no:

- summarization
- paraphrasing
- synthesis across chunks
- prompt templates
- citations-as-a-chat-feature
- model-facing instruction strings

This package should assemble retrieved evidence, not invent a response.

## Good Candidate Changes

Examples of changes that fit this note well:

- improve annotated-context formatting so repeated document identity is easier to scan
- make plain-context assembly slightly smarter about repeated adjacent chunks from the same document
- tighten budget handling tests around truncation and separators
- refine promotion heuristics or expand chunk metadata when a concrete retrieval or indexing need emerges from real documents
- add one more narrow markdown policy decision only if a real corpus shows the current parser-backed behavior is leaving retrieval value on the floor

## Changes That Should Trigger Escalation

Stop and escalate before implementing any of the following:

- a broader query language for metadata
- persistence-oriented filtering or index-specific query semantics
- context assembly that rewrites, summarizes, or ranks chunks using generation-style logic
- public APIs that introduce agents, prompts, chat sessions, or provider-specific retrieval orchestration

Those are all real scope changes, not harmless retrieval-default tweaks.

## Suggested Execution Order

When this pass starts for real, the order should be:

1. identify the smallest missing retrieval behavior causing real caller friction
2. add or adjust the narrowest core type or API needed to solve that problem
3. add deterministic tests first
4. update README and roadmap only if the public meaning changes

## Definition Of Done

This follow-up is done when:

- the package gains one small meaningful retrieval-quality improvement in metadata filtering, context assembly, or both
- the markdown ingestion path remains parser-backed and retrieval-first
- the public surface stays retrieval-first and easy to explain
- tests cover the new behavior deterministically
- no generation, chat, or orchestration concepts leak into the package surface
