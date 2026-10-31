# Giving Kombucha feedback from a project

When a project hits a problem in the tooling or the kit, the project writes
it up here. Kombucha then decides what to do with it. The two jobs stay
apart on purpose: **the project reports what it hit, and Kombucha judges it.**

## Where and how

Write one file per session: `docs/feedback/<project>/session_<id>.md`.
Commit it in Kombucha on a branch named `feedback/<project>-session-<id>`,
and leave it there for a Kombucha session to pick up. Change nothing else
in Kombucha on that branch. Name the project's own files by path as the
reference implementations. Do not copy code into the report.

```bash
cd ~/godot-projects/Kombucha
git checkout -b feedback/<project>-session-<id> main
# write docs/feedback/<project>/session_<id>.md
git add docs/feedback && git commit -m "Feedback from <Project>: <one line>"
```

## What a finding says

Write each numbered finding from the project's side only:

1. **What happened.** Give the symptom, how it was first misread, and
   how long it cost.
2. **What broke without it.** Give the rule the project had to learn.
3. **What the project wants.** Describe the change as behaviour. Name the
   project file that already does it (the reference).
4. **Tooling stamp.** Copy the first line of `tools/TOOLING_VERSION` once,
   at the top of the file.

Say what you would delete on the day Kombucha has the change (a hook
override, a local check). Then the sync after it knows what became
redundant.

## What a finding does not do

**Do not read Kombucha to write a finding.** Do not open Kombucha's
harness, scripts or docs to check whether the thing already exists,
whether it is easy, or how Kombucha should build it. A project that reports
from its own experience gives Kombucha the signal. A project that has read
Kombucha reports what it guessed Kombucha has. That guess goes stale the
day the project writes it.

Kombucha's session reads the report against Kombucha's current state and
decides on each finding. The session appends a **Disposition** section to
the same file: done, deferred, split, or not ported, and why. Only Kombucha
writes that section, never the project.

A finding that turns out to be fixed already costs nothing. A finding
nobody wrote costs the next project the same debugging pass.

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
with its disposition.
