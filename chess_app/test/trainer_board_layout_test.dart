import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
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

  // ── what phase 1 of docs/PLAN-EKRANI.md added for the puzzle screen ────

  group('the panel, extended', () {
    testWidgets(
        'a task with no spoken line is words alone: no speaker beside it',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: TrainerInfoPanel(taskText: 'White to move. Deliver mate.')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('White to move. Deliver mate.'), findsOneWidget);
      expect(find.byTooltip('Enable reading aloud'), findsNothing);
      expect(find.byTooltip('Read aloud'), findsNothing);

      // And with a line it is the speaker's, as it always was.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: TrainerInfoPanel(
                task: SpokenLine([SpeechVocabulary.goForward]),
                autoSpeak: false)),
      ));
      await tester.pumpAndSettle();
      expect(
          find.byWidgetPredicate((w) =>
              w is Tooltip &&
              (w.message == 'Enable reading aloud' ||
                  w.message == 'Read aloud')),
          findsOneWidget);
    });

    testWidgets(
        'the verdict as drawn text, its shape, and the children after it '
        'in that order', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TrainerInfoPanel(
            taskText: 'Task',
            taskLeading: Icon(Icons.circle_outlined, key: Key('side')),
            messageText: ['Said once', 'And a rating'],
            messageIcon: Icons.check_circle,
            messageIsGood: true,
            children: [Text('the solution')],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      final said = tester.getTopLeft(find.text('Said once'));
      final rating = tester.getTopLeft(find.text('And a rating'));
      final child = tester.getTopLeft(find.text('the solution'));
      expect(rating.dy, greaterThan(said.dy));
      expect(child.dy, greaterThan(rating.dy), reason: 'under the message');
      // The side's icon stands level with the task, to its left.
      expect(tester.getTopLeft(find.byKey(const Key('side'))).dx,
          lessThan(tester.getTopLeft(find.text('Task')).dx));
    });

    testWidgets('a panel with none of it draws what it drew: no icon, no row',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TrainerInfoPanel(
            task: SpokenLine([SpeechVocabulary.goForward]),
            message: [
              SpokenLine([SpeechVocabulary.correct])
            ],
            autoSpeak: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Icon), findsOneWidget, reason: 'the speaker only');
    });
  });

  group('TrainerScreenLayout chooses by the window, once', () {
    Future<void> pump(WidgetTester tester, Size size,
        {double scale = 1.0}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TrainerScreenLayout(
            scale: scale,
            board: (side) =>
                SizedBox(key: _boardKey, width: side, height: side),
            panel: const SizedBox(key: Key('panel'), height: 40),
            asidePanel: const SizedBox(key: Key('aside'), height: 40),
            extras: const SizedBox(key: Key('extras'), height: 40),
            controls: const SizedBox(key: Key('controls'), height: 40),
            strip: const SizedBox(key: Key('strip'), height: 40),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a window: the aside beside the board, never the phone\'s',
        (tester) async {
      // Wider than tall, and not a phone: 900 x 700 is the layout of a
      // window, which the puzzle screen used to give the phone's landscape.
      await pump(tester, const Size(900, 700));
      expect(find.byType(TrainerBoardLayout), findsOneWidget);
      expect(find.byType(LandscapeBoardLayout), findsNothing);
      expect(find.byKey(const Key('aside')), findsOneWidget);
      expect(find.byKey(const Key('panel')), findsNothing);
      expect(find.byKey(const Key('extras')), findsNothing);
      expect(tester.getTopLeft(find.byKey(const Key('aside'))).dx,
          greaterThan(tester.getRect(find.byKey(_boardKey)).right - 1));
      // The strip and the buttons are under the board, in that order.
      expect(tester.getTopLeft(find.byKey(const Key('strip'))).dy,
          greaterThan(tester.getRect(find.byKey(_boardKey)).bottom));
      expect(tester.getTopLeft(find.byKey(const Key('controls'))).dy,
          greaterThan(tester.getTopLeft(find.byKey(const Key('strip'))).dy));
    });

    // Rewritten 3.10.2026 on the owner's word: on a phone held upright the
    // buttons come right under the board (and its strip), before the panel —
    // until then the panel came first and the main button was a scroll away
    // on every board screen. What the old case protected, that the panel and
    // the extras are under the board and in a fixed order, it still does.
    testWidgets(
        'a phone upright: the strip and the buttons right under the board, '
        'then the panel, then the extras', (tester) async {
      await pump(tester, const Size(360, 640));
      expect(find.byType(LandscapeBoardLayout), findsNothing);
      final ys = [
        for (final k in ['strip', 'controls', 'panel', 'extras'])
          tester.getTopLeft(find.byKey(Key(k))).dy
      ];
      expect(find.byKey(const Key('aside')), findsNothing);
      expect(ys[0], greaterThan(tester.getRect(find.byKey(_boardKey)).bottom));
      expect(ys[1], greaterThan(ys[0]));
      expect(ys[2], greaterThan(ys[1]));
      expect(ys[3], greaterThan(ys[2]));
    });

    testWidgets(
        'a phone on its side: the layout of its own, the aside in its '
        'column', (tester) async {
      await pump(tester, const Size(800, 360));
      expect(find.byType(LandscapeBoardLayout), findsOneWidget);
      expect(find.byType(TrainerBoardLayout), findsNothing);
      expect(find.byKey(const Key('aside')), findsOneWidget);
      expect(find.byKey(const Key('extras')), findsNothing);
      expect(find.byKey(const Key('controls')), findsOneWidget);
    });

    testWidgets('the board size setting only ever shrinks the board',
        (tester) async {
      await pump(tester, const Size(900, 700));
      final full = tester.getSize(find.byKey(_boardKey)).width;
      await pump(tester, const Size(900, 700), scale: 0.6);
      expect(tester.getSize(find.byKey(_boardKey)).width,
          closeTo(full * 0.6, 0.01));
    });
  });
}
