#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/lib"
. "$SELF_DIR/lib/common.sh"

load_profile_env
ensure_git_repo

TEST_TARGET="${NL_INTEGRATION_TEST_ONLY:-NaturalLanguageEmbedderIntegrationTests}"

log "Running the Natural Language integration lane for $TEST_TARGET from $REPO_ROOT."

cd "$REPO_ROOT"
RUN_NL_INTEGRATION_TESTS=1 swift test --filter "$TEST_TARGET"
