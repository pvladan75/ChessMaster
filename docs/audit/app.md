# Audit — The app's architecture (`chess_app/lib`)

Read-only run, 16.9.2026. Every `file:line` below was read in this run against
`master` at `6af0a86`. Nothing was executed except greps and a throwaway import
graph over `lib/` and `test/`; no test suite was run.

## Findings

### 1. The room's client and server disagree on the names of seventeen socket events, so a peer's board never follows the trainer's moves and five controls emit into the void
Severity: high
Where:
- Client listeners: `chess_app/lib/screens/chess_game_screen.dart:1056` (`moveMade`), `:1038` (`flip_board_forced`), `:1153` (`user_role_changed`), `:1225` (`recording_status_update`), `:1378`/`:1401` (`audio_force_mute_student` / `audio_force_unmute_student`), `:987` (`gameState`), `:1267` (`student_position_shared`), `:1423` (`audio_hand_raised_alert`); `chess_app/lib/screens/home_screen.dart:330` (`session_invite_received`), `:338` (`lesson_invite`).
- Server emits: `chess_backend/server.js:549` (`move`), `:516` (`board_flipped`), `:359` and `:421` (`role_changed`), `:490` (`recording_status_changed`), `:655` (`audio_force_muted_all`), `:304` (`lesson_invite_received`). The server never emits `gameState`, `student_position_shared`, `audio_hand_raised_alert`, `moveMade`, `session_invite_received` or `lesson_invite` anywhere (grep over `chess_backend/**/*.js` excluding `node_modules`).
- Client emits with no server listener: `chess_game_screen.dart:369` (`leaveGame`), `:587` (`audio_raise_hand` — the server listens on `audio_hand_raise_toggle`, `server.js:687`), `:2501` (`student_shares_position`), `:3888` (`audio_allow_speech`), `:3893` (`audio_mute_student`).
- The split happened in commit `6a6b0dd` (10.8.2026, "modularize server.js routes"), which renamed the server's emits (`moveMade`→`move`, `user_role_changed`→`role_changed`, `recording_status_update`→`recording_status_changed`, `audio_force_mute_student`→`audio_force_muted_all`, `lesson_invite`→`lesson_invite_received`, and introduced `board_flipped`) and touched only `constants.dart` on the app side.
Why it matters: the only handler that moves a peer's **board** (`controller.loadFen`, `:1061`) and steps its cursor to the trainer's move is `moveMade`, which no longer arrives. The peer still receives `pgn_loaded` (`:1122`, same name on both sides, sent after every move by `_broadcastMoveAndState` at `:2299`), so the peer's move **tree** updates while the peer's board and cursor stay where they were — the exact "every layer looks right and the feature is dead" shape this repository keeps recording. A trainer's forced flip, the mute-all, the invite popup ("Invitation sent for room X! Connecting…" at `home_screen.dart:900` is answered by nothing on the student's side), "raise hand", "allow speech / mute this student" and "share my position with the trainer" are all drawn and all do nothing. `TODO-provera.md` items 31, 32 and 118 say the room has not been watched live since these dates; I found no recorded live check of two clients in one room after 10.8.2026.
Proof: a two-client test against the real server, or cheaper: a widget test that pumps `ChessGamePage` as a student with a fake socket, delivers the server's actual payload `move {move:{from:'e2',to:'e4'}, currentFen, movePath}` and asserts the board FEN changed — it fails today because nothing listens on `move`. Reading the two lists side by side is itself the proof: of the 26 names the client listens on, 12 are emitted by nothing on the server (three more — `notifications_changed`, `relationship_changed`, `voice_level_changed` — are sent under a variable through `services/realtime.js:172` and do match); of the 19 names the client emits, 5 have no server listener; and 8 of the server's 19 literal emits reach no client listener.
Fix direction: one shared list of event names read by both ends (a constants file in the app mirrored by one on the server, with a test on each side that reads the other's file), and a test that feeds the room the server's real payloads rather than the client's own. Then delete the dead handlers (`gameState` is the largest: it is the only code that would rebuild a peer's root, see finding 5).

