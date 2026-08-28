# Project Guidelines & Rules — Mislisha (`chess_app`)

This document defines core rules, architectural guidelines, and constraints for all AI agents and subagents working in this codebase.

---

## 1. Domain & Language Rules
- **Target Audience**: Children (ages 7–14) learning chess and chess trainers/coaches.
- **Language**: All user-facing strings, UI labels, tooltips, dialogs, and button copy **must be in Serbian Latin (sr-Latn)**.
- **Domain Terminology**:
  - `Trening` (Training/Drills): Practice drills, puzzle sets, endgame exercises whose progress is saved.
  - `Lekcija` (Lesson): Structured courses with ordered steps created and assigned by a trainer.
  - `Repertoar` (Repertoire): Opening move tree built and evaluated position-by-position.
  - `Potez` (Move), `Mat` (Checkmate), `Šah` (Check), `Remi` (Draw), `Završnica` (Endgame), `Taktika` (Tactics), `Otvaranje` (Opening).
  - **Never modify user-facing Serbian copy** without explicit user instruction. Preserve all existing copy verbatim.

---

## 2. Git & Worktree Protection Rules
- **NEVER modify or stage platform-generated directories**:
  - `chess_app/linux/`
  - `chess_app/macos/`
  - `chess_app/windows/`
  - If any build or pub tool touches these, always run: `git checkout -- chess_app/linux chess_app/macos chess_app/windows`.
- **Formatting Scope**:
  - **Never** run `dart format .` or `dart format lib/` over the whole project.
  - **Always** format only the files you touched by exact path: `dart format <file1> <file2>`.

---

## 3. Design System & Token Rules
- **Theme & Colors**:
  - Never use raw `Colors.*` or hardcoded hex `Color(0x...)` in UI widgets.
  - Always read colors from `context.colors.*` (`AppColorTokens.dark` via `package:chess_app/theme/app_colors.dart`):
    - `context.colors.canvas`: Dark background behind panels (`#0F172A`).
    - `context.colors.surface`: Default card and panel surface (`#1E293B`).
    - `context.colors.surfaceRaised`: Elevated surface for headers and selected rows (`#334155`).
    - `context.colors.border`: Subtle 12% white outline (`0x1FFFFFFF`).
    - `context.colors.borderStrong`: Focused 24% white outline (`0x3DFFFFFF`).
    - `context.colors.textPrimary`: High-contrast body/title text (`#F8FAFC` — 17.06 / 13.98 / 9.90 on canvas / surface / surfaceRaised).
    - `context.colors.textSecondary`: Secondary descriptive text (`#CBD5E1` — 12.02 / 9.85 / 6.97).
    - `context.colors.textMuted`: Metadata, labels, inactive hints (`#94A3B8` — 6.96 / 5.71 / **4.04**). On `surfaceRaised` this is below AA for body text: use it there only for icons, badges and large text, never for prose.
    - `context.colors.accent`: Teal 400 (`#2DD4BF`) — engine eval, active board state.
    - `context.colors.accentAlt`: Purple 400 (`#C084FC`) — alternate branches, variations.
    - `context.colors.brand`: Violet 400 (`#A78BFA`) — platform identity.
    - `context.colors.danger`: Rose 300 (`#FDA4AF`) — errors, blunders, lost positions (9.44 / 7.74 / 5.48 on canvas / surface / surfaceRaised).
    - `context.colors.warning`: Amber 400 (`#FBBF24`) — warnings, blunder alerts.
    - `context.colors.success`: Green 400 (`#4ADE80`) — correct moves, puzzle victories.
    - `context.colors.info`: Sky 400 (`#38BDF8`) — informational hints, adaptive mode.
- **Typography**:
  - Always use `AppText.*` (`package:chess_app/theme/app_typography.dart`): `display`, `headline`, `title`, `subtitle`, `bodyLargeBold`, `bodyLarge`, `bodyBold`, `body`, `captionBold`, `caption`, `micro`.
- **Spacing & Radii**:
  - Always use `AppSpacing.*` (2, 4, 8, 12, 16, 20, 24, 32 dp).
  - Always use `AppRadii.*` (4, 8, 12, 16, 20 dp, pill 999 dp).
- **Accessibility & Child Touch Targets**:
  - Every interactive button and touch target must have a minimum size of **48×48 dp**.
  - Body text must achieve **WCAG AA ($\ge 4.5:1$)** against **the surface it actually sits on**, which is not always `surface`. Large text, icons, borders and badges need $\ge 3.0:1$.
  - A contrast figure is only meaningful with its background named. Never write an unqualified "$\ge X:1$" next to a token — three of the tokens above pass on `canvas` and `surface` and fail on `surfaceRaised`, and an unqualified number hides exactly that.
  - **A token used as a background takes `context.colors.canvas` as its foreground.** `accent`, `danger`, `warning`, `success`, `brand`, `accentAlt` and `info` are light tokens, chosen to be read *on* canvas; putting `textPrimary` on one gives roughly 1.8:1. The theme already declares the pairing — `onPrimary`, `onSecondary` and `onError` are all `#0F172A`. This is not a rule about buttons: it holds for any filled chip, badge, pill or container. Where the background is conditional, the foreground must switch with it.
  - **Recompute before you claim.** Every ratio in this file was verified against the sRGB relative-luminance formula. If you change a token, recompute all three surfaces and update the numbers here in the same edit.

---

## 5. Rules That Bite

These are not style preferences. Each has already cost this project real time, and
none of them can be inferred from the code. They are condensed from `CLAUDE.md`,
which is the authority — read it when any of these is in play.

- **Never name the product "Chess Master" or "Chessmaster"** anywhere a user could see it. It is Ubisoft's trademark, in the same product category. The app is **Mislisha**; the application id is `rs.pejovic.chesscoach`.
- **Never call `ScaffoldMessenger` directly.** All user feedback goes through `AppFeedback` (`lib/widgets/app_feedback.dart`), which cannot throw. A message must never be able to take down the action it reports on — that has happened twice here, once preventing a recording from stopping. `test/app_feedback_guard_test.dart` fails if a raw call reappears.
- **A release build paints no overflow warning.** A `Row` wider than the screen gets stripes in debug and is silently *clipped* in release: the row merely looks shorter and the controls past the edge are unreachable. Where a row can grow use `Wrap`; where a width is fixed take it from `MediaQuery` rather than hardcoding. A widget test at `Size(360, 640)` catches it, because a test build does throw.
- **The repository is public.** No secrets, IP addresses, email addresses, account or cluster identifiers in code, comments, docs or commit messages. Real values live in `.env` on the machine that needs them.
- **Prefer a loud failure to a quiet fallback.** The recurring bug in this codebase is a step that skips silently, reports success, and fails one layer or one run later. When you add a guard, prove it by mutation before believing it: break the thing it guards and confirm the guard fails.

---

## 4. Testing & Verification Rules
- **Unit & Widget Tests**:
  - `flutter test` must pass all 767+ standard tests.
  - Golden screenshot tests are tagged with `@Tags(['golden'])` and configured in `dart_test.yaml` so they stay as visual review artifacts and are skipped during regular CI test runs.
  - To run/update goldens: `flutter test --tags golden --run-skipped --update-goldens test/design_gallery_golden_test.dart`.
- **Static Analysis**:
  - `flutter analyze` must produce **0 errors** and **0 warnings**.
  - Baseline info issues (29 pre-existing `curly_braces_in_flow_control_structures`) must not be increased.
