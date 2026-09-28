// „Study this position" — docs/PLAN-STUDIJA-POZICIJE.md: the dialog that took
// Auto Analysis's place. What a reader is asked, what they are told while the
// engine works, and what they are told at the end — on a phone and in a
// window.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/position_study.dart';
import 'package:chess_app/features/analysis_studio/widgets/position_study_dialog.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart';
import 'support/recorded_engine.dart';

const _phone = Size(360, 640);
const _window = Size(1280, 800);

class _Popped extends NavigatorObserver {
  final List<String> events;
  _Popped(this.events);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    events.add('popped');
  }
}

class _Harness {
  _Harness(this.engine);

  final RecordedEngine engine;
  late final AnalysisNode start = AnalysisNode(fen: engine.fen);
  final List<String> events = [];
  final List<StudyResult> completed = [];
  final List<Map<String, dynamic>> asked = [];

  /// What the server answers; null answers every slot.
  StudyWordsOutcome? outcome;

  /// Held until completed, when set: the engine's first answer waits on it.
  Completer<void>? gate;

  Future<List<AnalysisLine>> analyzer(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    events.add('search');
    final held = gate;
    if (held != null) await held.future;
    return engine.analyzer(fen, depth: depth, multiPV: multiPV);
  }

  Future<StudyWordsOutcome> ask(Map<String, dynamic> request,
      {required bool comment}) async {
    asked.add(request);
    events.add('asked');
    return outcome ??
        StudyWordsOutcome.written({
          for (final item in request['items'] as List)
            for (final slot in (item as Map)['slots'] as List)
              (slot as Map)['id'] as String: 'Words for ${slot['id']}.',
        });
  }

  Future<void> open(
    WidgetTester tester,
    Size size, {
    bool words = true,
    bool tutorial = true,
    AnalysisNode? node,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      navigatorObservers: [_Popped(events)],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => PositionStudyDialog(
                startNode: node ?? start,
                analyzer: analyzer,
                ask: words ? ask : null,
                noWordsReason:
                    words ? null : 'Sign in to have comments written.',
                onHold: () => events.add('hold'),
                onRelease: () => events.add('release'),
                onCompleted: (result) {
                  events.add('completed');
                  completed.add(result);
                },
                onOpenAsTutorial:
                    tutorial ? () => events.add('tutorial') : null,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    events.clear();
  }
}

Future<void> _run(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('study-start')));
  // The engine's answers are read from a file and the futures between them
  // are microtasks: a few frames see the whole study through.
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  // Real glyphs: text drawn as squares is wider than the words it stands for.
  setUpAll(loadRoboto);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  for (final size in [_phone, _window]) {
    final where = size == _phone ? 'on a phone' : 'in a window';

    testWidgets('what is asked, $where: one tick, one dial, one button',
        (tester) async {
      final h = _Harness(RecordedEngine.read('owner2'));
      await h.open(tester, size);
      expect(tester.takeException(), isNull);

      final dialog = find.byType(PositionStudyDialog);
      Finder inDialog(Finder f) => find.descendant(of: dialog, matching: f);
      expect(inDialog(find.text('Study this position')), findsOneWidget);
      expect(inDialog(find.text('Write comments with AI')), findsOneWidget);
      expect(inDialog(find.text('Engine depth: 20')), findsOneWidget);
      expect(inDialog(find.text('Start')), findsOneWidget);
      expect(
          tester
              .widget<CheckboxListTile>(inDialog(find.byType(CheckboxListTile)))
              .value,
          isTrue);

      // Nothing the old dialog asked: no plies, no candidates, no cutoff.
      expect(inDialog(find.textContaining('plies')), findsNothing);
      expect(inDialog(find.textContaining('Candidate')), findsNothing);
      expect(inDialog(find.textContaining('Cutoff')), findsNothing);

      // Whole on the screen, and inside it.
      final box = tester.getRect(find.byType(Dialog));
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(size.width));
      final button = tester.getRect(find.byKey(const ValueKey('study-start')));
      expect(button.bottom, lessThanOrEqualTo(size.height));
      expect(h.events, isEmpty, reason: 'nothing starts by itself');
    });

