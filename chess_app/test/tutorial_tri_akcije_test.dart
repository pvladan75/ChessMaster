// Three actions instead of „dodaj deo", and parts that are called by what they
// say.
//
// The trainer's own words for what was wrong: they had to think about „Delovi"
// and about when to add one. A part is not something to plan — it is what a
// tutorial falls into once you ask a question, because a step's `pgn` is not
// redacted on its way to a child and a question carrying its line hands over
// the answer. So the panel offers what the next step *is*:
//
//   „Novi prikaz"             a demonstration after this one
//   „Traži potez na tabli"    ask here, `ask_move`
//   „Traži odgovor iz liste"  ask here, `ask_choice`
//
// and the parts that come out of that are named by their first sentence.
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

  group('the three things a trainer can do next', () {
    testWidgets('are the three buttons, and none of them says „deo"',
        (tester) async {
      await open(tester);

      expect(find.text('New demonstration'), findsOneWidget);
      expect(find.text('Find the move'), findsOneWidget);
      expect(find.text('Choose the answer'), findsOneWidget);
      expect(find.text('+ Dodaj deo'), findsNothing);
      expect(find.text('Delovi tutorijala'), findsNothing);

      await close(tester);
    });

    testWidgets('asking cuts the demonstration and keeps what followed',
        (tester) async {
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Italijanka');
      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      await play(tester, 'g1', 'f3');

      // Standing after 2. Nf3 and asking what Black plays. The move that
      // followed does not exist yet — this is the end of the line — so the
      // trainer would play it; here the point is the shape.
      await press(tester, 'ask-move');

      final parts = await save(tester, api);

      expect(parts, hasLength(2));
      expect(parts.first['kind'], 'show');
      expect(parts.first['pgn'].toString(), contains('Nf3'));
      expect(parts.last['kind'], 'ask_move');
      expect(parts.last.containsKey('pgn'), isFalse,
          reason: 'a question that carries its line shows the answer on the '
              'move strip');

      await close(tester);
    });

    testWidgets('and the answer that was already played becomes the solution',
        (tester) async {
      final api = await open(tester);
      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      await play(tester, 'g1', 'f3');
      await play(tester, 'b8', 'c6');

      // Back to the position after 2. Nf3 and ask there.
      await tester.tap(find.byTooltip('Previous move'));
      await tester.pumpAndSettle();
      await press(tester, 'ask-move');

      final parts = await save(tester, api);

      expect(parts, hasLength(3));
      expect(parts[1]['kind'], 'ask_move');
      expect(parts[1]['solutionSan'], 'Nc6');
      expect(parts[2]['kind'], 'show');
      expect(parts[2]['pgn'].toString(), contains('Nc6'),
          reason: 'the continuation was thrown away with the split');

      await close(tester);
    });

    testWidgets('„Traži odgovor iz liste" asks the same question differently',
        (tester) async {
      // Not asserted on the request, and deliberately: a question with offered
      // answers and no answers on it is refused before anything is sent, which
      // is a different rule and has its own test. What is being asked here is
      // that the same split happens and the kind is the other one.
      await open(tester);
      await play(tester, 'e2', 'e4');
      await press(tester, 'ask-choice');

      expect(find.text('Choice'), findsOneWidget,
          reason: 'the chip on the row says what the part is');
      expect(find.text('Show'), findsOneWidget,
          reason: 'and the demonstration in front of it is still a prikaz');

      await close(tester);
    });

    testWidgets('a part with nothing on it just becomes the question',
        (tester) async {
      final api = await open(tester);
      await type(tester, 'tutorial-title', 'Otvaranje');
      await press(tester, 'ask-move');

      final parts = await save(tester, api);

      expect(parts, hasLength(1),
          reason: 'there was no demonstration to cut off');
      expect(parts.single['kind'], 'ask_move');

      await close(tester);
    });

    testWidgets('the trainer is left standing on the question they asked',
        (tester) async {
      await open(tester);
      await play(tester, 'e2', 'e4');
      await press(tester, 'ask-move');

      // The editor shows the question's own fields, on the position it asks
      // about — not the demonstration in front of it.
      expect(find.byKey(const Key('example-instruction')), findsOneWidget);

      await close(tester);
    });
  });

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
