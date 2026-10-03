import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';

const _boardKey = Key('board');

Widget harness({required double width, required double height}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => LayoutBuilder(
            builder: (context, constraints) => TrainerBoardLayout(
              wide: Breakpoints.isWide(context),
              constraints: constraints,
              panel: TrainerInfoPanel(
                task: SpokenLine([
                  SpeechVocabulary.whiteToMove,
                  SpeechVocabulary.holdTheDraw
                ]),
                detail: SpokenLine([SpeechVocabulary.playMoveHoldsDraw]),
                chips: const ['KRPvKR', 'Difficulty: 6/10'],
                message: [
                  SpokenLine([SpeechVocabulary.correctDrawHeld])
                ],
                messageIsGood: true,
              ),
              reserveHeight: 200,
              builder: (boardSize) => Column(
                children: [
                  SizedBox(
                    key: _boardKey,
                    width: boardSize,
                    height: boardSize,
                    child: const ColoredBox(color: Colors.brown),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('on a wide window the panel stands to the right of the board',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(width: 1200, height: 900));
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(_boardKey));
    final panel = tester.getRect(find.byType(TrainerInfoPanel));

    // Beside, not above or below: the whole point is that the board and what
    // is being said about it are in view together.
    expect(panel.left, greaterThan(board.right - 1));
    expect(panel.top, lessThan(board.bottom));
    // And close to it. The first version let the board column swallow every
    // spare pixel and centred a capped board inside it, which parked the panel
    // at the far edge of a wide monitor with empty board between the two things
    // you have to read together.
    expect(panel.left - board.right, lessThan(40));
  });

  testWidgets('on a phone the layout hands the whole width to the board',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(width: 360, height: 800));
    await tester.pumpAndSettle();

    // Narrow means the layout renders the board column alone; the screen puts
    // the panel under it, which is why there is none in the tree here.
    expect(tester.takeException(), isNull);
    expect(find.byType(TrainerInfoPanel), findsNothing);
    expect(tester.getSize(find.byKey(_boardKey)).width, 360 - 24);
    // Square, and bounded by the tighter axis either way.
    expect(tester.getSize(find.byKey(_boardKey)).height, 360 - 24);
  });

  testWidgets(
      'the panel draws the lines it was given, and none of the empty ones',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Phase 4b: the panel takes `SpokenLine`s and draws each line's text, the
    // first letter a capital and one full stop where the line has two.
    final task = SpokenLine([
      SpeechVocabulary.playedHere('black'),
      SpeechVocabulary.piece('rook'),
      SpeechVocabulary.square('d3'),
      SpeechVocabulary.hereLostDraw,
    ]);
    Future<int> boxes({List<SpokenLine> message = const []}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TrainerInfoPanel(
            task: task,
            chips: const ['KRPPvKR'],
            message: message,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return find.byType(Container).evaluate().length;
    }

    final bare = await boxes();
    expect(find.text('Black played rook d3 here and lost the draw.'),
        findsOneWidget);
    expect(find.text('KRPPvKR'), findsOneWidget);

    // A panel with nothing to report shows no empty box where the verdict
    // goes: with a verdict there is exactly one more.
    final withVerdict = await boxes(message: [
      SpokenLine([SpeechVocabulary.correct])
    ]);
    expect(withVerdict, bare + 1);
    expect(find.text('Correct.'), findsOneWidget);
  });

  testWidgets(
      'a line that begins with a move is drawn with a capital and one '
      'full stop', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TrainerInfoPanel(
          task: SpokenLine([SpeechVocabulary.goForward]),
          message: [
            SpokenLine([
              SpeechVocabulary.piece('king'),
              SpeechVocabulary.square('d5'),
              SpeechVocabulary.losesDrawDrillStops,
            ])
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('King d5 loses the draw. The drill stops here.'),
        findsOneWidget);
  });
}
