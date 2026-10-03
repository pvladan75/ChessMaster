// The gate of phase 3 of docs/PLAN-EKRANI.md: My mistakes
// (`MistakeDrillScreen`) on the board layout every board screen shares, the
// game's details and the verdict in the panel, the grades on screen after an
// answer (today below the fold at both sizes), every move named in SAN
// (§2.4: „The best move was e1g1, and you tried f3g5"), and rule R4 for a row
// of four peer grades: the one the reader most likely wants is filled —
// „Again" after a wrong answer, „Good" after a right one — the rest outlined.
//
// The app's own theme with real Roboto (`robotoTheme`), as phase 1 taught.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/mistake_item.dart';
import 'package:chess_app/features/archive/screens/mistake_drill_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';

import 'features/archive/mistake_drill_screen_test.dart'
    show FakeArchiveApiService;
import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _small = Size(900, 700);
const _phone = Size(360, 640);

/// The Italian after 3...Bc5: the best move was to castle, and in the game
/// White played Ng5.
const _castleFen =
    'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';

/// After 1.e4 d5: the best move takes, and in the game White pushed on.
const _captureFen =
    'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2';

MistakeItem _item(String fen, String best, String played) => MistakeItem(
      id: 'mistake_1',
      gameId: 'game_1',
      fenBefore: fen,
      playedUci: played,
      bestUci: best,
      swingCp: 120,
      playedAt: DateTime(2026, 9, 12),
      opponent: 'zoran_m',
      result: '0-1',
      subjectColor: 'w',
      opening: 'Italian Game',
      kind: 'engine',
      ply: 7,
      dueAt: DateTime(2026, 10, 3),
      intervalDays: 1,
      lapses: 0,
      repetitions: 0,
    );

class _Api extends FakeArchiveApiService {
  _Api(this.item);
  final MistakeItem item;

  @override
  Future<List<MistakeItem>> fetchMistakesDue({int limit = 20}) async => [item];
}

Future<_Api> _pump(WidgetTester tester, Size size, {MistakeItem? item}) async {
  final api = _Api(item ?? _item(_castleFen, 'e1g1', 'f3g5'));
  ArchiveApiService.setMock(api);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: MistakeDrillScreen(key: UniqueKey()),
  ));
  await tester.pumpAndSettle();
  return api;
}

