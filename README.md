# ♟️ Chess Master - Interactive Chess Training & AI Coaching Platform

**Chess Master** is a full-stack, cross-platform interactive chess training and remote teaching application built with **Flutter** (Android, Windows, Web) and **Node.js / Express / PostgreSQL** with **Socket.IO**, **Agora RTC**, and **Google Gemini AI**.

Designed for chess trainers and students, it provides real-time interactive chessboard synchronization, Stockfish engine integration, dynamic role management, audio voice chat, full session recording & MP4 video playback, friend management, room invitations, Google Calendar scheduled sessions, and an **AI Chess Coach with Adaptive Puzzles**.

---

## 🌟 Key Features

### 1. 🤖 AI Chess Coach & Adaptive Puzzles (NEW!)
- **Lichess Puzzle Database**: PostgreSQL `puzzles` table indexed with B-tree (rating) and GIN (themes) arrays.
- **Adaptive Rating Tracking**: Per-user overall rating and tactical theme breakdown (`fork`, `pin`, `discoveredAttack`, `mateIn1`, `mateIn2`, `endgame`, `skewer`, `deflection`) with Elo updates.
- **Google Gemini SDK Integration (`@google/genai`)**: Natural language position coaching in Serbian/English explaining tactical motifs, step-by-step plans, and recommended moves.
- **Interactive Move Animation**: Tapping AI-recommended move chips animates board moves and draws visual direction arrows.

### 2. 🎤 Real-Time Interactive Classroom & Voice Chat
- **Synchronized Chessboard**: Moves, PGN variations, custom arrow drawings, and board setups sync in real-time across all connected clients via WebSockets.
- **Agora Voice RTC**: Integrated voice audio communication with mute/unmute and hand-raising mechanics.
- **Dynamic Role Management**: Host (`Trener`) can promote any participant to Co-Host (`Trener`) or demote to `Učenik`.

### 3. 📹 Complete Session Recording & MP4 Video Rendering
- **Timeline Recording**: Records move timestamps, FEN positions, arrow annotations, and trainer voice audio during live lessons.
- **In-Session Pause & Resume**: Pause and resume recording mid-session with gap-free timestamp calculations.
- **Synced Interactive Replay & Server-Side MP4 Export**: Dedicated `ReplayPlayerScreen` and FFmpeg server-side video rendering.

### 4. 👥 Friends List, Room Invites & Google Calendar
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
