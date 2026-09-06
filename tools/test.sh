#!/usr/bin/env bash
# Runs the GUT test suite headless.
#
#   tools/test.sh                    every test, split across processes
#   tools/test.sh test_smoke         one script: an EXACT name wins, so
#                                    test_campaign does not also run
#                                    test_campaign_flow; with no exact
#                                    match every script containing the
#                                    fragment runs and the run says so
#   tools/test.sh a b c              several scripts, one process — closing
#                                    a feature meant a dozen runs of one
#                                    script each, and every one paid the
#                                    engine's boot
#   TEST_JOBS=1                      one process — the readable log, and
#                                    what to reach for when a failure is
#                                    confusing (shards interleave nothing,
#                                    but a green shard prints nothing)
#   TEST_JOBS=8                      more shards (default 4, capped by the
#                                    script count and by nproc)
#   TEST_TIMEOUT=180                 seconds a shard may take (the default
#                                    is 180 for four shards and scales with
#                                    4/TEST_JOBS: one process gets 720, since
#                                    it carries the whole suite)
#   TEST_JUNIT=.godot/test-results.xml
#                                    where the merged JUnit report lands
#                                    (CI keeps it as an artifact; "" skips)
#   GODOT=/path/to/binary            the engine to run
#
# Why shards: a Godot test run is CPU-bound and single-threaded, and the
# suite is a pile of independent scripts. Each shard is its own process with
# its own XDG_DATA_HOME — every shard writes to `user://` (saves, settings,
# scratch), and two sharing that directory would fight over the same files.
# Shards share only the read-only `res://`.
#
# Balance comes from the LAST run: each shard writes JUnit timings and they
# are merged into .godot/test-timings, which the next run deals
# longest-first. Without it (a fresh checkout) the deal is round-robin and
# one slow script can hold the whole run open.
#
# Two guards that four projects each added separately: a test script that
# fails to PARSE is simply absent from the run and GUT reports a pass for
# whatever did load. Every log is grepped for the load failure, and the
# scripts that ran are counted against the scripts on disk.
#
# OWNED BY KOMBUCHA (tools/tooling-manifest.txt); do not edit in a project.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot4}"
cd "$ROOT" || exit 2

DEFAULT_TIMEOUT=180
TIMEOUT="${TEST_TIMEOUT:-$DEFAULT_TIMEOUT}"
TIMINGS="$ROOT/.godot/test-timings"
JUNIT="${TEST_JUNIT-$ROOT/.godot/test-results.xml}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# GUT paints its summary; strip the reset codes that survive grep-free output.
paint() { sed -E 's/\x1b\[0m$//' "$1"; }

load_fails() { grep -c 'Failed to load script' "$1" || true; }

