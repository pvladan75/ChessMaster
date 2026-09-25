// Parts that are called by what they say, and the one question left when a
// new one is made: where it starts.
//
// The trainer's own words for what was wrong: they had to think about „Delovi"
// and about when to add one. This file was written for three actions — a new
// demonstration, „find the move" and „choose the answer" — and the two that
// asked went with the questions (docs/PLAN-TUTORIJAL-VIDEO.md, phase 4). The
// parts are still named by their first sentence.
//
// Where it matters, this asserts on the **request**: the panel showing a name
// is not evidence that the child is sent it, which is batch 57's finding, and
// the whole reason the label and the wire read one function.

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
        return http.Response(jsonEncode({'id': 77}), 201);
      }),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const openingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

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
        entry: const TutorialEntry.blank('Opozicija'),
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

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String value) async {
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.pumpAndSettle();
  }

  /// The parts as they are sent, which is the only place a name is a fact.
  Future<List<Map<String, dynamic>>> save(
      WidgetTester tester, _RecordingApi api) async {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1));
    return (api.saves.single['positionList'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  group('a part is called by what it says', () {
    testWidgets('the list reads the sentences, not the numbering',
        (tester) async {
      await open(tester);
      await type(tester, 'example-sentence', 'Zauzimamo centar.');

      expect(find.text('Zauzimamo centar.'), findsWidgets);
      expect(find.text('Part 1'), findsNothing);

      await close(tester);
    });

    testWidgets('and that is the name the child is sent', (tester) async {
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Otvaranje');
      await type(tester, 'example-sentence', 'Zauzimamo centar.');

      final parts = await save(tester, api);

      expect(parts.single['title'], 'Zauzimamo centar.');

      await close(tester);
    });

    testWidgets('a name the trainer types wins, and emptying it gives it back',
        (tester) async {
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Otvaranje');
      await type(tester, 'example-sentence', 'Zauzimamo centar.');

      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();
      await type(tester, 'section-name-field', 'Uvod');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(find.text('Uvod'), findsOneWidget);

      final parts = await save(tester, api);
      expect(parts.single['title'], 'Uvod');

      // Emptying the field is not a failure to name it: a part with no name of
      // its own goes back to being called by what it says.
      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();
      await type(tester, 'section-name-field', '');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(find.text('Uvod'), findsNothing);
      expect(find.text('Zauzimamo centar.'), findsWidgets);

      await close(tester);
    });

    testWidgets('a part with no words at all still has a row to click',
        (tester) async {
      await open(tester);
      await play(tester, 'e2', 'e4');

      expect(find.text('Part 1'), findsOneWidget,
          reason: 'the fallback is the one place that word is still read');

      await close(tester);
    });
  });

  group('the one question left is about a position, not about parts', () {
    testWidgets('„Odavde" starts where this line ended', (tester) async {
      await open(tester);
      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      final ended = board(tester).controller.getFen();

      await press(tester, 'add-show');
      await tester.tap(find.text('From here'));
      await tester.pumpAndSettle();

      expect(board(tester).controller.getFen().split(' ').take(2).join(' '),
          ended.split(' ').take(2).join(' '));

      await close(tester);
    });

    testWidgets('„Nova tabla" starts on a board of its own', (tester) async {
      await open(tester);
      await play(tester, 'e2', 'e4');

      await press(tester, 'add-show');
      await tester.tap(find.text('New board'));
      await tester.pumpAndSettle();

      expect(board(tester).controller.getFen().split(' ').first,
          openingFen.split(' ').first);

      await close(tester);
    });
  });
}
