---
id: KOMBU-37
title: Harness: click scrolls only the nearest ScrollContainer, not the ones around it
status: ready
priority: 2
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scenes/, scripts/main.gd, scenarios/, .godot-map/graph.json, PROJECT_MAP.md]
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

## Left for later
