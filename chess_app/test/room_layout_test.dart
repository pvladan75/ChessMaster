// The room on one set of rules — phase 4 of docs/PLAN-EKRANI.md, drawn as
// docs/skice/ekrani/compare_room.png and chosen by the owner on 3.10.2026:
// „B, and the student's column as drawn".
//
// What the phase decided, as things a reader can see:
//   * on a window the board takes the height, because the engine panel moved
//     from under the board to the top of the Moves column — the middle column
//     no longer scrolls (B);
//   * the Board column's actions are one quiet list of words, named as
//     Preparation and Analysis name them; the FEN field became „Paste FEN…";
//   * the move tree takes what the Moves column leaves;
//   * a student's Board column keeps only what saves, and the student's four
//     answers stand on one row under the board;
//   * on a phone held upright the moves and their actions come right under
//     the board, the engine after them, and the comment opens on its own.
//
// The columns themselves are PLAN-SESIJA phase 6's, on the owner's word, and
// this file does not move them.
//
// The app's own theme with real Roboto (`robotoTheme`), as phase 1 taught: a
// gate in `ThemeData.dark()` measures a different button.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/room_session_api.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/move_history_view.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

import 'support/landscape.dart' show expectOnScreen, sizeLabel;
import 'support/render_look.dart';

const _owners = Size(1536, 792);
const _smallest = Size(900, 700); // Windows' minimum window
const _phone = Size(360, 640);
const _sideways = Size(760, 360);

const _boardActions = Key('room-board-actions');

http.Client _server() => MockClient((req) async {
      if (req.url.path.endsWith('/library/positions')) {
        return http.Response(jsonEncode({'items': []}), 200);
      }
      if (req.url.path == '/trainer/students') {
        // One accepted student, so the trainer's seat teaches and „Make
        // exercise" is in the Board column.
        return http.Response(
            jsonEncode({
              'students': [
                {'id': 2, 'name': 'Ana', 'status': 'accepted'}
              ]
            }),
            200);
      }
      return http.Response('[]', 200);
    });