### 2. The room saves a "position" whose `fen` is the board's current square and whose `pgn` is an export of the root, so a line saved from anywhere but move zero cannot be replayed by any reader
Severity: high
Where: `chess_app/lib/screens/chess_game_screen.dart:1965-1973` (`saveCurrentPosition`: `fen: controller.getFen()`, `pgn: moveTree.exportToPgn()`), reached from the "Save position" button at `:2915` → `:2550-2558`; success message `:1979`. Reader: `chess_app/lib/features/lessons/models/lesson_step_line.dart:50` (`MoveTree.parsePgn(pgn, startingFen: fen)`), where the given `fen` wins over the `[FEN]` header (`chess_app/lib/move_tree.dart:438`).
Why it matters: this is the 6.9.2026 fault ("one node answers for both fields", fixed in `StudioLessonStep.from`) still alive in the room. A trainer who walks a line, presses Save, and later assigns that saved position or opens it in the studio gets a step whose every move is rejected — the student sees a still board, the trainer was told "Tutorial with variations saved successfully!". No reader of `rejectedMoves` exists in `chess_game_screen.dart` (grep), so nothing refuses it. It also reloads wrong in the room itself: `loadLessonPosition` at `:1987` parses with `startingFen: fen`.
Proof: in a room, play `1. e4 e5`, leave the cursor on `e5`, Save. Then `LessonStepLine.read(fen: <fen after e5>, pgn: <saved pgn>).rejectedMoves == 2`. As a pure test: `MoveTree.parsePgn('1. e4 e5', startingFen: fenAfterE5).rejectedMoves` is 2.
Fix direction: the room should save through the same one-node rule the studio uses (fen and pgn from `moveTree.root`, or the step built from the current node with a line that starts there), and refuse when `LessonStepLine.read(...).replays` is false — the writer reads its own work back before saving, as CLAUDE.md already prescribes.

### 3. `MoveTree.exportToPgn` never writes the NAG that `MoveTree.parsePgn` now keeps, so the room silently strips every `!`/`?` from a game it broadcasts or saves
Severity: medium
Where: writer `chess_app/lib/move_tree.dart:249` and `:264` (`sb.write('${mainChild.san} ')`, no `nag`); the field it ignores `move_tree.dart:70` and the parser that fills it `:527-568`. The other writer does write it: `chess_app/lib/features/analysis_studio/services/pgn_exporter_service.dart:173-175`. Callers of the lossy writer: `chess_game_screen.dart:752, 1972, 2081, 2147, 2187, 2301, 2467`.
Why it matters: the 12.9.2026 repair ("a field one end wrote and no end ever read") taught the parser to keep `c5??`; the room's writer was not taught to write it back. A reviewed game loaded into a room (`_loadSinglePgnGame`, `:2440`) loses its marks on the first move, comment or arrow, both for the peer (via `pgn_loaded`) and for the saved position. The room never draws `nag` either (no `.nag` in `chess_game_screen.dart`, `move_history_view.dart` or `widgets/game_screen/`), so it cannot see what it drops.
Proof: `MoveTree.parsePgn('1. e4 c5?? 2. Nf3')!.exportToPgn()` does not contain `??`.
Fix direction: one PGN writer, or at least `_writePgnNode` writing `san + (nag ?? '')`, with a round-trip test on `MoveTree` mirroring the one `PgnExporterService` already has.

