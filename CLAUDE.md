# CLAUDE.md

Chess coaching platform: a Flutter client (`chess_app/`) and a Node backend
(`chess_backend/`). A trainer runs a live lesson in a room — board, voice, and a
silent replay of the lesson's move timeline — plus puzzles, homework, spaced
repetition and parent reports. Audio is recorded only by an adult alone in a
room, making their own teaching material. Most users are children, which decides
several rules below.

## Layout

| | |
|---|---|
| `chess_app/` | Flutter client. Android + Windows are the real targets |
| `chess_backend/` | Express + Socket.IO + PostgreSQL (managed, DigitalOcean) |
| `docs/` | Handoff and planning docs — read `STANJE-RADA.md` first |
| `deploy/` | Server provisioning scripts, idempotent, run as root |
| `puzzles/` | One-off import tooling and datasets, not part of the app |

## Commands

```bash
cd chess_app && flutter test          # 989 tests, 1 skipped, rest green
cd chess_app && flutter analyze       # exits 1 on 29 known infos — read the list
cd chess_backend && npm test          # node --test, 751 tests, all green
cd chess_backend && npm run dev       # nodemon, port 3000
```

Both counts measured 31.8.2026, after the first live pass through the
repertoire trainer. They are here so a suite that quietly stops running half of itself is
visible; if the number you get is lower, find out why before carrying on.

The one skip is the golden screenshot group, skipped unconditionally in
`dart_test.yaml`. `--tags golden` alone does **not** run it — that selects the
tests and the skip still skips them, so the run exits 0 saying "All tests
skipped". Run them with `flutter test --tags golden --run-skipped`.

**`flutter analyze` does not exit clean, and has not for a long time.** It
reports 29 issues, every one of them `info` level and every one of them
`curly_braces_in_flow_control_structures`, spread over
`positional_evaluator_service.dart`, `tactical_motif_detector.dart`,
`game_analysis_walker_service.dart`, `review_api_service.dart`,
`ai_studio_screen.dart` and `matrix_filter_panel.dart`. This file used to say
"must be clean", which is worse than saying nothing: it makes a red exit code
look like the normal state, so a real error added tomorrow reads as the same
failure as today's. **What must hold is zero errors, zero warnings, and no new
infos — compare the list, not the exit code.** Clearing the 29 is a fine
standalone chore and would restore the simpler rule.

Run `dart format` on any Dart file you edit — CI does not enforce it, but the
formatter reindents aggressively and an unformatted file turns the next diff
into noise.

## Rules that bite

**The repository is public.** Never put secrets, IP addresses, email addresses,
account or cluster identifiers into `docs/`, comments, or commit messages. Real
values belong in `.env` on the machine that needs them. `.env.example` is the
authoritative list of environment variables — add new ones there, and the
deploy script picks them up automatically.

**`chess_backend/uploads/` is the only copy of every recording made.** It is
gitignored, it is never deleted by cleanup code, and it must never be committed.
Rendered MP4 exports are different: they are reproducible, so they age out on a
retention timer.

Since 26.8.2026 it can no longer hold a child's voice: audio is accepted only
from a room whose sole occupant is its adult owner (`services/
recordingConsent.js`). That is the reason the rule exists — `uploads/` is the
one thing here that cannot be reproduced, anonymised or taken back.

**The backend requires Node >= 22.15.** The Lichess puzzle import uses
`zlib.zstd*`, which does not exist before that. This already cost one silently
red CI pipeline.

**The branch is `master`**, and it is the default branch. CI (`.github/workflows/
ci_cd.yml`) triggers on pushes to it and builds an APK artifact after the tests.

**Never name the product "Chess Master" or "Chessmaster"** in anything
user-facing — it is Ubisoft's brand. The application id is
`rs.pejovic.chesscoach`, deliberately decoupled from whatever the brand ends up
being.

**Language:** the user writes in Serbian and reads English, so **reply in
English** and write new `docs/` in English. Code comments and commit messages
are English, as before. Two things stay Serbian no matter what: user-facing
strings in the app, because the users are Serbian children and trainers, and the
legal texts (`docs/politika-privatnosti.md`, `docs/saglasnost-roditelja.md`),
because a lawyer approved that exact wording for Serbia. The existing Serbian
docs stay Serbian — follow whichever register a file already uses, and translate
one only when asked to.

## The recurring bug in this codebase

