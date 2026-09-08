# Brief — the English pivot, batch 65b: the archive, the shared widgets and the services

Written 8.9.2026 by the lead, after 65a landed clean in one round. This brief and
`docs/TASK-prevod-ostatak.md` are the whole of the context for this batch.

## Where this sits

**This is the last translation batch.** Four are done — the screens and the home
tabs; the tutorial and the assignments; the repertoire and the trainers; the
analysis studio and the scanner. **214 lines of Serbian copy are left in `lib/`
and they are all yours**, across the games archive, groups, the trainer panel,
the library, reviews, the shared widgets, `lib/services/`, `lib/core/`,
`lib/theme/` and `lib/routing/`.

When this lands, the two anchors in `docs/gates/` move into `test/`, the two
Serbian anchors are deleted, and Phase 4 of `docs/PLAN-ZAVRSNICA.md` — the
manual and the site — begins. So a word you settle here is a word the manual is
written against.

`docs/GLOSSARY-EN.md` is the contract. **Read it before you touch a file.** Its
two standing rules apply here as everywhere:

* **Tutorial** is what a trainer writes; **Session** is the live meeting in a
  room. Never write "Lesson" on a screen — in code that word already means the
  written artefact.
* **The copy addresses a player, a student and a trainer, never a child.**

## The one rule that is different from every previous brief

**Log lines ARE in scope this time, and the gate will fail you without them.**

Every brief in this series said "log lines and comments are not in scope." That
was true because none of those files had a Serbian log line. Yours do:
`gate_english_ui` reads **every string literal** on a line that is not a comment,
and it does not care that the string goes to `AppLogger`.

**17 of your 214 lines are log lines**, in these files:

```
core/services/eval_cache.dart                        1
features/reviews/services/review_api_service.dart    2
features/trainer_panel/services/trainer_panel_api_service.dart  2
services/billing_service.dart                        6
services/server_status_service.dart                  1
services/speech_service.dart                         1
services/stockfish_service_native.dart               1
widgets/desktop_shortcuts.dart                       2
widgets/matrix_filter_panel.dart                     1
```

Translate them. They are developer text, so translate them plainly and keep the
bracketed tag exactly as it is — `[Billing]`, `[Reviews]`, `[Panel]`,
`[ServerStatus]`, `[EvalCache]`, `[StockfishService]` — and keep every
interpolation. `'[Billing] Ne mogu da učitam prava pristupa: $e'` is
`'[Billing] Could not load entitlements: $e'`.

**Comments are still out of scope.** The gate skips a line starting with `//` or
`*`. Do not translate them; it only enlarges the diff.

## The vocabulary this batch adds

Everything in `GLOSSARY-EN.md` still holds. These are the words this batch is
the first to need.

| Serbian | English | Note |
|---|---|---|
| Čas | **Session** | The live meeting. `'Čas'` as a JSON fallback title, `'Snimak časa'` → `Session recording`. See trap 2 |
| Domaći | **assignment** | The trainer panel's word for homework. Matches `assignments` on the wire |
| Domaći ističe / stoji | **Assignment due** / **Assignment untouched** | Two of the panel's three alert cards |
| Nije vežbao | **Not practising** | The third card. A state, not an accusation |
| Grupa učenika | **Student group** | |
| soba, učionica | **room** | Two Serbian words, one English one. „učionica" is the same room |
| Trener / Predavač | **Trainer** | Two Serbian words, one English one. Never "coach", never "lecturer" |
| posmatrač | **observer** | Somebody watching a session without playing |
| gost | **guest** | An unsigned-in visitor who knows the room code |
| Moje greške | **My mistakes** | The mistake drill screen |
| previd, greška | **blunder**, **mistake** | As in 65a |
| ponavljanje | **review** | Spaced repetition. The screen is a **review session** |
| na redu | **due** | „Ništa nije na redu." → `Nothing is due.` |
| Lako / Srednje / Teško | **Easy** / **Medium** / **Hard** | The review grades |
| odstupanje | **deviation** | Where a played game left the prepared repertoire |
| praćen / napušten repertoar | **followed** / **abandoned repertoire** | |
| curenje u otvaranju | **opening leak** | The report screen's own name |
| uvoz partija | **game import** | |
| preskočeno | **skipped** | The import counters |
| pročitano / već postojalo | **read** / **already there** | |
| završnica | **endgame** | See trap 4 for the named endgame classes |
| Labela | **label** | |
| oznake (na tabli) | **marks** | Arrows and coloured squares together |
| prečice | **shortcuts** | Desktop keyboard shortcuts |
| naplata, pretplata | **billing**, **subscription** | |
| prava pristupa | **entitlements** | Matches `ENT.*` in the code |
| nalog | **account** | |
| prijava | **sign-in** | Never "application" |
| Narandžasta / Ljubičasta | **Orange** / **Purple** | Arrow colours. See trap 3 |
| Klasična / Klasične | **Classic** | A board skin and a piece set. See trap 3 |

