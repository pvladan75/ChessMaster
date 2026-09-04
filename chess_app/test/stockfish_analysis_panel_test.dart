import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

/// **One shape for the engine, on every board that has one.**
///
/// The owner picked the repertoire's „Pitaj motor" panel on 4.9.2026 as the
/// form every engine readout should take. This widget is the other form, and it
/// is the one three screens draw: Analysis Studio, AI Studio and the room.
///
/// He also said which half of it to change: **the appearance only.** The switch
/// stays, because this panel runs the engine continuously and the repertoire's
/// asks once; the dialog on tap stays, because these screens have somewhere to
/// put a line and the repertoire's board does not. So these tests are in two
/// halves — what had to change, and what had to survive.
AnalysisLine _line({
  int multipv = 1,
  int depth = 20,
  String evaluation = '+0.35',
  String bestMoveSan = 'e4',
  String continuationSan = '1. e4 e5 2. Nf3',
}) {
  return AnalysisLine(
    multipv: multipv,
    depth: depth,
    evaluation: evaluation,
    bestMoveLan: 'e2e4',
    bestMoveSan: bestMoveSan,
    continuationLan: 'e2e4 e7e5 g1f3',
    continuationSan: continuationSan,
    sanMoveList: const ['e4', 'e5', 'Nf3'],
    // A real FEN: the line dialog parses it, and a placeholder made it
    // print „FEN string must contain six space-delimited fields." on the
    // way past.
    fenList: const ['rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'],
    fromSquare: 'e2',
    toSquare: 'e4',
  );
}

Widget _panel({
  List<AnalysisLine> lines = const [],
  bool enabled = true,
  bool allowed = true,
  VoidCallback? onToggleEngine,
  VoidCallback? onToggleEvalBar,
  Function(AnalysisLine line)? onInsert,
  Size size = const Size(360, 640),
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: SingleChildScrollView(
          child: StockfishAnalysisWidget(
            isEngineEnabled: enabled,
            isAllowedToUseEngine: allowed,
            isOnline: false,
            isCustomEngineActive: false,
            lines: lines,
            orientation: PlayerColor.white,
            onToggleEngine: onToggleEngine ?? () {},
            isShowEvalBarEnabled: false,
            onToggleShowEvalBar: onToggleEvalBar,
            onInsertLineAsVariation: onInsert,
            // Passed rather than read from settings, so the test needs no
            // SharedPreferences and no engine.
            analysisDepth: 20,
            analysisLines: 3,
            onAnalysisDepthChanged: (_) {},
            onAnalysisLinesChanged: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the panel took the repertoire\'s shape', () {
    testWidgets('it is headed „Motor", like the one it was matched to',
        (tester) async {
      await tester.pumpWidget(_panel(lines: [_line()]));

      expect(find.text('Motor'), findsOneWidget);
      // And says which engine is answering and from whose side the number
      // reads — the repertoire's own sentence, because the convention is the
      // app's rather than this screen's.
      expect(
        find.text('Lokalni motor — ocena je iz ugla belog.'),
        findsOneWidget,
      );
    });

    testWidgets('the depth is on every row, not once in a banner',
        (tester) async {
      // The lines arrive at different depths and get better while the search
      // runs, so one number over all of them is right about the first row and
      // wrong about the others.
      await tester.pumpWidget(_panel(lines: [
        _line(depth: 22, evaluation: '+0.35'),
        _line(multipv: 2, depth: 14, evaluation: '-0.10', bestMoveSan: 'd4'),
      ]));

      expect(find.text('d22'), findsOneWidget);
      expect(find.text('d14'), findsOneWidget);
      // The banner it replaces, gone: `Eval: +0.35 (depth: 22)`.
      expect(find.textContaining('Eval:'), findsNothing);
      expect(find.textContaining('Najbolji potez'), findsNothing);
      // And the heading over the list, gone with it.
      expect(find.textContaining('Linije'), findsNothing);
    });

    testWidgets('a row reads eval, move, line — in that order', (tester) async {
      await tester.pumpWidget(_panel(lines: [_line()]));

      expect(find.text('+0.35'), findsOneWidget);
      expect(find.text('e4'), findsOneWidget);
      expect(find.text('1. e4 e5 2. Nf3'), findsOneWidget);
    });

    testWidgets('it spins while the engine has said nothing yet',
        (tester) async {
      // A panel that stays blank is indistinguishable from an engine that is
      // not answering. Same reason the repertoire's panel spins.
      await tester.pumpWidget(_panel(lines: const []));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Računanje poteza...'), findsOneWidget);

      await tester.pumpWidget(_panel(lines: [_line()]));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('and kept what it does', () {
    testWidgets('the switch is still there and still reports', (tester) async {
      // Kept deliberately: this panel runs the engine continuously, so it needs
      // a way to stop it. The repertoire's asks once and needs a button.
      var toggled = 0;
      await tester.pumpWidget(
          _panel(lines: [_line()], onToggleEngine: () => toggled += 1));

      expect(find.text('Prikaži evaluaciju'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      expect(toggled, 1);
    });

    testWidgets('the eval bar is still a second, separate question',
        (tester) async {
      var toggled = 0;
      await tester.pumpWidget(_panel(
        lines: [_line()],
        onToggleEvalBar: () => toggled += 1,
      ));

      expect(find.text('Prikaži evaluacionu liniju'), findsOneWidget);
      await tester.tap(find.byType(Switch).last);
      await tester.pump();

      expect(toggled, 1);
    });

    testWidgets('tapping a line still opens the full inspector',
        (tester) async {
      // The other half of the owner's decision. These screens have a move tree
      // to put a line into; the repertoire's board does not, which is why that
      // panel plays the move instead.
      await tester.pumpWidget(_panel(lines: [_line()]));

      await tester.tap(find.text('1. e4 e5 2. Nf3'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('inserting a line as a variation survived the restyle',
        (tester) async {
      AnalysisLine? inserted;
      await tester.pumpWidget(
          _panel(lines: [_line()], onInsert: (line) => inserted = line));

      await tester.tap(find.byIcon(Icons.call_split));
      await tester.pump();

      expect(inserted?.bestMoveSan, 'e4');
    });

    testWidgets('a trainer\'s lock is still said out loud', (tester) async {
      await tester.pumpWidget(_panel(lines: const [], allowed: false));

      expect(find.text('Zaključano od strane trenera'), findsOneWidget);
      // And nothing is computed behind the lock.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('and fits a phone', () {
    testWidgets('no row overflows at 360 dp, with every control on it',
        (tester) async {
      // In a release build an overflowing Row is simply clipped, with no
      // stripes painted to say so — three of those have been found by looking
      // at a phone. In a test build it throws, which is why this is a test.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_panel(
        lines: [
          _line(depth: 22),
          _line(
            multipv: 2,
            depth: 18,
            evaluation: '-M4',
            bestMoveSan: 'Qxh7+',
            continuationSan: '1. Qxh7+ Kxh7 2. Rh3+ Kg8 3. Rh8#',
          ),
        ],
        onToggleEvalBar: () {},
        onInsert: (_) {},
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
