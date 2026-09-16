# Audit — The server: security, access and data

Read-only run of track 2 on 16.9.2026, against `master` at `6af0a86`. Every
route file, `server.js`, `db.js`, the middleware, the access helpers and the
services behind them were read whole; the one-off scripts and the deploy
scripts were read for what they write. No server was started and nothing but
this file was written. Line numbers are as of that commit.

Counts: 2 critical, 2 high, 9 medium, 6 low.

## Findings

### 1. Anyone can pre-register a victim's email and keep a working password to the account the victim later verifies.
Severity: critical
Where: `chess_backend/routes/auth.js:40-59` (existing unverified account: a new code is mailed, **the password and name are left as the first registrant wrote them**); `auth.js:131-133` (`/verify-email` sets `is_verified = TRUE, verification_code = NULL` and nothing else); contrast `auth.js:316-326`, where the Google path recognises exactly this hazard and clears the password — but only for Google sign-in. No password-change or reset route exists anywhere in `routes/` (grep `reset|forgot|password_hash =` finds only the Google branch).
Why it matters: an attacker registers a child's address with a password of their choosing. The child later registers, is told „Email already exists but is not verified. A new verification code has been sent", receives the code at their own address, enters it, gets a token and uses the account for a week. The attacker logs in with the password they set at any time — trainers, homework, room codes, notifications, the parent's address on file. The child's own password was never stored, so after the seven-day token they cannot log in and there is no reset.
Proof: (1) `POST /register {email: V, password: A, name: N}`; (2) `POST /register {email: V, password: B}` → 200 `requiresVerification`; (3) `POST /verify-email {email: V, code}` with the mailed code → 200 token; (4) `POST /login {email: V, password: A}` → 200 token. A test driving the mounted router with a fake pool that records `UPDATE users SET password_hash` would show step (2) never writes one.
Fix direction: on the re-registration branch replace the password hash and name with the new registrant's, or refuse re-registration of an unverified address outright and let only the code path proceed; verification of an account should also invalidate any password set before the address was proven.

