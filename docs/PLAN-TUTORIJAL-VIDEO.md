# Tutorials are for video: every part shows, and the student gets the film

Written 25.9.2026 by the lead (Opus), from the owner's request of the same
day. Every phase names who builds it and the gate that decides it is done.
**The owner answered §4 the same day: all fourteen decisions as recommended**
(„sve po preporuci, kreni sa fazom 0").

Every brief handed to a worker carries this sentence, in its method section:
*If you believe a test in the gate is wrong, stop and say so in the report — do
not work around it.*

Baseline measured in phase 0 (below), in a worktree (rule: measure a baseline
where nothing is being edited): app **4177** (1 skipped), backend **1737**
without a database / **1888** with, `flutter analyze` the same **23** infos
(`CLAUDE.md`, header). **The counts will fall**: most of this plan is deleted
code, and its tests go with it. Every phase ends with its arithmetic in
`docs/LESSONS.md` — what was deleted, by name, and what was added — and the
block in `CLAUDE.md` updated.

## 1. The request

The owner, 25.9.2026, translated:

> We are changing what a tutorial is for: it is only for making a video
> (export video). It can no longer be sent to a student — only the rendered
> video can. Remove the `ask_move` and `ask_choice` kinds of a part; there is
> only `show`. Everything else stays as it is: it can be sent as a task for
> the student to watch the video, or as part of a homework. We need to record
> whether the student downloaded the video; whether they watched it we cannot
> know. This simplifies many questions we had to solve before — the voice on
> the user's device used for reading, making `ask_choice` and `ask_move`
> parts, how they are played back… If a trainer wants to put a task in front
> of a student, they make an exercise.
>
> Once this is done we will agree on changing one part of the screen: the
> parts should be drawn like moves in the graphical move tree — which one
> follows from which, and whether there is a link back.
>
> P.S. I went through the tutorial items in `TODO-provera` and confirm they
> are all as we agreed — but the experience needs to be simpler.

The model in one sentence: **a tutorial is the trainer's material for a film;
what reaches a student is the film; anything that asks is an exercise.**

The second paragraph is §8 of this plan, and is to be agreed after this one
is built. The P.S. is recorded in §6, phase 6.

## 2. What exists, measured 25.9.2026

Read on `master` at `c4c6e967`. Paths: `APP` = `chess_app/lib/`,
`BE` = `chess_backend/`, `T` = `chess_app/test/`.

**A tutorial reaches a student three ways today, and none of them is the film.**

| way | where | what the student gets |
|---|---|---|
| sent alone | `POST /assignments/lesson` (`BE/routes/assignments.js:344`), from the Library row's „Send to student" (`APP/features/tutorial_studio/widgets/tutorial_row_actions.dart:88`) and the student progress screen (`APP/features/assignments/widgets/assign_lesson_dialog.dart`) | one `assignment_items` row per part (`BE/services/assignmentService.js:241-298`) |
| homework item `lesson` | `BE/services/homeworkSend.js:86-105` | the same, as a child of the homework |
| read in the Library | `READABLE_BY_READER` (`BE/routes/lessons.js`), `/lessons/labels`, `listTutorials` (`BE/services/positionLibrary.js:200-240`) | every tutorial the trainer ever saved: `POST /lessons/save` writes `trainer_id = user_id`, and a student reads rows whose `trainer_id` is an accepted trainer of theirs |

**The student walks a tutorial on their own device.** `LessonViewerScreen`
(`APP/features/assignments/screens/lesson_viewer_screen.dart`, 1271 lines):
„Next move", „Play tutorial" read aloud by the device's own voice
(`APP/services/speech_service.dart`, the voice picked by the tutorial's
language from what the device has installed —
`APP/core/services/tutorial_language.dart`, `deviceVoices`), a move question
judged by the server (`POST /assignments/:id/step/:position/answer`), „Show
me" (`…/reveal`), a list of answers. **Every part viewed or answered enrols
that part in spaced repetition** (`ensureReviewItem` → `review_items`), and
that is the only way the app ever puts a part there: Home's „Due for
review" card (`APP/widgets/home/dashboard_tab.dart:200-240`), the `/review`
route and `ReviewSessionScreen` (447 lines) exist for it alone. The SM-2
arithmetic in `BE/services/spacedRepetitionService.js` is shared —
`mistakeReviews.js` and `repertoireDrillService.js` import `schedule` and
`GRADES` from it.

**The film.** Built by the app (`APP/features/tutorial_studio/services/tutorial_video.dart`),
drawn by the server, **one per tutorial** (`saved_lessons.video_filename`).
Only its owner can fetch it (`GET /lessons/:id/video`, `BE/routes/lessons.js:1254`),
through a link signed for them and that file, valid 30 minutes
(`signDownloadToken`, `BE/middleware/auth.js:115`), opened in the platform's
browser (`launchUrl(… externalApplication)`, `tutorial_row_actions.dart:255`).
A new export replaces the file and deletes the old one
(`BE/routes/lessons.js:950-975`). Deleting the tutorial deletes its film
(`:421-441`). **And every film is deleted after 14 days** by
`cleanupOldExports` (`BE/services/retentionService.js`,
`EXPORT_RETENTION_DAYS=14` in `.env.example`), which also clears
`video_filename`. On this workstation `BE/exports/` holds 14 tutorial films,
1.8–6.4 MB each, 59.5 MB together.

**A question part is already in the film — as a board with its task written
under it**, on the part's last beat (`_captionOf`, `tutorial_video.dart:309-320`).
The answers of a list question and the solution of a move question never
appear in a film. The film's signature — what a recorded narration is checked
against (`narration_signature`) — sees a part's kind and task only through
that caption (`tutorial_video.dart:216`). So a question part turned into a
show part **whose opening sentence is its task** makes the same film, and a
recorded take over it stays valid. (Kept as a finding; since the owner's
second word of 25.9.2026 nothing stored is converted — §4.)

**A show part can carry a task and a solution the film never shows.**
„Add to tutorial" in the Library sends both (`APP/features/library/screens/library_screen.dart:489-496`);
`_captionOf` writes the task only when the part asks.

**Where question parts are made, and checked.** The studio: `Task type`
(`APP/features/tutorial_studio/screens/tutorial_studio_screen.dart:2080-2160`),
the question card, the parts panel's `Move` / `Choice` buttons
(`widgets/tutorial_sections_panel.dart:195-210`), the phone layout, and
`askHere` → `splitForQuestion` (`services/section_split.dart`, 276 lines). The
PGN import's question split (`services/pgn_question_split.dart`, 264 lines —
phase 2 of `PLAN-PGN-TUTORIJAL.md`). The JSON import
(`services/tutorial_import.dart:300-340`). The tutorial from a game
(`services/game_tutorial/skeleton_moments.dart:609-655`) and its last
dialog's `For students` / `For a video` choice, where „for a video" is
`showOnly` — the owner's rule of 14.9.2026 that a film carries no questions
(`widgets/game_tutorial_flow.dart:377-460`). Outside the app: the generation
prompt in `docs/PGN-TUTORIAL-FORMAT.md` §1 and `tools/tutorial_translate/`.
On the server: `KINDS`, `buildMoveAnswer`, `buildChoices` and
`redactStepForStudent` in `BE/services/lessonSteps.js`.

