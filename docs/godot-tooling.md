<!-- OWNED BY KOMBUCHA (tools/tooling-manifest.txt) and overwritten by
/sync-godot-tooling. Every project's CLAUDE.md imports this file with a
single `@docs/godot-tooling.md` line where its tooling sections used to be,
so a rule added in Kombucha reaches every synced project without a
hand-splice, and the copies cannot drift. Project-specific test rules stay
in the project's own CLAUDE.md, beside the import. -->

### Exploring the project

Read `PROJECT_MAP.md` before you grep for which scene carries a script,
who emits or listens to a signal, what uses a `class_name`, or
whether a node path exists. `godot-map` generates the map (it has its own repo,
`~/godot-projects/godot-map`; run `uv tool install --editable` on it once per
machine). The project commits the map, with the full graph in
`.godot-map/graph.json`:

```bash
godot-map .                          # regenerate after adding or moving scenes or scripts
godot-map . --who Enemy --depth 2    # what references a path, class_name or autoload
godot-map . --paths scripts/hud.gd   # every $Node / %Unique path in a script, checked against its scenes
```

Without the map, Claude reads twenty `.tscn` files to find one connection, or
guesses a node path that does not exist. When the tool is installed,
`check.sh` fails on a stale map. When the tool is missing, `check.sh` prints
`--`. So a map that fell behind the scenes never reaches CI. A project with
no map yet gets a note, not a failure. Run `godot-map .` once and commit both
files.

The hook in `tools/seeds/claude-hooks.json` regenerates the map after every
`.gd`/`.tscn` edit. Merge it into the project's `.claude/settings.json`. The
sync does not copy settings, because they carry each project's permissions.

### Verifying a change

Re-import after you add a new `class_name`, autoload, or translation CSV:

```bash
godot4 --headless --path . --import
git diff --stat project.godot     # the import can rewrite it
```

**The import may rewrite `project.godot`.** It can drop a setting the editor
normalises. One project lost a directional-shadow size on every import and
had to `git checkout project.godot` after each one. It did not happen in this
fixture, so treat it as a problem of that project's shape. Check the diff
while the change is small, not at commit time.

Smoke-test by running headless for a fixed duration:

```bash
timeout 8 godot4 --headless --path . > /tmp/run.log 2>&1; echo "EXIT=$?"
```

**Exit 124 means success.** The game ran the full duration without crashing.
Any other exit code is a crash or early quit. Redirect to a file rather than
piping to `tail`/`head`. Piping loses the engine's stdout, and you will see an
empty log from a run that actually worked.

### Checking a change

```bash
tools/check.sh          # tests + boot (with memory budget) + all scenarios
tools/check.sh --quick  # tests + boot only (no display needed)
tools/export.sh         # every declared preset (Linux, Windows, Web), then smoke-tests the Linux binary
```

Run check.sh before you say something works. It names whatever failed.

**The execute bit is part of the commit.** Git records it. A filesystem that
ignores modes (`/mnt/c`, Git Bash) makes every file look executable. So a
script committed as 100644 works there, and fails with "Permission denied"
the day the checkout lands on a real filesystem. A non-executable
`check.local.sh` then reads as "no local checks". check.sh's first section
fails on any `tools/*.sh` without the bit. The fix is `chmod +x` plus
`git update-index --chmod=+x`.

Put project-specific checks (sims, gates, linters) in `tools/check.local.sh`.
check.sh runs it between the boot and the scenarios, with `QUICK` set. The
sync copies check.sh itself over. When a project's copy of the tooling is
behind, check.sh says so in a `note:` line. That is the cue to run
`/sync-godot-tooling`.

**check.sh's settings live in `tools/check.local.env`**, a file a sync
never touches. It holds plain `KEY=VALUE` lines. check.sh reads them as
text and never runs them, so `$HOME` stays the five letters `$HOME`. The
first key is `CHECK_RSS_BUDGET_KB`, the boot memory budget in KB
(default 400000). The boot check fails at or above it. Its line says
where the budget came from (`tools/check.local.env`, `environment` or
`default`). A variable the caller sets wins over the file, so a CI
workflow that passes one keeps working. Before this file existed, one
project raised its budget by editing check.sh, and every sync put it back.

**`check.local.sh` may choose which scenarios check.sh renders.** Use this
for a push gate that renders only what a batch touches. If the file mentions
`--scenarios`, check.sh first calls it with that argument. The script prints
the paths to render, one per line, or the one word `none` to render nothing.
No output, or a non-zero exit, renders all of `scenarios/*.txt`. A listed
path that does not exist fails the check. check.sh then prints "N of M
scenario(s), chosen by tools/check.local.sh", so nobody mistakes a smaller
gate for the full sweep. The script must answer `--scenarios` and exit
before its own checks, or they run twice (the seed does this).

