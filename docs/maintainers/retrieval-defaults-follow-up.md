# Retrieval Defaults Follow-Up

Use this note to guide the next retrieval-quality pass after the current Natural Language verification and baseline CI work lands.

## Purpose

The next package-improvement step after Apple-backed integration verification should be a narrow retrieval-defaults pass. The job is to make the package more useful for ordinary app-side retrieval without widening it into a larger query language, answer-generation layer, or orchestration surface.

This is a durable scope note for v1 planning, not a mandate to build every idea listed here in one change.

## What This Work Is Actually For

In practical terms, this pass is about two things:

- making metadata filters expressive enough for common app-side retrieval narrowing
- making assembled context more predictable and useful as a downstream input to UI or model calls outside this package

The point is not to make `KnowledgeBase` smarter in a chat or agent sense. The point is to make its retrieval output easier to trust and easier to consume.

## Current State

The package already has a good small baseline:

- `MetadataFilter` supports key presence, typed equality, string containment, and `any` / `all` composition
- `KnowledgeBase.makeContext(...)` assembles top results into plain or annotated text within a character budget
- the current behavior is deterministic and easy to reason about

That is enough for the first useful retrieval loop, but it still leaves a few likely v1 pain points unresolved.

## Desired Outcome

The desired outcome for this pass is:

- ordinary app code can narrow searches by simple metadata facts without inventing its own wrapper layer
- context assembly produces predictable, compact output that preserves retrieval value without pretending to synthesize an answer
- the public API still feels small and obvious

## Metadata Filtering Scope

### Keep

Keep the current filter model centered on small typed predicates and explicit composition.

That means preserving:

- `hasKey`
- typed `equals`
- string `contains`
- boolean composition through `any` and `all`

### Likely Additions Worth Considering

The next pass may justify one or two additions if they clearly remove real app-side boilerplate:

- `not(...)` for simple exclusions without forcing callers to restructure every filter tree
- lightweight numeric or date comparison operators only if a real retrieval use case already needs recency or score-window style narrowing

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

The next pass should focus on practical output quality improvements such as:

- clearer section separation rules when multiple chunks from the same document are included
- lightweight duplicate suppression when adjacent results are effectively repeating the same text
- stable document or chunk labeling that helps downstream consumers keep citations straight
- budget behavior that remains deterministic when annotated headers consume meaningful space

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

- add a small `not` filter case plus tests
- improve annotated-context formatting so repeated document identity is easier to scan
- make plain-context assembly slightly smarter about repeated adjacent chunks from the same document
- tighten budget handling tests around truncation and separators

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
- the public surface stays retrieval-first and easy to explain
- tests cover the new behavior deterministically
- no generation, chat, or orchestration concepts leak into the package surface
