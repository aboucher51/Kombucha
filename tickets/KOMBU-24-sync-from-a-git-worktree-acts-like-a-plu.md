---
id: KOMBU-24
title: Sync from a git worktree acts like a plugin install
status: ready
priority: 2
owner: 
depends_on: []
touches: [tools/sync-tooling.sh, tools/selftest.sh, CLAUDE.md]
created: 2026-10-31
updated: 2026-10-31
---

Make `tools/sync-tooling.sh` treat a Kombucha git worktree as a git checkout. Today it treats one as an installed plugin with no history.

What happened: during KOMBU-B2 and KOMBU-23, I synced a scratch Mapledot clone from a Kombucha worktree. Both times the sync printed `sync-tooling: stamped plugin-0.2.2`, not the worktree's commit.

Why: the script tests `[[ -d "$SRC/.git" ]]` in five places (lines 66, 122, 138, 155 and 255 on 03e4258). In a git worktree, `.git` is a file, not a folder. So a sync from a worktree:
- stamps `plugin-<version>`, not the commit (`source_commit`)
- skips the refusal of a source with uncommitted owned changes (line 138), so it can stamp files that match no commit
- skips the drift report's history and the "pulled N Kombucha commit(s)" list

Workers run in worktrees (the ticket brief says so), and the synced-project check runs the sync from one. So this hits every worker's sync.

What to do:
- Test for a git checkout with `git -C "$SRC" rev-parse --is-inside-work-tree`, or with `-e` in place of `-d`, in all five places.
- Prove it in `tools/selftest.sh`: sync from a worktree of the scratch source, and check that the stamp is the worktree's HEAD and that a dirty worktree is refused. Watch the new check fail before the fix.

## Progress
- 2026-10-31 23:25 PM: also add the map step (KOMBU-23, self-test step 3a) to CLAUDE.md's "Kombucha-only checks" paragraph, which lists what the self-test proves. Added CLAUDE.md to touches.

## Left for later
