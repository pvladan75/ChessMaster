# PLAN-SESIJA — the live session, reorganised

Status: **adopted 21.9.2026 with the owner's five answers (§5), nothing built.**
Phase 1 is built (item 219 is its live check). Phase 5b's sharing is decided:
in the app only, by relationship, with download — no public link.

## 1. What was reported, and what it was

The owner's live attempt of 21.9.2026, two accounts, two devices: no voice, a
recording that started „with several present", and confusion about who leads.

The server log settles all three with one fact: **the two accounts were in two
different rooms.** One sat in `856933` (student seat), the other in `192803`
(owner seat). The Agora channel *is* the room code, so each was alone in a
channel; `mayRecordRoom` allowed the recording because the owner of `192803`
really was alone in it; and each saw a room containing only themselves. The
owner confirmed it: he had pressed Join on an **old invitation** in the bell.

Every layer was right and the feature was still dead (rule 10). The wrong room
was reachable because of four things, all measured in code:

| # | Fault | Where |
|---|---|---|
| F1 | **A room never ends.** `rooms.status` allows `'archived'` and nothing ever writes it; every `POST /rooms/create` mints a new code and the old ones stay open for ever | `db.js:78`, `routes/rooms.js:20` |
| F2 | **An invitation never dies.** The bell keeps a working Join for a session that finished days ago | `routes/social.js:469`, `home_screen.dart:699` |
| F3 | **The saved „active session" is cleared only by the Leave button** — not by back, not by a refused join, not by the room being dead — and while it is set, `_checkNoActiveSession` blocks every other room and offers only the way back into the stale one | `game_session_service.dart`, `home_screen.dart:1000`, `chess_game_screen.dart:330` / `:1016` |
| F4 | **The room never says who is missing.** A student alone in a room sees a board, not „your trainer is not here" | `chess_game_screen.dart:3579` — the roster is a card far down the right column |

Found beside them by the inventory of the room screen (each spot-checked):

| # | Fault | Where |
|---|---|---|
| F5 | Four definitions of „who leads": the class getter, two local `isHost` that add the **account** role, and an `isTrener` that excludes `'host'`. `canDriveSharedBoard` trusts `accountRole == 'trener'` outright, although `users.role` is meant to play no part in teaching | `chess_game_screen.dart:268/699/752/3087/3342`, `board_control_rules.dart:31` |
| F6 | „Demote to User" sends `newRole: 'korisnik'`, which the server's whitelist refuses — the control cannot succeed | `chess_game_screen.dart:3648`, `server.js:417` |
| F7 | „Student plays as White / Black" are **labels only** — nothing filters a move by colour on either end; and a fresh room arrives as `host_only`, which the dropdown has no item for and the student reads verbatim as „Permission status: host_only" | `board_control_rules.dart:33`, `roomBoardEvents.js:42`, `chess_game_screen.dart:3434/1806` |
| F8 | Voice fails silently: a failed `initAgora`, or any non-403 failure of the token route, is a `print` and the panel flips back to „off" with nothing said | `agora_service.dart:149/229/258` |
| F9 | `voice_level_changed` is sent through `emitToUser`, which knows only sockets that sent `register_user` — and only Home's socket does, which two entry paths disconnect before opening the room. „Grant microphone" therefore does not reach the student it is granted to while they are in the room | `routes/social.js:291`, `home_screen.dart:285/348/845` |
| F10 | On a phone, a student has **no drawer** (`hasDrawer = !isWide && isTrener`), so „Show my position to trainer" — a student-only button — is unreachable for students | `chess_game_screen.dart:4189/3285` |
| F11 | `_recordingAllowed` starts `true` and waits for the server to say otherwise | `chess_game_screen.dart:115` |
| F12 | Small dead things: `playerColor` on the wire, read by nobody; a raised hand cannot be lowered; two board-view switches that govern nothing in the room; a shared position never carries its title | inventory §11 |

