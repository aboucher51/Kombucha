#!/usr/bin/env bash
# Sets a machine up for the Godot-to-Claude workflow: Godot 4.7 as
# `godot4`, the three Claude Code plugins, the editor path Claude's
# GDScript language server needs, and (optionally) the project map tool.
# Safe to re-run: every step checks before it acts and says what it did.
#
#   curl -fsSL https://raw.githubusercontent.com/aboucher51/Kombucha/main/tools/setup.sh | bash
#   tools/setup.sh                # from a clone
#   tools/setup.sh --with-map     # also install godot-map (needs uv)
#   tools/setup.sh --no-plugins   # only Godot and the settings
#
# Linux or WSL2. Nothing here needs sudo: Godot goes to ~/.local/bin.
set -uo pipefail

GODOT_VERSION="4.7"
BIN="${SETUP_BIN:-$HOME/.local/bin}"
CLAUDE_SETTINGS="${SETUP_CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
PROJECTS="${SETUP_PROJECTS:-$HOME/godot-projects}"
WITH_MAP=0
PLUGINS=1
for arg in "$@"; do
	case "$arg" in
		--with-map) WITH_MAP=1 ;;
		--no-plugins) PLUGINS=0 ;;
		-h|--help) sed -n '2,13p' "$0"; exit 0 ;;
		*) echo "setup: unknown option '$arg' (see --help)" >&2; exit 2 ;;
	esac
done

ok()   { printf '  ok    %s\n' "$*"; }
did()  { printf '  done  %s\n' "$*"; }
skip() { printf '  --    %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILED=1; }
FAILED=0
TODO=()

echo "── prerequisites ──"
case "$(uname -s)" in
	Linux) ok "Linux$(grep -qi microsoft /proc/version 2>/dev/null && echo ' (WSL2)')" ;;
	*) fail "this workflow runs on Linux or WSL2 (found $(uname -s))"; exit 1 ;;
esac
for tool in git python3 curl; do
	if command -v "$tool" >/dev/null 2>&1; then ok "$tool"; else fail "$tool is missing — install it with your package manager"; fi
done
[[ $FAILED -eq 1 ]] && exit 1
if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
	skip "no display in this shell: tests run headless, screenshots need WSLg (Windows 11) or an X server"
else
	ok "display ${DISPLAY:-$WAYLAND_DISPLAY}"
fi

echo "── godot $GODOT_VERSION ──"
have_godot() { command -v godot4 >/dev/null 2>&1 && godot4 --version 2>/dev/null | grep -q "^${GODOT_VERSION//./\\.}\."; }
if have_godot; then
	ok "godot4 $(godot4 --version 2>/dev/null | head -1) on PATH"
else
	mkdir -p "$BIN"
	zip="$(mktemp --suffix=.zip)"
	url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
	if curl -fL --retry 3 --progress-bar -o "$zip" "$url" \
			&& python3 - "$zip" "$BIN/godot4" <<-'PY'
		import os, sys, zipfile
		zip_path, out = sys.argv[1], sys.argv[2]
		with zipfile.ZipFile(zip_path) as z:
		    name = next(n for n in z.namelist() if n.endswith("linux.x86_64"))
		    with open(out, "wb") as f:
		        f.write(z.read(name))
		os.chmod(out, 0o755)
	PY
	then
		did "installed $BIN/godot4"
	else
		fail "could not download Godot from $url"
	fi
	rm -f "$zip"
	if ! command -v godot4 >/dev/null 2>&1; then
		TODO+=("add $BIN to your PATH (e.g. echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.bashrc) and open a new shell")
	fi
fi

echo "── claude code ──"
if command -v claude >/dev/null 2>&1; then
	ok "claude $(claude --version 2>/dev/null | head -1)"
	if [[ $PLUGINS -eq 1 ]]; then
		marketplaces="$(claude plugin marketplace list 2>/dev/null || true)"
		installed="$(claude plugin list 2>/dev/null || true)"
		add_plugin() { # marketplace-name  marketplace-source  plugin  what
			if ! grep -q "$1" <<<"$marketplaces"; then
				if claude plugin marketplace add "$2" >/dev/null 2>&1; then did "marketplace $1"; else fail "could not add marketplace $2"; return; fi
			fi
			if grep -q "$3@$1" <<<"$installed"; then
				ok "$3 ($4)"
			elif claude plugin install "$3@$1" >/dev/null 2>&1; then
				did "installed $3 ($4)"
			else
				fail "could not install $3@$1"
			fi
		}
		add_plugin kombucha aboucher51/Kombucha kombucha "the test, screenshot and check loop; scaffolds projects"
		add_plugin skillsmith jame581/skillsmith godot-prompter "how to build each Godot system"
		add_plugin claude-code-gdscript twaananen/claude-code-gdscript gdscript "GDScript language server for Claude"
	fi
	# The GDScript language server starts Godot itself; tell it where.
	godot_path="$(command -v godot4 2>/dev/null || echo "$BIN/godot4")"
	mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
	case "$(python3 - "$CLAUDE_SETTINGS" "$godot_path" <<-'PY'
		import json, os, sys
		path, godot = sys.argv[1], sys.argv[2]
		data = {}
		if os.path.exists(path):
		    with open(path) as f:
		        text = f.read().strip()
		    data = json.loads(text) if text else {}
		env = data.setdefault("env", {})
		if env.get("GODOT_EDITOR_PATH") == godot:
		    print("same")
		else:
		    env["GODOT_EDITOR_PATH"] = godot
		    with open(path, "w") as f:
		        json.dump(data, f, indent=2)
		        f.write("\n")
		    print("set")
	PY
	)" in
		same) ok "GODOT_EDITOR_PATH in $CLAUDE_SETTINGS" ;;
		set) did "GODOT_EDITOR_PATH=$godot_path in $CLAUDE_SETTINGS" ;;
		*) fail "could not update $CLAUDE_SETTINGS (is it valid JSON?)" ;;
	esac
	TODO+=("restart Claude Code so the plugins and settings load")
else
	skip "claude is not installed"
	TODO+=("install Claude Code (https://claude.com/claude-code), then re-run this script for the plugins")
fi

echo "── project map (optional) ──"
if command -v godot-map >/dev/null 2>&1; then
	ok "godot-map"
elif [[ $WITH_MAP -eq 0 ]]; then
	skip "not installed; re-run with --with-map (Claude reads the map before grepping; check.sh keeps it fresh)"
elif ! command -v uv >/dev/null 2>&1; then
	fail "godot-map installs with uv (https://docs.astral.sh/uv/); install uv and re-run with --with-map"
else
	mkdir -p "$PROJECTS"
	if [[ ! -d "$PROJECTS/godot-map" ]]; then
		git clone -q https://github.com/aboucher51/godot-map "$PROJECTS/godot-map" || fail "could not clone godot-map"
	fi
	if [[ -d "$PROJECTS/godot-map" ]] && uv tool install -q --editable "$PROJECTS/godot-map" >/dev/null 2>&1; then
		did "godot-map from $PROJECTS/godot-map"
	else
		fail "uv tool install of godot-map failed"
	fi
fi

echo
if [[ $FAILED -eq 1 ]]; then
	echo "setup: something failed above; fix it and re-run (every step is safe to repeat)"
	exit 1
fi
if [[ ${#TODO[@]} -gt 0 ]]; then
	echo "setup: nearly there —"
	for item in "${TODO[@]}"; do echo "  - $item"; done
fi
echo "setup: then, in Claude Code, /new-godot-project MyGame scaffolds a project under $PROJECTS that starts green."