Steps that skip silently, report success, and fail one layer or one run later.
It has appeared five times: `zlib.zstd*` missing on old Node, a `certbot` guard
that skipped reinstalling TLS and dropped the host to port 80, `sed s/^KEY=.*/`
doing nothing when the key is absent, an unverified database certificate that
looked exactly like a verified one, and a `server.js` that did not parse — two
`const seat` in one block — while `npm test` stayed green, because the two tests
that look at that file read it as **text** and search it for a function name.
`test/sources_compile.test.js` now compiles every server source, and a second
test asserts `server.js` is actually in the walk.

Two more, both on 25.8.2026. A token outlived the account it named: `jwt.verify`
proves this server issued the slip and nothing else, so a deleted account kept a
working login for the rest of its seven days — and after a `RESTART IDENTITY`
the same slip was a credential for whoever inherited the id. Every gate now asks
whether the row is still there (`services/accountGuard.js`), with **three**
answers, since "the database did not answer" must not read as "you were
deleted".

A message must never be able to take down the action it reports on. Twice now:
playback that never started because a failing audio call sat in front of the
timer, and a recording that would not stop for a child whose parent had refused
it, because `showSnackBar` threw first. **Do the thing, then say it** — and say
it through `AppFeedback`, which cannot throw. All 82 raw
`ScaffoldMessenger` calls in `lib/` were moved onto it on 25.8.2026, and
`test/app_feedback_guard_test.dart` fails if one comes back. That sweep found
the guard itself still throwing: the helpers built their `SnackBar` — and with
it `context.colors`, which is `Theme.of(context)` — *before* the mounted check
and the `try`, so an ancestor lookup ran in front of the guard against ancestor
lookups. `_show` now takes a builder and builds inside. Same lesson as the one
below: prove a guard by mutation before believing it.

And the guard written for it did not guard: it read a fixed 1600 characters from
the start of each function, which ran into the next one, so removing the check
still matched — in a different function. **Read a function body by matching
braces, never by slicing, and prove any source-reading test by mutation before
believing it.**

When adding a guard or a fallback, prefer a loud failure. `DB_CA_PATH` pointing
at a missing file deliberately kills the process rather than downgrading to an
unverified connection — copy that instinct.

## Two ways a Flutter release build hides a mistake

Both cost time on 20.8.2026, and neither shows up in tests, in `flutter
analyze`, or in the log.

**A release build paints no overflow warning.** In debug, a `Row` wider than the
screen gets the yellow-and-black stripes and an assertion. In release it is
simply clipped: the row looks shorter than it is and the buttons past the edge
are unreachable. Three of these were found by looking at a phone — the move
navigation strip, the Analysis Studio's app bar, and the notifications dialog,
which had a fixed content width of 360 on a 360 dp phone. Where a row can grow,
use `Wrap`; where a width is fixed, take it from `MediaQuery` instead. A widget
test at `Size(360, 640)` catches it, because in a *test* build the overflow does
throw.

**`flutter build windows` can ship a stale icon font.** Icons are tree-shaken
into `MaterialIcons-Regular.otf`, and that file is not always regenerated when
new icons are referenced: two builds in a row kept a font from before the icons
were added, so `Icons.handshake` and `Icons.chat_bubble_outline` rendered as
nothing at all. Icons already used elsewhere in the app kept working, which is
what makes it look like a problem with those two icons. If a newly added icon
comes out blank, check the timestamp:

```bash
stat -c '%y %s' chess_app/build/flutter_assets/fonts/MaterialIcons-Regular.otf
```

Delete that file and build again. `build_and_deploy.ps1` (Android) regenerates
it, so the same build can be right on the phone and wrong on Windows.

## Where things are written down

- `docs/STANJE-RADA.md` — the handoff document, and the only one worth reading
  whole. What is still live: where we are, what is open, what is next, and the
  rules that still hold. Read it before proposing work; much of the obvious
  backlog is already done.
- `docs/arhiva/` — closed history split out on 27.8.2026, in two files: the
  handoff doc's finished sections (fixes with a ✅ and a date, measurements, the
  routes by which the current shape was reached) and the verification items that
  are closed in full. **Never read an archive file up front.** `grep` it when you
  need the *why* of an older decision, or the evidence that something passed,
  and read only the section you hit.
  Item numbers in `TODO-provera.md` were deliberately **not** renumbered when it
  was split — other docs cite them by number ("stavka 27"), so gaps in the
  numbering are expected, not a mistake.