If a word here is wrong, say so in the report — do not quietly use a better one.

## Scope: 55 files, 214 lines

```
  1  core/build_info.dart
  1  core/models/move_cursor.dart
  1  core/services/eval_cache.dart
  1  core/services/local_puzzle_extractor_service.dart
  1  features/archive/services/archive_api_service.dart
  1  features/library/models/library_entry.dart
  1  models/recording_models.dart
  1  screens/age_gate_screen.dart
  1  services/app_settings_service.dart
  1  services/speech_service.dart
  1  services/stockfish_service_native.dart
  1  widgets/engine_line_dialog.dart
  1  widgets/game_screen/branch_choice_sheet.dart
  1  widgets/game_selector_dialog.dart
  2  features/archive/screens/player_profile_screen.dart
  2  features/trainer_panel/services/trainer_panel_api_service.dart
  2  services/account_standing_service.dart
  2  services/local_recording_service.dart
  2  services/oauth_pkce.dart
  2  theme/arrow_colors.dart
  2  theme/board_skins.dart
  2  widgets/account_stats_card.dart
  2  widgets/desktop_shortcuts.dart
  2  widgets/game_screen/board_annotation_bar.dart
  2  widgets/game_screen/course_step_bar.dart
  2  widgets/game_screen/move_navigation_controls.dart
  2  widgets/parent_email_dialog.dart
  2  widgets/pgn_import_dialog.dart
  2  widgets/promotion_picker.dart
  2  widgets/speakable_info.dart
  3  features/archive/screens/archive_home_screen.dart
  3  features/library/widgets/course_picker_dialog.dart
  3  features/reviews/services/review_api_service.dart
  3  features/trainer_panel/models/trainer_panel.dart
  3  routing/app_router.dart
  3  widgets/matrix_filter_panel.dart
  4  services/engine_download_service.dart
  4  widgets/engine_settings_dialog.dart
  5  features/archive/screens/archive_import_screen.dart
  5  services/desktop_google_sign_in_io.dart
  5  services/server_status_service.dart
  5  widgets/save_position_dialog.dart
  5  widgets/share_position_dialog.dart
  5  widgets/stockfish_analysis_widget.dart
  6  services/billing_service.dart
  7  features/archive/screens/repertoire_diff_screen.dart
  7  features/archive/widgets/import_counters.dart
  7  features/reviews/screens/review_session_screen.dart
  9  features/library/widgets/position_picker_dialog.dart
  9  features/trainer_panel/widgets/trainer_panel_view.dart
  9  widgets/create_course_dialog.dart
 11  features/archive/screens/opening_leak_report_screen.dart
 12  features/groups/screens/groups_screen.dart
 12  features/groups/widgets/room_guests_dialog.dart
 23  features/archive/screens/mistake_drill_screen.dart
```

All under `chess_app/lib/`. Counted by `gate_english_ui` on 8.9.2026: lines
holding at least one Serbian literal. **Smallest first.**

**`lib/core/services/speech_text.dart` is deliberately NOT in the list.** It is
the lead's, and it will already be translated when you start. It is a
pronunciation table for a text-to-speech voice plus a rationale about how one
particular voice reads one particular language, and it needs a decision and a
listen rather than a translation — the same reason
`tactical_motif_detector.dart` was taken out of 65a. **Do not touch it, and do
not touch `test/speech_text_test.dart`.**

**Do not touch `chess_backend/`.** Not one file.

## One deletion

