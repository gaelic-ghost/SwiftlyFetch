#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/lib"
. "$SELF_DIR/lib/common.sh"

load_profile_env
ensure_git_repo

log "Running the opt-in Hugging Face corpus audit lane from $REPO_ROOT."
log "Set HF_CORPUS_AUDIT_* environment variables to tune bounded Dataset Viewer slice sizes."

cd "$REPO_ROOT"
swift run SwiftlyFetchCorpusAudit