- `docs/TODO-provera.md` — features that pass tests but have never been watched
  running. Ticked off only after the user confirms live.
- `docs/TODO-objavljivanje.md` — publishing steps, in dependency order.

Keep these current as part of the work, not afterwards. When something is
verified live, say who verified it and when. New entries go in
`docs/STANJE-RADA.md`; move one to `docs/arhiva/` once it is done, verified, and
nothing upcoming depends on reading it.

**These docs are big, and reading one whole is a real cost.** `TODO-provera.md`
is 75 KB and `TODO-objavljivanje.md` 45 KB — roughly 22k and 14k tokens, more
than that in Serbian. `grep` for the item you need and read around the hit;
slurping all three costs more context than the code they describe. The handoff
doc was 242 KB and `TODO-provera.md` 101 KB until they were split, which is why
every session used to open above 150k tokens before doing any work.

## Server

A provisioned droplet exists (`chess-backend-ams3`, Ubuntu 26.04 LTS, AMS3) with
nginx, a TLS certificate and a `chess-backend` systemd unit. **The service is
deliberately stopped and disabled**: while the app still points at a local
backend, two servers on one database split `uploads/` and live session state.
The switch happens in one direction, once a domain is chosen — the current
hostname is an interim `sslip.io` name.

`deploy/provision.sh` sets up the base system, `deploy/app-setup.sh` the
application half. Both are idempotent and both are meant to be re-run; that is
how two of the bugs above were found.

**Do not close port 80.** The backend is on `api.chesstrainers.app`, whose
certificate renews itself over HTTP-01 — that check reaches the host on port 80
and nowhere else. `.app` is HSTS-preloaded, so browsers never use plain HTTP and
closing 80 looks like tidying up; it silently breaks renewal, and the site
disappears three months later. Same shape as everything in the section above.

## Consent: built, and where it still has holes

*Trainer* is a position in a relationship, not a property of a person, so
`users.role` plays no part in teaching — the same account is a trainer in one
edge and a student in another. `users.role` survives only for `'admin'`.

A `trainer_students` row grants nothing until `status = 'accepted'`, and either
side may start the request; the sender chooses which capacity they are claiming.
**Verified live by the user on 17.8.2026**: invitation, greyed-out pending row,
acceptance, and assigning a lesson immediately afterwards.

Rights are read through exactly two places, and new code must use them rather
than write the condition again:

- `trainerOwnsStudent` (`services/assignmentService.js`) — homework, reports.
- `acceptedTrainersOf` (`services/relationshipService.js`) — anything a student
  reads *because* someone teaches them.

Three hand-written copies of that second subquery all forgot the status, so an
unanswered request already unlocked the sender's lessons. A test reads the source
and fails if a fourth copy appears.

**The parent half is built** (25.8.2026, not yet watched running). A minor's
relationship stops at `awaiting_parent`, the parent confirms through a link to a
page this backend serves, and `parent_consent_at/ip/version` are written from
that page — not from a code read out to a child, which proves a mail arrived and
nothing more. The age threshold (`AGE_OF_CONSENT`) and the text version
(`PARENT_CONSENT_VERSION`) are configuration, because a lawyer confirmed the
wording on 25.8.2026 **for Serbia only, and said so explicitly**; the country
list in Play Console is a decision somebody has to make rather than a default to
accept. Two rules that came out of it and hold generally: an age is read when an
edge is created and never applied backwards over edges that exist — **tell the
trainer, do not rewrite their lesson** — and the parent is asked **two**
questions rather than three.

The third question — recording the lesson — was removed on 26.8.2026, one day
after it was built. `parent_allows_recording` had spent its first hours written
by the parent's page and read by nobody; the enforcement written for it worked,
and then the feature it enforced was deleted. **A lesson is not recorded at all
any more, by anybody, under any consent.** The replay survives, silently: a
recording is a `timeline_json` and `audio_url` was always nullable.

The reasoning, because it generalises: the feature bought a replay with sound
and cost a per-market legal text about children's voices plus the worst breach
this project could have had. Removing it barely shrank the consent machinery —
that is driven by minors *having accounts*, not by recording — but it removed
the one artefact that could not be taken back. **Exposure falls by holding less,
not by getting an opinion that holding it is allowed.**

Still open: the account-level lock (a minor with no trainer uses the app as
before, since the approved text is per-trainer), and parent observation of a
lesson, which is designed (`docs/STANJE-RADA.md`, "Dogovoren model uloga i
nadzora") and not built.
