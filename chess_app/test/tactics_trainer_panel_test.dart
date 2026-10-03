// The gate of phase 2 of docs/PLAN-EKRANI.md: the tactics trainer
// (`TacticsTrainerScreen`) on the board layout every board screen shares
// (`TrainerScreenLayout`, `TrainerInfoPanel`) — rules R1-R6 — and the counter
// that said „found 0" after a solve (§2.5, measured 3.10.2026: the session's
// `solvedMoveCount` floored an odd cursor).
//
// The screen is the real one, the server a `MockClient`, the app's own theme
// with real Roboto (`robotoTheme`), because a gate in `ThemeData.dark()`
// measures smaller buttons than the reader's — phase 1's lesson.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/speech/clip_voice.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/features/tactics_trainer/models/tactics_puzzle.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/services/tactics_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';

import 'support/landscape.dart';
import 'support/render_look.dart';

UserSession _session() => UserSession(
    token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik');

const _window = Size(1536, 792);
const _small = Size(900, 700);
const _phone = Size(360, 640);

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

/// A mate in one for White after Black's setup move h6, with no trainable
/// theme — so the line under the task is the move counter, not the motif.
Map<String, dynamic> _mateInOne() => {
      'puzzle_id': 'p1',
      'fen': '6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1',
      'setup_move': 'h7h6',
      'solution': ['a1a8'],
      'rating': 1180,
      'themes': const ['mateIn1'],
    };

http.Client _server(Map<String, dynamic> puzzle) => MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/puzzles/attempt')) {
        return http.Response(
            jsonEncode({
              'newRating': 1524,
              'ratingChange': 9,
              'puzzleRating': 1180,
              'puzzlesSolved': 143,
            }),
            200);
      }
      return http.Response(
          jsonEncode({
            'puzzle': puzzle,
            'selection': {'targetRating': 1200}
          }),
          200);
    });

Future<void> _pump(WidgetTester tester, SpeechService speech, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: TacticsTrainerScreen(
      key: UniqueKey(),
      session: _session(),
      speech: speech,
      api: TacticsApiService(authToken: 't', client: _server(_mateInOne())),
    ),
  ));
  await _wait(tester);
}

Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pumpAndSettle();
}

Future<void> _move(WidgetTester tester, String from, String to) async {
  tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
      .onMove(from, to, '');
  await _wait(tester);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

// ── finders ──────────────────────────────────────────────────────────────

Finder get _panel => find.byType(TrainerInfoPanel);
Finder _inPanel(Finder f) => find.descendant(of: _panel, matching: f);

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

Rect _rectOfFinder(Finder f) {
  expect(f, findsOneWidget);
  return _rectOf(f.evaluate().single);
}

/// Seen: inside the window and inside every box that scrolls it.
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
            reason: '${element.widget} is a scroll away at ${sizeLabel(size)}');
      }
      return true;
    });
  }
}

Rect get _board => _rectOfFinder(find.byType(ChessBoardWithOverlay));

const _task = 'White to move. Find the best move.';

