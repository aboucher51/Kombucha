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

# The headless driver pattern (tools/seeds/dev_driver.gd), both verdicts:
# the exit code is the gate, and a gate must be proven able to fail.
if timeout 30 "${GODOT:-godot4}" --headless --path . -- --selftest >/dev/null 2>&1; then
	printf '  ok    selftest driver exits 0\n'
else
	printf '  FAIL  selftest driver did not exit 0\n'; MISSING=1
fi
if timeout 30 "${GODOT:-godot4}" --headless --path . -- --selftest --selftest-fail >/dev/null 2>&1; then
	printf '  FAIL  selftest driver cannot go red\n'; MISSING=1
else
	printf '  ok    selftest driver goes red on demand\n'
fi

# Between scenarios the harness must return to the BOOT scene, not reload
# wherever the last scenario navigated: run an ordered pair in one process
# (SHOOT_JOBS=1 keeps the order) — the first leaves the boot scene, the
# second asserts it is back on it. Needs a display, like every scenario.
if [[ "${QUICK:-0}" -eq 0 ]]; then
	if SHOOT_JOBS=1 SHOOT_KEEP=1 tools/shoot.sh scenarios/leave_boot.txt scenarios/example.txt >/dev/null 2>&1; then
		printf '  ok    harness returns to the boot scene between scenarios\n'
	else
		printf '  FAIL  harness did not return to the boot scene between scenarios\n'; MISSING=1
	fi
	# The JSONL trace beside the shots: one JSON object per line, a summary
	# last, and the lines a scenario ran are all there.
	if python3 - <<'PY'
import json, sys
rows = [json.loads(l) for l in open("shots/example.jsonl")]
ok = rows[-1].get("scenario") == "scenarios/example.txt" and rows[-1]["ok"] is True \
	and any(r.get("line") == "assert_visible TitleLabel" and r["ok"] for r in rows) \
	and any(r.get("line", "").startswith("expect_fail") for r in rows) and all("ms" in r for r in rows[:-1])
sys.exit(0 if ok else 1)
PY
	then
		printf '  ok    scenario trace shots/example.jsonl is complete\n'
	else
		printf '  FAIL  scenario trace shots/example.jsonl missing or incomplete\n'; MISSING=1
	fi
	# Clicks must land at a window size BELOW the design size (fractional
	# shrink) and ABOVE it (integer snap), not only at 1280x720: the real
	# cursor is warped in window pixels while the event is in canvas
	# coordinates, and the two only agree at the design size.
	for res in 960x540 1280x800; do
		if SHOOT_RESOLUTION=$res SHOOT_JOBS=1 SHOOT_KEEP=1 tools/shoot.sh scenarios/pause_menu.txt scenarios/tooltip.txt >/dev/null 2>&1; then
			printf '  ok    clicks and hovers land at %s\n' "$res"
		else
			printf '  FAIL  clicks or hovers miss at %s\n' "$res"; MISSING=1
		fi
	done
	# Serve mode: one engine, commands as files, verdict per command. A
	# passing run, a failing line (the gate's own red), and a clean stop.
	if tools/serve.sh start >/dev/null 2>&1 \
			&& tools/serve.sh run scenarios/example.txt 2>&1 | grep -q '^scenario ok' \
			&& ! tools/serve.sh say "assert_visible NoSuchNode" >/dev/null 2>&1 \
			&& tools/serve.sh say "assert_visible TitleLabel" >/dev/null 2>&1 \
			&& tools/serve.sh stop >/dev/null 2>&1 && ! tools/serve.sh status >/dev/null 2>&1; then
		printf '  ok    serve mode runs, fails a bad line, stops\n'
	else
		printf '  FAIL  serve mode (tools/serve.sh) — see .godot/serve/engine.log\n'; MISSING=1
		tools/serve.sh stop >/dev/null 2>&1
	fi
	# The CI path (virtual display, software GL) exercised HERE when the
	# package is present, so the branch cannot rot between pushes.
	if command -v xvfb-run >/dev/null; then
		if SHOOT_DISPLAY=xvfb SHOOT_JOBS=1 SHOOT_KEEP=1 tools/shoot.sh scenarios/example.txt 2>&1 | grep -q 'renderer llvmpipe'; then
			printf '  ok    Xvfb path renders with llvmpipe\n'
		else
			printf '  FAIL  Xvfb path did not render with llvmpipe\n'; MISSING=1
		fi
	else
		printf '  --    Xvfb path (xvfb-run not installed: sudo apt install xvfb)\n'
	fi
fi

# One Godot version, written in two places: tools/GODOT_VERSION (CI and
# export.sh read it) and setup.sh (which runs from a curl pipe, with no
# file beside it). They must agree.
PINNED="$(cat tools/GODOT_VERSION)"
if grep -q "^GODOT_VERSION=\"$PINNED\"" tools/setup.sh; then
	printf '  ok    setup.sh installs the pinned Godot %s\n' "$PINNED"
else
	printf '  FAIL  setup.sh GODOT_VERSION differs from tools/GODOT_VERSION (%s)\n' "$PINNED"; MISSING=1
fi

# The runner's own guards, proven against a scratch copy (see selftest.sh).
tools/selftest.sh || MISSING=1
exit $MISSING
