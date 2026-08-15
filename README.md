# ♟️ Chess Master - Interactive Chess Training & AI Coaching Platform

**Chess Master** is a full-stack, cross-platform interactive chess training and remote teaching application built with **Flutter** (Android, Windows, Web) and **Node.js / Express / PostgreSQL** with **Socket.IO**, **Agora RTC**, and **Google Gemini AI**.

Designed for chess trainers and students, it provides real-time interactive chessboard synchronization, Stockfish engine integration, dynamic role management, audio voice chat, full session recording & MP4 video playback, friend management, room invitations, Google Calendar scheduled sessions, and an **AI Chess Coach with Adaptive Puzzles**.

---

## 🌟 Key Features

### 1. 🤖 AI Chess Coach & Adaptive Puzzles
- **Lichess Puzzle Database (6.1M puzzles)**: `lichess_puzzles` table with the dataset's real ratings, themes, popularity and opening tags — B-tree index on rating, GIN index on the themes array. Loaded by `import_lichess_puzzles.js`, which streams the CC0 zstd dump (`--dry-run`, `--limit`, `--min-rating` and `--min-popularity` supported for partial loads).
  - The dump is written by `pzstd` as many independent frames, which Node's own zstd stream stops at; `services/zstdMultiFrame.js` walks the frame chain so the whole file is read rather than only its first 32 MiB.
- **Adaptive Selection (`puzzleSelectionService`)**: `GET /api/puzzles/adaptive` targets the motif the user is measurably weakest at, inside a rating band centred slightly *below* their rating so a session stays mostly solvable. A theme needs several attempts before it counts as a weakness, and a share of requests deliberately explore untried motifs so the picture keeps filling in.
- **Per-Theme Rating Tracking**: `POST /api/puzzles/attempt` updates the overall rating and every trainable theme on the puzzle, using the puzzle's stored rating (never a client-supplied one). `user_puzzle_attempts` keeps per-attempt history — what a trainer's progress view will read.
- **Note on the older `puzzles` table**: the mate-in-N and "winning position" modules still use it. It carries an engine-verified solution tree rather than a Lichess move line, which is why the two live in separate tables.
- **Google Gemini SDK Integration (`@google/genai`)**: Natural language position coaching in Serbian/English explaining tactical motifs, step-by-step plans, and recommended moves.
- **Interactive Move Animation**: Tapping AI-recommended move chips animates board moves and draws visual direction arrows.

### 2. 🔬 Analysis Studio & Opening / Endgame Explorers (NEW!)
- **ECO Opening Book Service (`OpeningBookService`)**:
  - Background isolate loading of 3,810 ECO opening lines from `assets/data/eco_openings.json` with zero UI main-thread stuttering.
  - Real-time display of ECO code and official opening name (e.g. `B90 · Sicilian Defense, Najdorf`).
- **Lichess Opening Explorer Integration (`OpeningExplorerService` & `OpeningExplorerPanelWidget`)**:
  - Fetches real-time game popularity and outcome statistics (White %, Draw %, Black %) from the Lichess Opening Explorer API.
  - Supports rating bucket filtering (`Svi rejtinzi`, `1600+`, `1800+`, `2000+`, `2200+`, `2500+`).
  - Interactive candidate move chips: tapping any opening move chip plays the move on the board and branches into the move tree.
  - Token supplied at build time (`--dart-define-from-file=dart_defines.json`), never entered manually by users.
- **Syzygy Tablebase Explorer (`SyzygyTablebaseService` & `SyzygyPanelWidget`)**:
  - Automatically activates when $\le 7$ pieces remain on the board.
  - Displays exact WDL (Win/Draw/Loss) evaluations, distance-to-zero (DTZ), and winning/drawing candidate move chips.
- **AutoTree Variation Generator (`AutoTreeGeneratorService` & `AutoTreeDialog`)**:
  - Automated Stockfish-driven recursion tree generator for deep variation analysis with delta cutoff pruning and global depth configuration.
- **Save & Load Analyses (`AnalysisPersistenceService`) (NEW!)**:
  - Variation trees (moves, comments, NAGs, eval) save to the `saved_analyses` table and reload on any device the user logs into.
  - Cloud icon in the AppBar opens a save/list/load/delete dialog, scoped per user account.
- **In-App Live Log Viewer**:
  - Top bar terminal icon 📜 for real-time inspection of engine commands, Lichess HTTP responses, and system events.
- **Consistent Board Setup Editor**: the manual position builder (FEN/PGN/drag-to-place tabs) renders pieces with the same `chess_vectors_flutter` artwork used by every live board in the app, instead of plain Unicode glyphs.

