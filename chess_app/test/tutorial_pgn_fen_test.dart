import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';

/// T5 of `docs/PLAN-PGN-TEKST.md` — a pasted game brings its own position, and
/// what happens to it is asked rather than assumed.
///
/// This is the branch that moves the board a **child** opens the part on, which
/// is why it is a question and not a rule. And it is the ordinary case rather
/// than the exotic one: a game copied out of a book or off Lichess nearly
/// always starts somewhere else than the part it is being pasted into, and
/// without the question every move of it is rejected at once with a count that
/// explains nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const endgameFen = '4k3/8/5K2/4P3/8/8/8/8 w - - 0 12';

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  late List<Map<String, dynamic>> saves;

  LessonApiService recordingApi() {
    saves = [];
    return LessonApiService(
      authToken: 'tok',
      client: MockClient((req) async {
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

  var nextLessonId = 900;

  Map<String, dynamic> lesson({String fen = startFen, String pgn = '1. e4'}) =>
      {
        'id': nextLessonId++,
        'title': 'Otvaranje',
        'position_list': [
          {
            'id': 'step-1',
            'fen': fen,
            'title': 'Deo 1',
            'pgn': pgn,
            'kind': 'show',
          },
        ],
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Future<void> open(WidgetTester tester,
      {String fen = startFen, String pgn = '1. e4'}) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lesson(fen: fen, pgn: pgn)),
        lessonApi: recordingApi(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pgn-tab')));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> paste(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('pgn-field')), text);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pgn-apply')));
    await tester.pumpAndSettle();
  }

  Future<Map> saveAndStep(WidgetTester tester) async {
    await tester.tap(find.text('Sačuvaj tutorijal'));
    await tester.pumpAndSettle();
    expect(saves, hasLength(1));
    return (saves.single['positionList'] as List).single as Map;
  }

  /// A little endgame, written the way a book would hand it over.
  const pastedGame = '[Event "Knjiga"]\n'
      '[SetUp "1"]\n'
      '[FEN "$endgameFen"]\n\n'
      '{ Kralj ispred pešaka. } 12. Ke6 { Zauzima opoziciju. } Kf8 13. Kd7 *';

  group('a pasted position is asked about', () {
    testWidgets('when it differs from the one the part stands on',
        (tester) async {
      await open(tester);

      await paste(tester, pastedGame);

      expect(find.text('Tekst počinje iz druge pozicije'), findsOneWidget,
          reason: 'the position a child opens on was changed, or refused, '
              'without anybody being asked');

      await close(tester);
    });

    testWidgets('and „Uzmi tu poziciju" takes the game whole', (tester) async {
      await open(tester);
      await paste(tester, pastedGame);

      await tester.tap(find.text('Uzmi tu poziciju'));
      await tester.pumpAndSettle();

      final step = await saveAndStep(tester);
      final line = LessonStepLine.read(
        fen: step['fen'].toString(),
        pgn: step['pgn']?.toString(),
      );

      expect(MoveTree.samePosition(step['fen'].toString(), endgameFen), isTrue,
          reason: 'the part still opens on its old position, so the line that '
              'was pasted cannot be played from it');
      expect(line.replays, isTrue);
      expect(line.line.movesSan, ['Ke6', 'Kf8', 'Kd7']);
      expect(line.line.rootComment, 'Kralj ispred pešaka.',
          reason: 'the note the game opened with was dropped on the way in');
      expect(line.line.comments.first, 'Zauzima opoziciju.');

      await close(tester);
    });

    testWidgets('„Zadrži postojeću" refuses the text and changes nothing',
        (tester) async {
      await open(tester);
      await paste(tester, pastedGame);

      await tester.tap(find.text('Zadrži postojeću'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nije primenjeno'), findsWidgets,
          reason: 'keeping the position silently dropped a text that cannot be '
              'played from it — the trainer is left believing it was applied');

      final step = await saveAndStep(tester);
      final line = LessonStepLine.read(
        fen: step['fen'].toString(),
        pgn: step['pgn']?.toString(),
      );

      expect(MoveTree.samePosition(step['fen'].toString(), startFen), isTrue);
      expect(line.line.movesSan, ['e4'],
          reason: 'the pasted moves were applied to a position they do not '
              'belong to');

      await close(tester);
    });

    testWidgets('„Odustani" leaves the part and the text alone',
        (tester) async {
      await open(tester);
      await paste(tester, pastedGame);

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      // The difference between backing out and keeping the position is exactly
      // one sentence: „Odustani" is silent, because nothing was attempted. A
      // mutation that dropped the cancel branch left every other assertion here
      // green — the outcome is the same, and only the noise differs.
      expect(find.textContaining('Nije primenjeno'), findsNothing,
          reason: 'backing out of the question reported a failure at something '
              'the trainer had just called off');

      final field = tester
          .widget<TextField>(find.byKey(const Key('pgn-field')))
          .controller!;
      expect(field.text, contains('Ke6'),
          reason: 'backing out of the question threw away the text that was '
              'pasted');

      final step = await saveAndStep(tester);
      expect(
          LessonStepLine.read(
            fen: step['fen'].toString(),
            pgn: step['pgn']?.toString(),
          ).line.movesSan,
          ['e4']);

      await close(tester);
    });
  });

  group('a text that brought no position of its own', () {
    // The trainer's complaint on 7.9.2026 was that pasting one of these got
    // „samo mi ovo javi" — the count of moves that would not play, and no
    // question. There was nothing to ask *about*: a PGN with no `[FEN]` says
    // nothing about where it starts. But a game without a header is a game
    // from the standard opening position, so when the text plays cleanly from
    // **there** and not from here, the same question can be asked — and it is
    // grounded in the reading rather than in a guess about what was meant.

    testWidgets('is offered the opening position when it plays from there',
        (tester) async {
      await open(tester, fen: endgameFen, pgn: '12. Ke6');

      await paste(tester, '1. e4 e5 2. Nf3 { Italijanka. }');

      expect(find.text('Tekst ne počinje odavde'), findsOneWidget);

      await tester.tap(find.text('Uzmi početnu poziciju'));
      await tester.pumpAndSettle();

      final step = await saveAndStep(tester);
      expect(step['fen'], startFen,
          reason: 'the part was moved onto the position the text plays from');
      expect(
          LessonStepLine.read(
            fen: step['fen'].toString(),
            pgn: step['pgn']?.toString(),
          ).line.movesSan,
          ['e4', 'e5', 'Nf3']);

      await close(tester);
    });

    testWidgets('„Zadrži postojeću" refuses it and says why', (tester) async {
      await open(tester, fen: endgameFen, pgn: '12. Ke6');

      await paste(tester, '1. e4 e5 2. Nf3');
      await tester.tap(find.text('Zadrži postojeću'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nema svoju polaznu poziciju'), findsOneWidget,
          reason: 'the count of rejected moves alone is what sent the trainer '
              'looking for a bug');

      final step = await saveAndStep(tester);
      expect(step['fen'], endgameFen);
      expect(step['pgn'].toString(), contains('Ke6'));

      await close(tester);
    });

    testWidgets('„Odustani" leaves the part alone and reports nothing',
        (tester) async {
      await open(tester, fen: endgameFen, pgn: '12. Ke6');

      await paste(tester, '1. e4 e5 2. Nf3');
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nije primenjeno'), findsNothing,
          reason: 'a question the trainer backed out of is not a failure');

      final step = await saveAndStep(tester);
      expect(step['fen'], endgameFen);

      await close(tester);
    });

    testWidgets(
        'and a text that plays from neither is refused without a '
        'question', (tester) async {
      // Offering to move the part onto a position that also rejects moves
      // would trade one silent loss for another. The message says what is
      // missing, which is the whole of the fix for that case.
      await open(tester, fen: endgameFen, pgn: '12. Ke6');

      await paste(tester, '13. Kd7 Kf7');

      expect(find.text('Tekst ne počinje odavde'), findsNothing);
      expect(
          find.textContaining('nema svoju polaznu poziciju'), findsOneWidget);

      await close(tester);
    });
  });

  group('and not asked about when there is nothing to ask', () {
    testWidgets('a text with no position of its own', (tester) async {
      await open(tester);

      await paste(tester, '1. d4 d5');

      expect(find.text('Tekst počinje iz druge pozicije'), findsNothing);

      final step = await saveAndStep(tester);
      expect(
          LessonStepLine.read(
            fen: step['fen'].toString(),
            pgn: step['pgn']?.toString(),
          ).line.movesSan,
          ['d4', 'd5']);

      await close(tester);
    });

    testWidgets('a position that differs only in the clocks', (tester) async {
      // The comparison is placement, side, castling and en passant. A halfmove
      // clock two moves further on is the same board to a child, and a question
      // about it would be a question nobody can answer.
      await open(tester, fen: endgameFen, pgn: '12. Ke6');

      await paste(
          tester,
          '[SetUp "1"]\n[FEN "4k3/8/5K2/4P3/8/8/8/8 w - - 7 19"]\n\n'
          '19. Ke6 Kf8 *');

      expect(find.text('Tekst počinje iz druge pozicije'), findsNothing,
          reason: 'a question was asked about two counters nobody can see');

      final step = await saveAndStep(tester);
      expect(
          LessonStepLine.read(
            fen: step['fen'].toString(),
            pgn: step['pgn']?.toString(),
          ).line.movesSan,
          ['Ke6', 'Kf8']);

      await close(tester);
    });
  });
}
