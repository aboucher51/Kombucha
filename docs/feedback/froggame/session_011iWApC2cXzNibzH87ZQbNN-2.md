# Feedback from FrogGame — session 011iWApC2cXzNibzH87ZQbNN, part 2

Source project: `~/godot-projects/FrogGame`, on tooling `8135a287b5844cb6f78b01f65206430b6935f200`
(synced 2026-09-06). The same session's second half: a six-step growth
system (a troupe level, natures, merit, class lines, talent supertiers,
held stones), each step landing with tests, a scenario, a schema bump
and a full check, so the tooling was run in a tight loop all day — twelve
targeted test runs and a shoot per step. Part 1 of this session is in
`session_011iWApC2cXzNibzH87ZQbNN.md`; nothing below repeats it.

## 1. `test.sh <name>` matches every script that starts with it (tooling bug)

`tools/test.sh test_campaign` ran `test_campaign.gd` AND
`test_campaign_flow.gd`, and the exit code was the union. Twice today a
green target read as red because the sibling had a stale assertion, and
once a PARSE error in the sibling was read as the target's; each cost a
round of reading the wrong log.

What breaks: a "one script" run is not one script, and the summary does
not say so.

Wants: an exact match wins when there is one; when several match, the
first summary line names them. Reference: none — the fix is in the
runner.

## 2. A parse error is reported everywhere except where it is (tooling)

A parse error in one class (`data_linter.gd`, a ternary the parser
refused) made every autoload fail to load, and every test and scenario
log said only `Could not resolve class "DataLinter", because of a parser
error` — never the file and line. Finding it took
`godot4 --headless --script scripts/util/data_linter.gd`, three times
today, one round trip each.

Wants: `test.sh`, `shoot.sh` and `check.sh` print the first
`Parse Error ... at: (res://...:N)` line from the log at the top of the
summary, the way the load-failure guard already greps for a test script
that did not load. Reference: none.

## 3. `--headless --import` rewrites `project.godot` (tooling doc)

Every re-import (a new test script, a new `class_name`) rewrote
`project.godot` — it dropped a directional-shadow size setting — and
had to be followed by `git checkout project.godot`. Forgotten once, it
would have shipped in the day's one commit.

Wants: the re-import recipe in the tooling doc says it and shows the
checkout, or a `tools/import.sh` that restores the project file (or
diffs it and warns) after the import. Reference: none — a habit.

## 4. `shoot.sh` wiping `shots/` bit again (tooling)

Part 1's observation 12, now a want: a single-scenario run wiped the
shots of the previous single-scenario run I was about to read, twice
today, and the second time I reshot under `SHOOT_KEEP=1`.

Wants: a run wipes only the shots of the scenarios it is about to run
(they are prefixed by stem) and leaves the rest; `SHOOT_KEEP` then has
nothing to keep. Reference: none.

## 5. The console cannot say "empty" (tooling)

`cp_assert pick:Hopper/class/1/1 ` — an assertion that a pick is UNSET,
whose expected value is the empty string — cannot be written: the trailing
space is trimmed and the required argument is missing. I asserted a
neighbouring fact instead, which is the weaker scenario.

Wants: `""` as the empty value in a scenario or console line, for any
argument. Reference: `scripts/dev/dev_hooks.gd` `cp_assert` keys that
legitimately answer `""` (`pick:`, `stone:`, `nature:`).

## 6. Several named scripts in one process (tooling)

Closing a step meant `TEST_JOBS=1 tools/test.sh <script>` nine to
twelve times in a row, each booting the engine and loading the mods
(five to eight seconds of the run). A way to name several scripts in one
invocation would have saved minutes per step.

Wants: `tools/test.sh a b c` runs exactly those in one process (the
sharded run stays the default for no arguments). Reference: none.

## 7. Two small kit UI rules (rule)

- `String.capitalize()` title-cases EVERY word ("Needs Troupe Level 8"):
  a refusal from a sim turned into a tooltip sentence wants the first
  letter only. Reference: `scripts/campaign/hub_screen.gd` `_sentence`.
- A `RichTextLabel` `[hint=text with spaces]word[/hint]` gives one word
  its own tooltip and the hint text may contain spaces; it is the way a
  card names a thing and explains it on hover without a second control.
  Reference: `scripts/game/tile_info.gd` `nature_bbcode`.
- A `Label` with empty text still takes a line in a `VBoxContainer`:
  add the line only when there is text, or a locked row leaves a gap
  (`hub_screen.gd` `_build_tree`, the `Under_` labels).

## 8. A ternary the parser refused (observation, Godot 4.7)

`Dictionary(o).get("k", {}) if Dictionary(o).get("k", {}) is Dictionary else {}`
did not parse ("Expected else after ternary operator condition") while
`u.get("k", {}) if u.get("k", {}) is Dictionary else {}` parses in the
same project. The difference I can see is the constructor-cast call in
the condition; I did not find the rule. Rewritten as an `if`. Worth one
line in the GDScript notes so the next person does not lose a round.