### 4. `CreateCourseDialog` ("Edit positions" in the room) writes `tags: ['lekcija_kurs']` on every update, erasing the labels a tutorial carries
Severity: medium
Where: `chess_app/lib/widgets/create_course_dialog.dart:173` (update) and `:179` (save); opened for an existing tutorial from `chess_app/lib/screens/chess_game_screen.dart:3182-3189` (menu value `'pozicije'`, label "Edit positions", drawn for every own course at `:3160-3184`). Labels are written by the studio through `TutorialDraft.tags` (`chess_app/lib/features/tutorial_studio/models/tutorial_draft.dart:527`) and by the JSON import; the server stores an explicit `tags` value (`PUT /lessons/:id`, the "absence is a third answer" rule).
Why it matters: nothing in `chess_app/lib` or `chess_backend` reads `lekcija_kurs` (grep: only these two writes) — it is a Serbian wire value that nothing filters on, yet it replaces the trainer's labels, which the library card filters by (`tutorial_library_card.dart:512-525`). Reorder two parts in the room and the tutorial's labels are gone. The comment at `:3183-3186` ("The step editor cannot add, remove or reorder steps until batch F, and this menu replaced the only way in") is stale: the studio's parts panel and the step editor both reorder now, so this is a third editor of the same list with its own rules.
Proof: label a tutorial "endgames" in the studio, open the room's saved list, "Edit positions" → Save changes; `GET /lessons` shows `tags: ["lekcija_kurs"]`. A widget test asserting on the request body (the shape `tutorial_section_titles_test.dart` uses) shows it without a server.
Fix direction: send no `tags` from this dialog (absence leaves the column alone), or retire the dialog in favour of the studio, which already does everything it does. Remove the stale comment either way.

