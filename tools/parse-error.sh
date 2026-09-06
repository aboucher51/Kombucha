#!/usr/bin/env bash
# Names the file and line behind a parse error, given a run's log(s).
#
#   tools/parse-error.sh <log> [<log> ...]
#
# The engine reports a class that will not parse as
#   Parse Error: Could not resolve class "SaveCompat", because of a parser error.
# and names neither the file nor the line; every autoload that touches
# that class then fails to load and says the same thing again, so a
# whole suite's log can hold a hundred lines about a broken file none of
# them names. Finding it by hand costs a round trip of
# `godot4 --headless --script <guess>` per guess (three in one day, in
# the project that reported this).
#
# So: map each unresolved class to the file that declares it (and take
# any file the engine did name outright), ask the engine to parse just
# that file, and print the real message with its line. Prints nothing
# when the logs hold no parse error, so a caller can always call it.
#
# OWNED BY KOMBUCHA (tools/tooling-manifest.txt); do not edit in a project.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot4}"
[[ $# -gt 0 ]] || exit 0

CANDIDATES=()
# A class the engine could not resolve: its file is the one that declares it.
while read -r class_name; do
	[[ -n "$class_name" ]] || continue
	while read -r file; do
		[[ -n "$file" ]] && CANDIDATES+=("${file#"$ROOT/"}")
	done < <(grep -rlE "^class_name[[:space:]]+$class_name([[:space:]]|$)" \
		"$ROOT/scripts" "$ROOT/addons" 2>/dev/null | head -2)
done < <(grep -hoE 'Could not resolve class "[^"]+"' "$@" 2>/dev/null \
	| sed -E 's/.*"([^"]+)"/\1/' | sort -u | head -4)

# A script the engine named outright (a test script that would not load).
while read -r path; do
	[[ -n "$path" ]] && CANDIDATES+=("$path")
done < <(grep -hoE 'Failed to load script "res://[^"]+"' "$@" 2>/dev/null \
	| sed -E 's|.*"res://([^"]+)"|\1|' | sort -u | head -4)

[[ ${#CANDIDATES[@]} -gt 0 ]] || exit 0

ROOT_CAUSE=""
DOWNSTREAM=""
SEEN=""
for file in "${CANDIDATES[@]}"; do
	[[ -f "$ROOT/$file" ]] || continue
	[[ "$SEEN" == *"|$file|"* ]] && continue
	SEEN="$SEEN|$file|"
	OUT="$("$GODOT" --headless --path "$ROOT" --check-only --script "$file" 2>&1)"
	# The engine answers with the message and then the location; only the
	# location that names THIS file is about this file.
	LINE="$(grep -F "(res://$file:" <<<"$OUT" | head -1 | sed -E 's/.*:([0-9]+)\).*/\1/')"
	MESSAGE="$(grep -m1 -oE 'Parse Error: .*' <<<"$OUT" | sed -E 's/^Parse Error: //')"
	[[ -n "$LINE" && -n "$MESSAGE" ]] || continue
	# A file that merely NAMES the broken class fails the same way; that is
	# the noise this script exists to see past, so it is only reported when
	# nothing better was found.
	if [[ "$MESSAGE" == "Could not resolve class"* ]]; then
		[[ -z "$DOWNSTREAM" ]] && DOWNSTREAM="parse error: $file:$LINE — $MESSAGE"
	else
		ROOT_CAUSE+="parse error: $file:$LINE — $MESSAGE"$'\n'
	fi
done
if [[ -n "$ROOT_CAUSE" ]]; then
	printf '%s' "$ROOT_CAUSE"
elif [[ -n "$DOWNSTREAM" ]]; then
	printf '%s\n' "$DOWNSTREAM"
fi
exit 0
