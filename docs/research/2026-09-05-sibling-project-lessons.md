# Lessons from the sibling projects' test tooling

Survey date: 2026-09-05. Companion to `2026-09-05-prior-art.md`. Nine
projects scaffolded from the Template were skimmed for how their test
runner, check script, screenshot harness, sandbox and CLAUDE.md test
sections diverged from the Template, and what each divergence paid for.

Projects: BossFights, Digit, FrogGame, Monmon, NavalWar, Orbit, Tandem,
Zoofle, procedural-factory. (AshenFlag predates the tooling;
card-game-prototype is empty.)

Suite sizes for scale: NavalWar 86 test files / 61 scenarios, FrogGame 52 /
36, Monmon 52 / 25, Orbit 29 / 37, BossFights 27 / 11.

The strongest signal is a lesson **several projects learned separately**.
Those are listed first; they are Template bugs, not project quirks.

## Tier 1: found independently by two or more projects

1. **A test script that fails to parse is silently dropped and GUT still
   exits 0.** Zoofle, procedural-factory, FrogGame and NavalWar each hit
   this and each wrote a guard: grep the log for `Failed to load script`
   and fail the run. Zoofle's note: "the only tell is the total test count
   falling", and it hid a duplicate-function error behind an all-green
   check. The Template's `test.sh` has no such guard. Highest priority.

2. **The shoot timeout pinned in `check.sh` breaks as the suite grows.**
   The Template's `shoot.sh` scales its own default (30 s + 10 s per
   scenario) but `check.sh` overrides it with a fixed 300. Orbit raised it
   to 540; NavalWar deleted the pin after "it started failing the batch the
   day it grew past ~45 scenarios". Delete the pin in the Template.

3. **Settings that live in the redirected config file survive between
   scenarios.** `_sandbox()` wipes the save root but not the settings
   file, so anything persisted there (campaign progress, the editor's
   last-opened mod, zoom) leaks forward. NavalWar and Monmon both grew long
   explicit reset lists with the same rule: reset *after* the redirect,
   never before, or the player's real progress is wiped. Worth a sentence
   in the Template's harness section and a comment at the top of
   `_sandbox()`.

