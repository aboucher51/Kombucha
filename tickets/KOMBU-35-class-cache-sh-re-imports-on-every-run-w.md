---
id: KOMBU-35
title: class-cache.sh re-imports on every run when an add-on registers a non-GDScript class
status: ready
priority: 2
owner: 
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

## Left for later
