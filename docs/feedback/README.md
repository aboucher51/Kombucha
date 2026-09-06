# Giving Kombucha feedback from a project

A project that hits a tooling or kit problem writes it up here, and
Kombucha decides what to do with it. The two halves are deliberately
separate: **the project reports what it hit; Kombucha assesses it.**

## Where and how

One file per session: `docs/feedback/<project>/session_<id>.md`, on a
branch `feedback/<project>-session-<id>`, committed in Kombucha and left
for a Kombucha session to pick up. Nothing else in Kombucha changes on
that branch. The project's own files are the reference implementations,
named by path; do not copy code into the report.

```bash
cd ~/godot-projects/Kombucha
git checkout -b feedback/<project>-session-<id> main
# write docs/feedback/<project>/session_<id>.md
git add docs/feedback && git commit -m "Feedback from <Project>: <one line>"
```

## What a finding says

Each numbered finding, from the project's side only:

1. **What happened**, concretely: the symptom, how it was misread at
   first, how long it cost.
2. **What broke without it**: the rule the project had to learn.
3. **What the project wants**: the change, described as behaviour, and
   the project file that already does it (the reference).
4. **Tooling stamp**: the first line of `tools/TOOLING_VERSION` at the
   top of the file, once.

Say what you would delete on the day Kombucha has it (a hook override,
a local check), so the sync afterwards knows what became redundant.

## What a finding does not do

**Do not read Kombucha to write it.** Do not open Kombucha's harness,
scripts or docs to check whether the thing already exists, whether it is
easy, or how it should be built there. A project reporting from its own
experience is the signal; a project that has read Kombucha reports what
it guessed Kombucha has, and that assessment goes stale the day it is
written. Kombucha's session reads the report against its own current
state, decides per finding, and appends a **Disposition** section to the
same file: done, deferred, split, or not ported, and why. That section is
Kombucha's to write, never the project's.

Findings that turn out to be already fixed cost nothing; findings that
were never written cost the next project the same debugging pass.

## Template

```markdown
# Feedback from <Project> — session <id>

Source project: `~/godot-projects/<Project>`, on tooling `<sha>`
(synced <date>). <One or two lines on what the session did.>

## 1. <Short title> (<tooling bug | kit change | rule | observation>)

<What happened, and what it cost.>

<What breaks without it.>

Wants: <the behaviour>. Reference: `<project file>` `<function>`.
Delete on sync: <the override or local check that becomes redundant>.

## 2. ...

## What not to port

<Project decisions that shaped the above but are the project's own.>
```

`froggame/session_011iWApC2cXzNibzH87ZQbNN.md` is a complete example,
disposition included.
