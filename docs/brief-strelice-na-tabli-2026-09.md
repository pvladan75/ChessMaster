# Brief: the board draws what the reader asked for

Written 3.9.2026. Pairs with [TASK-strelice-na-tabli.md](TASK-strelice-na-tabli.md),
which holds the scope and the method. This file holds the *why*, the exact
shapes, and the rules that bite.

Phase 1 of [PLAN-JEDNOSTAVNOST.md](PLAN-JEDNOSTAVNOST.md). Phase 0 is merged:
the three settings exist and are persisted, and you must not add a fourth.

## 1. Why this job exists

The owner, going through the app on a real machine: *„na tabli ponekad
pojavljuju strelice koje pokazuju potez koji je izabran i pokazuju se strelice
koje pokazuju Lichess statistiku. Korisnik bi mogao da ima izbor da li da ih
prikazuje ili ne. To isto i za linije motora."*

Three different things are drawn over the same eight squares, from three
different places, and the reader has no say. On a position with four kept moves
and an engine that has answered, the board is a bundle of arrows with numbers on
them and the pieces underneath are hard to find — the same complaint, in the
same session, as the last-move highlight that was painted over the piece
standing on it.

**This is not a redesign.** Everything keeps drawing exactly what it draws
today; the reader gains three switches and the defaults are the current
behaviour. A batch that changes what an arrow looks like has done something
nobody asked for.

## 2. What to build

### 2.1 One menu, where the one button is now

`BoardCoordinatesButton` is already the answer to "the same action grown four
icons across seven screens" — its own doc comment says so, and it is on ten
screens. The menu is that idea with three more items in it, not a second control
beside it.

So: **`BoardViewMenu` replaces it at all ten call sites**, and the old file goes.
A `PopupMenuButton` with switch rows, or a bottom sheet — your choice, with one
constraint from §5: it has to be usable at 360 dp, and a `PopupMenuItem` with a
`Switch` inside it is a row that grows.

Coordinates always. The arrow switches only where `arrows: true` is passed, on
the three screens that draw arrows. A menu offering to hide arrows on a screen
that has none is a control that teaches the reader the switch does nothing.

### 2.2 The three sources, and which switch owns which

This is the part to get exactly right, because all three arrive as
`EngineArrow` and the class says nothing about where an arrow came from.

In `repertoire_build_screen.dart`, `_boardArrows()` at line 1504, in the order
the method tries them:

| line | source | switch |
|---|---|---|
| `_replyArrows(_answers!)` | the opponent's replies to the move you just made — Lichess shares | **statistics** |
| `_shareArrows([...book.replies])` | the same, out of the stored book, after a move tapped in the tree | **statistics** |
| `_engineArrows()` | the engine's lines for this position | **engine** |
| `_keptArrows()` | the moves *you* chose here, with their share | **chosen move** |

`_boardArrows` is a chain of early returns: the first source with something to
say wins. Switching one off must let the chain **carry on to the next**, not
return an empty list — otherwise turning off statistics also turns off the
engine, which is a bug the reader will read as "the switches fight each other".

Elsewhere:

* `repertoire_drill_screen.dart:1133` — `_prefixArrow` is the move the rehearsal
  is replaying at you. That is the **chosen-move** switch: it is your line's
  move, drawn so you can see what was played.
* `analysis_studio_screen.dart:1929` — `_engineArrows`, the **engine** switch.
  The owner asked for this one *„generalno"*, which is why the Analysis Studio is
  in a repertoire-shaped batch.

### 2.3 Defaults, and why they are not yours to pick

All three default to **on**, and phase 0 already wrote that. A switch whose
default silently removes something on upgrade is received as a missing feature,
not as a new setting — this project has a whole section of `CLAUDE.md` about
changes that look like nothing and are not.

## 3. The API, exactly

**No endpoints.** Nothing in this batch talks to a server.