void main() {
  setUpAll(loadRoboto);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. the counter (§2.5) ──────────────────────────────────────────────

  group('the solved-move counter', () {
    TacticsPuzzle puzzle(List<String> solution) => TacticsPuzzle(
        id: 'p',
        fen: '8/8/8/8/8/8/8/8 w - - 0 1',
        setupMove: null,
        solution: solution,
        rating: 1500);

    test('a one-move puzzle, solved, has found its one move', () {
      final session = TacticsSolveSession(puzzle(['a1a8']));
      expect(session.solvedMoveCount, 0);
      session.submit('a1a8');
      expect(session.status, SolveStatus.solved);
      expect(session.solvedMoveCount, 1);
    });

    test('a two-move puzzle counts one after the first, two after the last',
        () {
      final session = TacticsSolveSession(puzzle(['a2a3', 'h7h6', 'a3a4']));
      session.submit('a2a3');
      expect(session.solvedMoveCount, 1);
      session.submit('a3a4');
      expect(session.status, SolveStatus.solved);
      expect(session.solvedMoveCount, 2);
    });
  });

  // ── 2. one layout (R1) ─────────────────────────────────────────────────

  group('the board and the panel', () {
    for (final (size, minBoard) in [(_window, 520.0), (_small, 400.0)]) {
      testWidgets(
          'on a window of ${sizeLabel(size)}: the shared layout, the task in '
          'the panel beside a square board of at least $minBoard',
          (tester) async {
        await _pump(tester, await _speech(), size);
        expect(tester.takeException(), isNull);
        expect(find.byType(TrainerBoardLayout), findsOneWidget);
        expect(find.byType(LandscapeBoardLayout), findsNothing);
        final board = _board;
        expect(board.width, closeTo(board.height, 0.01), reason: 'square');
        expect(board.width, greaterThanOrEqualTo(minBoard));
        expect(_rectOfFinder(_panel).left, greaterThanOrEqualTo(board.right));
        expect(_inPanel(find.text(_task)), findsOneWidget);
        _expectSeen(tester, size, _inPanel(find.text(_task)));
        _expectSeen(tester, size, _filled);
        await _leave(tester);
      });
    }

    testWidgets('on a 360 dp phone: the panel under the board', (tester) async {
      await _pump(tester, await _speech(), _phone);
      expect(tester.takeException(), isNull);
      final board = _board;
      expect(board.width, closeTo(board.height, 0.01));
      expect(_rectOfFinder(_panel).top, greaterThanOrEqualTo(board.bottom));
      expect(_inPanel(find.text(_task)), findsOneWidget);
      // The owner's word of 3.10.2026: on a phone the buttons come right
      // under the board, so the main one is never a scroll away.
      // The order is the rule, not whether this fixture's panel happens to
      // leave room: the main button stands above the panel.
      expect(_rectOfFinder(_filled).top, lessThan(_rectOfFinder(_panel).top));
      await _move(tester, 'a1', 'a8');
      _expectSeen(tester, _phone, _button<FilledButton>('Next'));
      expect(_rectOfFinder(_filled).top, lessThan(_rectOfFinder(_panel).top));
      await _leave(tester);
    });

    for (final size in landscapePhones) {
      testWidgets('on a phone on its side, ${sizeLabel(size)}', (tester) async {
        await _pump(tester, await _speech(), size);
        expect(tester.takeException(), isNull);
        expect(find.byType(LandscapeBoardLayout), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(LandscapeBoardLayout), matching: _panel),
            findsOneWidget);
        expectOnScreen(tester, size, _filled);
        await _leave(tester);
      });
    }
  });

  // ── 3. the verdicts and the actions (R3-R6) ────────────────────────────

  group('the panel says what happened', () {
    testWidgets(
        'while solving: Skip is the one filled button, Show solution a '
        'text button, and no coloured slab', (tester) async {
      await _pump(tester, await _speech(), _window);
      expect(_filled, findsOneWidget);
      expect(_button<FilledButton>('Skip'), findsOneWidget);
      expect(_button<TextButton>('Show solution'), findsOneWidget);
      expect(_elevated, findsNothing);
      await _leave(tester);
    });

    testWidgets('a wrong move is said in the panel', (tester) async {
      await _pump(tester, await _speech(), _window);
      await _move(tester, 'a1', 'a2');
      expect(
          _inPanel(find.text('Incorrect. Try another move.')), findsOneWidget);
      _expectSeen(
          tester, _window, _inPanel(find.text('Incorrect. Try another move.')));
      await _leave(tester);
    });

    testWidgets(
        'a solve: the verdict and the new rating in the panel, Next the one '
        'filled button, and the counter says the move was found',
        (tester) async {
      await _pump(tester, await _speech(), _window);
      await _move(tester, 'a1', 'a8');
      expect(_inPanel(find.text('Solved.')), findsOneWidget);
      expect(_inPanel(find.textContaining('1524')), findsWidgets,
          reason: 'the rating card is the panel\'s now');
      _expectSeen(tester, _window, _inPanel(find.textContaining('1524')));
      expect(find.textContaining('found 0'), findsNothing,
          reason: 'one move found, not none (§2.5)');
      expect(_filled, findsOneWidget);
      expect(_button<FilledButton>('Next'), findsOneWidget);
      _expectSeen(tester, _window, _button<FilledButton>('Next'));
      expect(find.text('Next puzzle'), findsNothing, reason: 'one word (R6)');
      await _leave(tester);
    });

    testWidgets(
        'once it is over the task line no longer asks for a move: it says '
        'how the puzzle ended, once', (tester) async {
      await _pump(tester, await _speech(), _window);
      await _move(tester, 'a1', 'a8');
      // „White to move. Find the best move." over a board that will not
      // answer reads as a frozen board — the endgame trainer's rule.
      expect(find.text(_task), findsNothing);
      expect(_inPanel(find.text('Solved.')), findsOneWidget,
          reason: 'the ending, said once — as the task line, not twice');
      await _leave(tester);
    });
  });
}
