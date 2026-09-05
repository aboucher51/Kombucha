# Plan: moving a project to the Linux filesystem (Monmon first)

Status: trial run on Monmon 2026-09-05, measured, NOT cut over. The trial
copy is at `~/godot-projects/Monmon`; the original on `/mnt/c` is
untouched and still the source of truth until the cut-over step below.

## Why

Every engine process pays the WSL `/mnt/c` bridge: each test shard, the
boot check, the balance gate, each scenario shard. The whole loop is
dozens of processes per check.

| Monmon (204 MB, 664 tests, 25 scenarios, 60-battle balance gate) | `/mnt/c` | Linux fs |
|---|---|---|
| Headless boot | 15.0 s | 0.8 s |
| Full `tools/check.sh` | 395 s | 217 s |
| Results | identical: 664 tests, 25 scenarios, same balance numbers, 96 shots |

The remaining 217 s is the work itself (the balance gate's 60 battles, 25
scenarios, and Monmon's unsharded pre-ownership test runner). Syncing the
current tooling would shard the tests on top of this.

## What the inspection found (and the plan must respect)

- **Monmon's working tree is dirty: 162 uncommitted changes** (52 modified,
  106 untracked, 4 deleted; last commit 2026-08-24 "lots of stuff",
  matching `origin/main`). A `git clone` would carry none of it. The move
  copies the working tree with `rsync`, `.git` included, and verifies the
  status count matches before anything else.
- The remote is GitHub (`aboucher51/monmon`), so the moved repo keeps its
  backup path; nothing else on the Windows side watches the Linux disk.
- No symlinks, submodules or LFS. `.gitattributes` pins LF on every text
  type, so a Windows editor saving CRLF is normalised on commit.
- The only absolute path in tracked files is the Template path in
  `.claude/skills/update-template/SKILL.md`, which stays valid while the
  Template stays on `/mnt/c`; `GODOT_TEMPLATE` / `GODOT_TOOLING` override
  it when everything moves.
- Player data (`user://`, saves, installed mods) lives in
  `~/.local/share/godot/app_userdata/Monmon` and is unaffected by where the
  project lives.
- The Windows side reaches the Linux disk at
  `\\wsl.localhost\Ubuntu\home\alex\...` (verified with `dir`); no drive
  letter is mapped yet.

## Procedure (per project)

1. **Inspect**: `git status --porcelain | wc -l`, remote, size,
   symlinks/submodules, absolute paths (`git grep -nE '/mnt/c|C:'`).
2. **Copy the working tree**, not a clone:
   ```bash
   rsync -a --exclude 'shots/*.png' /mnt/c/Users/Alex/godot-projects/<P>/ ~/godot-projects/<P>/
   ```
   Then in the copy: the same `git status --porcelain | wc -l` as step 1.
3. **Import and check** in the copy: `godot4 --headless --path . --import`,
   then `tools/check.sh`. Must be green with the same counts as the
   original (run the original's check first if a number is in doubt).
4. **Cut over** (the user's call, one project at a time):
   - map a drive once from Windows, so every app sees a normal folder:
     `net use W: \\wsl.localhost\Ubuntu\home\alex\godot-projects /persistent:yes`;
   - open the project from `W:\<P>` in whatever Windows tool needs it;
   - delete the `/mnt/c` copy, or rename it `<P>.moved` for a week; two
     live copies drift.
5. **Sync the tooling** (`/sync-godot-tooling`) as part of the same move,
   since the new runner is what turns the boot saving into a check saving.

## Rules after the move

- **One side imports.** The `.godot` cache is shared; two engines importing
  at once corrupt it. WSL owns imports; the Windows editor opens the
  project but does not run a full reimport.
- Same Godot version on both sides (4.7.1).
- Git operations from WSL. Line endings are pinned by `.gitattributes`.
- The Linux disk is not covered by anything watching Windows folders: the
  GitHub remote is the backup. Push.

## Order for the rest

Monmon (trial done), then the projects with the most engine processes per
check: NavalWar (86 test files, 61 scenarios), FrogGame (52 / 36), Orbit,
BossFights, procedural-factory, Zoofle, Tandem, Digit. The Template and
Microbiome last, with `GODOT_TEMPLATE` and `GODOT_TOOLING` set in the shell
profile before the scaffold and sync skills are used again.
