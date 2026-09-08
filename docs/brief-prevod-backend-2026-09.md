# Brief — the English pivot reaches the server, batch 66a: teaching, accounts and rooms

Written 8.9.2026 by the lead, after the owner found four screens still speaking
Serbian on a build every gate called clean. This brief and
`docs/TASK-prevod-backend.md` are the whole of the context for this batch.

## Why this exists at all

The app is English. `gate_english_ui` is clean over all 258 files under
`chess_app/lib`. And the owner opened "Notifications and Invitations" and read:

> učenik 2 želi da vas upiše kao učenika.

**The server sends sentences to the screen, and nobody had asked it to stop.**
Every previous brief in this pivot said *do not touch `chess_backend/`* — which
was right for those batches and hid this. The app renders
`res.json({ error })` as-is, `user_notifications.message` is written by the
server, and the endgame catalogue's category names come from
`services/endgameCatalog.js`.

This is the first of two backend batches. This one is the teaching side —
assignments, the trainer/student relationship, accounts, rooms, recordings,
billing. The chess side — puzzles, the repertoire, openings, endgames, scans,
the game archive — is briefed after this lands.

`docs/GLOSSARY-EN.md` is the contract. **Read it before you touch a file.** Its
two standing rules apply on the server exactly as in the app:

* **Tutorial** is what a trainer writes; **Session** is the live meeting in a
  room. Never write "Lesson" in a message a user reads — in code that word
  already means the written artefact, and the table really is `saved_lessons`.
* **The copy addresses a player, a student and a trainer, never a child**,
  except where the feature genuinely is about parental supervision.

## The rule that will break the app if you get it wrong

**A string on the server is either a sentence or a value, and the values are
frozen.** In the app a wrong guess makes a screen read oddly. Here a wrong guess
silently changes a contract, and the app keeps compiling.

**Role values are the sharp one. Never translate these:**

```
'trener'   'ucenik'   'korisnik'   'host'   'admin'   'user'
```

They are Serbian, they look exactly like copy, and they are:

1. **In a database CHECK constraint** — `db.js:59`,
   `users_role_check CHECK (role IN ('korisnik', 'host', 'admin', 'user', 'trener', 'ucenik'))`.
   Changing the string means migrating the constraint *and* every existing row.
2. **Branched on by the app in twenty-five places** —
   `chess_game_screen.dart` alone tests `role == 'trener'` eleven times and
   `role == 'ucenik'` five, and `core/services/board_control_rules.dart` decides
   who may move a piece from it. None of that is in this batch, and none of it
   would fail a test: the app's tests build their own fixtures.
3. **On the socket wire** — `server.js:336` and `:404`,
   `services/roomAccess.js:104/128/134`.

Renaming them is a migration across the schema, the server, the socket protocol
and the app, in one coordinated change. **It is not a translation and it is not
in this batch.** If you think a role value should change, say so in the report.

The same test applies to everything else: **would the app still work if the
server had never heard of this string?** If yes it is copy; if no it is a value.
Status strings (`'accepted'`, `'awaiting_parent'`), entitlement ids, column
names, route paths and socket event names are all values and are already
English.

## What is deliberately out of scope, and why

**`routes/consent.js`.** It serves the parent-consent page, and its Serbian is
wording **a lawyer approved for Serbia on 25.8.2026**. Translating it spends
that approval. The English version is a new document in Phase 4 of
`docs/PLAN-ZAVRSNICA.md`, reviewed externally before release. Do not touch this
file.

**The parent-consent mail in `services/mailService.js`** — the block beginning
`Poštovani,` and the subject `Saglasnost za učešće deteta u šahovskoj obuci`.
Same reason: it is the delivery of that approved text. **The verification-code
mail in the same file is ordinary transactional copy and IS in scope** — subject
`Verifikacioni kod` and its body. Read carefully; they are forty lines apart in
one file.

**`db.js`.** Schema, migrations and the role values above. Not in this batch.

**`import_*.js` and `clear_users.js`.** One-off tooling, not part of the running
app.

**Code comments and `console.log` / `logger.*` lines.** The gate skips comments.
Server logs are read by the person running the server, not by a user, and
translating them is churn in a diff that has to be read line by line. **Leave
them.** This is the opposite of the rule batch 65b was given, and the reason is
that a Flutter `debugPrint` ships inside the product while a server log does
not.

## One thing this batch cannot fix, said out loud

**`user_notifications` is a table.** The messages in the owner's screenshot are
**rows already written**, so translating the code that generates them changes
what is written from now on and nothing that exists. Every notification created
before this batch stays Serbian until it is deleted. That is a data decision for
the owner, not work for you — do not write a migration, and do not mention it as
though it were done.

## The vocabulary this batch adds

Everything in `GLOSSARY-EN.md` holds. These are the words the server is first
to need.

| Serbian | English | Note |
|---|---|---|
| Poziv / pozivnica | **invitation** | |
| zahtev | **request** | „je prihvatio vaš zahtev" → `accepted your request` |
| veza (trener–učenik) | **connection** | The relationship. Not "link" |
| prihvatio / odbio | **accepted** / **declined** | Matches the `status` values, which stay |
| Domaći, zadatak | **assignment** | Matches `assignments` on the wire |
| je uradio zadatak | **completed the assignment** | The notification in the screenshot |
| soba | **room** | |
| gost | **guest** | |
| posmatrač | **observer** | |
| snimak | **recording** | |
| saglasnost | **consent** | Only where it is not the approved text |
| roditelj | **parent** | |
| nalog | **account** | |
| prijava / odjava | **sign-in** / **sign-out** | |
| verifikacioni kod | **verification code** | |
| pretplata | **subscription** | |
| prava pristupa | **entitlements** | Matches `ENT.*` |
| kvota, ograničenje | **quota**, **limit** | |
| obavezan / obavezno | **required** | „Email učenika je obavezan." → `A student email is required.` |
| nije pronađen | **not found** | |
| nemate pravo | **you are not allowed** | Read the sentence; often better as `Only the trainer can …` |

