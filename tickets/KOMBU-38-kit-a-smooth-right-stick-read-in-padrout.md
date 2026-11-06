---
id: KOMBU-38
title: Kit: a smooth right-stick read in PadRouter and Pads (from Dwarf Mountain)
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scripts/util/pad_router.gd, scripts/autoloads/pads.gd, tests/, scripts/dev/dev_hooks.gd, scripts/main.gd, data/console_commands.project.json, scenarios/, tools/new-project.sh, CLAUDE.md, .godot-map/graph.json, PROJECT_MAP.md]
created: 2026-11-06
updated: 2026-11-06
---

Bring Dwarf Mountain's smooth right-stick read into the kit, so any project with a scrolling view can pan it with a pad.

What it is (dwarf-mountain-pm, DWARF-94, 2026-11-06): Dwarf Mountain added it in two kit files, at dwarf-mountain origin/main ba65d72 (~/godot-projects/dwarf-mountain):
- `PadRouter.stick(raw)` in `scripts/util/pad_router.gd` gives zero inside the deadzone, then grows from 0 to 1 between the deadzone's edge and the rim.
- `Pads.right_stick()` in `scripts/autoloads/pads.gd` sums the right stick of every allowed pad. It adds `stick_override`, a seam for tests, and gives zero while `Keybinds.capturing` is true (a rebind is listening).
The mountain adds it to its camera pan, so a pad pans the view without a third `Keybinds` slot. Their test is `test_a_stick_read_is_zero_in_the_deadzone_and_grows_to_one_at_the_rim`.

What to do:
- Copy only these two additions and their test from Dwarf Mountain. Diff each file against Kombucha's copy, and leave out anything that is Dwarf Mountain's own.
- Respect the pad gate: "allowed" must mean the same `pad_gate` rule that `Pads._allowed()` already uses.
- Make the fixture use it, because a kit API that nothing in `tests/` or `scenarios/` uses is untested tooling. At least: a unit test of the curve, a test that `right_stick()` reads zero while `Keybinds.capturing`, and a test of `stick_override`. If it fits, also give the fixture something small to read through it (with a `state` key a scenario can assert), placed off the boot screen.
- Add a line to the pad rules in CLAUDE.md's "Input is action-based" section only if one is needed. Load `writing-instructions` first.

The gate is `tools/check.sh --ci`, green. These are kit files, so projects copy them by hand. When this lands, the PM tells dwarf-mountain-pm.

## Progress
- 2026-11-06 09:22 Copied stick() and right_stick() + stick_override + DM's curve test. Added right_stick_of(devices) so a test can name pads Godot does not list as connected; right_stick() calls it with the connected pads. New tests/test_pads.gd: override, capture, sum, pad gate; red with the gate and capture checks taken out. Fixture: console 'stick x y' (dev_hooks + project json, sandbox resets it), main.gd state key right_stick, scenarios/right_stick.txt (scaffold leaves it out). Added to touches: console_commands.project.json, scenarios/, tools/new-project.sh, CLAUDE.md (one pad rule: read the right stick through Pads.right_stick), map files.
- 2026-11-06 09:25 tools/check.sh --ci green on forge. Branch kombu-38-right-stick, worktree ~/godot-projects/Kombucha-wt-38. Filed KOMBU-39. Handing to kombucha-pm.
- 2026-11-06 09:26 done on main at 27b2853

## Ready to play
- What changed: the kit has a smooth right-stick read. `Pads.right_stick()` gives 0 inside the deadzone, then grows to 1 at the rim. It skips pads the pad gate refuses, and it reads 0 while a rebind waits for a key.
- A scenario author can push the stick with the console line `stick <x> <y>` and read it back with `assert right_stick <x>,<y>` (two places, like `0.50,-0.25`). The harness's sandbox lets go of the stick between scenarios.
- `scenarios/right_stick.txt` passed. It draws nothing new, so there is no shot to look at. `tests/test_pads.gd` failed with the gate check and the capture check taken out, and passed with them back.
- Questions for a person:
  1. With a real controller on the desktop, does the curve feel gentle enough near the deadzone in Dwarf Mountain's pan?
  2. Should the left stick get the same smooth read some day, for a game that moves a cursor freely?

## Left for later
- [[KOMBU-39]] the pad gate check skips a gate node on its way out