**„Preview tutorial" is the student's viewer** fed by a local fake
(`APP/features/lessons/widgets/preview_assignment_api_service.dart`) — and
**the only place a single part is turned to face the other way**
(`_setPartOrientation`, `tutorial_studio_screen.dart:714-716`; the toolbar's
flip turns every part).

**The film is a paid feature.** `POST /lessons/:id/export-video` requires
`mp4_export`, and the free tier has `ai_comments` and `assignments` only
(`BE/services/entitlementService.js:91-95`). Billing is written and tested,
and no real purchase has been made yet — it waits on Play Console.

**The room** puts a tutorial's parts on the shared board one by one
(`APP/screens/chess_game_screen.dart:1494-1515`), reading `fen` and `pgn`
only. That is the trainer using their own material, not a tutorial sent to
anyone.

**What the owner confirmed today.** The QA tool holds 29 „ok" answers of
25.9.2026 under `Home — Domaći i lekcije (My Assignments)`, most of them the
student's tutorial viewer — the behaviour this plan deletes. They were
checked, and nothing here asks for them again.

## 3. The model on one page

```
  studio / game / PGN / JSON import          Library row, student progress, homework
     every part SHOWS                          „Send" — only a tutorial WITH a film
            │                                              │
            ▼                                              ▼
  saved_lessons ── export ──► the film ◄──── assignment (kind `lesson`, ONE item)
  (the trainer's own;          one per tutorial,             │
   no student reads it)        kept while the tutorial is    │ „Download video"
                                                             ▼
                                        first complete download = done
                                        (attempted_at, homework gate, notice)
```

- **Trainer**: writes a tutorial of show parts, exports the film, sends the
  film — alone or as a homework item — and sees *Downloaded on …* or *Not
  downloaded yet*.
- **Student**: sees a video assignment, presses „Download video", can download
  it again whenever they like. The app does not play it.
- **Anyone who wants to be asked something**: an exercise
  (`PLAN-MATERIJAL.md`), unchanged.

## 4. Decisions — answered by the owner 25.9.2026: all as recommended

Where a decision offers „the other way", it was not taken.

**The owner's second word, the same day:** *the app is in testing; any
material in the database may be deleted if it is in the way, and nothing
existing has to be adapted.* That revises D7 and D11 below (marked) and
withdraws phase 1: there is no conversion, so there is nothing to prove.

**D1. Which film a student gets.** *Recommended:* the tutorial's **current**
film. A trainer who fixes a sentence and exports again after sending has the
student download the new one; a student who already downloaded keeps what
they have. *The other way:* the film at the moment of sending, kept as long
as any assignment names it — several files per tutorial, counted references,
and a delete that cannot delete. Tutorial assignments have always read the
live tutorial (`lesson_id`, no copy), so D1 changes nothing about that.

**D2. A tutorial's film is no longer aged out.** *Recommended:* the 14-day
timer skips any file a tutorial names; a film goes when its tutorial is
deleted or a new export replaces it. The timer stays for recording exports
and for files nothing names. Measured cost: 1.8–6.4 MB a film (§2). Without
this, a video sent on Monday is gone for a student who looks two weeks later.

