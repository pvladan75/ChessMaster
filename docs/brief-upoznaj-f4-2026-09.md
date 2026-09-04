# Brief: the „Upoznaj repertoar" screen

Phase 4 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`, written 4.9.2026.

## 1. Why this job exists

The owner built a repertoire and could no longer read it:

> Kada gleda u stablo, teško je povezati celinu: „Šta ja zapravo igram u kojoj
> situaciji i šta me sve čeka?"

Phases 1–3 answered three quarters of that. The walk no longer hides his own
work behind the book's width (phase 1). The picture draws a decision of his, an
answered reply and a hole as three different shapes (phase 2). And
`walkthroughOrder` knows the order the story is told in (phase 3).

Phase 2 shipped and the owner watched it on both themes. His verdict, on
4.9.2026, is the reason this phase is still in the plan:

> Vizuelna razlika drastično olakšava pregled i graf je neuporedivo čitljiviji.
> Ipak, sam ekran „Upoznaj" nam je i dalje neophodan jer korisnik ne želi samo
> statičan pogled na razgranato stablo, već sekvencijalno vođenje kroz poteze
> na tabli korak-po-korak, gde na protivnikovom potezu jasno vidi listu
> odgovora i rupe.

So the screen you are building is **the tour**: one move at a time on a real
board, and at every reply of the opponent's, the list of what they can play and
which of those you have no answer to. Not a second tree, and not a second
builder.

Your job is the screen and the cursor that drives it. **No speech.** Narration
is phase 5, and it is deliberately last: a tour that is wrong is worse when it
talks.

## 2. What already exists — read these before writing anything

Almost all of this feature is already written. The new code is one small class
and one screen that arranges parts you must not reimplement.

| Where | What it gives you |
|---|---|
| `lib/features/repertoire/services/walkthrough_order.dart` | `walkthroughOrder(RepertoireTree)` → `List<WalkthroughStop>`, and `WalkthroughStop{move, path, depth, kind}`. **Phase 3's contract. Frozen.** |
| `lib/features/repertoire/widgets/repertoire_tree_panel.dart` | `repertoireTreeToNodes(tree, looks:)`, `RepertoireTreePanel`, `lookOfRepertoireMove`, `markOfRepertoireMove`, `findNodeByFen`, `countCutMoves` |
| `lib/features/analysis_studio/widgets/visual_move_tree_widget.dart` | `MoveTreeNodeLook { authored, covered, gap, refused }` |
| `lib/core/models/move_cursor.dart` | `MoveCursor` (the interface you implement) and `MoveBranch` |
| `lib/widgets/game_screen/move_navigation_controls.dart` | `MoveNavigationControls` — the strip, and it already asks at a fork |
| `lib/widgets/game_screen/move_keyboard_shortcuts.dart` | `MoveKeyboardShortcuts` — arrow keys over the same cursor |
| `lib/widgets/game_screen/branch_choice_sheet.dart` | `showBranchChoice` — the sheet. **The strip calls it for you.** |
| `lib/widgets/game_screen/chess_board_with_overlay.dart` | `ChessBoardWithOverlay` |
| `lib/features/repertoire/services/repertoire_api_service.dart` | `repertoireTree(...)`, `comments(color:)`, `RepertoireSummary` |
| `lib/theme/breakpoints.dart` | `Breakpoints.wide` (840) and `isWide(context)` |
| `lib/features/repertoire/screens/repertoire_drill_screen.dart` | **The screen to copy the shape of** — same constructor arguments, same load, same `onBuildHere` door |

`RepertoireTreeMove`, exactly:

```dart
final String uci;      // 'e2e4'
final String san;      // 'e4'
final String fen;      // the position this move leads to
final bool mine;       // whose move it is
final String? role;    // mine only: 'primary' | 'alternate'  (isPrimary)
final double share;    // theirs only: 0..1, how often it is played
final String state;    // '' | 'open' | 'unopened' | 'cut' | 'decided'
final List<RepertoireTreeMove> children;
```

## 3. The contract — the cursor

New file: `lib/features/repertoire/models/walkthrough_cursor.dart`.

```dart
/// The tour, as something the strip and the arrow keys can drive.
///
/// Built fresh in `build()` from the stop list and the current index, like
/// every other [MoveCursor]: it holds no state and calls back into the screen.
class WalkthroughCursor implements MoveCursor {
  const WalkthroughCursor({
    required this.tree,
    required this.stops,
    required this.index,
    required this.onSelect,
  });

