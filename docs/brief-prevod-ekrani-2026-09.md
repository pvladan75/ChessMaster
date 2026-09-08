# Brief — the English pivot, batch 1 of 3: screens and the home tabs

Written 8.9.2026 by the lead. This brief and `docs/TASK-prevod-ekrani.md` are
the whole of the context for this batch.

## Why this exists

The app is going English-only. That is the owner's decision, taken on 8.9.2026
on the ground that the market is global and the Serbian audience too small to
carry the format. There is **no i18n layer and none is being added** — no
`flutter_localizations`, no `.arb`, no language selector. The Serbian string
literals in `lib/` are replaced in place, in three batches. This is the first.

It is first because these files hold the screen names, and the vocabulary anchor
that pins those names cannot go green until they are English.

## The contract

`docs/GLOSSARY-EN.md` is the contract. **Read it before you touch a file.** It
is short, and every term in it is a decision that has already been argued.

The one distinction the whole app hangs on:

* **Tutorial** — the thing a trainer *writes*; a child walks it alone, whenever
  they like. Asynchronous.
* **Session** — the thing a trainer *runs*; trainer and student in a room at the
  same time, on one board, with voice. Live.

Serbian froze that pair as „Tutorijal" and „Čas" after one word had meant both,
so that „Poziv na lekciju" (a room opening this minute) and „Zadaj lekciju"
(homework for Thursday) read to a child as the same event.

**Never write „Lesson" on a screen.** In code, `lesson` already means the
tutorial — `saved_lessons`, `LessonStep`, `LessonViewerScreen`,
`LessonApiService` — and an interface using it for the live thing would put a
word on screen that means the opposite of what it means in the code. Identifiers
keep their names; only copy changes.

The screens in this batch:

| Serbian | English |
|---|---|
| „Soba: 589388" | `Room: 589388` |
| „Priprema" | `Preparation` |
| „Analiza" | `Analysis` |
| „Studio za tutorijal" | `Tutorial Studio` |

`Analysis` and `Tutorial Studio` are titled in files **outside this batch**. Do
not go and change them; batch 2 does.

## Scope: thirteen files, 409 lines

Nothing outside this list is yours, and that boundary is the most useful thing
in this arrangement.

```
chess_app/lib/screens/age_gate_screen.dart            5
chess_app/lib/screens/login_screen.dart              12
chess_app/lib/widgets/home/biblioteka_tab.dart        5
chess_app/lib/widgets/home/dashboard_tab.dart        11
chess_app/lib/widgets/home/friends_tab.dart          13
chess_app/lib/screens/home_screen.dart               22
chess_app/lib/screens/replay_player_screen.dart      22
chess_app/lib/screens/shortcuts_screen.dart          23
chess_app/lib/widgets/home/home_dialogs.dart         29
chess_app/lib/screens/design_gallery_screen.dart     30
chess_app/lib/screens/settings_screen.dart           50
chess_app/lib/screens/ai_studio_screen.dart          53
chess_app/lib/screens/chess_game_screen.dart        134
```

The number is lines holding at least one Serbian literal, measured by
`gate_english_ui` on 8.9.2026. **Do them in that order** — smallest first, so
that if you run short of time the batch has finished files behind it rather than
thirteen half-done ones.

`chess_game_screen.dart` is last and is the one to be careful in: it is the
screen a live session runs on, it is four thousand lines, and it holds three
names phase 1b decided a week ago — „Priprema", „Kontrole pripreme" and
„Samostalan rad — učionica je isključena".

**Do not touch `chess_backend/` at all.** Not one file. The server stores
Serbian nowhere a user reads, and anything you change there is outside every
gate this batch is graded by.

## The rules that bite

**1. Translate the meaning, not the words.** „Nema odigranih poteza." is
`No moves yet.` — not „There are no played moves." You are writing an English
interface, not producing a gloss.

