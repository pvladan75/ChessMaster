// A part is one line on the board — phase 1 of `docs/PLAN-MAPA-DELOVA.md`, D1.
//
// Until this phase a second move at a position that already went on became a
// second child in the same part: saved, drawn in „Tree", and never in the film,
// because `filmBeatsOf` walks first children. So the proof asked of every case
// here is the film, not the tree — a part that forks still „has" the move.
//
// D1: the open part stays exactly as it was, and a new part is inserted right
// after it, opening on the position the move was played from, with that move
// as its line. In the film it is a return („Back to the position after …").

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_controller.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/tutorial_part_fixtures.dart';

/// Part 3 of the sketch, with words, an arrow and a square on 18. Rfe1 — the
/// move a second line will be played from.
const String _bestLinePgn = '{The bishop stays active.} 17. Bg5 Nxe5 '
    '18. Rfe1 {The rook joins. [%cal Ge1e5] [%csl Re5]} cxd4 *';

TutorialSection _bestLine() => partOf(forkPosition, _bestLinePgn);

AnalysisNode _child(AnalysisNode node, String san) =>
    node.children.singleWhere((c) => c.moveSan == san);

AnalysisNode _rfe1Of(TutorialSection part) =>
    _child(_child(_child(part.root, 'Bg5'), 'Nxe5'), 'Rfe1');

/// Every node below [root].
Iterable<AnalysisNode> _below(AnalysisNode root) sync* {
  for (final child in root.children) {
    yield child;
    yield* _below(child);
  }
}

