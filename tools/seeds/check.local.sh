#!/usr/bin/env bash
# Project-specific checks, run by tools/check.sh between the headless boot
# and the scenarios. This file is yours; check.sh is owned by Microbiome.
#
# Print one `  ok    <name>` / `  FAIL  <name>` line per check and exit
# non-zero if any failed. QUICK=1 means no display is available.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
exit 0