### 5. A peer parses every incoming PGN against its **own** root, and the one handler that would replace that root is never sent, so a position loaded in a room never reaches the peer's tree
Severity: medium
Where: `chess_app/lib/screens/chess_game_screen.dart:1126` (`MoveTree.parsePgn(data['pgn'], startingFen: moveTree.root.fen)` — the given root wins over the PGN's `[FEN]`, `move_tree.dart:438`); `:1064-1073` (a `move` with `move == null` only moves the cursor, never the root); `:987-994` (`gameState` rebuilds the root — the server never emits it). Senders that change the root: `loadLessonPosition` `:1984-2028`, `_loadSinglePgnGame` `:2440-2467`, the board setup at `:2530`.
Why it matters: independent of finding 1 — even with the event names repaired, when the trainer loads a saved position, a tutorial step or a pasted game, the peer's `pgn_loaded` replays the moves from the peer's old root, every move is rejected without a word (`move_tree.dart:196-207`), and the peer is left with an empty tree whose root is a position no longer on anybody's board. Every later move then fails to name itself (`:1093-1101` falls back to `e2➔e4`).
Proof: `MoveTree.parsePgn('[FEN "<any non-standard fen>"] 1. Kf2', startingFen: standardStart).rejectedMoves == 1`. As a widget test: pump the room as a student, deliver `pgn_loaded` with a `[FEN]` header different from the room's start, assert `moveTree.root.children` is non-empty — it is empty.
Fix direction: the receiver should read the header (`MoveTree.fenHeaderOf`) or the `move` payload's `currentFen` when `movePath` is empty and `move` is null, and rebuild the tree from it; delete the dead `gameState` handler so nobody believes it does this.

### 6. Serbian words with no diacritic survive on common screens, contradicting the English-only decision — the endgame trainer prints "remi", "dobitak", "gubitak" on every readout
Severity: medium
Where: `chess_app/lib/features/endgame_trainer/models/tablebase_readout.dart:96-105` (`outcomeWord`, whose own doc says "How a position's own verdict reads in Serbian") read at `chess_app/lib/features/endgame_trainer/screens/endgame_trainer_screen.dart:708, 1424, 1494, 1583` ("Position: remi, DTZ …"); `chess_app/lib/features/analysis_studio/widgets/syzygy_panel_widget.dart:16, 20, 30` ("Pobeda", "Verovatna pobeda", "Nepoznato" beside "Draw", "Loss"); `chess_app/lib/move_tree.dart:160` ("Nepoznat datum", shown by `widgets/game_selector_dialog.dart:30` and `chess_game_screen.dart:2470`); `chess_app/lib/features/tutorial_studio/tutorial_editor_entry.dart:48` ("Koraci tutorijala", the Android fallback title); `chess_app/lib/features/lessons/widgets/preview_assignment_api_service.dart:34` ("Pregled" shown as a solution move in the frozen editor's preview).
Why it matters: `gate_english_ui` looks for `čćžšđ`; none of these has one, which is the exact hole `fen_legality.dart:18-21` already documents for itself. The endgame trainer is a routed, common screen, and it mixes languages inside one sentence.
Proof: grep as above; `outcomeWord('draw') == 'remi'`.
Fix direction: translate the six sites; teach the English gate a short no-diacritic word list (it already knows "trening" and "delovi"), adding at least `remi`, `dobitak`, `gubitak`, `pobeda`, `nepoznat`, `koraci`, `pregled`.

### 7. Two writers of `saved_lessons.tags` apply two different rules; the shared normaliser exists and the room's dialog does not use it
Severity: medium
Where: `chess_app/lib/features/lessons/models/lesson_labels.dart:30-51` (`normaliseLabels`: trim, case-insensitive dedupe, ≤255 chars, ≤12 labels — "one reading of the rule, shared", per its own header); `chess_app/lib/widgets/save_position_dialog.dart:43-44` (trim and a case-sensitive `contains`, no length cap, no count cap), used by the room at `chess_game_screen.dart:2553`.
Why it matters: "Endgame" and "endgame" are two labels when typed in the room and one when typed in the studio; a 300-character label typed in the room reaches Postgres and comes back as a 500 that reads as "saving is broken" — the very case `lesson_labels.dart:9-12` was written to stop. Duplication that has already drifted.
Proof: type `Endgame`, then `endgame` into the room's save dialog: both chips appear; `normaliseLabels(['Endgame','endgame']).length == 1`.
Fix direction: route `SavePositionDialog`'s chips through `normaliseLabels`, and have the source-reading test that guards the labels rule assert every writer of `tags` imports it.

### 8. The two PGN writers disagree about when a `[FEN]` header is needed
Severity: low
Where: `chess_app/lib/move_tree.dart:218-219` (whole-string comparison with the standard FEN) versus `chess_app/lib/features/analysis_studio/services/pgn_exporter_service.dart:39-40` (`startsWith` on the placement only, ignoring side to move, castling and en passant).
Why it matters: a part set up from the standard placement with Black to move, or with a castling right removed, exports from the studio with no header; any reader that trusts the text alone (`MoveTree.parsePgn(pgn)` without `startingFen`, the Analysis "Save as .pgn" file opened elsewhere, `pgn_tutorial_export.dart`) replays it from the wrong side and rejects the first move. `LessonStepLine.read` is safe only because the step's `fen` travels beside it.
Proof: `PgnExporterService.exportToPgn(AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1') with one child)` contains no `[FEN`; `MoveTree.parsePgn(thatText).rejectedMoves == 1`.
Fix direction: one predicate ("is this the standard starting position", using `MoveTree.samePosition`) used by both writers.

### 9. One rule, many copies: the move-number label, the position key, the orientation guess and the starting FEN are each written in several files
Severity: low
Where:
- Move number from a FEN (ply → "12." / "12..."): `chess_app/lib/features/analysis_studio/models/analysis_node.dart:90-98` (`moveNumberLabel`, the copy CLAUDE.md says is canonical), `chess_app/lib/features/analysis_studio/widgets/move_tree_widget.dart:276-280`, `chess_app/lib/widgets/move_history_view.dart:31-42`, `chess_app/lib/features/repertoire/line_text.dart:22-40`, `chess_app/lib/move_tree.dart:237-247`, `chess_app/lib/features/analysis_studio/services/pgn_exporter_service.dart:225-233`, `chess_app/lib/models/analysis_models.dart:97-99`, `chess_app/lib/features/tutorial_studio/services/game_tutorial/game_facts.dart:160`.
- Position key (first four FEN fields): `chess_app/lib/move_tree.dart:421-434` (`samePosition`), `chess_app/lib/features/repertoire/services/repertoire_api_service.dart:124-127` (`fenKeyOf`), `chess_app/lib/features/analysis_studio/services/opening_book_service.dart:95-98` (`normalizeFen`), inline at `chess_app/lib/features/analysis_studio/widgets/visual_move_tree_widget.dart:269` and `:635`.
- "Which way round does a step open" guessed from whose turn it is: `chess_app/lib/features/tutorial_studio/models/tutorial_draft.dart:44-47` (`blackToMoveIn`) and `chess_app/lib/features/assignments/screens/lesson_viewer_screen.dart:344-348` (`_sideToMove`).
- The standard starting FEN as a literal: 16 occurrences in 10 files (`chess_game_screen.dart` ×3, `analysis_studio_screen.dart` ×3, `move_tree.dart` ×2, `board_setup_dialog.dart` ×2, and one each in `settings_screen.dart`, `pgn_game_import.dart`, `tutorial_draft.dart`, `lesson_step_editor_panel.dart`, `pgn_exporter_service.dart`); the one named constant, `kStartFen`, is private to `repertoire_new_screen.dart:18`.
Why it matters: none of these has drifted in result yet (I compared them), but the position key is the rule a repertoire, a book lookup and a lesson join all depend on, and the move-number rule has already been written wrong once (the tree that "numbered its first move as one"). Finding 8 is what drift in the starting-FEN copies looks like.
Proof: the grep counts above.
Fix direction: `MoveTree.samePosition`/`fenKeyOf` become one function; the move-number label becomes one function taking a FEN and a side; one `kStandardStartFen` constant in `move_tree.dart`.

### 10. `lib/core` depends on `lib/features/analysis_studio`, and two feature pairs import each other
Severity: low
Where: `chess_app/lib/core/services/eval_cache.dart:3`, `core/services/game_analysis_walker_service.dart:9-10`, `core/services/local_puzzle_extractor_service.dart:4` import `features/analysis_studio/...`. Cycles: `features/analysis_studio/screens/analysis_studio_screen.dart:64-70` imports seven `tutorial_studio` files while `tutorial_studio` imports 26 `analysis_studio` files; `features/lessons/widgets/lesson_step_editor_panel.dart:7-8` and `lessons/widgets/preview_assignment_api_service.dart:1-2` import `assignments` while `assignments/screens/lesson_viewer_screen.dart:8-9` and `assignments/widgets/assign_lesson_dialog.dart:6` import `lessons`.
Why it matters: `AnalysisNode` and `auto_tree_generator_service` are used by core services, the room, the repertoire and the tutorial studio — they are shared models living inside one feature's folder, which is why every other feature reaches into `analysis_studio`. Nothing is broken by it; it is the reason the boundaries in `lib/features` do not describe the dependencies.
Proof: the import graph (a throwaway script over `lib/`; counts above).
Fix direction: move `analysis_node.dart`, `pgn_span.dart`, `pgn_exporter_service.dart` and `auto_tree_generator_service.dart` to `lib/core`; move `lesson_viewer_screen.dart` and `lesson_step_line.dart` to one side of the lessons/assignments line.

### 11. `services/puzzle_engine.dart` is dead code kept alive by its test
Severity: low
Where: `chess_app/lib/services/puzzle_engine.dart` (154 lines) is imported by nothing under `lib/` (import graph); its only importer is `chess_app/test/puzzle_logic_test.dart`. The live implementation of the same idea is `VariationBranchPoint` and `_activeBranchPoints` in `chess_app/lib/screens/ai_studio_screen.dart:48-60, 223, 1576-1601`.
Why it matters: a green test over code no user runs is the "count that quietly stops meaning anything" this repository watches for.
Proof: `grep -rl puzzle_engine.dart chess_app/lib` returns nothing.
Fix direction: delete the file and its test, or port the test onto `ai_studio_screen.dart`'s branch logic.

### 12. The room reads its role from two sources, and the "account role" fed to the board-control rule is the URL seed, not the account
Severity: low
Where: `chess_app/lib/routing/app_router.dart:113-116` (`userSession: SessionService.instance.current.copyWith(role: role)` — the `?role=` query replaces the account's role); `chess_app/lib/core/services/board_control_rules.dart:12-19` documents `accountRole` as "the account's global role … an account-level trainer is trusted in any room"; the room passes `accountRole: widget.userSession.role` at `chess_game_screen.dart:223`; the server-confirmed role is `activeRole` (`:1146`, `:1159`), 17 uses, while `widget.userSession.role == 'trener'` gates 12 more places (e.g. `:689`, `:3268`, `:3913`).
Why it matters: `canDriveSharedBoard` and the sidebar's `isHost` (`:3266-3269`) stay true from the seed after the server says otherwise, so trainer-only controls are drawn for a client the server will refuse (`action_denied`). The seed is set by `home_screen.dart:362/904/1010` and re-used on resume from `GameSessionService` (`:260` stores the seed, never the confirmed role), so it is stale after any `role_changed`.
Proof: pump `ChessGamePage(initialRole: 'trener', boardControl 'trainer_only')` on a non-STUDIO room, deliver `room_members_list` with `me.role == 'ucenik'`; `canDriveSharedBoard` is still true and "Host Controls & History" is still drawn.
Fix direction: one role in the room (`activeRole`), the seed used only until the roster answers; `canDriveSharedBoard` takes the genuine account role from `SessionService`.

## Suspicions

- **A newer saved version can be overwritten by an older list row plus one keystroke.** `tutorial_studio_screen.dart:486-531`: the studio adopts the row the library handed over, asks the server, and — when the trainer has typed anything in that round trip (`!untouched`) — only *remembers* the saved version. If the row was stale (saved elsewhere since the list loaded), the next save writes the stale row plus the edit over the newer version; `PUT /lessons/:id` cannot object unless the step lists have the same length and different ids. Confirm with a widget test that holds `fetchTutorial` in a `Completer`, types one character, completes it with a row that has an extra part, saves, and reads the request body.
- **The room's success message lies about shape.** `chess_game_screen.dart:1979` says "Tutorial with variations saved successfully!" for a bare position with no moves. Cosmetic unless finding 2 is fixed by refusing, in which case the message must change with it.
- **`recording_status_update` peers.** Client listens `:1225`, server emits `recording_status_changed` (`server.js:490`). Recording is now trainer-alone (`recordingConsent.js`), so no peer should need it; confirm nothing on the student side still waits for it, then delete the listener.
- **`GameSessionService.setActive` keeps the seed.** `chess_game_screen.dart:260` stores `activeRole` at join and nothing updates it on `room_members_list`; `resume_strip.dart:66` re-enters with it. Harmless while roles rarely change; would compound finding 12.

## For another track

- Track 3 (contract): finding 1's fifteen mismatched socket names is first of all a contract fault; the payload shapes differ too (`role_changed {newRole}` to the target socket vs the client's `{targetUserId, newRole}` at `chess_game_screen.dart:1155-1157`).
- Track 3: `tags: ['lekcija_kurs']` (finding 4) is a Serbian wire value the server stores and `GET /lessons/labels` lists back as a label.
- Track 3: `GET /lessons/labels` returns labels of saved positions as well as tutorials (`tutorial_library_card.dart:512-516` works around it client-side).
- Track 4 (tests): no test under `chess_app/test` references `moveMade`, `flip_board_forced` or any room event name — the room's peer path has no test at all, which is how finding 1 lived five weeks; `test/puzzle_logic_test.dart` tests dead code (finding 11).
- Track 2 (server): `student_shares_position`, `audio_allow_speech`, `audio_mute_student` and `leaveGame` reach the server with no handler — harmless today, but if handlers are added they need the same `canMoveInRoom`-style gate as `move`.

## What I did not cover

- `features/groups`, `features/trainer_panel`, `features/archive`, `features/position_scanner`, `features/endgame_trainer` (beyond the Serbian words), `features/repertoire` internals and `features/reviews`: sampled for imports and duplicated rules only, not read.
- `chess_game_screen.dart` (4411 lines) was read around its socket handlers, its save/load paths and its saved-tutorials list, not whole; `ai_studio_screen.dart`, `home_screen.dart`, `settings_screen.dart` likewise.
- The speech vocabularies (`speech_text.dart`, `walkthrough_speech.dart`) and the motif/positional sentence tables were not compared word for word.
- Theme, board skins, Agora voice, billing, engine download and the Stockfish services were not examined.
- Layout and overflow at phone width — nothing was run, so nothing was measured.
- The frozen `lesson_step_editor_panel.dart` (Android's editor) was checked only for its save shape and its strings.
