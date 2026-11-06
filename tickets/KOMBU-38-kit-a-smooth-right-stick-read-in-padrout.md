---
id: KOMBU-38
title: Kit: a smooth right-stick read in PadRouter and Pads (from Dwarf Mountain)
status: ready
priority: 3
owner: 
depends_on: []
touches: [scripts/util/pad_router.gd, scripts/autoloads/pads.gd, tests/, scripts/dev/dev_hooks.gd, scripts/main.gd]
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

## Left for later