**Not yet known:** whether voice works once both people are in the *same*
room. Both got PUBLISHER tokens, so the server half is fine; the client half
has not been observed. Phase 1 makes that test possible; do not assume it.

## 2. The model proposed

Five sentences, each of which the screen must be able to say.

1. **A session has a beginning and an end.** The trainer starts it and ends
   it. Ending archives the room, sends everyone home with „The session has
   ended", and kills its invitations.
2. **A trainer has at most one live session.** Starting a new one ends the
   previous one. So „Vladan's session" is unambiguous, and a student can be
   offered *„Vladan is in a session — Join"* on Home without any code or any
   notification being involved.
3. **One person leads: the one who started it.** No co-host, no promotion, no
   account role. One predicate, `seat == 'trener'`, in one place.
4. **The room says who is here.** Roster in the header, always. A student
   alone reads „Waiting for Vladan"; a trainer alone reads „Nobody has joined
   yet".
5. **A session with other people in it has no recording.** Not a disabled
   button — no button. Recording is something an adult does alone, and it is
   offered where they are alone.

## 3. What goes

Each is either broken, unenforced, or a second way of doing something.

| Remove | Why |
|---|---|
| The `'host'` (co-host) seat, `change_user_role`, „Promote to Host" / „Demote to User" | F5, F6; „who leads" has to have one answer |
| `accountRole` in `canDriveSharedBoard` and in both local `isHost` | contradicts „trainer is a position in a relationship" |
| `student_white`, `student_black`, `host_only` as distinct values | F7. Two states remain: **Only I move** / **Students may move**. The server normalises old values on read |
| „Mute all students" | per-student mute on the roster does it; one control fewer on a full card |
| `playerColor` in `joinGame`; the two inert board-view switches | dead |
| Recording in a room, whole — card, socket events, the roster lock, Agora capture | the owner's answer 3; phase 5a. Recording returns in Preparation, phase 5b |
| `POST /sessions/schedule` and door 4 of `mayJoinRoom`; the guests switch; invitations made before the room exists | answers 4, 2 and 5 |
| The blocking „You are already in a session" dialog | replaced by „Leave 856933 and join 192803?" — and a dead room is cleared without asking |

Kept on purpose: quick answers, raise hand (fixed so it can be lowered),
grant/revoke microphone, „Allow engine for students", force flip, „Show my
position", the Library column, Export to Analysis.

## 4. Phases

Every phase: baseline first (app 3594, backend 1550 / 1644), gate written and
watched red before the code, mutation round after. Server files are edited in a
worktree and copied in on the owner's word (nodemon, rule 20).

**Phase 1 — a session ends; stale doors close.** ✅ built 21.9.2026 by the lead, live check is item 219
- *As built:* `services/roomLifecycle.js` (end, end-previous, state);
  `mayJoinRoom` refuses `'archived'` with `ended`, asked **after** the seat so a
  stranger is never told a code once named a room; `realtime.closeRoom`
  announces, then empties, then forgets, and `server.js` registers its rosters
  as a closer; `/invitations/send` takes only the sender's own live room;
  `room_live` on every notification. In the app: `RoomSessionApi`,
  `GameSessionService.reconcile` / `makeWayFor` / `clearIf`, „End session" for
  the owner's seat, `session_ended`, a refused join forgets the save, the bell
  draws Join only on `room_live == true`. Scheduled sessions, the panel's
  „Today", the friends dialog before the room, `_inviteStudent` (unreachable
  already) and Home's friends fetch are gone; the guests switch is drawn only
  for a room that is open or will not say.
- *Found by the live pass, fixed the same day:* `audio_leave` took a seated
  socket out of the room (`services/roomVoiceEvents.js`), and a room socket
  closing wiped Home's presence registration (`realtime.goOffline`) — half of
  F9. Items 219.11–12.
- *Not built here:* `GET /sessions/live` and „*Name* is in a session — Join"
  stay in phase 2.
