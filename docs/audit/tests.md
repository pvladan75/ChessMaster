# Audit — Test quality

Read-only run of 16.9.2026 over `chess_app/test` (267 files) and
`chess_backend/test` (108 files). Sampled by pattern — source-reading tests,
absence assertions, `takeException`, fakes and what they replace, wall clock,
shared directories, `process.env` — and read closely where a pattern hit. No
suite was run and no production file was touched; every "mutation" below is a
change reasoned from the test and the code it names, not one applied.

## Findings

### 1. The route guards on a trainer's access to a student's records are reached by no test; deleting one leaves both suites green
Severity: critical
Where: `chess_backend/routes/assignments.js:698-700` (`POST /report/:studentId`), `:765-767` (`GET /progress/:studentId`), `:126` (`GET /student/:id/archive`), `:512` (`GET /given?studentId=`) — each an `if (!(await assignments.trainerOwnsStudent(...))) return 403`. Tests: `chess_backend/test/assignment.test.js:9-17` and `assignment_review.test.js:14-15` import services only; the one test that opens `routes/assignments.js` is `trainer_panel.test.js:232-240`, a source read of the review `GET`. No test file names `report/`, `/progress/` or `student/:id/archive` (grep over `chess_backend/test`).
Why it matters: `POST /report/:studentId` writes a `student_reports` row and returns a signed URL that lets a parent with no account read a child's record for `REPORT_TTL_DAYS`. With the guard gone, any signed-in account mints that link for any student id. Nothing in the suite would notice; the route works perfectly for the trainer who owns the student.
Proof: a route test in the shape of `tutorial_video_export.test.js` (fake `pool`, user set by hand) that posts `/report/5` as user 9 with a pool answering `[]` to `SELECT 1 FROM trainer_students` and expects 403 and **no** `INSERT INTO student_reports`. Mutation that survives today: delete lines 698-700.
Fix direction: one route test per `trainerOwnsStudent` call site that asserts the refusal and that nothing is written or read afterwards; cheapest is a table-driven test over the four routes with a pool that records every query.

### 2. Ownership predicates are proved by a fake that answers the same rows for any SQL, so the predicate itself is never pinned
Severity: high
Where: `chess_backend/services/studentGroups.js:35-40` (`ownsGroup`: `WHERE id = $1 AND trainer_id = $2`) against `chess_backend/test/student_groups.test.js:22-36` (`stubPool` returns `results[min(index, last)]` whatever the text) and `:46-53` (asserts only that an empty answer throws `NotYours`; the string `trainer_id` appears nowhere in the file). Same shape: `chess_backend/services/assignmentService.js:40-46` (`trainerOwnsStudent`) against `chess_backend/test/relationship.test.js:70-76`, which pins `status = 'accepted'` and `params = [1, 2]` and nothing about `trainer_id = $1 AND student_id = $2`.
Why it matters: every group route (`routes/groups.js:80-142`) and every homework/report route reads a child's name list or record through these two predicates. A predicate that forgets whose row it is answers "yes" for everybody, and the fake answers "no row" regardless, so the refusal test stays green.
Proof: mutation `ownsGroup` → `'SELECT 1 FROM student_groups WHERE id = $1'` with `[groupId]`: `student_groups.test.js` stays green (the `RangeError`/`NotYours` paths are driven by the fixture, not the SQL). Mutation `trainerOwnsStudent` → `WHERE (trainer_id = $1 OR student_id = $2) AND status = 'accepted'`: `relationship.test.js:70-76` stays green (status word present, params unchanged). A test that fails: `assert.match(pool.calls[0].text, /id = \$1 AND trainer_id = \$2/)` in the first; `/trainer_id = \$1 AND student_id = \$2 AND status/` in the second.
Fix direction: for each ownership query, assert the whole predicate on the recorded text (as `trainer_panel.test.js:60-106` already does for its SQL), or route the fake by SQL pattern (as `trainer_panel.test.js:39-41` and `narration_upload.test.js:192-194` do) so a predicate that changes shape gets no answer.

