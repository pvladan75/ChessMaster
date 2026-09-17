// Phase 4 of `docs/PLAN-PGN-TUTORIJAL.md`: the door a tutorial leaves by.
//
// What ends up in which game is `pgnGamesOfTutorial`'s, and it is tested in
// `pgn_tutorial_export_test.dart`. What is left here is the wiring: that the
// studio's button opens the dialog, that the dialog says what the file will
// hold and what it cannot carry, and that the picker is handed the tutorial's
// own name and the text of every game.
//
// The file chooser is a platform channel, so `debugSavePgnFile` stands in for
// it — the same seam the Analysis studio's export already uses.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/pgn_file_saver.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_pgn_export_dialog.dart';
import 'package:chess_app/models/user_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  // The position `1. e4 e5` runs out at, en passant square and all — which is
  // what `addSection(continueFromEnd: true)` writes, and what the viewer's own
  // join test compares. A part whose FEN says `-` there is a different board.
  const afterE4E5 =
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';
  const endingFen = '6k1/5pp1/7p/8/8/8/5PPP/R5K1 w - - 0 1';

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  LessonApiService api() => LessonApiService(
        authToken: 'tok',
        client: MockClient(
            (req) async => http.Response(jsonEncode({'id': 31}), 200, headers: {
                  'content-type': 'application/json; charset=utf-8',
                })),
      );

  /// A tutorial of two parts that continue one another, and a third on a board
  /// of its own: one game and then another.
  Map<String, dynamic> lesson({String title = 'Two lessons'}) => {
        'id': 31,
        'title': title,
        'position_list': [
          {
            'id': 'step-1',
            'fen': startFen,
            'title': 'Part 1',
            'kind': 'show',
            'pgn': '1. e4 e5 *',
          },
          {
            'id': 'step-2',
            'fen': afterE4E5,
            'title': 'Part 2',
            'kind': 'show',
            'pgn': '2. Nf3 Nc6 *',
          },
          {
            'id': 'step-3',
            'fen': endingFen,
            'title': 'Part 3',
            'kind': 'show',
            'pgn': '1. Ra8+ Kh7 *',
          },
        ],
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  tearDown(() {
    debugSavePgnFile = null;
  });

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openStudio(
    WidgetTester tester, {
    Map<String, dynamic>? saved,
    Size size = const Size(1600, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Closed even when an expectation fails: a studio left mounted flushes its
    // draft into the one slot the next test reads.
    addTearDown(() => close(tester));

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(saved ?? lesson()),
        lessonApi: api(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openExport(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('export-tutorial-pgn')));
    await tester.pumpAndSettle();
  }

  group('the dialog', () {
    testWidgets('says how the tutorial comes apart', (tester) async {
      await openStudio(tester);
      await openExport(tester);

      expect(find.text('Save tutorial as .pgn'), findsOneWidget);
      expect(find.text(pgnExportSummary(3, 2)), findsOneWidget,
          reason: 'three parts, and the third opens on a board of its own');
    });

    testWidgets('says what a PGN cannot carry', (tester) async {
      // A trainer who learns this by opening the file somewhere else and
      // missing their questions learns it too late.
      await openStudio(tester);
      await openExport(tester);

      expect(find.text(pgnExportLoses), findsOneWidget);
    });

    testWidgets('writes nothing until it is asked to', (tester) async {
      var asked = false;
      debugSavePgnFile = ({required fileName, required pgn}) async {
        asked = true;
        return 'C:/x.pgn';
      };

      await openStudio(tester);
      await openExport(tester);
      await tester.tap(find.byKey(const Key('tutorial-pgn-cancel')));
      await tester.pumpAndSettle();

      expect(asked, isFalse);
      expect(find.text(pgnExportLoses), findsNothing);
    });
  });

  group('what the picker is handed', () {
    testWidgets('the tutorial name, and every game', (tester) async {
      String? name;
      String? text;
      debugSavePgnFile = ({required fileName, required pgn}) async {
        name = fileName;
        text = pgn;
        return 'C:/tutorials/Two lessons.pgn';
      };

      await openStudio(tester);
      await openExport(tester);
      await tester.tap(find.byKey(const Key('tutorial-pgn-save')));
      await tester.pumpAndSettle();

      expect(name, 'Two-lessons.pgn');
      expect(text, contains('[Event "Two lessons"]'));
      expect(text, contains('1. e4 e5 2. Nf3 Nc6'));
      expect(text, contains('[FEN "$endingFen"]'));
      expect(text, contains('Ra8+'));
    });

    testWidgets('what is on the screen, not what was saved', (tester) async {
      // A trainer who has just written a sentence and exports before pressing
      // „Save tutorial" must not get the version without it.
      String? text;
      debugSavePgnFile = ({required fileName, required pgn}) async {
        text = pgn;
        return 'C:/x.pgn';
      };

      await openStudio(tester);
      await tester.enterText(
          find.byKey(const Key('example-sentence')), 'A new sentence.');
      await tester.pumpAndSettle();

      await openExport(tester);
      await tester.tap(find.byKey(const Key('tutorial-pgn-save')));
      await tester.pumpAndSettle();

      expect(text, contains('A new sentence.'));
    });

    testWidgets('the dialog closes and the path is reported', (tester) async {
      debugSavePgnFile =
          ({required fileName, required pgn}) async => 'C:/t/one.pgn';

      await openStudio(tester);
      await openExport(tester);
      await tester.tap(find.byKey(const Key('tutorial-pgn-save')));
      await tester.pumpAndSettle();

      expect(find.text(pgnExportLoses), findsNothing,
          reason: 'a SnackBar under an open dialog is dimmed by its barrier');
      expect(find.textContaining('C:/t/one.pgn'), findsOneWidget);
    });

    testWidgets('a cancelled picker says nothing at all', (tester) async {
      debugSavePgnFile = ({required fileName, required pgn}) async => null;

      await openStudio(tester);
      await openExport(tester);
      await tester.tap(find.byKey(const Key('tutorial-pgn-save')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing,
          reason: 'somebody who closed the picker knows they closed it');
      expect(find.text(pgnExportLoses), findsOneWidget,
          reason: 'and the dialog is still there to try again from');
    });

    testWidgets('a picker that throws does not take the studio with it',
        (tester) async {
      debugSavePgnFile = ({required fileName, required pgn}) async =>
          throw StateError('no such drive');

      await openStudio(tester);
      await openExport(tester);
      await tester.tap(find.byKey(const Key('tutorial-pgn-save')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('could not be saved'), findsOneWidget);
    });
  });

  group('the sentence about the file', () {
    test('says how many parts became how many games', () {
      // The widget test above asks the dialog for this exact string, which
      // pins the two **numbers** and says nothing about the words. This says
      // the words carry the numbers at all.
      final several = pgnExportSummary(3, 2);
      expect(several, contains('3 parts'));
      expect(several, contains('2 games'));

      final one = pgnExportSummary(2, 1);
      expect(one, contains('2 parts'));
      expect(one, contains('one game'));
      expect(one, isNot(contains('games')));
    });

    test('one part is one part', () {
      expect(pgnExportSummary(1, 1), contains('1 part,'));
    });
  });

  group('the layout', () {
    testWidgets('the button is reachable where the studio is narrowest',
        (tester) async {
      // 700 dp is the width `tutorial_editor_door_test.dart` already pins as
      // the narrow branch of the app bar. A release build paints no overflow
      // stripes — it clips — so an action past the edge is an export nobody
      // can reach.
      await openStudio(tester, size: const Size(700, 1000));

      expect(tester.takeException(), isNull);
      await openExport(tester);
      expect(find.text(pgnExportLoses), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