- *The plan as written:*
- `rooms`: `created_at`, `ended_at`. `POST /rooms/:code/end` (owner only) sets
  `status='archived'`, emits `session_ended` to the room, empties the roster.
  `POST /rooms/create` ends the caller's previous live room first.
- `mayJoinRoom` refuses an archived room with a new reason `ended` — one home,
  so socket, `/rooms/join` and `/agora/token` all inherit it.
- Notifications carry `roomLive`; the bell draws Join only when true, otherwise
  „This session has ended".
- `GET /rooms/:code/state` → `live | ended | not-yours`. Home asks it for the
  saved active session on load; anything but `live` clears it silently. A
  refused join clears it too (F3).
- App bar: the owner's „Leave session" becomes **„End session"** (confirm);
  a student's stays „Leave". `session_ended` pops the room and clears the save.
- With it, by the owner's answers: scheduled sessions out, the guests switch
  hidden, and one „New session" that creates the room with nobody invited —
  inviting happens inside (§5, 2/4/5).
- Gate: real-database cases for end / create-ends-previous / refuse-archived;
  app cases that a dead saved session is gone after Home loads, and that an
  invitation to a live room is joinable *while another room is saved*.
- No sweep at server start. Rooms that are already stale are closed once, by
  hand, on the owner's yes.

**Phase 2 — the room says who is here.** `[implementer]`
- Roster chips in the header on every layout; the waiting sentence of §2.4.
- Home: „*Name* is in a session — Join" from `GET /sessions/live` (rooms of my
  accepted trainers that are live and that I may join — through
  `mayJoinRoom`, not a second condition).
- Gate at 360 dp: header fits, sentence present when alone, gone when not.

**→ Owner's two-device voice test goes here**, before phase 4 is scoped.

**Phase 3 — one leader, two board states.** ✅ built 21.9.2026 by the lead, live check is items 219.18–20
- *As built:* `leadsRoom`, `boardIsOpen`, `boardLocked` / `boardOpen` in
  `board_control_rules.dart`, with `accountRole` gone from
  `canDriveSharedBoard`; the room's one getter `isLeader` in place of four
  definitions; a „Students may move" switch in place of the four-item list;
  the student reads a sentence, never a column value; promotion, its menu and
  its notices removed. Server: `canAdministerRoom` is the creator and nobody
  else, `change_user_role` is gone, a seat no longer survives a rejoin,
  `change_permissions` stores one of two values (`boardControlFor`) and
  refuses anything that is not a board state. `playerColor` left the wire.
- *Found on the way:* the board's orientation asked for the co-host seat by
  name, so every trainer since „New session" opened on Black's side.
- *Left alone, flagged:* `mayTeachInRoom`. With a one-way door the creator is
  always the trainer of everyone present, so its „trainer of somebody present"
  half can no longer differ from „opened the room and teaches somebody". It is
  a simplification the owner may want; nothing is wrong with it as it stands.
- *The plan as written:*
- One getter; delete the three others, the co-host seat and its server
  handler; drop `accountRole` from `board_control_rules.dart`.
- Board control to two values; server maps old ones on read; the student's
  line says a sentence, never a raw value.
- Gate: a source-structure test that `isHost`/`isTrener` are defined once;
  rules test without `accountRole`; `room_board_events` for the mapping.

**Phase 4 — voice that says what it is doing.** ✅ built 21.9.2026 by the lead; live check is items 219.21–27
- *The owner's two-device test passed:* both hear each other in one room. So
  the phase is about saying things, not about making voice work.
- *Built (server, first part):* presence holds **every** socket a person has
  (`realtime.setOnline` / `goOffline` / `socketIdsOf`), and `joinGame`
  registers the room's socket. That is F9: „Grant microphone" now reaches a
  student sitting in the room, whose Home socket is disconnected meanwhile.
  Live check 219.21.
