# Task — English pivot on the server, batch 66b: the chess half

**This file plus `docs/brief-prevod-backend-2-2026-09.md` are the only context
you get. Do not rely on any conversation before them.** Read the brief first,
then `docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.** Do not
substitute the nearest plausible one.

Branch: `batch/prevod-backend-2`. **Do not commit.**

Read the brief's sections "The rule that will break the app if you get it wrong"
and "Three files that are not a translation" twice.

## What to do

Replace the Serbian user-facing string literals with English in these forty-one
files, and in the same edit update every backend test that asserts on the text
you changed.

In this order — smallest first:

1. `chess_backend/services/positionScanner/fonts.mjs`
2. `chess_backend/services/repertoireComments.js`
3. `chess_backend/services/repertoireErase.js`
4. `chess_backend/services/repertoireFrontier.js`
5. `chess_backend/services/repertoireSpine.js`
6. `chess_backend/routes/library.js`
7. `chess_backend/routes/openingExplorer.js`
8. `chess_backend/services/repertoireDrillService.js`
9. `chess_backend/services/repertoireLine.js`
10. `chess_backend/services/repertoirePractice.js`
11. `chess_backend/services/repertoirePrune.js`
12. `chess_backend/videoRenderer.js`
13. `chess_backend/routes/openingJudge.js`
14. `chess_backend/services/positionLibrary.js`
15. `chess_backend/services/positionScanner/derive.mjs`
16. `chess_backend/services/repertoireArchive.js`
17. `chess_backend/services/repertoireNotes.js`
18. `chess_backend/services/repertoireAlternative.js`
19. `chess_backend/services/tablebaseService.js`
20. `chess_backend/routes/reports.js`
21. `chess_backend/routes/analysis.js`
22. `chess_backend/routes/mistakeDrill.js`
23. `chess_backend/services/positionScanner/index.mjs`
24. `chess_backend/services/openingExplorerService.js`
25. `chess_backend/services/endgameDrill.js`
26. `chess_backend/services/opponentPrep.js`
27. `chess_backend/services/scanIntake.js`
28. `chess_backend/services/openingLeaks.js`
29. `chess_backend/services/endgameCatalog.js`
30. `chess_backend/services/playerProfile.js`
31. `chess_backend/routes/scans.js`
32. `chess_backend/services/homeworkFromArchive.js`
33. `chess_backend/services/openingJudgeService.js`
34. `chess_backend/services/repertoireService.js`
35. `chess_backend/services/gameArchiveImport.js`
36. `chess_backend/routes/userGames.js`
37. `chess_backend/services/prepNarrative.js`
38. `chess_backend/routes/puzzles.js`
39. `chess_backend/routes/repertoire.js`
40. `chess_backend/geminiService.js`
41. `chess_backend/services/reportService.js`

**Run `npm test` once, at the end.** Not per file. You may run a single test
file when you have a specific reason to.

## Method

* One file at a time, finished before the next.
* For each Serbian literal decide **copy or value**, and when in doubt treat it
  as a value and report it. The test: would the app still work if the server had
  never heard of this string?
* **These are values. Never translate them:** `'trener'`, `'ucenik'`,
  `'korisnik'`, `'host'`, `'admin'`, `'user'`, `'w'`, `'b'`, `'theory'`,
  `'playable'`, `'mistake'`, `'network'`, `'rate-limited'`. Also values: status
  strings, entitlement ids, column names, route paths, socket event names, ECO
  codes, SAN and FEN text.
* **A template literal that wraps over several lines is one string.** The report
  HTML in `reportService.js` and the model prompts in `geminiService.js` and
  `prepNarrative.js` are the big ones, and they are graded.
* `geminiService.js`, `prepNarrative.js` and `endgameCatalog.js` are **not
  ordinary translations**. Do exactly what the brief's section on them says:
  delete the `userLanguage` / `isSr` dual path and write both prompts in English
  asking for English; keep every numeral in the narrative prompt; collapse the
  endgame catalogue's genitive table into one and use plurals.
* In `routes/puzzles.js`, stop reading `userLanguage` from the request body.
* In `reportService.js`, take `THEME_LABELS`' English values from
  `chess_app/lib/features/assignments/models/assignment.dart` (`themeLabels`,
  around line 455) key for key. **Read that file; do not edit it.**
* Comments and `console.log` / `logger.*` lines are **not** in scope. Leave them.
* When a string changes, `grep` the old Serbian across `chess_backend/test/`
  **and** `chess_backend/services/positionScanner/positionScanner.test.mjs`, and
  change every assertion on it in the same edit.

## Rules

* Do not touch `chess_app/`. Not one file — reading one is fine.
* Do not touch `chess_backend/services/customPuzzleJudge.js` or
  `chess_backend/services/positionScanner/verify.mjs`: they are the lead's, done
  on `master` in the commit before this batch.
* Do not touch `chess_backend/routes/consent.js`, `chess_backend/db.js`,
  `chess_backend/clear_users.js`, `chess_backend/services/positionScanner/scan.mjs`,
  any `chess_backend/import_*.js`, or the parent-consent mail in
  `chess_backend/services/mailService.js`.
* Do not touch any backend file outside the forty-one.
* Do not write a database migration and do not touch existing rows.
* Do not delete a test, weaken an assertion, or relax a matcher. If a test cannot
  be made green by translating it, stop and report it.
* Do not change a status code, a branch, or what an error means. A message that
  looks wrong is a finding for the report.
* Do not commit, branch, or `git add`.

## Done means

* `cd chess_backend && npm test` → **964 passing**.

```bash
cd chess_backend && npm test
```

  **This worktree has no `.env`** — it is gitignored, so it was never copied in,
  and that is exactly the environment CI has and the one this suite must pass
  in. Do not create one. If `npm test` dies at import rather than failing a
  test, say so and stop: `middleware/auth` calls `process.exit(1)` without
  `JWT_SECRET`, and that has silently taken 895 tests down before.

* No Serbian left in any string literal in the forty-one files — neither a
  diacritic (`čćžšđ ČĆŽŠĐ`) nor a Serbian word written without one
  (`vise`, `pesaka`, `moze`, `nije`, `zadatak`, `resenje` …), and that includes
  every template literal that wraps over more than one line.
* `chess_app` is untouched, so `flutter test` is unchanged at 1762, 1 skipped.

## The report

Write it to `REPORT-prevod-backend-2.md` in the repository root.

1. `npm test` before and after, both measured by you.
2. Per file: how many string literals you translated, called by their right
   name.
3. Every test file you edited, and why.
4. **Every string you decided was a value and left alone, with the reason.** The
   reviewer reads this section first: a wrong call here changes a contract and
   no test catches it.
5. What you did to `geminiService.js`, `prepNarrative.js` and
   `endgameCatalog.js` — what you deleted, and which test expectations you
   renamed.
6. Every sentence you rewrote rather than translated.
7. Every term in the brief's tables that turned out wrong or missing.
8. Any message whose text does not match the branch it sits in.
9. Anything this task or the brief got wrong.

**Write only what you did.** Four reports in this series had accurate numbers
and one invented section each. **Quote nothing you have not just grepped.**
