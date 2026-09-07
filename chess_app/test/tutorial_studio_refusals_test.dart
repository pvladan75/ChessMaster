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

/// P8 of `docs/PLAN-STUDIO-REDIZAJN.md`: the refusals of §7 live in the studio.
///
/// They were paid for in `LessonStepEditorPanel`, which D8 retires on Windows —
/// and **nothing is unlinked until its refusals are proved somewhere else.**
/// This file is that proof.
///
/// The load-bearing one is the answer leak. A step's `pgn` is not redacted on
/// its way to a child — the line *is* the lesson — and the viewer draws the move
/// strip for every kind, so an `ask_move` step whose line runs on from the
/// position being asked about hands the child its own answer through „Sledeći
/// potez". The server cannot make this refusal: it stores `pgn` as opaque text
/// and has no PGN reader, and giving it one would be a second parser disagreeing
/// with the app's. So the app makes it, in three parts — asked when the kind is
/// chosen, shown on a tutorial already in that state, and refused at save.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

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

  /// A different lesson id per test, and it is not decoration.
  ///
  /// The studio adopts a stored draft **when its `lessonId` matches** the
  /// tutorial being opened — D4, and the whole point of that rule. A screen
  /// flushes its draft on dispose, so two tests opening „lesson 31" hand the
  /// second one the first one's unfinished work: this file watched a perfectly
  /// good question be refused for two correct answers left behind by the test
  /// before it. Shared fixtures and a singleton draft slot is all it takes.
  var nextLessonId = 100;

  Map<String, dynamic> lessonWith(List<Map<String, dynamic>> steps) => {
        'id': nextLessonId++,
        'title': 'Otvaranje',
        'position_list': steps,
      };

  Map<String, dynamic> step({
    String title = 'Deo 1',
    String? pgn,
    String kind = 'show',
    String? instruction,
    List<Map<String, dynamic>>? choices,
  }) =>
      {
        'fen': startFen,
        'title': title,
        if (pgn != null) 'pgn': pgn,
        'kind': kind,
        if (instruction != null) 'instruction': instruction,
        if (choices != null) 'choices': choices,
      };

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

  Future<void> openLesson(
      WidgetTester tester, Map<String, dynamic> lesson) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lesson),
        lessonApi: recordingApi(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Sačuvaj tutorijal'));
    await tester.pumpAndSettle();
  }

  Future<void> pickKind(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('example-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('the answer leak', () {
    testWidgets('a question that carries its own line is not saved',
        (tester) async {
      await openLesson(
          tester,
          lessonWith([
            step(title: 'Pitanje', pgn: '1. e4 e5 2. Nf3', kind: 'ask_move'),
          ]));

      await save(tester);

      expect(saves, isEmpty, reason: 'the tutorial was sent as it stands');
      expect(find.textContaining('Pitanje'), findsWidgets,
          reason: 'the refusal does not say which part is wrong, so a trainer '
              'with fourteen parts has to find it themselves');

      await close(tester);
    });

    testWidgets('a question with no moves is saved, marks and words included',
        (tester) async {
      // The one this file was written for. „Nađi najbolji potez" plus an arrow
      // pointing at the weak square is a whole question — it carries a comment
      // and `[%cal]` on its root and **no line at all**, so nothing can be
      // paged to. Judging a part by whether its exported `pgn` is empty refuses
      // it anyway, because the exporter writes the root's note and marks ahead
      // of move one. P7a made this the normal way to write a question.
      await openLesson(
          tester,
          lessonWith([
            step(
              title: 'Pitanje',
              pgn: '{ Nađi najbolji potez. [%cal Gd1h5][%csl Rf7] } *',
              kind: 'ask_move',
            ),
          ]));

      await save(tester);

      expect(saves, hasLength(1),
          reason: 'a question with no moves was refused for carrying a line it '
              'does not have — the note and the arrows on its starting '
              'position were read as one');

      await close(tester);
    });

    testWidgets('choosing „traži potez" on a part with a line asks first',
        (tester) async {
      await openLesson(tester, lessonWith([step(pgn: '1. e4 e5 2. Nf3')]));

      await pickKind(tester, 'Traži potez na tabli');

      expect(find.text('Dete bi videlo odgovor'), findsOneWidget,
          reason: 'the kind changed with no question asked, and the line the '
              'trainer wrote is now the answer to their own question');

      await close(tester);
    });

    testWidgets('„Odustani" leaves the part exactly as it was', (tester) async {
      await openLesson(tester, lessonWith([step(pgn: '1. e4 e5 2. Nf3')]));

      await pickKind(tester, 'Traži potez na tabli');
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      await save(tester);

      expect(saves, hasLength(1),
          reason: 'the part was left in the state the '
              'trainer backed out of, so the save refused it');
      final sent = (saves.single['positionList'] as List).single as Map;
      expect(sent['kind'], 'show',
          reason: 'backing out of the question still changed the kind');
      expect(sent['pgn'].toString(), contains('e4'),
          reason: 'backing out of the question took the line anyway');

      await close(tester);
    });

    testWidgets('accepting drops the line and asks the question',
        (tester) async {
      await openLesson(tester, lessonWith([step(pgn: '1. e4 e5 2. Nf3')]));

      await pickKind(tester, 'Traži potez na tabli');
      await tester.tap(find.text('Ukloni liniju i postavi pitanje'));
      await tester.pumpAndSettle();

      await save(tester);

      expect(saves, hasLength(1));
      final sent = (saves.single['positionList'] as List).single as Map;
      expect(sent['kind'], 'ask_move');
      expect(sent['pgn']?.toString() ?? '', isNot(contains('e4')),
          reason: 'the line the child could page through is still there');

      await close(tester);
    });

    testWidgets('a tutorial already in that state says so when it opens',
        (tester) async {
      // Tutorials saved before this refusal existed can carry the leak, and the
      // quiet version of this bug is a child who simply stops getting anything
      // wrong. Hydration reads every part, not only the open one.
      await openLesson(
          tester,
          lessonWith([
            step(title: 'Prvi'),
            step(title: 'Drugi', pgn: '1. e4 e5', kind: 'ask_move'),
          ]));

      expect(find.textContaining('Dete bi videlo odgovor'), findsWidgets,
          reason: 'a tutorial that already hands the child its answer opened '
              'with nothing said about it');

      await close(tester);
    });
  });

  group('a question from a list', () {
    Map<String, dynamic> choice(String text, {bool correct = false}) =>
        {'text': text, 'correct': correct};

    testWidgets('one answer is not a question', (tester) async {
      await openLesson(
          tester,
          lessonWith([
            step(
              kind: 'ask_choice',
              instruction: 'Šta beli postiže?',
              choices: [choice('Zauzima centar.', correct: true)],
            ),
          ]));

      await save(tester);

      expect(saves, isEmpty,
          reason: 'a child was offered a single answer to pick from');

      await close(tester);
    });

    testWidgets('more than four is refused too', (tester) async {
      await openLesson(
          tester,
          lessonWith([
            step(
              kind: 'ask_choice',
              instruction: 'Šta beli postiže?',
              choices: [
                choice('Prvi', correct: true),
                choice('Drugi'),
                choice('Treći'),
                choice('Četvrti'),
                choice('Peti'),
              ],
            ),
          ]));

      await save(tester);

      expect(saves, isEmpty);

      await close(tester);
    });

    testWidgets('a stored question with two right answers comes back with one',
        (tester) async {
      // Not a refusal, and the test that asked for one was asking the screen to
      // do something it cannot: the answers are a radio group, so „two correct"
      // has no representation in the editor at all. What matters is that the
      // normalisation is not silent about *which* one it kept — the first, the
      // one the list already showed as chosen.
      await openLesson(
          tester,
          lessonWith([
            step(
              kind: 'ask_choice',
              instruction: 'Šta beli postiže?',
              choices: [
                choice('Prvi', correct: true),
                choice('Drugi', correct: true),
              ],
            ),
          ]));

      await save(tester);

      expect(saves, hasLength(1));
      final sent = (saves.single['positionList'] as List).single as Map;
      expect(sent['choices'], [
        {'text': 'Prvi', 'correct': true},
        {'text': 'Drugi', 'correct': false},
      ]);

      await close(tester);
    });

    testWidgets('a question with no right answer at all is refused',
        (tester) async {
      // The state the editor *can* produce: two answers typed, neither picked.
      await openLesson(
          tester,
          lessonWith([
            step(
              kind: 'ask_choice',
              instruction: 'Šta beli postiže?',
              choices: [choice('Prvi'), choice('Drugi')],
            ),
          ]));

      await save(tester);

      expect(saves, isEmpty,
          reason: 'a question with nothing marked correct was sent, and every '
              'answer a child picks is wrong');

      await close(tester);
    });

    testWidgets('two answers with exactly one correct is sent', (tester) async {
      await openLesson(
          tester,
          lessonWith([
            step(
              kind: 'ask_choice',
              instruction: 'Šta beli postiže?',
              choices: [
                choice('Zauzima centar.', correct: true),
                choice('Napada kralja.'),
              ],
            ),
          ]));

      await save(tester);

      expect(saves, hasLength(1),
          reason: 'a question that is exactly right was refused');

      await close(tester);
    });
  });
}