**`lib/core/services/serbian_plural.dart` has no caller left in `lib/`** — every
screen that used it was translated in batches 62–65a, and English needs two
plural forms rather than three. Delete it, together with its two test files:

```
chess_app/lib/core/services/serbian_plural.dart
chess_app/test/serbian_plural_test.dart
chess_app/test/serbian_plural_screens_test.dart
```

`grep serbian_plural chess_app/lib` before you delete, and if it finds a caller,
**stop and report it** rather than deleting anyway. The suite count will fall by
whatever those two files hold — count them first and say the number in your
report, because a falling test count is otherwise indistinguishable from a suite
that stopped running.

## The six traps in these files specifically

**1. Six of your files are named in `test/tutorial_vocabulary_test.dart`.** It
holds a frozen table of exact strings per file, and it fails if a file's copy
drifts from it. These are yours to update in the same edit:

```
lib/features/library/widgets/course_picker_dialog.dart
lib/features/reviews/screens/review_session_screen.dart
lib/widgets/account_stats_card.dart
lib/widgets/create_course_dialog.dart
lib/widgets/game_screen/course_step_bar.dart
lib/widgets/save_position_dialog.dart
```

Update **only** those six entries. Other entries in that table belong to files
outside this batch and must stay exactly as they are.

**2. „Čas" is Session, and it appears where you would not look for it.**
`features/trainer_panel/models/trainer_panel.dart` and
`models/recording_models.dart` use `'Čas'` and `'Snimak časa'` as **fallback
titles for a missing JSON field**. They are copy — a user sees them — so they
translate to `Session` and `Session recording`. But `account_stats_card.dart`
says „Kreirano sesija u tekućem mesecu", which is *already* about live sessions:
`Sessions created this month`. Do not let one become the other.

**3. Colour and skin names are the accessible label, and the owner is
colourblind.** `theme/arrow_colors.dart` and `theme/board_skins.dart` carry
names a user reads to tell two options apart when the hue does not help. Use the
plain colour word — `Orange`, `Purple`, `Classic` — never a decorative one
("Amber", "Violet", "Heritage"). Note that `board_skins.dart` has **two**
entries that both become `Classic`: one is a board skin and one is a piece set,
they live in different lists, and that is correct. If a test asserts one of
those strings is unique on screen, **report it rather than inventing a second
name.**

**4. `mistake_drill_screen.dart` names endgame classes from material keys.**
`KPRkpr`, `KRkr`, `KPk`, `KQkq`, `KBNk` and the rest are **values and must not
change**; the sentences beside them are copy and have settled English forms:
rook and pawn endgames, pure rook endgames, king and pawn versus king, queen
endgames, bishop and knight mate. If you are unsure of one, say so in the report
rather than inventing it.

**5. `screens/age_gate_screen.dart` carries one legally load-bearing
sentence.** „Ova usluga je za igrače od $kMinimumAge godina naviše." is the
refusal an under-13 sign-up gets, and the app ships as a **General Audience
product, 13+**. Keep the interpolation, address a **player**, and do not
introduce the word "child": `This service is for players aged $kMinimumAge and
over.` Do not soften it into an apology and do not add advice about asking a
parent — the whole point of that refusal is that there is no parent flow below
13.

