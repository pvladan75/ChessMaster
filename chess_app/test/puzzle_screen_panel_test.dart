// The gate of phase 1 of docs/PLAN-EKRANI.md: the puzzle screen
// (`AiStudioScreen`) on the board layout every board screen shares
// (`TrainerBoardLayout`, `TrainerInfoPanel`), with its task and every verdict
// in the panel (rules R1-R5), and the owner's two answers of 3.10.2026:
//
//   A. a verdict is said in the panel, not in a dialog, a sheet or a snackbar;
//   B. on „Find the winning path" and „Basic checkmate" the engine panel is
//      there only once the puzzle is over.
//
// The screen is the real one. The server is a `MockClient`; a puzzle's
// replies come out of its own solution tree or its `moves`, so no engine is
// asked; „Play it out" is answered by the engine singleton's handler, as
// `engine_game_screen_test.dart` does. Real Roboto, because these cases
// measure what fits.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';

import 'support/landscape.dart';
import 'support/render_look.dart';

final _session = UserSession(
    id: 1, token: 'tok', email: 'e@x.com', name: 'N', role: 'ucenik');

const _window = Size(1536, 792); // the owner's Windows window
const _small = Size(900, 700); // a window held sideways, but not a phone
const _phone = Size(360, 640);

// ── fakes ────────────────────────────────────────────────────────────────

/// A clip voice that says nothing and finishes at once.
class _SilentVoice extends ClipVoice {
  @override
  Future<void> load(AssetBundle bundle) async {}
  @override
  Future<void> speak(SpokenLine line) async {}
  @override
  Future<void> stop() async {}
}

Future<SpeechService> _speech() async {
  final speech = SpeechService.forSubclass();
  await speech.init(enabled: false, clipVoice: _SilentVoice());
  await AppSettingsService.instance.init();
  await AppSettingsService.instance.setSpeechEnabled(false);
  return speech;
}

Map<String, dynamic> _puzzle(String fen, Map<String, dynamic> solutions,
        {List<String> moves = const []}) =>
    {
      'puzzle_id': 't1',
      'fen': fen,
      'moves': moves,
      'solutions': solutions,
      'winning_move_uci': solutions.isEmpty ? '' : solutions.keys.first,
    };

/// The puzzle server, keeping every request it was sent.
class _Server {
  _Server(this.puzzle);
  final Map<String, dynamic> puzzle;
  final List<http.Request> sent = [];