Future<void> _room(WidgetTester tester, Size size,
    {required String role}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = _server();
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: ChessGamePage(
      userSession: UserSession(
          id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
      roomCode: '192803',
      initialRole: role,
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      groupApi: GroupApiService(client: client),
      roomSessionApi: RoomSessionApi(authToken: 'tok', client: client),
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  // Torn down here rather than at the end of each case, so a case that fails
  // half way does not leave the room's socket and timers to the next one.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  final board = tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);
  board.controller.makeMove(from: from, to: to);
  board.onMove(from, to, '');
  await tester.pump(const Duration(milliseconds: 50));
}

Rect _rectOf(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Rect _rect(Finder f) {
  expect(f, findsOneWidget);
  return _rectOf(f.evaluate().single);
}

/// Inside the window and inside every scrolling box around it.
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

final _board = find.byType(ChessBoardWithOverlay);
final _strip = find.byType(MoveNavigationControls);
final _engine = find.byType(StockfishAnalysisWidget);
final _tree = find.byType(MoveHistoryView);

/// The Board column's actions as Preparation and Analysis name them.
const _trainerActions = [
  'Set up position…',
  'Paste FEN…',
  'Import PGN…',
  'Export PGN',
  'Save position',
  'Save analysis',
  'Make exercise',
];
const _keeping = ['Export PGN', 'Save position', 'Save analysis'];

void main() {
  setUpAll(loadRenderFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'tok',
      'user_id': 1,
      'user_email': 'e',
      'user_name': 'N',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
    await GameSessionService.instance.clear();
  });

  // ── 1. the window: the board takes the height (B) ───────────────────────

  group('the window, B', () {
    testWidgets('the board takes the height at 1536 x 792', (tester) async {
      await _room(tester, _owners, role: 'trener');
      final board = _rect(_board);
      expect(board.width, closeTo(board.height, 0.01));
      expect(board.width, greaterThanOrEqualTo(600),
          reason: 'board is ${board.size} at ${sizeLabel(_owners)} '
              '(491 before this phase)');
      _expectSeen(tester, _owners, _board);
    });

    // At 900 x 700 green before this phase: the board is bound by the width
    // there, and the case holds that a taller board does not undo it.
    for (final size in [_owners, _smallest]) {
      testWidgets('the middle column needs no scroll at ${sizeLabel(size)}',
          (tester) async {
        await _room(tester, size, role: 'trener');
        await _play(tester, 'e2', 'e4');
        _expectSeen(tester, size, _board);
        _expectSeen(tester, size, _strip);
        // Whatever scrolls around the board has nowhere to scroll to.
        _board.evaluate().single.visitAncestorElements((ancestor) {
          if (ancestor is StatefulElement &&
              ancestor.state is ScrollableState) {
            final position = (ancestor.state as ScrollableState).position;
            if (position.axis == Axis.vertical) {
              expect(position.maxScrollExtent, 0,
                  reason: 'the board\'s column scrolls by '
                      '${position.maxScrollExtent} at ${sizeLabel(size)}');
            }
          }
          return true;
        });
      });
    }

    testWidgets('the engine is at the top of the Moves column', (tester) async {
      await _room(tester, _owners, role: 'trener');
      expect(_engine, findsOneWidget);
      final engine = _rect(_engine);
      final board = _rect(_board);
      final moves = _rect(find.text('Moves'));
      expect(engine.left, greaterThan(board.right),
          reason: 'the engine is still beside or under the board');
      expect(engine.top, lessThan(moves.top),
          reason: 'the engine is under the Moves heading, not above it');
      _expectSeen(tester, _owners, _engine);
    });

    testWidgets('the tree takes what the Moves column leaves', (tester) async {
      await _room(tester, _owners, role: 'trener');
      await _play(tester, 'e2', 'e4');
      final tree = _rect(_tree);
      expect(tree.height, greaterThan(150),
          reason: 'the tree is still a fixed box of ${tree.height}');
      // And the column's last controls are there without a scroll.
      _expectSeen(tester, _owners, find.text('Undo arrow'));
      _expectSeen(tester, _owners, find.text('Clear all arrows'));
    });
  });

  // ── 2. the Board column ────────────────────────────────────────────────

  group('the Board column', () {
    testWidgets('the trainer\'s actions are one quiet list of words',
        (tester) async {
      await _room(tester, _owners, role: 'trener');
      final actions = find.byKey(_boardActions);
      expect(actions, findsOneWidget);
      for (final label in _trainerActions) {
        final word = find.descendant(of: actions, matching: find.text(label));
        expect(word, findsOneWidget, reason: '„$label" is not in the list');
        _expectSeen(tester, _owners, word);
      }
      for (final loud in [ElevatedButton, FilledButton, OutlinedButton]) {
        expect(find.descendant(of: actions, matching: find.byType(loud)),
            findsNothing,
            reason: 'a $loud is still among the Board column\'s actions');
      }
      // The FEN field is a word now; the Library's search is the column's
      // only field.
      expect(find.descendant(of: actions, matching: find.byType(TextField)),
          findsNothing);
      expect(find.text('Paste FEN string...'), findsNothing);
      // Each word is a target, not a line of text.
      for (final label in _trainerActions) {
        final target = find.ancestor(
            of: find.descendant(of: actions, matching: find.text(label)),
            matching: find.byWidgetPredicate((w) =>
                w is ButtonStyleButton || w is InkWell || w is ListTile));
        expect(target, findsWidgets, reason: '„$label" answers no tap');
        expect(
            _rectOf(target.evaluate().first).height, greaterThanOrEqualTo(40),
            reason: '„$label" is too small to hit');
      }
    });

    testWidgets('„Paste FEN…" opens the setup dialog on its FEN tab',
        (tester) async {
      await _room(tester, _owners, role: 'trener');
      expect(find.text('Paste FEN…'), findsOneWidget);
      await tester.tap(find.text('Paste FEN…'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final dialog = find.byType(AnalysisBoardSetupDialog);
      expect(dialog, findsOneWidget);
      expect(tester.widget<AnalysisBoardSetupDialog>(dialog).initialTab,
          BoardSetupTab.fen);
      Navigator.of(tester.element(dialog)).pop();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('a student keeps only what saves, and the Library',
        (tester) async {
      await _room(tester, _owners, role: 'ucenik');
      final actions = find.byKey(_boardActions);
      expect(actions, findsOneWidget);
      for (final label in _keeping) {
        expect(find.descendant(of: actions, matching: find.text(label)),
            findsOneWidget,
            reason: 'a student lost „$label"');
      }
      // Anything that loads a position into the room, under its old name or
      // its new one.
      for (final gone in ['Set up position', 'Paste FEN', 'Import PGN']) {
        expect(find.textContaining(gone, skipOffstage: false), findsNothing,
            reason: 'a student is offered „$gone"');
      }
      expect(find.text('Make exercise', skipOffstage: false), findsNothing);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('a student\'s four answers stand on one row', (tester) async {
      await _room(tester, _owners, role: 'ucenik');
      final answers = [
        'Show my position to trainer',
        'Yes',
        'No',
        "I didn't understand",
      ];
      final first = _rect(find.text(answers.first));
      for (final a in answers) {
        final r = _rect(find.text(a));
        expect(r.center.dy, closeTo(first.center.dy, 2),
            reason: '„$a" is on another row');
        _expectSeen(tester, _owners, find.text(a));
      }
      // Under the board, as before.
      expect(first.top, greaterThan(_rect(_board).bottom - 1));
    });
  });

  // ── 3. the phone ───────────────────────────────────────────────────────

  group('the phone', () {
    testWidgets('upright: board, strip, moves and their actions, then engine',
        (tester) async {
      await _room(tester, _phone, role: 'trener');
      await _play(tester, 'e2', 'e4');
      final board = _rect(_board);
      final strip = _rect(_strip);
      final tree = _rect(_tree);
      final mainLine = _rect(find.text('To main line'));
      final engine = _rect(_engine);
      expect(strip.top, greaterThanOrEqualTo(board.bottom - 1));
      expect(tree.top, greaterThan(strip.top),
          reason: 'the moves are not under the strip');
      expect(mainLine.top, greaterThan(tree.top));
      expect(engine.top, greaterThan(mainLine.top),
          reason: 'the engine still comes before the moves');
    });

    testWidgets('upright: the comment opens on its own, and keeps its text',
        (tester) async {
      await _room(tester, _phone, role: 'trener');
      await _play(tester, 'e2', 'e4');
      final field =
          find.byKey(const Key('room-comment-field'), skipOffstage: false);
      expect(field, findsNothing,
          reason: 'the comment field is still drawn in the phone\'s column');
      expect(find.text('Comment…'), findsOneWidget);
      await tester.tap(find.text('Comment…'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(field, findsOneWidget);
      _expectSeen(tester, _phone, field);
      await tester.enterText(field, 'Castle next');
      await tester.pump();
      // Closed and opened again: the text is the move's, not the sheet's.
      Navigator.of(tester.element(field)).pop();
      await tester.pump(const Duration(milliseconds: 400));
      expect(field, findsNothing);
      await tester.tap(find.text('Comment…'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<TextField>(field).controller?.text, 'Castle next',
          reason: 'the comment belonged to the sheet, not to the move');
      Navigator.of(tester.element(field)).pop();
      await tester.pump(const Duration(milliseconds: 400));
    });

    for (final (size, role) in [
      (_owners, 'trener'),
      (_smallest, 'trener'),
      (_sideways, 'trener'),
      (_phone, 'trener'),
    ]) {
      // Green before this phase as well, and kept for after it: the engine
      // moves into the Moves column, which is also drawn sideways and on a
      // phone, where the engine already had a place of its own.
      testWidgets('one engine panel at ${sizeLabel(size)}', (tester) async {
        await _room(tester, size, role: role);
        expect(_engine, findsOneWidget,
            reason: 'the engine is drawn twice, or not at all');
      });
    }
  });
}