  final RepertoireTree tree;
  final List<WalkthroughStop> stops;

  /// Where the tour is standing. **-1 is the root position**, before the first
  /// move of the tour has been played.
  final int index;

  /// The index the tour should move to.
  final ValueChanged<int> onSelect;
}
```

Behaviour, all of it:

| member | answer |
|---|---|
| `canGoBack` | `index >= 0` |
| `canGoForward` | `index < stops.length - 1` |
| `currentFen` | `index < 0 ? tree.rootFen : stops[index].move.fen` |
| `first()` | `onSelect(-1)` |
| `previous()` | `onSelect(index - 1)` when `canGoBack`, otherwise nothing |
| `next()` | `onSelect(index + 1)` when `canGoForward`, otherwise nothing |
| `last()` | the end of **this line** — see below |
| `forwardBranches` | the moves out of the current position, in tour order — see below |
| `takeBranch(i)` | `onSelect` of that branch's index in `stops`; out of range is `next()` |

### `previous` walks the tour, not the tree

One step back is one step of the tour undone, so `previous` is `index - 1` and
not „the parent move". After a line ends, the tour's next step climbs back to a
fork somewhere above and goes out along another branch; a back button that went
to the parent instead could not undo that step, and the reader would be unable
to return to where they just were. Forward and back must be each other's
inverse or the strip lies.

### `last()` is the end of the line, and the interface says so

`MoveCursor` documents `last()` as „the end of the line the cursor is currently
on — following first children, never jumping into a sibling variation". In tour
order that is: advance while the **next** stop is a strict descendant of the
current one, i.e. while `stops[i + 1].path` starts with `stops[i].path`. Stop as
soon as it does not — that stop belongs to another branch.

From `index == -1` treat the current path as empty, and the rule falls out: it
runs to the end of the first line.

### `forwardBranches` is derived from the tour, never re-sorted

The moves out of the current position are the stops after `index` whose `path`
is exactly the current path plus one move, taken while the scan is still inside
the current subtree.

```
prefix = index < 0 ? const <String>[] : stops[index].path
scan j from index + 1 while stops[j].path starts with prefix:
  if stops[j].path.length == prefix.length + 1 -> it is a child