### 3. `authenticateToken`'s refusal of scoped tokens has no test, and a download token carries the user's id
Severity: high
Where: `chess_backend/middleware/auth.js:47-50` (`if (user.purpose) return 403`), `:115-121` (`signDownloadToken` signs `{ purpose: 'download', file, id: userId }` with the same `JWT_SECRET`). Tests: `grep purpose chess_backend/test` finds only prose; the middleware is checked by identity (`game_moves_route.test.js:58`, `opening_judge_route.test.js:85-87`, `tutorial_video_export.test.js:249`) and by a source read for `tokenHolderStanding(` (`account_guard.test.js:105-111`).
Why it matters: a download link is meant to be opened in a system browser and is routinely shared. Without line 47 the same token — valid for 30 minutes, carrying `id` — is a bearer credential for the whole API as that trainer: their students, their tutorials, their reports. The guard exists; nothing would say so if it went.
Proof: mutation — delete `auth.js:47-50`; every test stays green. A test that fails: call `authenticateToken` with `Authorization: Bearer <signDownloadToken(5, 'x.mp4')>` and a fake `pool`, expect 403 and `next` not called; repeat for `optionalAuth` (`:91`) and `authenticateSocket` (`:184`).
Fix direction: a behavioural test of the middleware with real `jwt.sign` — bad signature, expired, `purpose` set, account gone — one case each; the `JWT_SECRET` fixture the route tests already set (`lesson_clone.test.js:23`) is enough.

### 4. `POST /login` is never run by a test; the password check is pinned only as text order
Severity: high
Where: `chess_backend/routes/auth.js` login handler (`bcrypt.compare` → `if (!validPassword) return 400`; `if (user.is_verified === false)`). Tests: `chess_backend/test/google_account.test.js:36-56` reads the handler as text and asserts `indexOf('isPasswordlessHash') < indexOf('bcrypt.compare')`; `email_verification.test.js:171-173` asserts `/if\s*\(\s*!user\.is_verified\s*\)/` and `/password_hash\s*=\s*\$2/` against the source. No test file contains `'/login'` other than that `indexOf`.
Why it matters: this is the front door of every account, most of them minors'. A regression in the compare — the result ignored, the branch inverted, the refusal body emptied — is invisible to the suite.
Proof: mutation `if (!validPassword)` → `if (validPassword === undefined)` (or delete the block): `google_account.test.js` still finds both names in the right order; nothing else looks. Mutation: empty the body of `if (!user.is_verified)`: the regex at `email_verification.test.js:171` still matches. A test that fails: run the handler with a fake pool returning a row whose `password_hash` is `bcrypt.hashSync('right')` and post `password: 'wrong'`; expect 400 and no `jwt.sign`.
Fix direction: a handler-level test of login with a real bcrypt hash — wrong password, unverified account, Google account, success — and keep the text-order check only for what behaviour cannot see (the order).

### 5. The 13+ floor is enforced in one route and tested in none
Severity: high
Where: `chess_backend/routes/account.js:105-114` (`if (isUnderMinimumAge(year)) return 403` before the `UPDATE users SET birth_year`). Tests: `chess_backend/test/age.test.js:26` imports `../services/ageService` only (`isUnderMinimumAge`, `statedAge`, `MINIMUM_AGE` — `:191-233`); no test names `routes/account.js` or `/me/age` (grep over `chess_backend/test`).
Why it matters: the General Audience declaration is true only if this route says no (its own comment, `:94-97`). The app's gate (`chess_app/lib/screens/age_gate_screen.dart:32`, `kMinimumAge = 13`) refuses on the ordinary path, but the route is the one that keeps a `birth_year` saying eleven out of the database — the one row the decision exists to avoid. Borders critical (a legal promise) and is rated high only because the client still refuses.
Proof: mutation — delete `:105-114`; both suites green (`age.test.js` proves the function, not its caller — the same "proved function, unproved caller" shape `LESSONS.md` records for `revise`). A test that fails: run the handler as user 7 with `birthYear: currentYear - 11` and a recording pool; expect 403, `minimumAge: 13`, and **no** `UPDATE users`.
Fix direction: one route test with a recording pool, two cases (under and at thirteen), asserting on the queries as well as the status.

