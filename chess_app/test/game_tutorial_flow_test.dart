// Phase 4 of `docs/PLAN-SKELET.md`: the door, from a game to a tutorial open in
// the studio — at 360 × 640, with the run faked.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/features/tutorial_studio/widgets/game_tutorial_flow.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/app_slider.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final _fixture = jsonDecode(
    File('test/fixtures/game_tutorial/g01_scandinavian-defense.json')
        .readAsStringSync()) as Map<String, dynamic>;

GameTutorialResult _result({String? mastersNote}) {
  final expected = _fixture['expected'] as Map<String, dynamic>;
  return GameTutorialResult(
    // As the real run hands them over: without the question parts the
    // skeleton still makes until phase 5 of docs/PLAN-TUTORIJAL-VIDEO.md.
    keyMoments: readTutorialJson(jsonEncode(
        withoutQuestions(expected['tutorial'] as Map<String, dynamic>))),
    wholeGame: readTutorialJson(jsonEncode(
        withoutQuestions(expected['tutorialGame'] as Map<String, dynamic>))),
    report: const {
      'claims': ['m1.question names its answer or its square'],
      'missing_slots': <String>[],
    },
    momentsOffered: 6,
    mastersNote: mastersNote,
  );
}

/// The run, driven by the test: [steps] are sent as progress, then [finish]
/// decides the outcome.
class _Runner implements GameTutorialRunner {
  _Runner(
      {this.steps = const [], this.hold, required this.finish, this.askSlice});

  final List<GameTutorialProgress> steps;
  final Completer<void>? hold;
  final Object Function(bool cancelled) finish;

  /// Facts to ask the slice question about; null means do not ask.
  final Map<String, dynamic>? askSlice;
  bool cancelled = false;
  int? depthAsked;
  String? fenAsked;
  List<String>? movesAsked;
  SkeletonParameters? sliceChosen;

  @override
  void cancel() => cancelled = true;

  @override
  Future<GameTutorialResult> run({
    required String gameName,
    required String startFen,
    required List<String> uciMoves,
    required int depth,
    SkeletonParameters parameters = const SkeletonParameters(),
    Future<SkeletonParameters?> Function(GameTutorialSlice slice)? chooseSlice,
    void Function(GameTutorialProgress progress)? onProgress,
  }) async {
    depthAsked = depth;
    fenAsked = startFen;
    movesAsked = uciMoves;
    for (final s in steps) {
      onProgress?.call(s);
    }
    if (chooseSlice != null && askSlice != null) {
      sliceChosen = await chooseSlice(
          GameTutorialSlice(facts: askSlice!, parameters: parameters));
      if (sliceChosen == null) {
        throw const GameTutorialStopped(
            'cancelled', 'Cancelled. Nothing was spent.');
      }
    }
    if (hold != null) await hold!.future;
    final outcome = finish(cancelled);
    if (outcome is GameTutorialStopped) throw outcome;
    return outcome as GameTutorialResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _session = UserSession(
    token: 'jwt',
    id: 1,
    email: 'trainer@example.com',
    name: 'Trainer',
    role: 'trener');

/// Enough of a game's facts for the slice question: two moves that cost a pawn
/// or more, which is the least a tutorial is made of.
final Map<String, dynamic> _facts = {
  'rows': [
    for (final cost in [2.0, 1.4])
      {
        'fen': _start,
        'played': {'move': 'e4', 'cost_pawns': cost},
        'candidates': [
          {'move': 'd4'}
        ],
      },
  ],
};

Future<void> _pump(
  WidgetTester tester, {
  required _Runner runner,
  String startFen = _start,
  List<String> moves = const ['e2e4', 'e7e5', 'g1f3'],
  void Function(AnalysisNode root)? graft,
  List<ImportedTutorial>? opened,
  VoidCallback? onOpenEngineSettings,
  Future<SkeletonParameters?> Function(
          BuildContext context, GameTutorialSlice slice)?
      chooseSlice,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final root = analysisTreeFromMoves(startFen, moves).root;
  graft?.call(root);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const Key('door'),
            onPressed: () => makeTutorialFromGame(
              context,
              session: _session,
              root: root,
              gameName: 'test game',
              chooseSlice: chooseSlice,
              runnerFor: () => runner,
              onOpenEngineSettings: onOpenEngineSettings,
              openInStudio: (context, tutorial) async => opened?.add(tutorial),
            ),
            child: const Text('Make a tutorial from this game'),
          ),
        ),
      ),
    ),
  ));
}

