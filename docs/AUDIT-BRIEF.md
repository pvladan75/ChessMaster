# Architecture and code audit — brief

Written 16.9.2026 for four read-only runs of the `deep-debug` agent (Fable 5.1),
one per track below. The lead (the main session) grades every finding before
anything is built from it. This file is the brief; the findings go to
`docs/audit/<track>.md`, one file per run, and are merged by the lead into
`docs/AUDIT-2026-09.md`.

## What this audit is for

Every plan in this repository looked at one feature. Nothing has looked across
the whole: the same rule written in two places, the app and the server
disagreeing about a field, code nothing reaches, a guard that cannot fail, an
access check written by hand instead of through the one place that holds it.
The lesson log (`docs/LESSONS.md`) finds these shapes one at a time, after they
cost something. The audit's job is to find the ones still waiting.

**It is not** a style review, a list of refactors that would be nice, or a
second opinion on decisions already taken (below). A finding that would take a
week and prevents nothing a user or the data would ever feel ranks last or is
left out.

## Rules for every run

- **Read-only.** No edits, no commits, no migrations, no server started, no test
  run that writes outside the scratchpad. The one file you write is your track's
  findings file.
- Read `CLAUDE.md` first, whole. Grep `docs/LESSONS.md` and
  `docs/STANJE-RADA.md` when you need the *why* of something; do not read them
  whole. Never read `docs/arhiva/` up front.
- **Every finding carries evidence**: `file:line` for each side of it, and a
  concrete way to prove it — a test that would fail, a request that would
  return the wrong thing, a query. A finding you cannot give evidence for is
  written under "Suspicions", not under "Findings".
- Before reporting something as missing, grep for it. This codebase often has
  the thing, under another name, one layer away.
- Do not count a comment as proof of behaviour, and do not count a test's name
  as proof of what the test checks.

## Decisions not to reopen

These were taken on purpose, with the reasons written down. Report a place where
the code **contradicts** one of them; do not report the decision itself.

- **The server has no PGN parser and must not grow one.** A step's `pgn` is
  opaque text there; the app's `LessonStepLine` / `MoveTree.parsePgn` is the one
  reader.
- **The app and server are English only**, no i18n. Serbian stays in voice
  vocabularies, `routes/consent.js` and its mail, server logs, `db.js` role
  values, and the legal texts — whose wording a lawyer approved and which are
  not to be edited.
- **General Audience, 13+.** No account below 13; the parental machinery covers
  13 to `AGE_OF_CONSENT - 1`.
- **A lesson in a room is never recorded.** Audio is accepted only from an adult
  alone in their own room (`services/recordingConsent.js`). `uploads/` is never
  deleted by code.
- **Trainer is a relationship, not a role.** Rights are read only through
  `trainerOwnsStudent` and `acceptedTrainersOf`, and only `status = 'accepted'`
  grants anything.
- **The opening book is local** (`services/openingBook.js`), not Lichess; no
  student needs a token.
- **A repertoire is built on the board**, move by move (`PLAN-REPERTOAR-RUCNO`).
- **No evaluation in the graphical move tree.**
- **The scope is frozen** by `docs/PLAN-ZAVRSNICA.md`; its section "What is
  deliberately not being done" lists what will not be built.
- **The droplet's service is stopped on purpose**, and **port 80 stays open** for
  certificate renewal.
- `flutter analyze`'s 26 `curly_braces` infos are known.

## Tracks

Each run takes one track. Stay inside it; a finding that belongs to another
track goes under "For another track" in one line.

### 1. The app's architecture (`chess_app/lib`)

- Rules written more than once: the same computation, threshold, list or
  vocabulary in two files, especially where one copy is older.
- Features split across `lib/features/`, `lib/screens/`, `lib/services/`,
  `lib/widgets/` and the root files (`move_tree.dart`, `pgn_parser.dart`) — where
  the boundaries are, where they are crossed, and what is dead or reachable from
  nowhere a user goes.
- State that can be adopted from two sources (device drafts, server answers) and
  what happens when they disagree.
- Optional callbacks and actions drawn where they cannot be performed.

### 2. The server: security, access and data (`chess_backend`)

- Every route: who may call it, and whether that is checked through the shared
  helpers or written by hand. Any route that reads or writes another account's
  rows.
- `uploads/` and `exports/`: what is served, to whom, and whether a path can
  escape.
- One-off scripts beside the server (`clear_users.js`, `import_*.js`): what
  they would do if run against the production database, and whether anything
  stops that.
- Migrations and startup code that change data; what runs at import.
- Secrets, logging of personal data, and anything a public repository would
  expose.

### 3. The contract between app and server

- Fields one end writes and the other never reads, or reads under another name.
- Requests that say nothing about a column: does the server leave it alone, or
  write `null`?
- Numbers kept on both ends (limits, caps, counts) and whether one derives from
  the other.
- Error answers the app cannot tell apart (404 vs 410 vs 429), and messages the
  app compares as values.

### 4. Test quality (`chess_app/test`, `chess_backend/test`)

- Tests that cannot fail: assertions of absence over a whole screen, fixtures
  shorter than reality, fakes that answer questions nobody asked, source-reading
  tests that match text rather than structure.
- Behaviour that matters to a user or to the data and has no test at all.
- Tests that depend on the machine: wall clock, installed fonts, `.env`, file
  order, parallel load.

For this track, name for each finding the **mutation** that would survive — the
change to production code that leaves the suite green.

## Output — `docs/audit/<track>.md`

```
# Audit — <track name>

## Findings
### <n>. <one-sentence claim>
Severity: critical | high | medium | low
Where: file:line (each side)
Why it matters: what a user, the data or a release would feel
Proof: the test, request or query that would show it
Fix direction: one or two sentences; no code

## Suspicions
<claims without full evidence, each with what would confirm it>

## For another track
<one line each>

## What I did not cover
<honest list>
```

**Severity** means: *critical* — data loss, another account's data, a security
hole, or a legal promise broken; *high* — a user-visible fault on a common path,
or a guard that silently does nothing; *medium* — a fault on a rare path, or
duplication that has already drifted; *low* — everything else worth keeping.
Rank by severity, then by how cheap it is to prove.

## How the lead grades it

Every finding is re-derived before it is believed: the lines read, the proof run
where it can be run. Findings are marked confirmed, wrong, or already known
(with the `LESSONS.md` or `STANJE-RADA.md` entry). Confirmed ones become entries
in `docs/STANJE-RADA.md` or phases of a plan; nothing is fixed straight from the
audit file.
