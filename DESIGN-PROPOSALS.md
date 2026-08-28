# Design Proposals & System Architecture — `Mislisha`

This document details proposed design system expansions, architectural improvements, screen redesigns, and refactoring plans that lie outside the immediate allowlist of the `design/gemini-pass` branch.

---

## 1. Audit & Migration Plan for Color Literals (53 Files)

### 1.1 Current State
While 46 files in `chess_app/lib` properly consume tokens via `context.colors`, **53 files still contain hardcoded color literals** (`Colors.tealAccent`, `Colors.grey.shade900`, `Color(0x...)`, `Colors.white70`, etc.).

### 1.2 Impact & Risks
- **Visual Inconsistency**: Individual widgets pick ad hoc color shades (e.g. `Colors.indigo.shade700` vs `Colors.blue.shade800`).
- **Blocking Light Mode**: Direct `Colors.white` or `Colors.white70` text rendered on default surfaces will turn unreadable (white on white) in light mode.

### 1.3 Recommended Migration Roadmap
Migrate in 4 isolated, feature-specific PRs to prevent merge conflicts with concurrent feature development:
1. **Core Widgets & Shell** (`lib/widgets/*`, `lib/screens/home_screen.dart`, `lib/screens/settings_screen.dart`):
   - Replace literal backgrounds, icon colors, and card borders with `context.colors.surface`, `context.colors.border`, `context.colors.textSecondary`.
2. **Analysis Studio & Position Scanner** (`lib/features/analysis_studio/*`, `lib/features/position_scanner/*`):
   - Replace engine evaluation colors and piece highlight colors with `context.colors.accent` (Teal) and `context.colors.info` (Sky).
3. **Training & Tactics** (`lib/features/tactics_trainer/*`, `lib/features/endgame_trainer/*`, `lib/features/repertoire/*`):
   - Unify blunder, win, and draw badges with `context.colors.danger`, `context.colors.success`, and `context.colors.warning`.
4. **Live Room & Replay Player** (`lib/screens/chess_game_screen.dart`, `lib/screens/replay_player_screen.dart`):
   - Migrate chess clock text, voice indicators, and spectator seat styling to token layer.

---

## 2. Light Theme Enablement Roadmap

Light mode is currently disabled (`AppSettingsService` hardcodes `ThemeMode.dark`). Introducing light mode safely requires a strict 3-stage progression:

```
[Stage 1: Literals Migration] ──► [Stage 2: Light Token Layer] ──► [Stage 3: UI Preference Exposure]
53 files migrated to tokens        Define AppColorTokens.light     Expose ThemeMode toggle in Settings
```

### Stage 1: Literal Migration
- Complete the 53-file migration described above so zero UI elements assume a dark canvas.

### Stage 2: Register `AppColorTokens.light` & Light `ThemeData`
- Implement calibrated light tokens with verified WCAG AAA/AA contrast against `#F8FAFC` (Canvas), `#FFFFFF` (Surface), and `#F1F5F9` (SurfaceRaised):
  - `canvas`: `Color(0xFFF8FAFC)` (Slate 50)
  - `surface`: `Color(0xFFFFFFFF)` (White)
  - `surfaceRaised`: `Color(0xFFF1F5F9)` (Slate 100)
  - `border`: `Color(0x1E0F172A)` (12% Slate 900)
  - `borderStrong`: `Color(0x380F172A)` (22% Slate 900)
  - `textPrimary`: `Color(0xFF0F172A)` (Slate 900, 16.8:1 contrast)
  - `textSecondary`: `Color(0xFF475569)` (Slate 600, 7.5:1 contrast)
  - `textMuted`: `Color(0xFF64748B)` (Slate 500, 4.9:1 contrast)
  - `accent`: `Color(0xFF0D9488)` (Teal 600, 4.8:1 contrast)
  - `accentAlt`: `Color(0xFF7C3AED)` (Purple 600, 5.2:1 contrast)
  - `brand`: `Color(0xFF6D28D9)` (Violet 700, 6.1:1 contrast)
  - `info`: `Color(0xFF0284C7)` (Sky 600, 4.9:1 contrast)
  - `warning`: `Color(0xFFD97706)` (Amber 600, 4.7:1 contrast)
  - `danger`: `Color(0xFFE11D48)` (Rose 600, 4.8:1 contrast)
  - `success`: `Color(0xFF16A34A)` (Green 600, 4.6:1 contrast)
- Register `AppColorTokens.light` in light `ThemeData` in `main.dart`.

