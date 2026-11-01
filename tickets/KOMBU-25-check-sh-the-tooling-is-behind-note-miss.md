---
id: KOMBU-25
title: check.sh: the 'tooling is behind' note misses a worktree source
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tools/check.sh, tools/selftest.sh, CLAUDE.md]
batch: KOMBU-B3
created: 2026-10-31
updated: 2026-11-01
---

Make the "tooling is N Kombucha commit(s) behind" note in `tools/check.sh` work when the project was synced from a Kombucha git worktree.

`tools/check.sh` line 292 (on c41c217) tests `[[ -d "$TOOLING_SRC/.git" ]]`. In a git worktree, `.git` is a file, not a folder. So when `TOOLING_SRC` (the second line of the project's `tools/TOOLING_VERSION`) is a worktree, check.sh takes the plugin branch. It then compares against the installed plugin's sha, not the worktree's history. KOMBU-24 fixed the same test in `tools/sync-tooling.sh` with `has_git() { [[ -e "$1/.git" ]]; }`. Do not use `git rev-parse` here, because an installed plugin inside another repo would pass it.

When a worktree is removed after the sync, `TOOLING_SRC` no longer exists, and check.sh already falls back to the plugin. That case is fine.

Prove it in `tools/selftest.sh`: sync a scratch project from a worktree that is one owned commit ahead of the stamp, and check that check.sh prints the "behind" note. Watch the check fail before the fix.

## Progress
- 2026-10-31 23:37 PM: this ticket also carries one CLAUDE.md line, because KOMBU-23 and KOMBU-24 added self-test steps. In "Kombucha-only checks", change "It also proves the sync script: it stamps, seeds, sets the execute bit, reports drift and refuses a dirty source." to "It also proves the sync script: it stamps, seeds, sets the execute bit, reports drift, regenerates the project map, and refuses a dirty source, from a clone or from a git worktree."
- 2026-11-01 00:20 check.sh now tests -e .git (clone or worktree). Selftest step 3d added. Red-proof: the same steps on the unfixed check.sh printed no note (RED); after the fix, 'note: tooling is 1 Kombucha commit(s) behind' (GREEN). CLAUDE.md line updated as the PM gave it, plus one sentence on the check.sh note. Commit on kombu-b3; running the gate.
- 2026-11-01 00:26 Gate green on 484da14 (rebased), including selftest step 3d. Handing B3 to kombucha-pm.
- 2026-11-01 00:26 done on main at 484da14

## Ready to play
What changed: a project synced from a Kombucha git worktree now gets the "tooling is N Kombucha commit(s) behind" note from `check.sh`. Before, it got no note.

What the runs showed: self-test step 3d was red on the old `check.sh` and is green now. `tools/check.sh --ci` is green.

Questions for a person:
- None. This is tooling only.

## Left for later
- Nothing left over.