  http.Client get client => MockClient((request) async {
        sent.add(request);
        final path = request.url.path;
        if (request.method == 'GET' && path.endsWith('/api/puzzles/next')) {
          return http.Response(
              jsonEncode({'puzzle': puzzle, 'userRating': 1500}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (path.endsWith('/api/puzzles/submit')) {
          return http.Response('{"ratingChange":5,"newRating":1505}', 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{}', 200);
      });

  List<Map<String, dynamic>> get submits => [
        for (final r in sent)
          if (r.url.path.endsWith('/api/puzzles/submit'))
            jsonDecode(r.body) as Map<String, dynamic>
      ];

  int get fetched =>
      sent.where((r) => r.url.path.endsWith('/api/puzzles/next')).length;
}

// The positions. Each is chosen so that nothing but the case's own move can
// happen on it.
const _mateIn1 = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1'; // Ra8#
const _quiet = '7k/7p/8/8/8/8/P7/K7 w - - 0 1'; // a2a4 is the answer
const _drillLost = 'r5k1/8/8/8/8/8/1P3PPP/6K1 w - - 0 1'; // ...Ra1#
const _drillStalemate = '6k1/8/8/4q3/p7/8/P7/7K w - - 0 1'; // ...Qg3 =

// ── the screen ───────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester,
  SpeechService speech, {
  required Size size,
  String category = 'mate_puzzle',
  String depth = '1',
  String? basicMateLevel,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: robotoTheme(AppTheme.dark),
      home: AiStudioScreen(
        // A fresh State per pump: the same widget type pumped twice in one
        // case would otherwise keep the first case's puzzle.
        key: UniqueKey(),
        userSession: _session,
        initialCategory: category,
        mateDepth: depth,
        basicMateLevel: basicMateLevel,
        speech: speech,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Leaves the screen, so its timers are gone before the case ends.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tapSquare(WidgetTester tester, String square) async {
  final rect = tester.getRect(find.byType(SkinnedChessBoard).first);
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square.substring(1));
  final size = rect.width / 8;
  await tester.tapAt(rect.topLeft +
      Offset(file * size + size / 2, (8 - rank) * size + size / 2));
  await tester.pump();
}

/// The reader plays [from]→[to], and the screen has time to answer.
Future<void> _move(WidgetTester tester, String from, String to) async {
  await _tapSquare(tester, from);
  await _tapSquare(tester, to);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle();
}

// ── finders ──────────────────────────────────────────────────────────────

Finder get _panel => find.byType(TrainerInfoPanel);

Finder _inPanel(Finder finder) => find.descendant(of: _panel, matching: finder);

/// A button of kind [T] — its `.icon` variants are subclasses, which
/// `find.byType` does not match — labelled [label].
Finder _button<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

Finder get _filled => find.byWidgetPredicate((w) => w is FilledButton);
Finder get _elevated => find.byWidgetPredicate((w) => w is ElevatedButton);

Rect _rectOf(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Every widget [finder] matches is seen: inside the window **and** inside
/// every box that scrolls it (`repertoire_build_layout_test.dart`'s rule —
/// `expectOnScreen` alone passes a panel laid out below its own fold).
void _expectSeen(WidgetTester tester, Size size, Finder finder) {
  expectOnScreen(tester, size, finder);
  for (final element in finder.evaluate()) {
    final rect = _rectOf(element);
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Scrollable) {
        final box = _rectOf(ancestor);
        expect(
            box.contains(rect.topLeft) &&
                box.contains(rect.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: '${element.widget} is a scroll away at ${sizeLabel(size)}: '
                '$rect outside $box');
      }
      return true;
    });
  }
}

/// Nothing announced a verdict the old ways (rule R3, answer A).
void _expectNoPopups() {
  expect(find.byType(AlertDialog), findsNothing, reason: 'a dialog');
  expect(find.byType(BottomSheet), findsNothing, reason: 'a bottom sheet');
  expect(find.byType(SnackBar), findsNothing, reason: 'a snackbar');
}

Rect get _board => _rectOfFinder(find.byType(SkinnedChessBoard).first);

/// The one widget [f] finds — asserted first, so a missing widget fails the
/// case instead of throwing `Bad state` out of `.single`.
Rect _rectOfFinder(Finder f) {
  expect(f, findsOneWidget);
  return _rectOf(f.evaluate().single);
}

void main() {
  setUpAll(loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final service = StockfishService();
    service.onEvaluationChanged = null;
    service.onMultiPVUpdated = null;
    AppSettingsService.instance.setEnginePlayLevel('srednje');
  });

  // ── 1. one layout (R1) ────────────────────────────────────────────────

  group('the board and the panel', () {
    // 440 at 900 x 700 assumed the buttons fit one line under the board; in
    // the app's own theme they do not (507 px against a 465 column), and the
    // second line's height is the board's — 408 measured, 3.10.2026.
    for (final (size, minBoard) in [(_window, 520.0), (_small, 400.0)]) {
      testWidgets(
          'on a window of ${sizeLabel(size)}: the shared layout, the panel '
          'beside a square board of at least $minBoard', (tester) async {
        final speech = await _speech();
        final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
        await http.runWithClient(() async {
          await _pump(tester, speech, size: size);
          expect(tester.takeException(), isNull);
          // 900 x 700 is held sideways and is not a phone: the layout is
          // chosen by the window, never by its orientation.
          expect(find.byType(TrainerBoardLayout), findsOneWidget);
          expect(find.byType(LandscapeBoardLayout), findsNothing);
          expect(_panel, findsOneWidget);

          final board = _board;
          expect(board.width, board.height, reason: 'a board is square');
          expect(board.width, greaterThanOrEqualTo(minBoard));
          expect(_rectOfFinder(_panel).left, greaterThanOrEqualTo(board.right),
              reason: 'the panel stands beside the board');

          expect(
              _inPanel(find.text('White to move. Mate in 1.')), findsOneWidget,
              reason: 'the task is in the panel (R2)');
          _expectSeen(
              tester, size, _inPanel(find.text('White to move. Mate in 1.')));
          _expectSeen(tester, size, _button<FilledButton>('Next'));
          await _leave(tester);
        }, () => server.client);
      });
    }

    testWidgets('on a 360 dp phone: the panel under the board', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
      await http.runWithClient(() async {
        await _pump(tester, speech, size: _phone);
        expect(tester.takeException(), isNull);
        expect(find.byType(LandscapeBoardLayout), findsNothing);
        final board = _board;
        expect(board.width, board.height);
        expect(_rectOfFinder(_panel).top, greaterThanOrEqualTo(board.bottom),
            reason: 'the panel is under the board');
        expect(
            _inPanel(find.text('White to move. Mate in 1.')), findsOneWidget);
        // The owner's word of 3.10.2026: on a phone the buttons come right
        // under the board, so Next is never a scroll away.
        // The order is the rule, not whether this fixture's panel happens to
        // leave room: Next stands above the panel, before and after a move.
        expect(_rectOfFinder(_button<FilledButton>('Next')).top,
            lessThan(_rectOfFinder(_panel).top));
        await _move(tester, 'g2', 'g3');
        expect(_inPanel(find.text('Incorrect. Try another move.')),
            findsOneWidget);
        _expectSeen(tester, _phone, _button<FilledButton>('Next'));
        expect(_rectOfFinder(_button<FilledButton>('Next')).top,
            lessThan(_rectOfFinder(_panel).top));
        await _leave(tester);
      }, () => server.client);
    });

    for (final size in landscapePhones) {
      testWidgets(
          'on a phone on its side, ${sizeLabel(size)}: the landscape layout '
          'with the panel in its column', (tester) async {
        final speech = await _speech();
        final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
        await http.runWithClient(() async {
          await _pump(tester, speech, size: size);
          expect(tester.takeException(), isNull);
          expect(find.byType(LandscapeBoardLayout), findsOneWidget);
          expect(
              find.descendant(
                  of: find.byType(LandscapeBoardLayout), matching: _panel),
              findsOneWidget);
          expect(
              _inPanel(find.text('White to move. Mate in 1.')), findsOneWidget);
          expectOnScreen(tester, size, _button<FilledButton>('Next'));
          await _leave(tester);
        }, () => server.client);
      });
    }
  });

  // ── 2. one place per action, one filled button (R4-R6) ────────────────

  group('the actions', () {
    testWidgets(
        'one filled Next, the rest text buttons, and nothing of the old '
        'row or header left', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_quiet, {'a2a4': 'CHECKMATE'}));
      await http.runWithClient(() async {
        await _pump(tester, speech, size: _window, depth: '2');
        expect(_filled, findsOneWidget);
        expect(_button<FilledButton>('Next'), findsOneWidget);
        expect(_button<TextButton>('Try again'), findsOneWidget);
        expect(_button<TextButton>('Show solution'), findsOneWidget);
        expect(_button<TextButton>('Open in Analysis'), findsOneWidget);
        expect(_elevated, findsNothing, reason: 'no coloured slabs (R4)');
        for (final old in [
          'Analysis 🔬',
          'Try Again',
          'Next Position',
          'Next Puzzle'
        ]) {
          expect(find.text(old), findsNothing, reason: old);
        }
        for (final tip in [
          'Try Again',
          'Next Position',
          'Analyze in Analysis Board 🔬'
        ]) {
          expect(find.byTooltip(tip), findsNothing,
              reason: 'the header icon „$tip" is a second place (R5)');
        }
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets(
        'Basic checkmate is titled in words, not „(Checkmate '
        'Stockfish)"', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_mateIn1, {}));
      await http.runWithClient(() async {
        await _pump(tester, speech,
            size: _window, category: 'basic_mate', basicMateLevel: 'easy');
        expect(find.textContaining('Checkmate Stockfish'), findsNothing);
        expect(find.textContaining('Practice: easy'), findsNothing);
        expect(_filled, findsOneWidget);
        await _leave(tester);
      }, () => server.client);
    });
  });

  // ── 3. every verdict in the panel (A, R3) ─────────────────────────────

  group('the verdicts', () {
    testWidgets(
        'a wrong move: said in the panel, with Try again, Show solution '
        'and Next beside it', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_quiet, {'a2a4': 'CHECKMATE'}));
      await http.runWithClient(() async {
        await _pump(tester, speech, size: _window, depth: '2');
        await _move(tester, 'a2', 'a3');
        _expectNoPopups();
        expect(_inPanel(find.text('Incorrect. Try another move.')),
            findsOneWidget);
        _expectSeen(tester, _window,
            _inPanel(find.text('Incorrect. Try another move.')));
        expect(_button<TextButton>('Try again'), findsOneWidget);
        expect(_button<TextButton>('Show solution'), findsOneWidget);
        expect(_filled, findsOneWidget);
        expect(_button<FilledButton>('Next'), findsOneWidget);
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets(
        'Next after a wrong move gives the puzzle up: one failure is sent, '
        'then the next puzzle is asked for', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_quiet, {'a2a4': 'CHECKMATE'}));
      await http.runWithClient(() async {
        await _pump(tester, speech, size: _window, depth: '2');
        expect(server.fetched, 1);
        await _move(tester, 'a2', 'a3');
        expect(_button<FilledButton>('Next'), findsOneWidget);
        await tester.tap(_button<FilledButton>('Next'));
        await tester.pumpAndSettle();
        expect(server.submits, hasLength(1));
        expect(server.submits.single['solved'], isFalse);
        expect(server.fetched, 2);
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets('Try again after a wrong move clears the verdict',
        (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_quiet, {'a2a4': 'CHECKMATE'}));
      await http.runWithClient(() async {
        await _pump(tester, speech, size: _window, depth: '2');
        await _move(tester, 'a2', 'a3');
        expect(_inPanel(find.text('Incorrect. Try another move.')),
            findsOneWidget);
        await tester.tap(_button<TextButton>('Try again'));
        await tester.pumpAndSettle();
        expect(find.text('Incorrect. Try another move.'), findsNothing);
        expect(
            _inPanel(find.text('White to move. Mate in 2.')), findsOneWidget);
        expect(server.submits, isEmpty,
            reason: 'trying again is not giving up');
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets(
        'a solve: „Checkmate. Puzzle solved." and the new rating, in the '
        'panel', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
      await http.runWithClient(() async {
        await _pump(tester, speech, size: _window);
        await _move(tester, 'a1', 'a8');
        _expectNoPopups();
        expect(
            _inPanel(find.text('Checkmate. Puzzle solved.')), findsOneWidget);
        expect(_inPanel(find.textContaining('1505')), findsWidgets,
            reason: 'the rating the dialog used to carry');
        expect(server.submits.single['solved'], isTrue);
        expect(_button<FilledButton>('Next'), findsOneWidget);
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets('Find the winning path, lost: said in the panel',
        (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_drillLost, {}, moves: ['a8a1']));
      await http.runWithClient(() async {
        await _pump(tester, speech,
            size: _window, category: 'winning_position');
        await _move(tester, 'b2', 'b3');
        _expectNoPopups();
        expect(_inPanel(find.text('Stockfish delivered checkmate. Try again.')),
            findsOneWidget);
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets('Find the winning path, drawn: said in the panel',
        (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_drillStalemate, {}, moves: ['e5g3']));
      await http.runWithClient(() async {
        await _pump(tester, speech,
            size: _window, category: 'winning_position');
        await _move(tester, 'a2', 'a3');
        _expectNoPopups();
        expect(_inPanel(find.text('The game is drawn: stalemate. Try again.')),
            findsOneWidget);
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets('Find the winning path, won: said in the panel, no VICTORY',
        (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_mateIn1, {}));
      await http.runWithClient(() async {
        await _pump(tester, speech,
            size: _window, category: 'winning_position');
        await _move(tester, 'a1', 'a8');
        _expectNoPopups();
        expect(find.textContaining('VICTORY'), findsNothing);
        expect(
            _inPanel(find.text('Checkmate. Puzzle solved.')), findsOneWidget);
        await _leave(tester);
      }, () => server.client);
    });
  });

  // ── 4. the engine only once it is over (B) ────────────────────────────

  group('the engine panel', () {
    testWidgets(
        'Find the winning path: absent while solving, there once it is '
        'lost', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_drillLost, {}, moves: ['a8a1']));
      await http.runWithClient(() async {
        await _pump(tester, speech,
            size: _window, category: 'winning_position');
        expect(find.byType(StockfishAnalysisWidget, skipOffstage: false),
            findsNothing);
        await _move(tester, 'b2', 'b3');
        expect(find.byType(StockfishAnalysisWidget, skipOffstage: false),
            findsOneWidget);
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets('Basic checkmate: absent while solving', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_mateIn1, {}));
      await http.runWithClient(() async {
        await _pump(tester, speech,
            size: _window, category: 'basic_mate', basicMateLevel: 'easy');
        expect(find.byType(StockfishAnalysisWidget, skipOffstage: false),
            findsNothing);
        await _leave(tester);
      }, () => server.client);
    });

    testWidgets('Mate in N: never, before or after the solve', (tester) async {
      final speech = await _speech();
      final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
      await http.runWithClient(() async {
        await _pump(tester, speech, size: _window);
        expect(find.byType(StockfishAnalysisWidget, skipOffstage: false),
            findsNothing);
        await _move(tester, 'a1', 'a8');
        expect(find.byType(StockfishAnalysisWidget, skipOffstage: false),
            findsNothing);
        await _leave(tester);
      }, () => server.client);
    });
  });

  // ── 5. „Play it out" ──────────────────────────────────────────────────

  group('Play it out', () {
    const mateFen = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';
    final task = {'fen': mateFen, 'side': 'w', 'goal': 'win', 'plyCap': 40};

    Future<void> pumpGame(WidgetTester tester,
        {int? assignmentId, String? exerciseId, http.Client? client}) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: robotoTheme(AppTheme.dark),
          home: AiStudioScreen(
            userSession: _session,
            initialCategory: 'engine_game',
            engineGameTask: EngineGameTask.fromJson(task)!,
            assignmentId: assignmentId,
            exerciseId: exerciseId,
            exerciseApi: exerciseId == null
                ? null
                : ExerciseApiService(authToken: 'tok', client: client!),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    http.Client answers(Map<String, Object?> body) =>
        MockClient((_) async => http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'}));

    const won = {
      'goalMet': true,
      'judgedBy': 'rules',
      'pending': false,
      'ending': 'checkmate',
      'outcome': 'won',
    };

    testWidgets(
        'while it runs: Resign is an outlined button and the turn is in '
        'the panel', (tester) async {
      await http.runWithClient(() async {
        await pumpGame(tester, exerciseId: 'ex_1', client: answers(won));
        expect(_button<OutlinedButton>('Resign'), findsOneWidget);
        expect(_inPanel(find.byKey(const Key('engine-game-turn'))),
            findsOneWidget);
        await _leave(tester);
      }, () => answers(won));
    });

    testWidgets("one's own game: the verdict in the panel, no dialog",
        (tester) async {
      await http.runWithClient(() async {
        await pumpGame(tester, exerciseId: 'ex_1', client: answers(won));
        await _move(tester, 'd1', 'd8');
        _expectNoPopups();
        expect(_inPanel(find.text('Goal met')), findsOneWidget);
        await _leave(tester);
      }, () => answers(won));
    });

    testWidgets(
        'an assigned game keeps its dialog: it has ended, and Back is the '
        'only way on', (tester) async {
      await http.runWithClient(() async {
        await pumpGame(tester, assignmentId: 42);
        await _move(tester, 'd1', 'd8');
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Goal met'), findsOneWidget,
            reason: 'said once, in the dialog');
        await _leave(tester);
      }, () => MockClient((_) async => http.Response('{"ok":true}', 200)));
    });
  });
}