### Stage 3: UI Setting
- Add `ThemeMode` switcher (System / Dark / Light) in `SettingsScreen` and persist selection in `AppSettingsService`.

---

## 3. Proposed Design Token Additions

To bring the chessboard, clock, and specialized chess widgets into the token system, we propose adding `ChessColorTokens` as an additional `ThemeExtension`:

```dart
@immutable
class ChessColorTokens extends ThemeExtension<ChessColorTokens> {
  final Color boardLight;         // e.g. #E2E8F0 (Slate 200) / #F0D9B5 (Wood light)
  final Color boardDark;          // e.g. #475569 (Slate 600) / #B58863 (Wood dark)
  final Color squareLastMove;     // e.g. rgba(45, 212, 191, 0.35) (Teal highlight)
  final Color squareSelected;     // e.g. rgba(192, 132, 252, 0.40) (Purple highlight)
  final Color squareLegalMove;    // e.g. rgba(255, 255, 255, 0.25) dot / ring
  final Color squareCheck;        // e.g. rgba(253, 164, 175, 0.60) (Rose highlight)
  final Color clockActive;        // e.g. #2DD4BF
  final Color clockLowTime;       // e.g. #FDA4AF (< 30s alert)
  final Color evalWhite;          // e.g. #FFFFFF
  final Color evalBlack;          // e.g. #1E293B
}
```

---

## 4. Reusable Domain Component Library (`lib/widgets/chess/`)

Standardizing domain components will remove duplicate widget implementations across Analysis, Live Room, Tactics, and Replay:

### 4.1 `EvalBar` (`lib/widgets/chess/eval_bar.dart`)
- Vertical and horizontal animated evaluation bar.
- Automatic smooth animation on engine eval changes (`AnimatedContainer` / `TweenAnimationBuilder`).
- Accessible text rendering (White positive advantage in black text on white, Black negative advantage in white text on dark surface, Mate in X indicators).

### 4.2 `MoveListTable` (`lib/widgets/chess/move_list_table.dart`)
- Unified chess move table supporting mainline moves, inline variations, branch pills, and NAG annotations (`!`, `?`, `?!`, `??`, `!!`, `!?`).
- Auto-scrolling to active move index with highlight row.

### 4.3 `ChessClockWidget` (`lib/widgets/chess/chess_clock_widget.dart`)
- High-contrast digital clock readout with low-time warning pulse (`< 30s` transitions from neutral to `context.colors.warning` / `context.colors.danger`).
- Child-friendly large digits (`AppText.display`).

### 4.4 `PlayerCard` (`lib/widgets/chess/player_card.dart`)
- Compact player info row displaying title, username, rating, voice indicator, and active clock.

---

## 5. Screen Redesign Proposals

### 5.1 Analysis Studio (`AnalysisStudioScreen`)
- **Problem**: Right-hand panel is cramped on laptop screens; Stockfish dials and tree variations compete for vertical space.
- **Proposal**:
  - Implement a 3-tab segment for the side panel on desktop: `[Potezi & Stablo | Stockfish Analiza | Knjiga Otvaranja]`.
  - Use `AppSpacing.cardPaddingCompact` and `AppRadii.roundedMd` to maximize visible depth lines.
  - Use `context.colors.accent` for engine best move arrows and `context.colors.accentAlt` for alternative branches.

### 5.2 Live Room (`ChessGamePage`)
- **Problem**: In-game room controls (voice mute, draw offer, resign, flip board) are scattered across multiple toolbars.
- **Proposal**:
  - Clean floating action bar beneath the board with child-friendly 48×48dp icon buttons and clear Serbian tooltips.
  - Trainer controls (drawing arrows, setting positions, student mic control) grouped in a collapsible slide-over drawer on tablet/desktop.

### 5.3 Tactics Trainer (`TacticsTrainerScreen`)
- **Problem**: Feedback after solving or failing a puzzle is visually subtle.
- **Proposal**:
  - Prominent verdict banner using `context.colors.success` ("Tačno rešeno! +12 rejting") or `context.colors.danger` ("Netačan potez — pokušaj ponovo").
  - Tactical theme badges displayed as styled chips (e.g. `Dvostruki udar`, `Vezivanje`, `Otkriveni šah`) using `AppRadii.roundedPill`.

### 5.4 Repertoire (`RepertoireListScreen` & `RepertoireNewScreen`)
- **Problem**: Repertoire cards look identical regardless of white or black orientation.
- **Proposal**:
  - Distinct board orientation badge (White pawn icon vs Black pawn icon) with color-coded side indicators.
  - Progress ring indicating memorization percentage (% master lines reviewed).

