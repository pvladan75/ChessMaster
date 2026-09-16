# Audit — The contract between app and server

Track 3 of `docs/AUDIT-BRIEF.md`, written 16.9.2026 from a read-only pass over
`chess_app/lib` and `chess_backend`. Nothing was run against a server or a
database; every proof below is stated as the request, query or two-client
check that would show it, and the lead re-derives before believing.

Method: every `Uri.parse('$backendUrl/…')`, helper call and `MultipartRequest`
in the app was paired mechanically with every `router.<method>(…)` under its
mount (script in the scratchpad, `track3/pair_routes.py`), and every
`socket.emit` / `socket.on` on both ends was listed and paired by name. The
REST half of the contract is, with the exceptions below, tight: 87 app calls
resolve to a route, request bodies match the destructured fields, and the
routes that answer with more than one status (`/lessons/:id/video`,
`/lessons/:id/export-video`, `/lessons/from-game/words`) are read by status on
the app side. **The socket half is not tight**: one commit renamed the
server's room events and deleted five handlers, and the app was never changed
to match. Findings 1–5 are that one fault seen through five controls.

## Findings

### 1. A peer's board never follows a move: the server relays `move`, the room listens for `moveMade`
Severity: high
Where: `chess_app/lib/screens/chess_game_screen.dart:1056` (`socket.on('moveMade', …)`, the only handler that calls `controller.loadFen` for a peer's move) and `:1996, :2022, :2218, :2291, :2457` (the app emits `move`); `chess_backend/server.js:545-549` (`socket.on('move', …)` relays `socket.to(roomId).emit('move', …)`). No `moveMade` exists anywhere under `chess_backend/` (grep). The rename is commit `6a6b0dd` (10.8.2026): its diff of `server.js` removes `emit('moveMade', …)` and adds `emit('move', …)`; the app's listener is unchanged since the initial commit `50d5dd7`.
Why it matters: the board the lesson is taught on. What still travels is `pgn_loaded` (`server.js:557-562` ↔ app `:1122-1136`), which the app emits beside every `move` — but the receiving handler rebuilds `moveTree` and puts the cursor back on the receiver's **own** path (`:1124`, `:1128-1129`) and never calls `controller.loadFen`; the board widget is driven only by that controller (`:710-714`). So a student's tree gains the trainer's moves while their cursor and board stay where they were. The trainer's navigation (`movePath`, `:2218-2224`) is likewise never seen. Nothing on either side reports an error.
Proof: two clients in one room; the trainer plays `e4`. The student's board is unchanged; their move tree shows `e4` with the cursor on the root. Or, without a UI: a Socket.IO client joined as a second member receives an event named `move`, never `moveMade`. The recording path is not affected (recording is only allowed alone, `services/recordingConsent.js`), which is part of why this survived: every live check of the room since 10.8 recorded in `docs/` is a one-device check.
Fix direction: one list of event names read by both ends — a constants file on each side pinned by a test that pairs every server `emit` with an app `on` and every app `emit` with a server `on`, by reading both sources. Then decide once whether the board follows the *move* event or the *pgn* event, and delete the other.

### 2. „Force student board to White/Black" does nothing: the server emits `board_flipped`, the app listens for `flip_board_forced`
Severity: high
Where: `chess_app/lib/screens/chess_game_screen.dart:1758` (emits `force_flip_board`) and `:1038` (`socket.on('flip_board_forced', …)`); `chess_backend/server.js:512-518` (handles `force_flip_board`, emits `board_flipped`). Renamed in `6a6b0dd` (diff lines `-flip_board_forced` / `+board_flipped`).
Why it matters: a trainer control that reports nothing and changes nothing on any student's screen; the same shape as the tree menu that drew actions it could not perform (`CLAUDE.md`, 7.9.2026).
Proof: trainer presses the control; the server log prints `[FORCE FLIP] Room … -> orientation: …` (`server.js:517`) and no student's board turns.
Fix direction: same as 1; this event is one rename.

### 3. „Position sent to trainer!" is shown for an event the server has no handler for
Severity: high
Where: `chess_app/lib/screens/chess_game_screen.dart:2501-2507` (emits `student_shares_position`, then `_showSuccess('Position sent to trainer (…)!')`) and `:1267` (`socket.on('student_position_shared', …)`, the trainer's dialog); `chess_backend/server.js` has neither name — the handler was deleted in `6a6b0dd` (diff lines `-socket.on('student_shares_position', …)` and `-emit('student_position_shared', …)`).
Why it matters: the recurring bug in `CLAUDE.md` in its purest form — a step that reports success and did nothing. A student is told the trainer has their position; the trainer is never asked.
Proof: student shares a position; the server's socket layer logs nothing (no handler, so Socket.IO drops the event) and no dialog opens on the trainer's screen.
Fix direction: either restore the handler (with the same `canAdministerRoom`-style check the other handlers have — it is a student sending to a trainer, so the check is „is the sender in this room") or remove the button. Not both halves left as they are.

### 4. „Invite to lesson" from the student list reports „Invitation sent" and the student never hears of it
Severity: high
Where: `chess_app/lib/screens/home_screen.dart:891-900` (emits `send_lesson_invite`, then shows `'Invitation sent for room …! Connecting...'`) and `:338` (`_socket.on('lesson_invite', …)`); `chess_backend/server.js:297-310` (handles `send_lesson_invite`, emits `lesson_invite_received` to the recipient's socket, writes **no** notification row). Renamed in `6a6b0dd` (`-emit('lesson_invite'` / `+emit('lesson_invite_received'`).
Why it matters: the other invitation path, `POST /invitations/send` (`routes/social.js:469-530`), writes a notification row and nudges `notifications_changed`, so an invite from the „create room with friends" flow (`home_screen.dart:761`) arrives even offline. This path has only the socket, and the socket event is misnamed — so an invite sent from the trainer's student list reaches nobody, online or off, and the trainer is told it did.
Proof: trainer invites an online student from the student list; the server logs `[REALTIME INVITE] …` (`server.js:301`); the student's app shows no dialog and `GET /notifications` returns no new row.
Fix direction: route this path through `POST /invitations/send` too, so the row exists; the socket is then only the nudge, as `services/realtime.js` already says it should be. Rename or delete the socket pair.

### 5. Four voice controls do nothing: mute student, allow speech, mute all, raise hand
Severity: high
Where (app): `chess_app/lib/screens/chess_game_screen.dart:3893` (emits `audio_mute_student`), `:3888` (`audio_allow_speech`), `:587-593` (`audio_raise_hand`, then sets `isHandRaised = true`), `:3918` (`audio_mute_all_students`); listeners `:1378` (`audio_force_mute_student`), `:1401` (`audio_force_unmute_student`), `:1423` (`audio_hand_raised_alert`). Where (server): `chess_backend/server.js:632-642` (`audio_mute_toggle`, which **does** accept a `userId` from an administrator — the working route the app never uses for anyone but itself, `:511`), `:687-693` (`audio_hand_raise_toggle`), `:644-657` (`audio_mute_all_students` flips `isMuted` in the roster and emits `audio_force_muted_all`, which no app code listens for). The five app names were deleted from the server in `6a6b0dd`.
Why it matters: „Mute student" and „Allow to speak" reach no handler. „Mute all students" changes the roster's `isMuted` flags, which the app reads only for its own `handRaised` (`:1315-1328`) — the microphone is closed only by `_agoraService.toggleMute` (`:510, :1382, :1405`), and the two callers that would do it for a trainer's order are the two dead listeners. So mute-all is a cosmetic change to a list. „Raise hand" is set locally and reset by the very next roster (`:1324`), and the trainer's alert never fires. The per-student voice *right* (`PATCH /trainer/students/:id/voice`, `routes/social.js:277-307` ↔ app `:548`, `voice_level_changed` ↔ `:1334`) is intact; these are the courtesy controls beside it.
Proof: trainer presses „Mute all students"; the students' rows show muted; a student keeps talking and is heard. A student raises a hand; nothing appears on the trainer's screen and the hand lowers itself on the next roster.
Fix direction: point the app's per-student mute at `audio_mute_toggle` with a `userId`, and have the app apply its own `isMuted` from the roster it already receives (or listen for `audio_force_muted_all`); rename the hand-raise pair. Then delete the four dead listeners.

### 6. A late joiner never receives the room's position; `rooms.current_fen` is written on every move and read by nothing
Severity: medium
Where: `chess_backend/server.js:551` (`UPDATE rooms SET current_fen …` on every move); the only other mention of the column in the server is its definition, `chess_backend/db.js:72`. `routes/rooms.js:54-59` (`POST /rooms/join` returns the whole row, so `current_fen` does reach the app) and the app reads nothing from that row — on a 200 it navigates with the code it typed (`chess_app/lib/screens/home_screen.dart:967-979`). The listener that would take the position, `socket.on('gameState', …)` at `chess_game_screen.dart:987-1003`, has no emitter: `6a6b0dd` removed all five `emit('gameState', …)` from `server.js`.
Why it matters: a student who joins after the trainer has set up a position opens on the standard start and — with finding 1 — stays there.
Proof: trainer loads a position, then a student joins. The student's board shows the initial position; the `rooms` row for that code holds the trainer's FEN.
Fix direction: on `joinGame`, send the row's `current_fen` (and `board_control`, `allow_student_engine`) in one event the app reads; or have the app read them from the `/rooms/join` answer it already has. Drop the column if neither is wanted.

### 7. The engine permission a trainer has already granted does not reach a student who joins afterwards
Severity: medium
Where: `chess_backend/server.js:399-402` (`permissions_updated` on join carries `boardControl` **and** `allowStudentEngine`); `chess_app/lib/screens/chess_game_screen.dart:1005-1019` (the `permissions_updated` handler reads only `boardControl`); `:1021-1036` (`engine_permission_updated` is read, but the server emits it only on a change, `server.js:505`); the app's default is `allowStudentEngine = false` (`:112`).
Why it matters: a student who arrives after the trainer enabled computer analysis has it off until the trainer toggles it off and on again — and nothing says so.
Proof: trainer enables the engine for students; a student joins; their engine switch is disabled.
Fix direction: read `allowStudentEngine` in the `permissions_updated` handler when present. One line.

### 8. `POST /games/mistakes` — the door for the client's engine findings — has no caller in the app
Severity: medium
Where: `chess_backend/routes/mistakeDrill.js:47` (the route; its header at `:40-46` says the engine pass „runs on the client" and this is „where engine findings come in"); `docs/PLAN-MOJE-PARTIJE.md:355-357` says the same. In the app, `chess_app/lib/features/archive/services/archive_api_service.dart:190, :225, :238, :248` call `/games/mistakes/due`, `/:id/grade`, `/stats`, `/recurrence` — and nothing under `lib/` posts to `/games/mistakes` (grep). The only writer of `mistake_reviews` is the server-side endgame audit, `chess_backend/services/mistakeReviews.js:99`.
Why it matters: the drill works for tablebase mistakes and can never contain an engine mistake; the recurrence buckets by tactical motif (`/recurrence`) and the route's six named rejection reasons are unreachable. A feature complete at every layer and reachable from nowhere — the shape `CLAUDE.md` records for the arrows nothing wrote.
Proof: `grep -rn "games/mistakes'" chess_app/lib` finds no `POST`; `GET /games/mistakes/recurrence` for any account returns only material-signature buckets.
Fix direction: either build the client half the plan describes or mark the route and the motif half of `/recurrence` as not yet reachable in `STANJE-RADA.md`, so nobody reads the drill's tally as covering engine mistakes.

### 9. The step builder truncates silently at caps the app does not know, against its own rule of refusing rather than repairing
Severity: medium
Where: `chess_backend/services/lessonSteps.js:251-255` (`text(value, limit)` returns `trimmed.slice(0, limit)`), applied to the task at `:103` (`MAX_INSTRUCTION = 500`), the title at `:82` (200), the line at `:86-87` (`pgn`, 100000), each choice's text at `:207` (200) and every SAN at `:139, :163, :178` (20). The same file's header (`:44-45`) says the builder „refuses rather than repairs", and `acceptedSans` is indeed refused over its cap (`:172-173`). On the app side there is no `maxLength` anywhere under `chess_app/lib/features/tutorial_studio/` (grep), and the save path reports success on any 201 (`chess_app/lib/features/lessons/services/lesson_api_service.dart:380`).
Why it matters: a task longer than 500 characters, or a part whose annotated line exceeds 100 KB, is stored cut and announced as saved. The app's own defence — reading the line back through `LessonStepLine` before sending — runs on the *untruncated* text, so it cannot see this. A line cut mid-token is exactly the „step that does not replay" the read-back was built to stop.
Proof: `POST /lessons/save` with one step whose `instruction` is 501 characters answers 201; `GET /lessons/:id` returns 500. Reopening in the studio shows the shortened task with no notice.
Fix direction: refuse over the cap with a 400 and the number, as `acceptedSans` does; serve the caps to the app the way `maxMs` is served (`routes/lessons.js:603`), or cap the fields in the studio. Not a silent slice.

### 10. A render progress answer that is not 200 and not 404 is read as „still drawing", forever
Severity: medium
Where: `chess_app/lib/features/lessons/services/lesson_api_service.dart:600-607` (404 becomes an error object; any other non-200 returns `null`); `chess_app/lib/features/tutorial_studio/services/tutorial_video_export.dart:413-415` (`if (at == null …) return;` — the 900 ms timer at `:507` asks again). On the server, `chess_backend/routes/lessons.js:1080` answers 400 for a malformed job id and `:1090-1092` answers 500 when the row cannot be read.
Why it matters: a server fault during a render is indistinguishable, on the trainer's screen, from a slow film: the bar freezes at its last value and the dialog polls until it is closed by hand. The brief's „error answers the app cannot tell apart".
Proof: make the progress route answer 500 (or poll with a job id the server rejects); the app's bar neither errors nor finishes.
Fix direction: count consecutive non-200 answers in the poller and end with the server's sentence after a few; or return a distinct failed status from `renderStatus` for 4xx/5xx.

### 11. Two refusals of a voice sample lead to different actions and arrive as one sentence
Severity: low
Where: `chess_backend/routes/lessons.js:170` (404, „This server does not have that voice") and `:175` (503, „The voice produced nothing. The server log says why."); `chess_app/lib/features/lessons/services/lesson_api_service.dart:703-706` (logs the status, returns `null`, discards the body); `chess_app/lib/features/tutorial_studio/services/tutorial_video_export.dart:1033-1035` (one sentence for every `false`).
Why it matters: a trainer told „the server log says why" for a voice the server simply does not list will read a log for nothing, when the answer was „pick another voice". Same family as the two refusals that `RenderAccountBusy` was split off for.
Proof: request `/lessons/tts/sample?voice=nonexistent`; the sheet says the log knows why.
Fix direction: return the server's sentence from `fetchVoiceSample` (or the status) and show it.

### 12. A lesson title over 255 characters is a 500 that reads as „saving is broken"
Severity: low
Where: `chess_backend/db.js:129` (`title VARCHAR(255) NOT NULL`); `chess_backend/routes/lessons.js:66` and `:194` check only presence; the clone route already guards this exact overflow (`:43-60`, `copyTitle`). The studio's title field (`chess_app/lib/features/tutorial_studio/screens/tutorial_studio_screen.dart:1894`) has no `maxLength`, and the app shows the server's generic sentence (`lesson_api_service.dart:381-383`).
Why it matters: rare, but the sentence the trainer gets is „Server error while saving lesson", which is the wrong diagnosis.
Proof: `POST /lessons/save` with a 256-character title answers 500 (driver 22001).
Fix direction: a 400 with the limit on both routes, and `maxLength: 255` on the field.

### 13. One `join_refused` event answers two doors, and the app leaves the room on both
Severity: low
Where: `chess_backend/server.js:328` (refusal of `joinGame`) and `:581` (refusal of `audio_join`) emit the same event; `chess_app/lib/screens/chess_game_screen.dart:964-985` handles it once and pops the screen after 1.2 s (`:982-984`).
Why it matters: a member whose voice join is refused (the guest switch turned off, an invitation declined, between the board join and pressing „voice on") is ejected from a room they are in, with a sentence about not being on the list.
Proof: admit a guest, turn `allowGuests` off (`PATCH /rooms/:code/guest-access`), have the guest press voice on: the room closes under them.
Fix direction: a separate event (or a `door` field) for the voice refusal, handled without leaving.

### 14. Dead ends on the socket, both directions
Severity: low
Where: server emits nobody reads — `role_changed` (`server.js:359, :421`; the app listens for `user_role_changed` with a `targetUserId`, `chess_game_screen.dart:1153`, and takes its seat from `room_members_list` instead, `:1146-1148`, so only the „You have been promoted" notice is lost); `recording_status_changed` (`:490`; app listens for `recording_status_update`, `:1225` — moot while recording is allowed only alone); `audio_speaker_active` (`:695-696`, relayed for a client that never sends it); `blunder_alert_toggled` / `toggle_blunder_alert` (`:520-526`, nothing in the app emits or listens); `audio_force_muted_all` (`:655`). App listeners with no emitter — `user_presence_changed` (`home_screen.dart:303`; the server has no presence broadcast at all, and `routes/social.js` never reads `onlineUsers`), `session_invite_received` (`:330`; `/sessions/schedule` does write a notification, `routes/social.js:576`, so the bell covers it). App emits with no handler — `leaveGame` (`chess_game_screen.dart:369`; harmless because `socket.disconnect()` follows at `:371` and the server's `disconnect` does the work). Payload fields the server deliberately ignores — `userId`, `userName`, `role`, `playerColor` in `joinGame` (`:918-924` ↔ `server.js:312`, identity comes from the token; `playerColor` is destructured and never used).
Why it matters: each is small; together they are why nobody noticed findings 1–5 — half the names in the room screen have no counterpart, so a missing one looks normal.
Proof: the paired list in this file; `grep` either tree for each name.
Fix direction: covered by the shared-names test in finding 1; delete what it flags.

### 15. Server routes nothing in the app calls
Severity: low
Where: `GET /agora/config` (`routes/agora.js:25`), `GET /billing/usage` and `/billing/usage/me` (`routes/billing.js:95, :111`), `POST /games/import` — the Lichess-by-username import (`routes/userGames.js:135`; the app offers only pasted PGN and a file, `archive_api_service.dart:68, :84`), `POST /games/prep/import` and `GET /games/prep/narrative` (`:230, :267`; the opponent-prep policy is off by default, so this may be deliberate), `GET /games/stats` (`:449`), `GET /repertoire/weak` (`routes/repertoire.js:663`), `POST /users/account-type` (`routes/social.js:340`; the admin grant, done by hand), and the un-prefixed aliases `POST /google` and `POST /verify-email` (`routes/auth.js:275, :94`; the app calls `/auth/google` and `/auth/verify-email`). Excluded on purpose: `/consent/:token`, `/reports/:id`, `/billing/play/rtdn` and `/recordings/export-download/:filename`, which are for a browser, Google, or a link the server itself hands out.
Why it matters: each is surface that is tested, kept and never exercised by a user; `/games/import` in particular is a whole import path the plan describes and the app does not offer.
Proof: `pair_routes.py` in the scratchpad; confirmed by grep of `chess_app/lib` for each path.
Fix direction: a one-line note per route in `STANJE-RADA.md` saying whether it is waiting for a client or is a maintenance door; delete the rest.

### 16. Caps kept on both ends by hand, consistent today
Severity: low
Where: note length 2000 — `routes/assignments.js:39` and `services/assignmentNotes.js:14` against `chess_app/lib/features/assignments/widgets/parent_report_dialog.dart:166` and `screens/assignment_review_screen.dart:76`; scan task text 500 — `routes/scans.js:267` against `chess_app/lib/features/position_scanner/screens/saved_positions_screen.dart:301`; multiple-choice count 2..4 — `services/lessonSteps.js:16-17` against `tutorial_studio_screen.dart:1854` and `services/tutorial_import.dart:336`. The one number that is derived rather than copied is the narration cap (`routes/lessons.js:603` → app `lesson_api_service.dart:909`, with a fail-safe fallback).
Why it matters: none has drifted; the brief asks whether one end derives from the other, and here neither does. The next change to any of them is a change in two or three places.
Proof: the line pairs above.
Fix direction: nothing urgent; if a caps endpoint is built for finding 9, these belong on it.

## Suspicions

- **`express.json({ limit: '2mb' })` against a large tutorial.** `server.js:94` bounds every JSON body; a step's `pgn` may be up to 100 KB (`lessonSteps.js:86`), so a tutorial of twenty richly annotated parts could exceed it. A 413 from body-parser arrives as Express's HTML error page, and the app would show „Save failed (413)". Not confirmed: no measurement of how large a real game tutorial's `positionList` gets. Confirm by saving one produced from a long reviewed game with the studio's arrows and comments.
- **`quick_answer` wire values are Serbian** (`server.js:670`, `['da','ne','nejasno']`; app `chess_game_screen.dart:524-526` uses the same keys). Consistent, and the brief allows wire values; noted only because the English-pivot gates are blind to them and a future „translation" of one end would break the pair silently.
- **The room's `boardControl` vocabulary.** The server enforces `host_only` / `trainer_only` (`server.js:540-541`); the app's rules file names the same two (`core/services/board_control_rules.dart:33`) and the screen also writes `'all'` (`chess_game_screen.dart:198-199, :3049-3051`). The server treats anything else as „everyone may move", so `'all'` works by falling through rather than by being known. Confirm by reading what the settings dialog offers and whether a third value exists anywhere.

## For another track

- Track 4: no test on either end names the room's socket events — `grep` of `chess_app/test` finds `'move'` only as a map key in unrelated tests, and `chess_backend/test` names none of `moveMade`, `board_flipped`, `role_changed` — so findings 1–5 were invisible to both suites since 10.8.2026; a source-reading test pairing `emit` and `on` across both trees would have gone red on the day.
- Track 1: `chess_game_screen.dart` carries listeners and emitters for at least eight events with no counterpart (`gameState`, `moveMade`, `flip_board_forced`, `user_role_changed`, `recording_status_update`, `student_position_shared`, `audio_force_mute_student`, `audio_force_unmute_student`, `audio_hand_raised_alert`, `leaveGame`, `student_shares_position`, `audio_raise_hand`, `audio_mute_student`, `audio_allow_speech`) — dead code in the one screen a live lesson runs on.
- Track 2: `server.js:545-549` relays the client-supplied `role` field of a `move` unchanged to the room; nothing reads it today (finding 1), but if the listener is restored it should not be trusted for anything.
- Track 1: `docs/PLAN-MOJE-PARTIJE.md:355` describes a client-side engine pass over the archive that feeds `POST /games/mistakes`; if that pass exists under another name it is not wired to this route (finding 8), and if it does not exist the plan overstates what was built.

## What I did not cover

- Response shapes field by field for the large list answers (`GET /assignments/:id`, `/trainer/panel`, `/repertoire/tree`, `/games/openings/leaks`, `/lessons` rows); I paired request bodies and query names for every route and read the answers only where the app branches on them.
- Payload shapes of the socket events whose names do match (`room_members_list`, `audio_users_list`, `recording_consent`, `quick_answer`), beyond the fields the app reads.
- The parent-consent page and the parent report (browser contracts, not app–server).
- The Google Play RTDN body and the purchase-verify answer beyond the field names.
- Anything executed: by the brief's rules no request was sent, no socket connected and no query run; every proof above is the one the lead can run.
