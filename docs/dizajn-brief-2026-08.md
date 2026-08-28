# Design brief — `design/gemini-pass`

This branch exists for one job: **the look of the app**. Colour, type, spacing,
the shape and weight of buttons, the rhythm of a card, how a dense panel sits
next to a chessboard. It is deliberately narrow, because the rest of the team is
working on functionality in the same files at the same time.

Read this whole file before editing anything. The allowlist in section 3 is the
part that decides whether your work can be merged at all.

---

## 1. What this app is

A chess coaching platform, Serbian, built in Flutter. A trainer runs a live
lesson in a room — board, voice, a silent replay of the lesson's move timeline —
plus puzzles, homework, spaced repetition and parent reports.

- **The users are Serbian children, roughly 7–14, and their trainers.** Not
  developers, not adults browsing on a laptop.
- **Real targets are Android and Windows.** A 360 dp phone is the hard case; a
  desktop window is the wide case.
- **The board is the hero.** On nearly every screen, everything else is support
  around a square that must stay as large as it can be.
- The app is called **Mislisha**. See section 4 — the naming rule is not a
  preference.

Today the UI is functional and plain: default Material 3, a dark palette, panels
that grew one at a time. Nothing has ever had a design pass. That is the gap.

## 2. The design system as it stands

There is already a small token layer. It was a *naming* pass, not a repaint —
the values are the literals the app happened to be using, pulled behind names.
**Repainting them is exactly the empty slot you are being asked to fill.**

| File | What it holds |
|---|---|
| `chess_app/lib/theme/app_colors.dart` | `AppColorTokens`, a `ThemeExtension`: 15 roles (canvas, surface, surfaceRaised, border, borderStrong, textPrimary/Secondary/Muted, accent, accentAlt, brand, info, warning, danger, success). Read at call sites as `context.colors.accent`. |
| `chess_app/lib/theme/app_typography.dart` | `AppText`, a type scale distilled from what the app already uses: 10/11/12/13/14/16/18/22. Plain `const TextStyle`s, not a `TextTheme`, because most call sites do `.copyWith(color: …)`. |
| `chess_app/lib/theme/breakpoints.dart` | `Breakpoints.wide = 840.0` and `isWide(context)`. |
| `chess_app/lib/main.dart` (~lines 67–85) | The two `ThemeData` blocks. Both are `ColorScheme.fromSeed(deepPurple)` + `useMaterial3`, and **nothing else** — no button theme, no card theme, no input decoration theme, no shape. |

Two facts worth knowing before you start:

- **46 files read `context.colors`; 53 still use raw `Colors.x` / `Color(0x…)`
  literals.** Migrating those 53 is a genuinely good idea and you may **not** do
  it — it touches half the app and would collide with active work. Write it up
  in `DESIGN-PROPOSALS.md` instead.
- **The light theme registers no `AppColorTokens`.** `context.colors` falls back
  to `AppColorTokens.dark`, so in light mode every tokenised colour is still the
  dark one. The app is dark-only in practice. If you want to make light mode
  real, register a light token set — do not leave the silent fallback in place.

The empty `ThemeData` is your biggest lever. A `FilledButtonThemeData`, a
`CardTheme`, an `InputDecorationTheme` and a shape scale change every screen at
once without editing a single screen. Reach for that before you reach for a
widget tree.

## 3. What you may change

**Edit freely:**

- `chess_app/lib/theme/*` — and new files added there.
- The two `ThemeData` blocks in `chess_app/lib/main.dart`, and nothing else in
  that file.
- A new `chess_app/lib/screens/design_gallery_screen.dart` (see below).
- `chess_app/lib/routing/app_routes.dart` and `app_router.dart` — **one appended
  route** for the gallery, nothing else.
- The pilot screen, all three files:
  - `chess_app/lib/features/training/screens/training_hub_screen.dart`
  - `chess_app/lib/widgets/ai_studio/category_selection_hub.dart`
  - `chess_app/lib/features/training/widgets/resume_strip.dart`
- `DESIGN-PROPOSALS.md` at the repo root — a new file, yours.

**The gallery** is a screen that exists only to be looked at: your button
variants, cards, dialogs, chips, list rows, the spacing scale, the type scale,
the palette, an evaluation bar, a move-list row. It is where design gets
reviewed, because a widget diff cannot be reviewed by reading it. Route it, but
do not link it from any user-facing navigation.

**The pilot** is the training hub: a screen of cards that says what there is to
practise. It is small (70 + 545 + 120 lines), self-contained, visual, and has a
test (`chess_app/test/training_hub_test.dart`). Take it end to end. It is the
sample by which the rest of the mandate is decided.

**Everything else is off-limits.** All 29 other screens, every other widget, the
whole of `chess_backend/`, `docs/`, `deploy/`, `puzzles/`, CI config, and
`pubspec.yaml` unless a font genuinely requires it (say so in the commit).

Anything you would like to change outside the allowlist goes into
`DESIGN-PROPOSALS.md`: what, where, why, and roughly how big. That file is a
deliverable, not a consolation prize — a good one is worth more than a wide
diff, because the wide diff would be thrown away in the merge.

## 4. Rules that bite

These are not style preferences. Each has already cost this project real time.

