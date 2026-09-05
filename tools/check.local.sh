#!/usr/bin/env bash
# The FIXTURE's local check: exists so check.sh's local-check seam is
# exercised here. A real project puts its sims, balance gates and linters
# in this file (see tools/seeds/check.local.sh for the skeleton).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

# Every path the manifest names must exist here, or a sync would ship a
# manifest that points at nothing.
MISSING=0
while read -r entry; do
	[[ -z "$entry" || "$entry" == \#* ]] && continue
	[[ -e "$entry" ]] || { printf '  FAIL  manifest entry missing: %s\n' "$entry"; MISSING=1; }
done < tools/tooling-manifest.txt
[[ $MISSING -eq 0 ]] && printf '  ok    manifest paths exist\n'

# The project command file the console merges must be a JSON array.
if python3 -c 'import json,sys; sys.exit(0 if isinstance(json.load(open("data/console_commands.project.json")), list) else 1)' 2>/dev/null; then
	printf '  ok    console_commands.project.json is a list\n'
else
	printf '  FAIL  console_commands.project.json is not a JSON list\n'; MISSING=1
fi
exit $MISSING