# GUT counts a failed assertion in its summary but prints the text far
# above it; on a suite of any size that is hundreds of lines up, and the
# reflex is a second run piped through grep. Repeat them at the end.
report_failures() {
	local out
	out="$(awk '
		/^res:\/\/tests\// { script = $0; next }
		/^\* test_/ { name = substr($0, 3); next }
		/\[Failed\]/ {
			line = $0
			gsub(/\033\[[0-9;]*m/, "", line)
			sub(/^[ \t]+/, "", line)
			printf "  %s %s\n    %s\n", script, name, line
		}
	' "$@" 2>/dev/null | head -40)"
	[[ -n "$out" ]] && { echo "── failing assertions ──"; printf '%s\n' "$out"; }
	return 0
}

# A class that will not parse is reported by the engine as an unresolved
# class NAME, in every log, without ever naming the file or the line.
report_parse_error() {
	[[ -x "$ROOT/tools/parse-error.sh" ]] || return 0
	grep -qE 'because of a parser error|Failed to load script' "$@" 2>/dev/null || return 0
	local located
	located="$("$ROOT/tools/parse-error.sh" "$@" 2>/dev/null)"
	[[ -n "$located" ]] && printf '%s\n' "$located" >&2
	return 0
}

# ── named scripts: exactly those, in one process ─────────────────────────
# An EXACT name wins over a prefix: `test.sh test_campaign` used to run
# test_campaign_flow.gd too and return the union of both verdicts, so a
# green target read as red twice in one day, and a sibling's parse error
# read as the target's.
if [[ $# -gt 0 ]]; then
	shopt -s nullglob
	ALL=(tests/test_*.gd)
	shopt -u nullglob
	SELECTED=()
	for wanted_raw in "$@"; do
		wanted="$(basename "$wanted_raw" .gd)"
		exact=""
		matches=()
		for candidate in "${ALL[@]}"; do
			stem="$(basename "$candidate" .gd)"
			[[ "$stem" == "$wanted" ]] && exact="$candidate"
			[[ "$stem" == *"$wanted"* ]] && matches+=("$candidate")
		done
		if [[ -n "$exact" ]]; then
			SELECTED+=("$exact")
			(( ${#matches[@]} > 1 )) && \
				echo "test: '$wanted' also matches ${#matches[@]} scripts; running the exact one — name the others to include them" >&2
		elif (( ${#matches[@]} == 0 )); then
			echo "test: no test script matches '$wanted'" >&2
			exit 2
		else
			SELECTED+=("${matches[@]}")
			(( ${#matches[@]} > 1 )) && \
				echo "test: '$wanted' matches ${#matches[@]} scripts: ${matches[*]#tests/}" >&2
		fi
	done
	mapfile -t SELECTED < <(printf '%s\n' "${SELECTED[@]}" | awk '!seen[$0]++')
	LOG="$WORK/named.log"
	[[ -n "$JUNIT" ]] && mkdir -p "$(dirname "$JUNIT")"
	{
		printf '{"dirs": [], "include_subdirs": false, "log_level": 1,'
		printf ' "should_exit": true, "should_maximize": false,'
		[[ -n "$JUNIT" ]] && printf ' "junit_xml_file": "%s",' "$JUNIT"
		printf ' "tests": ['
		printf '"res://%s"\n' "${SELECTED[@]}" | paste -sd, -
		printf ']}'
	} > "$WORK/named.json"
	timeout "$TIMEOUT" "$GODOT" --headless --path "$ROOT" \
		-s addons/gut/gut_cmdln.gd "-gconfig=$WORK/named.json" >"$LOG" 2>&1
	STATUS=$?
	paint "$LOG"
	echo "Ran ${#SELECTED[@]} script(s): ${SELECTED[*]#tests/}"
	[[ $STATUS -eq 124 ]] && echo "test: timed out after ${TIMEOUT}s — a test is probably awaiting something that never comes" >&2
	[[ $STATUS -ne 0 ]] && report_failures "$LOG"
	FAILS=$(load_fails "$LOG")
	if [[ "$FAILS" -gt 0 ]]; then
		report_parse_error "$LOG"
		echo "test: $FAILS test script(s) failed to load (parse error above)" >&2
		echo "Failing Tests         $FAILS (scripts that did not load)"
		STATUS=1
	fi
	exit $STATUS
fi

# ── the whole suite, dealt across shards ─────────────────────────────────
find tests -name 'test_*.gd' | sort > "$WORK/all"
if [[ ! -s "$WORK/all" ]]; then
	echo "test: no test scripts under tests/" >&2
	exit 2
fi
COUNT=$(wc -l < "$WORK/all")
CORES="$( (nproc 2>/dev/null || echo 4) )"
JOBS="${TEST_JOBS:-4}"
(( JOBS > COUNT )) && JOBS=$COUNT
(( JOBS > CORES )) && JOBS=$CORES
(( JOBS < 1 )) && JOBS=1
# The default budget is per shard for FOUR shards; fewer shards carry more
# of the suite each. Without this, TEST_JOBS=1 on a suite that takes two
# minutes per shard was killed at 180 s and reported "88 scripts did not
# load" — a timeout wearing a parse error's message.
[[ -z "${TEST_TIMEOUT:-}" ]] && (( JOBS < 4 )) && TIMEOUT=$(( DEFAULT_TIMEOUT * 4 / JOBS ))

# Longest-processing-time first onto the emptiest shard. An unknown script
# is priced at the average, so a new test is not assumed free.
awk -v jobs="$JOBS" -v work="$WORK" -v timings="$TIMINGS" '
	BEGIN {
		known = 0; sum = 0
		while ((getline line < timings) > 0) {
			split(line, f, "\t"); if (f[1] != "") { cost[f[1]] = f[2] + 0; sum += f[2] + 0; known++ }
		}
		avg = (known > 0) ? sum / known : 1
	}
	# the floor matters: with every price at 0 the emptiest shard is always
	# shard 0, and the whole suite lands in one process
	{ script[NR] = $0; price[NR] = (($0 in cost) ? cost[$0] : avg) + 0.001; n = NR }
	END {
		for (i = 1; i <= n; i++) {
			pick = i
			for (j = i + 1; j <= n; j++) if (price[j] > price[pick]) pick = j
			t = price[i]; price[i] = price[pick]; price[pick] = t
			t = script[i]; script[i] = script[pick]; script[pick] = t
		}
		for (i = 1; i <= n; i++) {
			lightest = 0
			for (s = 1; s < jobs; s++) if (load[s] < load[lightest]) lightest = s
			load[lightest] += price[i]
			printf "\"res://%s\"\n", script[i] > (work "/list." lightest)
		}
		for (s = 0; s < jobs; s++) printf "" >> (work "/list." s)
	}
' "$WORK/all"

# A shard with nothing to run is not a pass: GUT refuses a config with no
# tests and exits 1. Shrink the count instead.
LIVE=0
for ((i = 0; i < JOBS; i++)); do
	[[ -s "$WORK/list.$i" ]] && { mv "$WORK/list.$i" "$WORK/live.$LIVE"; LIVE=$((LIVE + 1)); }
done
for ((i = 0; i < LIVE; i++)); do mv "$WORK/live.$i" "$WORK/list.$i"; done
JOBS=$LIVE

PIDS=()
STARTED=$(date +%s)
for ((i = 0; i < JOBS; i++)); do
	# `dirs: []` matters as much as the list: GUT ADDS -gtest entries to
	# whatever the config already names, so a shard that inherited tests/
	# would run the whole suite.
	{
		printf '{"dirs": [], "include_subdirs": false, "log_level": 1,'
		printf ' "should_exit": true, "should_maximize": false,'
		printf ' "junit_xml_file": "%s/shard.%d.xml", "tests": [' "$WORK" "$i"
		paste -sd, - < "$WORK/list.$i"
		printf ']}'
	} > "$WORK/shard.$i.json"
	(
		mkdir -p "$WORK/user.$i"
		XDG_DATA_HOME="$WORK/user.$i" timeout "$TIMEOUT" "$GODOT" --headless --path "$ROOT" \
			-s addons/gut/gut_cmdln.gd "-gconfig=$WORK/shard.$i.json" >"$WORK/shard.$i.log" 2>&1
	) &
	PIDS+=($!)
done

STATUS=0
TIMED_OUT=0
for ((i = 0; i < JOBS; i++)); do
	wait "${PIDS[$i]}"
	CODE=$?
	if [[ $CODE -eq 124 ]]; then
		echo "test: shard $i timed out after ${TIMEOUT}s — a test awaiting something that never comes, or a suite bigger than the budget (TEST_TIMEOUT)" >&2
		TIMED_OUT=1
	fi
	FAILS=$(load_fails "$WORK/shard.$i.log")
	if [[ "$FAILS" -gt 0 ]]; then
		echo "test: shard $i had $FAILS test script(s) that failed to load" >&2
		CODE=1
	fi
	# A green shard's log is noise; a red one is the whole point.
	if [[ $CODE -ne 0 ]]; then
		echo "── shard $i ──"
		paint "$WORK/shard.$i.log"
		STATUS=1
	fi
done
ELAPSED=$(( $(date +%s) - STARTED ))

# The stronger guard: count what ran against what exists. A script that
# vanished without printing anything at all still shows up here.
RAN=$(grep -hoE '^res://tests/test_[a-z0-9_]+\.gd' "$WORK"/shard.*.log | sort -u | wc -l)
if [[ $RAN -lt $COUNT ]]; then
	if [[ $TIMED_OUT -eq 1 ]]; then
		# A killed shard never reached its remaining scripts: that is the
		# timeout's doing, not a parse error's, and must not read as one.
		echo "test: only $RAN of $COUNT test scripts ran — a shard timed out before the rest" >&2
		echo "Failing Tests         $((COUNT - RAN)) (scripts a timed-out shard never reached)"
	else
		echo "test: only $RAN of $COUNT test scripts ran — the rest failed to load" >&2
		grep -hE 'Failed to load script' "$WORK"/shard.*.log | sed 's/^/  /' >&2
		report_parse_error "$WORK"/shard.*.log
		echo "Failing Tests         $((COUNT - RAN)) (scripts that did not load)"
	fi
	STATUS=1
fi

# The assertions behind a red run, repeated where they can be read.
[[ $STATUS -ne 0 ]] && report_failures "$WORK"/shard.*.log

# Per-script times for the NEXT run's deal. Written only when every shard
# produced one, so a crashed run cannot poison the balance with a half table.
if [[ $(find "$WORK" -name 'shard.*.xml' | wc -l) -eq $JOBS ]]; then
	mkdir -p "$(dirname "$TIMINGS")"
	grep -ho '<testsuite [^>]*>' "$WORK"/shard.*.xml \
		| sed -nE 's/.*name="(res:\/\/)?([^"]*tests\/[^"]*)".*time="([0-9.]+)".*/\2\t\3/p' \
		> "$TIMINGS.new" && mv "$TIMINGS.new" "$TIMINGS"
fi

# The per-shard JUnit files, merged into ONE report a CI system or an
# editor can read: every <testsuite> under a single <testsuites>, with the
# totals re-summed. Written whatever the verdict — a red run is exactly
# when the report is wanted.
if [[ -n "$JUNIT" ]] && compgen -G "$WORK/shard.*.xml" >/dev/null; then
	mkdir -p "$(dirname "$JUNIT")"
	{
		echo '<?xml version="1.0" encoding="UTF-8"?>'
		printf '<testsuites name="GutTests" tests="%s" failures="%s">\n' \
			"$(grep -ho '<testsuites [^>]*>' "$WORK"/shard.*.xml | sed -nE 's/.* tests="([0-9]+)".*/\1/p' | paste -sd+ - | bc)" \
			"$(grep -ho '<testsuites [^>]*>' "$WORK"/shard.*.xml | sed -nE 's/.* failures="([0-9]+)".*/\1/p' | paste -sd+ - | bc)"
		cat "$WORK"/shard.*.xml | grep -vE '^<\?xml|^<testsuites |^</testsuites>'
		echo '</testsuites>'
	} > "$JUNIT"
	echo "junit: ${JUNIT#"$ROOT"/}"
fi

# One summary in the shape every caller greps for, whatever the shard count.
awk -v jobs="$JOBS" -v elapsed="$ELAPSED" '
	/^(Scripts|Tests|Passing Tests|Failing Tests|Asserts) / {
		key = ($2 ~ /^[0-9]/) ? $1 : $1 " " $2
		total[key] += $NF + 0; if (!(key in order)) order[key] = ++k
	}
	END {
		printf "── %d shard(s), %ds ──\n", jobs, elapsed
		for (key in total) rows[order[key]] = key
		for (i = 1; i <= k; i++) if (rows[i] != "") printf "%-20s %6d\n", rows[i], total[rows[i]]
	}
' "$WORK"/shard.*.log

exit $STATUS