If a word here is wrong, say so in the report — do not quietly use a better one.

## Scope: 30 files, 362 lines

```
   1  routes/trainerPanel.js
   1  services/playBillingService.js
   2  services/accountGuard.js
   3  limitsService.js
   3  services/ageService.js
   4  services/assignmentNotes.js
   4  services/mistakeReviews.js
   4  services/parentConsentService.js
   5  middleware/auth.js
   5  services/spacedRepetitionService.js
   6  middleware/entitlements.js
   6  routes/lessons.js
   6  routes/reviews.js
   6  services/recordingConsent.js
   6  services/roomAccess.js
   7  services/studentGroups.js
   8  routes/agora.js
  10  routes/billing.js
  11  routes/groups.js
  11  routes/rooms.js
  11  services/assignmentService.js
  13  services/lessonSteps.js
  14  server.js
  20  services/mailService.js
  21  routes/auth.js
  21  services/relationshipService.js
  22  routes/account.js
  22  routes/recordings.js
  54  routes/assignments.js
  55  routes/social.js
```

All under `chess_backend/`. Counted on 8.9.2026: lines holding at least one
Serbian string literal, comments excluded. **Smallest first.**

**Do not touch `chess_app/`.** Not one file — the app is finished and any change
there is a merge conflict with nothing to gain. **Do not touch any backend file
outside this list**; the chess half is the next batch.

## The three traps in these files specifically

**1. `server.js` is the socket protocol.** Its fourteen lines mix copy with
event and role names. A message emitted to a client is copy; the string in
`socket.emit('...')`, the seat role, and anything compared with `===` is a
value. This file has taken the whole test suite down before by not parsing —
`test/sources_compile.test.js` exists because of it — so read your own edit.

**2. `routes/social.js` and `routes/assignments.js` are half the batch**, 109
lines between them, and they are the two the owner's screenshot came from. They
are also the files where „učenik" appears both as a **word in a sentence**
(translate: `student`) and as a **role value** (leave: `'ucenik'`). Decide per
occurrence, not per file.

**3. `middleware/auth.js` and `middleware/entitlements.js` answer before a route
runs.** Their messages are what a user sees when a session expires or a paid
feature is refused, so they are copy — but `middleware/auth` calls
`process.exit(1)` at import without `JWT_SECRET`, which is how a backend test
run has silently taken 895 tests down before. Change strings there and nothing
else.

## The rules that bite

**Tests are part of the string.** `chess_backend/test/` asserts on these
messages. A message changed without its test turns `npm test` red. `grep` the
old text across `chess_backend/test/` before moving on. You may edit any test
file. You may **not** delete a test, weaken an assertion, or relax a matcher. If
a test cannot be made green by translating it, stop and say so.

**`npm test` runs with no `.env`, and the worktree has none.** That is the
environment CI has: a test that reaches a route drags in `middleware/auth`,
which calls `process.exit(1)` without `JWT_SECRET` and has taken 895 tests down
silently before. Do not create a `.env` to make something pass — if the suite
dies at import rather than failing a test, that is a finding.

**Translate the meaning, not the words.** „Nemate pravo na ovu sobu." is
`You are not allowed in this room.`, and often the better sentence names who is:
`Only the trainer can open this room.`

**Do not change what an error means.** A 400 that said one thing in Serbian must
say the same thing in English. If you find a message that is simply wrong — the
wrong status, or a sentence that does not match the branch it is in — that is a
finding for the report, not something to fix in this batch.

**If a file named above is missing, stop and say so.**

## How this is graded

By machine, after you stop. Your report is evidence to read, not the verdict.

| gate | passes when |
|---|---|
| `english backend` | no Serbian left in any string literal in the 30 files |
| `npm test` | **964 passing**, with `.env` moved aside |
| `flutter test` | **1762**, 1 skipped — unchanged, because you touched no Dart |
| `worktree` | no stray files; the report is the only untracked one |

Measure both counts yourself, before and after. Do not trust a number quoted at
you, including the one in this brief.

**Run each suite at most once at the end**, and never both at once. Translate
the files, grep the tests, fix what you find by reading, then run.

## What the report must contain

Numbers you computed in this run:

1. `npm test` before and after, both measured by you.
2. Per file: how many string literals you translated. **Call the number what it
   actually is** — the last report labelled `git diff --numstat` added lines as
   "translated literals", and the real count was less than half of it.
3. Every **test file** you edited, and why.
4. **Every string you decided was a value and left alone**, with the reason. This
   is the section the reviewer reads first, because a wrong call here is a
   contract change that no test catches.
5. Every sentence you rewrote rather than translated.
6. Every term in the table above that turned out wrong or missing.
7. Any message whose text does not match the branch it is in.
8. **Anything this brief got wrong.**

**Write only what you did.** Four reports in this series have had accurate
numbers and one invented section each — a clipboard message for a dialog that
has no clipboard, a 404 page quoted with words it does not contain. **Quote
nothing you have not just grepped.** A short report that is entirely true is
worth more than a thorough one that is not.

## Out of scope

Everything not in the 30 files: all of `chess_app/`, `routes/consent.js`, the
parent-consent mail in `services/mailService.js`, `db.js`, `import_*.js`,
`clear_users.js`, the legal texts in `docs/`. Do not commit. Do not branch. Do
not `git add`.
