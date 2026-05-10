#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
  printf '%s\n' "usage: version-bump.sh <version>" >&2
  exit 1
fi

version="$1"
tag="v$version"

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
readme_path="$repo_root/README.md"
release_notes_dir="$repo_root/docs/releases"
release_notes_path="$release_notes_dir/$tag.md"

tmp_readme="$(mktemp "${TMPDIR:-/tmp}/swiftlyfetch-readme.XXXXXX")"
trap 'rm -f "$tmp_readme"' EXIT INT TERM

python3 - "$readme_path" "$tmp_readme" "$tag" <<'PY'
from pathlib import Path
import re
import sys

readme_path = Path(sys.argv[1])
tmp_path = Path(sys.argv[2])
tag = sys.argv[3]
version = tag.removeprefix("v")
text = readme_path.read_text()
status_pattern = re.compile(r"(?:`v\d+\.\d+\.\d+` is .*|SwiftlyFetch has tagged releases stable enough to try locally, and the umbrella `SwiftlyFetch` surface is available in the current codebase\. See GitHub Releases for the latest published version details\.)")
status_replacement = "SwiftlyFetch has tagged releases stable enough to try locally, and the umbrella `SwiftlyFetch` surface is available in the current codebase. See GitHub Releases for the latest published version details."
updated, status_count = status_pattern.subn(status_replacement, text, count=1)
if status_count != 1:
    raise SystemExit("Could not find the README status line to update.")
dependency_pattern = re.compile(r'from: "[^"]+"')
updated, dependency_count = dependency_pattern.subn(f'from: "{version}"', updated, count=1)
if dependency_count != 1:
    raise SystemExit("Could not find the README package dependency version to update.")
tmp_path.write_text(updated)
PY

mv "$tmp_readme" "$readme_path"

mkdir -p "$release_notes_dir"

cat >"$release_notes_path" <<EOF
# SwiftlyFetch $tag

## What Changed

- added the first \`SwiftlyFetch\` umbrella facade for one-corpus ingestion across conventional search and semantic retrieval
- persisted semantic vector index state and document-level semantic health through Core Data-backed \`RAGKit\` storage
- added semantic retry storage, retry cooldown handling, persistent facade construction, and side-by-side \`searchAndRetrieve(...)\`
- expanded corpus-based coverage with a TinyStories-derived fixture source alongside the existing Gutenberg-derived fixture records
- hardened release resume behavior and refreshed the quick-start documentation with package dependency guidance and promo media

## Breaking Changes

- None. This is a backward-compatible minor release on top of \`v0.1.2\`.

## Migration Or Upgrade Notes

- Existing \`RAGCore\`, \`RAGKit\`, \`FetchCore\`, and \`FetchKit\` callers can keep using those products directly.
- New callers that want coordinated corpus writes can import \`SwiftlyFetch\` and use \`SwiftlyFetchLibrary\`.
- \`SwiftlyFetchLibrary.searchAndRetrieve(...)\` returns conventional and semantic results side by side; ranked hybrid search remains intentionally reserved for a later score-policy API.
- The default umbrella facade still uses deterministic hashing embeddings so tests, previews, and examples do not depend on downloaded Apple embedding assets.

## Verification Performed

- \`scripts/repo-maintenance/validate-all.sh\`
- \`swift test --filter SwiftlyFetchLibraryTests\`
- \`swiftformat --lint Sources/SwiftlyFetch/SwiftlyFetchLibrary.swift Sources/SwiftlyFetch/SwiftlyFetchSemanticRetry.swift Tests/SwiftlyFetchTests/SwiftlyFetchLibraryTests.swift\`
EOF
