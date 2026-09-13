#!/usr/bin/env bash
# One engine kept alive and fed scenarios as files, so iterating on a
# scenario costs no boots and the game keeps its state between commands.
#
#   tools/serve.sh start                 boot the engine on the display
#   tools/serve.sh run scenarios/x.txt   run a scenario against the live state
#   tools/serve.sh say "click PlayButton"   one line (any scenario or console
#                                        command; `reset` returns to the
#                                        boot scene with a fresh sandbox)
#   tools/serve.sh status                running or not
#   tools/serve.sh stop                  end it (restores what the sandbox
#                                        redirected)
#
# The reply is what the harness printed for that command (shot paths,
# FAIL lines, scenario ok), and the exit code is its verdict; shots and
# the JSONL trace land in shots/ as usual. Same display and GPU rules as
# shoot.sh (SHOOT_GPU, SHOOT_RESOLUTION, SHOOT_SEED, SHOOT_DISPLAY): a
# virtual display (Xvfb, held open for the life of the engine) when
# xvfb-run is installed, because a window on the real display takes the
# keyboard on every launch under WSLg; else the real display;
# SHOOT_DISPLAY=real to watch the window. The GPU is used on either.
#
# OWNED BY KOMBUCHA (tools/tooling-manifest.txt); do not edit in a project.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot4}"
SERVE="${SERVE_DIR:-$ROOT/.godot/serve}"
LOG="$SERVE/engine.log"
PIDFILE="$SERVE/engine.pid"
TIMEOUT="${SERVE_TIMEOUT:-120}"

