---
id: KOMBU-36
title: new-project.sh copies untracked runtime files into a new project
status: ready
priority: 3
owner: 
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

## Left for later