4. **Ambient real-time systems ambush scenarios.** Zoofle: a scenario must
   `rain off` first or a stray drop lands mid-setup ("cost a debugging pass
   on day one"). Monmon: roaming mons and watching trainers hijack
   scenarios intermittently, so `roam_clear` and `watch off` exist and
   `_sandbox()` turns them back on. Generic rule for the Template: every
   system driven by real time needs an off switch reachable from the
   console, and the sandbox restores it.

5. **`set_anchors_preset()` on a Control already in the tree leaves it
   0×0.** Orbit and Digit found this separately, both only via a
   screenshot. Use `set_anchors_and_offsets_preset()` or anchor before
   `add_child()`. Not a test-tool lesson, but it is exactly the class of
   bug the harness exists for and belongs in the Template's CLAUDE.md.

## Tier 2: single project, directly generalisable

### Runner and check script

6. **Sharded test runs** (FrogGame, refined; NavalWar, simpler). Each shard
   is its own Godot process with its own `XDG_DATA_HOME` so `user://`
   writes cannot collide; a per-shard gutconfig with `dirs: []` (GUT *adds*
   `-gtest` entries to whatever the config names) and a `tests` list;
   shards write JUnit XML (`junit_xml_file`), per-script times are merged
   into `.godot/test-timings`, and the next run deals longest-first. An
   empty shard is shrunk away because GUT exits 1 on a config with no
   tests. The summary is re-aggregated into the same greppable shape.
   Measured about 2× on NavalWar. Side benefit stated by FrogGame:
   sharding *exposes* cross-test leaks (one script relied on an earlier
   one having told GUT to tolerate a `push_error`).

7. **`GODOT` env override and the WSL bridge cost** (FrogGame). Booting
   the project costs about 11 s through `/mnt/c` and 1.4 s natively, and
   every process pays it. Running the same suites from Git Bash with the
   Windows binary took `check.sh` from 4m10s to 1m45s. All three scripts
   take `GODOT="${GODOT:-godot4}"`. A missing `/usr/bin/time` skips the
   memory budget instead of failing the boot.

8. **A lock on `check.sh`** (NavalWar). The harness sandbox is a fixed
   path, so two concurrent runs share a save slot and fail each other in a
   way that "looks exactly like a real regression". `mkdir` lock, exit 2.

9. **`--ci` mode and a `ci.yml` on push/PR** (BossFights). Everything
   headless (tests, boot, sims, multi-process nettest) runs on every push
   with the Godot binary cached; scenarios stay local. The Template only
   has `export.yml` on tags.

10. **`SOAK=1` endurance battery** (BossFights). Many sequential
    encounters in one process under a memory ceiling, meant for nightly
    rather than every push. The reset loop is where leaks hide.

11. **Grep `shader` alongside `SCRIPT ERROR|Parse Error`** in boot and
    shoot logs (FrogGame). Shader compile errors are not script errors.

12. **Print each scenario's elapsed seconds on pass** (FrogGame). "36
    scenarios in one process; the expensive ones are visible without a
    profiler." Scenarios are the slow half of check (85 s vs 20 s there).

### Harness commands

13. **`settle [seconds]`** (FrogGame). Waits until nothing in the
    `skirmish` group reports `is_busy()`, or the deadline passes.
    "Deterministic where a `sleep` after a move was a guess." This is the
    `wait_until` primitive the prior-art survey recommended, already built.
    Generalise to a group name argument.

14. **Game-time vs wall-clock waits.** Three projects disagree, which is
    the insight. Orbit rewrote `sleep` to count physics ticks because
    under llvmpipe physics falls behind wall time and exact-timed
    choreography under-waited "at batch load, passed alone". FrogGame kept
    `sleep` wall-clock on purpose for Timer-driven things. Digit documents
    that `wait N` is frames and real-time gameplay cannot be waited for,
    so scenarios drive state through console commands. The Template should
    ship both (`sleep` wall-clock, `ticks N` physics frames) and say which
    to use for what.

15. **`frame_budget <ms> [frames]`** (Monmon). Turns vsync and the FPS cap
    off (with vsync on every scene measures 16.7 ms and the gate can never
    fail), warms up 10 frames, measures average and worst, fails over
    budget, and prints the number even on pass so the trend is legible.
    Documented as "a regression tripwire, not a device target" because
    the suite runs on software rasterisation under WSL.

16. **Ambiguous names are an error, not a coin toss** (Monmon).
    `assert_onscreen` used to answer about whichever same-named node
    loaded first. It now finds all matches and refuses if more than one.
    Also extended to Node3D via camera unproject of the AABB centre (a
    mesh's origin is not where its geometry is).

17. **`scroll_to <NodeName>`** (Orbit). A row below the fold of a
    ScrollContainer is visible but not clickable; `click` lands outside
    the viewport. Walks up to the ScrollContainer and calls
    `ensure_control_visible`.

18. **`hover_hint` / `assert_tooltip`** (procedural-factory). Warps the
    mouse to a tooltip-bearing point, verifies `gui_get_hovered_control`
    landed on the right control, waits out the dwell, asserts hint text.
    Hover was previously an untestable path.

### Game-state seams

19. **Every game grows `<prefix>_state` and `<prefix>_assert key value`.**
    NavalWar (`nw_state`, `nw_assert`), FrogGame (`fg_state`, `fg_assert`,
    including `pos:<name>` and `threat:<x>,<y>`), Monmon and others. The
    Template should ship a generic `state` / `assert <key> <value>` pair
    over a small registry seam the game fills in, instead of each project
    reinventing it. This is also the "state readback before pixels"
    recommendation from the prior-art survey.

20. **Scenarios must assert state after actions.** FrogGame: a click on
    an unreachable tile cancels back to the menu without an error, "and a
    scenario of silent cancels passes — the combat scenario did exactly
    that once." Goes in the Template's harness rules.

21. **World clicks for non-Control boards.** Harness `click` only reaches
    named Controls; every board game added `<prefix>_click x y`. A generic
    `click_at x y` (viewport coordinates, synthesised mouse event) belongs
    in the Template.

22. **A scrolling menu whose only seam is a clickable button is not fully
    scriptable** (NavalWar). `nw_build <unit_id>` exists because with a
    twenty-unit roster the buttons sit outside the visible rect. Rule:
    every menu action needs a non-click seam.

23. **A playtest must not bank progress** (NavalWar `MatchConfig.playtest`).
    Any editor-launched or harness-launched session must be flagged so
    completion and unlock code skips persistence.

### Test technique

24. **Sleeping tests get a seam** (FrogGame). `AudioManager.save_debounce`
    is a variable so a test can shorten it, and `flush_volumes()` exists
    so a test need not sleep through the debounce. AudioManager is
    Template code, so this is directly backportable. Profile with
    `-gjunit_xml_file=` and read per-script times.

25. **Contract tests that scan the repo.** NavalWar's `test_localization`
    scans scripts for every `ui.*` key and fails when the CSV lacks a row,
    making "a new string is a key plus a row in the same commit" a tested
    rule. L10n is Template code; the test could ship with it. Other
    examples: "shipped data covers every X", "every seed is solvable",
    "the base mod ships all five".

26. **Frame-rate independence as a test** (Tandem). Run the pure sim at
    dt = 1/30 and 1/120 with the same seed and require identical outcomes.
    Catches anything accumulating delta wrongly.

27. **A gate must be proven able to fail** (Monmon balance gate). "It was
    verified by restoring the exploitable heal and confirming it goes
    red." Plus a self-check row: a mirror match must read exactly 50%, or
    both seat orders did not run. Generic principle for any threshold in
    `check.sh`.

28. **Split scene-heavy test files and share a base class** (NavalWar).
    One 74-second file was the whole suite's long pole; the skirmish scene
    tests extend a common `tests/skirmish_scene_base.gd`.

29. **`-s` tool scripts run without autoloads** (Orbit) and cannot compile
    a class cycle that only resolves once autoloads register (NavalWar).
    Both projects moved dev tools to self-freeing autoloads gated on a
    `--flag` user argument. That pattern (an autoload that checks
    `OS.get_cmdline_user_args()` and frees itself when its flag is absent)
    is how `--sim`, `--balance`, `--ai-bench`, `--battle`, `--lint`,
    `--nettest-*` and `--net-role` all work. It deserves a Template
    skeleton.

## Tier 3: patterns worth a skeleton, not a copy

30. **Headless bot drivers as tier-3 tests.** BossFights' `BotDriver`
    touches only the seams a human uses (`input_override`, `request_cast`)
    so a sim exercises the real pipeline; one driver serves the in-process
    sim and the multi-process nettest. procedural-factory's `AutoPlayer` is
    a logistics-ideal bot whose tier times are a lower bound the pacing
    harness asserts against bands. Zoofle has a greedy "seeing player"
    fixture. Monmon's balance gate runs AI-vs-random and AI-vs-AI with
    thresholds that each trace to a bug the unit tests missed.

31. **Multi-process network acceptance** (BossFights `nettest.sh`, Tandem
    `net_test.sh`). One host plus N headless clients on localhost, each
    with its own log and port, exit 0 when the server reports the match
    ended; Tandem repeats under 100 ms simulated latency and checks a
    mismatched client is rejected cleanly.

32. **A data linter with no rules of its own** (Monmon, NavalWar). It runs
    the real loaders and reports what they said as `file:line: level:
    message`; a second rule set would drift and bless content the game
    refuses. Line numbers are recovered by searching for the token the
    message quotes, because `JSON.parse` discards position on success.

33. **Two match runners answer different questions** (NavalWar). One pins
    player 0 to a reference profile so rows are comparable and the
    mirror row is the control; the other plays both sides identically so
    unit statistics measure the unit, not the profile.

## Two conventions found once but caught only by the harness

- **A child's `_ready()` runs before its parent's** (NavalWar): a pause
  menu asked whether a match was running, always got no, and its Save
  button "had never once appeared in a running game — nothing asserted
  it, so nothing noticed."
- **Signals from an autoload need a method, not a lambda** (NavalWar): a
  lambda captures `self` without binding, so the connection outlives the
  scene and fails on the next emit.

## What to do with this in Microbiome

The order below is by how many projects paid for the lesson, then by how
mechanical the port is.

1. Parse-failure guard in `test.sh` (item 1). Remove the `SHOOT_TIMEOUT`
   pin in `check.sh` (item 2). `GODOT` override in all three scripts
   (item 7). Grep `shader` (item 11). Per-scenario seconds (item 12).
   All small script edits.
2. Harness: `settle`, `ticks`, `scroll_to`, `click_at`, ambiguity refusal
   in `assert_onscreen`, generic `state` / `assert` (items 13, 14, 16, 17,
   19, 21). Then `frame_budget` (item 15).
3. CLAUDE.md: settings-file persistence rule, ambient off-switch rule,
   assert-after-action rule, anchors preset, non-click seam for menus,
   playtest flag (items 3, 4, 5, 20, 22, 23).
4. Sharded `test.sh` with JUnit timings (item 6), the `check.sh` lock
   (item 8), `--ci` plus `ci.yml` (item 9).
5. Template code fixes with tests: `save_debounce` seam and
   `flush_volumes()` (item 24), a localization scan test (item 25).
6. A self-freeing `--flag` autoload skeleton for headless drivers
   (item 29) with the bot-driver and gate-must-fail principles written
   beside it (items 27, 30).