1. **User-facing strings stay Serbian.** Every label, button, dialog and error
   the user reads is Serbian and must remain Serbian, spelled exactly as it is.
   The users are Serbian children and trainers. Do not "improve" copy, do not
   translate, do not switch script. Code comments and commit messages are
   English.
2. **Never name the product "Chess Master" or "Chessmaster"**, anywhere a user
   could see it. It is Ubisoft's trademark. The app is **Mislisha**; the
   application id is `rs.pejovic.chesscoach`.
3. **A release build paints no overflow warning.** A `Row` wider than the screen
   gets yellow-and-black stripes in debug and is silently *clipped* in release —
   the row just looks shorter and the buttons past the edge are unreachable.
   Three of these shipped. Where a row can grow, use `Wrap`. Where a width is
   fixed, take it from `MediaQuery` instead of hardcoding (a dialog with a fixed
   360 content width overflows a 360 dp phone). A widget test at
   `Size(360, 640)` catches it, because in a test build the overflow does throw.
4. **Never use `ScaffoldMessenger` directly.** All user feedback goes through
   `AppFeedback` (`chess_app/lib/widgets/app_feedback.dart`), which cannot throw.
   A message must never be able to take down the action it reports on — that bug
   has happened twice here, once stopping a recording from stopping.
   `test/app_feedback_guard_test.dart` fails if a raw call comes back.
5. **Touch targets are for children.** Nothing interactive below 48×48 dp, and
   be generous with spacing between adjacent controls. Density is fine in an
   analysis panel an adult reads; it is not fine in anything a child taps.
6. **Contrast is not optional.** Body text against its surface at 4.5:1, large
   text and icons at 3:1. Check it, do not eyeball it — the current palette
   leans on `white54` in places that are already marginal.
7. **Run `dart format` on every Dart file you touch.** CI does not enforce it,
   but the formatter reindents aggressively and an unformatted file turns the
   next diff into noise.
8. **The repository is public.** No secrets, IP addresses, email addresses or
   account identifiers in code, comments, docs or commit messages.
9. **Do not add a package** without saying why in the commit message. A design
   pass should not need one.

## 5. What "good" looks like here

- **Calm, not loud.** This is a tool a child uses for forty minutes with a
  trainer, not a game that needs to grab attention. Colour earns its place by
  meaning something — an evaluation sign, a correct answer, a warning — and the
  chrome stays quiet so the board reads first.
- **One accent, used consistently.** Right now `accent`, `accentAlt` and `brand`
  are teal, purple and deep purple, chosen at different times. Decide what the
  three are actually *for* and make the difference legible.
- **A spacing scale.** There isn't one. Padding is currently 4/6/8/12/16 chosen
  per widget. Pick a scale, put it in the theme layer, and use it in the pilot.
- **Shape as a system.** Corner radii, border weights and elevation should come
  from two or three decisions, not thirty.
- **Dense panels still need air.** The analysis panels next to the board are the
  hardest case: a lot of numbers in a narrow column. Solve the general problem in
  the gallery rather than screen by screen.
- **Portrait phone first, then the wide window.** Not the other way round.

## 6. Before you hand it back

All four, every time:

- `cd chess_app && flutter test` — **767 tests, all passing.** The suite is a
  real semantic guard: if a design change breaks a test, you changed behaviour,
  not appearance. Fix the code, not the test, unless the test is asserting a
  literal colour or size you deliberately changed — and then say so.
- `cd chess_app && flutter analyze` — **no new issues.** The baseline is 29,
  all `info` level, all `curly_braces_in_flow_control_structures`, all
  pre-existing. Zero errors and zero warnings today; keep it that way.
- **Screenshots**: the gallery and the pilot screen, at 360×640 and at a window
  ≥840 wide. Commit them under `design-screenshots/` in this branch. Without
  these the work cannot be reviewed.
- **`DESIGN-PROPOSALS.md`** written up.

### Getting the screenshots without a backend

You are working in a `git worktree`, so this directory has only what git tracks.
Before anything else:

```bash
cd chess_app
cp dart_defines.example.json dart_defines.json   # the real one is not in git, and you do not need it
flutter pub get
```

Do **not** ask for the real `dart_defines.json`. It carries a Lichess API token
and Google desktop OAuth credentials; nothing in your mandate needs them, and the
example file has the same shape with empty values.

For the screenshots themselves, do not try to boot the whole app — the training
hub sits behind a login against a backend that is not running. Use golden files:
a widget test that pumps the gallery and the pilot at a fixed
`Size(360, 640)` and again at `Size(1200, 800)`, with `matchesGoldenFile`, then

```bash
flutter test --update-goldens
```

which writes real PNGs. That gets you the picture, and it gets you the 360 dp
overflow check from section 4 in the same run, because a test build throws on an
overflow where a release build silently clips. Keep those tests out of the normal
suite's expectations if they would be brittle — say what you did either way.

Commit in small, readable steps — tokens, then theme, then gallery, then pilot —
so the review can follow the reasoning. Do not merge, do not rebase onto
`master`, do not push anywhere but this branch. `master` moves while you work;
that is expected and is exactly why the allowlist is what it is.

## 7. If you disagree with the scope

Say so in `DESIGN-PROPOSALS.md` and keep to it anyway. The narrowness is not a
judgement about design — it is that this branch has to survive a merge with a
month of concurrent work on the same widget trees.
