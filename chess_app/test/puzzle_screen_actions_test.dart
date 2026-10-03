// What the buttons of the puzzle screen do, beyond what
// `puzzle_screen_panel_test.dart` (the gate of phase 1 of
// docs/PLAN-EKRANI.md) holds: the choices the „Incorrect Move!" sheet and the
// drill dialogs offered are the panel's buttons now, and each keeps the side
// effects its old home had.
//
// The screen is the real one and the server a `MockClient`; no engine is
// asked, because a mate puzzle's replies come out of its own solution tree and
// the drills are answered by their `moves`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';

import 'support/landscape.dart';

final _session = UserSession(
    id: 1, token: 'tok', email: 'e@x.com', name: 'N', role: 'ucenik');

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

Map<String, dynamic> _puzzle(String fen, Map<String, dynamic> solutions,
        {List<String> moves = const []}) =>
    {
      'puzzle_id': 't1',
      'fen': fen,
      'moves': moves,
      'solutions': solutions,
      'winning_move_uci': solutions.isEmpty ? '' : solutions.keys.first,
    };

const _mateIn1 = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1'; // Ra8#, or Kh1
const _drillLost = 'r5k1/8/8/8/8/8/1P3PPP/6K1 w - - 0 1'; // ...Ra1#

const _size = Size(1536, 792);