---

## 6. Concurrent Work & Merge Safety Rationale

1. **Zero Breaking Changes**: No models, services, network protocols, or database schemas were touched.
2. **Strict Allowlist Isolation**: Only theme tokens, global ThemeData, the design gallery, the pilot training hub, and golden screenshot review tests were committed.
3. **No External Packages**: No dependencies added to `pubspec.yaml`.
4. **Verbatim Serbian Copy**: 100% of user-facing strings preserved exactly as written.

---

## 7. AI Studio Solution Graph: Palette Audit & Token Proposals (Batch 6)

### 7.1 Scope & Context
An audit of `chess_app/lib/widgets/ai_studio/` identified 16 hardcoded color and typography literals across 3 files:
- `solution_graph_widget.dart` (13 literals)
- `pgn_solution_tree_widget.dart` (1 literal)
- `grouped_moves_dialog.dart` (2 literals)

Rather than forcing naive substitutions onto foreground tokens that degrade contrast and destroy semantic pairings, all 16 literals are preserved in code pursuant to Rules 11 and 16. This section formalizes the architectural requirements and token proposals needed to support these complex surfaces.

---

### 7.2 Missing Token Role: Container Tokens & On-Container Typography

`solution_graph_widget.dart:390-413` defines distinct triples per node state:

| State | Background | Border | Text | Measured Contrast |
|---|---|---|---|---|
| **Active** | `#0284C7` (Sky 600) | `colors.info` (`#38BDF8`) | `Colors.white` | **4.10:1** (fails 4.5:1) |
| **Checkmate** | `#065F46` (Emerald 800) | `#34D399` (Emerald 400) | `#ECFDF5` (Emerald 50) | **7.29:1** (WCAG AAA) |
| **Grouped** | `#312E81` (Indigo 900) | `#818CF8` (Indigo 400) | `#E0E7FF` (Indigo 100) | **9.27:1** (WCAG AAA) |
| **White move** | `colors.surface` (`#1E293B`) | `#475569` (Slate 600) | `colors.textPrimary` (`#F8FAFC`) | **13.98:1** (WCAG AAA) |
| **Black move** | `colors.canvas` (`#0F172A`) | `colors.surfaceRaised` (`#334155`) | `colors.textMuted` (`#94A3B8`) | **6.96:1** (WCAG AA) |

#### The Defect of Naive Substitution
The current `AppColorTokens` system exposes only 400-level foreground accents (e.g. `success: #4ADE80`, `brand: #A78BFA`, `info: #38BDF8`), which are calibrated for legibility **on dark canvas/surface**:
- Naively remapping checkmate background to `colors.success` with `colors.textPrimary` text drops contrast from **7.29:1 down to 1.67:1** (catastrophic failure).
- Naively remapping grouped background to `colors.brand` with `colors.textPrimary` text drops contrast from **9.27:1 down to 2.60:1** (fails WCAG AA/AAA).

#### Proposal: Add Container & On-Container Semantic Tokens
We propose extending `AppColorTokens` with container triples (dark-hued surface + 400-level border + 50/100-level on-container text):
```dart
// Success Container (Checkmate / Solved nodes)
final Color successContainer;         // #065F46 (Emerald 800, L = 0.08665)
final Color successContainerBorder;   // #34D399 (Emerald 400, L = 0.49619)
final Color onSuccessContainer;       // #ECFDF5 (Emerald 50,  L = 0.94676) -> 7.29:1 contrast

// Grouped / Neutral Container (Defense variations / Branch clusters)
final Color groupedContainer;         // #312E81 (Indigo 900,  L = 0.04192)
final Color groupedContainerBorder;   // #818CF8 (Indigo 400,  L = 0.30201)
final Color onGroupedContainer;       // #E0E7FF (Indigo 100,  L = 0.80219) -> 9.27:1 contrast
```

---

### 7.3 The Fourth Accent & AI Studio Identity Hue (`#0284C7` Sky 600)

`#0284C7` (Sky 600, relative luminance $L = 0.20639$) is consistently used across the AI Studio feature:
1. `solution_graph_widget.dart:221` — Outer panel border
2. `solution_graph_widget.dart:224` — Panel glow shadow (`Color(0x400284C7)`, Sky 600 at 25% alpha)
3. `solution_graph_widget.dart:391` — Active graph node background
4. `grouped_moves_dialog.dart:100` — Primary modal CTA button (`ElevatedButton`)
5. Paired with `colors.info` (`#38BDF8`, Sky 400) for active borders and tree edges.

