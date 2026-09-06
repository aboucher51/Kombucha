#!/usr/bin/env bash
# Runs screenshot scenarios and reports where the PNGs landed.
#
#   tools/shoot.sh                        all of scenarios/*.txt
#   tools/shoot.sh scenarios/example.txt  just one
#
# Optional env vars:
#   SHOOT_RESOLUTION=1280x720   window size (layout bugs are often
#                               height-dependent — check more than one)
#   SHOOT_SEED=1                repeatable randomness, so two runs of the
#                               same scenario are actually comparable
#   SHOOT_TIMEOUT=<n>           seconds before giving up (default scales
#                               with the batch: 30 + 10 per scenario)
#   SHOOT_KEEP=1                keep existing shots instead of clearing
#   SHOOT_BASELINES=update      expect_shot WRITES its baselines (into
#                               scenarios/baselines/<renderer>/) instead of
#                               comparing; look at them, then commit them
#   SHOOT_JOBS=auto             processes to split the batch across: auto
#                               (default) is 2 for four or more scenarios
#                               on a machine with four or more cores, else
#                               1. Measured on a 36-scenario suite: two
#                               shards 164 s against 204 s in one.
#                               SHOOT_JOBS=1 runs the scenarios IN THE
#                               ORDER GIVEN (one process has nothing to
#                               balance): how an order-dependent pair, such
#                               as "this scenario leaves the boot scene and
#                               the next one must start on it", is proven.
#   SHOOT_DISPLAY=auto          auto (default): a real display if one is
#                               reachable, else a virtual one via xvfb-run;
#                               real: fail without one; xvfb: force the
#                               virtual display (how the CI path is
#                               exercised on a machine with WSLg)
#   SHOOT_SLOW=3                timeout multiplier under the virtual display
#   SHOOT_GPU=auto              auto (default): render on the GPU through
#                               Mesa's d3d12 driver when WSLg offers one
#                               (GALLIUM_DRIVER=d3d12) and a real display
#                               is in use; 0 forces llvmpipe (what CI
#                               renders with, so its expect_shot baselines
#                               can be made here). Measured on a 36-
#                               scenario suite: 208 s llvmpipe, 105 s GPU,
#                               same shots, and static frames are
#                               pixel-identical between GPU reruns.
#   GODOT=/path/to/binary       the engine to run (see check.sh)
#
# Every process gets its OWN XDG_DATA_HOME: user:// (saves, the sandboxed
# settings file) is per process, so shards cannot trample each other and two
# shoot.sh runs at once cannot either — the fixed sandbox path used to make
# concurrent runs fail in a way that looked exactly like a regression. A side
# effect worth having: scenarios boot from default settings, never the
# developer's saved ones. Only data moves; the shader cache stays shared.
#
# Needs a display SERVER, not a monitor or a GPU. --headless cannot be used:
# it has no renderer, so the viewport texture comes back null. Under WSL
# that means WSLg (DISPLAY=:0); anywhere else, Xvfb with Mesa's llvmpipe is
# what Godot's own CI uses (`xvfb-run godot --audio-driver Dummy ...`).
#
# OWNED BY KOMBUCHA (tools/tooling-manifest.txt); do not edit in a project.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot4}"
TIMINGS="$ROOT/.godot/shoot-timings"

