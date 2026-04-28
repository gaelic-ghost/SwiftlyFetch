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

- added the first conventional-search foundation through \`FetchCore\`, \`FetchKit\`, and the new \`FetchKitLibrary\` facade
- shipped the first Core Data-backed durable corpus store, persisted pending index-sync queue, and thin macOS Search Kit backend
- added the polished persistent-library construction surface plus the local Search Kit helper lane for opt-in macOS verification
- documented the \`SwiftlyFetch\` / \`FetchKit\` / \`RAGKit\` package-family split more clearly in public and maintainer docs
- stabilized hosted CI by moving the Core Data-backed verification path to XCTest and aligning the durable store with a private-queue Core Data context

## Breaking Changes

- None. This is a backward-compatible patch release on top of \`v0.1.0\`.

## Migration Or Upgrade Notes

- \`RAGCore\` and \`RAGKit\` continue to provide the shipped semantic retrieval surface from \`v0.1.0\`.
- \`FetchCore\` and \`FetchKit\` now expose the first conventional-search foundation, including \`FetchKitLibrary\` for in-memory and macOS-persistent library construction.
- Real Natural Language integration coverage remains opt-in and requires \`RUN_NL_INTEGRATION_TESTS=1\`.
- The Search Kit verification lane remains local-only for now through \`scripts/repo-maintenance/run-searchkit-tests.sh\`.

## Verification Performed

- \`swift test\`
- \`scripts/repo-maintenance/validate-all.sh\`
- \`scripts/repo-maintenance/run-searchkit-tests.sh\`
EOF