**A long scenario suite can gate on only what a batch reaches.** Record
what each scenario loads. The dev hooks' `scenario_started` and
`scenario_finished` bracket each scenario. So a recorder can note every
script and scene the scenario adds in between, and write one record per
scenario to a committed file. Then `check.local.sh --scenarios` picks the
scenarios that a batch's changed files reach: a scenario that loaded the
file, or loaded a file that uses it (the project map's links say which).
Always add a small core of the main flows, and every scenario the record has
never seen. Run everything when an autoload, `project.godot`, the main
scene or the tooling changes. One project's gate rendered 200 scenarios
on every push, about 17 of its 25 minutes, for batches that touched one
screen.

**Run the full sweep when the ticket queue is empty, and re-record in it.**
A record only shrinks the gate. A scenario that now loads a file it did not
load before drops out of every gate that changes that file. Without the
sweep, a broken scenario can skip the gate forever.

`tools/export.sh` builds every preset in `export_presets.cfg` that it
knows (Linux, Windows Desktop, Web). It names an unknown preset and skips
it. On first run it fetches only the export templates those presets need
(~1 GB download, cached). It applies the same exit-124 convention to the
exported Linux binary. CI runs it on version tags
(`.github/workflows/export.yml`).

### The debug console

**Dev builds only.** F12 or ~ toggles the console. A project with a
`console` InputMap action gets that action instead of ~, so a rebindable row
keeps working and nothing toggles twice. The console ignores the key while
another text field has focus. It opens only when `DebugConsole.allowed()`
says yes: in a debug build, or in an export with the `dev` custom feature,
unless the project's `console_allowed()` hook decides. A player export
builds no console UI at all, so its cheats do not ship. Before this gate,
every export carried them.

`-- --console-check` prints `console_allowed=…` and exits 0 or 3. A release
check uses this to prove an exported binary. `--console-release` makes a
debug run act as a player build.

`DebugConsole.execute(line) -> String` is the input-free seam, and it answers
in every build. Scenarios pass unknown commands straight to it, so scenario
lines and console lines are ONE vocabulary.

**A new command needs both halves.** Put its surface (name, aliases, usage,
args) in `data/console_commands.project.json`. Put a handler in
`scripts/dev/dev_hooks.gd`'s `console_dispatch()`. The console itself
(`scripts/dev/debug_console.gd`, `data/console_commands.json`) is a synced
copy. The next sync overwrites a handler you add to its closed `match`.
That is why one project's 600 lines of in-file commands cannot sync today.

Return failures as `"ERROR: ..."`. The harness fails a scenario on exactly
that shape. So an assertion-like handler that answers `"false"` instead
passes silently.

**`""` is the empty value**, in console lines and scenario lines alike (one
tokeniser, `DebugConsole.tokenise`). Before, nobody could write an assertion
that a field is UNSET. The tokeniser trimmed the trailing space and read the
argument as missing. So one project asserted a neighbouring fact instead.

The tokeniser leaves every OTHER quote where it is. A console command that
takes JSON needs `ed_set name "Shore War"` to reach its handler with the
quotes on. A version that stripped them broke thirteen scenario files in one
project on the day someone tried it.

**An assertion's value is `"kind": "rest"`**, as the core `assert` declares
it. A `string` value stops at the first space, and every Vector2i prints with
one. So a project's own `x_assert anchor (4, 3)` compared against `(4,`.

**A named argument is a flag** (`"flag": true`, given as `--name=value`
anywhere on the line). The console pulls flags out before the positional
pass. A flag lets an optional argument come before a rest one, which
positions cannot express. One project forked a command per field instead.

**The console asks the hooks first**, for console handlers and scenario
lines alike. A project may take over a core command or a harness built-in by
answering for its id. (One project's `saves` prints the browser's own row
text. Another's `settle` knows its own busy nodes.) `null` means "not
mine". Without this, a project that needed its own `locale` had to edit
the synced console, and the next sync erased it.

**The project's command rows win the same way.** A row in
`console_commands.project.json` with a core row's id replaces that row in
place. So `help`, usage errors and the suggestions show the project's own
usage and list the command once. A project name that is a core alias takes
that alias.

**The console suggests as you type.** For the first word it lists matching
commands (usage plus the command's one-line `description`, which every
command should carry). After the first word it shows the current argument's
hint (name, kind, needed or optional, range) and its values. The values come
from an `enum`'s `values`, a `bool`, or a `"complete": "<source>"` field.
Core sources are `commands`, `saves`, `actions` and `locales`. The console
asks the project's `console_complete(source, prefix)` hook first, so a game
offers its registry's ids.

Up/Down walk the list (or the history, when the list is hidden). Tab takes a
row. Enter takes one only after Up/Down. Esc hides the list. Ctrl+R searches
past lines. `DebugConsole.suggest(text)` is the pure answer the list shows.
Test that, not pixels.

**History, height and tab persist** in `console.cfg` under
`SaveManager.save_root`, so a suite or harness run never touches the
developer's own. The harness calls `DebugConsole.reset_session()` between
scenarios, because a console left open covers every later shot.

**Buttons are data.** A list entry `{"buttons": [{id, label, run, group,
tip, fill}]}` in either command file adds buttons under a tab per
`group`. The project's tabs come first, and the core `Console` tab last
(Help, Clear, Restart, Report bug, Copy log). `run` is a console line, so a
button is a command the tooltip teaches. `fill: true` puts the line in the
input for you to finish. Each button is `ConsoleButton_<id>` under
`ConsoleTab_<group>`, and `DebugConsole.press_button(id)` is its input-free
seam. `button_problems()` lists a button whose line names no command, and a
test should assert that list empty.

`console_assert <key> <value>` reads the console's own UI back (open, input,
suggests, hint, tab, button, history). The harness's `key <name>` and
`type <text>` reach the console as a keyboard would.

### Tests

```bash
tools/test.sh                       # all, across parallel shards
tools/test.sh test_smoke            # one script: an EXACT name wins
tools/test.sh test_a test_b         # several, in ONE process
TEST_JOBS=1 tools/test.sh           # one process — the readable log
```

**An exact name wins over a prefix.** `test.sh test_campaign` used to run
`test_campaign_flow.gd` as well and return the union of both verdicts. So
a green target read as red twice in one day, and a sibling's parse error
read as the target's. With no exact match, every script containing the
fragment runs, and the run names them. Several names run in one process,
because closing a feature meant a dozen one-script runs, and each paid for
the engine's boot.

GUT 9.7.1, vendored in `addons/gut`, tests in `tests/`, config in
`.gutconfig.json`. Everything in `tests/` is pure logic and runs headless.
Anything that needs a rendered frame belongs in a scenario instead.

**The suite runs in shards.** `test.sh` starts one shard per thread of
`nproc` by default, at most 16, capped by the script count. Total CPU sets
the suite's speed, and a thread pair is not one shard's worth. A 12-thread
box ran a 159-script suite in 52 s on four shards, 41 s on six, 35 s on eight
and 29 s on twelve. That is a few seconds over the floor its longest script
sets. A 4-core CI runner keeps its four. Sharding helps because a Godot test
run is CPU-bound and single-threaded, while the suite is a pile of
independent scripts.

Each shard gets its own `XDG_DATA_HOME`, because every shard writes
`user://`, and two shards sharing it fight over the same files. **A named run
also gets its own.** It used to boot against the developer's real `user://`.
So whatever a boot read before a `before_each` redirected the config (a
display zoom, a visibility scale) came from the developer's own settings
file, and a test passed sharded and failed by name.

A shard's config says `dirs: []`, because GUT ADDS `-gtest` entries to
whatever the config names. `test.sh` drops an empty shard, because GUT exits
1 on a config with no tests. Balance comes from the LAST run's JUnit timings
in `.godot/test-timings`, dealt longest-first.

**Sharding exposes cross-test leaks, which is a feature.** A script that
only passed because an earlier one had left something set now fails. Fix
the dependency, and never reorder the shards. When a sharded failure makes no
sense, run `TEST_JOBS=1` and compare.

**A red run repeats its failing assertions at the end**, under
`── failing assertions ──`. GUT counts them in its summary but prints the
text far above it, which on any real suite is hundreds of lines up.
`test.sh` lists each failing test once, under its own file. After an
"Unexpected Errors" failure it prints the error text GUT counted.

**A red run keeps its evidence** in `.godot/test-logs/`: each red shard's log
and JUnit file (`shard.N.log`, `.xml`), or a named run's `named.log`. Before,
nobody could read a flake once the run's temporary folder was gone, and a
rerun had already replaced `.godot/test-results.xml`. A suite run clears only
the `shard.*` files, and a named run clears only `named.*`. So rerunning one
script keeps the suite's evidence.

**The engine reports a parse error everywhere except where it is.** The
engine answers a class that will not parse with `Could not resolve class "X",
because of a parser error`. It says this in every log, naming neither the
file nor the line, while every autoload that touches the class fails the same
way. When a run sees that, `tools/parse-error.sh` maps the class to its file,
asks the engine to parse just that file (`--check-only --script`), and prints
`parse error: <file>:<line> — <message>`. `test.sh`, `shoot.sh` and
`check.sh` all call it. It prints nothing when there is no parse error.

**GUT silently drops a test script that fails to parse, and exits 0.** Four
projects each found this behind an all-green check. The only sign was the
total test count falling. `test.sh` now greps every log for the load failure,
and counts the scripts that ran against the files on disk. Kombucha's
self-test proves both guards fire against a scratch copy with a broken test
file. A falling count means a file did not load, not that fewer tests passed.

**`test.sh` merges the JUnit report across shards** into
`.godot/test-results.xml` (`TEST_JUNIT` moves it, and an empty value skips
it). CI keeps it as the `test-results` artifact beside the shots, so you can
read a red run per test without the log.

**A shard's budget scales with how few shards there are.** The default 180 s
is per shard for four or more shards (more shards each carry less).
`TEST_JOBS=1` gets four times that, because one process carries the whole
suite. When `test.sh` kills a shard, the shard reports as timed out with the
scripts it never reached. It never reports them as scripts that "did not
load" (that was the message once, on a 1,000-test suite). `TEST_TIMEOUT`
overrides.

**A slow test is usually a sleeping one.** Put anything that waits out a real
timer behind a seam a test can shorten. Profile with the per-script times in
`.godot/test-timings`.

**Assert an expected error by its text.** A test of a refusal path, where
the logged error is what it checks, ends with
`assert_push_error("part of the message")` (`assert_engine_error` for an
engine error). That marks only that error as expected, in that test, and
fails if the error never comes. Never set
`gut.error_tracker.treat_push_error_as`. GUT keeps one tracker for the
whole process, so the setting stays off for every later test in the
shard, and those tests pass with errors in them. This fixture had two
such lines. A planted `push_error` test failed alone and passed after
either one. `test.sh` prints a `test: warning:` line naming the file and
line of any such setting, and the run stays green.

**Headless UI smoke recipe:** you can still test a crash in code-built UI
that only mouse input reaches, headless. Instantiate the real scene, let it
build, and call its handlers directly:

```gdscript
func test_scene_builds_and_handlers_run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame  # _ready has run; code-built UI exists
	# call the scene's input-free methods here and assert
```

This complements the screenshot harness. The harness proves the player's
path renders. This test proves the wiring survives a refactor, cheaply, in CI.

**Frame-rate independence recipe** (for any pure simulation): run the same
seeded scenario twice, at two `dt`s (1/30 and 1/120). Record the sim-time at
which each event first became true, not the end state. (An end-state
comparison passes trivially once both runs finish.) Compare timestamps with
a tolerance you can derive (one slow tick per stage boundary), and compare
discrete counters exactly. Anything that drifts is accumulating delta
somewhere.

### Seeing the game (screenshot harness)

For anything visual, do not ask the user what it looks like. Capture it:

```bash
tools/shoot.sh                        # every scenario, one Godot process
tools/shoot.sh scenarios/example.txt  # just one
tools/serve.sh start                  # one engine kept alive; then
tools/serve.sh run scenarios/x.txt    #   a scenario against the LIVE state
tools/serve.sh say "click PlayButton" #   one line; `say reset` = boot scene
tools/serve.sh stop
```

**Use `serve` to iterate on one scenario, and `shoot` to prove it.** Serve
mode keeps one engine on the display and feeds it scenario files as they
appear. It answers each file with its printed lines and a verdict in under a
tenth of a second. State carries over between commands unless a line says
`reset`. Serve mode is not a gate: `check.sh` runs `shoot.sh`, which boots
fresh, deals the batch, and is what CI runs.

**A served engine waiting for a command draws at 10 fps** and gets 4
llvmpipe threads (`LP_NUM_THREADS`). It stops by itself after
`SERVE_IDLE_S` seconds with no command (1800 by default, 0 for never), or
when its serve folder or its project is gone. Uncapped, one waiting
engine took about 20 cores on a software renderer. One engine left behind
by a removed worktree ran for 17 hours.

**`SERVE_IDLE_FPS` sets that rate** (default 10). It trades CPU for reply
time. The engine picks up a command within one idle frame, so 5 fps answers
within 0.2 s. One project's waiting sessions used about 80% CPU at 5 fps and
131% at 10. A value that is not a whole number above 0 gets 10, with a note
in the engine log. The engine's `harness: serving` line says which rate it
took.

**The batch runs on a virtual display when Xvfb is installed** (`sudo apt
install xvfb`, the `SHOOT_DISPLAY=auto` default). No window appears, and
nothing takes the keyboard. Without Xvfb, `shoot.sh` uses the real display.
Under WSLg, Windows then brings every new window to the foreground, whatever
the engine says:

- The no-focus window flag keeps X focus off, and the window comes to the
  front anyway.
- `--screen` only moves the window to another monitor.
- The engine maps a hidden parent window (`--wid`) as a top-level window of
  its own.

We measured all three from the Windows side, by polling the foreground
window during a run. So a batch of N processes interrupts whoever is typing
N times. `SHOOT_DISPLAY=real` is for watching the window. Under WSLg
`/tmp/.X11-unix` is a read-only mount. So the virtual server listens on TCP
(`xvfb-run -l`), and the client finds it there by itself. `serve.sh`
follows the same rule.

**The virtual screen is as big as the game window** (`SHOOT_RESOLUTION`,
else the window size in `project.godot`, at least 1280x720).
`tools/xvfb-screen.sh` works the size out for both scripts. X keeps the real
cursor inside its screen. On the old fixed 1280x720 screen, a 1600x900
game's `hover` on a button at x=1292 stopped at x=1279, and read the
control there instead. Clicks still worked, because the harness pushes them
as events.

**Rendering is on the GPU when WSLg offers one** (`SHOOT_GPU=auto`, Mesa's
d3d12 driver), on the real display and the virtual one alike. We measured it
twice as fast on a 36-scenario suite, with the same shots. A settled frame is
pixel-identical between GPU reruns. The adapter name (and so the
`expect_shot` baseline directory) is the same on both displays.
`SHOOT_GPU=0` forces llvmpipe, which CI always uses. `check.sh --ci`
sets both, and the local gate proves the virtual display with each.

**Batches take turns on a shared machine.** Where the agent-tickets
script is installed, `shoot.sh` holds its machine-wide `render` slot
(one at a time by default) while its engines run. It also caps llvmpipe at
half the cores, split across its shards (`LP_NUM_THREADS`). One llvmpipe
shard took ~12 of a 32-thread server's cores, so three projects'
batches at once each slowed the other two. Headless tests do not wait
for the slot. `SHOOT_RENDER_SLOT=0` skips the slot. `SHOOT_RENDER_WAIT`
(1800 s) is how long to wait before running anyway. CI has no script and is
unchanged.

Scenarios are plain-text files in `scenarios/`, one command per line. Write a
new scenario for whatever you are working on, rather than editing an existing
one. Scenarios need a display server (Xvfb, else WSLg's `DISPLAY=:0`), and
**not** `--headless`, which has no renderer and captures blank frames. PNGs
land in `shots/` (gitignored).

**`shots/` and `builds/` each hold an empty `.gdignore`**, committed.
`shoot.sh`, `serve.sh` and `export.sh` write it back when it is missing. A
long-lived headless editor (the GDScript language server an IDE keeps
running) imports every PNG under `res://` as a texture and holds it. One
project's editor grew to 7.7 GB on ~3,600 shots. It starved the shared
machine, and other sessions' checks died.

**A run clears only the scenarios it is about to run.** The harness prefixes
each shot with its scenario stem. So a single-scenario run no longer destroys
the shots of the one before it. That bit twice in one day, the second time
while someone was reading them. `SHOOT_KEEP=1` keeps everything. After every
run, `shoot.sh` copies the engine's own shard logs to `shots/shard.*.log`.

Built-in commands (`scripts/dev/screenshot_harness.gd`): `shot <name> [x y w
h]`, `wait <frames>`, `ticks <n>` (physics frames: game time), `sleep
<seconds>` (wall-clock, deliberately ignoring `Engine.time_scale`), `settle
[s] [group]` (wait until nothing in the group answers `is_busy()`, ERROR
after `s`), `until <s> <line>` (run any scenario line once a frame until it
answers without an error; ERROR with its last reply after `s` wall-clock
seconds), `click <NodeName>` (synthesises real input — prefer it when what
you need to prove is that the *player's* path works, not that a handler
does), `click_at <x> <y>` (viewport coordinates, for Node2D boards),
`drag <NodeName | x y> <to_x> <to_y> [steps]` (press at the start, move
with the button held in `steps` moves, 8 by default, release at the end;
use it over `click` when the thing must follow the pointer, like a
slider or a lever; the real cursor stays still while the button is
held, because its motions carry no button and a hand-made lever lets
go on one, so on the real display a drag wants `SHOOT_JOBS=1`, like
hover),
`scroll_to <NodeName>` (`click` and `hover` scroll a target below a
ScrollContainer's fold into view themselves; this forces it), `press
<action>`, `key <name>` (a real key, `QuoteLeft` or `Ctrl+R`, for keys no
action names), `type <text>` (one key event per character into the
focused control),
`assert_visible`, `assert_onscreen` (Control, or Node3D through the live
camera), `assert_zone <NodeName> <top|bottom|left|right>` (the whole rect
in that zone of the viewport: a layout rule a scenario enforces instead of
an eye), `select <Dropdown> <id-or-label>` and `select_assert` (a click
only OPENS an OptionButton, so this is how a scenario picks; the harness
refuses a disabled item and names its tooltip), `window` (prints the size the window
manager actually granted, for a check at a named size),
`assert_tooltip <NodeName> <text>`, `frame_budget <ms> [frames]`,
`expect_shot <name> [tolerance]`, `mask <x> <y> <w> <h>`, `expect_fail`,
`reset`, and `#` comments.
Put project-specific commands in `scripts/dev/dev_hooks.gd`'s
`scenario_command()`. Return `""` on success, `"ERROR: ..."` on failure, and
`null` to hand the line to the console. **The harness only fails on
error-shaped replies.** So an assertion command must return an error, never a
`"false"` answer that passes silently.

The hooks also hear each scenario start and end.
`scenario_started(path)` runs after the sandbox, before the first line.
`scenario_finished(path, ok)` runs after the last line, failed or not. Use
them to record what each scenario loads. Never read the harness's private
fields, because a sync may rename them.

**Read state back before you compare pixels.** The console's `state` and
`assert <key> <value>` reach any node in the `state` group that implements
`state_text()` and `assert_key(key, value)`. The node answers `""`,
`"ERROR: ..."`, or exactly `"ERROR: unknown key '<key>'"`, so the console
asks the next provider. A `prefix:` key exposes an open namespace. A JSON
line is cheaper than a screenshot, and you can assert on it. Every board game
reinvented this seam under its own prefix before Kombucha shared it.

**A scenario must assert state after actions.** Picture a click that cancels
back to a menu without an error, followed by more clicks that also do
nothing. That scenario is a run of silent cancels, and it passes.

Rules that keep the harness useful:

- **Waits are three verbs, on purpose.** `wait` is frames, `ticks` is
  physics frames (game time), and `sleep` is wall-clock. Under a slow
  renderer, physics falls behind wall time. So a wall-clock sleep
  under-waits exact-timed choreography (one project's ferry failed only in
  the batch). A timer-driven thing wants `sleep`.
- **`is_busy()` answers only for work that will FINISH.** Leave a loop with
  no end out of the answer: a wounded hull smoking until it heals, or any
  ambient effect, is scenery. Otherwise the first such animation a project
  adds hangs every `settle` in the batch, and any pacing that awaits one with
  it.
- `settle` beats both when the thing you are waiting for can say it is busy.
  **Any node that animates joins the `settle` group and answers
  `is_busy()`.** The scaffold's main scene does this, as the pattern. One
  project replaced every `sleep 1.6` guess with `settle` the day its board
  answered.
- `is_busy()` reads the owner's OWN table of live tweens and effects, never
  `get_child_count()`. A `queue_free`'d node is a child until the frame ends,
  and reads busy one frame too long. For the same reason, the harness skips
  nodes on their way out, in `settle` and in the `state` group.
- **Watch for the state a scenario waits for. Never count frames to it.**
  Where a `wait N` or `sleep s` stands before an assert, use
  `until <s> <line>`. It runs the assert itself once a frame until it
  passes. Under batch load, a frame count covers more or less game than on a
  quiet box. One project had four scenarios that went red only under
  parallel checks (a `wait 30` met three record rows instead of two).
- The watched value must pass THROUGH the target (rows that grow one at a
  time) or HOLD it (a button that stays visible). If a value can jump past
  the target, the harness never sees it equal to the target. Such a value
  wants a different assert.
- **A name shared by two VISIBLE nodes is an ERROR, not a coin toss.**
  Every lookup refuses an ambiguous name. Assert on a uniquely named node
  instead. One project's `assert_onscreen Cliffs` used to answer about
  whichever area loaded first. A hidden namesake does not count. A hub's
  `SettingsButton` beside a closed pause menu's is the visible one, which
  is what the line means. (Three of one project's scenarios went red on
  the strict rule, for nodes a player could not have confused.)
- **The harness sends synthetic clicks through `push_input` in canvas
  coordinates**, never through `Input.parse_input_event`. That function
  treats the position as window pixels. So under any stretch other than the
  design resolution, every click lands somewhere else. (We found this at
  Steam Deck resolution, where every scenario click missed.) `click`,
  `click_at` and `hover` all use `push_input`.
- **The real cursor is the other way round.** `Input.warp_mouse` takes
  window pixels, so the warp before a click goes through the viewport's
  screen transform. Given canvas coordinates, it parked the cursor over
  another control at any window below the design size, and the click
  missed. (We found this again, at 1280x800 in a 1600x900 game, after the
  warp was added.) The local check clicks at 960x540 and 1280x800 for that.
- **A row below the fold is visible but not clickable.** `click` lands where
  the rect is, outside the viewport. The harness used to answer ok while
  nothing opened. (A settings header dropped below the fold when its
  buttons grew an icon slot.) `click` and `hover` now scroll a target
  into view when its rect is outside its ScrollContainer's. `scroll_to`
  forces it.
- A menu whose only seam is a clickable button is still not fully
  scriptable once it scrolls. Give every menu action a non-click seam too.
- **`expect_shot` is the visual regression gate, and each rasterizer has its
  own baselines.** It compares the frame against
  `scenarios/baselines/<renderer>/<stem>-<name>.png`. That directory is
  committed and `.gdignore`d, so the editor never imports it. By default it
  fails on ANY differing pixel, and saves the actual frame and a red-on-dim
  diff beside the shots.
- Reruns on one machine are pixel-identical, so a difference is a change to
  look at, not noise. Give a moving element a `mask` line, because a
  tolerance wide enough to hide a clock also hides a real regression.
- `SHOOT_BASELINES=update tools/shoot.sh <scenario>` writes the baselines
  (the first frame per name). `expect_fail` never writes.
- The `<renderer>` directory is the adapter family (`llvmpipe`, `nvidia`).
  A GPU and a software rasterizer do not agree pixel for pixel. A missing
  baseline for the machine's renderer is an ERROR that names the path,
  never a silent pass. So commit one baseline per rasterizer you check on:
  the GPU's (the default here), and `llvmpipe` for CI, written with
  `SHOOT_GPU=0 SHOOT_BASELINES=update`.
- **A frame captured mid-tween is not the same twice** on any rasterizer.
  (We measured `pop_in` varying from run to run.) Use `settle` or `wait`
  past the animation before `expect_shot`.
- **`frame_budget` is a regression tripwire, not a device target.** It
  turns vsync off for the measurement, because with vsync on every scene
  reads 16.7 ms and the gate can never fail. It prints the number on pass,
  so you see the trend before the gate goes red. On CI the renderer is
  llvmpipe, software. What it catches is the same scene on the same machine
  becoming several times more expensive.
- **The real cursor is global state.** `_sandbox()` parks it at (2, 2).
  Left over a control, it feeds hover and tooltips into every later
  scenario. On the virtual display each shard has its own X server, and so
  its own cursor. On the real display, the developer and every other shard
  share the one cursor.

- **When you add UI, add the input-free seam alongside it.** If only an
  InputEvent can reach an interaction, no screenshot can capture it, no
  scenario can script it, and no test can assert on it. Such an interaction
  is effectively untestable.
- Give run-time-built controls a stable `name`. Nothing can click or find an
  auto-named `@Button@3`.
- Put `assert_onscreen` after anything that places objects. An object
  escaping the view is among the most repeated visual bugs.
- To judge text sharpness or fine detail, capture a **1:1 crop**
  (`shot <name> <x> <y> <w> <h>`). The viewer shrinks a full-window shot,
  which hides exactly the detail in question.
- **`shoot.sh` deals scenarios across processes and reorders them by cost**
  (`SHOOT_JOBS`, longest-first from `.godot/shoot-timings`). Each process
  has its own `XDG_DATA_HOME`. So no scenario may depend on another having
  run first, and two `shoot.sh` runs cannot collide. Measured: two shards
  took 164 s, against 204 s, for a 36-scenario suite. `SHOOT_JOBS=1` keeps
  the order given, which is how you prove an order-dependent pair on
  purpose.
- `shoot.sh` MERGES the timings file. So a single-scenario run updates one
  row, and never leaves the next batch to deal blind.
- **On the real display the shards share the ONE cursor** (a virtual server
  per shard has its own). For that reason the harness pushes a click's
  press and release in the same frame. With a frame between them, the other
  shard's warp made the button see the pointer leave mid-press ("the second
  click of a confirm button fails only in the batch"). A scenario that
  proves hover or tooltips wants `SHOOT_JOBS=1`.
- **Test a layout rule at a named size.** `SHOOT_RESOLUTION=WxH` runs the
  batch in that window, and `assert_zone` lines state the rule. The
  scenario's `window` reply says what the window manager actually gave
  (WSLg refuses sizes above its virtual screen). So a project's
  `check.local.sh` can run its target screens, and report a refused size as
  `--`, never as a pass. The seed carries the loop, commented out.
- **Between scenarios the harness returns to the BOOT scene**
  (`application/run/main_scene`). It never reloads wherever the last
  scenario went. In one project, the first scenario pressed Play, and every
  scenario after it started inside the arena. Every `click PlayButton` then
  failed with "no node named". A scenario is free to leave the boot scene.
  The next one starts on it.
- **Where the project lives is the biggest cost.** Through WSL's `/mnt/c`
  bridge, a real project boots in ~11 s per process. From the Linux
  filesystem it boots in under a second. `check.sh` says so when it notices.
  Pacing flags do not help here. Under WSLg the game already runs
  unthrottled (~400 fps). `--fixed-fps` makes heavy scenes SLOWER on a
  software renderer, because game time falls behind wall time (measured and
  rejected).
- **A coroutine mid-`await` outlives the teardown between scenarios.**
  Anything sleeping on a timer (an AI turn loop's pacing, a replay)
  resumes AFTER the harness has returned to the boot scene. Then
  `is_instance_valid(self)` is still true, and `is_inside_tree()` is false.
  Whatever it then does with the viewport (`get_viewport()`,
  `create_tween()`, a deferred `grab_focus`) is an engine error under a
  green batch. It happens once per scenario that ended on that seat.
- A resumed coroutine checks `is_inside_tree()` before it touches the scene.
  A deferred focus goes through `UIFocus.grab()` (by instance id), never
  `control.grab_focus.call_deferred()`.
- Scenarios run in a batch, and the harness reloads the scene between
  them. But **anything global survives that reload**, and so does anything
  APPLIED from a setting. The redirected settings file lives for the whole
  process. A frame cap, vsync, a window mode, a UI scale or a rebuilt
  palette is engine state, not scene state. (One scenario's 150% UI scale
  poisoned six after it, and the failures pointed at clicks.) The project's
  `sandbox()` must write the defaults AND re-apply them through the path a
  boot uses.
- When you add new global state (autoload fields, static vars,
  write-through files), reset it in `sandbox()` in
  `scripts/dev/dev_hooks.gd`. The harness's own `_sandbox()` comes over with
  the sync and only knows the kit's autoloads. Otherwise a scenario that
  changes the state poisons every scenario after it. The symptom is always
  misleading: a scenario that passes alone and fails in the batch, or the
  other way round.

### Reading a run as data

Every scenario leaves `shots/<stem>.jsonl` beside its PNGs. It holds one JSON
object per executed line (`line`, `reply`, `ms`, `ok`), and a summary
last (`scenario`, `ok`, `failures`, `seconds`, `shots`). It answers "what
did this scenario do, and where did the time go" with `grep` or `jq`,
without the engine log. The merged JUnit report is the same idea for the
suite. Both exist because you read a log once, and you ask a file again.

**The gates name each engine error by the scenario it fell under.** The shard
logs carry the scenario headers in the same stream, so a counted error
prints as `<scenario>: <error>`. An unattributed `Condition
"!is_inside_tree()" is true` under "0 failed" cost one project four
minutes of re-running the batch to place it. The logs themselves stay in
`shots/shard.*.log`, because you read a log once, and you ask a file again.

**Every engine `ERROR:` line fails the boot and the batch**, not only
`SCRIPT ERROR`s. A freed lambda capture and a ConfigFile key read with no
default are plain engine errors. One project logged 738 of them under
an all-green check, before the gates counted them.

The one exception is the engine's exit-time resource accounting (`N resources
still in use at exit`, `N RID allocations ... were leaked at exit`, `Texture
with GL ID ... leaked N bytes`). The gates do NOT count it. It names a
resource that a `const preload` still holds while the tree is torn down
(`--verbose` says which). The counts vary between identical runs, so a gate
on them would be a coin toss. A leak that matters shows up as memory in the
boot budget, or as a growing `frame_budget` number, and the gates check both.

### The tooling is a synced copy

The Kombucha repo owns `tools/test.sh`, `check.sh`, `shoot.sh`, `export.sh`,
the screenshot harness, the debug console, GUT and `.gutconfig.json`.
`tools/tooling-manifest.txt` lists them, and `tools/TOOLING_VERSION` says
which Kombucha commit they came from. Do not edit them here. A
`/sync-godot-tooling` run overwrites them, and an improvement made here is
invisible to every other project. Improve them in Kombucha, then sync. Extend
them only through `scripts/dev/dev_hooks.gd`,
`data/console_commands.project.json`, `tools/check.local.sh` and
`tools/check.local.env`.

A sync prints the headlines of the Kombucha commits it pulled (old stamp
to new). So you can check a note that said "blocked on the next tooling
sync" against what just arrived. (One project's Steam Deck run was already
fixed by a sync, and nobody re-ran the check after it.)

Before a sync, run `tools/sync-tooling.sh <project> --check --diff` from
Kombucha. It measures each drifted owned file against the Kombucha version
it is closest to, and prints the lines THIS project added beyond it. Those
lines must move into a seam, or go to Kombucha first, before the sync
overwrites them.

`--kit` is the same report for the kit files (autoloads, util, ui). You
cherry-pick kit files, and never sync them. Per file, the report shows the
Kombucha version the copy is at, the project's own lines, and the Kombucha
commits since. Both reports need a clone of Kombucha with its history
(`GODOT_TOOLING`). The installed plugin has none.
