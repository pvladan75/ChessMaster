# Brief — the English pivot, batch 2 of 3: the tutorial, lessons and assignments

Written 8.9.2026 by the lead, after batch 1 landed. This brief and
`docs/TASK-prevod-tutorijal.md` are the whole of the context for this batch.

## Why this batch is the one that matters

Batch 1 translated the screens. This one translates **the feature the whole
vocabulary was written for**: the tutorial a trainer writes, the live session
they run, the assignment a student receives, and the report a parent reads.

`docs/GLOSSARY-EN.md` is the contract. **Read it before you touch a file.** Two
of its rules decide most of the work here, and both are new since batch 1's
brief was written.

### The pair

* **Tutorial** — the thing a trainer *writes*; a student walks it alone,
  whenever they like. Asynchronous.
* **Session** — the thing a trainer *runs*; trainer and student in a room at the
  same time, on one board, with voice. Live.

Serbian froze this as „Tutorijal" and „Čas" on 6.9.2026, after one word had
meant both — so „Poziv na lekciju" (a room opening this minute) and „Zadaj
lekciju" (homework for Thursday) read as the same event. **Every „čas" in these
files is a Session and every „tutorijal" is a Tutorial.**

**Never write „Lesson" on a screen.** In code, `lesson` already means the
tutorial — `saved_lessons`, `LessonStep`, `LessonViewerScreen`,
`LessonApiService` — and these are exactly the files where that word is
everywhere in identifiers. Identifiers keep their names. Only copy changes, and
copy says Tutorial or Session.

### Who the interface talks to

**The copy addresses a player, a student and a trainer. It does not address a
child.** The app ships as a General Audience product, 13+, and an interface
that says „child" in every second sentence reads as child-directed to a store
reviewer whatever the listing says.

The Serbian you are replacing says „dete" freely — it was written for a Serbian
audience of children. Translating those sentences **is** where the rule gets
applied: „Dete bi videlo odgovor" becomes `The student would see the answer`.

„Child" survives in exactly one place in this batch: **`parent_report_dialog.dart`
and anything else explicitly about parental supervision.** There a parent is
being told about their child, and a euphemism would be worse.

## Scope: 21 files, 232 lines

```
 1  features/tutorial_studio/widgets/tutorial_flow_panel.dart
 1  features/tutorial_studio/widgets/tutorial_pgn_panel.dart
 2  features/tutorial_studio/services/tutorial_draft_service.dart
 3  features/assignments/widgets/assignment_detail_gate.dart
 5  features/tutorial_studio/widgets/tutorial_sections_panel.dart
 7  features/assignments/widgets/assign_lesson_dialog.dart
 7  features/assignments/widgets/create_assignment_dialog.dart
 8  features/assignments/screens/custom_assignment_overview_screen.dart
 8  features/assignments/screens/lesson_viewer_screen.dart
 8  features/assignments/screens/my_assignments_screen.dart
 8  features/assignments/services/assignment_api_service.dart
 8  features/assignments/widgets/parent_report_dialog.dart
 8  features/assignments/widgets/trainer_student_archive_view.dart
 9  features/lessons/services/lesson_api_service.dart
12  features/assignments/screens/custom_puzzle_solver_screen.dart
16  features/assignments/models/assignment.dart
19  features/assignments/screens/assignment_review_screen.dart
19  features/assignments/screens/student_progress_screen.dart
19  features/lessons/widgets/lesson_step_editor_panel.dart
24  features/tutorial_studio/widgets/tutorial_library_card.dart
40  features/tutorial_studio/screens/tutorial_studio_screen.dart
```

All under `chess_app/lib/`. Counted by `gate_english_ui` on 8.9.2026: lines
holding at least one Serbian literal. **Smallest first**, so that running short
of time leaves finished files behind rather than twenty-one half-done ones.

**Do not touch `chess_backend/` at all.** Not one file. **Do not touch
`lib/features/repertoire/`, `lib/features/puzzle_trainer/`, or anything else
outside the list** — that is batch 3.

## The four traps in these files specifically

**1. `assignment.dart` is a model, and half its Serbian is not copy.** It holds
the wire names for the three kinds of part — `'show'`, `'ask_move'`,
`'ask_choice'` — and status values the server sends. Those **stay exactly as
they are**: every tutorial already saved on a student's device carries them. The
test is the one from the glossary — would the app still work if the server had
never heard of this string? If yes it is copy.