**D3. What „downloaded" means.** *Recommended:* the server delivered the
file's **last byte** to that student, for that assignment, and the response
finished without an error — a whole download, or the tail of a resumed one.
Recorded **once**, the first time (`assignment_items.attempted_at`); a
second download changes nothing. It counts as done: the assignment
completes, the next gated item of a homework opens, and the trainer gets a
notice, worded „*Name* downloaded the video: *title*". Opening the
assignment, asking for the link or a download cut off halfway record
nothing.

**D4. A downloaded video does not wait in the trainer's review queue.**
*Recommended:* a lone video assignment is left out of „awaiting review" and
the People badge — there is nothing in it to review, and the notice has
already said it. A homework that holds a video waits as it does now, as a
homework.

**D5. Sending needs a film.** *Recommended:* „Send to student", the student
progress screen's dialog (renamed „Send a video") and a homework's send all
refuse a tutorial without one, saying „Export the video first". A homework
template may still hold such a tutorial; only sending refuses, and names it.
**Consequence for pricing**: the film is paid, so a trainer on the free tier
can no longer send any tutorial content. *Recommended:* accept it for now —
nobody has bought anything yet — and write it into `docs/CENA-I-PRETPLATA.md` as
an open question. *The other way:* a small monthly export quota on the free
tier.

**D6. A trainer's tutorials leave their students' Library.** *Recommended:*
yes — a student reads a tutorial only if it is their own. It is the one way a
tutorial still reaches a student without being sent, and without a film it
is a board a student can do nothing with. A trainer's single saved positions
stay readable exactly as now.

**D7. Stored question parts are deleted, not converted** *(revised by the
owner's second word)*. Phase 0 found two, both move questions, in one
tutorial of ten parts with no recorded take; the lead removes those two parts
at the start of phase 4, and the film is exported again whenever the owner
wants it. No show part carries a task or a solution (phase 0), so nothing
else is touched.

**D8. Tutorial assignments already sent are deleted**, after a count, with
the homework they sit in — the rule of 18.9.2026 that old sent homework may
be deleted, and a homework with a hole in it could never complete.
*The other way:* each is converted to the new one-item shape.

**D9. Spaced repetition of tutorial positions is deleted.** Home's „Due for
review", its screen, `/reviews/*`, `review_items` (dropped after a count) and
the lesson half of `spacedRepetitionService.js`. Its only source was a
student stepping through a tutorial (§2). The SM-2 arithmetic stays — two
drills use it — and an exercise already comes back when it was last failed
(`GET /exercises/queue`).

**D10. The tutorial from a game asks nothing.** The `For students` /
`For a video` choice goes, the skeleton stops making the question part, and
the question sentence is no longer paid for. What the dialog opens is what
„For a video" opens today.

**D11. A tutorial file with a question part is refused on import, naming
the part** *(revised by the owner's second word — old files are not
adapted)*. The refusal says what to do: remove the part, or make the question
an exercise. The PGN import's „questions where the review marked a blunder"
goes (a PGN comes in as show parts, as without that option today).

**D12. „Preview tutorial" goes; turning one part moves to that part's row.**
Its only job nothing else does is `_setPartOrientation` (§2) — so each row of
the parts panel gets „Turn this part", on both layouts. A trainer checks a
film by the preview stills before exporting and by the film itself.

**D13. Deleting a tutorial a student has not downloaded yet says so.**
*Recommended:* the confirmation that already offers „Download video" adds
„*N* students have not downloaded its video yet". The film goes with the
tutorial (the owner's decision of 22.9.2026), and this is the only moment the
trainer can know that it strands somebody.

**D14. Names on the wire stay.** The assignment and homework item kinds stay
`lesson` — renaming means two CHECK constraints and every reader of them, and
buys nothing a reader sees. The screens say „Video" / „Tutorial video";
`docs/GLOSSARY-EN.md` gets the term.

The room's use of a tutorial (§2) is **unchanged** unless the owner says
otherwise: it is the trainer's own material on the trainer's own board.

## 5. What goes, and what stays

**Goes — in the app:** the student's tutorial viewer and its preview fake;
„Next move", „Play tutorial", „Show me", the answer list, the speaker, the
crossed speaker and the voice chosen per tutorial language on the device;
„Due for review" and the review session; the studio's `Task type`, question
card, `Move` / `Choice`, „Ask here", recording a solution by playing it,
the answer editor and „a question carries no line" refusal; `section_split`'s
question split and `pgn_question_split`; the game tutorial's choice between
two tutorials; `LessonStepKind` and a part's `instruction`, `solutionSan`,
`acceptedSans` and `choices`. **On the server:** `/assignments/:id/step/…`
(mark, answer, reveal), `/reviews/*`, `review_items`,
`assignment_items.step_key` and `revealed_at` (read by nothing afterwards —
a column nobody reads is a rule somebody will believe), `KINDS` beyond
`show`, `buildMoveAnswer`, `buildChoices`, `redactStepForStudent`, the
question rules of `services/prompts/tutorial_words.txt` and the facts that
feed them. 34 test files in `T` name at least one of
`LessonViewerScreen`, `PreviewAssignmentApiService`, `ReviewSessionScreen`,
`ReviewApiService`, `LessonStepKind`, `splitForQuestion`,
`pgn_question_split`, `section_split`, `showOnly(`, `askHere`,
`deviceVoices` or the labels `Task type`, `Preview tutorial`,
`Due for review` (grep of 25.9.2026). On the server two test files go whole
(`lesson_step_answer`, `review_due_runs`); `lesson_step_kinds` keeps its
cases about `show`, an unknown kind and a single position; and
`spaced_repetition` stays whole — it pins the SM-2 arithmetic the two drills
use. Several more lose their lesson cases (`homework_gate`,
`homework_template`, `lesson_steps`, the `assignment*` files).

**Stays:** writing a part — moves, sidelines, sentences, arrows, squares,
glyphs, per-part orientation; the narration, synthesised on the server or
recorded by the trainer, and the take's signature; every export option and
the preview stills; PGN import and export; a tutorial from a game; moving
parts between tutorials; the tutorial's language (now only the film's
voice); labels; the Library card; homework templates; the room. The device
voice stays wherever else it speaks (endgame trainer, tactics, repertoire,
Settings) — only the tutorial routing on top of it goes.

## 6. Phases, each with its gate

Order: 0 → (2 + 3 together) → 4 → 5 → 6 → 7; phase 1 is withdrawn. Phases 2
and 3 are one release: the server stops answering the old viewer the moment
the new screen is needed, and the owner is the only user. Phase 4 starts by
deleting the two stored question parts, because from phase 4 on the app no
longer reads one. Every app phase ends with `dart format`
on what it touched, `flutter analyze` read against the 23 infos, and the full
suite with nothing else running; every backend phase with `npm test` with
`.env` moved aside and, where a route reaches the database, on a throwaway
cluster (`CLAUDE.md`, the four commands). **Server code is written in a
worktree and copied in with the owner's server stopped** — nodemon restarts on
every `.js` save, and phase 2 changes what `initDB` does to data.

### Phase 0 — the counts, and the owner's answers [lead]

Nothing changes. Read-only, on the managed database, with the owner's go
ahead:

1. Tutorials with question parts: rows, parts by kind, any with a non-empty
   `pgn` (the app refuses to save one; the server never checked), any whose
   task contains `{` or `}`.
2. Show parts carrying a task or a solution: tutorial, part, the text (D7).
3. Sent `lesson` assignments — alone and inside homework, open and completed
   — and the homework parents that would go with them (D8). Homework
   *templates* with a tutorial item are listed too; they stay.
4. `review_items` rows (D9).
5. Tutorials with a film, and which film files are on disk (D2).

Every tutorial of (1) and (2) is exported whole — `id` and `position_list` —
to the lead's scratchpad, **never the repository** (it is the owner's
material, and the repository is public). The numbers go into this section;
the owner answers §4.

