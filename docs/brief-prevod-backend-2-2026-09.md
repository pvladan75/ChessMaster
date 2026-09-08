# Brief — the English pivot reaches the server, batch 66b: the chess half

Written 8.9.2026 by the lead, immediately after batch 66a merged. This brief and
`docs/TASK-prevod-backend-2.md` are the whole of the context for this batch.

## Where this sits

66a translated the **teaching** side of the server — assignments, the
trainer/student relationship, accounts, rooms, billing: 30 files, 362 lines. It
merged as `a5fc057` and `npm test` is green at 964.

This is the other half: **puzzles, the repertoire, openings, endgames, the game
archive, the position scanner, the parent report and the AI.** 41 files, 466
lines. When it lands, no Serbian sentence is left anywhere the server can send
one to a screen.

`docs/GLOSSARY-EN.md` is the contract. **Read it before you touch a file.** Its
two standing rules hold here as everywhere:

* **Tutorial** is what a trainer writes; **Session** is the live meeting in a
  room. Never write "Lesson" in a sentence a user reads.
* **The copy addresses a player, a student and a trainer, never a child.**

## The rule that will break the app if you get it wrong

**A string on the server is either a sentence or a value, and the values are
frozen.** In the app a wrong guess makes a screen read oddly. Here a wrong guess
silently changes a contract the Flutter app compares against, and everything
keeps compiling and every test stays green.

That is not hypothetical for this batch — it is why part of it was done before
you were briefed. Three strings in these files were **both**: Serbian prose that
the app matched character for character.

* `services/customPuzzleJudge.js` returned `reason: 'drugi mat, ali mat'`, and
  `custom_puzzle_solver_screen.dart` compared exactly that to tell a student
  their different mate still counted. The same field's *false* verdicts are
  printed verbatim to a student in the tutorial viewer. Translate one half and
  the explanation silently stops; freeze both and a student keeps reading
  Serbian.
* `services/positionScanner/verify.mjs` wrote `sideSource = 'nepoznato'`, and
  `ScannedPosition.needsReview` fires on that word. It is the flag that puts a
  doubtful position in front of the trainer. One translated word would have
  stopped flagging them — with both suites green.

**Both files are already done and are not yours.** They are listed under "Out of
scope", and their values are now `'solution'`, `'only-legal-side'`, `'unknown'`
and English verdict sentences. They are described here because the same shape
can be hiding in a file that *is* yours, and the test is always the same:

> **Would the app still work if the server had never heard of this string?**

If yes it is copy. If no it is a value, and it stays — say so in the report.

**Known values in these files. Never translate them:**

```
'network'   'rate-limited'    error reasons that are already English
'w'  'b'                      colours on the wire
'theory' 'playable' 'mistake' the repertoire verdicts
'trener' 'ucenik' 'korisnik'  roles: a database CHECK constraint
'host' 'admin' 'user'
```

Column names, route paths, socket event names, entitlement ids, ECO codes, SAN
and FEN text and status strings are values, and are already English.

## Three files that are not a translation

Read this section twice; it is most of the risk in the batch.

**1. `geminiService.js` — delete the Serbian, do not translate it.**
The file has a `userLanguage = 'sr'` parameter and an `isSr ? … : …` branch on
every user-visible string, plus two prompts written **in Serbian, instructing
the model to answer in Serbian**. The app is English-only with no i18n, so:

* delete the `userLanguage` parameter and every `isSr` branch, keeping the
  English side;
* rewrite both prompts (the `explainPosition` prompt around line 75 and the
  commentary prompt around line 196) in English, asking for English, keeping
  every instruction and every JSON key exactly as it is;
* in `routes/puzzles.js`, stop reading `userLanguage` out of the request body.

The Flutter app still *sends* `userLanguage: 'sr'`; an ignored extra field is
harmless and the lead removes it on merge. **Do not touch `chess_app/` to fix
it.** The JSON keys the model is told to return — `summary`, `keyMotif`, `plan`,
`recommendedMoves` — are wire values the app reads.

