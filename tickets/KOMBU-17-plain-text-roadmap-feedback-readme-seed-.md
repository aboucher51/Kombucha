---
id: KOMBU-17
title: Plain text: roadmap, feedback README, seed comments
status: claimed
priority: 3
owner: kombucha-worker
pid: 2496951
depends_on: []
touches: [.godot-map/graph.json, docs/roadmap.md, docs/feedback/README.md, tools/seeds/check.local.sh, tools/seeds/check.local.env, tools/seeds/dev_hooks.gd, tools/seeds/dev_driver.gd]
created: 2026-10-31
updated: 2026-10-31
---

Rewrite the living parts of three docs in plain active sentences. This is part of TextCleaner's cleanup of how Claude writes, which Alex approved on 2026-10-29.

Files:
- `docs/roadmap.md`: rewrite the open work (the numbered "what is left" list and the "Next" lines). Leave each "Landed <date>" section as it is, because those sections are a record.
- `docs/feedback/README.md`: rewrite all of it. Projects read it to write a feedback report.
- `tools/seeds/check.local.sh`, `tools/seeds/check.local.env`, `tools/seeds/dev_hooks.gd`, `tools/seeds/dev_driver.gd`: rewrite the comments only. A new project starts from these files, so their comments teach every project. Do not change code. `tools/seeds/README.project.md` is already done (f2d6ff3).

Do not touch `docs/plans/`, `docs/research/`, `docs/feedback/<project>/` or `claude-log.md`. They are records. CLAUDE.md, README.md, `docs/godot-tooling.md` and the skills under `skills/` are already done.

Load `writing-instructions` for all of these files.

## How to do it
- Read `~/.claude/rig/text-cleanup-brief.md` first. Follow its "Rules that review taught us" section.
- Before you write each kind of text, load the skill the brief's table names.
- Before you edit a file, list every number, name, path, key and test name in it. After the edit, check that each one is still there.
- Before you change a string, grep `scripts/`, `tests/`, `scenarios/` and `tools/` for it. If a test or scenario asserts the string, update that check so it tests the same thing. If a script parses the string, leave it alone.
- Keep each file within 10% of its old word count.
- Check every changed file with `python3 ~/.claude/skills/writing-plain-core/scripts/readability.py -f FILE --max 25`. Write the passive counts before and after into a ticket note, so the PM can send them to TextCleaner.
- Note any line where you were unsure who acts or what a line means. Leave such a line as it was.
- The gate is `tools/check.sh --ci`, green.

## Progress
- 2026-10-31 21:35 claimed; worktree ../Kombucha-wt-kombu17 on branch kombu-17-text
- 2026-10-31 21:37 edits done and committed. Passive before->after (readability.py): roadmap.md 12->9 (the Landed sections are unchanged), feedback/README.md 1->1, check.local.sh 2->0, check.local.env 0->0, dev_hooks.gd 2->0, dev_driver.gd 2->0. Words: roadmap 1589->1637, README 448->470, check.local.sh 385->392, check.local.env 83->91, dev_hooks 662->711, dev_driver 268->273.
- 2026-10-31 21:42 first gate red on one item: project map stale. The map stores each script's line count, and the seed comments changed two seeds' lengths. Added .godot-map/graph.json to touches and regenerated it.

## Left for later
- [[KOMBU-22]] the roadmap's Next list has out-of-date facts (item 2 landed, Template retired)
