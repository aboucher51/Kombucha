---
id: KOMBU-36
title: new-project.sh copies untracked runtime files into a new project
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tools/new-project.sh, tools/selftest.sh]
created: 2026-11-06
updated: 2026-11-06
---

Make `tools/new-project.sh` copy only the files Kombucha tracks in git, so runtime files from a live session never reach a new project.

What happened (forgemaster, 2026-11-06): a scaffold from 97ce2f7 copied `.claude/scheduled_tasks.lock` into the new emblem-autobattler and committed it. That file is a runtime lock from the kombucha-pm Claude session (it held that session's id and pid). Kombucha does not track it. The script copies the working tree (with `rsync`, or `tar` when there is no `rsync`) and leaves out only its own exclude list. So any untracked file in the checkout lands in the new project. forgemaster removed it by hand before the first push.

What to do:
- When the source is a git checkout, build the copy from `git ls-files` (tracked files only), then apply the existing exclude list on top. Keep a working fallback when the source has no git history (the installed plugin), and say in a comment which files that fallback can still let through.
- Check that nothing the scaffold needs is untracked today (like `addons/gut` or the `shots/` and `builds/` `.gdignore` files). The self-test's new-project step must stay green.
- Prove it in `tools/selftest.sh`: plant an untracked file (like `.claude/test.lock`) in the scratch source, scaffold, and check that the file is not in the new project. Watch that step go red before the fix.

The gate is `tools/check.sh --ci`, green.

## Progress
- 2026-11-06 07:28 new-project.sh copies git ls-files minus excludes (rsync/tar fallback without git). Red-proof in scratch: old script copied a planted .claude/test.lock, new one did not; otherwise same files, contents and modes. Self-test step added.
- 2026-11-06 07:31 Gate green: tools/check.sh --ci (TEST_JOBS=16), self-test line 'the scaffold leaves out a file git does not track' ok, scaffold's own tests 107 pass. Branch kombu-36 rebased on origin/main; handed to kombucha-pm.
- 2026-11-06 07:32 done on main at e761519

## Left for later
