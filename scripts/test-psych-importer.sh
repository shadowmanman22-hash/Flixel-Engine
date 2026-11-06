#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
psych_test_dir=$(mktemp -d)
trap 'rm -rf "$psych_test_dir"' EXIT
# Isolate the standard-library-only converter from the game's global import.hx.
mkdir -p "$psych_test_dir/src/funkin/modding"
cp source/funkin/modding/PsychModImporter.hx "$psych_test_dir/src/funkin/modding/"
cp test/modding/PsychModImporterTest.hx "$psych_test_dir/src/"
PSYCH_TEST_ROOT="$psych_test_dir/data" haxe -cp "$psych_test_dir/src" --main PsychModImporterTest --interp
