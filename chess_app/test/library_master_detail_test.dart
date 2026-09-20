// `docs/PLAN-LISTE.md`, phase 5 — pattern B for the Library.
//
// A wide window gets a pane beside the shelf: tap a board and it is drawn
// there, large, instead of over the list in a dialog. Below `Breakpoints.wide`
// nothing changes — the dialog opens exactly as it does today, and so it must,
// because that is the behaviour the owner signed off on 20.9.2026 (item 205,
// point 5: „kucni sličicu — otvara se pregled table").
//
// Three claims carry the phase, and each is here because it is the one that
// could quietly go wrong:
//
//  * **The pane replaces the dialog only where there is room for it.** A
//    dialog that still opened behind a pane would draw the same board twice.
//  * **The room's column is untouched.** `LibraryList` is drawn by two callers
//    and only one of them has a pane. The list must draw a selection only when
//    it was given one (rule 15), so the case that proves it is asked of the
//    **real** narrow caller rather than of a stripped-down fixture.
//  * **Tapping the card still opens the thing.** Master–detail usually means
//    the row selects; here the row has always opened, the owner has checked
//    that it opens, and only the board thumbnail — the second of the two taps
//    a card already carried — becomes „show me".
//
// `board_preview_dialog`'s own tests stay green unchanged, in
// `exercise_board_side_test.dart`, `exercise_library_test.dart` and
// `library_grid_3b_test.dart`. That they do is the proof the extraction into a
// shared panel changed nothing about the dialog.
//
// **What this file cannot see, said out loud.** Replacing the screen's
// `constraints.maxWidth` with `MediaQuery.sizeOf(context).width` leaves every
// case below green, because `LibraryScreen` is always pushed as a whole route
// and the two numbers are the same one. The distinction is real for
// `LibraryList` and `AdaptiveCardGrid` — both are embedded in the room's
// narrow column inside a wide window, and both have a case for it — but here
// it would take a fixture that puts this screen somewhere the app never puts
// it. Recorded rather than contrived: a mutation that survives is a question
// about the test, and this one's answer is that the rule does not yet bite.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

/// White to move, so the panel's wording is a fact about the entry and not
/// about the default.
const _fen = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';

/// Black to move, on the second position, so „the pane shows the one that was
/// tapped" cannot pass by drawing either of them.
const _fenBlack = '8/8/8/8/8/4K3/8/r3k3 b - - 0 1';

List<Map<String, dynamic>> _shelf() => [
      {'kind': 'position', 'id': '12', 'title': 'Lucena', 'fen': _fen},
      {'kind': 'position', 'id': '13', 'title': 'Philidor', 'fen': _fenBlack},
      {
        'kind': 'tutorial',
        'id': '14',
        'title': 'Sicilian: the Najdorf',
        'fen': _fen,
        'partsCount': 6,
      },
      // Deliberately the same id as the position above. Ids come from
      // different tables, so this pair exists on a real shelf, and it is the
      // only fixture in which „mark the chosen card" can be caught marking
      // two (rule 6: stand the test on the boundary).
      {
        'kind': 'tutorial',
        'id': '12',
        'title': 'Tutorial twelve',
        'fen': _fen,
        'partsCount': 2,
      },
    ];

http.Client _server() => MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/library/positions')) {
        return http.Response(jsonEncode({'items': _shelf()}), 200);
      }
      if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
      if (path.endsWith('/lessons')) return http.Response('[]', 200);
      return http.Response('{}', 404);
    });

UserSession _session() =>
    UserSession(id: 1, token: 'tok', email: 'e', name: 'N', role: 'trener');

Future<void> _at(WidgetTester tester, Size size, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: home,
  ));
  await tester.pumpAndSettle();
}

Future<void> _library(WidgetTester tester, Size size) async {
  final client = _server();
  await _at(
    tester,
    size,
    LibraryScreen(
      session: _session(),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      lessonApi: LessonApiService(authToken: 'tok', client: client),
    ),
  );
}

Future<void> _room(WidgetTester tester, Size size) async {
  final client = _server();
  await _at(
    tester,
    size,
    ChessGamePage(
      userSession: _session(),
      roomCode: 'STUDIO',
      initialRole: 'trener',
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
    ),
  );
}

/// The board on a card — the second of the two taps a card carries.
///
/// The thumbnail itself, not the `GestureDetector` around it: a row holds
/// several detectors and `.first` picked one that was not the board, which
/// made three cases red for a reason that had nothing to do with the phase.
/// `library_grid_3b_test.dart` reaches it the same way.
Finder _boardOn(String key) => find.descendant(
      of: find.byKey(ValueKey('library-row-$key')),
      matching: find.byType(BoardThumbnail),
    );