### 6. The "no fourth copy" guard on `trainer_students` matches the word `status` anywhere and only one spelling of the query
Severity: medium
Where: `chess_backend/test/relationship.test.js:483-489` — pattern `SELECT\s+(trainer_id|student_id)\s+FROM\s+trainer_students[\s\S]{0,240}?(?=\)|`)` then `if (!/status/.test(snippet))`. Guarded code: `chess_backend/routes/account.js:172-173` (`SELECT trainer_id FROM trainer_students WHERE student_id = $1 AND status = 'accepted'`).
Why it matters: the guard exists because three copies forgot the condition. It cannot see a copy that spells it wrong (`status = 'pending'`, `status <> 'declined'`), and it cannot see a copy written with an alias (`SELECT ts.student_id FROM trainer_students ts`) or as `SELECT 1 FROM trainer_students` — which is how `roomAccess.js:205` and `assignmentService.js:41-42` are already written. The next hand-written copy is likelier to look like those than like the pattern.
Proof: mutation — `account.js:173` `status = 'accepted'` → `status <> 'declined'`: the snippet still contains `status`, test green; effect: a trainer whose request the child never answered is told the child is a minor (`notifyTrainersOfStatedAge`). A test that fails: require the literal `status\s*=\s*'accepted'` in the snippet, and match `FROM\s+trainer_students(\s+\w+)?` in any `SELECT` outside `relationshipService.js`.
Fix direction: tighten the two regexes, and list the sanctioned files explicitly so that a copy outside them fails whatever its shape — the same "one home" rule `archive_scope.test.js:177-201` applies to `OWN_GAMES_SQL`.

### 7. A source-reading test asserts `/403/` over a file whose comment says "403", so the refusal it guards can become a `false` answer
Severity: medium
Where: `chess_backend/test/room_access.test.js:354-359` reads `routes/rooms.js` **without** stripping comments and asserts `assert.match(rooms, /403/, 'tuđa soba mora da bude odbijena, a ne prećutana')`. `chess_backend/routes/rooms.js:68` is a comment: "a plain 403 for anybody else"; the refusals are `:77` and `:105`.
Why it matters: the test's own message names the failure — answering `false` for somebody else's room instead of refusing — and that exact mutation passes it. (The sibling at `:305-313` strips comments first; `:390-398` strips them and says why. This one was written without.)
Proof: mutation — replace `res.status(403).json(...)` at `rooms.js:77` and `:105` with `res.json({ allowGuests: false })`; test green because of line 68. A test that fails: strip `^\s*//.*$` first (as `:307`, `:396` do) and assert on the body of the two `guest-access` handlers, not the file.
Fix direction: strip comments and scope to the handler body using the brace-matching helper the file's neighbours already have (`trainer_panel.test.js:218-232`); the fourth entry in `LESSONS.md`'s family of text checks that match prose.

### 8. The endgame trainer's HTTP contract has no test at either end
Severity: medium
Where: app client `chess_app/lib/features/endgame_trainer/services/endgame_api_service.dart:82-344` (seven requests: `/api/puzzles/endgame/next`, `/catalog`, `/game/next`, `/line`, `/probe`, `/play`); no test constructs it with a client and no test contains `puzzles/endgame` — all five endgame tests subclass it and override the methods (`endgame_trainer_keys_test.dart:14-26`, `endgame_trainer_layout_test.dart`, `endgame_picker_test.dart`, `drill_scope_test.dart`, `govor_na_panelima_test.dart`). Server: `chess_backend/routes/puzzles.js:142-446` has no route test (`endgame_drill.test.js`, `endgame_catalog.test.js`, `tablebase_service.test.js` import services); `routes/puzzles.js` is named by no test file.
Why it matters: `LESSONS.md` rule 7 — fake the client, not the method. A path, a query parameter or a response field can change on either end and both suites stay green; the student finds out on the board. Unlike the newer routes (`game_moves_route.test.js:58`, `opening_explorer_route.test.js:63`), nothing pins that `puzzles.js:186` carries `authenticateToken`.
Proof: mutation — `endgame_api_service.dart:94` `'.../endgame/next'` → `'.../endgame/nxt'`, or drop `mode` from the query: app suite green. Mutation — remove `authenticateToken` from `puzzles.js:186`: backend suite green. A test that fails: `EndgameApiService` over a `MockClient` recording the request (the shape `archive_wire_format_test.dart:16-59` uses for `ArchiveApiService.withClient`), one per method; and a `layer()[0] === authenticateToken` check per endgame route.
Fix direction: give the service a client seam and one request-recording test per method; on the server, the identity check the four newer route tests already use.

