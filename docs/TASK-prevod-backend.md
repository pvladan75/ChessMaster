# Task — English pivot on the server, batch 66a: teaching, accounts and rooms

**This file plus `docs/brief-prevod-backend-2026-09.md` are the only context you
get. Do not rely on any conversation before them.** Read the brief first, then
`docs/GLOSSARY-EN.md`, then come back here.

If you cannot find a file this task names, **stop and say so.** Do not
substitute the nearest plausible one.

Branch: `batch/prevod-backend`. **Do not commit.**

This is the first batch in this project that edits `chess_backend/`. Read the
brief's section "The rule that will break the app if you get it wrong" twice.

## What to do

Replace the Serbian user-facing string literals with English in these thirty
files, and in the same edit update every backend test that asserts on the text
you changed.

In this order — smallest first:

1. `chess_backend/routes/trainerPanel.js`
2. `chess_backend/services/playBillingService.js`
3. `chess_backend/services/accountGuard.js`
4. `chess_backend/limitsService.js`
5. `chess_backend/services/ageService.js`
6. `chess_backend/services/assignmentNotes.js`
7. `chess_backend/services/mistakeReviews.js`
8. `chess_backend/services/parentConsentService.js`
9. `chess_backend/middleware/auth.js`
10. `chess_backend/services/spacedRepetitionService.js`
11. `chess_backend/middleware/entitlements.js`
12. `chess_backend/routes/lessons.js`
13. `chess_backend/routes/reviews.js`
14. `chess_backend/services/recordingConsent.js`
15. `chess_backend/services/roomAccess.js`
16. `chess_backend/services/studentGroups.js`
17. `chess_backend/routes/agora.js`
18. `chess_backend/routes/billing.js`
19. `chess_backend/routes/groups.js`
20. `chess_backend/routes/rooms.js`
21. `chess_backend/services/assignmentService.js`
22. `chess_backend/services/lessonSteps.js`
23. `chess_backend/server.js`
24. `chess_backend/services/mailService.js`
25. `chess_backend/routes/auth.js`
26. `chess_backend/services/relationshipService.js`
27. `chess_backend/routes/account.js`
28. `chess_backend/routes/recordings.js`
29. `chess_backend/routes/assignments.js`
30. `chess_backend/routes/social.js`

**Run `npm test` once, at the end.** Not per file. You may run a single test
file when you have a specific reason to.

## Method

* One file at a time, finished before the next.
* For each Serbian literal decide **copy or value**, and when in doubt treat it
  as a value and report it. The test: would the app still work if the server had
  never heard of this string?
* **These are values. Never translate them:** `'trener'`, `'ucenik'`,
  `'korisnik'`, `'host'`, `'admin'`, `'user'`. They live in a database CHECK
  constraint (`db.js:59`) and the Flutter app branches on them in twenty-five
  places. Also values: status strings, entitlement ids, column names, route
  paths, socket event names.
* In `routes/social.js` and `routes/assignments.js`, „učenik" appears both as a
  word in a sentence and as a role value. **Decide per occurrence.**
* In `services/mailService.js`, translate the **verification-code** mail only.
  Leave the parent-consent mail — the block starting `Poštovani,` and the
  subject `Saglasnost za učešće deteta u šahovskoj obuci` — exactly as it is.
* Comments and `console.log` / `logger.*` lines are **not** in scope. Leave
  them. (This is the opposite of the last app batch's rule; the brief says why.)
* When a string changes, `grep` the old Serbian words across
  `chess_backend/test/` and change every assertion on it in the same edit.

## Rules

* Do not touch `chess_app/`. Not one file.
* Do not touch `chess_backend/routes/consent.js`, `chess_backend/db.js`,
  `chess_backend/clear_users.js`, or any `chess_backend/import_*.js`.
* Do not touch any backend file outside the thirty.
* Do not write a database migration and do not touch existing rows. The Serbian
  already stored in `user_notifications` stays; that is the owner's decision,
  not this batch's work.
* Do not delete a test, weaken an assertion, or relax a matcher. If a test
  cannot be made green by translating it, stop and report it.
* Do not change a status code, a branch, or what an error means. A message that
  looks wrong is a finding for the report.
* Do not commit, branch, or `git add`.

## Done means

* `cd chess_backend && npm test` → **964 passing**, run with `.env` moved aside:

```bash
cd chess_backend && mv .env .env.off && npm test; mv .env.off .env
```

* No Serbian left in any string literal in the thirty files — neither a
  diacritic (`čćžšđ ČĆŽŠĐ`) nor a Serbian word written without one
  (`vise`, `pesaka`, `moze`, `nije`, `zadatak` …). The app-side sweep was
  reported clean for weeks on a diacritic test alone; do not repeat it.
* `chess_app` is untouched, so `flutter test` is unchanged at 1762.

## The report

Write it to `REPORT-prevod-backend.md` in the repository root.

1. `npm test` before and after, both measured by you.
2. Per file: how many string literals you translated, called by their right
   name.
3. Every test file you edited, and why.
4. **Every string you decided was a value and left alone, with the reason.**
   The reviewer reads this section first: a wrong call here changes a contract
   and no test catches it.
5. Every sentence you rewrote rather than translated.
6. Every term in the brief's table that turned out wrong or missing.
7. Any message whose text does not match the branch it sits in.
8. Anything this task or the brief got wrong.

**Write only what you did.** Four reports in this series had accurate numbers
and one invented section each. **Quote nothing you have not just grepped.**
