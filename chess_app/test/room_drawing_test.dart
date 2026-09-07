import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/game_screen/arrow_color_button.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// What the room's drawing does today — written **before** P7b moves it onto
/// `BoardAnnotationController`, and green before a line of that move was
/// written.
///
/// The room had this behaviour privately for months and **no test at all**,
/// which is the whole reason P7 was split: the studio could be given the
/// feature by a batch, but rewiring the screen a live lesson runs on — where an
/// arrow is also recorded into `timeline_json` and broadcast to a child's board
/// — with nothing to catch a regression is the one thing this repository has
/// written down that it does not do.
///
/// **What this file can see, and what it cannot.** The arrows on the board are
/// observable: the room hands them to `ChessBoardWithOverlay`, so every
/// assertion below reads them off the widget the trainer is looking at. The
/// broadcast is not: `_publishArrows` records an event on a private recorder and
/// emits on a socket that no test connects. So this file pins the *behaviour*
/// and the refactor has to keep the publish calls where they are by inspection
/// — which is stated here rather than left for someone to assume it was covered.
///
/// The room is opened in `STUDIO` mode, which is the one entry that asks for no
/// server, no session registration and no partner: `initState` takes a
/// different branch for it, and everything about drawing is identical.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openRoom(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: ChessGamePage(
        roomCode: 'STUDIO',
        userSession: UserSession(
          token: 't',
          id: 7,
          email: 'a@b.c',
          name: 'Trener',
          role: 'trener',
        ),
        lessonApi: LessonApiService(
          authToken: 'tok',
          client: MockClient((_) async => http.Response('[]', 200)),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> closeRoom(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  List<String> arrows(WidgetTester tester) =>
      board(tester).arrows.map((a) => a.toString()).toList();

  /// A tap on a square, the way the board reports one while drawing.
  Future<void> tapSquare(WidgetTester tester, String square) async {
    board(tester).onSquareTapForDrawing(square);
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// The drawing panel lives in a side column that scrolls, so a control can be
  /// on screen and below the fold. A tap that misses is the flakiest kind of
  /// failure there is — batch 58 lost a round to one.
  Future<void> pressText(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(target, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> pickColor(WidgetTester tester, ArrowColor colour) async {
    final swatch = find.byWidgetPredicate(
        (w) => w is ArrowColorButton && w.arrow.id == colour.id);
    await tester.ensureVisible(swatch.last);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(swatch.last, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> startDrawing(WidgetTester tester) =>
      pressText(tester, 'Nacrtaj strelicu');

  group('entering and leaving drawing mode', () {
    testWidgets('the button turns the board over to drawing and back',
        (tester) async {
      await openRoom(tester);

      expect(board(tester).isDrawingMode, isFalse);

      await startDrawing(tester);
      expect(board(tester).isDrawingMode, isTrue);
      expect(find.text('Završi crtanje'), findsOneWidget,
          reason: 'the button still offers to start drawing while drawing');

      await pressText(tester, 'Završi crtanje');
      expect(board(tester).isDrawingMode, isFalse);

      await closeRoom(tester);
    });

    testWidgets('the colour swatches appear only while drawing',
        (tester) async {
      await openRoom(tester);

      expect(find.byType(ArrowColorButton), findsNothing);

      await startDrawing(tester);

      expect(
          find.byType(ArrowColorButton), findsNWidgets(ArrowColor.all.length),
          reason: 'one swatch per colour in the catalogue, generated rather '
              'than listed — the list once said four while the catalogue held '
              'five, and nobody could pick the fifth');

      await closeRoom(tester);
    });
  });

  group('drawing an arrow', () {
    testWidgets('two taps draw it, in the colour that is picked',
        (tester) async {
      await openRoom(tester);
      await startDrawing(tester);

      await tapSquare(tester, 'e2');
      expect(arrows(tester), isEmpty,
          reason: 'the first tap drew something on its own');
      expect(board(tester).drawingStartSquare, 'e2');

      await tapSquare(tester, 'e4');
      expect(arrows(tester), ['Ge2e4']);
      expect(board(tester).drawingStartSquare, isNull);

      await closeRoom(tester);
    });

    testWidgets('a different colour is drawn in that colour', (tester) async {
      await openRoom(tester);
      await startDrawing(tester);
      await pickColor(tester, ArrowColor.r);

      await tapSquare(tester, 'd2');
      await tapSquare(tester, 'd4');

      expect(arrows(tester), ['Rd2d4']);

      await closeRoom(tester);
    });

    testWidgets('the same square twice draws nothing and starts over',
        (tester) async {
      await openRoom(tester);
      await startDrawing(tester);

      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e2');

      expect(arrows(tester), isEmpty);
      expect(board(tester).drawingStartSquare, isNull,
          reason: 'the cancelled start is still armed, so the next tap draws '
              'from a square the trainer had given up on');

      await closeRoom(tester);
    });
  });

  group('taking an arrow back', () {
    testWidgets('drawing the same pair again erases it', (tester) async {
      await openRoom(tester);
      await startDrawing(tester);

      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');
      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');

      expect(arrows(tester), isEmpty);

      await closeRoom(tester);
    });

    testWidgets('erasing does not care what colour is picked now',
        (tester) async {
      // The rule the room has always had, and the one a rewrite is most likely
      // to "improve": the mistake being corrected is „wrong arrow", not „right
      // arrow, wrong colour".
      await openRoom(tester);
      await startDrawing(tester);

      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');
      await pickColor(tester, ArrowColor.r);
      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');

      expect(arrows(tester), isEmpty,
          reason: 'the arrow could only be erased by the colour that drew it');

      await closeRoom(tester);
    });

    testWidgets('„Poništi strelicu" takes the last one and says so',
        (tester) async {
      await openRoom(tester);
      await startDrawing(tester);

      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');
      await tapSquare(tester, 'd2');
      await tapSquare(tester, 'd4');
      expect(arrows(tester), ['Ge2e4', 'Gd2d4']);

      await pressText(tester, 'Poništi strelicu');

      expect(arrows(tester), ['Ge2e4'],
          reason: 'the undo took the arrow drawn first rather than last');
      expect(find.text('Poslednja strelica je poništena.'), findsOneWidget);

      await closeRoom(tester);
    });

    testWidgets('an undo with nothing to undo says that instead',
        (tester) async {
      // Its own test rather than a third press in the one above: a `SnackBar`
      // queues behind the one already showing, so the third message would only
      // be found by waiting out two four-second displays — a test that passes
      // for a reason that has nothing to do with the rule.
      await openRoom(tester);
      await startDrawing(tester);

      await pressText(tester, 'Poništi strelicu');

      expect(find.text('Nema strelice za poništavanje.'), findsOneWidget,
          reason: 'an empty undo said „done" over nothing');

      await closeRoom(tester);
    });

    testWidgets('„Izbriši sve strelice" empties the move', (tester) async {
      await openRoom(tester);
      await startDrawing(tester);

      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');
      await tapSquare(tester, 'd2');
      await tapSquare(tester, 'd4');

      await pressText(tester, 'Izbriši sve strelice');

      expect(arrows(tester), isEmpty);

      await closeRoom(tester);
    });
  });
}