stop at the first j whose path does not start with prefix
```

**Do not sort the move's `children` yourself, and do not copy phase 3's
comparator.** Three hand-written copies of one condition in this codebase each
forgot the same clause, and this is exactly that shape: the tour's order and the
fork sheet's order would drift apart the first time the rule changed. Deriving
from the stop list makes disagreement impossible.

Each branch:

```dart
MoveBranch(
  label: '${move.san}${markOfRepertoireMove(move) ?? ''}',
  detail: <the state, in words — §5.4>,
  isMain: <the first child in tour order>,
)
```

The label is the one the tree's own cards carry, marks and all, because the
choice must be made in the same words as everywhere else that move appears.

## 4. The contract — the screen

New file: `lib/features/repertoire/screens/repertoire_walkthrough_screen.dart`.

```dart
class RepertoireWalkthroughScreen extends StatefulWidget {
  const RepertoireWalkthroughScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    required this.api,
    this.rootPath = const [],
    this.gateUci,
    this.minRating,
    this.breadth,
    this.onBuildHere,
  });

  final String name;
  final String color;        // 'w' | 'b'
  final String rootFen;
  final List<String> rootPath;
  final String? gateUci;
  final int? minRating;
  final String? breadth;
  final RepertoireApiService api;

  /// The door out of a hole: „you have no answer here" and a way to the build
  /// screen at that very position. Null where the caller has nowhere to send
  /// them, and then the button is not drawn.
  final void Function(String fen)? onBuildHere;
}
```

Copy the argument list and the load from `RepertoireDrillScreen` — it is the
sibling of this screen, and the list screen already passes exactly these.

### Loading

One request, in `initState`:

```dart
_api.repertoireTree(
  color: widget.color,
  rootFen: widget.rootFen,
  rootPath: widget.rootPath,
  minRating: widget.minRating,
  gateUci: widget.gateUci,
  breadth: widget.breadth,
  maxPly: 30,
)
```

and one more beside it for `comments(color: widget.color)`, which is what the
card shows when the reader wrote something about a position. Two calls, both
free, both already used this way by the build screen.

`repertoireTree` returns **null when the server did not answer**, which is not
the same as a repertoire with nothing in it. Tell them apart on screen: §5.1.

Then `_stops = walkthroughOrder(tree)` once, and
`_root = repertoireTreeToNodes(tree, looks: _looks)` once. Both are pure;
neither is recomputed in `build()`.

### State

`int _index = 0` — the tour opens on its first move already played, not on an
empty board. `previous()` from there reaches the root, so both are available and
the screen opens on content. When `_stops` is empty, `_index` is `-1` and stays
there.

### Layout

`Breakpoints.isWide(context)`:

* **Narrow (< 840 dp)** — a `Column`: the board, the strip, then the card. **No
  tree.** The fork sheet is how a branch is chosen, and it is already built.
* **Wide (>= 840 dp)** — a `Row`: the board column on the left, and
  `RepertoireTreePanel` on the right, kept in step with the tour. The owner
  asked for this explicitly: on a desktop window the whole picture beside the
  board is what tells you where in it you are standing.

The tree panel is passed `root: _root`, `active:` the node for the current stop,
`onSelect:` a jump to that stop, `nodeLook: (node) => _looks[node.id]`,
`showCut: false`, and `minRating` / `breadth` so the picture says what it was
drawn at. Pass **no** `onPromote` and **no** `onDelete`: the tour does not
write, and a menu bound to nothing is a day of „a menu that does nothing"
already paid for once in that file's history.

Board and tree are matched by `findNodeByFen(_root, fen)`, never by comparing
whole FEN strings. The tree's FENs come from the server and the board computes
its own; they agree about the position and differ in the halfmove clock. That
exact mistake made the picture highlight the opening instead of the reader, in
silence, and it is in CLAUDE.md as a recurring shape.

### The board

`ChessBoardWithOverlay`, with `isAllowedToMove: false`, `isDrawingMode: false`,
`arrows: const []`, `engineArrows: const []`, and both callbacks no-ops. The
tour is read-only (plan §2.2) — the board is a picture here, not an input.

`boardOrientation` from `widget.color`. `lastMoveFrom` / `lastMoveTo` from the
current stop's `move.uci` (`substring(0, 2)` and `substring(2, 4)`), because on
a board that jumps a whole ply at a time the reader must be able to see what
just moved.

The board size comes from `MediaQuery`, never a constant. A release build paints
no overflow stripes: a row wider than the screen is silently clipped and the
controls past the edge are simply unreachable. See CLAUDE.md.

### The strip and the keys

`MoveNavigationControls(cursor: cursor, centerLabel: 'Potez N od M', onFlipBoard: …)`
wrapped in `MoveKeyboardShortcuts` over the same cursor. N is `_index + 1` and M
is `_stops.length`; below two stops pass `centerLabel: null` and
`canNavigate: false`, as the build screen does.

You write no fork dialog. The strip asks at a fork by itself, through
`forwardBranches` and `takeBranch` — that is the whole reason the cursor is the
contract and the screen is not.

## 5. The card, and every string on this screen

One card under the strip, saying what this stop is. This is the sentence phase 5
will later speak, so it must be a sentence and not a table.

All strings are new, and they are read against the **frozen glossary** of
`docs/PLAN-JEDNOSTAVNOST.md`: „glavna linija", „nepotvrđeni potezi", „koliko
odgovora spremamo", „rupe u repertoaru", „ne spremam". Do not invent a synonym
for any of those, and do not use a retired word („kičma", „nacrt", „talas",
„kapija", „širina", „pokrivenost", „odsečeno"). Use these strings **exactly**:

### 5.1 Screen chrome

| where | string |
|---|---|
| app bar title | `Upoznaj repertoar` |
| app bar subtitle | the repertoire's `name` |
| the server did not answer | `Ne mogu da učitam repertoar. Pokušajte ponovo.` |
| the repertoire is empty | `U ovom repertoaru još nema poteza.` |

### 5.2 A move of the reader's own (`MoveTreeNodeLook.authored`)

* primary: `Vaš potez — glavna linija.`
* alternate: `Vaš potez — druga mogućnost.`

### 5.3 A reply of the opponent's (`covered`)

* `Protivnik igra <SAN> — <X>% partija.`
* when `move.state == 'unopened'`, a second line: `Odluka bez uzetih odgovora.`

`<X>%` is formatted the way `markOfRepertoireMove` already does it: `<1%` under
one percent, otherwise rounded to a whole number. **Reuse that formatting; do
not write a second rounding rule.** Where `share` is 0 the percentage is left
out of the sentence entirely, which is the same rule the mark follows —
`Protivnik igra <SAN>.`

### 5.4 A hole (`gap`)

* `Na <SAN>, <X>% partija, nemate odgovor.`
* and a button, `Napravi odgovor`, shown only when `onBuildHere != null`, which
  calls `onBuildHere(move.fen)`.

The hole's `detail` in a `MoveBranch` is `nemate odgovor`; `unopened` is
`odluka bez uzetih odgovora`; a covered reply has `detail: null`. That is how
the reader „jasno vidi listu odgovora i rupe" in the sheet — the plain words,
next to the mark.

### 5.5 The replies, listed on the card

When the moves out of the current position are the **opponent's** and there is
more than one, the card ends with `Odavde protivnik ima <N> odgovora:` and then
a `Wrap` of one chip per branch, each chip carrying the branch's `label`,
tappable, jumping the tour to that stop. Use `serbianCount` for the plural of
„odgovor" — it is not regular, and the helper exists (see
`test/serbian_plural_test.dart`).

`Wrap`, not `Row`. This is the single most likely place for this screen to
overflow on a 360 dp phone, and in a release build it will do so without a
word.

### 5.6 What the reader wrote

When a comment exists for the current position — keyed by `fenKeyOf(fen)`,
which is how `comments()` is keyed — it is appended to the card under the
heading `Vaša napomena:`. It is the sentence they most want back, and it is the
last line of the card so it never pushes the state sentence off screen.

## 6. The entry point

In `lib/features/repertoire/screens/repertoire_list_screen.dart`, the
`PopupMenuButton<String>` already on each row (`tooltip: 'Još'`):

* a new item, **first in the list**, `value: 'walkthrough'`,
  `leading: Icon(Icons.menu_book_outlined)`, `title: Text('Upoznaj repertoar')`;
* in `onSelected`, a case that pushes the screen with `MaterialPageRoute`,
  exactly the way `_drill(item)` does — same arguments, and `onBuildHere` wired
  to `_open(item, at: fen)` after a `pop()`, again as `_drill` does.

Three rules about this, and each of them is a rejection if broken:

* **The menu, not a fourth icon.** The row already carries a badge, „Vežbaj" and
  this menu; a fourth control on a 360 dp phone clips silently in a release
  build. The owner decided the menu on 4.9.2026.
* **`Icons.menu_book_outlined`, because this app already draws it.**
  `flutter build windows` can ship a stale `MaterialIcons-Regular.otf`, and a
  *newly referenced* icon then renders as nothing at all while every existing
  one keeps working. See CLAUDE.md. Do not reach for an icon this app does not
  already use.
* **No named route.** The list screen pushes its siblings with
  `MaterialPageRoute` and `AppRoutes` knows about none of them. A route here
  would be a second copy of a contract, and `test/navigation_map_test.dart`
  exists because those two copies drift.

## 7. What gets the work rejected

* **A second copy of the ordering rule.** `forwardBranches` derived by sorting
  `children` instead of reading the stop list. §3.
* **A tour that writes.** Any call that saves, deletes, promotes or cuts. The
  screen reads two endpoints and nothing else.
* **An engine.** No evaluation, no Stockfish, no eval on the card. Plan §8.
* **A second builder.** The hole offers a *door*; it does not grow a board you
  can play a move on.
* **`ScaffoldMessenger` anywhere.** Use `AppFeedback`;
  `test/app_feedback_guard_test.dart` fails on a raw call and it is right to.
* **A fixed width, or a bare `Row` of controls.** §4, §5.5.
* **A string not in §5**, or a retired glossary word.
* **Changing `walkthroughOrder`, `WalkthroughStop`, `lookOfRepertoireMove`,
  `markOfRepertoireMove` or `RepertoireTree*`.** They are the frozen contract
  you are building against. If one of them is wrong, say so in the report and
  stop — do not fix it.
* **Touching `chess_backend/`.** Nothing here has a server side.

## 8. Your tests

Two files. Widget tests, not goldens — `dart_test.yaml` skips the golden group
unconditionally and `--tags golden` alone still skips it, so a batch graded on
goldens is a batch graded on nothing.

`test/walkthrough_cursor_test.dart` — the cursor, with no widget at all:

1. `next` walks the tour order, including the climb back to a fork: on the tree
   in §9, pressing next from the last stop of the first line lands on the stop
   phase 3 puts next, **not** on a sibling of the current move.
2. `previous` undoes exactly that step — `next` then `previous` returns the
   index it started from, at a place where the tour climbs.
3. `first` reaches the root, and `currentFen` there is `tree.rootFen`.
4. `last` stops at the end of the line and does not cross into a sibling
   branch.
5. `forwardBranches` at a fork lists the children **in tour order**, with the
   labels and details of §3 and §5.4, and `isMain` on the first.
6. `takeBranch(1)` moves to that branch's own stop index.
7. An empty tree: `canGoBack` and `canGoForward` are both false and nothing
   throws.

`test/repertoire_walkthrough_screen_test.dart` — the screen, against a fake
`RepertoireApiService` (there are several in `test/` to copy):

8. The card says the right sentence for each of the three kinds, on the tree in
   §9.
9. A hole shows `Napravi odgovor`, tapping it reports that position's FEN, and
   with `onBuildHere: null` the button is not drawn.
10. **At `Size(360, 640)` nothing overflows** on a fork with five replies. In a
    test build an overflow throws, which is the only place it is loud.
11. At `Size(1400, 900)` the tree panel is drawn and its active card follows the
    tour; at `Size(360, 640)` the panel is absent.
12. The server answering null shows §5.1's error and not the empty-repertoire
    sentence.

**Prove tests 1, 5 and 10 by mutation before you believe them** — break the
cursor's climb, break the branch order, and put the reply chips in a `Row` — and
report that you watched each one fail. A guard that has not been mutated is a
guard nobody has tested.

## 9. The worked tree — use this one

The reader plays White here; his own work sits under the opponent's *second*
reply, which is the shape the owner's own repertoire „Druga" has.

```
1. e4                        mine, primary
   1… e5      55%  decided   theirs — covered
      2. Nf3                 mine, primary
   1… c5      31%  open      theirs — a hole
   1… e6      14%  decided   theirs — covered
      2. d4                  mine, primary
         2… d5  60% open     theirs — a hole
