---
id: KOMBU-40
title: test_pads.gd leaves 2 unfreed children (GUT warning)
status: ready
priority: 3
owner: 
depends_on: []
touches: [tests/test_pads.gd]
created: 2026-11-06
updated: 2026-11-06
---

Make `tests/test_pads.gd` free the nodes it adds, so GUT stops warning "Test script has 2 unfreed children".

What happened (dwarf-mountain-pm, DWARF-96, 2026-11-06): at 276c21e, the two pad-gate tests add an `OnlyPad` node with `add_child()` and free it with `queue_free()`. GUT still sees the node when the script ends, so it warns. The run stays green.

What to do:
- Use `add_child_autofree()`, or await one frame after `queue_free()`. Keep what each test proves. The KOMBU-39 test needs the gate to still be in its group while it is queued for deletion, so check that test still fails without the KOMBU-39 fix.
- Check that the warning is gone from the test log.
- If GUT's unfreed-children warning appears anywhere else in the suite's log, note it in this ticket.

The gate is `tools/check.sh --ci`, green. When this lands, the PM tells dwarf-mountain-pm.

## Progress

## Left for later