```dart
// Already in lib/services/app_settings_service.dart — do not add to it.
bool get showChosenMoveArrow;      // default true, key 'app_arrow_chosen_move'
bool get showStatisticsArrows;     // default true, key 'app_arrow_statistics'
bool get showEngineArrows;         // default true, key 'app_arrow_engine'

Future<void> setShowChosenMoveArrow(bool show);
Future<void> setShowStatisticsArrows(bool show);
Future<void> setShowEngineArrows(bool show);

// And the one that already existed, which the menu keeps offering:
bool get showBoardCoordinates;
Future<void> setShowBoardCoordinates(bool show);
```

`AppSettingsService` is a `ChangeNotifier` and `AppSettingsService.instance` is
a singleton. **Read it through `ListenableBuilder`**, the way
`board_coordinates_button.dart` already does, not into a field in `initState`:
the reader flips a switch and the board under it must change, in that frame,
without the screen being left and re-entered.

`ChessBoardWithOverlay` takes `arrows` (hand-drawn) and `engineArrows` (the ones
with a label on them). **Neither is yours to change.** The filtering happens in
the screens, above the board.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `AppSettingsService.instance` | the settings, persisted, already a `ChangeNotifier` |
| `board_coordinates_button.dart` | the control being replaced, and the reasoning to carry over |
| `AppFeedback` | the only way to show a message |
| `AppText`, `AppSpacing`, `AppRadii`, `context.colors` | the theme. Hardcoded values fail the scale gate |
| `test/repertoire_build_layout_test.dart` | how a build screen is pumped with a fake api |

## 5. Rules that bite

**A release build paints no overflow warning.** In debug a too-wide `Row` gets
yellow-and-black stripes; in release it is clipped, so a menu row looks shorter
than it is and the switch past the edge cannot be reached. A menu row is a label
and a switch, and Serbian labels are long — „Strelice sa statistikom" beside a
`Switch` at 360 dp is exactly the case. Use `Wrap` where a row can grow, take
widths from `MediaQuery`, and **pump every new menu at `Size(360, 640)`**.

**Colour is not a channel here.** The reader who signs this off does not read
hue. A switch that is on must be readable as on from its position and its label,
which is what a Material `Switch` already gives you — do not replace it with a
tinted dot.

**Two deprecated APIs will fail the analyze gate**, twelve infos between them,
and they cost an earlier batch a round:

* `Color.withOpacity(x)` → `Color.withValues(alpha: x)`
* `RadioListTile`'s per-tile `groupValue` / `onChanged` → a `RadioGroup`
  ancestor, whose callback is non-nullable, so a disabled state is an
  `AbsorbPointer` rather than a null callback.

**`flutter analyze` compares a list, not an exit code.** It has reported 29
infos for a long time and a red exit is its normal state. A thirtieth fails you.

**Prove a switch by watching the arrow go, not by watching the setting change.**
A test asserting `showEngineArrows == false` proves the setting was written. The
property is that the board stops drawing: pump the screen, count the arrows the
board is handed, flip the setting, count again. `ChessBoardWithOverlay` is a
widget you can find and read the parameters of.

## 6. How it will be judged

Nine gates, every one an exit code:

* nothing under `chess_backend/` may change;
* `strings` — user-facing literals byte-identical to HEAD, except in the files
  the harness has an allowance for (the menu is new; its labels are additions);
* `contrast`, `idioms`, `scale` — the theme's own rules;
* `dart format --set-exit-if-changed`;
* `worktree` — no stray files;
* `analyze` — 29, list compared;
* `tests` — 1108 before, and your own number after.

And then the diff is read for the things no gate reaches: whether the chain in
`_boardArrows` still falls through, whether the menu is reachable at 360 dp, and
whether `BoardCoordinatesButton` is really gone rather than left orphaned.

## 7. Out of scope

* Anything in `chess_backend/`.
* Changing how an arrow is drawn — colour, thickness, the label on it.
* A per-screen override of the settings. They are app-wide, like coordinates,
  and for the same reason: somebody who finds arrows cluttered means it
  everywhere.
* Settings screen rows for these three. The board menu is where they belong;
  a second place to change the same thing is the next question the owner asks.