Future<void> _move(WidgetTester tester, String from, String to) async {
  tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
      .onMove(from, to, '');
  await tester.pumpAndSettle();
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

const _task = 'White to move. Recall the better move.';
const _grades = ['Again', 'Hard', 'Good', 'Easy'];

void main() {
  setUpAll(loadRoboto);

  // ── 1. one layout (R1) ─────────────────────────────────────────────────

  group('the board and the panel', () {
    for (final (size, minBoard) in [(_window, 520.0), (_small, 400.0)]) {
      testWidgets(
          'on a window of ${sizeLabel(size)}: the shared layout, the game and '
          'the task in the panel beside a square board of at least $minBoard',
          (tester) async {
        await _pump(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.byType(TrainerBoardLayout), findsOneWidget);
        expect(find.byType(LandscapeBoardLayout), findsNothing);
        final board = _board;
        expect(board.width, closeTo(board.height, 0.01));
        expect(board.width, greaterThanOrEqualTo(minBoard));
        expect(_rectOfFinder(_panel).left, greaterThanOrEqualTo(board.right));
        expect(_inPanel(find.text(_task)), findsOneWidget);
        expect(_inPanel(find.textContaining('zoran_m')), findsWidgets,
            reason: 'the game it came from is the panel\'s context');
        _expectSeen(tester, size, _inPanel(find.text(_task)));
        _expectSeen(tester, size, _filled);
      });
    }

    testWidgets('on a 360 dp phone: the panel under the board', (tester) async {
      await _pump(tester, _phone);
      expect(tester.takeException(), isNull);
      final board = _board;
      expect(board.width, closeTo(board.height, 0.01));
      expect(_rectOfFinder(_panel).top, greaterThanOrEqualTo(board.bottom));
    });

    for (final size in landscapePhones) {
      testWidgets('on a phone on its side, ${sizeLabel(size)}', (tester) async {
        await _pump(tester, size);
        expect(tester.takeException(), isNull);
        expect(find.byType(LandscapeBoardLayout), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(LandscapeBoardLayout), matching: _panel),
            findsOneWidget);
        expectOnScreen(tester, size, _filled);
      });
    }
  });

  // ── 2. before the answer (R4) ──────────────────────────────────────────

  testWidgets('before an answer: Show answer is the one filled button',
      (tester) async {
    await _pump(tester, _window);
    expect(_filled, findsOneWidget);
    expect(_button<FilledButton>('Show answer'), findsOneWidget);
    expect(_elevated, findsNothing, reason: 'no coloured slabs (R4)');
  });

  // ── 3. the verdict, in moves a person reads (§2.4) ─────────────────────

  group('the verdict', () {
    testWidgets(
        'a wrong answer names every move in SAN, in the panel, and the '
        'grades are on screen with Again filled', (tester) async {
      await _pump(tester, _window);
      await _move(tester, 'd2', 'd3');
      expect(_inPanel(find.textContaining('O-O')), findsWidgets,
          reason: 'the best move, castling, in SAN');
      expect(_inPanel(find.textContaining('d3')), findsWidgets,
          reason: 'the move tried');
      expect(_inPanel(find.textContaining('Ng5')), findsWidgets,
          reason: 'the move played in the game');
      for (final uci in ['e1g1', 'f3g5', 'd2d3']) {
        expect(find.textContaining(uci), findsNothing, reason: uci);
      }
      for (final grade in _grades) {
        _expectSeen(tester, _window, find.text(grade));
      }
      expect(_filled, findsOneWidget);
      expect(_button<FilledButton>('Again'), findsOneWidget);
      for (final grade in ['Hard', 'Good', 'Easy']) {
        expect(_button<OutlinedButton>(grade), findsOneWidget, reason: grade);
      }
      expect(_elevated, findsNothing);
    });

    testWidgets('a right answer: Good is filled', (tester) async {
      await _pump(tester, _window);
      await _move(tester, 'e1', 'g1');
      expect(_inPanel(find.textContaining('best move')), findsWidgets);
      expect(_filled, findsOneWidget);
      expect(_button<FilledButton>('Good'), findsOneWidget);
    });

    testWidgets(
        'Show answer without a move: the best move in SAN, and no „you '
        'tried nothing"', (tester) async {
      await _pump(tester, _window);
      expect(_button<FilledButton>('Show answer'), findsOneWidget);
      await tester.tap(_button<FilledButton>('Show answer'));
      await tester.pumpAndSettle();
      expect(_inPanel(find.textContaining('O-O')), findsWidgets);
      expect(find.textContaining('nothing'), findsNothing);
      expect(find.textContaining('e1g1'), findsNothing);
    });

    testWidgets('a capture is named as one: exd5', (tester) async {
      await _pump(tester, _window, item: _item(_captureFen, 'e4d5', 'e4e5'));
      await _move(tester, 'a2', 'a3');
      expect(_inPanel(find.textContaining('exd5')), findsWidgets);
      expect(_inPanel(find.textContaining('e5')), findsWidgets);
      expect(find.textContaining('e4d5'), findsNothing);
    });

    testWidgets('a grade is still sent, and the drill moves on',
        (tester) async {
      final api = await _pump(tester, _window);
      await _move(tester, 'e1', 'g1');
      expect(_button<FilledButton>('Good'), findsOneWidget);
      await tester.tap(_button<FilledButton>('Good'));
      await tester.pumpAndSettle();
      expect(api.graded, ['good']);
    });
  });
}