**Measured 25.9.2026 — done.** One `READ ONLY` transaction, rolled back.

| | found |
|---|---|
| `saved_lessons` | 8 rows: 4 tutorials (two accounts), 4 single positions |
| parts | 32 `show`, 2 `ask_move`, 0 `ask_choice` |
| (1) question parts | both in one tutorial of 10 parts; both have a task, no line, no brace; the tutorial has a film and no recorded take |
| (2) show parts with a task, solution, answers or accepted moves | **none** |
| (3) sent `lesson` assignments | **one**, sent that day, alone (not in a homework), 10 items, none attempted; no notes; no homework template holds a tutorial |
| (4) `review_items` | **0 rows** |
| (5) films | 2 of the 4 tutorials have one, both on disk (5.7 and 2.8 MB); 12 older tutorial films on disk that no row names — tutorials deleted before 22.9, when a delete started taking the film with it; the timer, which D2 keeps for such files, removes them |

One finding for phase 2: `assignment_items.step_key` is set on 26 rows — the
10 items of that assignment and **16 „Play it out" items**. `db.js:961`
backfills `step_key` on every start for any item without a puzzle, not only
for tutorial parts. Nothing reads it there; it goes with the column.

Baseline, in a worktree at `c4c6e967`, nothing else being edited: backend
**1737** without a database (no `.env` in the worktree — CI's environment)
and **1888** with a throwaway cluster, 0 failed, 0 skipped; `flutter analyze`
the 23 known `curly_braces_in_flow_control_structures` infos; app suite
**4177**, 1 skipped, all passed (5 min 55 s).

### Phase 1 — withdrawn 25.9.2026

*Kept for the record: withdrawn by the owner's second word (§4) before it
was started. Nothing stored is converted, so the function and its proof are
not needed.* What it was to be:

#### (withdrawn) One rule for a question part, proved on every stored tutorial

`askPartAsShow` — one pure function, one home
(`APP/features/tutorial_studio/services/`): a part of any kind in, a show part
out; a task becomes the opening sentence — the root's comment, **written by
the app's own writer**, never a hand-made `{ … }`; a list's answers, a
solution and accepted moves are dropped; a show part's task and solution are
dropped (D7). `tool/tutorials_to_show.dart` reads an export, converts every
part, and for every tutorial compares the film before and after: the event
list and the film signature.

**Gate.**
- The film of each fixture part — a move question with a task, without a
  task, with a sentence already on its position; a list question; a show part
  with a task — built by the **old** code on `master`, frozen as literals in
  the test, equals the film of the converted part. The literals are computed
  before the function exists; a test that computed both sides with the new
  code could not fail.
- The converted part read back through `LessonStepLine.read` gives the task
  as the root comment, word for word, for every task shape phase 0 found.
- Mutations, each red on the right case: the task not moved; the task put on
  the first move instead of the root; the answers kept.
- The lead runs the tool on phase 0's export: **every** tutorial's film
  signature is unchanged, or the tool names the ones that are not, and the
  phase stops there.

Nothing is written to the database in this phase.

### Phase 2 — the server sends a film [lead] — built 25.9.2026

- `POST /assignments/lesson` and a homework's send refuse a tutorial with no
  film (D5); a lesson assignment gets **one** item, not one per part.
- `GET /assignments/:id` answers a `lesson` with the film's facts (length,
  resolution, when it was made, whether it is there) and **no** parts;
  `GET /assignments/:id/video` gives the student a link signed for them, that
  assignment and that file, under a purpose of its own, so an ordinary
  download link can never mark anything.
