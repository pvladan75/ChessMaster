// The shared fixtures of `docs/PLAN-MAPA-DELOVA.md`, phase 0.
//
// Every part here is read through `TutorialSection.fromStep` — the app's one
// reader of a stored step — so a fixture that did not replay would say so in
// `rejectedMoves` rather than quietly lose its moves (rule 6: a fixture that is
// luckier than the real thing cannot fail). `tutorial_part_fixtures_test.dart`
// holds them to that before anything else is built on them.

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

/// The position of the owner's screenshot of 25.9.2026 — White to move before
/// move 17, the bishop still on f4. Every part of [sketchDraft] but the last
/// stands on it or on a position reached from it.
const String forkPosition =
    'r1b2rk1/p3qppp/2p2n2/2ppP3/2nP1B2/2P3P1/P1Q2PBP/R4RK1 w - - 0 17';

/// One move earlier: the knight still on b6, Black to play 16... Nc4.
const String beforeForkPosition =
    'r1b2rk1/p3qppp/1np2n2/2ppP3/3P1B2/2P3P1/P1Q2PBP/R4RK1 b - - 0 16';

const String standardStart =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A part read from a stored step: [fen] and a line written from it.
TutorialSection partOf(String fen, [String? pgn]) =>
    TutorialSection.fromStep({'fen': fen, if (pgn != null) 'pgn': pgn});

/// The position a line ends on, read through the same reader.
String fenAfter(String fen, String pgn) =>
    endOfMainLine(partOf(fen, pgn).root).fen;

/// The owner's example of 11.9.2026, checked live on 12.9 (`[151.7]` in the
/// archive): one part whose line forks after `1... Kc6`, the new line
/// `2. Ra8 Bb2` beside the original `2. Ra6 Bb2 3. c3 Kb5`.
///
/// `splitForLine` at `Kc6` makes three parts of it — up to the fork, the new
/// line, the original continuation — which is the order D2 of the plan
/// adopts for every door.
const String ownerExampleFen = '8/3k4/1n3b2/8/8/8/2PK4/2R5 w - - 0 1';
const String ownerExamplePgn =
    '1. Ra1 {The rook goes to the a-file.} Kc6 2. Ra6 '
    '(2. Ra8 {[%cal Ga8a6]} Bb2) Bb2 3. c3 Kb5 *';

TutorialSection ownerExamplePart() => partOf(ownerExampleFen, ownerExamplePgn);

/// A tree with two forks on its main line, two side lines at one of them, and
/// a fork inside a side line — the shape a book's annotated game has.
///
/// Main line: `17. Bg5 Nxe5 18. Rfe1 cxd4 19. cxd4`.
///  * at the root: `17. Be3 Nxe3 18. fxe3` and `17. Bc1 Nxe5`;
///  * after `18. Rfe1`: `18... h6 19. Rxe5`, which itself forks into
///    `19. Bxf6 Qxf6`.
///
/// Comments and one arrow sit on nodes in every kind of branch, so a split
/// that carries a node without what is written on it has something to lose.
const String manyForksPgn = '17. Bg5 {The bishop pins the knight.} '
    '(17. Be3 {The quiet retreat.} Nxe3 18. fxe3) '
    '(17. Bc1 Nxe5) '
    '17... Nxe5 18. Rfe1 {[%cal Ge1e5]} cxd4 '
    '(18... h6 {Asking the bishop.} 19. Rxe5 '
    '(19. Bxf6 {Taking first.} Qxf6)) '
    '19. cxd4 *';

TutorialSection manyForksPart() => partOf(forkPosition, manyForksPgn);

/// The eight parts of the sketch the owner accepted on 25.9.2026 — §3 of the
/// plan: a new board, two continuations, a return into the middle of a part,
/// two returns to the same position, a continuation after a return, and a
/// second new board.
TutorialDraft sketchDraft() {
  final afterRfe1 = fenAfter(forkPosition, '17. Bg5 Nxe5 18. Rfe1');
  final afterBc1 = fenAfter(forkPosition, '17. Bc1 Nxe5');
  return TutorialDraft(
    title: 'Broken Pawns and the Bishop Pair',
    sections: [
      // 1 — new board, ending on the fork position after 16... Nc4.
      partOf(beforeForkPosition, '16... Nc4 {The game until 16... Nc4.} *'),
      // 2 — continues: the position with the move the game played, drawn.
      partOf(
        forkPosition,
        '{In this position White played Bc1. The best move was… '
        '[%cal Bf4c1]} *',
      ),
      // 3 — continues: the best line.
      partOf(
        forkPosition,
        '{The bishop avoids the pawn\'s challenge and stays where it is '
        'active.} 17. Bg5 Nxe5 18. Rfe1 cxd4 *',
      ),
      // 4 — goes back into the middle of 3.
      partOf(afterRfe1, '{Black can also defend with h6.} 18... h6 19. Rxe5 *'),
      // 5 — goes back to the start of 3.
      partOf(
        forkPosition,
        '{A second move was available, but it is worse.} '
        '17. Be3 Nxe3 18. fxe3 *',
      ),
      // 6 — goes back to the same position, last shown at the start of 5.
      partOf(forkPosition, '{Back to the game.} 17. Bc1 Nxe5 *'),
      // 7 — continues 6.
      partOf(afterBc1, '{White\'s centre holds.} 18. Qe2 Re8 19. Re1 *'),
      // 8 — a new board nothing before it showed.
      partOf(
        standardStart,
        '{The same structure in another game.} 1. d4 d5 2. c4 c6 3. Nc3 Nf6 *',
      ),
    ],
  );
}