SCENARIOS=("$@")
if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
	shopt -s nullglob
	SCENARIOS=(scenarios/*.txt)
fi
if [[ ${#SCENARIOS[@]} -eq 0 ]]; then
	echo "usage: tools/shoot.sh [<scenario-file> ...]" >&2
	exit 2
fi
for scenario in "${SCENARIOS[@]}"; do
	if [[ ! -f "$ROOT/$scenario" && ! -f "$scenario" ]]; then
		echo "shoot: no such scenario '$scenario'" >&2
		exit 2
	fi
done

# The watchdog exists for error loops, not to cap honest work — the budget
# scales with the batch so a growing suite is not killed mid-scenario.
TIMEOUT="${SHOOT_TIMEOUT:-$((30 + 10 * ${#SCENARIOS[@]}))}"

# A display is REACHABLE when its socket exists: DISPLAY=:0 alone proves
# nothing (WSLg exports it whether or not the server is up, and CI exports
# nothing at all).
have_display() {
	local n="${DISPLAY#*:}"
	n="${n%%.*}"
	[[ -n "${DISPLAY:-}" && -S "/tmp/.X11-unix/X${n}" ]] && return 0
	[[ -n "${WAYLAND_DISPLAY:-}" && -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}" ]] && return 0
	return 1
}
export DISPLAY="${DISPLAY:-:0}"
RUNNER=()
case "${SHOOT_DISPLAY:-auto}" in
	real)
		if ! have_display; then
			echo "shoot: no display reachable at DISPLAY=$DISPLAY (SHOOT_DISPLAY=real)" >&2
			exit 2
		fi ;;
	auto|xvfb)
		if [[ "${SHOOT_DISPLAY:-auto}" == "xvfb" ]] || ! have_display; then
			if ! command -v xvfb-run >/dev/null; then
				echo "shoot: no display and no xvfb-run — install xvfb (sudo apt install xvfb) or run under WSLg" >&2
				exit 2
			fi
			# Mesa's software rasterizer, explicitly, so the result is the same
			# on a runner with no GPU as on one with a GPU nobody asked for.
			export LIBGL_ALWAYS_SOFTWARE=1
			RUNNER=(xvfb-run -a -s "-screen 0 ${SHOOT_RESOLUTION:-1280x720}x24")
			echo "shoot: no real display — Xvfb + llvmpipe"
		fi ;;
	*) echo "shoot: SHOOT_DISPLAY must be auto, real or xvfb" >&2; exit 2 ;;
esac
[[ -z "${SHOOT_KEEP:-}" ]] && rm -f "$ROOT"/shots/*.png "$ROOT"/shots/*.jsonl 2>/dev/null

# The GPU is twice as fast and just as deterministic for a settled frame;
# llvmpipe stays the rasterizer of the virtual display (CI) and of any
# run that must match it.
gpu_available() { [[ -z "${GALLIUM_DRIVER:-}" && -e /usr/lib/x86_64-linux-gnu/dri/d3d12_dri.so ]]; }
if [[ ${#RUNNER[@]} -eq 0 && "${SHOOT_GPU:-auto}" != "0" ]] && gpu_available; then
	export GALLIUM_DRIVER=d3d12
fi

GODOT_ARGS=(--path "$ROOT")
[[ -n "${SHOOT_RESOLUTION:-}" ]] && GODOT_ARGS+=(--resolution "$SHOOT_RESOLUTION")
# The virtual display has no audio server either, and software rendering
# is slower: scale the watchdog rather than let honest work time out.
if [[ ${#RUNNER[@]} -gt 0 ]]; then
	GODOT_ARGS+=(--audio-driver Dummy)
	[[ -z "${SHOOT_TIMEOUT:-}" ]] && TIMEOUT=$(( TIMEOUT * ${SHOOT_SLOW:-3} ))
fi
SEED_ARGS=()
[[ -n "${SHOOT_SEED:-}" ]] && SEED_ARGS+=(--seed "$SHOOT_SEED")
if [[ "${SHOOT_BASELINES:-}" == "update" ]]; then
	SEED_ARGS+=(--update-baselines)
	echo "shoot: writing expect_shot baselines (SHOOT_BASELINES=update)"
fi

# ── deal the batch across processes ──────────────────────────────────────
CORES="$( (nproc 2>/dev/null || echo 4) )"
JOBS="${SHOOT_JOBS:-auto}"
if [[ "$JOBS" == "auto" ]]; then
	JOBS=1
	(( ${#SCENARIOS[@]} >= 4 && CORES >= 4 )) && JOBS=2
fi
(( JOBS > ${#SCENARIOS[@]} )) && JOBS=${#SCENARIOS[@]}
(( JOBS < 1 )) && JOBS=1

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# Longest-first from the last run's per-scenario seconds, unknown priced at
# the average (so a new scenario is not assumed free); one boot per shard
# is the fixed cost the deal is balancing against. One shard keeps the
# given order instead: there is nothing to balance, and the order is then
# a promise a scenario pair can rely on.
if [[ $JOBS -eq 1 ]]; then
	printf '%s\n' "${SCENARIOS[@]}" > "$WORK/list.0"
fi
[[ $JOBS -gt 1 ]] && printf '%s\n' "${SCENARIOS[@]}" | awk -v jobs="$JOBS" -v work="$WORK" -v timings="$TIMINGS" '
	BEGIN {
		known = 0; sum = 0
		while ((getline line < timings) > 0) {
			split(line, f, "\t"); if (f[1] != "") { cost[f[1]] = f[2] + 0; sum += f[2] + 0; known++ }
		}
		avg = (known > 0) ? sum / known : 1
	}
	{ item[NR] = $0; price[NR] = (($0 in cost) ? cost[$0] : avg) + 0.001; n = NR }
	END {
		for (i = 1; i <= n; i++) {
			pick = i
			for (j = i + 1; j <= n; j++) if (price[j] > price[pick]) pick = j
			t = price[i]; price[i] = price[pick]; price[pick] = t
			t = item[i]; item[i] = item[pick]; item[pick] = t
		}
		for (i = 1; i <= n; i++) {
			lightest = 0
			for (s = 1; s < jobs; s++) if (load[s] < load[lightest]) lightest = s
			load[lightest] += price[i]
			print item[i] > (work "/list." lightest)
		}
	}
'

PIDS=()
for ((i = 0; i < JOBS; i++)); do
	[[ -s "$WORK/list.$i" ]] || continue
	HARNESS_ARGS=()
	while read -r scenario; do HARNESS_ARGS+=(--scenario "$scenario"); done < "$WORK/list.$i"
	mkdir -p "$WORK/user.$i"
	# Piping godot's stdout swallows it; redirect to a file and read afterwards.
	# The log is only ever grepped, never slurped into a variable — an engine
	# stuck in an error loop can write hundreds of MB inside the timeout.
	# -k so a timeout kills the X server along with the engine; xvfb-run returns
	# the engine's exit code, so nothing below cares which path ran.
	(
		XDG_DATA_HOME="$WORK/user.$i" timeout -k 5 "$TIMEOUT" "${RUNNER[@]}" "$GODOT" "${GODOT_ARGS[@]}" \
			-- "${HARNESS_ARGS[@]}" "${SEED_ARGS[@]}" >"$WORK/shard.$i.log" 2>&1
	) &
	PIDS+=($!)
done

STATUS=0
FAILED=0
for pid in "${PIDS[@]}"; do
	wait "$pid"
	CODE=$?
	if [[ $CODE -eq 124 ]]; then
		echo "shoot: timed out after ${TIMEOUT}s — a scenario never reached its end" >&2
		STATUS=124
	elif [[ $CODE -ne 0 && $STATUS -eq 0 ]]; then
		STATUS=$CODE
	fi
done

LOG_LIMIT="${SHOOT_LOG_LIMIT:-$((2 * 1024 * 1024))}"
for log in "$WORK"/shard.*.log; do
	LOG_SIZE=$(stat -c %s "$log" 2>/dev/null || echo 0)
	if [[ $LOG_SIZE -le $LOG_LIMIT ]]; then
		cat "$log"
	else
		KEPT="$(mktemp)"; cp "$log" "$KEPT"
		head -n 200 "$log"
		echo "  [... shoot: log truncated — $LOG_SIZE bytes, full log kept at $KEPT ...]"
		tail -n 200 "$log"
	fi
done
FAILED=$(grep -h '^FAIL ' "$WORK"/shard.*.log | awk '{print $2}' | cut -d: -f1 | sort -u | wc -l)
if [[ $JOBS -gt 1 ]]; then
	echo "── batch: ${#SCENARIOS[@]} scenario(s) in $JOBS process(es), $FAILED failed ──"
fi

# Per-scenario seconds for the NEXT run's deal, only from a run that
# finished everything — MERGED over what the file already knows, so a
# single-scenario run updates one row instead of wiping the rest and
# leaving the next batch to deal blind.
if [[ $STATUS -eq 0 ]]; then
	mkdir -p "$(dirname "$TIMINGS")"
	touch "$TIMINGS"
	grep -h '^scenario ok:' "$WORK"/shard.*.log \
		| sed -nE 's/^scenario ok: (.*) \(([0-9.]+)s\)$/\1\t\2/p' \
		| awk -F'\t' 'NR == FNR { seen[$1] = 1; print; next } !seen[$1]' - "$TIMINGS" > "$TIMINGS.new" \
		&& mv "$TIMINGS.new" "$TIMINGS"
fi

# The harness only knows about failures its commands report back, so an
# engine-level error (a bad type, a null call, a shader that will not
# compile) would otherwise let a run pass while the game was visibly
# broken behind the screenshots. Plain `ERROR:` lines count too — a freed
# lambda capture, a ConfigFile key with no default — minus the exit-time
# "resources still in use" line, whose count is a coin toss.
ERROR_PATTERN="SCRIPT ERROR|Parse Error|shader|^ERROR:"
ENGINE_ERRORS=$(cat "$WORK"/shard.*.log | grep -vE "resources still in use at exit" | grep -cE "$ERROR_PATTERN")
if [[ $ENGINE_ERRORS -gt 0 ]]; then
	echo "shoot: $ENGINE_ERRORS engine error(s) — a green scenario does not mean a clean run" >&2
	cat "$WORK"/shard.*.log | grep -vE "resources still in use at exit" | grep -E "$ERROR_PATTERN" | sort -u | head -5 >&2
	[[ $STATUS -eq 0 ]] && STATUS=1
fi

shopt -s nullglob
SHOTS=("$ROOT"/shots/*.png)
echo "shoot: ${#SHOTS[@]} shot(s) in $ROOT/shots"
exit $STATUS