Future<void> _startAt(WidgetTester tester, {int? depth}) async {
  await tester.tap(find.byKey(const Key('door')));
  await tester.pumpAndSettle();
  if (depth != null) {
    tester
        .widget<AppSlider>(find.byKey(const Key('game-tutorial-depth')))
        .onChanged!(depth.toDouble());
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(const Key('game-tutorial-start')));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the depth is chosen with its time, and remembered',
      (tester) async {
    SharedPreferences.setMockInitialValues({kGameTutorialDepthPreference: 20});
    final runner = _Runner(finish: (_) => _result());
    await _pump(tester, runner: runner, opened: []);

    await tester.tap(find.byKey(const Key('door')));
    await tester.pumpAndSettle();
    // Remembered from last time: 20 is preselected, with its measured time.
    expect(find.text('Depth 20'), findsOneWidget);
    expect(find.text(gameTutorialDepthTime(20)), findsOneWidget);
    await tester.tap(find.byKey(const Key('game-tutorial-start')));
    await tester.pumpAndSettle();
    expect(runner.depthAsked, 20);
    expect(tester.takeException(), isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(kGameTutorialDepthPreference), 20);
  });

  // The owner, 17.9.2026: every depth up to 50 wherever a depth is chosen.
  // Dragged, not set: the track itself has to reach the end.
  testWidgets('the depth slider runs from 18 to 50, and says 50 is not timed',
      (tester) async {
    final runner = _Runner(finish: (_) => _result());
    await _pump(tester, runner: runner, opened: []);

    await tester.tap(find.byKey(const Key('door')));
    await tester.pumpAndSettle();
    // It opens at 20 since phase 1b of docs/PLAN-ZAGONETKE-IZ-PARTIJE.md — the
    // depth the mistake rule's floor was measured at; 18 until then.
    expect(find.text('Depth 20'), findsOneWidget);

    final slider = find.byKey(const Key('game-tutorial-depth'));
    await tester.drag(slider, const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(find.text('Depth 50'), findsOneWidget);
    expect(find.text(gameTutorialDepthTime(50)), findsOneWidget);
    expect(gameTutorialDepthTime(50), contains('not measured'));

    await tester.drag(slider, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(find.text('Depth 18'), findsOneWidget, reason: 'nothing below 18');

    await tester.drag(slider, const Offset(2000, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('game-tutorial-start')));
    await tester.pumpAndSettle();
    expect(runner.depthAsked, 50);
  });

  // **What the door sends, when the board is not a game from move one.** The
  // owner asked on 15.9.2026 whether a sequence of moves — a study, a position
  // with a line on it — can be made into a tutorial the way a whole game can.
  // It can, and this is what says so: the position the tree stands on travels
  // as the start, and the moves are that tree's main line. What does **not**
  // travel is in the second half of this test: a sideline is not sent, so a
  // study's branches are not part of what the engine is asked about.
  testWidgets('a study position and its main line are what the run is given',
      (tester) async {
    const study = '4k3/8/8/8/8/8/4P3/4K3 w - - 0 1';
    final runner = _Runner(finish: (_) => _result());
    await _pump(
      tester,
      runner: runner,
      startFen: study,
      moves: const ['e2e4', 'e8d7', 'e4e5'],
      // A second line off the root, as a study written in Analysis carries.
      graft: (root) => root.children.add(AnalysisNode(
          fen: '4k3/8/8/8/8/4K3/4P3/8 b - - 1 1',
          moveSan: 'Ke1-e3',
          moveUci: 'e1e3',
          parent: root)),
      opened: [],
    );
    await _startAt(tester, depth: 18);
    await tester.pumpAndSettle();

    expect(runner.fenAsked, study);
    expect(runner.movesAsked, ['e2e4', 'e8d7', 'e4e5']);
  });

  testWidgets('a new depth is kept for next time', (tester) async {
    final runner = _Runner(finish: (_) => _result());
    await _pump(tester, runner: runner, opened: []);
    await _startAt(tester, depth: 22);
    await tester.pumpAndSettle();
    expect(runner.depthAsked, 22);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(kGameTutorialDepthPreference), 22);
  });

  testWidgets(
      'progress says what it is doing and how long is left, then the choice opens the tutorial',
      (tester) async {
    final hold = Completer<void>();
    final runner = _Runner(
      steps: const [
        GameTutorialProgress(GameTutorialStage.engine),
        GameTutorialProgress(GameTutorialStage.analysis,
            done: 20, total: 63, secondsLeft: 125),
      ],
      hold: hold,
      finish: (_) => _result(
          mastersNote: 'The masters database could not be asked (network).'),
    );
    final opened = <ImportedTutorial>[];
    await _pump(tester, runner: runner, opened: opened);
    await _startAt(tester);

    expect(find.text('The engine is searching every position of the game.'),
        findsOneWidget);
    expect(
        find.text('20 of 63 positions · about 3 minutes left'), findsOneWidget);
    expect(runner.movesAsked, ['e2e4', 'e7e5', 'g1f3']);
    expect(tester.takeException(), isNull);

    hold.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-tutorial-key-moments')), findsOneWidget);
    expect(find.byKey(const Key('game-tutorial-to-check')), findsOneWidget);
    expect(find.textContaining('could not be asked'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final whole = find.byKey(const Key('game-tutorial-whole-game'));
    await tester.ensureVisible(whole);
    await tester.tap(whole);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(
        opened.single.partCount,
        ((_fixture['expected'] as Map)['tutorialGame']['positionList'] as List)
            .where((s) => (s as Map)['kind'] == 'show')
            .length);
  });

  // The owner, 14.9.2026: a tutorial made for a film asks nothing — a
  // question in a video is a board waiting for an answer nobody can give.
  testWidgets(
      'a tutorial from a game has no question parts, and says how many '
      'parts that leaves', (tester) async {
    final opened = <ImportedTutorial>[];
    await _pump(tester,
        runner: _Runner(finish: (_) => _result()), opened: opened);
    await _startAt(tester);
    await tester.pumpAndSettle();

    final expected =
        ((_fixture['expected'] as Map)['tutorialGame']['positionList'] as List)
            .cast<Map>();
    final shows = expected.where((s) => s['kind'] == 'show').length;
    expect(shows, lessThan(expected.length),
        reason: 'the fixture must ask something, or this test cannot tell');
    // Every part shows (docs/PLAN-TUTORIJAL-VIDEO.md, phase 4): there is no
    // „For students" / „For a video" to choose between any more.
    expect(find.byKey(const Key('game-tutorial-for-video')), findsNothing);
    expect(find.byKey(const Key('game-tutorial-for-students')), findsNothing);
    expect(find.textContaining('$shows parts —'), findsOneWidget);
    expect(find.textContaining('${expected.length} parts —'), findsNothing);

    final whole = find.byKey(const Key('game-tutorial-whole-game'));
    await tester.ensureVisible(whole);
    await tester.tap(whole);
    await tester.pumpAndSettle();

    expect(opened.single.partCount, shows);
    expect(opened.single.positionList.map((s) => s['kind']).toSet(), {'show'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('no engine says so, and its button goes to the engine settings',
      (tester) async {
    var settingsOpened = 0;
    final runner = _Runner(
      finish: (_) => const GameTutorialStopped(
          'no-engine', 'Making a tutorial needs the chess engine.',
          offerEngineDownload: true),
    );
    await _pump(tester,
        runner: runner, onOpenEngineSettings: () => settingsOpened++);
    await _startAt(tester);
    await tester.pumpAndSettle();

    expect(
        find.text('Making a tutorial needs the chess engine.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('game-tutorial-engine-settings')));
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);
    expect(tester.takeException(), isNull);
  });

  // Point 6 of the owner's live pass, 14.9.2026. The runner asks a question
  // between the engine and the words; these say the screen answers it, which
  // no test of the runner or of the dialog on its own can say.
  testWidgets('the count is put to the trainer, and their answer is used',
      (tester) async {
    final opened = <ImportedTutorial>[];
    SkeletonParameters? asked;
    final runner = _Runner(
      askSlice: _facts,
      finish: (_) => _result(),
    );
    await _pump(
      tester,
      runner: runner,
      opened: opened,
      chooseSlice: (context, slice) async {
        asked = slice.parameters;
        // No threshold since phase 1b: what the trainer can hand back is
        // the parameters themselves, here with another cap.
        return const SkeletonParameters(maxMoments: 5);
      },
    );
    await tester.tap(find.byKey(const Key('door')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('game-tutorial-start')));
    await tester.pumpAndSettle();

    expect(asked, isNotNull, reason: 'the screen is asked');
    expect(runner.sliceChosen?.maxMoments, 5,
        reason: 'and the answer goes back to the run');

    // The run carried on to the end, which says the question is a step in the
    // flow and not a dead end.
    await tester.tap(find.byKey(const Key('game-tutorial-whole-game')));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
  });

  testWidgets('stopping at the count opens nothing', (tester) async {
    final opened = <ImportedTutorial>[];
    final runner = _Runner(askSlice: _facts, finish: (_) => _result());
    await _pump(
      tester,
      runner: runner,
      opened: opened,
      chooseSlice: (context, slice) async => null,
    );
    await tester.tap(find.byKey(const Key('door')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('game-tutorial-start')));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
  });

  testWidgets('cancel stops the run and says so, and nothing opens',
      (tester) async {
    final hold = Completer<void>();
    final runner = _Runner(
      steps: const [
        GameTutorialProgress(GameTutorialStage.analysis, done: 3, total: 63),
      ],
      hold: hold,
      finish: (cancelled) => cancelled
          ? const GameTutorialStopped(
              'cancelled', 'Cancelled. Kept for next time.')
          : _result(),
    );
    final opened = <ImportedTutorial>[];
    await _pump(tester, runner: runner, opened: opened);
    await _startAt(tester);

    await tester.tap(find.byKey(const Key('game-tutorial-cancel')));
    await tester.pump();
    expect(runner.cancelled, isTrue);
    expect(find.text('Cancelling…'), findsOneWidget);
    hold.complete();
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.text('Cancelled. Kept for next time.'), findsOneWidget);
    expect(find.text('No tutorial was made'), findsNothing,
        reason: 'a cancel is a short message, not a refusal');
  });

  testWidgets('under a minute left is said as such', (tester) async {
    final hold = Completer<void>();
    final runner = _Runner(
      steps: const [
        GameTutorialProgress(GameTutorialStage.analysis,
            done: 60, total: 63, secondsLeft: 30),
      ],
      hold: hold,
      finish: (_) => _result(),
    );
    await _pump(tester, runner: runner, opened: []);
    await _startAt(tester);
    expect(
        find.text('60 of 63 positions · under a minute left'), findsOneWidget);
    hold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('while the words are written, cancel is not offered',
      (tester) async {
    final hold = Completer<void>();
    final runner = _Runner(
      steps: const [GameTutorialProgress(GameTutorialStage.words)],
      hold: hold,
      finish: (_) => _result(),
    );
    await _pump(tester, runner: runner, opened: []);
    await _startAt(tester);

    final cancel = tester
        .widget<TextButton>(find.byKey(const Key('game-tutorial-cancel')));
    expect(cancel.onPressed, isNull);
    expect(find.textContaining('cannot be cancelled'), findsOneWidget);
    hold.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a position with no moves asks for a game first', (tester) async {
    final runner = _Runner(finish: (_) => _result());
    await _pump(tester, runner: runner, moves: const [], opened: []);
    await tester.tap(find.byKey(const Key('door')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('game-tutorial-start')), findsNothing);
    expect(find.textContaining('no moves to make a tutorial from'),
        findsOneWidget);
    expect(runner.depthAsked, isNull);
  });
}