**2. The two API services hold both.** An error message a user reads is copy; a
path, a header, a JSON key and anything compared against a response is not.
`'Tutorijal nije pronađen ili nemate dozvolu za izmenu.'` is copy — it is what
the screen shows. `'position_list'` is not.

**3. `test/screen_names_test.dart` will fail, and it is not broken.** It carries
an allowance list containing `"'Studio za tutorijal'"`, because that was the one
place the word „studio" was allowed to be a screen name. When you translate that
title to `'Tutorial Studio'`, update the allowance in the same edit. Same for
`test/tutorial_vocabulary_test.dart`, whose `_expected` table names some of the
files in this batch by their Serbian strings.

**4. `lesson_step_editor_panel.dart` is retired on Windows and live on
Android.** Translate it like everything else. It is not dead code.

## The rules that bite

**Translate the meaning, not the words.** „Nema odigranih poteza." is
`No moves yet.`, not „There are no played moves."

**Tests are part of the string.** Hundreds of tests assert on exact copy with
`find.text`. A string changed without its test turns the suite red, and a test
changed without its string does too — both, in the same edit. `grep` the old
text across `chess_app/test/` before moving on. You may edit any test file. You
may **not** delete a test, weaken an assertion, or relax a matcher to make
something pass. If a test cannot be made green by translating it, stop and say
so — that is a finding, not an obstacle.

**Plurals are decisions.** Serbian has three forms, English has two. This app
has helpers written for the Serbian ones — `_partsWord`, `_movesWord` and their
like. Rewrite them; do not leave one returning three different words.

**Log lines and comments are not in scope.** `AppLogger.log('[Lessons] …')` is
read by us, and much of the prose in these files is Serbian on purpose. The gate
skips both.

**If a file named above is missing, stop and say so.** Do not substitute the
nearest plausible file. A run on this project did exactly that once and reported
success for work nobody asked for.

## What already exists

* `docs/GLOSSARY-EN.md` — the terms, the pair, and the register rule.
* `docs/gates/vocabulary_en_test.dart` and `docs/gates/screen_names_en_test.dart`
  — the anchors for the whole pivot. They are **not** in `test/` and must not be
  moved there: they go green only when batch 3 lands, and a red suite hides the
  next real failure. Run them to see how you are doing:
  `cd chess_app && flutter test ../docs/gates/vocabulary_en_test.dart`. Some
  assertions name files outside this batch and will still fail. Expected.
* `AppFeedback` — every user message goes through it. A raw `ScaffoldMessenger`
  fails a test.

## How this is graded

By machine, after you stop. Your report is evidence to read, not the verdict.

| gate | passes when |
|---|---|
| `english ui` | no Serbian letter left in any string literal in the 21 files |
| `flutter test` | **1774 passing**, 1 skipped |
| `flutter analyze` | 29 infos, no errors, no warnings |
| `dart format` | every file you touched is formatted |
| `strings` | steps aside for these 21 files, grades the rest as usual |
| `contrast`, `idioms`, `scale`, `worktree` | unchanged — this batch moves no widget |

Measure the test count yourself, before and after. Do not trust a number quoted
at you, including the one in this brief.

## What the report must contain

Numbers you computed in this run, not a summary:

1. Test count **before** and **after**, both measured by you.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated.
4. Every **test file** you edited, and why.
5. Every place you had to choose between Tutorial and Session, and what decided
   it. This is the batch's whole risk and the reviewer will read this section
   first.
6. Every place the Serbian said something English cannot say the same way — a
   plural, a case ending, a sentence built on word order.
7. **Anything this brief got wrong.** A correction is worth more than a clean
   report.

**Write only what you did.** Batch 1's report described updating matchers for
buttons that do not exist anywhere in the repository — invented, in a report
that was otherwise accurate. Nothing was built on it and the gates never read
it, but it cost the reviewer an hour proving it was fiction.

## Out of scope

Everything not in the 21 files: `chess_backend/`, the rest of `lib/features/`,
`lib/screens/`, `lib/widgets/`, the anchors in `docs/gates/`, the legal texts.
Do not commit. Do not branch. Do not `git add`.