### 9. Two dialog layout tests assert only `takeException()`, so a dialog that draws nothing passes them
Severity: medium
Where: `chess_app/test/dialog_layout_test.dart:16-22` (`pumpDialog` — its only assertion is `takeException() isNull`) with `:32-41` and `:43-61` (`CreateCourseDialog`, no further `expect`); `chess_app/test/mobile_layout_test.dart:68-95` (`CreateAssignmentDialog` at 320 px, only `takeException`). Guarded code: `chess_app/lib/widgets/create_course_dialog.dart`, `chess_app/lib/features/assignments/widgets/create_assignment_dialog.dart`.
Why it matters: `LESSONS.md` already records that `takeException` is not a layout assertion — an overflow that never happens because the widget was not built passes it. A release build paints no overflow, so these are the only guards CI has for those phones.
Proof: mutation — `CreateCourseDialog.build` returns `const SizedBox.shrink()`: both `dialog_layout_test` cases green. Mutation — `CreateAssignmentDialog` returns an empty `Dialog` when `MediaQuery.sizeOf(context).width < 340`: `mobile_layout_test.dart:68-95` green (the 360 px case at `:35-66` asserts `find.text('Assign')` and would catch it there). A test that fails: assert the dialog's primary control is present and inside the dialog's rect (as `LESSONS.md` prescribes: "ask whether the button is inside the dialog").
Fix direction: add one content assertion per `takeException`-only case — the save button found and hit-testable within `find.byType(Dialog)`.

### 10. A backend test counts every file in the shared real `exports/` while sibling files write there and `node --test` runs files in parallel
Severity: low
Where: `chess_backend/test/tutorial_preview_frames.test.js:203-210` (`readdirSync(exportsDir).length` before and after). Writers in parallel: `tutorial_video_export.test.js:474`, `:533`, `:787-793`, `:898-900`; `tutorial_video_link.test.js:73-74`. Runner: `chess_backend/package.json:9` `node --test` (one process per file, concurrent).
Why it matters: a red that is the machine's load, not the code — the exact shape `LESSONS.md` records for test 3 of the export file, which was then scoped with `ours()` (`tutorial_video_export.test.js:392-409`). This sibling was not.
Proof: no mutation survives (this is a false failure, not a false pass); run the two files together under load and watch `:210` fail on a count that moved. A test that cannot flake: point the route at a `mkdtemp` directory (as `narration_upload.test.js:24-25` does with `NARRATION_DIR`) or filter to this test's own filenames.
Fix direction: an `EXPORTS_DIR` override read by the route, set to a temp directory in every test that touches it.

