---
id: KOMBU-35
title: class-cache.sh re-imports on every run when an add-on registers a non-GDScript class
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [tools/class-cache.sh, tools/selftest.sh]
created: 2026-11-04
updated: 2026-11-04
---

Make `tools/class-cache.sh` compare only GDScript classes, so an add-on's other script languages stop forcing an import on every run.

What happened (navalwar-worker, NAVAL-335 and NAVAL-385, 2026-11-04): NavalWar vendors Godot Sandbox. The add-on registers `addons/godot_sandbox/gdscript.elf` in `.godot/global_script_class_cache.cfg` as class `Sandbox_AddonsGodotSandboxGdscript`, with `"language": &"ELF"`. SafeGDScript files (`.sgd`) get the same treatment, with `"language": &"SafeGD"` and a class named `SafeGDScript_<Path>`. The script's cache reader lists every entry, while its disk reader lists only `class_name` lines in `.gd` files. So the two lists never match. Every `test.sh`, `check.sh`, `shoot.sh` and `serve.sh start` run does a full import, then prints "class cache still differs after the import". Nothing goes red, but each run pays for the import.

What to do:
- In the cache reader, keep only entries whose `"language"` is `&"GDScript"`. Read each entry as a whole, not as alternating class and path lines, so a `language` field in any position is safe.
- Prove it in `tools/selftest.sh`: plant a cache entry with another language, and check that the script reports a match and does not import. Watch the step go red before the fix.

The gate is `tools/check.sh --ci`, green. When this lands, the PM tells navalwar-pm.

## Progress
- 2026-11-04 08:14 class-cache.sh reads each cache entry whole and keeps GDScript only (gawk/mawk/busybox ok). Selftest step 2j plants ELF + SafeGD entries; red on the old script, green on the new. Running the gate.
- 2026-11-04 08:44 Gate tools/check.sh --ci green (selftest 2j ok, 21 scenarios). Commit 41ab702 on branch kombu-35, worktree ../Kombucha-kombu-35, origin/main unmoved. Handed to kombucha-pm. No play pass: nothing a player or scenario author sees changed.
- 2026-11-04 08:44 done on main at 41ab702

## Left for later