Future<void> _pump(WidgetTester tester, SpeechService speech,
    {String category = 'mate_puzzle', String depth = '1'}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AiStudioScreen(
        key: UniqueKey(),
        userSession: _session,
        initialCategory: category,
        mateDepth: depth,
        speech: speech,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  // Closed in a tear-down, so a case that fails half way does not leave the
  // screen standing for the next one.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
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

Future<void> _move(WidgetTester tester, String from, String to) async {
  await _tapSquare(tester, from);
  await _tapSquare(tester, to);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pumpAndSettle();
}

/// A button of kind [T] — its `.icon` variants are subclasses, which
/// `find.byType` does not match — labelled [label].
Finder _button<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

/// Nothing announced a verdict the old ways (rule R3, answer A).
void _expectNoPopups() {
  expect(find.byType(AlertDialog), findsNothing);
  expect(find.byType(BottomSheet), findsNothing);
  expect(find.byType(SnackBar), findsNothing);
}

String _fenOnBoard(WidgetTester tester) => tester
    .widget<SkinnedChessBoard>(find.byType(SkinnedChessBoard).first)
    .controller
    .getFen();

Finder get _panel => find.byType(TrainerInfoPanel);
Finder _inPanel(Finder f) => find.descendant(of: _panel, matching: f);
Finder get _engine => find.byType(StockfishAnalysisWidget, skipOffstage: false);

void main() {
  setUpAll(loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final service = StockfishService();
    service.onEvaluationChanged = null;
    service.onMultiPVUpdated = null;
    AppSettingsService.instance.setEnginePlayLevel('srednje');
  });

  testWidgets(
      'a wrong move keeps the board still until a choice is made: the other '
      "side's move, tried next, is not played", (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
    await http.runWithClient(() async {
      await _pump(tester, speech);
      await _move(tester, 'g1', 'h1'); // legal, and not the answer
      expect(
          _inPanel(find.text('Incorrect. Try another move.')), findsOneWidget);
      final stopped = _fenOnBoard(tester);
      expect(stopped, contains(' b '), reason: 'Black is to move now');

      // Nothing answers a mate puzzle's wrong move, so it is the reader's
      // own pieces that could be moved on: the sheet kept them still by
      // being in the way, and the panel does it by name.
      await _move(tester, 'g8', 'f8');
      expect(_fenOnBoard(tester), stopped);
      // By hand as well as by tapping: a drag does not go through the tap.
      final rect = tester.getRect(find.byType(SkinnedChessBoard).first);
      final square = rect.width / 8;
      await tester.dragFrom(rect.topLeft + Offset(6.5 * square, 0.5 * square),
          Offset(-square, 0));
      await tester.pumpAndSettle();
      expect(_fenOnBoard(tester), stopped);
      expect(
          _inPanel(find.text('Incorrect. Try another move.')), findsOneWidget);
      expect(server.submits, isEmpty);

      // And the choice gives the board back.
      await tester.tap(_button<TextButton>('Try again'));
      await tester.pumpAndSettle();
      expect(_fenOnBoard(tester), isNot(stopped));
      expect(_fenOnBoard(tester), startsWith('6k1/5ppp/8/8/8/8/5PPP/R5K1 w'));
    }, () => server.client);
  });

  testWidgets(
      'Show solution after a wrong move records one failure, replays, and '
      'is gone once the solution is shown', (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
    await http.runWithClient(() async {
      await _pump(tester, speech);
      await _move(tester, 'g1', 'h1');
      await tester.tap(_button<TextButton>('Show solution'));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(server.submits, hasLength(1));
      expect(server.submits.single['solved'], isFalse);
      expect(server.submits.single['skipped'], isFalse,
          reason: 'giving up after a wrong move is a failure, not a skip');
      expect(find.text('Incorrect. Try another move.'), findsNothing);
      expect(find.text('Graphical Move Tree'), findsOneWidget,
          reason: 'the solution is on show');
      expect(_button<TextButton>('Show solution'), findsNothing);
    }, () => server.client);
  });

  testWidgets(
      'Try again, then Show solution: the replay has its start (the reset '
      'used to leave it nowhere)', (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
    await http.runWithClient(() async {
      await _pump(tester, speech);
      await _move(tester, 'g1', 'h1');
      await tester.tap(_button<TextButton>('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect. Try another move.'), findsNothing);

      await tester.tap(_button<TextButton>('Show solution'));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(find.text('Graphical Move Tree'), findsOneWidget);
      expect(server.submits.single['solved'], isFalse);
    }, () => server.client);
  });

  testWidgets(
      'Show solution before any move is giving up too: one failure, the '
      'solution on show', (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
    await http.runWithClient(() async {
      await _pump(tester, speech);
      expect(_button<TextButton>('Show solution'), findsOneWidget);
      await tester.tap(_button<TextButton>('Show solution'));
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();
      expect(server.submits, hasLength(1));
      expect(server.submits.single['solved'], isFalse);
      expect(find.text('Graphical Move Tree'), findsOneWidget);
    }, () => server.client);
  });

  testWidgets(
      'Next after a drill that ended against the reader records nothing, as '
      'the dialog\'s „Next Position" did not', (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_drillLost, {}, moves: ['a8a1']));
    await http.runWithClient(() async {
      await _pump(tester, speech, category: 'winning_position');
      await _move(tester, 'b2', 'b3');
      expect(_inPanel(find.text('Stockfish delivered checkmate. Try again.')),
          findsOneWidget);
      await tester.tap(_button<FilledButton>('Next'));
      await tester.pumpAndSettle();
      expect(server.submits, isEmpty);
      expect(server.fetched, 2);
    }, () => server.client);
  });

  testWidgets(
      'solving it again is solving it: the engine panel goes with Try again '
      'after a solve', (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {}));
    await http.runWithClient(() async {
      await _pump(tester, speech, category: 'winning_position');
      expect(_engine, findsNothing);
      await _move(tester, 'a1', 'a8');
      expect(_engine, findsOneWidget);
      await tester.tap(_button<TextButton>('Try again'));
      await tester.pumpAndSettle();
      expect(_engine, findsNothing);
      expect(find.text('Checkmate. Puzzle solved.'), findsNothing);
    }, () => server.client);
  });

  testWidgets(
      'Next after a wrong move is a failure and not a skip, as the sheet\'s '
      '„Next Puzzle" was', (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
    await http.runWithClient(() async {
      await _pump(tester, speech);
      await _move(tester, 'g1', 'h1');
      await tester.tap(_button<FilledButton>('Next'));
      await tester.pumpAndSettle();
      expect(server.submits, hasLength(1));
      expect(server.submits.single['solved'], isFalse);
      expect(server.submits.single['skipped'], isFalse);
      // Without a wrong move it is a skip, which the hub card tells from a
      // failure (docs/PLAN-NAPREDAK-VEZBI.md §4).
      await tester.tap(_button<FilledButton>('Next'));
      await tester.pumpAndSettle();
      expect(server.submits, hasLength(2));
      expect(server.submits.last['skipped'], isTrue);
    }, () => server.client);
  });

  testWidgets(
      'the engine, switched on after a solve, is off again when the puzzle '
      'is solved a second time: no help carried over', (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {}));
    await http.runWithClient(() async {
      await _pump(tester, speech, category: 'winning_position');
      await _move(tester, 'a1', 'a8');
      tester.widget<StockfishAnalysisWidget>(_engine).onToggleEngine();
      await tester.pump();
      expect(tester.widget<StockfishAnalysisWidget>(_engine).isEngineEnabled,
          isTrue);

      await tester.tap(_button<TextButton>('Try again'));
      await tester.pumpAndSettle();
      await _move(tester, 'a1', 'a8');
      expect(_engine, findsOneWidget);
      expect(tester.widget<StockfishAnalysisWidget>(_engine).isEngineEnabled,
          isFalse,
          reason: 'the engine was off while the puzzle was being solved');
    }, () => server.client);
  });

  testWidgets(
      'the other defence is said in the panel, and only until the reader '
      'moves on', (tester) async {
    final speech = await _speech();
    // Two defences to the first move: the first ends the line at once, and
    // the second needs two more moves of the reader's.
    final server = _Server(_puzzle('7k/7p/8/3n4/8/8/P7/K5N1 w - - 0 1', {
      'a2a3': {
        'd5b6': {'a3a4': 'CHECKMATE'},
        'h7h6': {
          'g1h3': {
            'h6h5': {'h3g5': 'CHECKMATE'}
          }
        },
      }
    }));
    await http.runWithClient(() async {
      await _pump(tester, speech, depth: '3');
      await _move(tester, 'a2', 'a3');
      await _move(tester, 'a3', 'a4'); // the first line, solved
      expect(
          _inPanel(
              find.text('Great! Now solve the opponent\'s other defense.')),
          findsOneWidget);
      _expectNoPopups();

      await _move(tester, 'g1', 'h3'); // a right move of the second line
      expect(find.textContaining('other defense'), findsNothing,
          reason: 'the reader has moved on');
      expect(find.text('Incorrect. Try another move.'), findsNothing);
    }, () => server.client);
  });

  testWidgets('the rating joins the solve once the server has answered it',
      (tester) async {
    final speech = await _speech();
    final server = _Server(_puzzle(_mateIn1, {'a1a8': 'CHECKMATE'}));
    await http.runWithClient(() async {
      await _pump(tester, speech);
      await _move(tester, 'a1', 'a8');
      expect(_inPanel(find.text('New rating: 1505 (+5)')), findsOneWidget);
      // And is the next puzzle's only for as long as it is the same puzzle:
      // Next clears the verdict with the puzzle.
      await tester.tap(_button<FilledButton>('Next'));
      await tester.pumpAndSettle();
      expect(find.textContaining('New rating'), findsNothing);
    }, () => server.client);
  });
}
