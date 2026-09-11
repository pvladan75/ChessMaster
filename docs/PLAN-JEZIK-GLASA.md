# A tutorial read in its own language

Written 11.9.2026. Nothing in it is built yet.

## The decision

The owner, 11.9.2026, agreeing to all three recommendations of the proposal:

1. **A tutorial says which language it is written in**, and the app reads the
   trainer's sentences with a voice for that language. The app's own text stays
   English. This narrows the 9.9.2026 rule „nothing is spoken in Serbian, by any
   route" (`PLAN-ZAVRSNICA.md`, „Superseded on 9.9.2026"): it now holds for the
   app's own text and for a tutorial that has not said what it is.
2. **Seven languages, and only seven** — the ones whose moves the app can say
   properly: English, Serbian (Latin), Serbian (Cyrillic), German, Spanish,
   Italian, French. These are exactly the vocabularies in
   `chess_backend/services/spokenMoves.js`. A language whose moves would be read
   out in English words is not offered.
3. **No voice for the language means no reading, never the wrong voice.** The
   ▶ is not drawn and the screen says why and what to install; the tutorial is
   walked with the buttons as it is today. This is the rule the app already
   keeps for its own text (`SpeechService.pickLanguage`: „a German voice handed
   English text does not fail — it reads it with German phonetics, which is
   worse than silence because it sounds like the feature works").

**A field, not detection.** „Beli igra e4" is not reliably tellable from
English, and a wrong guess reads a whole sentence in the wrong phonetics with no
way for the listener to correct it. The trainer knows and says it once per
tutorial. `PLAN-ZAVRSNICA.md` reached the same conclusion on 8.9.2026 and said
whoever builds this should „start from the artefact-field version".

## What already exists, and what does not

| Piece | Where | State |
|---|---|---|
| One voice for everything | `SpeechService._language`, chosen in Settings | built |
| Moves turned into words | `speakable()` in `core/services/speech_text.dart`, through a `SpeechVocabulary` | **English table only** |
| Seven vocabularies | `spokenMoves.js` `VOCABULARIES` | built, used by the film |
| Serbian on a phone | Google's engine | verified live 23.8.2026 (`TODO-provera.md` line ~148) |
| Serbian on Windows | no Microsoft Serbian voice; Croatian `Matej` reads Latin Serbian correctly | verified before the pivot (`arhiva/STANJE-RADA-do-26.8.2026.md`, „Windows nema srpski glas") |
| Reading speed | `SpeechService.charsPerSecond`, measured | **one number for one voice** |
| The tutorial viewer speaks | `lesson_viewer_screen.dart`: the node's comment, and a question's instruction | two call sites, both the trainer's text |
| Tutorial columns | `saved_lessons` in `db.js` | no language |
| „A request that does not mention a column leaves it alone" | `PUT /lessons/:id`, `mentions()` | built — the new column follows it for free |

The two viewer call sites are the whole of the reading, and both are the
trainer's words. So inside the viewer everything spoken belongs to the tutorial;
the English interface voice is not involved there at all.

## The seven values

| Code (stored) | Shown as | Device voices, in order | Film voices (`_openingLanguage`) |
|---|---|---|---|
| `en` | English | `en-*` | `en-US`, then any `en-*` |
| `sr-Latn` | Serbian (Latin) | `sr`, `hr`, `bs`, `sh`, `me` | `sr-Latn-*` |
| `sr-Cyrl` | Serbian (Cyrillic) | `sr` only | `sr-RS`, `sr-Cyrl-*` |
| `de` | German | `de-*` | `de-*` |
| `es` | Spanish | `es-*` | `es-*` |
| `it` | Italian | `it-*` | `it-*` |
| `fr` | French | `fr-*` | `fr-*` |

`NULL` is the eighth state and the most common one: **not said**. It means
exactly what every tutorial means today — the voice chosen in Settings — so
nothing already saved changes behaviour. Absence is a third answer, not English
(CLAUDE.md, the orientation field: „a stored step that says nothing about its
orientation is not a step that says White").

The Latin list is the app's old `preferredLanguages` verbatim, and the reason it
was a list still holds: Windows ships no Serbian voice, and Croatian reads the
same alphabet with the same sounds. Cyrillic gets Serbian alone, because a
Croatian voice cannot read Cyrillic.

## Phase 1 — the column, on the server

**Done 11.9.2026** — backend **1226** with `.env` moved aside (+13, all in
`test/tutorial_language.test.js`), fourteen mutations, all caught. One survived
at first, and it was the one that mattered: deleting `language` from the
student route's `SELECT` left every test green, because the fake pool handed
the column back whether or not the query asked for it. The fake now returns
only what was selected, as a database does — **a fake that answers a question
nobody asked cannot see the question go missing.**

- `db.js`: `ALTER TABLE saved_lessons ADD COLUMN IF NOT EXISTS language
  VARCHAR(16);` with a comment saying NULL means not said.
- One reader of the seven codes on the server (`services/tutorialLanguage.js`,
  a frozen list and `isTutorialLanguage`), used by every route below. Not a
  regex written twice.
- `POST /lessons/save`, `PUT /lessons/:id`: accept `language`. A code outside
  the seven is **400** with a sentence naming the seven — stored and wrong is
  worse than refused. `PUT` writes it only when mentioned (`mentions()`), and an
  explicit `null` clears it.
- `POST /:id/clone` copies it: a translated copy is still in the language of the
  copy.
- `GET /lessons` names it in its column list, which is explicit rather than
  `*`.
- **The child's route**: `GET /assignments/:id` → `getAssignmentDetail` in
  `services/assignmentService.js` reads `title, fen, pgn, position_list` for an
  assignment's steps and must read `language` too, and the response must carry
  it (`lessonLanguage`). Not `assignmentReview.js` — that is the trainer's
  review of the same assignment, and this plan named it first by mistake; the
  student's viewer never calls it. This is the one that decides whether the feature
  reaches the reader it exists for, and it is the one easiest to forget — the
  trainer's list working proves nothing about it.

Tests, with `.env` moved aside: absent leaves it alone; `null` clears; an unknown
code is refused on both writes; clone copies; the list returns it; **a student's
assignment detail returns it** — driven as the student, not the trainer.
Mutation targets: the `mentions()` branch, the clone column, the assignment
column.

## Phase 2 — the pure core, in the app

**Done 11.9.2026** — app **1971** with 1 skipped (+15), backend unchanged at
**1226**, analyze 29 infos and zero warnings. `core/services/
tutorial_language.dart` and six vocabularies in `speech_text.dart`; the shared
cases are `chess_backend/test/fixtures/spoken_moves_cases.json` (76 of them,
all seven languages). Fifteen mutations, all caught. Three things came out of
it:

- **The two ends already disagreed**, before any of this: the server's
  end-of-sentence rule knew Serbian capitals (Š, Č…) and the app's knew only
  A–Z, and neither knew Cyrillic. Both carry one class now, and the shared file
  has a case for each.
- **`vocabulary_en_test.dart` failed the Serbian vocabulary**, correctly by its
  own rule and wrongly by its contract — those words are heard, not shown. It
  exempts lines inside a `SpeechVocabulary(...)` now, by structure rather than
  by file, and was **taught Cyrillic** at the same moment, since it had never
  known it and this was the first Cyrillic in `lib/`. Four probes prove it still
  fails on real copy, including a Serbian string on the line after a vocabulary
  closes.
- **One backend run of five failed two tests and was not repeatable**; which
  two is unknown, because that run printed only the totals. It fits the
  shared-`exports/` flake CLAUDE.md already records, which is a guess and not a
  finding.

The lead's own commit, before any screen touches it (CLAUDE.md, batch 59: „where
a batch has a pure core, land it as the lead's own commit").

- `core/services/tutorial_language.dart`: the seven codes, their labels, and
  `voiceFor(String code, List<String> installed) → String?` — the device-voice
  order in the table above. Pure, and tested with lists of installed tags the way
  `pickLanguage` already is.
- **The other six vocabularies in `speech_text.dart`**, ported from
  `spokenMoves.js` — which was itself ported from this file, so this is the
  words coming home, not a third implementation. `speakable(text, {vocabulary})`
  with English the default, so every existing caller is untouched.
- **One file of expected outputs, read by both suites.** Today
  `spoken_moves.test.js` carries a hand-copied list of the app's expected
  strings. Replace both sides' copies with
  `chess_backend/test/fixtures/spoken_moves_cases.json` — language, input,
  expected — read by `spoken_moves.test.js` and by a new Dart test through
  `../chess_backend/...`. CI runs both suites in one checkout
  (`.github/workflows/ci_cd.yml`, job `build`), so the path exists there too. A
  number kept in two places by a comment is two numbers; a table kept in two
  languages is two tables unless one file judges both.

Tests: `voiceFor` for each code against a phone-shaped list, a Windows-shaped
list with Croatian, one without, and Cyrillic against a list whose only
Serbian-capable voice is Croatian (it must answer none); each vocabulary through
the shared file. Mutation targets: drop
`hr` from the Latin list; let Cyrillic fall back to `hr`; let any code fall back
to `en`.

**Heard, not only asserted.** The Serbian table spells files as words („ce",
„ge"), proved on 11.9.2026 against Azure's Serbian voice. The app's old Serbian
build used bare letters because the Croatian voice named them itself. Which is
right on Google's Serbian voice and on `Matej` is a thirty-second listening
test per voice, and it goes in the live check rather than being argued here.

## Phase 3 — the model, the import and the script

**Done 11.9.2026** — app **1983** with 1 skipped (+12, all in
`test/tutorial_language_draft_test.dart`, every one reading the request),
backend untouched at **1226**, analyze 29 infos. Fifteen mutations, all caught.
The three states travel as `LanguageWrite` (`silent`, `unsaid`, a code) in
`lesson_api_service.dart`, because a nullable string can say only two of them;
it defaults to `silent`, so every caller written before sends what it sent
before. Checked end to end with the real Serbian translation from section 9 of
`PGN-TUTORIAL-FORMAT.md`: `translate.py merge --code sr-Latn` → the file →
`readTutorialJson` → a draft in `sr-Latn`, clean, four parts of four. One rule
the plan did not have: **without `--code` the script removes the field** rather
than keeping the source's — an English source translated into Serbian would
otherwise still say `en`, and be read by an English voice.

- `TutorialDraft.language`: read by `fromLesson`, written by the draft's own
  JSON (the local draft the studio flushes on dispose) and sent by
  `commitDraft`.
- **Three states on the way out.** A local draft written before this field
  existed has no key; sending `null` from it would clear a language set
  elsewhere. Missing key → the request does not mention `language`; `null` → it
  says „not said"; a code → that code. One test per state, on the **request**.
- `readTutorialJson` reads an optional `"language"`. Unknown code → a problem
  that is reported, and the tutorial is imported as not said.
  `PGN-TUTORIAL-FORMAT.md` gains the field in its prompt, its fields table and
  section 9.
- `tools/tutorial_translate/translate.py --code sr-Latn` writes it, and refuses
  a code outside the seven.

## Phase 4 — the voice, per sentence

**Done 11.9.2026** — app **2009** with 1 skipped (+26), backend untouched at
**1226**, analyze 29 infos. Twenty-one mutations, all caught. Built as planned,
with four things the plan did not say:

- **In place of the ▶ there is a reason, not nothing.** A tutorial in a language
  this device cannot read shows a „no voice" icon whose tap says why and what to
  install — the Croatian voice for Serbian in Latin script, a Serbian one for
  Cyrillic. A tutorial that has not said its language still draws nothing on a
  machine with no voice, as it always did.
- **A machine with no English voice can still read a Serbian tutorial.** Its
  language is the only question it asks.
- **The film is stricter than the device.** For the export sheet a Croatian
  voice is not a Serbian one: the server's `spokenMoves.js` has no Croatian
  vocabulary and would hand it the moves in English. Where the server has no
  real Serbian voice, the sheet opens as it always did.
- **All reading speeds are forgotten when the rate slider or the Settings voice
  changes**, not only that voice's. A superset of what the plan said, and
  simpler: a speed is re-measured from the next sentence.

Two tests were added before the mutation run, found by reading rather than by
running: nothing checked that the writing asks for the **tutorial voice's**
speed, and the test tutorial had no question part, so the question being read
without the language would have passed. And one test was made to close the
studio even when it fails — under a mutation it had left the studio mounted and
failed the test after it, through the one draft slot both share.

`SpeechService`:

- `speak(text, {language})`. No language → today's voice, unchanged, for every
  existing caller. A tutorial code → `voiceFor(code, availableLanguages)`, and
  the engine is switched to that voice before the utterance when it is not
  already on it.
- `canSpeak(String? code)` — whether the ▶ may be drawn for this tutorial. The
  viewer asks it rather than finding out mid-sentence.
- **Reading speed per voice.** `charsPerSecond` becomes a map keyed by voice,
  and the viewer asks for the rate of the voice it is reading with. Without this
  the Serbian voice's measurement is applied to the English one, and today's
  „the writing follows the voice" fix quietly stops being true for both. The
  speed slider forgets all of them; a voice change forgets that voice's.
- **Windows lists languages it has no voice for** (`_apply`'s comment:
  Croatian is offered on a machine with no Croatian voice, and setting it
  throws). So `canSpeak` can say yes and the first sentence fail. That failure
  marks the voice unusable for the session, stops the reading, and shows the
  same message as no voice at all. It must not fall through to the Settings
  voice.

The viewer (`lesson_viewer_screen.dart`) passes the tutorial's language at both
call sites and asks `canSpeak` before drawing the ▶. When it cannot:

> This tutorial is in Serbian (Latin), and this device has no voice for it. On
> Windows, add the Croatian voice: Settings → Time & language → Speech → Add
> voices. The tutorial works without it — use the buttons.

`AssignmentDetail` carries the language from phase 1's response;
`_previewAsStudent` in the studio passes the draft's.

The export sheet (`_openingLanguage`) opens on the tutorial's language when it
has one: the remembered voice if it is in that language, else the first voice of
that language, else today's order.

Tests: a Serbian tutorial speaks through the Croatian voice where there is no
Serbian one; a Cyrillic one does not; a `null` tutorial and an English one speak
exactly as today (the regression that matters most — every tutorial already
saved is one of these); the message replaces the ▶; a failing `setLanguage`
leads to the message and not to the English voice; the rate asked for is the
reading voice's. Mutation targets: fall back to `_language`; share one rate;
draw the ▶ without asking.

## Phase 5 — the control in the studio

A „Language" dropdown — „Not set" plus the seven. **Where it goes is measured,
not chosen**: the authoring pane's title row already overflowed the 840 dp
window by 24 px once when the labels field arrived (CLAUDE.md, 11.9.2026), and
the fix was to put title and labels on one row. A third control there is the
same risk. A throwaway layout probe at 840 dp and at 360 dp decides between that
row, the row under it, and the part's settings, before the gate is written.

Tests: the choice reaches the save request; reopening shows it; „Not set" sends
`null` only when the trainer changed it.

## Phase 6 — documents and the live check

- `UPUTSTVO-STUDIO.md` section 8 („Glas koji čita tutorijal") is rewritten: it
  currently says the device's voice reads everything and the trainer must match
  it by hand.
- The `SpeechService.preferredLanguages` comment and `PLAN-ZAVRSNICA.md`'s
  „Superseded on 9.9.2026" paragraph point here.
- `TODO-provera.md`, a new item:
  1. Android, Google's Serbian voice: a Serbian (Latin) tutorial is read in
     Serbian, moves included („lovac ce četiri" or „lovac c četiri" — whichever
     sounds right is the one kept).
  2. Windows with Croatian `Matej`: the same tutorial, same check.
  3. Windows without Croatian: no ▶, the sentence above, the buttons work.
  4. A tutorial with no language and an English one: exactly as before.
  5. A Serbian (Cyrillic) tutorial on Windows with only Croatian: no ▶.
  6. The export sheet opens on Serbian voices for a Serbian tutorial.
  7. The interface around the tutorial is still read in English wherever the
     app reads its own text.

## Out of scope

- Repertoire comments, custom-puzzle instructions and every other place a user
  writes text. Same mechanism later: a field on the artefact and a language at
  the call site.
- Choosing *which* Serbian voice on a device that has two. The first by the
  order above; a per-language choice in Settings if anyone asks.
- Languages beyond the seven, which need a vocabulary first.

## Counts to measure against

App **1956** with 1 skipped, backend **1213** with `.env` moved aside, analyze
29 infos — measured 11.9.2026 before any of this.