Future<void> _tapBoard(WidgetTester tester, String key) async {
  expect(_boardOn(key), findsOneWidget, reason: 'no board to tap on row $key');
  await tester.tap(_boardOn(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a wide window the board goes in the pane, not a dialog',
      (tester) async {
    await _library(tester, const Size(1400, 900));

    await _tapBoard(tester, 'position-12');

    expect(find.byType(AlertDialog), findsNothing,
        reason: 'a dialog over a pane draws the same board twice');
    expect(find.text('White to move'), findsOneWidget,
        reason: 'the entry was not drawn anywhere');
  });

  testWidgets('the pane shows the one that was tapped', (tester) async {
    await _library(tester, const Size(1400, 900));

    await _tapBoard(tester, 'position-13');

    // Without this line the case passes on master through the dialog, which
    // also draws the right entry — it would pin *which* entry and say nothing
    // about *where*.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Black to move'), findsOneWidget);
    expect(find.text('White to move'), findsNothing);
  });

  testWidgets('on a narrow window the dialog opens exactly as today',
      (tester) async {
    // Below `Breakpoints.wide`. This is the behaviour the owner checked live
    // on 20.9.2026 and it is not the phase's to change.
    await _library(tester, const Size(800, 900));

    await _tapBoard(tester, 'position-12');

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('White to move'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('the room\'s column is untouched', (tester) async {
    // The other caller, driven for real. It is given no pane and no selection,
    // so it must behave exactly as it always has — a dialog, over a 300 px
    // column, inside a window wide enough that a screen reading `MediaQuery`
    // instead of its own constraint would get this wrong.
    await _room(tester, const Size(1400, 900));

    await _tapBoard(tester, 'position-12');

    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'the room lost its preview, or grew a pane it never asked for');
  });

  testWidgets('choosing a board shows it and does not open it', (tester) async {
    // A card carries two taps and only the thumbnail changed meaning. The
    // risk of this phase is that the new one also fires the old one, which
    // would navigate away from the shelf the reader is reading.
    //
    // That the *card* tap still opens is guarded where it can be: at the
    // `LibraryList` level in `library_grid_3b_test.dart`, with an `onOpen`
    // that records. Here the screen is real and opening a position pushes a
    // route through `go_router`, which this harness has none of — so the
    // claim asked here is the one this file can actually answer.
    await _library(tester, const Size(1400, 900));

    await _tapBoard(tester, 'position-12');

    expect(find.byType(LibraryScreen), findsOneWidget,
        reason: 'the thumbnail opened the entry as well as showing it');
    expect(tester.takeException(), isNull);
  });

  testWidgets('with nothing chosen the pane says what it is for',
      (tester) async {
    await _library(tester, const Size(1400, 900));

    expect(find.textContaining('Tap a board'), findsOneWidget,
        reason: 'width spent on a blank rectangle is the fault of phase 3a');
  });

  testWidgets('only the chosen card is marked, ids colliding or not',
      (tester) async {
    // The mark is an outline — shape, not hue, because the owner's live
    // sign-off reads luminance and shape and never colour.
    await _library(tester, const Size(1400, 900));
    await _tapBoard(tester, 'position-12');

    RoundedRectangleBorder shapeOf(String key) => tester
        .widget<Card>(find.descendant(
          of: find.byKey(ValueKey('library-row-$key')),
          matching: find.byType(Card),
        ))
        .shape as RoundedRectangleBorder;

    expect(shapeOf('position-12').side.width, greaterThan(0),
        reason: 'the chosen card is not marked at all');
    expect(shapeOf('tutorial-12').side.width, 0,
        reason: 'an id without its kind marked the wrong card as well');
    expect(shapeOf('position-13').side.width, 0);
  });

  testWidgets('the pane\'s board is square', (tester) async {
    // The same shape of fault the Repertoire's pane had, asked of this one
    // because the two panes sit in the same kind of stretched column: a board
    // wider than it is tall draws a rank outside itself and is clipped, and
    // nothing anywhere reports it. Green here — `BoardPreviewPanel` centres
    // its own children, so the stretch stops at the panel — and the case is
    // what keeps it that way.
    await _library(tester, const Size(1920, 1000));

    await _tapBoard(tester, 'position-12');

    final board = tester.getSize(find.byType(BoardThumbnail).last);
    expect(board.width, board.height,
        reason: 'the pane stretched the board out of square');
  });

  testWidgets('a narrow shelf draws one card per row and clips nothing',
      (tester) async {
    // The fault phase 5 walked into, kept here in the shape it was found: a
    // pane makes the shelf narrow, and a narrow shelf used to be split into
    // two half-width columns whose cards overflowed by 48 px. Fixed in
    // `AdaptiveCardGrid.minTileWidth`; this case is the end-to-end proof,
    // with the four actions a tutorial card carries at its tallest.
    await _library(tester, const Size(914, 700));

    final shelfCards = find.byKey(const ValueKey('library-row-tutorial-14'));
    expect(shelfCards, findsOneWidget);
    expect(tester.getSize(shelfCards).width,
        greaterThanOrEqualTo(AdaptiveCardGrid.minTileWidth));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing overflows at either size', (tester) async {
    await _library(tester, const Size(840, 700));
    expect(tester.takeException(), isNull);

    await _tapBoard(tester, 'position-12');
    expect(tester.takeException(), isNull);

    await _library(tester, const Size(1400, 900));
    await _tapBoard(tester, 'position-13');
    expect(tester.takeException(), isNull);
  });
}