### 3. 🎯 Universal Tactical Motif Detector (`TacticalMotifDetector`)
- **Pure Stateless Core Service**: `lib/core/services/tactical_motif_detector.dart` — `detect()` for a single position, `explainMove()` to diff a move's before/after position (what it created vs. what it resolved), `describeMoveDiff()` / `candidateCommentLines()` to render findings as Serbian text.
- **Geometric Detection**: Fork, Pin, Skewer, Discovered Attack/Check, Overloading, Deflection, Hanging Pieces (via a real static-exchange evaluation, not naive attacker/defender counting), and Mate Threat (direction-aware — reads the engine eval's actual sign so a threat is never shown as favoring the side about to be mated).
- **"Walks into mate" awareness**: a pseudo-legal capture that would hand the opponent an immediate forced mate is excluded from defender/attacker counting, so a piece that's technically "attacked" but can't actually be taken isn't flagged as hanging.
- **Natural Serbian Descriptions**: names the actual piece, color, and square with correct grammatical case ("beli skakač sa c7 napada dve crne figure: crnog topa na a8 i crnog kralja na e8") instead of a generic placeholder.
- **Significance-Ranked & Directional**: every finding carries `favorsMover` (good for whoever just moved vs. good for the opponent) and a `significance` score, so auto-generated comments can drop routine/low-value findings when something bigger is happening instead of listing everything.
- **Wired into Analysis Studio**: live "Taktički motivi" panel next to the engine eval, auto-generated move comments, and (optional) manual mode where the user picks findings from a checklist instead of accepting the auto text.

### 4. ♟️ Positional & Strategic Evaluator (`PositionalEvaluatorService`)
- **Mirrors the tactical service's shape** (`evaluate()` / `explainMove()` / `describeMoveDiff()` / `candidateCommentLines()`) so the two combine into one comment and share UI.
- **Pawn structure**: doubled, isolated, backward, and passed pawns; pawn islands.
- **Files & center**: open/semi-open file control by a rook or queen; center control (d4/e4/d5/e5) from pawn occupation and pawn attacks.
- **Piece placement**: the bishop pair, color-complex weaknesses (no bishop of a color with pawns fixed on it), and permanent knight outposts.
- **King safety**: kept deliberately simple (binary "pawn shield damaged" / "open file next to the king" signals, not a composite score) — this is the factor most prone to being overstated by a heuristic.
- **Narration, not a second score**: never produces its own positional evaluation number that could contradict the engine's centipawn eval — only findings that explain *why* the position looks the way the engine already says it does.
- **Significance-calibrated for auto-mode**: lasting findings (passed pawns, the bishop pair, a lost pawn shield) auto-narrate; fluid/contested ones (which file is open right now, a marginal center-control edge) are available for manual selection but don't clutter the automatic comment.

### 5. 🧩 Game Review & Automated Puzzle Generation
- **`GameAnalysisWalkerService`**: walks an already-played game (not engine-searched branches) move by move, gets the engine eval at every position, and computes each move's eval swing *from the mover's own perspective* (careful sign handling — the same class of bug once found and fixed in the mate-threat detector). Combines with both services above into a per-move comment.
- **`annotateNodeChain()`**: one click ("Analiziraj celu partiju" in Analysis Studio) reviews an entire loaded/imported game and writes a tactical+positional comment plus eval into every move, without overwriting comments already written by hand (unless asked to).
- **`LocalPuzzleExtractorService`**: filters that same walk for moves that gave up a large amount of eval (a blunder), and packages the position right after each one as an exercise — themed via `TacticalMotifDetector` (fork, hanging piece, pin, ...) rather than left generic. Reuses the app's existing `'winning_position'` puzzle shape (live engine verification, no solution tree needed), so it doesn't require a network round-trip to the Lichess puzzle database.
- **"Pretvori partiju u vežbe"** in Analysis Studio: pick a blunder threshold and a max puzzle count, review the results (theme + which move caused it + how big the swing was), and jump straight to any of them on the board.

### 6. 🎤 Real-Time Interactive Classroom & Voice Chat
- **Synchronized Chessboard**: Moves, PGN variations, custom arrow drawings, and board setups sync in real-time across all connected clients via WebSockets.
- **Agora Voice RTC**: Integrated voice audio communication with mute/unmute and hand-raising mechanics.
- **Dynamic Role Management**: Host (`Trener`) can promote any participant to Co-Host (`Trener`) or demote to `Učenik`.

### 7. 📚 Lesson Builder & Multi-Step Courses
- **Ordered Course Steps**: a lesson is a reorderable sequence of steps — bare positions and/or full Analysis Studio trees (embedded as PGN with variations/comments/eval via `PgnExporterService`) — assembled and drag-reordered in `CreateCourseDialog`.
- **Live Step-Through**: opening a course in a session shows a trainer-only step bar (`◀ ▶` plus a tap-to-jump-to-step-N menu); each step broadcasts to students the same way a single position does.
- **Full Editing**: rename, add/remove/reorder steps, and either overwrite the saved lesson or save the edit as a new one; single (non-course) positions get a lightweight rename dialog. Any own lesson can be deleted.
- **Automatic Sharing**: every lesson a trainer saves is already visible to their linked students (`trainer_students`) — no separate share step needed.
- **Mini Board Previews**: each lesson in the list shows a real board thumbnail (`BoardThumbnail`) instead of a generic icon.
- Backend: `PUT`/`DELETE /lessons/:id`, ownership-checked, alongside the existing `POST /lessons/save` and `GET /lessons`.

### 8. 📹 Complete Session Recording & MP4 Video Rendering
- **Timeline Recording**: Records move timestamps, FEN positions, arrow annotations, and trainer voice audio during live lessons.
- **In-Session Pause & Resume**: Pause and resume recording mid-session with gap-free timestamp calculations.
- **Synced Interactive Replay & Server-Side MP4 Export**: Dedicated `ReplayPlayerScreen` and FFmpeg server-side video rendering.
- **App-Matching Piece Theme**: rendered videos default to a "Classic" piece set transcribed directly from the app's own `chess_vectors_flutter` artwork, so exported video looks identical to the live app instead of merely similar (Alpha/Staunton remain available as alternates).

### 9. 👥 Friends List, Room Invites & Google Calendar
- **Friends Management & Invitations**: Pre-session and in-session friend invites with persistent offline notification badges.
- **1-Click Google Calendar Sync**: Scheduled sessions pre-fill Google Calendar events for hosts and students.

---

## 🗺️ Roadmap / Sledeći koraci

Ono što je sledeće na listi (dogovoreno, još neurađeno), plus par sugestija:

1. **LLM-generisani komentari (Premium)** — umesto (ili pored) template teksta iz `TacticalMotifDetector`/`PositionalEvaluatorService`, ponuditi tečniju prozu generisanu preko LLM-a. **Ključna arhitektonska odluka koju treba čuvati**: LLM nikad ne sme da generiše taktičke/pozicione *činjenice* sam — samo da preformuliše već tačne, mašinski proverene nalaze (`MotifFinding`/`PositionalFinding`) u prirodniji stil. Ovo sprečava halucinacije ("dama je vezana" kad zapravo nije). Videti odgovor u chat-u za konkretne korake (provajder, cena, ključ).
2. **Dublja integracija izvučenih vežbi sa ekranom za rešavanje** — trenutno "Pretvori partiju u vežbe" učitava poziciju na Analysis Studio tablu; puna integracija sa AI Studio puzzle-solving tokom (verifikacija poteza, praćenje rejtinga) je veći, poseban zahvat ako se pokaže da je vredan.
3. **Otvoreno pitanje: da li treba filtrirati i live panele** ("Taktički motivi" / "Pozicioni faktori") istim rangiranjem po značaju koje već koriste auto-komentari — u testiranju je panel ponekad prikazao 10+ čipova odjednom. Vidi `memory/project_positional_panel_declutter.md` iz prethodne sesije — odluka je namerno ostavljena za kasnije.
4. **Mobile/Android provera** — sve novo ovog kruga (paneli, ručni dijalog, Game Review, Puzzle Extractor) testirano je samo na Windows desktop buildu; vredi proći kroz njih i na telefonu pre nego što se smatraju gotovim (dijaloge posebno, zbog veličine ekrana).
5. **Predlog (nije dogovoreno)**: `GameAnalysisWalkerService` i `AutoTreeGeneratorService` oba pozivaju engine nezavisno — ako se partija prvo pregleda pomoću "Analiziraj celu partiju" pa se posle nad istim pozicijama pokrene automatska analiza (ili obrnuto), evaluacije se ponovo računaju od nule. Ako ovo počne da smeta u praksi (sporo), vredelo bi keširati eval po FEN-u unutar jedne sesije.

---

## 🛠️ Technology Stack

- **Frontend**: Flutter (Dart) — Android, Windows Desktop, Web
- **Backend Server**: Node.js, Express.js, Socket.IO, `@google/genai`
- **Database**: PostgreSQL (`pg` client) with GIN and B-Tree indexing
- **AI Integration**: Google Gemini 2.5 Flash (`@google/genai`)
- **Real-Time Audio**: Agora RTC SDK (`agora_rtc_engine`)
- **Chess Engine**: Stockfish CLI & WASM Engine integration
- **Video Rendering**: Server-side FFmpeg rendering engine

---

## 🚀 API Endpoints Summary

- `GET /api/puzzles/next?userId=...&theme=...`: Fetches adaptive puzzle matching user rating.
- `POST /api/puzzles/submit`: Submits puzzle solution, calculates Elo rating change.
- `POST /api/ai/explain-position`: Passes FEN position and Stockfish evaluation to Gemini AI for natural language coaching advice.
- `POST /sessions/schedule`: Schedules future lesson rooms with 1-click Google Calendar integration.

---

## 📄 License
This project is proprietary and developed for interactive remote chess teaching and AI lesson analysis.