**2. Tests are part of the string.** Hundreds of tests assert on exact copy with
`find.text('…')`. A string changed without its test turns the suite red, and a
test changed without its string does too. **Both, together, in the same edit.**
This is the gate that actually grades you: the suite must come back at 1772
passing, and it will not if you miss one.

You may edit any test file. You may not delete a test, weaken an assertion, or
change `findsOneWidget` to `findsWidgets` to make something pass. If a test
cannot be made to pass by translating it, stop and say so in the report.

**3. Plurals and interpolation are decisions, not replacements.** Serbian has
three plural forms and English has two. The app has helpers written for the
Serbian ones — `_partsWord`, `_movesWord` and their like. Each is a small
rewrite: in English `1 part` / `2 parts` and nothing else. Do not leave a helper
that returns three different words.

**4. Wire values are not copy.** `'show'`, `'ask_move'`, `'ask_choice'`,
`'STUDIO'`, `'accepted'`, `'trener'`, `'ucenik'`, tag values, API paths, JSON
keys, `SharedPreferences` keys and anything compared against a server response
**stay exactly as they are**. Every tutorial already saved on a child's device
carries them. If you are unsure whether a literal is copy or a value, the test
is: would the app still work if the server had never heard of it? If yes it is
copy.

**5. Log lines and comments are not in scope.** `AppLogger.log('[Lessons] …')`
is read by us. Comments are prose explaining the code and much of it is Serbian
on purpose. The gate skips both — do not spend the batch on them.

**6. Emoji stay.** 🔬 in a label is not Serbian and the gate knows that.

**7. If a file named above is missing, stop and say so.** Do not substitute the
nearest plausible file. A previous run on this project did exactly that and
reported success for work nobody asked for.

## What already exists, and must not be reinvented

* `docs/GLOSSARY-EN.md` — the terms.
* `docs/gates/screen_names_en_test.dart` and `docs/gates/vocabulary_en_test.dart`
  — the two anchors. They are **not** in `test/` and you must not move them
  there: they are red until all three batches land, and a red suite hides the
  next real failure. You may run them to see how you are doing:
  `cd chess_app && flutter test ../docs/gates/screen_names_en_test.dart`.
  Some of their assertions name files outside this batch and will still fail.
  That is expected and is not your problem to fix.
* `AppFeedback` — every message to a user goes through it. Do not introduce a
  raw `ScaffoldMessenger`; a test fails if you do.

## How this is graded

By machine, in a worktree, after you stop. Your report is evidence to read, not
the verdict.

| gate | passes when |
|---|---|
| `english ui` | no Serbian letter is left in any string literal in the thirteen files |
| `flutter test` | **1772 passing**, 1 skipped |
| `flutter analyze` | 29 infos, no errors, no warnings |
| `dart format` | every file you touched is formatted |
| `strings` | steps aside for these thirteen files and grades the rest as usual |
| `worktree` | no platform drift, no stray files |
| `idioms`, `scale`, `contrast` | unchanged — this batch moves no widget |

`flutter test` is the one to watch. Measure it yourself, before and after; do
not trust a number quoted at you, including the one in this brief.

## What the report must contain

Not a summary. Numbers you computed in this run:

1. The test count **before** you started and **after**, both measured by you.
2. The analyzer's issue count before and after, and whether the list changed.
3. For each of the thirteen files: how many literals you translated.
4. Every **test file** you edited, and for each, why.
5. Every place where the Serbian said something the English cannot say the same
   way — a plural helper, a case ending, a sentence that only worked because of
   word order. These are the decisions, and they are what a reviewer needs.
6. **Anything this brief got wrong.** A correction is worth more than a clean
   report.

## Out of scope

Everything not in the thirteen files. Especially: `chess_backend/`,
`lib/features/**` (batches 2 and 3), the two anchors in `docs/gates/`, the
legal texts in `docs/`, and `.env.example`. Do not commit. Do not create a
branch. Do not run `git add`.