running() { [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

# Commands are numbered, so shots and traces read 0007-example-01-boot.png
# and the engine takes them in the order they were sent.
next_name() { # stem
	local n=0
	[[ -f "$SERVE/counter" ]] && n=$(cat "$SERVE/counter")
	n=$((n + 1)); echo "$n" > "$SERVE/counter"
	printf '%04d-%s' "$n" "$1"
}

# Waits for a reply file, then prints the engine log lines added meanwhile.
send() { # name, source-file
	local name="$1" from_line
	from_line=$(wc -l < "$LOG")
	cp "$2" "$SERVE/$name.cmd.tmp" && mv "$SERVE/$name.cmd.tmp" "$SERVE/$name.cmd"
	local waited=0
	while [[ ! -f "$SERVE/$name.done" ]]; do
		running || { echo "serve: engine died — see $LOG" >&2; return 2; }
		sleep 0.05; waited=$((waited + 1))
		if (( waited > TIMEOUT * 20 )); then echo "serve: no reply after ${TIMEOUT}s" >&2; return 124; fi
	done
	tail -n +"$((from_line + 1))" "$LOG" | grep -vE '^harness: |^── scenario'
	local verdict; verdict="$(cat "$SERVE/$name.done")"; rm -f "$SERVE/$name.done"
	[[ "$verdict" == ok ]]
}

case "${1:-}" in
	start)
		running && { echo "serve: already running (pid $(cat "$PIDFILE"))"; exit 0; }
		mkdir -p "$SERVE/user"; rm -f "$SERVE"/*.cmd "$SERVE"/*.done "$SERVE/quit" "$SERVE/counter"; : > "$LOG"
		ARGS=(--path "$ROOT")
		[[ -n "${SHOOT_RESOLUTION:-}" ]] && ARGS+=(--resolution "$SHOOT_RESOLUTION")
		SEED=(); [[ -n "${SHOOT_SEED:-}" ]] && SEED=(--seed "$SHOOT_SEED")
		export DISPLAY="${DISPLAY:-:0}"
		# The same display rule as shoot.sh: virtual when xvfb-run is
		# installed (a window on the real display takes the keyboard on
		# every launch under WSLg), else the real display when its socket
		# exists (DISPLAY alone proves nothing under WSLg or CI). Under
		# WSLg /tmp/.X11-unix is read-only, so Xvfb listens on TCP (-l).
		RUNNER=()
		n="${DISPLAY#*:}"; n="${n%%.*}"
		have_real=0
		{ [[ -S "/tmp/.X11-unix/X${n}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" && -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY:-}" ]]; } && have_real=1
		want="${SHOOT_DISPLAY:-auto}"
		if [[ "$want" == "auto" ]]; then
			if command -v xvfb-run >/dev/null; then want=xvfb; elif [[ $have_real -eq 1 ]]; then want=real; else
				echo "serve: no display and no xvfb-run — install xvfb (sudo apt install xvfb) or run under WSLg" >&2; exit 2
			fi
		fi
		case "$want" in
			real) [[ $have_real -eq 1 ]] || { echo "serve: no display reachable at DISPLAY=$DISPLAY (SHOOT_DISPLAY=real)" >&2; exit 2; } ;;
			xvfb)
				command -v xvfb-run >/dev/null || { echo "serve: no xvfb-run — install xvfb (sudo apt install xvfb)" >&2; exit 2; }
				listen=(); [[ -w /tmp/.X11-unix ]] || listen=(-l)
				RUNNER=(xvfb-run -a "${listen[@]}" -s "-screen 0 ${SHOOT_RESOLUTION:-1280x720}x24")
				ARGS+=(--audio-driver Dummy) ;;
			*) echo "serve: SHOOT_DISPLAY must be auto, real or xvfb" >&2; exit 2 ;;
		esac
		# The GPU on either display when WSLg offers one (same adapter, same
		# baselines); the virtual display gets llvmpipe explicitly without it.
		if [[ -z "${GALLIUM_DRIVER:-}" && "${SHOOT_GPU:-auto}" != "0" && -e /usr/lib/x86_64-linux-gnu/dri/d3d12_dri.so ]]; then
			export GALLIUM_DRIVER=d3d12
		elif [[ ${#RUNNER[@]} -gt 0 && -z "${GALLIUM_DRIVER:-}" ]]; then
			export LIBGL_ALWAYS_SOFTWARE=1
		fi
		if [[ ${#RUNNER[@]} -gt 0 ]]; then
			[[ "${GALLIUM_DRIVER:-}" == "d3d12" ]] && echo "serve: virtual display (Xvfb), GPU" || echo "serve: virtual display (Xvfb), llvmpipe"
		else
			echo "serve: real display — the window takes focus; sudo apt install xvfb for a virtual one"
		fi
		XDG_DATA_HOME="$SERVE/user" nohup "${RUNNER[@]}" "$GODOT" "${ARGS[@]}" -- --serve "$SERVE" "${SEED[@]}" >"$LOG" 2>&1 &
		echo $! > "$PIDFILE"
		for i in $(seq 1 200); do grep -q '^harness: serving' "$LOG" 2>/dev/null && break; sleep 0.1; done
		grep -q '^harness: serving' "$LOG" || { echo "serve: engine did not start — see $LOG" >&2; exit 1; }
		grep -m1 '^harness: renderer' "$LOG"
		echo "serve: running (pid $(cat "$PIDFILE"))" ;;
	run)
		running || { echo "serve: not running — tools/serve.sh start" >&2; exit 2; }
		[[ -f "${2:-}" ]] || { echo "usage: tools/serve.sh run <scenario-file>" >&2; exit 2; }
		send "$(next_name "$(basename "$2" .txt)")" "$2" ;;
	say)
		running || { echo "serve: not running — tools/serve.sh start" >&2; exit 2; }
		[[ -n "${2:-}" ]] || { echo "usage: tools/serve.sh say \"<line>\"" >&2; exit 2; }
		TMP="$(mktemp)"; printf '%s\n' "$2" > "$TMP"
		send "$(next_name say)" "$TMP"; CODE=$?; rm -f "$TMP"; exit $CODE ;;
	status)
		running && echo "serve: running (pid $(cat "$PIDFILE"))" || { echo "serve: not running"; exit 1; } ;;
	stop)
		running || { echo "serve: not running"; exit 0; }
		: > "$SERVE/quit"
		for i in $(seq 1 100); do running || break; sleep 0.1; done
		# A forced stop must take the engine AND a virtual X server with it.
		running && { pkill -P "$(cat "$PIDFILE")" 2>/dev/null; kill "$(cat "$PIDFILE")" 2>/dev/null; }
		rm -f "$PIDFILE"; echo "serve: stopped" ;;
	*) echo "usage: tools/serve.sh start|run <scenario>|say \"<line>\"|status|stop" >&2; exit 2 ;;
esac