/// A three-part tutorial standing on the best line, the part in the middle —
/// so „right after the open part" and „at the end" are different places.
TutorialDraftController _threeParts({bool blackOrientation = false}) {
  final best = _bestLine()..blackOrientation = blackOrientation;
  return TutorialDraftController(
    draft: TutorialDraft(
      sections: [
        partOf(beforeForkPosition, '16... Nc4 *'),
        best,
        partOf(standardStart, '1. d4 d5 *'),
      ],
      selected: 1,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  group('a second move at a position that goes on', () {
    test('leaves the open part as it was and opens a part right after it', () {
      final c = _threeParts();
      final best = c.draft.sections[1];
      final signature = treeSignature(best.root);
      final rfe1 = _rfe1Of(best);
      c.jumpTo(rfe1);

      expect(c.playMove('h7', 'h6', ''), MoveOutcome.branched);

      final parts = c.draft.sections;
      expect(parts, hasLength(4));
      expect(identical(parts[1], best), isTrue);
      expect(treeSignature(best.root), signature,
          reason: 'the open part keeps its one line — no second child');
      expect(c.draft.selected, 2, reason: 'right after the open part');
      expect(parts[3].root.fen, standardStart,
          reason: 'the part that followed still follows, one place on');

      final line = parts[2];
      expect(line.root.fen, rfe1.fen);
      expect(line.root.children.map((n) => n.moveSan), ['h6']);
      expect(identical(c.cursor, line.root.children.single), isTrue,
          reason: 'the trainer stands on the move just played');
    });

    test('is in the film — the proof, not the tree', () {
      final c = _threeParts();
      c.jumpTo(_rfe1Of(c.draft.sections[1]));
      c.playMove('h7', 'h6', '');

      final played = [
        for (final stop in filmBeatsOf(c.draft)) stop.beat.arrivedBy,
      ];
      expect(played, contains('h6'));
      expect(played.where((m) => m == 'cxd4'), hasLength(1),
          reason: 'the main line is still filmed once');
    });

    test('opens as a return to the move it was played after', () {
      final c = _threeParts();
      c.jumpTo(_rfe1Of(c.draft.sections[1]));
      c.playMove('h7', 'h6', '');

      final stops = filmBeatsOf(c.draft);
      final openings = partOpeningsOf(stops);
      final at = stops.indexWhere(
        (s) => identical(s.section, c.draft.sections[2]) && s.beat.index == 0,
      );
      expect(openings[at]?.entry, PartEntry.returns);
      expect(openings[at]?.afterMove, '18. Rfe1');
    });

    test('carries the marks and the orientation, not the sentence', () {
      final c = _threeParts(blackOrientation: true);
      c.jumpTo(_rfe1Of(c.draft.sections[1]));
      c.playMove('h7', 'h6', '');

      final root = c.draft.sections[2].root;
      expect(root.arrows.map((a) => a.toString()), ['Ge1e5'],
          reason:
              'the board reloads at a return, so the marks are drawn again');
      expect(root.squares.map((s) => s.toString()), ['Re5']);
      expect(root.comment, isEmpty,
          reason: 'the sentence was read out where it was written');
      expect(c.draft.sections[2].blackOrientation, isTrue);
    });

    test('from the part\'s own starting position, opens on that position', () {
      final c = _threeParts();
      c.jumpTo(c.draft.sections[1].root);

      expect(c.playMove('f4', 'e3', ''), MoveOutcome.branched);
      expect(c.draft.sections, hasLength(4));
      expect(c.section.root.fen, forkPosition);
      expect(c.section.root.children.map((n) => n.moveSan), ['Be3']);
      expect(c.draft.sections[1].root.children.map((n) => n.moveSan), ['Bg5']);
    });

    test('one undo gives back one part, and the cursor where it was', () {
      final c = _threeParts();
      c.jumpTo(_rfe1Of(c.draft.sections[1]));
      c.playMove('h7', 'h6', '');

      c.undo();

      expect(c.draft.sections, hasLength(3));
      expect(c.draft.selected, 1);
      expect(c.cursor.moveSan, 'Rfe1');
      expect(_below(c.draft.sections[1].root).map((n) => n.moveSan),
          isNot(contains('h6')));
    });
  });

  group('everything else a move does is unchanged', () {
    test('the move the line already plays walks into it', () {
      final c = _threeParts();
      final rfe1 = _rfe1Of(c.draft.sections[1]);
      c.jumpTo(rfe1);

      expect(c.playMove('c5', 'd4', ''), MoveOutcome.played);
      expect(c.draft.sections, hasLength(3));
      expect(identical(c.cursor, rfe1.children.single), isTrue);
    });

    test('a move at the end of the line extends the part', () {
      final c = _threeParts();
      final cxd4 = _child(_rfe1Of(c.draft.sections[1]), 'cxd4');
      c.jumpTo(cxd4);

      expect(c.playMove('c3', 'd4', ''), MoveOutcome.played);
      expect(c.draft.sections, hasLength(3));
      expect(identical(c.cursor.parent, cxd4), isTrue);
    });

    test('a move the position does not allow changes nothing', () {
      final c = _threeParts();
      c.jumpTo(_rfe1Of(c.draft.sections[1]));

      expect(c.playMove('f4', 'f5', ''), MoveOutcome.illegal);
      expect(c.draft.sections, hasLength(3));
      expect(c.cursor.moveSan, 'Rfe1');
    });
  });

  // The owner's decision of 25.9.2026: while the PGN tab holds text that was
  // not applied, a move that would open a part is held back. A new part
  // rebuilds that field for itself, so the text would be gone without a word;
  // carried across, it would be applied to a part it was not written for.
  group('held back while the PGN tab holds unapplied text', () {
    test('a move that would open a part changes nothing', () {
      final c = _threeParts();
      final signature = treeSignature(c.draft.sections[1].root);
      final rfe1 = _rfe1Of(c.draft.sections[1]);
      c.jumpTo(rfe1);

      expect(
          c.playMove('h7', 'h6', '', mayOpenPart: false), MoveOutcome.heldBack);
      expect(c.draft.sections, hasLength(3));
      expect(c.draft.selected, 1);
      expect(treeSignature(c.draft.sections[1].root), signature);
      expect(identical(c.cursor, rfe1), isTrue);
    });

    test('a move that opens no part is played as before', () {
      final c = _threeParts();
      final rfe1 = _rfe1Of(c.draft.sections[1]);
      c.jumpTo(rfe1);

      expect(c.playMove('c5', 'd4', '', mayOpenPart: false), MoveOutcome.played,
          reason: 'walking into the line opens nothing');
      expect(c.playMove('c3', 'd4', '', mayOpenPart: false), MoveOutcome.played,
          reason: 'extending the line opens nothing');
      expect(c.draft.sections, hasLength(3));
    });
  });

  group('the studio says it', () {
    final session = UserSession(
      token: 't',
      id: 7,
      email: 'a@b.c',
      name: 'Trener',
      role: 'trener',
    );

    Future<void> open(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: TutorialStudioScreen(
          session: session,
          entry: TutorialEntry.fromAnalysis(
            TutorialHandover.tree(_bestLine().root),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> play(WidgetTester tester, String from, String to) async {
      tester
          .widget<ChessBoardWithOverlay>(
              find.byType(ChessBoardWithOverlay).first)
          .onMove(from, to, '');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after $from$to');
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      debugDefaultTargetPlatformOverride = null;
    }

    const said = '18... h6 starts part 2. The film shows it after part 1.';

    testWidgets('on the desktop, after the part is made', (tester) async {
      await open(tester, const Size(1600, 1000));
      for (final move in ['f4g5', 'c4e5', 'f1e1']) {
        await play(tester, move.substring(0, 2), move.substring(2));
      }
      expect(find.text(said), findsNothing,
          reason: 'walking into moves the line already plays says nothing');

      await play(tester, 'h7', 'h6');
      expect(find.text(said), findsOneWidget);
      await close(tester);
    });

    testWidgets('on a phone at 360 x 640, and the Parts tab shows the part',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await open(tester, const Size(360, 640));
      for (final move in ['f4g5', 'c4e5', 'f1e1', 'h7h6']) {
        await play(tester, move.substring(0, 2), move.substring(2));
      }
      expect(find.text(said), findsOneWidget);

      await tester.tap(find.byKey(const Key('phone-tab-parts')));
      await tester.pumpAndSettle();
      expect(find.text('Part 2'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a PGN tab that went away holds nothing back', (tester) async {
      // An Android tablet turned across the breakpoint swaps the desktop
      // layout, which has the PGN tab, for the phone's, which has none — and
      // the board stays. The typed text went with the tab, so a move that
      // opens a part must not be held back for it.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await open(tester, const Size(1600, 1000));
      await tester.tap(find.byKey(const Key('pgn-tab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pgn-field')), '1. e4');
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pgn-field')), findsNothing,
          reason: 'the case needs the phone layout, which has no PGN tab');

      await play(tester, 'f4', 'e3');
      expect(find.textContaining('starts part 2'), findsOneWidget);
      await close(tester);
    });
  });
}