- *Built (app), in the order it was planned:*
  1. **Failures say why.** The seat is asked for **before** the engine is
     started, and the answer has a fourth field: `failure` beside `refused`,
     because an empty token alone cannot tell a silent server from one that
     runs without an App Certificate, which is a working setup. A silent
     server stops the join („Voice could not start: the server did not
     answer."); an engine that will not start keeps its reason and says it; a
     join Agora itself turns down — which never called back, so the panel
     span for ever — is heard through `onConnectionStateChanged`. The seam for
     the engine is `engineFactoryOverride`. Gate: `voice_seat_test.dart`.
  2. **„*Name* is in voice — Join voice"**, `RoomVoiceInvite` in
     `AppBar.bottom`, drawn only while `voiceInviteLine` is not null: my voice
     off, somebody else's on. The trainer is the name said. It calls
     `_joinVoice`, the panel's own door — a source case holds it to that. The
     gate measures the strip at 360 x 640 and 760 x 360 **on Android and
     Windows**, which caught a 24 px button on the desktop's compact density.
  3. **The voice is announced again** when the room's socket is seated anew
     while the call is up — on `role_changed`, which the server sends once per
     seating, and **not** on `connect`: the voice roster reads the role from
     the seat, and an announcement that beats it lists a trainer as a student.
  4. **A dead microphone is said.** `microphoneProblemFor` reads Agora's
     local-audio state — the only witness on Windows, where
     `permission_handler` always answers „granted". The panel keeps its
     controls: the person is in the call and hears it.
- *Found on the way, server, proved in a scratch copy and copied in on the
  owner's word with the server off:* (a) when the **last** person left the voice nothing was sent, so
  everybody whose voice was off kept the last list — „In call: Vladan." for a
  call nobody was in, which item 2 would have made loud (rule 14); (b) both
  rosters are keyed by person and a closing socket deleted **by person**, so
  the late `disconnect` of a dropped connection unseated whoever had already
  come back on a new socket — which item 3 makes the normal case.
  `dropEntry` in `services/roomVoiceEvents.js` removes only what the closing
  socket wrote; the voice half of `disconnect` moved beside `audio_leave`.
  Backend 1569 → 1575 without a database, 1677 with one (both measured), six
  mutations caught.
- *Not doing here:* a persistent voice chip in the bar — the bar already holds
  five actions at 360 dp; phase 6 places it.
- *The plan as written:*
- A voice chip in the header: off / listening / talking / **failed: why**.
  Every `print` in `agora_service.dart` that ends a join becomes a reason.
- When the trainer's voice is on and mine is off: „Vladan is talking — Join
  voice". The microphone still opens only by the person's own tap — that rule
  stays.
- `voice_level_changed` is emitted to the **room**, not through
  `emitToUser` (F9).
- Windows: `permission_handler` always answers „granted", so a join with a
  dead microphone is detected from Agora's local-audio state, not from the
  permission.

**Phase 5a — recording leaves the room.** `[lead]` deletion, `[implementer]` app
- The „Session recording" card, `recording_status_update`, `recording_consent`
  / `_denied` / `_must_stop` / `_status_changed`, the roster half of
  `mayRecordRoom` and the Agora capture (`startAudioRecording`) all go.
  **`uploads/` and the `session_recordings` rows are not touched**; the player
  and the MP4 export keep working on what exists.
- Deleting the lock is safe only in this order: the *writer* goes first
  (`POST /recordings/save` stops accepting a room's audio), then the checks
  that guarded it. Never the other way round.

**Phase 5b — „Record a lesson" in Preparation.** the owner's idea of 21.9.2026; to be designed
- An adult alone at the board: plays moves or steps through a loaded PGN,
  talks, and the app keeps the move timeline and the voice together.
- Almost all of it exists. The timeline recorder, the player and the MP4
  export are the room's and survive 5a; the microphone is the studio's local
  recorder (`record_pcm_source.dart`), so **no Agora and no metered voice
  seconds**; the lock is `mayRecordNarration` — eighteen, a known age, no
  room and therefore no roster to get wrong. That last point is the gain:
  today's fault („recorded with several present") becomes impossible by
  construction rather than by a check.
- What is new is **reaching students**. A recording is readable today only by
  its host and its participants (`routes/recordings.js`), and alone that is
  one person. Proposed: „Share with…" students or a group, read through
  `acceptedTrainersOf` like everything else a student sees because somebody
  teaches them; the student opens it in the app's player, and the MP4 is a
  download for the trainer. **No public link** — a URL that plays without an
  account is outside every consent rule this app has, and MP4 exports age out
  on a timer, so a link sent in a chat would also die quietly.
- It does not replace tutorial narration: that one is scripted (bound to a
  beat list), this one is free. They share the film pipeline and the lock.

**Phase 6 — the screen.** `[implementer]`
- Header: code · roster · voice · End/Leave. Right column: moves and comment.
  The trainer's switches in one „Session" sheet. Student on a phone gets
  „Show my position" and the quick answers under the board (F10).
- Gate: 360 x 640 and 760 x 360, every seat, nothing clipped — measured
  rectangles for the board, not only „no overflow".

**Phase 7 — live pass**, two devices, items in `docs/TODO-provera.md`.

## 5. The owner's answers, 21.9.2026

1. **One live session per trainer: yes.** Starting a new one archives the
   previous one.
2. **Guests: hidden.** The switch leaves the „Room access" dialog until
   parent observation is built. `allow_guests` stays in the schema, `FALSE`;
   `asGuest` in `mayJoinRoom` stays, since it is also what words the refusal.
3. **Recording leaves the room** (phase 5a). The owner proposed recording a
   lesson alone in Preparation, with sound, saved as video, downloadable and
   reachable by students — phase 5b. Sharing is **in the app only**, by
   relationship, with a download for whoever it is shared with; the owner never
   meant a public link.
4. **Scheduled sessions: removed**, in phase 1 — `POST /sessions/schedule`,
   door 4 of `mayJoinRoom`, and the reader in `trainerPanelService.js`. No
   `.dart` file references any of it (grep, 21.9.2026). The two tables are
   left in place; dropping them is a separate yes.
5. **Invitations: from inside the room only.** `_createRoomWithInvites`, the
   friends dialog before the room and `_inviteStudent`'s create-and-invite
   collapse into one „New session"; the room's roster carries „Invite".
   With sentence 2 of §2 the invitation is a nudge, not the key: a student
   can always join their trainer's live session from Home.
6. **Who may be invited, and who may come in — 21.9.2026, from the owner's
   live pass.** Whoever starts a session is teaching in it, so they invite
   **their own students**, not their trainer — and the door follows the
   invitation: `mayJoinRoom` admits the creator's students, in that direction
   only (it read the relationship either way, so a trainer could sit in a
   student's room as a student). Both through `trainerOwnsStudent`. The room's
   invite dialog (`InviteStudentsDialog`) lists accepted students instead of
   `/friends`, and **a group is a chip that ticks its members** — people are
   what is sent, as in the homework dialog. Built. The owner chose to leave
   „Invitations sent." unconditional once the list can only hold people the
   server accepts; what is left is a session that ended with the dialog open.
7. **No room code is typed, by anybody — 21.9.2026.** `POST /rooms/join`, the
   „Join a session" card and `PendingSessionAction.joinRoomByCode` are gone.
   The ways in are an invitation and Home's **„In a session now"**
   (`GET /rooms/live` → `liveSessionsFor`: candidates through
   `acceptedTrainersOf`, each then put to `mayJoinRoom`, so a row offered is a
   door that opens). That was phase 2's second half; its first, the presence
   line in the room's bar (`RoomPresenceTitle`), is built too. **Phase 2 is
   built.** The code is still shown in the room's title and in the invite
   dialog, as a name for logs; phase 6 decides whether it stays on screen.