### 11. Retired-string guards left in Serbian after the English pivot cannot catch the English reintroduction
Severity: low
Where: `chess_app/test/notifications_dialog_test.dart:129` (`'Odgovorite u tabu Prijatelji.'`, findsNothing — the retired "answer in the Friends tab" pointer), `stockfish_analysis_panel_test.dart:112-114` (`'Najbolji potez'`, `'Linije'`), `tutorial_tri_akcije_test.dart:134-135` (`'+ Dodaj deo'`, `'Delovi tutorijala'`), `tutorial_tok_test.dart:197` (`'Linija ovog dela'`), `opening_book_service_test.dart:173` (`'Ukucajte naziv'`). None of these literals exists anywhere under `chess_app/lib` (grep).
Why it matters: each was written to keep a retired control or heading retired; since the pivot the control would come back in English and the Serbian finder cannot see it. Vacuous by construction — `LESSONS.md` rule 5: after a rename, grep the old word in the tests.
Proof: mutation — draw `Text('Answer in the Friends tab.')` under the student request in the notifications dialog, or a `'Lines'` heading over the engine list: every listed assertion stays green. A scan that lists them: extract every `find.text('…')`/`textContaining('…')` followed by `findsNothing` and grep `lib/` for the literal (that is how this list was made; fixture strings such as `'Nedovršen deo'`, `'Filidor.'` are legitimate and were excluded by reading).
Fix direction: either translate the guard to the English the control would carry today, or replace it with a structural assertion (no second `Tab`, no `Text` under the engine list's header) and delete the rest.

## Suspicions

- **Sequential fake pools answer questions nobody asked.** `assignment.test.js:30-33`, `assignment_review.test.js:23-26`, `notifications.test.js:22-24`, `position_library.test.js:23-25`, `room_access.test.js:29-31`, `student_groups.test.js:27-31` return `results[Math.min(index, results.length - 1)]` — every query past the fixture's end gets the last row set, whatever it asks. A query added to, or removed from, the middle of a service is answered by the wrong fixture and often still passes. Finding 2 is the one instance read to the bottom; the rest would need each service walked query by query. Confirm by inserting a harmless extra `pool.query` at the top of any tested function and watching which tests notice.
- **`render_font.test.js:61-70` and `:130-181` are tests of the machine's fonts**, and say so: they pass only where an installed family draws č/ć and ж/ф. Deliberate ("a machine with no usable font is a loud log line"), so not a finding; confirm the trade-off is wanted by running the file in a minimal container with no DejaVu.
- **`analysis_pgn_export_test.dart:81`** compares `pgnFileNameFor(DateTime.now())` in the test with a name the code built a moment earlier — red across midnight. Cheap: pass a fixed `DateTime` to both.
- **`lesson_steps.test.js:206-212`** guards against a fifth hand-written step fallback with `/list\.length\s*>\s*0/`; a copy written `!= 0`, `>= 1` or `isNotEmpty`-style passes. Same family as finding 6; confirm by counting how many spellings the four original copies used.
- **Route files named by no test** beyond those in findings 1, 4, 5 and 8: `billing.js`, `consent.js`, `groups.js`, `library.js`, `mistakeDrill.js`, `reports.js`, `reviews.js`, `social.js`, `trainerPanel.js`, `analysis.js`, `agora.js` (`grep -l routes/<name> chess_backend/test` returns nothing; `social.js`, `agora.js`, `consent.js` are read as text by `room_access.test.js` and `parent_consent.test.js`). Their services are tested; the route-level decision — who is refused, what is written on refusal — is not. Each would need the same reading finding 1 got.
- **`tutorial_language_draft_test.dart`** has `'id': 31` and no `testWidgets` (plain `test`), so the shared-slot hazard `LESSONS.md` records does not apply; every other file sharing id 31 clears `TutorialDraftService.instance` in `setUp` (e.g. `tutorial_reopen_test.dart:74-76`). Noted so nobody re-reports it.

## For another track

- Track 2: `routes/account.js:172-173` reads the edge with its own `SELECT trainer_id FROM trainer_students … status = 'accepted'` rather than through `acceptedTrainersOf`/`trainerOwnsStudent` — the third sanctioned spelling, or a copy?
- Track 2: `routes/puzzles.js:142-446` — six endgame routes whose `authenticateToken` is pinned by no test (finding 8); worth a look at what each reads.
- Track 3: the endgame request/response shape (finding 8) is the one contract with no test on either side; a field renamed on the server would be found on the board.
- Track 1: `EndgameApiService` has no client seam (`super(authToken: '')` is the only constructor the fakes reach for), which is why every test overrides its methods.

## What I did not cover

- The render queue and job store beyond confirming their limits are read at call time (`renderQueue.js:35-58`) and that admission (429) is tested at the route (`tutorial_video_export.test.js`, `render_fairness.test.js`); no mutation reasoning was done on them.
- The tutorial save round-trip: relied on `LESSONS.md`'s record (byte-identical round trip, `tutorial_reopen_test.dart:149` reading `step['id']` from the request) rather than re-deriving each guard.
- Backend tests that use `Date.now()` (`retention.test.js`, `recording_export_deadline.test.js`, `render_deadline.test.js`, `repertoire_drill.test.js`) — not read; a fixture built relative to now is usually fine, but none was checked against a boundary.
- Roughly 230 of the 267 app test files and 80 of the 108 backend files were touched only by pattern scan, not read.
- The golden screenshot group, `sources_compile.test.js`'s walk, `deploy/`, `tools/`, `puzzles/`.
- No suite was run and no mutation was applied; every "survives" above is reasoned from the code and would need the lead's scratch-copy run to be believed.
