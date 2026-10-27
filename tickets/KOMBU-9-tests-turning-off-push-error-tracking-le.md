---
id: KOMBU-9
title: Tests: turning off push_error tracking leaks into every later test in the shard
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [tests/test_function_registry.gd, tests/test_screenshot_harness.gd, docs/godot-tooling.md]
created: 2026-10-26
updated: 2026-10-27
---

Found while working KOMBU-8 (2026-10-26).

`gut.error_tracker` is one object for the whole GUT process (GutUtils.get_error_tracker()). A test that sets `gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING` leaves it set. Every test that runs after it in the same process can then push_error without failing.

Seen: a planted test that calls push_error("...") fails when run alone (`tools/test.sh test_zz_b`). In the full sharded suite it passed, because test_function_registry.gd:35 or test_screenshot_harness.gd:216 ran earlier in its shard. Which tests lose the guard depends on how the shards are dealt.

docs/godot-tooling.md ("Tests") tells every project to use exactly this line for a test whose logged error is the behaviour under test, so synced projects probably have the same leak.

What to do:
- In the two fixture tests, put the setting back after the test (after_each, or right after the expected error), or find GUT's own per-test way to expect an error.
- Change the docs line so it says to restore the setting, and why: without that, a test that sets it turns off error checking for the rest of its shard.
- Prove it: a test that push_errors, dealt after one of these tests in the same process, must go red.

## Progress
- 2026-10-26 23:29 Proved the leak: planted push_error test is red alone, green after test_function_registry or test_screenshot_harness in one process. Fix: both sites use assert_push_error(text) instead (scoped to one test, fails if the error never comes); planted test now red after each. Docs paragraph rewritten to say this. Branch kombu-9-error-tracker on top of kombu-7-8-runners; full check next.
- 2026-10-26 23:37 Full check --ci green on eecbba4 (139 tests, 20 scenarios, 0 engine errors), origin/main d125fc5. Filed KOMBU-10 (test.sh guard for synced projects). Waiting for Alex's yes; KOMBU-7/8's push is still blocked by the permission check.
- 2026-10-27 18:06 2026-10-27: Alex's standing yes relayed by kombucha-pm; origin still d125fc5, but git push of kombu-11-xvfb-size was blocked again by this session's permission check. Not pushed; stopped as the PM asked.
- 2026-10-27 18:07 PM pushed kombu-11-xvfb-size (8c5c5b3) to main from kombucha-pm on Alex's direct go-ahead 2026-10-27 (the worker's session blocks git push).
- 2026-10-27 18:08 Landed on origin/main in d125fc5..8c5c5b3 (pushed by kombucha-pm on Alex's go-ahead).
- 2026-10-27 18:08 done on main at c2660d1

## Left for later
