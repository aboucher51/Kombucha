#!/usr/bin/env bash
# Scaffolds a new Godot project from THIS repo. The fixture here is the
# smallest project the tooling needs in order to exercise itself, which is
# also the smallest project a game starts from: the kit (autoloads, UI
# theme, save system, keybinds, pads), the tooling, and the contract.
#
#   tools/new-project.sh ../MyGame "My Game"
#   tools/new-project.sh ../MyGame "My Game" --no-check   (self-test: no
#                                              import, map or check run)
#
# It copies only the files git tracks, so a live session's runtime files
# (like .claude/scheduled_tasks.lock) stay behind.
# What else stays behind: the plugin and skills, the tooling's own tests and
# scenarios, the self-test, the research docs and roadmap, Kombucha's
# ticket board (the new project's PM runs tk init with its own key, and
# only Alex sets its PUSH_POLICY), and the
# sections of CLAUDE.md and LICENSES.md fenced by
# <!-- kombucha-only --> ... <!-- /kombucha-only -->, so the conventions
# have ONE source and the new project reads as its own. The copy is then
# synced from this repo (seeds the three extension files, stamps
# tools/TOOLING_VERSION), named, git-initialised, imported, mapped and
# checked, so it starts green with one commit.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEST="${1:-}"
NAME="${2:-}"
CHECK=1
for arg in "${@:3}"; do
	case "$arg" in
		--no-check) CHECK=0 ;;
		*) echo "usage: tools/new-project.sh <destination-dir> <\"Project Name\"> [--no-check]" >&2; exit 2 ;;
	esac
done
if [[ -z "$DEST" || -z "$NAME" ]]; then
	echo "usage: tools/new-project.sh <destination-dir> <\"Project Name\"> [--no-check]" >&2
	exit 2
fi
if [[ -e "$DEST" ]]; then
	echo "new-project: '$DEST' already exists" >&2
	exit 2
fi