### 2. `POST /recordings/save` lets any account plant a "lesson recording" — with its own voice — in any other user's list, by naming them in `participants`.
Severity: critical
Where: `chess_backend/routes/recordings.js:191-196` (participants parsed from the body), `:204-217` (only the consent-stop's `blocked` ids are removed; nothing checks the ids against the roster or a relationship), `:219-222` (written as `participants`); readers `recordings.js:249` and `:269` (`$1 = ANY(sr.participants)` grants the list and the detail); the app lists these at `chess_app/lib/screens/home_screen.dart:608`. Also `recordings.js:45` — `roomId` is any string, never checked to be the caller's room.
Why it matters: the whole model of this app is that a minor is reachable only by an adult who has an accepted relationship (`social.js:480-494` enforces it for invitations). This route is a channel around it: the row carries a `title`, a `timeline_json` and `host_name`, and — if the attacker first records alone in a room they own, which `mayRecordRoom` allows for any stated adult — an audio file of their voice. It appears to the victim as a lesson they took part in, from a "trainer" they never met, and nothing in the row says otherwise. It is also a cross-account write: a user's own recordings list is data the account did not create.
Proof: `POST /rooms/create` (attacker); socket `joinGame` + `recording_status_update {status:'started'}` in that room; `POST /recordings/save` multipart with `roomId=<own code>`, `title=<text>`, `timelineJson=[...]`, `participants=[<victim id>]`, `audio=<file>` → 201 `audioSaved: true`. `GET /recordings` as the victim lists it. Without the socket step the same request still stores the row (audio refused, timeline kept). A route test with a fake pool asserting that the INSERT's `participants` contains only ids from `realtime.recordedRoster(roomId)` would fail today.
Fix direction: derive `participants` on the server from the recorded roster (and from the caller's accepted relationships), never from the body; require `roomId` to be a room the caller owns.

### 3. Socket `move` and `pgn_loaded` never ask whether the socket is in the room, and ignore the colour the trainer chose.
Severity: high
Where: `chess_backend/server.js:530-543` (`canMoveInRoom` reads only `rooms.board_control`; returns `true` for any value other than `host_only`/`trainer_only` and `true` when the room row is absent), `:545-555` (`move` broadcasts to `roomId` and writes `current_fen`), `:557-562` (`pgn_loaded`), `:695-697` (`audio_speaker_active`, no check at all). The guest list is asked only in `joinGame` (`server.js:317`); `io.use` at `:204-213` admits tokenless sockets. The app's values are `unrestricted`, `student_white`, `student_black` (`chess_app/lib/core/services/board_control_rules.dart:33`, `chess_game_screen.dart:3489-3491`).
Why it matters: once a trainer opens the board to students, any client that knows the six-digit code — signed in or not, invited or not, refused by `joinGame` or not — can push moves and PGNs into the live lesson and overwrite the room's stored position. `student_white`/`student_black` is drawn in the app as "only this student's colour"; the server enforces nothing of the kind, so the setting is a guard that silently does nothing. Finding 6 is the enumeration half of this.
Proof: connect a socket with no token; do not `joinGame`; emit `move {roomId: <code of a room with board_control 'unrestricted'>, currentFen: <anything>}` → every member receives `move` and `SELECT current_fen FROM rooms WHERE room_code = $1` returns the attacker's string. A server test with a fake pool answering `board_control = 'student_white'` and a socket whose `roomId` is unset would show `canMoveInRoom` resolve `true`.
Fix direction: require `socket.roomId === roomId` (the seat `joinGame` granted) on every room-scoped event, and decide `student_white`/`student_black` against the seat's colour on the server.

### 4. The one-off scripts run `TRUNCATE users … CASCADE` and `DROP TABLE puzzles CASCADE` against whatever `.env` names, with no guard — and on the development machine that is the managed cluster.
Severity: high
Where: `chess_backend/clear_users.js:2-9` (`require('dotenv')` → `require('./db')` → `TRUNCATE users RESTART IDENTITY CASCADE`); `chess_backend/import_new_puzzles.js:25` (`DROP TABLE IF EXISTS puzzles CASCADE`); neither checks `NODE_ENV`, `DB_HOST`, asks for confirmation or takes a `--yes` (grep `NODE_ENV|readline|confirm|DB_HOST` over the scripts finds only CSV readers). `server.js:132-135` recommends `node clear_users.js` "against a development database", but `db.js:34-41` connects to the one `.env` names, and CLAUDE.md records that the workstation and the droplet share one managed database.
Why it matters: one mistyped command on the owner's machine deletes every account, relationship, lesson, homework record, consent record and the rows `uploads/` files are reachable through, with `RESTART IDENTITY` handing old ids to new accounts (the shape `accountGuard.js:16-19` was written for). `import_new_puzzles.js` drops the puzzle table the tactics trainer serves from.
Proof: read `clear_users.js` — there is no branch that does anything but truncate. A dry run is not possible without the database, which is the point.
Fix direction: refuse to run unless `DB_HOST` matches a local address or an explicit `--i-mean-production` flag is passed, and print the target host and row counts before doing anything; move the scripts out of the server's root so they are not a `node` away from `server.js`.

### 5. A 100 MB JSON body is parsed for any caller of `/recordings/*` before authentication.
Severity: medium
Where: `chess_backend/server.js:93` (`app.use('/recordings', express.json({ limit: '100mb' }))`), mounted before any route; `routes/recordings.js:36` and `:243-285` apply `authenticateToken` inside the router, after the body has been read and `JSON.parse`d. nginx allows 120 MB (`deploy/app-setup.sh:134`).
Why it matters: an unauthenticated client can make the one-vCPU droplet buffer and parse 100 MB of JSON per request; `JSON.parse` is synchronous, so every other request — and every render frame — waits behind it. The multipart save does not need the JSON limit at all (`local_recording_service.dart:88-106` sends multipart), and the `audioBase64` path it was raised for is reachable only after login.
Proof: `curl -X POST /recordings/save -H 'Content-Type: application/json' --data-binary @100mb.json` with no token: the connection stays open while the body is read and parsed, and only then answers 401.
Fix direction: keep the 2 MB default for JSON everywhere and, if base64 audio must stay, parse the large body inside the route after `authenticateToken`, or drop the base64 path in favour of multipart.

### 6. `POST /rooms/join` is a room-code oracle that hands any signed-in user the whole room row.
Severity: medium
Where: `chess_backend/routes/rooms.js:46-64` (`SELECT * … WHERE room_code = $1 AND status = 'active'`, returned as `room`; no `mayJoinRoom`, no limiter); the column list is `db.js:68-95` (`creator_id`, `current_fen`, `board_control`, `allow_student_engine`, `allow_guests`). `mayJoinRoom` is applied only on the socket (`server.js:317`).
Why it matters: the socket's guest list decides who may enter, but this route answers "does this code exist, who made it, is the board open, are guests allowed" for every code, at whatever rate a client likes. With finding 3 it is how a stranger finds a room with an open board; with `allow_guests` it tells them which rooms they may walk into. Nothing ever writes `status = 'archived'` (grep finds no writer), so every room ever created stays enumerable.
Proof: authenticated `POST /rooms/join {roomCode: "123456"}` for codes 100000–999999; each hit returns `creator_id` and `board_control`. A route test asserting that a non-member receives 403 (or a row without `creator_id`) fails today.
Fix direction: answer through `mayJoinRoom` and return only what the joiner needs (the seat), and rate-limit the route like the login routes.

### 7. Socket `send_lesson_invite` has no relationship check, unlike its HTTP twin — and the app never receives what it emits.
Severity: medium
Where: `chess_backend/server.js:297-310` (any authenticated socket, any `studentId`, any `roomCode`; emits `lesson_invite_received` to `onlineUsers[studentId]`); the HTTP route for the same thing checks `acceptedEdgeBetween` at `routes/social.js:485-494`. The app emits it at `chess_app/lib/screens/home_screen.dart:891` and listens for `lesson_invite` at `home_screen.dart:338` — a different name; grep of `lib/` finds no `lesson_invite_received` listener.
Why it matters: the server-side hole is the model's rule written in one place and not the other: a stranger can address a pop-up to any online child by id, with a room code of their own. Today it lands on a name the shipped app ignores, so the trainer sees „Invitation sent … Connecting…" (`home_screen.dart:896-901`) and the student sees nothing — a feature `docs/STANJE-RADA.md:6351` lists as a working reason to keep the room-code field. A client that listens for the right name (any modified client) gets the pop-up.
Proof: from a socket authenticated as user A with no relationship to B, emit `send_lesson_invite {studentId: B, roomCode: '000000'}` → B's socket receives `lesson_invite_received {senderId: A, senderName, roomCode}`; a test asserting `action_denied` fails.
Fix direction: gate the handler on `acceptedEdgeBetween(pool, authUser.id, studentId)` and on the room being the sender's; fix the event name on one side (the name mismatch belongs to track 3).

### 8. `audio_url` is taken from the request body, stored, then used as a filesystem path by the renderer and as a URL by the app.
Severity: medium
Where: `chess_backend/routes/recordings.js:153` (`finalAudioUrl = req.body.audioUrl || null`, kept whenever no file and no base64 arrive), `:219-222` (stored); `recordings.js:331-336` (`audio_url.split('/uploads/')` → `path.join(uploads, parts[1])` → `videoRenderer.js:995` spawns `ffmpeg -i <that path>`); the app passes any absolute URL through unchanged (`chess_app/lib/constants.dart:17`) and plays it (`replay_player_screen.dart:105,185`).
Why it matters: the host of a recording controls a path the server opens: `/uploads/../narration/<name>.wav` reaches the private narration folder that `middleware/uploadsStatic.js:18` exists to keep off the network (names are random, so today this needs a name), and `/uploads/../../.env` is opened by ffmpeg (which will refuse it as audio — but the server should not be the one to find out). A stored `https://…` makes every participant's app fetch an attacker-chosen URL when they open the replay.
Proof: `POST /recordings/save` (multipart, no file) with `audioUrl=/uploads/../narration/x.wav`, then `POST /recordings/:id/export-mp4` → `[VIDEO_RENDER] … audio: <path outside uploads>` in the log (`videoRenderer.js:989`). A test on the export route asserting `audioFilePath` starts with the uploads directory fails today.
Fix direction: never accept `audioUrl` from the body — the server names the files it saved; when reading `audio_url` back, take `path.basename` and refuse anything outside `uploads/` (the same check `export-download` already makes at `recordings.js:444-451`).

### 9. Two routes spend third-party calls with no limiter and no quota: the Gemini narrative, and a `judgeLimit` that walks around the judge's limiter.
Severity: medium
Where: `chess_backend/routes/userGames.js:267-303` (`GET /games/prep/narrative`: one or two Gemini calls per request via `narrator.narrate`, `prepNarrative.js:120,133`; no `rateLimit`, no `requireQuota`, no `recordUsage` — the metered AI routes have all three at `routes/puzzles.js:827,851`); `userGames.js:352-355` and `:368-385` (`?judge=true&judgeLimit=N` judges up to `limit` nodes, `openingLeaks.js:103` caps that at 200; each `judge` costs two Lichess cloud evaluations, `openingJudgeService.js:317-338`), while `/opening-judge` itself is capped at 40/min (`routes/openingJudge.js:28-34`).
Why it matters: the Gemini key has no billing and a daily allowance of a few dozen requests (project memory); one free account in a loop exhausts it for every AI comment in the app. The cloud-eval path is the "scan of a service somebody else runs" the judge's limiter exists to prevent, reachable from a route that has none.
Proof: 50 × `GET /games/prep/narrative?subject=<own handle>` → 50–100 Gemini calls, no 429, no `usage_counters` row; `GET /games/openings/leaks?subject=…&judge=true&judgeLimit=200&limit=200` → up to 400 upstream requests from one call.
Fix direction: put the narrative behind `aiLimiter` and `requireQuota(ENT.AI_COMMENTS)` (and meter it); cap `judgeLimit` low and run the leaks route through `judgeLimiter`.

### 10. Scanning a 25 MB PDF is open to every free account at any rate.
Severity: medium
Where: `chess_backend/routes/scans.js:72` (`authenticateToken, upload.single('document')` — no `rateLimit`, no `requireEntitlement`, no `requireQuota`); `scanIntake.js:18` (25 MB), `positionScanner/index.mjs:23` (40 pages per scan); `scans.js:97` only *records* `SCANNED_PAGES`, and `entitlementService.js:61-66` has no quota for it.
Why it matters: pdf.js parsing of 40 pages of a 25 MB book is seconds of CPU on the droplet, on the same thread that draws films and answers polls (`LESSONS.md` records what one busy loop did to the progress bar). Nothing stops a free account from sending it in a loop.
Proof: 20 parallel `POST /scans` with a 25 MB PDF from one free account: all accepted, no 429; `usage_counters` grows but refuses nothing.
Fix direction: a per-account limiter on `/scans` and a `SCANNED_PAGES` quota per tier, checked before multer accepts the file.

### 11. Email addresses are written to the server log on every registration, verification and Google sign-in.
Severity: medium
Where: `chess_backend/routes/auth.js:51`, `:78` (`Failed to send verification code to ${email}`), `:120` (`logger.warn({ email }, …)`), `:143` (`logger.info({ email }, 'User email successfully verified')`), `:301`, `:318-319`, `:333`; `services/mailService.js:57`, `:136`; `services/logger.js` has no `redact` option.
Why it matters: most of these addresses belong to minors, and a parent's address goes through `mailService.js:136`. The log on the droplet is journald, kept by systemd's defaults and readable by anyone with a shell; a copied log is a list of children's addresses. Elsewhere the codebase strips emails from lists on purpose (`relationshipService.js:366-369`).
Proof: register once with SMTP configured and read the journal: the address appears three times before the first login.
Fix direction: log user ids, and give pino a `redact` list (`email`, `parent_email`) so a future `logger.info({ user })` cannot reintroduce them.

### 12. `checkUserLimits` is never called, so `ENABLE_LIMITS=true` changes nothing — while the app draws the limits it implies.
Severity: medium
Where: `chess_backend/limitsService.js:77-113` (the only guard for `maxSavedLessons`, `maxMonthlySessions`, `mp4ExportAllowed`); grep of `chess_backend` finds no caller outside the file; `ENT.UNLIMITED_LESSONS` / `UNLIMITED_SESSIONS` (`entitlementService.js:19-20`) are checked by no `requireEntitlement` anywhere. `GET /users/me/stats` returns `limits` and `limitsEnabled` (`limitsService.js:56-67`, `routes/social.js:323-331`), and the app renders "n / 20" and "n / 5" from them (`chess_app/lib/widgets/account_stats_card.dart:117,131`).
Why it matters: a switch documented in `.env.example:249` that does nothing when turned on is the recurring bug this codebase names; two paid entitlements are advertised and never enforced; and the account card tells a free user they have a ceiling the server does not hold. Not a security hole — a guard that cannot fail.
Proof: set `ENABLE_LIMITS=true`, save 21 lessons as a free account: all 201.
Fix direction: either call the check from `POST /lessons/save`, `POST /rooms/create` and the export routes (through `requireEntitlement`, which is where every other gate lives), or delete `checkUserLimits`, the two entitlements and the card's ceilings together.

### 13. A trainer's assignment list carries every student's email, against the rule the student lists keep.
Severity: medium
Where: `chess_backend/services/assignmentService.js:613-618` (`u.email AS student_email` in `getTrainerAssignments`, served by `GET /assignments/given`, `routes/assignments.js:508`); the rule it contradicts is written at `relationshipService.js:366-369` ("No email. A list of people is not the place for their addresses … most of the people in this one are children") and followed by `listStudents`, `listMembers` (`studentGroups.js:98-102`) and `roomGuests`.
Why it matters: a relationship can be started by the student (`social.js:77-116`), so the trainer may never have known the address; here every homework row hands it over. It is one hand-written column away from the decision the rest of the server took.
Proof: `GET /assignments/given` → each row has `student_email`. Grep the app for `student_email`: if nothing reads it (track 3 should confirm), the column is exposure with no reader.
Fix direction: drop `u.email` from `PROGRESS_COLUMNS`' trainer query; a trainer who needs to write to a student already has the address they invited by.

### 14. The droplet's public IP is in a tracked doc, against the written rule.
Severity: low
Where: `docs/TODO-objavljivanje.md:668` and `:730` (an IPv4 literal, the reserved address); the rule is `CLAUDE.md`, "Rules that bite": never IP addresses in `docs/`. Also `chess_app/lib/constants.dart:3` bakes a LAN address into the default `backendUrl`.
Why it matters: the repository is public. The reserved IP resolves from the domain anyway, so the exposure is small — but the rule exists so that nobody has to judge each case, and this one has been there since the deploy notes were written.
Proof: `git grep -nE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' -- docs` (excluding loopback).
Fix direction: replace with `<reserved-ip>` in the doc; make the app default a hostname.

### 15. Verification codes come from `Math.random()`; room codes were moved to `crypto.randomInt` for the same reason and this one was not.
Severity: low
Where: `chess_backend/routes/auth.js:25-27` vs `routes/rooms.js:9-16` (and `parentConsentService.js:165`, which uses `crypto.randomBytes`).
Why it matters: the code is the whole proof of an address (`emailVerification.js:33-53`), and the login limiter is per IP (`auth.js:15-23`), so a distributed guesser is limited only by the six digits. Predictable output is one more thing than it needs to be. Cheap to fix, low impact on its own.
Proof: read the two generators side by side.
Fix direction: `crypto.randomInt(100000, 1000000)`, as `rooms.js` does.

### 16. `POST /me/parent-email` sends mail to any address a signed-in user names, as often as they like.
Severity: low
Where: `chess_backend/routes/account.js:203-269` (no limiter; each call re-opens every `awaiting_parent` request and mails the new address, `:227-240`); the body of the mail names the caller and their trainer (`mailService.js:94-108`).
Why it matters: an authenticated relay for unsolicited mail from the project's sender to arbitrary recipients, with partly attacker-chosen content (the caller's own name). Needs an `awaiting_parent` relationship to fire, which limits it to accounts stated as minors. Deliverability of the sender domain is what it costs.
Proof: state a minor's year, accept a request, then loop `POST /me/parent-email {parentEmail: <victim>}` — one consent mail per call, no 429.
Fix direction: rate-limit the route and do not re-send when the address is unchanged.

### 17. The socket handshake also accepts the JWT in the query string.
Severity: low
Where: `chess_backend/server.js:205` (`socket.handshake.auth?.token || socket.handshake.query?.token`); the app sends it in `auth` (`home_screen.dart:274`, `chess_game_screen.dart:896`).
Why it matters: a seven-day credential in a URL is a credential in nginx's access log and in any proxy between; the app never uses the path, so it protects nothing.
Proof: connect with `?token=<jwt>` and read the nginx access log.
Fix direction: drop the query fallback.

### 18. Two other secrets travel in URLs and therefore in access logs.
Severity: low
Where: `chess_backend/routes/billing.js:175-176` (`?key=` is the whole RTDN authentication); `routes/assignments.js:724` and `routes/recordings.js:411-414` (report and download tokens, 60 days and 30 minutes) — the latter two are by design for browsers.
Why it matters: the RTDN secret is static; a leaked access log is a permanent forged-notification key. It cannot grant anything on its own (the payload is only a token to re-check, `billing.js:172-174`), so the cost is nuisance traffic and Pub/Sub noise.
Proof: read nginx's default `access_log` format; `deploy/app-setup.sh` does not change it.
Fix direction: move the RTDN check to a header Pub/Sub can set (an OIDC token), or at least strip the query from the access log.

### 19. Preview frames are drawn outside the queue, unmetered and unlimited per account.
Severity: low
Where: `chess_backend/routes/lessons.js:1154-1220` (`requireEntitlement` only; four frames per call, `renderPreviewFrame` on the main thread; the comment at `:1211-1214` says why it is not metered).
Why it matters: a premium account in a loop draws frames on the thread the queued film is using; the queue's fairness (`renderQueue.js:49-60`) does not see it. Bounded to entitled accounts, so low.
Proof: 100 parallel `POST /lessons/:id/preview-frames` with `beats: [0,1,2,3]` → no 429.
Fix direction: a small per-account limiter on the route.

## Suspicions

- **A startup `UPDATE` auto-verifies accounts.** `db.js:62` runs `UPDATE users SET is_verified = TRUE WHERE is_verified IS FALSE AND verification_code IS NULL` on every start. No current writer leaves an unverified row with a NULL code (`auth.js:68-70` always writes one), so it is dormant — but any future path that clears a code without verifying would be verified at the next restart. Confirm by grepping writers of `verification_code` after each change; consider deleting the statement now that it has done its migration.
- **The parent's "yes" does not require the relationship to still be waiting.** `parentConsentService.js:276-284` sets `status = 'accepted'` by id with no `AND status = 'awaiting_parent'`. Every path I traced that changes the row also deletes the request (`removeRelationship` cascades, `openRequest` deletes unanswered ones), so I could not build a case where a stale link accepts a live row. A test with a fake pool would settle it in a minute; the guard costs one clause.
- **A relationship with an account of unknown age is accepted without a parent.** `relationshipService.js:250-253` and `ageService.js:167-185` (`known: false → minor: false`). Documented as the grandfathering decision and as the open "account-level lock" in CLAUDE.md, so not reported as a finding — but it is the one place where "General Audience, 13+, parents cover 13–15" is enforced only for accounts that chose to state a year.
- **`parent_allows_recording` is still created at every start** (`db.js:378-381`) for a feature deleted on 26.8.2026; readers are only `parentConsentService.js` (a comment) and two tests. Harmless; a column that says a rule exists.
- **`rooms.status` is never set to `'archived'`**, so `/rooms/join`'s "has been closed" branch (`rooms.js:54-56`) is unreachable and `limitsService`'s monthly session count only ever grows.
- **Piper accepts any `voice` from `/export-video`** (`lessons.js:707`, `piper.js:197-206` falls back to the first model for an unknown name), while `/tts/sample` validates against the list (`lessons.js:168-171`). Path traversal is blunted by the `.onnx` suffix and the existence check; the inconsistency is the thing to confirm.
- **The render loop's `console.log` at `videoRenderer.js:989` prints `audioFilePath`**, which under finding 8 is attacker-chosen text written to the log (and via `console.log`, outside pino).

## For another track

- Track 3: the server emits `lesson_invite_received` (`server.js:304`) and the app listens for `lesson_invite` (`home_screen.dart:338`); `docs/STANJE-RADA.md:6351` cites the live invite as working.
- Track 3: `GET /users/me/stats` returns `limits` and `limitsEnabled` that nothing enforces (finding 12); `account_stats_card.dart:117,131` draws them.
- Track 3: `POST /rooms/join` returns `SELECT *`; which of `creator_id`, `board_control`, `allow_guests` the app actually reads decides how far finding 6 can be narrowed.
- Track 3: `GET /assignments/given` carries `student_email` — whether any screen reads it (finding 13).
- Track 3: the app's `audio_url` is passed through when absolute (`constants.dart:17`); with finding 8 fixed on the server the app should still refuse a foreign origin.
- Track 4: `recording_consent.test.js` and `parent_consent.test.js` still reference `parent_allows_recording`, a column no production code reads.
- Track 4: no test drives `POST /recordings/save` with a `participants` list that differs from the roster, and no test sends `move` from a socket that never joined; both mutations survive today.
- Track 1: `auth.js:357-366` says `/session/check` "does no database work"; since `accountGuard` it does one lookup per call — a comment, not a fault.

## What I did not cover

- `videoRenderer.js` beyond `ffmpegArgsFor`, `look` validation and the spawn; `positionScanner/*.mjs` beyond the page cap; `tts/piper.js`, `tts/windows.js`, `tts/google.js` beyond how `voice` reaches them; `polyglotRandom.js`, `openingBook.js`, `endgameDrill.js`, `tablebaseService.js`, `spacedRepetitionService.js`, `mistakeReviews.js`, `playerProfile.js`, the repertoire services (`repertoireLine/Frontier/Prune/Erase/Notes/Comments/Practice/Progress/Book/Archive`) — every one of their routes is `authenticateToken` + `req.user.id`-scoped at the route layer, and I read the routes, not the SQL inside each service.
- `gameArchiveImport.js` beyond the URL construction, the running-import guard and `OWN_GAMES_SQL`; the Lichess pacer.
- The `deploy/` scripts beyond nginx's body size, timeouts, forwarded headers and a grep for secrets (none); `deploy/site-setup.sh` not read.
- `.env.example` was checked only for real-looking values (a numeric Google client id, which also ships in the app; the service-account key line is placeholder-shaped) — I did not read it whole.
- The test suite: not run (a dev server may own port 3000), and not read except where a grep hit named a test.
- Whether `docs/arhiva/` already records any of these; I grepped `LESSONS.md`, `STANJE-RADA.md`, `TODO-provera.md` and `TODO-objavljivanje.md` for each finding's terms and found only the `uploads/` static-serving note (`LESSONS.md:1281`, `STANJE-RADA.md:2299`), which is why the public `uploads/` folder is not a finding here — it is already known and flagged as its own task.
- Live behaviour of Agora, Play billing and Azure was not exercised; findings about them are from code alone.
