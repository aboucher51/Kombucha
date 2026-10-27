#!/usr/bin/env bash
# Prints the size of the virtual screen (Xvfb) for shoot.sh and serve.sh,
# as WxH, so the two cannot disagree.
#
#   tools/xvfb-screen.sh [project-dir]
#
# X keeps the real cursor inside its screen. A screen smaller than the game
# window stopped every warp at its edge: in a 1600x900 game on the old
# fixed 1280x720 screen, `hover` on a button at x=1292 read whatever was
# under (1279, y) instead (NavalWar's Settings Apply button). Clicks were
# fine, because they are pushed events, not the real cursor.
#
# The size is SHOOT_RESOLUTION when set (the window is opened at exactly
# that size), else the window project.godot opens (the window override
# when set, else the viewport size), never smaller than 1280x720. The
# floor keeps the screen of a smaller project as it was. The screen is not
# made larger than the window: a project that goes fullscreen would take
# the whole screen, and its shots would change size.
set -euo pipefail
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -n "${SHOOT_RESOLUTION:-}" ]]; then
	echo "$SHOOT_RESOLUTION"
	exit 0
fi

# Reads one key of project.godot's [display] section; prints nothing when
# it is absent.
setting() {
	awk -v key="$1" '
		/^\[/ { in_display = ($0 == "[display]") }
		in_display && index($0, key "=") == 1 { sub(/^[^=]*=/, ""); print; exit }
	' "$DIR/project.godot" 2>/dev/null || true
}
w="$(setting window/size/window_width_override)"
h="$(setting window/size/window_height_override)"
[[ "${w:-0}" =~ ^[1-9][0-9]*$ ]] || w="$(setting window/size/viewport_width)"
[[ "${h:-0}" =~ ^[1-9][0-9]*$ ]] || h="$(setting window/size/viewport_height)"
[[ "${w:-}" =~ ^[0-9]+$ ]] || w=0
[[ "${h:-}" =~ ^[0-9]+$ ]] || h=0
(( w < 1280 )) && w=1280
(( h < 720 )) && h=720
echo "${w}x${h}"