## 9. Restored equals fresh: the normaliser rule (rule, kit doc candidate)

Eight schema bumps today (5 → 8 in one afternoon, each a migration and
a golden fixture) held together on one pattern: every record shape has
ONE normaliser (`SimUnit.from_dict`, `CampaignActions.normalise_roster_unit`,
`SimMerit.normalise`) that every path goes through — fresh, template,
restore — fixing key order AND types (JSON hands back floats and a
Dictionary equality is order-sensitive), and one test per shape asserts
`restore(to_dict()) == to_dict()`. Migrations are then tiny (`_to_N`
reshapes one field; the normaliser does the rest) and a golden fixture
per schema pins the whole chain. The kit's SaveManager doc says how to
save; it could say this about how to load. Reference:
`scripts/util/save_compat.gd`, `tests/test_save_compat.gd`.

## 10. A check flake, once (observation)

`check.sh` reported `FAIL zones at 1920x1080` once while that run's
scenario log ended `scenario ok`; the rerun and every later full check
passed. No cause found. Written down so a second sighting has a first.

## 11. The map hook and Bash edits (observation)

The project-map hook fires on the Edit/Write tools; a day of edits made
through `python` and `sed` left the map stale until `godot-map .`, and
`check.sh` caught it every single time. Nothing to change — the gate
works — but the seed's hook comment could say what does not fire it.

## What not to port

The growth system's shapes — the troupe level, natures folded into
talents, acts as event triggers, class lines, supertiers, held stones —
are FrogGame's design (`docs/growth.md`). What crosses over is the
discipline: schema entry in the same commit, one normaliser per record,
a golden per schema, a scenario per step, and a full check before the
step is called done.

## Disposition (Kombucha, 2026-09-06)

Assessed against the tooling at `2d182eb`. Two findings did not reproduce
here and are declined with what was run; the rest landed in the next
commit. FrogGame is on `8135a28` and gets all of it by syncing.

- **1, `test.sh <name>` prefix matching** — done, and reproduced first
  (`test.sh test_save` ran both save scripts). An EXACT name now wins,
  and says that a sibling also matched; with no exact match every match
  runs and the run names them. The self-test plants a sibling and proves
  it.
- **2, a parse error reported everywhere but where it is** — done, and
  reproduced: breaking one class made every log say only
  `Could not resolve class "SaveCompat"`. New `tools/parse-error.sh`
  maps the class to its file, parses just that file
  (`--check-only --script`) and prints `parse error: <file>:<line> —
  <message>`; `test.sh`, `shoot.sh` and `check.sh` call it whenever a log
  shows a parser error, and it prints nothing otherwise. It reports the
  ROOT cause, not the files that merely name the broken class. Proven in
  the self-test.
- **3, `--headless --import` rewrites `project.godot`** — did NOT
  reproduce here (an import left the file byte-identical), so it is
  project-shaped, probably a setting the editor normalises. The
  re-import recipe now shows `git diff --stat project.godot` beside it
  and says why. No automatic restore: an import legitimately writes
  other files, and a script that reverted one of them would be worse
  than the habit.
- **4, `shoot.sh` wiping `shots/`** — done: a run clears only the
  scenarios it is about to run (shots are prefixed by stem). The
  fixture's local check runs two single-scenario runs and fails if the
  first one's shots are gone.
- **5, the console cannot say "empty"** — done: one tokeniser
  (`DebugConsole.tokenise`) for console lines AND scenario lines, where
  double quotes group a phrase and `""` is the empty value; the
  argument parser now distinguishes an ABSENT rest argument from an
  explicitly empty one. `assert last_row ""` is in `scenarios/state.txt`
  and a unit test.
- **6, several named scripts in one process** — done:
  `tools/test.sh a b c` runs exactly those, once.
- **7, three UI rules** — all three are in CLAUDE.md's UI kit rules
  (`capitalize()` title-cases every word; an empty Label still takes a
  row; `[hint=...]word[/hint]` for a one-word tooltip). No kit helper:
  nothing in the fixture would use it, and an unused helper is untested
  tooling.
- **8, the ternary the parser refused** — did NOT reproduce on Godot
  4.7.2. The exact line, constructor cast and all, parsed and ran here:
  `Dictionary(o).get("k", {}) if Dictionary(o).get("k", {}) is Dictionary
  else {}`. Something else on that line was the cause, so no rule was
  added; a rule that is not true costs more than the round trip it saves.
- **9, restored equals fresh** — adopted as a CLAUDE.md rule beside the
  save rules: one normaliser per record shape, every path through it,
  `restore(to_dict()) == to_dict()` per shape, a golden per schema.
- **10, the check flake** — recorded, no action. A second sighting now
  has a first.
- **11, the map hook and Bash edits** — the tooling text now says the
  hook fires on the Edit and Write tools only, and that `check.sh` is
  what catches the rest.