    testWidgets(
        'the end, $where: the study is in the tree before it is '
        'said to be', (tester) async {
      final h = _Harness(RecordedEngine.read('owner2'));
      await h.open(tester, size);
      await _run(tester);
      expect(tester.takeException(), isNull);
      expect(h.engine.unanswered, isEmpty);

      expect(find.text('The study is in the tree.'), findsOneWidget);
      expect(find.textContaining('The main line starts with 8. dxc6.'),
          findsOneWidget);
      expect(find.textContaining('11 comments written'), findsOneWidget);
      expect(h.completed, hasLength(1));
      expect(h.start.children.first.moveSan, 'dxc6');
      expect(h.start.comment, 'Words for s.position.');

      // Held before the first search, released after the last; asked once,
      // after the engine.
      expect(h.events.first, 'hold');
      expect(h.events.last, 'release');
      expect(h.events.where((e) => e == 'asked'), hasLength(1));
      expect(h.events.indexOf('asked'),
          greaterThan(h.events.lastIndexOf('search')));
      expect(h.events.indexOf('completed'),
          greaterThan(h.events.indexOf('asked')));

      final open =
          tester.getRect(find.byKey(const ValueKey('study-open-as-tutorial')));
      expect(open.right, lessThanOrEqualTo(size.width));
      expect(open.bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('with nobody signed in the tick is off, and says why',
      (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'));
    await h.open(tester, _phone, words: false);
    final tick = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(tick.value, isFalse);
    expect(tick.onChanged, isNull);
    expect(find.text('Sign in to have comments written.'), findsOneWidget);

    await _run(tester);
    expect(h.asked, isEmpty);
    expect(find.text('The study is in the tree.'), findsOneWidget);
    expect(find.textContaining('comments written'), findsNothing);
    expect(h.start.children, isNotEmpty);
  });

  testWidgets('the tick taken off: the lines, and nothing asked',
      (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'));
    await h.open(tester, _window);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    await _run(tester);
    expect(h.asked, isEmpty);
    expect(h.start.children, isNotEmpty);
    expect(h.start.comment, isEmpty);
  });

  testWidgets('a refusal is said in its own words, and the lines are kept',
      (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'))
      ..outcome = const StudyWordsOutcome.refused(WordsRefusal('quota-spent',
          'You have used all the AI comments your plan includes this month.'));
    await h.open(tester, _phone);
    await _run(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.text('No comments were written: You have used all the AI '
          'comments your plan includes this month.'),
      findsOneWidget,
    );
    expect(h.start.children.first.moveSan, 'dxc6');
    expect(h.completed.single.refusal?.reason, 'quota-spent');
  });

  testWidgets('sentences the analysis did not bear out are counted',
      (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'))
      ..outcome = const StudyWordsOutcome.written({
        's.position': 'White is a pawn up.',
        'w1.capture': 'Taking the rook loses to Qh5.',
      });
    await h.open(tester, _window);
    await _run(tester);
    expect(find.textContaining('1 comment written'), findsOneWidget);
    expect(find.textContaining('1 comment left out: what the model wrote'),
        findsOneWidget);
    expect(h.completed.single.offered, 11);
    expect(h.completed.single.answered, 2);
  });

  testWidgets(
      'a position that cannot be studied is said, and nothing is '
      'added', (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'));
    final stalemate = AnalysisNode(fen: '7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
    await h.open(tester, _phone, node: stalemate);
    await _run(tester);
    expect(find.text('The game is over in this position.'), findsOneWidget);
    expect(find.text('Nothing was added to the tree.'), findsOneWidget);
    expect(h.completed, isEmpty);
    expect(stalemate.children, isEmpty);
    expect(h.events, ['hold', 'release']);
  });

  testWidgets(
      'cancelled while the engine works: closed at once, nothing '
      'written, the engine handed back', (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'))..gate = Completer<void>();
    await h.open(tester, _window);
    await tester.tap(find.byKey(const ValueKey('study-start')));
    await tester.pump();
    expect(find.text('Reading the position'), findsOneWidget);
    expect(find.textContaining('Position 1 of at most'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(PositionStudyDialog), findsNothing);
    expect(h.events, containsAllInOrder(['hold', 'search', 'popped']));
    expect(h.events, contains('release'),
        reason: 'the screen has its engine back the moment the dialog goes');

    // The search that was under way comes back to nobody.
    h.gate!.complete();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.takeException(), isNull);
    expect(h.start.children, isEmpty);
    expect(h.completed, isEmpty);
    expect(h.events.where((e) => e == 'search'), hasLength(1),
        reason: 'no search is asked for after the cancel');
    expect(h.events.where((e) => e == 'release'), hasLength(1));
  });

  testWidgets(
      'closed by the back button while the engine works, it is '
      'cancelled all the same', (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'))..gate = Completer<void>();
    await h.open(tester, _phone);
    await tester.tap(find.byKey(const ValueKey('study-start')));
    await tester.pump();

    // Not the dialog's own Cancel: the route is popped from outside it.
    Navigator.of(tester.element(find.byType(PositionStudyDialog))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(PositionStudyDialog), findsNothing);

    h.gate!.complete();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(tester.takeException(), isNull);
    expect(h.start.children, isEmpty);
    expect(h.completed, isEmpty);
    expect(h.asked, isEmpty);
    expect(h.events.where((e) => e == 'search'), hasLength(1));
  });

  testWidgets('two taps on Start start one study', (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'))..gate = Completer<void>();
    await h.open(tester, _window);
    final start = find.byKey(const ValueKey('study-start'));
    await tester.tap(start);
    await tester.tap(start, warnIfMissed: false);
    await tester.pump();
    expect(h.events.where((e) => e == 'hold'), hasLength(1));
    expect(h.events.where((e) => e == 'search'), hasLength(1));
    h.gate!.complete();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(h.completed, hasLength(1));
  });

  testWidgets('„Open as a tutorial" closes the dialog and then opens',
      (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'));
    await h.open(tester, _window);
    await _run(tester);
    h.events.clear();
    await tester.tap(find.byKey(const ValueKey('study-open-as-tutorial')));
    await tester.pumpAndSettle();
    expect(h.events, ['popped', 'tutorial']);
    expect(find.byType(PositionStudyDialog), findsNothing);
  });

  testWidgets('with no way to open a tutorial there is no such button',
      (tester) async {
    final h = _Harness(RecordedEngine.read('owner2'));
    await h.open(tester, _window, tutorial: false);
    await _run(tester);
    expect(find.text('The study is in the tree.'), findsOneWidget);
    expect(find.text('Open as a tutorial'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('the depth asked for is the depth searched', (tester) async {
    SharedPreferences.setMockInitialValues({'app_analysis_depth': 20});
    await AppSettingsService.instance.init();
    final engine = RecordedEngine.read('owner2');
    final depths = <int>{};
    final h = _Harness(engine);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PositionStudyDialog(
          startNode: h.start,
          analyzer: (fen,
              {required depth,
              required multiPV,
              timeout = const Duration(seconds: 1)}) {
            depths.add(depth);
            return engine.analyzer(fen, depth: depth, multiPV: multiPV);
          },
          onCompleted: (_) {},
        ),
      ),
    ));
    await _run(tester);
    expect(depths, {20});
  });
}
