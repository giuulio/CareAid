#!/usr/bin/env bash
# Checks the Swift models in CareAid/Models against a realistic `extract`
# response built from the CLAUDE.md §9 demo script.
#
# The models only import Foundation, so they compile and run outside the app —
# no test target, no simulator. Run this after changing the extraction schema:
#
#   tools/model_check/run.sh
#
# Offline dev tooling. Never shipped; tools/ is outside the app target.
set -euo pipefail
cd "$(dirname "$0")"
out=$(mktemp -d)
xcrun swiftc -swift-version 6 ../../CareAid/Models/*.swift main.swift -o "$out/model_check"
"$out/model_check"