**2. `services/prepNarrative.js` — a prompt, with a guard behind it.**
Nineteen lines of Serbian instructions to the model. Translate it whole, and
**keep every rule and every numeral exactly**: `0.413 → 41.3%`, `0.76 → 76%`.
`services/narrativeGuard.js` refuses any numeral in the model's answer that was
not in its input, so a worked example rewritten with different numbers turns a
working feature into a refusal nobody can explain. The rule that says the reader
is a young one stays a rule; write it as *the reader is a student, not a
statistician*, per the glossary's "never a child".

**3. `services/endgameCatalog.js` — a grammar machine, not a word list.**
`describeSide` carries three tables — `ONE`, `ONE_GEN`, `MANY` — because Serbian
needs a genitive after „protiv". English does not; it needs a plural.

* Collapse `ONE` and `ONE_GEN` into one table and drop the `genitive` argument
  that exists for it: `queen`, `rook`, `bishop`, `knight`, `pawn`.
* `MANY` becomes plurals: `rooks`, `pawns`, …
* `HOW` becomes `two three four five six seven eight`.
* „protiv" is **versus**; „goli kralj" and „golog kralja" are both **bare king**.
* `labelOf('KRPPvKR')` must read `rook and two pawns versus rook`.

`test/endgame_catalog.test.js` asserts these labels. **Rename its expectations,
never drop a case**: batch 64 lost two whole tests to a plural rule with fewer
forms in English, and only an input-by-input check could say nothing had been
uncovered. Every input asserted today must still be asserted.

## The vocabulary that is already written

`services/reportService.js` holds `THEME_LABELS`, 39 Lichess motif tags with
Serbian names, and its own comment says it is a hand-kept duplicate of a table
in the app. **That table is already English.** Copy the values from
`chess_app/lib/features/assignments/models/assignment.dart`, `themeLabels`
(around line 455), key for key — `skewer: 'skewer'`, `backRankMate:
'back-rank mate'`, `xRayAttack: 'x-ray attack'`, `underPromotion:
'underpromotion'`. Do not invent a synonym for any of them: the parent report
and the puzzle screen name the same motif in front of the same person.

That file is also the **parent report** itself: 55 lines of HTML in one template
literal, with headings, a legend and „Poruka trenera". It is a document a parent
reads. Translate the prose; leave the HTML, the CSS class names and the
`&middot;` entities alone.

Other words this batch is the first to need:

| Serbian | English |
|---|---|
| zagonetka | **puzzle** |
| repertoar | **repertoire** |
| nacrt | **draft** |
| linija, grana | **line**, **branch** |
| glavni potez | **main move** |
| neslaganje | **mismatch** |
| orezivanje | **pruning** |
| priprema | **preparation** |
| protivnik | **opponent** |
| partija | **game** |
| arhiva, uvoz | **archive**, **import** |
| tempo igre | **time control** |
| završnica | **endgame** |
| tablica (Syzygy) | **tablebase** |
| skener, dokument | **scanner**, **document** |
| strana na potezu | **side to move** |
| prolaznost | **score** |
| izveštaj | **report** |
| nije dostupno | **is not available** |
| nije uspelo | **failed** |
| nije imenovan brojem | **is not named by a number** |

If a word here is wrong, say so in the report — do not quietly use a better one.

## What is out of scope, and why

* **`chess_app/` — not one file.** The app is finished; any edit there is a
  merge conflict with nothing to gain.
* **`services/customPuzzleJudge.js` and `services/positionScanner/verify.mjs`** —
  done by the lead on `master` in the commit before this batch, both ends of
  their wire values in one change. Do not touch them; if you think one is wrong,
  say so in the report.
* **`routes/consent.js`, and the parent-consent mail in
  `services/mailService.js`** — a lawyer approved that wording for Serbia on
  25.8.2026. Not yours, and not 66a's either.
