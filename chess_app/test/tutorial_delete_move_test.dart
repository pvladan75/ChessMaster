// Taking a move back, from the surfaces the tutorial is written on.
//
// The tree's own menu has drawn „Unapredi u Glavnu Liniju" and „Obriši Ovu
// Varijantu" since the Analysis Studio was built, and the tutorial studio took
// the widget without either callback — so the sheet opened, the trainer pressed
// „Obriši", and the move stayed. The only way to take a move back was to retype
// the line in the „PGN" tab, which is where the owner found it on 7.9.2026:
// „može iz pgn prikaza … ali ne iz stabla ili toka".
//
// Two rules are asserted here beyond the deletion itself. A move with words,
// drawings or moves under it asks first, and a bare move does not — a dialog on
// every deletion is a dialog that gets dismissed unread. And the cursor never
// stays inside what was removed: the board is the trainer's only view of where
// they are, and one left on a detached position is how the board and the tree
// quietly part company.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> saves;

  factory _RecordingApi() {
    final saves = <Map<String, dynamic>>[];
    return _RecordingApi._(
      saves,
      MockClient((req) async {
        if (req.body.isNotEmpty) {
          final body = jsonDecode(req.body);
          if (body is Map && body.containsKey('positionList')) {
            saves.add(Map<String, dynamic>.from(body));
          }
        }
        return http.Response(jsonEncode({'id': 91}), 201);
      }),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  Future<_RecordingApi> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = _RecordingApi();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: const TutorialEntry.blank('Italijanka'),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    board(tester).onMove(from, to, '');
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byTooltip('Prethodni potez'));
      await tester.pumpAndSettle();
    }
  }

  /// The line as it is sent — the only place a deletion is a fact.
  Future<String> savedLine(WidgetTester tester, _RecordingApi api) async {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
    final parts = (api.saves.last['positionList'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return parts.first['pgn']?.toString() ?? '';
  }

  testWidgets('a bare move is taken back without a question', (tester) async {
    final api = await open(tester);
    await play(tester, 'e2', 'e4');
    await play(tester, 'e7', 'e5');
    await play(tester, 'g1', 'f3');

    // The last beat of „Tok" is 2. Nf3.
    await tester.tap(find.byKey(const Key('beat-delete-3')));
    await tester.pumpAndSettle();

    expect(find.text('Delete move?'), findsNothing,
        reason: 'a move with nothing written under it has nothing to lose');

    final pgn = await savedLine(tester, api);
    expect(pgn, contains('e5'));
    expect(pgn, isNot(contains('Nf3')));

    await close(tester);
  });

  testWidgets('a move with words under it asks first, and „Odustani" keeps it',
      (tester) async {
    final api = await open(tester);
    await play(tester, 'e2', 'e4');
    await tester.enterText(
        find.byKey(const Key('example-sentence')), 'Zauzimamo centar.');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('beat-delete-1')));
    await tester.pumpAndSettle();

    expect(find.text('Delete move?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await savedLine(tester, api), contains('e4'),
        reason: 'a question that was answered „no" must change nothing');

    await close(tester);
  });

  testWidgets('and „Obriši" takes the move and the words with it',
      (tester) async {
    final api = await open(tester);
    await play(tester, 'e2', 'e4');
    await tester.enterText(
        find.byKey(const Key('example-sentence')), 'Zauzimamo centar.');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('beat-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final pgn = await savedLine(tester, api);
    expect(pgn, isNot(contains('e4')));
    expect(pgn, isNot(contains('Zauzimamo centar')));

    await close(tester);
  });

  testWidgets('the trainer is moved off a move that is being deleted',
      (tester) async {
    await open(tester);
    await play(tester, 'e2', 'e4');
    await play(tester, 'e7', 'e5');

    // Standing on 1... e5 and deleting 1. e4, which is above it. It carries a
    // move under it, so it asks.
    await tester.tap(find.byKey(const Key('beat-delete-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // The opening position, which is what is left of the part.
    expect(find.text('Starting position'), findsOneWidget);
    expect(find.text('after 1. e4'), findsNothing);
    expect(board(tester).controller.getFen().split(' ').first,
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        reason: 'the board may never stand on a position the part lost');

    await close(tester);
  });

  testWidgets('the opening position of a part carries no delete',
      (tester) async {
    await open(tester);
    await play(tester, 'e2', 'e4');

    expect(find.byKey(const Key('beat-delete-1')), findsOneWidget);
    expect(find.byKey(const Key('beat-delete-0')), findsNothing,
        reason: 'the position a part opens on is not a move; „Obriši deo" is '
            'the way to throw that away');

    await close(tester);
  });

  testWidgets('a sideline can be made the line the child walks',
      (tester) async {
    final api = await open(tester);
    await play(tester, 'e2', 'e4');
    await play(tester, 'e7', 'e5');
    await back(tester, 1);
    await play(tester, 'c7', 'c5'); // a second reply to 1. e4

    // Through the tree's own menu, on the „Stablo" tab — the node is drawn as
    // a `RichText`, so it is found by the text it renders rather than by a key
    // no user can see.
    await tester.tap(find.text('Tree'));
    await tester.pumpAndSettle();
    await tester.longPress(find.textContaining('c5').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unapredi u Glavnu Liniju (Main Line)'));
    await tester.pumpAndSettle();

    final pgn = await savedLine(tester, api);
    expect(pgn, contains('1. e4 c5'),
        reason: 'the promoted line is the one the child is walked down');

    await close(tester);
  });
}
