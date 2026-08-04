# ♟️ Chess Master - Interactive Chess Training & Remote Teaching Platform

**Chess Master** is a full-stack, cross-platform interactive chess training and remote teaching application built with **Flutter** (Android, Windows, Web) and **Node.js / Express / PostgreSQL** with **Socket.IO** and **Agora RTC**.

Designed for chess trainers and students, it provides real-time interactive chessboard synchronization, Stockfish engine integration, dynamic role management, audio voice chat, full session recording & MP4 video playback, friend management, room invitations, and Google Calendar scheduled sessions.

---

## 🌟 Key Features

### 1. 🎤 Real-Time Interactive Classroom & Voice Chat
- **Synchronized Chessboard**: Moves, PGN variations, custom arrow drawings, and board setups sync in real-time across all connected clients via WebSockets.
- **Agora Voice RTC**: Integrated voice audio communication with mute/unmute and hand-raising mechanics.
- **Dynamic Role Management**:
  - The room host (`Trener` / Host) can promote any participant to Co-Host (`Trener`) or demote to `Učenik`.
  - Multiple trainers can simultaneously control the board, Stockfish engine, and audio moderation.

### 2. 📹 Complete Session Recording & MP4 Video Rendering
- **Timeline Recording**: Records move timestamps, FEN positions, arrow annotations, and trainer voice audio during live lessons.
- **In-Session Pause & Resume**: Pause and resume recording mid-session with seamless time-offset calculation.
- **Synced Interactive Replay**: Dedicated `ReplayPlayerScreen` with synced audio playback, automatic move progression, and timeline scrubbing.
- **Persistent Server-Side MP4 Video Export**: FFmpeg server-side video rendering with PostgreSQL video URL caching for instant offline downloads across logins.

### 3. 👥 Friends List & Room Invitations
- **Friends Management**: Add friends by email address, view friends list, and remove friends.
- **Pre-Session Invites**: Select friends from a checklist to invite before launching a new lesson room.
- **In-Session Invites**: Invite online/offline friends during an active session.
- **Persistent Offline Notifications**: Unread invitation count badge in `HomeScreen` AppBar.

### 4. 📅 Scheduled Sessions & 1-Click Google Calendar Sync
- **Advance Scheduling**: Schedule future lessons for specific dates and times (e.g. 3 days in advance).
- **Google Calendar Integration**: 1-click **"Dodaj u Google Kalendar"** button pre-fills Google Calendar events with session title, scheduled start/end date, room code, and join instructions for hosts and students.

### 5. 💎 Free vs. Premium Tier Limits
- **Account Tiers**: Free and Premium account types.
- **Usage Limits**: Enforces monthly creation limits for lessons, saved positions, and session recordings for Free accounts.

---

## 🛠️ Technology Stack

- **Frontend**: Flutter (Dart) — Android, Windows Desktop, Web
- **Backend Server**: Node.js, Express.js, Socket.IO
- **Database**: PostgreSQL (Prisma/pg client)
- **Real-Time Audio**: Agora RTC SDK (`agora_rtc_engine`)
- **Audio Playback**: `audioplayers`
- **Chess Engine**: Native Stockfish CLI & WASM Engine integration
- **Video Rendering**: Server-side FFmpeg rendering engine

---

## 📁 Repository Structure

```
chess_master/
├── chess_app/             # Flutter Client Application
│   ├── lib/
│   │   ├── models/        # Data models (UserSession, SessionRecording, etc.)
│   │   ├── screens/       # UI Screens (HomeScreen, ChessGamePage, ReplayPlayerScreen, LoginScreen)
│   │   ├── services/      # Agora RTC, Stockfish & API Services
│   │   └── widgets/       # Chessboard, Draw Overlay, Move History & Dialogs
│   └── pubspec.yaml
└── chess_backend/         # Node.js Server & Database Layer
    ├── server.js          # Express & Socket.IO HTTP Server
    ├── db.js              # PostgreSQL Pool & Migration Schemas
    ├── limitsService.js   # Account Tier Limiter Middleware
    ├── clear_users.js     # Admin Database Cleanup Utility
    └── exports/           # Server-rendered MP4 Video Cache
```

---

## 🚀 Getting Started & Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>=3.0.0`)
- [Node.js](https://nodejs.org/) (`>=18.x`)
- [PostgreSQL](https://www.postgresql.org/) database server

### 1. Database Setup
Create a PostgreSQL database named `chess_app` (or configure your credentials in `chess_backend/.env`):
```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=chess_app
DB_USER=postgres
DB_PASSWORD=your_password
JWT_SECRET=your_jwt_secret
```

### 2. Backend Server Setup
```bash
cd chess_backend
npm install
node server.js
```

### 3. Flutter App Setup
```bash
cd chess_app
flutter pub get
flutter run
```

---

## 📄 License
This project is proprietary and developed for interactive remote chess teaching and lesson analysis.