```

`walkthroughOrder` visits, in this order — check it, do not assume it:

```
[e4], [e4 e5], [e4 e5 Nf3], [e4 e6], [e4 e6 d4], [e4 e6 d4 d5], [e4 c5]
```

`e6` comes before `c5` although `c5` is played more often: `e6` holds work of
the reader's own and `c5` holds none. That is the owner's rule from phase 3, and
if your `forwardBranches` disagrees with it you have re-sorted instead of
derived.

From `[e4 e5 Nf3]`, `next` goes to `[e4 e6]` — the climb. From `[e4]`,
`forwardBranches` is `e5 55%`, `e6 14%`, `c5 31% ?` in that order, with `c5`
carrying `detail: 'nemate odgovor'`.

## 10. How you are judged

Machine-checked, on the branch, by the lead:

1. `flutter test` — the floor is **1167 passing, 1 skipped**, measured by you
   before you start. Your own tests on top. **No existing test may change.** A
   test you had to edit is a finding: report it and stop.
2. `flutter analyze` — **29 issues, all `info`, all
   `curly_braces_in_flow_control_structures`.** Compare the list, not the exit
   code; it has never exited clean.
3. `dart format` on every Dart file you touched, last.
4. The strings gate allows added strings in exactly the three files named in
   §3, §4 and §6. A string added anywhere else fails the batch.

## 11. Out of scope, however tempting

* **Speech.** Phase 5. Not one `SpeechService` call.
* **Progress.** No „you have read 60% of your repertoire". It is a reading, not
  a schedule, and the drill already knows what you know.
* **A second order.** One order, phase 3's. „Show me the holes first" is a
  filter over the same order if it is ever wanted, and it is not wanted yet.
* **The tail.** The opponent's replies outside the breadth („van toga još 3
  poteza") are not in the tree endpoint's answer, and the owner decided on
  4.9.2026 that the tour speaks only about what is drawn. Do not add a field to
  the endpoint, and do not claim the list is complete.
* **The legend.** Whether the tree's legend should also name fill and
  silhouette is an open question of the owner's, not part of this batch.