**6. `widgets/share_position_dialog.dart` is old copy with two words for one
thing.** „Trener / Predavač" and „učionica" predate the glossary. Both trainer
words become **Trainer**, and „učionica" is the **room**. Rewrite the sentences
rather than substituting word for word — „Izaberite predavača u učionici kome
želite da pošaljete vašu poziciju sa table na uvid" is `Choose a trainer in the
room to show your position to.`

## The rules that bite

**Translate the meaning, not the words.** „Ništa nije na redu." is
`Nothing is due.`, not `Nothing is in the queue.`

**Tests are part of the string.** Hundreds of tests assert on exact copy with
`find.text`. A string changed without its test turns the suite red, and a test
changed without its string does too — both, in the same edit. `grep` the old
text across `chess_app/test/` before moving on. You may edit any test file. You
may **not** delete a test, weaken an assertion, or relax a matcher to make
something pass. If a test cannot be made green by translating it, stop and say
so — that is a finding, not an obstacle. The two `serbian_plural` test files are
the single exception, and only because the code they test is being deleted.

**A plural test is renamed, not trimmed.** 65a's `gamesLabel` test went from
three Serbian forms to two English ones and kept **all eight inputs**. Batch 64's
equivalent dropped two whole tests and the suite count fell. If you meet one,
keep every input.

**English substrings nest where Serbian inflections do not.** 65a translated
`contains('slika')` — which is *not* a substring of `slike` — into
`contains('image')`, which *is* a substring of `images`, and that assertion
silently stopped discriminating. When you translate a `contains` or an
`isNot(contains(...))`, ask whether the new string can also match the case the
test is supposed to rule out. Report any you find; do not leave one silently.

**The gate cannot see Serbian in a test.** `gate_english_ui` reads `lib/` and it
matches on `šđčćž`. Five assertions in commit `b694d3b` had no diacritic at all
— `contains('Beli')`, `contains('otvorenu')`, `contains('je otvorena')` — and
only the suite found them. Grep the tests for the **old Serbian words**, not for
accented letters.

**Values are not copy.** API paths, JSON keys, status strings, the material keys
in trap 4, `'w'`/`'b'`, entitlement ids, and anything compared against a server
response stay exactly as they are. The test: would the app still work if the
server had never heard of this string? If yes, it is copy.

**If a file named above is missing, stop and say so.** Do not substitute the
nearest plausible file.

## What already exists

* `docs/GLOSSARY-EN.md` — the terms, the pair, the register rule.
* `docs/gates/vocabulary_en_test.dart` and `docs/gates/screen_names_en_test.dart`
  — the anchors for the whole pivot. **Not** in `test/` and not to be moved
  there: the lead moves them when this batch merges. Run them to see how you are
  doing; **this is the batch that should make them go green**, so a failing
  assertion in one of them is a real finding rather than an expected leftover.
  Say in your report which of their assertions still fail, if any.
* `AppFeedback` — every user message goes through it. A raw `ScaffoldMessenger`
  fails a test.

## How this is graded

By machine, after you stop. Your report is evidence to read, not the verdict.

| gate | passes when |
|---|---|
| `english ui` | no Serbian letter left in any string literal in the 55 files |
| `flutter test` | the count you measured **before**, less whatever the two deleted `serbian_plural` test files held. Say both numbers |
| `flutter analyze` | 29 infos, no errors, no warnings |
| `dart format` | every file you touched is formatted |
| `strings` | steps aside for these 55 files, grades the rest as usual |
| `contrast`, `idioms`, `scale`, `worktree` | unchanged — this batch moves no widget |

Measure the test count yourself, before and after. Do not trust a number quoted
at you.

**Run the whole suite at most once, at the end.** Translate the files, grep the
tests, fix what you find by reading, and run the suite once when you are done.

## What the report must contain

Numbers you computed in this run:

1. Test count **before** and **after**, both measured by you, **and how many
   tests the two deleted `serbian_plural` files held** — the three numbers have
   to add up, and that is the only reason a falling count is acceptable here.
2. Analyzer count before and after, and whether the list changed.
3. Per file: how many literals you translated. **Call them what they are.** The
   last report's per-file table was honest arithmetic — `git diff --numstat`
   added lines — under the label "translated literals", where the real literal
   count was less than half of it. A true number under a false name costs more
   to catch than an invented one.
4. Every **test file** you edited, and why.
5. Every sentence you had to **rewrite rather than translate**, and every
   `contains` whose English version might match something its Serbian version
   could not.
6. Every term in the table above that turned out to be wrong or missing, and
   every endgame name you were unsure of.
7. Which assertions in the two `docs/gates/` anchors still fail, if any.
8. **Anything this brief got wrong.**

**Write only what you did.** Three reports in this series have had accurate
numbers and one invented section each — buttons that exist nowhere, copy that
was never written, a scanner message about "low lighting" for a feature that
never looks at an image. Nothing was built on any of them and the gates never
read them, but each cost the reviewer an hour proving it was fiction. **Quote
nothing you have not just grepped.** A short report that is entirely true is
worth more than a thorough one that is not.

## Out of scope

Everything not in the 55 files: `chess_backend/`,
`lib/core/services/speech_text.dart` and its test, the anchors in `docs/gates/`,
the legal texts. Do not commit. Do not branch. Do not `git add`.
