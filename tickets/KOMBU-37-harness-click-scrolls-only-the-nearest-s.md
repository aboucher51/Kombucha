---
id: KOMBU-37
title: Harness: click scrolls only the nearest ScrollContainer, not the ones around it
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scenes/, scripts/main.gd, scripts/nested_scroll.gd, scenarios/, docs/godot-tooling.md, tools/new-project.sh, .godot-map/graph.json, PROJECT_MAP.md]
created: 2026-11-06
updated: 2026-11-06
---

Make the harness's `click` and `hover` (and `scroll_to`) bring a control into view through every ScrollContainer around it, not only the nearest one.

What happened (tandem-pm, TAND-189, 2026-11-06): `_scroll_into_view` in `scripts/dev/screenshot_harness.gd` calls `ensure_control_visible` on the nearest ScrollContainer only. Tandem's editor has a list (`PoolList`) inside another scroll area (`PropertiesScroll`). `click` scrolled the inner list and left the outer one where it was. So the click landed on whatever control sat at that spot, not the target. Tandem works around it today in its `scripts/dev/dev_hooks.gd` `_reveal`, which walks every ScrollContainer from the outermost in. Read that as the reference.

What to do:
- Walk every ScrollContainer between the target and the root, from the outermost in. Make each one show the target (or the next inner ScrollContainer), so the target ends up inside the viewport. Wait for the layout to settle between steps if the code needs it.
- Make the fixture show the bug first. Add a nested pair (a ScrollContainer inside another, with the target below both folds) off the boot screen (memory note boot-frame-is-a-baseline), and a scenario that clicks the target and asserts the click reached it. Watch the scenario go red before the fix.
- Keep the existing single-ScrollContainer behaviour and its scenario green.

The gate is `tools/check.sh --ci`, green. When this lands, the PM tells tandem-pm, so Tandem can sync and drop `_reveal`.

## Progress
- 2026-11-06 08:58 Added scripts/nested_scroll.gd (the fixture scene's script, off the boot screen, reached by goto) and docs/godot-tooling.md (the harness rule) to touches. New scenario click_nested_scroll.txt went red before the fix (click ok, nothing pressed). Fix: _scroll_into_view scrolls every holder nearest first. Outermost first (Tandem's _reveal order) also goes red on this fixture.
- 2026-11-06 08:59 Added tools/new-project.sh to touches: the scaffold must leave out the new fixture scene, its script and its scenario (the scenario uses goto, a fixture-only command), like second.tscn and leave_boot.txt.
- 2026-11-06 09:02 tools/check.sh --ci green on forge (commit b46496b, branch kombu-37-nested-scroll, worktree ~/godot-projects/Kombucha-wt-37). Handing to kombucha-pm to land.
- 2026-11-06 09:03 done on main at b46496b

## Ready to play
- What changed: the harness's `click`, `hover` and `scroll_to` now scroll every ScrollContainer around the target, nearest first. Before, only the nearest one scrolled.
- The fixture has a new scene, `scenes/nested_scroll.tscn`: a list inside a scrolling panel, with `DeepRow` below both folds. `scenarios/click_nested_scroll.txt` reaches it with `goto`, clicks `DeepRow`, then clicks `NestedRow01` back at the top. It asserts each click with the `nested_pick` state key.
- Before the fix, the scenario was red: `click DeepRow` answered ok and nothing was pressed. With the order reversed (outermost first, as Tandem's `_reveal` does), it was red as well.
- The shot `shots/click_nested_scroll-01-nested.png` shows both scroll bars moved and `NestedRow01` in view. Nothing is cut off. `scroll.txt` and `click_below_fold.txt` stay green.
- Questions for a person:
  1. Does Tandem's editor click land with this harness once Tandem syncs and drops `_reveal`?
  2. Tandem's `_reveal` scrolls outermost first, which failed on this fixture. Does Tandem's `pick_row` ever miss today?

## Left for later
