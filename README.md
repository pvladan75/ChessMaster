# ♟️ Chess Master - Interactive Chess Training & AI Coaching Platform

**Chess Master** is a full-stack, cross-platform interactive chess training and remote teaching application built with **Flutter** (Android, Windows, Web) and **Node.js / Express / PostgreSQL** with **Socket.IO**, **Agora RTC**, and **Google Gemini AI**.

Designed for chess trainers and students, it provides real-time interactive chessboard synchronization, Stockfish engine integration, dynamic role management, audio voice chat, full session recording & MP4 video playback, friend management, room invitations, Google Calendar scheduled sessions, and an **AI Chess Coach with Adaptive Puzzles**.

---

## 🌟 Key Features

### 1. 🤖 AI Chess Coach & Adaptive Puzzles
- **Lichess Puzzle Database**: PostgreSQL `puzzles` table indexed with B-tree (rating) and GIN (themes) arrays.
- **Adaptive Rating Tracking**: Per-user overall rating and tactical theme breakdown (`fork`, `pin`, `discoveredAttack`, `mateIn1`, `mateIn2`, `endgame`, `skewer`, `deflection`) with Elo updates.
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

### 3. 🎯 Universal Tactical Motif Detector (`TacticalMotifDetector`) (NEW!)
- **Pure Stateless Core Service**: Located in `lib/core/services/tactical_motif_detector.dart` for use across all modules (Training, Live Classroom, Lesson Replay, Analysis Studio).
- **Geometric Raycasting Algorithms**:
  - **Fork (`detectFork`)**: Detects Knight/Pawn/piece attacks on $\ge 2$ valuable targets or simultaneous check + piece attack.
  - **Pin & Skewer (`detectPin`, `detectSkewer`)**: 8-directional raycasting for sliders (Bishop, Rook, Queen) detecting absolute pins (pinned to King), relative pins, and skewers.
  - **Discovered Attack / Check (`detectDiscoveredAttack`)**: Detects unblocking of slider attack lines upon piece moves.
  - **Overloading (`detectOverloading`)**: Identifies sole defender pieces protecting $\ge 2$ attacked targets.
  - **Hanging Pieces (`_detectHangingPieces`)**: Detects un-defended or under-defended target pieces.
- **Serbian Descriptions & Square Highlighting**: Generates human-readable Serbian descriptions and affected square lists (`affectedSquares`) for board arrows and highlights.

### 4. 🎤 Real-Time Interactive Classroom & Voice Chat
- **Synchronized Chessboard**: Moves, PGN variations, custom arrow drawings, and board setups sync in real-time across all connected clients via WebSockets.
- **Agora Voice RTC**: Integrated voice audio communication with mute/unmute and hand-raising mechanics.
- **Dynamic Role Management**: Host (`Trener`) can promote any participant to Co-Host (`Trener`) or demote to `Učenik`.

### 5. 📚 Lesson Builder & Multi-Step Courses (NEW!)
- **Ordered Course Steps**: a lesson is a reorderable sequence of steps — bare positions and/or full Analysis Studio trees (embedded as PGN with variations/comments/eval via `PgnExporterService`) — assembled and drag-reordered in `CreateCourseDialog`.
- **Live Step-Through**: opening a course in a session shows a trainer-only step bar (`◀ ▶` plus a tap-to-jump-to-step-N menu); each step broadcasts to students the same way a single position does.
- **Full Editing**: rename, add/remove/reorder steps, and either overwrite the saved lesson or save the edit as a new one; single (non-course) positions get a lightweight rename dialog. Any own lesson can be deleted.
- **Automatic Sharing**: every lesson a trainer saves is already visible to their linked students (`trainer_students`) — no separate share step needed.
- **Mini Board Previews**: each lesson in the list shows a real board thumbnail (`BoardThumbnail`) instead of a generic icon.
- Backend: `PUT`/`DELETE /lessons/:id`, ownership-checked, alongside the existing `POST /lessons/save` and `GET /lessons`.

### 6. 📹 Complete Session Recording & MP4 Video Rendering
- **Timeline Recording**: Records move timestamps, FEN positions, arrow annotations, and trainer voice audio during live lessons.
- **In-Session Pause & Resume**: Pause and resume recording mid-session with gap-free timestamp calculations.
- **Synced Interactive Replay & Server-Side MP4 Export**: Dedicated `ReplayPlayerScreen` and FFmpeg server-side video rendering.
- **App-Matching Piece Theme (NEW!)**: rendered videos default to a "Classic" piece set transcribed directly from the app's own `chess_vectors_flutter` artwork, so exported video looks identical to the live app instead of merely similar (Alpha/Staunton remain available as alternates).

### 7. 👥 Friends List, Room Invites & Google Calendar
- **Friends Management & Invitations**: Pre-session and in-session friend invites with persistent offline notification badges.
- **1-Click Google Calendar Sync**: Scheduled sessions pre-fill Google Calendar events for hosts and students.

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