- The download route: serves the file and, per D3, stamps the item and runs
  `markCompleteIfDone`; the account must still exist (`accountGuard`, three
  answers); a film replaced since the link was issued answers „a newer video
  replaced this one — open the assignment again".
- The assignment review answers `downloadedAt`; the notice is worded per D3;
  the review queue per D4.
- Retention per D2. Readers per D6: `READABLE_BY_READER`, `/lessons/labels`
  and `listTutorials` — positions keep the trainer clause, tutorials lose it.
- Deleted: the step routes, `markLessonStepDone`, `recordLessonStepAnswer`,
  `revealLessonStep`, `lessonStepOfAssignment`, `/reviews/*` and the lesson
  half of `spacedRepetitionService.js`.
- **Data, by the lead** (the owner's standing word of 25.9.2026): D8's
  deletion — phase 0 found one sent tutorial assignment — as a one-off in one
  transaction after a fresh count (never in `initDB`, which runs on every
  start and would delete the new video assignments too); then in `initDB`,
  idempotent: `DROP TABLE IF EXISTS review_items` (0 rows), the two columns,
  their indexes and the `step_key` backfill.

**Gate** (backend; the homework cases on the real-database half):
- Sending a tutorial without a film is refused on both routes, and with one
  it makes exactly one item.
- A whole download stamps the item once and completes the assignment; a
  second leaves the first time alone; a download aborted mid-file, a `HEAD`,
  and a range that stops short of the end stamp nothing; the tail of a
  resumed download stamps. The file for the abort case is large enough not to
  go out in one write — generated in a temp directory, deleted after.
- The trainer's own download (`/lessons/:id/video`) stamps nothing; a
  student's link is refused for another student's assignment and for another
  file; a deleted student's link is refused.
- A homework whose second item is gated opens it after the first item's video
  is downloaded, and not before.
- The student's `GET /assignments/:id` carries no `pgn`, no part, no task.
- Retention deletes an old file nothing names and keeps an old film a
  tutorial names.
- A student reads no trainer tutorial through `/lessons`, `/lessons/:id`,
  `/lessons/labels` or the Library's tutorials, and still reads the trainer's
  single positions.
- Each of these watched red on `master` first, where it can be; the ones
  that cannot (routes that do not exist yet) say so in the file.

### Phase 3 — the app: the student downloads, the trainer sees it [lead] — built 25.9.2026

- `assignmentItemScreen` opens a `lesson` on a video screen: title, the
  trainer's instructions, the film's length, „Download video", and
  *Downloaded on …* once it is. Re-downloading is always possible.
- My Assignments and the homework screen say „Video" and *Downloaded* /
  *Not downloaded yet* instead of „parts viewed"; Home's „Set for me" says
  „Drills and videos your trainer set you".
- The trainer: the assignment review and the homework review show the
  download date; „Send to student" on a row without a film says „Export the
  video first" and offers the export; the student progress dialog lists
  tutorials with a film and shows the others greyed with the reason; the
  homework editor's tutorial picker marks tutorials with no film; the delete
  confirmation per D13.
- Deleted: `LessonViewerScreen`, `PreviewAssignmentApiService`, the step
  calls of `AssignmentApiService`, `ReviewSessionScreen`,
  `ReviewApiService`, the `/review` route, the „Due for review" card, the
  tutorial-language routing of `SpeechService` and `deviceVoices` — each
  symbol's readers grepped first, in `lib/`, `test/`, `test/support/` and
  `site/`.

**Gate** (widget tests, each at 360 x 640 and at a desktop width):
- The student opens a video assignment and „Download video" fetches a fresh
  link and hands it to the launcher — a fake launcher, asserted on the URL it
  was given; the screen then shows the date the server returns.
- A tutorial without a film cannot be sent from any of the three doors, and
  each says why — red on `master`, where all three send.
- An absence check scoped to Home's shortcut flow finds no „Due for review",
  and one scoped to the router finds no `/review`.
- `manual_labels_test` green with `site/` updated in the same change.

**Built 25.9.2026, both phases in one worktree, by the lead.** App
**4177 → 4076** (−115 / +14); backend **1737 → 1735** without a database and **1888 → 1891**
with one, both measured (−18 tests of deleted code, +16 fast and +5
real-database cases in `tutorial_video_assignment.test.js` and
`tutorial_video_db.test.js`). `flutter analyze`: **22** infos, the 23 known
less the one that lived in the deleted `review_api_service.dart`. Every new
case was watched red by mutation: 12 on the server's fast half, 8 on its
database half (the count of waiting downloads included), 8 on the app's.

What differs from the text above, and why:

- **„Turn this part" came into phase 3, not 4.** The student's viewer went
  in phase 3, and „Preview tutorial" was that viewer — so its one unique job,
  turning a single part, had to move the same day. On each part's row (the
  panel's action row has no pixel to spare at 840 dp), both layouts.
- **The delete dialog's count needed a server column**, `waiting_downloads`
  on every tutorial row (`routes/lessons.js`, scoped to the reader's own
  assignments). The plan listed D13 under phase 3 only.
- **The manual under `site/` changed now, not in phase 6**:
  `manual_labels_test` fails on a quoted label that is gone. Four pages and
  the landing page's line.
- **The trainer's review** shows a video item as its own card — the date,
  or `Not downloaded yet.` — and the homework row says `Video downloaded`.
- **`step_key` was written by `engine_game` items too** (`'game'`, in
  `homeworkSend.js`), besides the backfill; nothing read it there. Gone.
- **Kept:** `TutorialLanguage.vocabulary` — nothing in the app speaks a
  tutorial any more, but `spoken_moves_cases_test` ties it to the server's
  vocabularies; the SM-2 arithmetic (`spacedRepetitionService.schedule`,
  and `ReviewGrade`, moved to `lib/core/models/review_grade.dart`), which the
  two drills use.
- **Data:** the one sent tutorial assignment phase 0 found is deleted after a
  fresh count; `review_items` and the two columns drop when the server next
  starts (`initDB`).

### Phase 4 — the studio makes only show parts [lead] — built 25.9.2026

**First, the lead:** the two stored question parts (phase 0) are removed
from their tutorial in one transaction, after a fresh count shows they are
still the only ones — the owner's standing word of 25.9.2026 covers it.

**Then the code:**
- The studio: `Task type`, the question card, `Move` / `Choice`, „Ask here"
  and `splitForQuestion` go, on both layouts; a board move on a part is always
  a move. „Preview tutorial" goes and „Turn this part" goes into each part's
  row (D12).
- `LessonStepKind` and the four fields go from the part; the film's caption
  is the beat's sentence and nothing else.
- The JSON import refuses a file with a question part, naming it (D11);
  the PGN import loses its question option; the PGN export writes no kind.
- „Add to tutorial" (Library) makes the position's task the part's opening
  sentence — the one place a task still enters a tutorial, and now into
  something the film shows.
- Server: `KINDS` is `show` alone; a part that says anything else is refused
  with the sentence „A part only shows a position and a line; a question is an
  exercise"; the task, solution and answer fields are no longer stored.

**Gate:**
- A part with a line and one without both save and reopen unchanged; the film
  of every fixture tutorial in `T` without a question part is the same as on
  `master`. Fixtures that exist only to carry questions are deleted with the
  tests of deleted code.
- A JSON file whose third part is a question is refused with „Part 3" in the
  refusal, and nothing is saved — red on `master`, which imports it.
- „Turn this part" turns only that part, and the film shows it turned — red
  on `master`, where the only door is the preview.
- The server refuses `ask_move` and `ask_choice` on save, on `PUT`, on
  `/steps` and on clone.
- An absence check over the studio, scoped to the part editor, finds no
  `Task type`.

**Built 25.9.2026 by the lead, in the main checkout.** App **4076 → 3981**
(measured; −100 / +5 — the 49 in the five deleted question files derived from
the first full run, the other 51 counted case by case); backend **1735 → 1730** without a database and **1891 →
1886** with one, both measured (−18 tests of question rules, +4 in
`lesson_step_kinds.test.js`, +9 in the new
`lesson_routes_refuse_questions.test.js`). `flutter analyze`: the same **22**
infos. Every new gate case was watched red by mutation: 4 on the server
(`KINDS` admitting `ask_move`; `/steps`, clone and `PUT` each skipping the
builder's refusal), 6 in the app (the import letting a question through, or
naming the wrong part — the first form of that mutation did not compile and
was redone; the flow panel drawing „Task type" again; „Add to tutorial"
dropping the task or sending it as `instruction`), and 2 on the two rules the
question split used to hold and the line cut now does (no cut part keeps the
old text; every part keeps the orientation).

What differs from the text above, and why:

- **The data came first, as written:** tutorial 77's two `ask_move` parts
  deleted in one compare-and-set transaction after a fresh count (10 → 8
  parts).
- **„Preview tutorial" and „Turn this part"** had already moved in phase 3.
- **The game tutorial's „For students / For a video" choice went now, not in
  phase 5**: with the studio unable to hold a question, a tutorial made „for
  students" would have opened with parts nothing can edit. Until phase 5 stops
  the skeleton making question parts, `withoutQuestions` drops them where the
  run hands its result over (`game_tutorial_run.dart`).
- **The PGN import's offer to make questions from a reviewed game's mistakes**
  (`pgn_question_split.dart`, `showBlunderQuestionsDialog`) went with the
  questions; a reviewed game comes in as one demonstration.
- **The phone studio's tabs are `Line | Parts`**; `New demonstration` is a
  button, not a menu with one item.
- **The server's refusal is enforced on four doors, not in the builder only**:
  `POST /save`, `PUT /:id`, `POST /:id/steps` and `POST /:id/clone` each have a
  case that sends a question and asserts a 400 and no write, beside one that
  sends a tutorial that shows and is taken.
- **The film of the fixture tutorials was not compared byte for byte with
  `master`**, as the gate asked. What stands in for it: the caption is now
  `node.comment` alone, `tutorial_video_test` and the recording and narration
  tests are green unchanged apart from the three that asserted a task caption,
  and no fixture there had a question part. Said here rather than claimed.
- **Where a stored part still says `ask_move`** (none do after the deletion),
  the studio would open it as a demonstration of its line; no code converts
  it, on the owner's word.

### Phase 5 — the tutorial from a game asks nothing [implementer]

- `skeleton_moments.dart` makes no question part and no question slot;
  `showOnly` and the dialog's choice go (D10).
- The server's prompt loses its question rules and `tutorialWords.js` its
  question facts; the claim check for a question sentence goes with them.
- The ten recorded model answers lose their question keys — a mechanical edit
  of the fixtures, **no model is called**.

**Gate:** each of the ten games assembles with no missing and no unused slot,
and into exactly as many parts as `showOnly` gave on `master` — the ten
numbers measured on `master` first and written into the test as literals.

**Built 25.9.2026** — gate by the lead, code by the implementer in a
worktree, graded and copied in by the lead with the server stopped. App
**3981 → 4019** (+41 in `game_tutorial_asks_nothing_test.dart`; −3: the
castling question of `game_tutorial_skeleton_edges_test`, „the question mode
still refuses its answer" in `review_words_test`, and „a question that names a
move and a fork", a case generated from `answer_cases.json` whose row went —
the worker's report missed that one); backend **1730 → 1743** measured
without a database (+13 in `tutorial_words_asks_nothing.test.js`), **1886 →
1899** with one, derived (the new cases are pure). `flutter analyze` the same
22 infos. `export_fixtures.py --check` exits 0.

What differs from the text above, and why:

- **„No unused slot" was wrong for two games.** Measured on master, g01 leaves
  4 slots unused and g03 3, all lead-in moves cut where two moments overlap —
  nothing to do with questions. The gate holds each game to master's own list.
- **The gate's literals are a hand-written file**,
  `test/fixtures/game_tutorial/show_parts_on_master.json` — every part's FEN
  of both tutorials as `withoutQuestions` handed them over on master — not
  the harness's fixtures, which this phase regenerates. Parts per game (key
  moments / whole game): 9/11, 9/11, 11/13, 8/10, 8/10, 11/13, 10/12, 6/8,
  9/11, 10/12; all ten equal after. Watched red on master: 40 of 41 cases
  app-side, 12 of 13 on the server.
- **Three places, not two.** The question part was made by the Python harness
  (`tools/game_annotate/skeleton.py`, the fixtures' source), the Dart port and
  the server's prompt; all three changed, and the prompt's premise now says
  video („the board plays the moves, and every sentence is read aloud")
  rather than a student walking a board alone.
- **The recorded answers lost 22 question slots** (1–3 per game), checked by
  script to be the only change; the local run folders under
  `tools/game_annotate/out/` (ignored) were edited and re-assembled the same
  way.
- **The server takes an old app's `asks` / `correct` and drops them** — a case
  holds the prompt identical with and without them.

### Phase 6 — the words [lead]

The manual under `site/` (`for-students.html`, `write-a-tutorial.html`,
`student-progress.html`, `mislisha.html`), `PGN-TUTORIAL-FORMAT.md` §1 (the
prompt makes show parts only) and its rules 9–10, `tools/tutorial_translate/`
(no task or answers to translate), `UPUTSTVO-STUDIO.md`, `GLOSSARY-EN.md`
(D14), `CENA-I-PRETPLATA.md` (D5).

`TODO-provera.md`: the items this plan makes untrue — the whole of
`Teach — Tutorijal — kako ga vidi učenik` (9 open) and
`Home — Ponavljanje u razmacima` (2 open), and item by item the tutorial
viewer in `Home — Domaći i lekcije`, the questions in `Teach — Tutorial
studio`, `Teach — Tutorijal — uvoz iz fajla` and `Analyse — Tutorijal iz
partije` — go to the archive as superseded by this plan, with the owner's
confirmation of 25.9.2026 recorded beside them. **Their text is not edited**:
the QA tool matches on it.

**Built 25.9.2026 by the lead.** Docs and tooling only; the counts are
unchanged (app 4019, backend 1743 / 1899).

- **`site/`**: phase 3 had already rewritten the four pages; what was left
  was the landing page's description („tutorials a student walks alone"),
  the student page's description and lead and its index line („what comes
  back for review"), and **two pages that sent the reader to a „Review" card
  on Home** (`practice.html`, `repertoire.html`) — untrue before this plan
  too, since that card was fed only by tutorial parts (§2). Mistakes come back
  in „My mistakes", repertoire positions in the drill. `manual_labels_test`
  green, and watched red on a misspelt label in the edited paragraph.
- **`PGN-TUTORIAL-FORMAT.md`**: §1's prompt makes show steps only (rule 9 is
  now „every step only shows", the old 9–11 gone, 12–13 renumbered); the worked
  example is two parts, read through `readTutorialJson` on the edited file —
  two parts, no problems; the refusal and field tables, the language paragraph
  (it picks the export's voice now; nothing in the app reads a tutorial aloud)
  and §9 follow. Every „child" sentence about a viewer went with the viewer.
- **`tools/tutorial_translate/`**: no task or answers extracted, merged or
  compared; a source with a question part is **refused**, naming the part,
  as the app's import refuses it (run on a made-up file with `merge`, which
  calls no model); two report lines that said the app reads a tutorial with a
  device voice now say the export opens on that voice; `prompt.md` loses the
  two question ids and calls its readers students of 13 and older.
- **`UPUTSTVO-STUDIO.md`**: rewritten around show-only parts — sections 3–4
  (question rules, offered answers) and the device-voice half of the voice
  section gone; „Turn this part" added; the model prompt's block has no type,
  task or answers. Its first paragraph also said the studio was Windows-only
  with a frozen editor on the phone, which had been untrue since the phone
  studio; corrected.
- **`GLOSSARY-EN.md`**: the Tutorial row, „Show" as the one kind, and
  **Video / Tutorial video** (D14); Task and Answers of a part gone.
- **`CENA-I-PRETPLATA.md`**: D5 as open question 7; the film's exemption from
  the 14-day timer (D2) in §3; §4's list.
- **`TODO-provera.md`**: **55 items** moved to the archive (862 → 807, no other
  item's text changed): 23 of the viewer in `Home — Domaći i lekcije`, all
  answered „ok" in the QA tool on 25.9.2026 and recorded so; the two sections
  that went whole (`Home — Ponavljanje u razmacima` 2,
  `Teach — Tutorijal — kako ga vidi učenik` 9); 17 in the studio, 3 in the
  file import, 2 in the tutorial from a game. Each archive copy carries
  **prevaziđeno (25.9.2026)** and the reason. **Three items stay, half untrue,
  for the owner to decide** because their text cannot be edited: [177.2]
  (expects `Due for review` on a trainer's Home), [172.3] (the lesson and
  review screens among those that must fit sideways) and [151.10]
  (`Preview tutorial` beside the icon check that still holds). **The owner
  had all three archived the same day** (807 → 804); the icon check of
  [151.10] has no item of its own since.
- **Not docs, noticed**: `chess_backend/services/lessonSteps.js` still says in
  a comment that two parts with one id make „a schedule row" ambiguous; no
  schedule row exists since phase 2.

### Phase 7 — the owner's live pass [owner]

New items from `[246.1]`, under `Teach` and `Home`, in the file's five-line
form. The ones that matter most:

- On Windows and on the phone, as the student: a video assignment,
  „Download video", the file arrives, and the trainer's device says
  *Downloaded on …* — both platforms, because the browser that downloads is
  different on each (D3 is judged by what the server saw, and this is where
  it is seen).
- A homework with a video item and a gated exercise after it: the exercise
  opens only after the download.
- An old tutorial that had questions: its film, exported again, is the film
  it was (and a recorded take still plays over it).
- „Turn this part" on one part of three, and the film.

## 7. Not in this plan

- **Playing the film inside the app**, or knowing it was watched — the owner
  ruled that out.
- **A film pinned at the moment of sending** (D1's other way).
- **Splitting an imported game into show parts at its mistakes** — the
  question split goes; a split that only shows is a new feature, asked for if
  missed.
- **Spaced repetition over exercises** — `PLAN-NAPREDAK-VEZBI.md` phase 3,
  unchanged and unbuilt.
- **Renaming the wire kind** `lesson` (D14).
- **Converting old tutorials or old tutorial files** — the owner's second
  word of 25.9.2026: nothing existing is adapted.
- **A free-tier export quota** (D5's other way), until the first real
  purchase.

## 8. Next, to be agreed: the parts drawn as a tree

**Superseded 25.9.2026 by [PLAN-MAPA-DELOVA.md](PLAN-MAPA-DELOVA.md)**, which
the owner opened from a live look at the studio and accepted as recommended the
same day; its §4 answers the five questions below. Kept as it was written.

The owner's second paragraph (§1). **Nothing decided; to be agreed once
phases 1–7 are done.** What already exists, so the conversation starts from
it rather than from nothing:

- **How parts join is already computed, from positions alone.**
  `PLAN-VRACANJE-NA-POZICIJU.md`: a part opens on a position never shown (a
  *new diagram*), on the position where the previous part ended (a
  *continuation*), or on a position already shown earlier (a *return* — the
  film already says „Back to the position after 12. Rh7"). The comparison is
  `MoveTree.samePosition`; nothing is stored, the trainer declares nothing.
- **The drawing already exists.** `VisualMoveTreeWidget`
  (`APP/features/analysis_studio/widgets/visual_move_tree_widget.dart`):
  cards joined by curved edges, pan and zoom, a top-down or left-to-right
  layout, and node looks told apart by fill and shape, never by hue.

Questions for that conversation:

1. Is a part one card, or a chain of its moves?
2. A continuation is a child. Where does a return's edge go — to the part
   whose end it reopens, or to the move in the middle of a part where that
   position was shown?
3. The film's order is the list's order. Does the tree replace the list or
   stand beside it, and how is the order seen and changed in a tree?
4. Can a part be moved by dragging it in the tree, and what does that do to a
   recorded take, whose markers name beats by index?
5. On a phone at 360 dp.