* **`db.js`, `clear_users.js`, `import_*.js`** — schema, role values, one-off
  tooling.
* **`services/positionScanner/scan.mjs`** — a command-line tool whose Serbian is
  all in `console.log`.
* **Comments, `console.log` and `logger.*`.** A server log is read by the person
  running the server. Leave them. (The opposite of the app batches' rule: a
  Flutter `debugPrint` ships inside the product and a server log does not.)

## What the gate can now see, and could not last week

`gate_english_backend` matched `` `[^`\n]*` `` — no newline — so **a template
literal that wraps was invisible to it**. The three largest Serbian blocks in
this batch are exactly that shape: the report's HTML (55 lines) and the two
model prompts, in `geminiService.js` (36) and `prepNarrative.js` (23). A batch
could have translated every one-line literal, left three whole documents in
Serbian, and been told it was clean. Fixed and mutation-proved on 8.9.2026, so
those 135 lines are graded like everything else.

`.mjs` counts too: the position scanner is ESM because pdfjs ships no CommonJS
build, and `endswith('.js')` is false for every one of its files.

## Scope: 41 files, 466 lines

```
   1  services/positionScanner/fonts.mjs         7  routes/analysis.js
   1  services/repertoireComments.js             7  routes/mistakeDrill.js
   1  services/repertoireErase.js                8  services/positionScanner/index.mjs
   1  services/repertoireFrontier.js             9  services/openingExplorerService.js
   1  services/repertoireSpine.js                9  services/endgameDrill.js
   2  routes/library.js                          9  services/opponentPrep.js
   2  routes/openingExplorer.js                  9  services/scanIntake.js
   2  services/repertoireDrillService.js        10  services/openingLeaks.js
   2  services/repertoireLine.js                11  services/endgameCatalog.js
   2  services/repertoirePractice.js            12  services/playerProfile.js
   2  services/repertoirePrune.js               13  routes/scans.js
   2  videoRenderer.js                          13  services/homeworkFromArchive.js
   3  routes/openingJudge.js                    13  services/openingJudgeService.js
   3  services/positionLibrary.js               18  services/repertoireService.js
   3  services/positionScanner/derive.mjs       20  services/gameArchiveImport.js
   3  services/repertoireArchive.js             20  routes/userGames.js
   3  services/repertoireNotes.js               23  services/prepNarrative.js
   5  services/repertoireAlternative.js         26  routes/puzzles.js
   6  services/tablebaseService.js              47  routes/repertoire.js
   6  routes/reports.js                         50  geminiService.js
                                                81  services/reportService.js
