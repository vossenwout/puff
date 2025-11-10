#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSISTANT_NAME="${1:-Smoke Test}"

echo "Running swift build (debug)..."
swift build

echo "Bundling release artifacts (release)..."
CONFIG=release "$ROOT/Scripts/build_and_bundle.sh"

echo "Triggering verification notification..."
"$ROOT/dist/puff" "$ASSISTANT_NAME"

echo "Smoke test completed."
