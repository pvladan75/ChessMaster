# Brief — Preparation, phase 9: „Translate…" on a tutorial

`docs/PLAN-PRIPREMA.md` — read §4's **D6**, **D8** and **D9**, and phase 9
under §6. The server half is built and graded by the lead; this is the app's
half: „Translate…" on a tutorial's Library card and in the Tutorial Studio,
the flow behind both, and the two new counters in „Usage this month".

**Work only in the worktree you are given**, on a branch made from
`priprema-faza-9` (run `git merge --ff-only priprema-faza-9` first if your
worktree started from `master`, and check `git log --oneline -3` shows
`docs(preparation): phase 9 — the doors' brief and gate` and
`feat(preparation): phase 9, the route`). App commands run from its
`chess_app/`; run `flutter pub get` there before anything else, and before any
`dart format`. Touch nothing in `D:\Projekti\chess_master` itself, commit on
your branch only, push nothing. **Never start the server.** `flutter test`
rewrites the seven generated plugin registrants under `linux/`, `macos/` and
`windows/`; leave them, the lead restores them.

If you believe a test in the gate is wrong, **stop and say so in the report** —
do not work around it. A workaround that satisfies a test without satisfying
the rule is worth less than a stopped batch. „The gate is wrong" and „here is
my fix" are graded separately. **A gate's literal text is screen text** — if
one of its sentences breaks the app's vocabulary rules
(`test/vocabulary_en_test.dart`, `docs/GLOSSARY-EN.md`), that is a fault of the
gate: stop and say so.

## What is already here, and is the lead's

- `docs/gates/tutorial_translation_doors_test.dart` — **the gate**, 9 cases.
  Copy it to `chess_app/test/tutorial_translation_doors_test.dart` and do not
  edit the copy except to report a fault. **Its head comment is the frozen
  contract**: the flow's name and parameters, the request, every key and every
  sentence it reads.
- The server (`chess_backend/routes/lessonTranslation.js`, read its head):
  `POST /lessons/:id/translate { language }` → **201** with the new
  tutorial's row (`id`, `title`, `language`, `position_list` with the step ids
  the server minted), or `{ error, reason? }` with 400 (a language not
  offered, the one it is already in, no parts), 404, 422 (`bad-translation`:
  the model's answer failed the checks twice; no copy was made), 429 (one
  translation at a time per account), 503 (not configured, or the model
  failed). It takes up to a minute or so: the model translates, and whatever
  was refused is asked for once more.
- `TutorialLanguage` (`lib/core/services/tutorial_language.dart`) — the seven
  languages and their labels. The dialog offers the ones the tutorial is not
  in, labelled by it.
- `openTutorialEditor` (`lib/features/tutorial_studio/tutorial_editor_entry.dart`)
  — how a saved tutorial opens in the studio. Phase 8's
  `recording_tutorial_flow.dart` is the nearest pattern for a flow that ends
  there: a guard set before the first `await`, a progress dialog that cannot
  be dismissed, every message through `AppFeedback`.

## The pass condition

```
flutter test test/tutorial_translation_doors_test.dart
flutter test test/library_card_doors_test.dart test/tutorial_editor_door_test.dart test/usage_screen_test.dart test/tutorial_language_studio_test.dart test/vocabulary_en_test.dart test/recording_tutorial_doors_test.dart
```

all green, **and** the full app suite at **4892 + 9 = 4901 passed, 1 skipped,
plus yours** (say how many, by file) — run with nothing else running; if a
test fails under load, rerun that file alone and report both — **and**
`flutter analyze` with the same 22 infos (all
`curly_braces_in_flow_control_structures`) and nothing new, no `// ignore`
added. Run `dart format` on every Dart file you touch. No existing test is
deleted, skipped or weakened; one rewritten must be rewritten openly, with a
comment saying which rule superseded what.

## What is built

1. **The request** — one `LessonApiService` method for
   `POST /lessons/:id/translate`, answering the new row or the server's
   sentence; a timeout long enough for the server's work (the server's model
   call alone may take 100 s, twice): say what you chose and why.
2. **The flow** — `lib/features/tutorial_studio/services/tutorial_translation_flow.dart`,
   `translateTutorialCopy(context, session:, lessonId:, language:, api:)`:
   - the dialog „Translate into…" with the languages the tutorial is not in
     (all seven when it says none), one chosen at a time, and „Translate"
     enabled only once one is; one sentence says the tutorial's words are sent
     to DeepSeek to be translated, and that the translation is a copy — the
     tutorial itself is not changed;
   - the guard against a second start is set **before the first `await`**,
     keyed by the tutorial's id, and released however the flow ends;
   - while the server works, a progress dialog that cannot be dismissed
     („Translating…");
   - 201: the copy opens in the studio (`openTutorialEditor`, on the row the
     server answered) and a message names the language by its label;
   - anything else: the server's sentence through `AppFeedback.error`, and
     nothing opens.
3. **The Library's door** — on a tutorial card, an `IconButton` with the
   tooltip „Translate…" (`Icons.translate`), for the account's own tutorials
   only (a trainer's shared one is not this account's to copy); the shelf is
   loaded again after a copy is made.
4. **The studio's door** — `tutorial-translate`, a button „Translate…" in the
   Details sheet, for both layouts. A tutorial never saved, or with changes
   not saved, sends nothing and says „Save the tutorial first — the
   translation is made of what is saved." The language passed is the
   tutorial's saved language.
5. **Usage this month** — `ai_translations` is „Tutorials translated" (a
   count), `ai_translation_tokens` is „AI translation writing" (tokens), both
   in „Also counted", placed after the AI review rows.

## Rules that are not in the gate, and are graded

- **No `Tooltip` inside another `Tooltip`, no Material `Slider`** — the
  Windows screen-reader crash (`CLAUDE.md`, 22.9 and 26.9.2026).
- Text that must be read is not clipped: the dialog at 360 × 640 shows every
  language whole.
- Every request goes through the `LessonApiService` the caller gave (a seam
  the gate cannot see is a false one), including the studio's own when it
  opens the copy.

## Cases you add

At least these, each watched red on the wrong code before green:

1. The request method: 201 answers the row; 422 and a network failure answer
   the server's sentence or a sentence of the app's, and neither throws.
2. The guard is released after a refusal: refused (422), then the same
   tutorial translated again, sends a second request.
3. The dialog at 360 × 640: every offered language on screen and „Translate"
   reachable.
4. The Library: a tutorial shared by a trainer has no „Translate…".

## What is not built

- No change to the server, the prompt or the judge.
- No voice or film for the copy (D6), no translation of a recording.
- The manual and the glossary (phase 10).

## The report

1. **What the brief or the gate got wrong**, first, with the case's name and
   what you measured. If nothing: say so.
2. The pass condition's commands, their last lines, as run by you.
3. Cases you added, by file and name, and for each the wrong code you watched
   it fail on.
4. Every existing test you rewrote, with the rule that superseded it.
5. Anything you saw that is outside this phase — reported, not fixed.

## The lead's note on the gate

Proved on `priprema-faza-9` on 27.9.2026, where the app is as on `master`
(**4892 passed, 1 skipped**, measured on phase 8's merge). Copied into
`test/` as it is, it fails to compile on exactly its two contract names — the
file `tutorial_translation_flow.dart` and `translateTutorialCopy`. With an
inert flow **all nine cases are red, each at the missing behaviour**: the
dialog's absent choices, the absent `translate-start`, the Library's absent
button, the studio's absent `tutorial-translate` (after its helper had found
and edited the title field), and the usage row's missing label. **None of it
has been watched going green.**