```

All under `chess_backend/`. Counted on 8.9.2026 with the gate's own reader:
lines holding at least one Serbian string literal, comments and log calls
excluded, a wrapped template counted as the lines it spans. 331 are single lines
and 135 sit inside wrapped templates, in seven files — `reportService.js`,
`geminiService.js`, `prepNarrative.js`, `playerProfile.js`,
`gameArchiveImport.js`, `openingExplorerService.js` and `tablebaseService.js`.

**Do not touch any backend file outside this list.**

## Four things in these files specifically

**1. A label that reaches the app as data.** `services/playerProfile.js` builds
its groups in SQL — `COALESCE(speed, 'nepoznato')`, `'do 20. poteza'`,
`'bez imena'`. Those strings are rendered as group names in the profile screen
and nothing compares them, so they are copy. Change the string inside the SQL,
never the column names or the `CASE` structure around it.

**2. Two strings are written into the database.**
`services/homeworkFromArchive.js` titles an assignment `'Iz tvojih partija'`,
and `services/gameArchiveImport.js` stores
`error = 'Uvoz je prekinut pre nego što se završio.'` on a stalled import. Rows
already written stay Serbian; only new ones change. Do not write a migration,
and do not report the old rows as fixed.

**3. A half-translated list already exists.** 66a translated
`assignmentService.js`'s refusals to `reason: 'not your position'`, while
`homeworkFromArchive.js:164` still pushes
`reason: 'nema rešenje koje se može odigrati'` into the same kind of list, and
both can appear in one dialog. That is what this batch is for. It is also a
reminder that `reason` is a sentence in one file and a value in another.

**4. `videoRenderer.js` renders the MP4 export.** Two lines, and its text is
burnt into a video frame — check that the English still fits where it is drawn.

## The rules that bite

**Tests are part of the string.** `chess_backend/test/` asserts on these
messages — `endgame_catalog.test.js`, `scanIntake.test.js`,
`narrative_guard.test.js`, `themeSplit.test.js` and the repertoire tests among
them — and `services/positionScanner/positionScanner.test.mjs` sits beside the
code rather than in `test/`. `grep` the Serbian you are about to change across
both places before moving on. You may edit any test file. You may **not** delete
a test, weaken an assertion, or relax a matcher. If a test cannot be made green
by translating it, stop and say so.

**Re-read every translated `contains` and every regex.** English substrings nest
where Serbian inflections do not: `contains('slika')` does not match `slike`,
but `contains('image')` **does** match `images`, and one scanner assertion
silently stopped discriminating that way in batch 65a. For each one, ask whether
the new string can also match the case the test is ruling out.

**`npm test` runs with no `.env`, and the worktree has none.** That is the
environment CI has. Do not create one. If the suite dies at import rather than
failing a test, that is a finding: `middleware/auth` calls `process.exit(1)`
without `JWT_SECRET`, and that has taken 895 tests down silently before.

**Translate the meaning, not the words**, and **do not change what an error
means**. A 400 that said one thing in Serbian says the same thing in English. A
message that looks wrong — the wrong status, or a sentence that does not match
the branch it sits in — is a finding for the report, not a fix in this batch.

**If a file named above is missing, stop and say so.**

## How this is graded

By machine, after you stop. Your report is evidence to read, not the verdict.

| gate | passes when |
|---|---|
| `english backend` | no Serbian left in any string literal in the 41 files, wrapped templates included |
| `npm test` | **964 passing**, with `.env` moved aside |
| `flutter test` | **1762**, 1 skipped — unchanged, because you touched no Dart |
| `worktree` | no stray files; the report is the only untracked one |

Measure both counts yourself, before and after. Do not trust a number quoted at
you, including the ones in this brief.

**Run each suite at most once, at the end**, and never both at once.

## What the report must contain

Numbers you computed in this run:

1. `npm test` before and after, both measured by you.
2. Per file: how many string literals you translated. **Call the number what it
   actually is** — one report in this series labelled `git diff --numstat` added
   lines as "translated literals", and the real count was less than half of it.
3. Every **test file** you edited, and why.
4. **Every string you decided was a value and left alone, with the reason.** The
   reviewer reads this section first: a wrong call here changes a contract and
   no test catches it.
5. What you did to `geminiService.js`, `prepNarrative.js` and
   `endgameCatalog.js` in that section's own terms — what you deleted, and which
   test expectations you renamed.
6. Every sentence you rewrote rather than translated.
7. Every term in the tables above that turned out wrong or missing.
8. Any message whose text does not match the branch it sits in.
9. **Anything this brief got wrong.**

**Write only what you did.** Four reports in this series have had accurate
numbers and one invented section each — a clipboard message for a dialog with no
clipboard, a scanner error about blurry photographs for a feature that never
reads a photograph. **Quote nothing you have not just grepped.** A short report
that is entirely true is worth more than a thorough one that is not.

## Out of scope

Everything not in the 41 files: all of `chess_app/`, `routes/consent.js`, the
parent-consent mail in `services/mailService.js`, `db.js`, `clear_users.js`,
`import_*.js`, `services/positionScanner/scan.mjs`,
`services/customPuzzleJudge.js`, `services/positionScanner/verify.mjs`, and the
legal texts in `docs/`. Do not commit. Do not branch. Do not `git add`.
