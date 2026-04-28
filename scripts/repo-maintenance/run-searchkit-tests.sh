#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/lib"
. "$SELF_DIR/lib/common.sh"

load_profile_env
ensure_git_repo

DESTINATION="${SEARCHKIT_TEST_DESTINATION:-platform=macOS}"
SCHEME="${SEARCHKIT_TEST_SCHEME:-SwiftlyFetch-Package}"
TEST_TARGET="${SEARCHKIT_TEST_ONLY:-SearchKitFetchIndexTests}"

log "Running the local opt-in Search Kit test lane for $TEST_TARGET from $REPO_ROOT."

cd "$REPO_ROOT"
RUN_SEARCHKIT_TESTS=1 swift test --filter "$TEST_TARGET"
