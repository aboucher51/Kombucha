#!/usr/bin/env bash
# Produces runnable builds: Linux and Windows, release, PCK embedded.
#
#   tools/export.sh              both presets + a smoke test of the Linux one
#   tools/export.sh --no-smoke   both presets, no smoke (nothing to run it on)
#
# The binary name comes from config/name in project.godot, so a scaffolded
# project exports under its own name with no edits here.
#
# Export templates are per-Godot-version, ~1 GB, and not in the repo; this
# fetches the two release binaries it needs on first run. Exit 124 from the
# smoke run means the build survived the full duration — the same convention
# as the editor smoke test in CLAUDE.md.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

GODOT_VERSION="4.7"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
TEMPLATE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"

NAME="$(grep -m1 '^config/name=' project.godot | sed 's/^config\/name="\(.*\)"$/\1/' | tr '[:upper:] ' '[:lower:]_')"
[[ -z "$NAME" ]] && NAME="game"

ensure_templates() {
	if [[ -f "$TEMPLATE_DIR/linux_release.x86_64" && -f "$TEMPLATE_DIR/windows_release_x86_64.exe" ]]; then
		return 0
	fi
	echo "── fetching export templates ($GODOT_VERSION) ──"
	local tpz
	tpz="$(mktemp --suffix=.tpz)"
	curl -fL --retry 3 -o "$tpz" "$TEMPLATE_URL" || { echo "template download failed"; return 1; }
	mkdir -p "$TEMPLATE_DIR"
	# A .tpz is a zip with everything under templates/; take only what the
	# two presets need rather than unpacking a gigabyte of platforms.
	# python3 rather than unzip, which WSL does not ship by default.
	python3 - "$tpz" "$TEMPLATE_DIR" <<-'PY' || { rm -f "$tpz"; return 1; }
		import os, sys, zipfile
		tpz, dest = sys.argv[1], sys.argv[2]
		wanted = [
		    "templates/linux_release.x86_64",
		    "templates/windows_release_x86_64.exe",
		    "templates/windows_release_x86_64_console.exe",
		]
		with zipfile.ZipFile(tpz) as z:
		    for name in wanted:
		        out = os.path.join(dest, os.path.basename(name))
		        with open(out, "wb") as f:
		            f.write(z.read(name))
		        os.chmod(out, 0o755)
	PY
	rm -f "$tpz"
}

ensure_templates || exit 1

echo "── import (translations, class registry) ──"
godot4 --headless --path . --import > /dev/null 2>&1

FAILED=()
export_preset() { # preset name, output path
	echo "── export: $1 ──"
	mkdir -p "$(dirname "$2")"
	local log
	log="$(mktemp)"
	if godot4 --headless --path . --export-release "$1" "$2" > "$log" 2>&1 && [[ -f "$2" ]]; then
		echo "  ok    $2 ($(du -h "$2" | cut -f1))"
	else
		echo "  FAIL  $1"
		tail -5 "$log" | sed 's/^/        /'
		FAILED+=("$1")
	fi
	rm -f "$log"
}

export_preset "Linux" "builds/linux/${NAME}.x86_64"
export_preset "Windows Desktop" "builds/windows/${NAME}.exe"
chmod +x "builds/linux/${NAME}.x86_64" 2>/dev/null

if [[ "${1:-}" != "--no-smoke" && ${#FAILED[@]} -eq 0 ]]; then
	echo "── smoke: the exported binary itself ──"
	timeout 8 "./builds/linux/${NAME}.x86_64" --headless > /tmp/export-smoke.log 2>&1
	STATUS=$?
	ERRORS=$(grep -ci "ERROR" /tmp/export-smoke.log || true)
	if [[ $STATUS -eq 124 && "$ERRORS" -eq 0 ]]; then
		echo "  ok    ran full duration, 0 engine errors"
	else
		echo "  FAIL  exit=$STATUS engine errors=$ERRORS (/tmp/export-smoke.log)"
		FAILED+=("smoke")
	fi
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
	echo "export: FAILED — ${FAILED[*]}"
	exit 1
fi
echo "export: all green"
