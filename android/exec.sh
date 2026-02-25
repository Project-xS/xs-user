#!/usr/bin/env bash
set -euo pipefail

# run relative to android/ no matter where you call it from
ANDROID_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ANDROID_DIR"

CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/flutter/nix-gradle"
mkdir -p "$CACHE_BASE/gradle-project-cache" "$CACHE_BASE/kotlin"

exec ./gradlew \
  --project-cache-dir="$CACHE_BASE/gradle-project-cache" \
  -Pkotlin.project.persistent.dir="$CACHE_BASE/kotlin" \
  --console=plain \
  "$@"