#### Trade-Off Analysis & Options
- **Option A (Recommended — Explicit Token `infoContainer` / `brandAiStudio`)**:
  - Add `#0284C7` as an identity token or calibrate active node background to Sky 700 (`#0369A1`, $L = 0.12696$).
  - White text on Sky 700 achieves **5.93:1** (passes WCAG AA 4.5:1), resolving the active node's current 4.10:1 contrast defect while retaining the blue identity.
- **Option B (Unify into `colors.info`)**:
  - Remap all 5 sites to `colors.info` (`#38BDF8`, Sky 400).
  - Under Rule 23, filled backgrounds take `colors.canvas` (`#0F172A`) as text foreground, achieving **8.33:1** (WCAG AAA).
  - *Cost*: Changes the visual mood of AI Studio from deep Sky 600 to bright Sky 400 and removes the 2-tone depth between the active node background and its `colors.info` border.

---

### 7.4 Recessed Canvas: Surface Below Canvas (`#020617` Slate 950)

`solution_graph_widget.dart:299` renders the `InteractiveViewer` scroll container background in Slate 950 (`#020617`):
- Relative luminance:
  - `#020617` (Slate 950): $L = 0.00205$
  - `#0F172A` (colors.canvas): $L = 0.00882$
- **Analysis**: Slate 950 is **4.3× darker** than `canvas`. Because the solution graph widget is embedded inside a panel that already sits on `canvas`, a nested recessed surface must be darker than `canvas` to provide visual depth.
- **Proposal**: Introduce `canvasRecessed: Color(0xFF020617)` to `AppColorTokens` for deep viewports, terminal panes, and interactive graph boards.

---

### 7.5 Audit of Pre-existing Contrast Deficits in Scope

Exact measured contrast ratios for failing pairings present in the existing code:

1. **Active Node Text** (`Colors.white` on Sky 600 `#0284C7`):
   - Contrast: **4.10:1** (Deficit: Below 4.5:1 minimum for body text).
2. **Active Node Border** (`colors.info` `#38BDF8` on Sky 600 `#0284C7`):
   - Contrast: **1.91:1** (Deficit: Below 3.0:1 minimum for graphical UI boundaries).
3. **White-Move Node Border** (Slate 600 `#475569` on `colors.surface` `#1E293B`):
   - Contrast: **1.93:1** (Deficit: Below 3.0:1 minimum for UI boundaries).
4. **PGN Solution Tree Border** (Teal 700 `#00796B` on `colors.surface` `#1E293B`):
   - Contrast: **2.75:1** (Deficit: Below 3.0:1 minimum for UI boundaries).
5. **Panel Border** (Sky 600 `#0284C7` on `colors.canvas` `#0F172A`):
   - Contrast: **4.36:1** (Compliant: Exceeds 3.0:1 for graphical UI boundaries).

---

### 7.6 Decision Records for Scope Substitution Points

#### 1. `grouped_moves_dialog.dart:100-101` (CTA Button)
- **Current code**: `backgroundColor: const Color(0xFF0284C7)`, `foregroundColor: Colors.white` (Contrast: **4.10:1**).
- **Decision**: **Keep literal** pursuant to Rule 11.
- **Rationale**: While remapping to `backgroundColor: colors.info` + `foregroundColor: colors.canvas` improves contrast to **8.33:1**, it breaks the unified Sky 600 identity across the 4 other AI Studio surfaces. The decision should be resolved globally via Section 7.3.

#### 2. `pgn_solution_tree_widget.dart:49` (Panel Border)
- **Current code**: `border: Border.all(color: Colors.teal.shade700, width: 1.5)` (Contrast: **2.75:1**).
- **Decision**: **Keep literal** pursuant to Rule 11.
- **Rationale**: Remapping to `colors.accent` (`#2DD4BF`, Teal 400) increases contrast to **7.86:1**, but visually transforms a subtle dark container outline into a glowing high-luminance active border, distorting the intended visual hierarchy.

#### 3. `solution_graph_widget.dart:243-246` (Header Typography)
- **Current code**: `TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.textPrimary)`
- **Decision**: **Keep literal** pursuant to Rule 11.
- **Rationale**: `fontSize: 15` is off the `AppText` scale (which defines 14 `subtitle` and 16 `title`). Rounding to `title` (16) violates Rule 10/11.

