#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/../lib"
. "$SELF_DIR/../lib/common.sh"

[ -f "$REPO_ROOT/Package.swift" ] || die "Expected $REPO_ROOT/Package.swift to exist before running Swift package validation."

cd "$REPO_ROOT"

log "Building Swift package from $REPO_ROOT."
swift build

log "Testing Swift package from $REPO_ROOT."
swift test
