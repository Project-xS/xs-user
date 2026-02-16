cd android

CACHE_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/flutter/nix-gradle"
mkdir -p "$CACHE_BASE"

./gradlew \
  --project-cache-dir="$CACHE_BASE/gradle-cache" \
  -Pkotlin.project.persistent.dir="$CACHE_BASE/kotlin" \
  :app:signingReport \
  --console=plain --stacktrace