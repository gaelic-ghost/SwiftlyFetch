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
text = readme_path.read_text()
pattern = re.compile(r"`v\d+\.\d+\.\d+` is .*")
replacement = f"`{tag}` is the current tagged package release and is stable enough to try locally."
updated, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit("Could not find the README status line to update.")
tmp_path.write_text(updated)
PY

mv "$tmp_readme" "$readme_path"

mkdir -p "$release_notes_dir"

cat >"$release_notes_path" <<EOF
# SwiftlyFetch $tag

## What Changed

- refined conventional-search ranking so title hits get a modest boost, Search Kit scores normalize per field, and cross-field matches accumulate more intentionally
- replaced the old single-term snippet behavior with shared query-aware snippets that can highlight multiple query terms and show visible truncation markers when context is cropped
- added stronger default-path and opt-in Search Kit coverage for ranking preference, phrase behavior, and snippet presentation
- documented the new conventional-search refinement state in the README, roadmap, and maintainer notes

## Breaking Changes

- None. This is a backward-compatible patch release on top of \`v0.1.1\`.

## Migration Or Upgrade Notes

- \`RAGCore\` and \`RAGKit\` continue to provide the shipped semantic retrieval surface from \`v0.1.1\`.
- \`FetchCore\` and \`FetchKit\` still expose the same conventional-search foundation, but \`FetchKitLibrary\` search results now rank title and phrase matches more intentionally and return richer snippets by default.
- Real Natural Language integration coverage remains opt-in and requires \`RUN_NL_INTEGRATION_TESTS=1\`.
- The Search Kit verification lane remains local-only for now through \`scripts/repo-maintenance/run-searchkit-tests.sh\`.

## Verification Performed

- \`swift test\`
- \`scripts/repo-maintenance/validate-all.sh\`
- \`scripts/repo-maintenance/run-searchkit-tests.sh\`
EOF