# Paths that are Kombucha's, not a project's. Anchored at the repo root.
EXCLUDES="$(mktemp)"
cat > "$EXCLUDES" <<'EOF'
/.git
/.godot
/shots/*.png
/builds
/claude-log.md
/PROJECT_MAP.md
/.godot-map
/.claude-plugin
/skills
/LICENSE
/README.md
/docs/research
/docs/plans
/docs/roadmap.md
/docs/feedback
/tickets
/tools/selftest.sh
/tools/TOOLING_VERSION
/scripts/dev/selftest_driver.gd
/scripts/dev/selftest_driver.gd.uid
/scenes/second.tscn
/scenes/nested_scroll.tscn
/scripts/nested_scroll.gd
/scripts/nested_scroll.gd.uid
/scenes/harness_inputs.tscn
/scripts/harness_inputs.gd
/scripts/harness_inputs.gd.uid
/tests/test_cmdline.gd
/tests/test_cmdline.gd.uid
/tests/test_console_state.gd
/tests/test_console_state.gd.uid
/tests/test_dev_hooks.gd
/tests/test_dev_hooks.gd.uid
/tests/test_json_lines.gd
/tests/test_json_lines.gd.uid
/tests/test_screenshot_harness.gd
/tests/test_screenshot_harness.gd.uid
/scenarios/baseline.txt
/scenarios/baselines
/scenarios/click_nested_scroll.txt
/scenarios/menu.txt
/scenarios/drag_drop.txt
/scenarios/frame_budget.txt
/scenarios/console_ui.txt
/scenarios/hooks.txt
/scenarios/leave_boot.txt
/scenarios/onscreen.txt
/scenarios/pseudo_locale.txt
/scenarios/scroll.txt
/scenarios/right_stick.txt
/scenarios/settle.txt
/scenarios/state.txt
/scenarios/tooltip.txt
/scripts/dev/dev_hooks.gd
/scripts/dev/dev_hooks.gd.uid
/data/console_commands.project.json
/tools/check.local.sh
/tools/check.local.env
EOF

mkdir -p "$DEST"
if [[ "$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" == "$ROOT" ]]; then
	# A git checkout: copy only the files git tracks, minus the excludes.
	# A live session leaves runtime files in the checkout that git does
	# not track. One scaffold carried the PM session's
	# .claude/scheduled_tasks.lock (its id and pid) into the new
	# project's first commit. A tracked file deleted from the working
	# tree is skipped. An edited one is copied as it is on disk.
	(cd "$ROOT" && git ls-files -z | python3 -c '
import fnmatch, os, sys
pats = [p.strip().lstrip("/") for p in open(sys.argv[1]) if p.strip()]
def left_out(path):
    return any(path == p or path.startswith(p + "/") or fnmatch.fnmatchcase(path, p) for p in pats)
names = [n for n in sys.stdin.buffer.read().decode().split("\0") if n]
sys.stdout.write("".join(n + "\0" for n in names if not left_out(n) and os.path.lexists(n)))
' "$EXCLUDES" | tar --null --no-recursion -T - -cf -) | (cd "$DEST" && tar -xf -)
else
	# No git (a copy without history): copy the whole tree minus the
	# excludes, with rsync if present, else tar. This path still lets
	# through any runtime file the excludes do not name, like a
	# session's .claude/*.lock. Delete such files from the new project
	# by hand.
	if command -v rsync >/dev/null; then
		rsync -a --exclude-from="$EXCLUDES" "$ROOT/" "$DEST/"
	else
		(cd "$ROOT" && tar --exclude-from=<(sed 's|^/||' "$EXCLUDES") -cf - .) | (cd "$DEST" && tar -xf -)
	fi
fi
rm -f "$EXCLUDES"

# /builds is excluded whole (old exports), but its .gdignore belongs to
# every project: the editor must never import an export.
mkdir -p "$DEST/builds" && : > "$DEST/builds/.gdignore"

# The project's own README, and the fenced Kombucha-only sections gone.
cp "$ROOT/tools/seeds/README.project.md" "$DEST/README.md"
python3 - "$DEST/CLAUDE.md" "$DEST/LICENSES.md" <<'PY'
import re, sys
for path in sys.argv[1:]:
    text = open(path).read()
    text = re.sub(r"<!-- kombucha-only -->.*?<!-- /kombucha-only -->\n?", "", text, flags=re.S)
    text = re.sub(r"\n{3,}", "\n\n", text)
    open(path, "w").write(text)
PY

sed -i "s|^config/name=.*|config/name=\"$NAME\"|" "$DEST/project.godot"
# The fixture's self-test driver is an autoload here; a project has no
# script for it.
sed -i '/^SelftestDriver=/d' "$DEST/project.godot"

# Seeds the extension files, stamps the tooling version. The copy is
# already this repo's, so nothing else changes.
"$ROOT/tools/sync-tooling.sh" "$DEST" --no-check | grep -E 'seeded|stamped'

cd "$DEST"
git init -q -b main
# Nothing may be configured globally on this machine, so a fresh repo has
# no author identity and the scaffold commit below would fail — inherit
# the source repo's when it has one.
if ! git config user.email >/dev/null; then
	git config user.name "$(git -C "$ROOT" config user.name 2>/dev/null || echo scaffold)"
	git config user.email "$(git -C "$ROOT" config user.email 2>/dev/null || echo scaffold@example.invalid)"
fi
if [[ $CHECK -eq 1 ]]; then
	"${GODOT:-godot4}" --headless --path . --import >/dev/null 2>&1 || true
	# The copied project map describes THIS repo; for the new project it
	# is stale, and check.sh fails on a stale map when the tool is here.
	# Regenerate it, or drop it so the check says "no map yet".
	if command -v godot-map >/dev/null 2>&1; then
		godot-map . >/dev/null
	else
		rm -rf PROJECT_MAP.md .godot-map
	fi
	tools/check.sh --quick
else
	rm -rf PROJECT_MAP.md .godot-map
fi
git add -A
git commit -qm "Scaffold from Kombucha $(head -c 12 tools/TOOLING_VERSION)"

echo "new-project: '$NAME' ready at $DEST"
