#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
if ! command -v swift >/dev/null 2>&1; then
  echo "swift is not on PATH. Install a Swift 5.9+ toolchain, then rerun." >&2
  exit 1
fi
swift test --package-path "$root" --filter 'ProgressionEngineTests|TodaySessionEntryTests'
