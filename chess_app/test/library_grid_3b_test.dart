// Gate — `docs/PLAN-LISTE.md`, phase 3b: `LibraryList`'s rows onto
// `AdaptiveCardGrid`.
//
// Written by the lead before the phase was built, and proved on master.
//
// 3b is the risky half of phase 3 for one reason: `LibraryList` is drawn by
// **two** callers with opposite widths — the Library screen on Teach, which is
// as wide as the window, and the room's left column, which is 300 px — and
// eight test files outside this one reach its rows. So both callers are driven
// here for real (`LibraryScreen` over a `MockClient`, `ChessGamePage` over the
// same one), and the finders those eight files use are asserted as facts of
// their own rather than left to be discovered by a red suite.
//
// Every layout claim is read from **where the cards are actually painted** —
// never from a width threshold. Phase 1 learned that a width assertion can
// pass on master while the fault stands.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/board_preview_dialog.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'support/shelf_over_lessons.dart';

const _fen = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';

// ------------------------------------------------------------------ fixtures

/// Six entries, one of every kind the Library draws, so the wide case counts
/// real rows of the real screen and not six copies of one.
List<Map<String, dynamic>> _shelf() => [
      {
        'kind': 'tutorial',
        'id': '14',
        'title': 'Sicilian: the Najdorf',
        'fen': _fen,
        'partsCount': 6,
        'hasVideo': true
      },
      {'kind': 'position', 'id': '12', 'title': 'Lucena', 'fen': _fen},
      {
        'kind': 'scan',
        'id': 'cust_1',
        'title': 'Diagram 41',
        'fen': _fen,
        'assignable': true,
        'hasSolution': true,
        'isExercise': true,
        'sourceTitle': 'Mat u 333',
        'sourcePage': 41
      },
      {'kind': 'analysis', 'id': '9', 'title': 'Game vs. Ana', 'fen': _fen},
      {
        'kind': 'recording',
        'id': '3',
        'title': 'Endgames, part 1',
        'fen': '',
        'createdAt': '2026-09-12T18:30:00.000Z'
      },
      {'kind': 'tutorial', 'id': '15', 'title': 'Rook endings', 'fen': _fen}
    ];

/// The `saved_lessons` rows behind the two tutorials. Without them the Library
/// screen draws a tutorial no actions at all (`_rawTutorialFor`), and the case
/// that guards the actions would be guarding nothing.
List<Map<String, dynamic>> _rawTutorials() => [
      for (final id in ['14', '15'])
        {
          'id': int.parse(id),
          'title': id == '14' ? 'Sicilian: the Najdorf' : 'Rook endings',
          'position_list': [
            {'fen': _fen, 'title': 'part 1'}
          ],
          'has_video': id == '14',
          'is_trainer_lesson': false,
          'tags': <String>[]
        }
    ];

http.Client _server() => MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/library/positions')) {
        return http.Response(jsonEncode({'items': _shelf()}), 200);
      }
      if (path.endsWith('/lessons/labels')) {
        return http.Response(jsonEncode(['endgame']), 200);
      }
      if (path.endsWith('/lessons')) {
        return http.Response(jsonEncode(_rawTutorials()), 200);
      }
      if (path.endsWith('/lessons/14')) {
        return http.Response(
            jsonEncode({
              'id': 14,
              'title': 'Sicilian: the Najdorf',
              'position_list': [
                {'fen': _fen, 'title': 'part 1'}
              ]
            }),
            200);
      }
      return http.Response('{}', 404);
    });

Widget _app(Widget home) => MaterialApp(
      theme:
          ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
      home: home,
    );

Future<void> _at(WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(home));
  await tester.pumpAndSettle();
}

UserSession _session() =>
    UserSession(id: 1, token: 'tok', email: 'e', name: 'N', role: 'trener');

Future<void> _library(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
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

/// Every key the shelf above produces, in the order the list draws them.
const _keys = [
  ValueKey('library-row-tutorial-14'),
  ValueKey('library-row-position-12'),
  ValueKey('library-row-scan-cust_1'),
  ValueKey('library-row-analysis-9'),
  ValueKey('library-row-recording-3'),
  ValueKey('library-row-tutorial-15'),
];

/// How many of [keys] share the topmost row of whatever is on screen.
///
/// Reading the y-offsets is the whole method: it says nothing about which
/// widget draws a row, so the implementation is free about composition, and it
/// cannot be satisfied by a grid that was configured but never given the
/// width.
int _onFirstRow(WidgetTester tester, List<Key> keys) {
  final tops = <double>[];
  for (final key in keys) {
    final finder = find.byKey(key);
    if (finder.evaluate().isEmpty) continue;
    tops.add(tester.getTopLeft(finder).dy);
  }
  expect(tops, isNotEmpty, reason: 'none of those rows was built');
  final first = tops.reduce((a, b) => a < b ? a : b);
  return tops.where((t) => (t - first).abs() < 0.5).length;
}

Finder _inRow(Key key, Finder what) =>
    find.descendant(of: find.byKey(key), matching: what);

void main() {
  // ================================================ the Library screen, wide

  group('the Library screen', () {
    testWidgets('a wide window puts library cards side by side',
        (tester) async {
      // RED on master: a `ListView` of `ListTile`s puts one row per line at
      // any width at all, which is the owner's complaint word for word.
      await _library(tester, const Size(1400, 900));

      expect(_onFirstRow(tester, _keys), greaterThanOrEqualTo(3),
          reason: 'a 1400 px window still draws one entry per line');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone still draws one card per line, without overflowing',
        (tester) async {
      // GREEN on master, and it must stay green: the plan changes the desktop
      // and leaves the phone exactly as it was.
      await _library(tester, const Size(360, 640));

      expect(_onFirstRow(tester, _keys), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rows go through the one grid, not a second copy of it',
        (tester) async {
      // RED on master. Rule 12: `AdaptiveCardGrid` is where the column count
      // is worked out, and a list that reimplements the delegate is a second
      // number to keep in step with the first.
      await _library(tester, const Size(1400, 900));

      expect(
          find.descendant(
              of: find.byType(LibraryList),
              matching: find.byType(AdaptiveCardGrid)),
          findsOneWidget);
    });

    testWidgets('the row keys and the finder eight files reach them by survive',
        (tester) async {
      // GREEN on master, and the reason this phase is the risky one.
      // `test/support/shelf_over_lessons.dart` finds a row by a `KeyedSubtree`
      // whose key starts with `library-row-`; `exercise_edit_test`,
      // `exercise_board_side_test`, `exercise_shelves_test` and
      // `exercise_library_test` reach one by that exact key.
      await _library(tester, const Size(1400, 900));

      for (final key in _keys) {
        expect(find.byKey(key), findsOneWidget, reason: key.value);
      }
      expect(libraryRow, findsNWidgets(6),
          reason: 'the rows are no longer found by the shared helper');
    });

    testWidgets('a card still carries its own kind\'s actions', (tester) async {
      // GREEN on master. Four on a tutorial, two on an exercise, one on a
      // position, one on an analysis — asserted inside the card that owns
      // them, so a grid that draws the actions of the wrong entry is red.
      //
      // **Superseded openly on 21.9.2026.** This case said „an analysis has
      // no actions and must draw none", and item 3 of the owner's review gave
      // it exactly one: „Delete analysis" (TODO-provera 211.4, „Nema dugme za
      // brisanje"). The assertion is not loosened — an analysis draws one
      // button, and it is that one.
      await _library(tester, const Size(1400, 900));

      expect(
          _inRow(_keys[0], find.byTooltip('Send to student')), findsOneWidget);
      expect(
          _inRow(_keys[0], find.byTooltip('Delete tutorial')), findsOneWidget);
      expect(_inRow(_keys[2], find.byTooltip('Assign to student')),
          findsOneWidget);
      expect(
          _inRow(_keys[1], find.byTooltip('Add to tutorial')), findsOneWidget);
      expect(_inRow(_keys[3], find.byType(IconButton)), findsOneWidget,
          reason: 'an analysis draws its delete and nothing else');
      expect(
          _inRow(_keys[3], find.byTooltip('Delete analysis')), findsOneWidget);
    });

    testWidgets('what a card says and what acts on it stay together',
        (tester) async {
      // GREEN on master, where the actions are the tile's `trailing` and sit
      // on the title's own line. It is here because phase 3a's live look found
      // the opposite: a `Spacer` inside a tile taller than its content pushed
      // the buttons to the bottom and left 29 px of dead air between a set and
      // the buttons that act on it. A fixed tile height makes that easy to
      // reintroduce, so the rule is asserted rather than remembered.
      //
      // Two claims, because a grid can break this in two ways. A tutorial's
      // card is nearly full, so the measure there is the gap itself; an
      // analysis has the fewest actions (none until 21.9.2026, its delete
      // since) and so the most slack, so the measure there is that the slack
      // is all *below* the content.
      //
      // What mutation says about the pair, recorded because it is the honest
      // limit: `MainAxisAlignment.center` and `.end` are red here, and so is
      // a taller `cardHeight` spread with `.spaceBetween` — 3a's fault word
      // for word. A bare `Spacer` or a bare `.spaceBetween` **survives**, and
      // for a real reason: the tile height is tight to the tallest card, so
      // on a tutorial there are 4 px to spread and spreading them changes
      // nothing a reader would see. The gap assertion bites once the slack
      // exists, which is exactly when it matters.
      await _library(tester, const Size(1400, 900));

      final subtitle = tester.getRect(find.textContaining('6 parts · video'));
      final send =
          tester.getRect(_inRow(_keys[0], find.byTooltip('Send to student')));
      expect(send.top - subtitle.bottom, lessThan(20.0),
          reason: 'the gap between what a tutorial says and the buttons that '
              'act on it is ${(send.top - subtitle.bottom).round()} px');

      final card = tester.getRect(find.byKey(_keys[3]));
      final tile = tester.getRect(_inRow(_keys[3], find.byType(ListTile)));
      expect(tile.top - card.top, lessThan(8.0),
          reason: 'a card with few actions floats its content '
              '${(tile.top - card.top).round()} px down its own tile');
    });

    testWidgets('a card still says what the row said', (tester) async {
      // GREEN on master. What a row says is not this phase's business.
      await _library(tester, const Size(1400, 900));

      expect(find.text('Sicilian: the Najdorf'), findsOneWidget);
      expect(find.textContaining('6 parts · video'), findsOneWidget);
      expect(find.textContaining('Mat u 333'), findsOneWidget);
      expect(find.text('saved position'), findsOneWidget);
    });

    testWidgets('the chips and the search still stand over the cards',
        (tester) async {
      // GREEN on master. The header is not part of the grid; searching must
      // still narrow what the grid is given.
      await _library(tester, const Size(1400, 900));

      await tester.enterText(
          find.widgetWithText(TextField, LibraryList.searchHint), 'najdorf');
      await tester.pumpAndSettle();

      expect(find.byKey(_keys[0]), findsOneWidget);
      expect(find.byKey(_keys[1]), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty shelf says so and draws no card', (tester) async {
      // GREEN on master, and an assertion of absence scoped to the rows: the
      // sentence stands alone, with no card under it.
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/library/positions')) {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        if (req.url.path.endsWith('/lessons/labels')) {
          return http.Response(jsonEncode(<String>[]), 200);
        }
        return http.Response(jsonEncode(<dynamic>[]), 200);
      });
      await _at(
        tester,
        const Size(1400, 900),
        LibraryScreen(
          session: _session(),
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
          lessonApi: LessonApiService(authToken: 'tok', client: client),
        ),
      );

      expect(find.text(LibraryList.empty), findsOneWidget);
      expect(libraryRow, findsNothing);
    });
  });

  // ============================================== the room's narrow column

  group('the room\'s column', () {
    testWidgets('is one card per line without being told, and does not throw',
        (tester) async {
      // GREEN on master and the point of pattern A: the column is 300 px, so
      // the grid gives it one column because it is narrow — not because
      // anything asked which screen it is. It also lives inside a
      // `SingleChildScrollView`, so a grid that asks for all the height there
      // is gets none and throws.
      await _room(tester, const Size(1200, 800));

      expect(find.byType(LibraryList), findsOneWidget);
      expect(tester.getSize(find.byType(LibraryList)).width, lessThan(432),
          reason: 'the column is no longer the narrow one this case is about');
      expect(
          _onFirstRow(tester, const [
            ValueKey('library-row-tutorial-14'),
            ValueKey('library-row-position-12'),
            ValueKey('library-row-scan-cust_1'),
            ValueKey('library-row-tutorial-15'),
          ]),
          1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tap still puts a tutorial on the board', (tester) async {
      // GREEN on master. The only thing the column is for.
      await _room(tester, const Size(1200, 800));

      await tester.ensureVisible(find.text('Sicilian: the Najdorf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sicilian: the Najdorf'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BoardPreviewDialog), findsNothing,
          reason: 'a tutorial has no board preview; the tap puts it on the '
              'board');
    });
  });

  // ============================================ the board on a card's front

  group('the board a card leads with', () {
    const entries = [
      LibraryEntry(
          kind: LibraryKind.scan,
          id: 'cust_1',
          title: 'From the book',
          fen: _fen,
          assignable: true,
          hasSolution: true),
      LibraryEntry(
          kind: LibraryKind.position,
          id: '7',
          title: 'Saved',
          fen: _fen,
          assignable: false),
      LibraryEntry(
          kind: LibraryKind.tutorial,
          id: '3',
          title: 'A tutorial',
          fen: '',
          assignable: false),
    ];

    Future<void> pump(WidgetTester tester, Size size,
        {void Function(LibraryEntry)? onOpen}) async {
      await _at(
          tester,
          size,
          Scaffold(
              body: LibraryList(entries: entries, onOpen: onOpen ?? (_) {})));
    }

    for (final size in [const Size(360, 640), const Size(1400, 900)]) {
      testWidgets(
          'an exercise and a position lead with a board, a tutorial does not, '
          'at ${size.width.toInt()}', (tester) async {
        // GREEN on master at 360 and, once the grid lands, at 1400 too: the
        // thumbnail is what decision 3 of `PLAN-EXERCISE.md` bought, and a
        // card must not lose it.
        await pump(tester, size);

        Finder boardIn(String key) =>
            _inRow(ValueKey(key), find.byType(BoardThumbnail));
        expect(boardIn('library-row-scan-cust_1'), findsOneWidget);
        expect(boardIn('library-row-position-7'), findsOneWidget);
        expect(boardIn('library-row-tutorial-3'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      testWidgets('the card\'s board is square on $platform', (tester) async {
        // Added 20.9.2026, after the owner saw a clipped rank in the
        // Repertoire's pane and a sweep of every board in `lib/` found the
        // same fault here — shipping, and invisible on the device he checks
        // on.
        //
        // `ListTile` lays its leading slot out with
        // `maxHeight = 56 + visualDensity.dy`, and `adaptivePlatformDensity`
        // is **compact on every desktop**. A board told 56 was handed 48 of
        // height and drew its eighth rank outside itself. Measured before the
        // fix: `56.0 x 48.0` on Windows and macOS, `56.0 x 56.0` on Android —
        // which is exactly why only a Windows build could show it.
        //
        // The case asks both platforms, because one alone cannot tell a
        // square board from a lucky density.
        // Restored inside the body rather than in a tear-down: the framework
        // checks its debug variables between the two and reports „the value
        // of a foundation debug variable was changed by the test", which
        // reads as a fault in the case rather than in the screen.
        debugDefaultTargetPlatformOverride = platform;
        try {
          await pump(tester, const Size(1400, 900));

          final board = tester.getSize(_inRow(
              const ValueKey('library-row-position-7'),
              find.byType(BoardThumbnail)));
          expect(board.width, board.height,
              reason: 'on $platform the board is ${board.width} x '
                  '${board.height}, so a rank is drawn outside it and clipped');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('tapping the board previews it; tapping the card opens it',
        (tester) async {
      // GREEN on master. Two taps on one card that must not collapse into
      // one — a card is a larger target than a row, which makes this easier
      // to get wrong, not harder.
      final opened = <String>[];
      await pump(tester, const Size(1400, 900),
          onOpen: (e) => opened.add(e.id));

      await tester.tap(_inRow(const ValueKey('library-row-position-7'),
          find.byType(BoardThumbnail)));
      await tester.pumpAndSettle();
      expect(find.byType(BoardPreviewDialog), findsOneWidget);
      expect(opened, isEmpty, reason: 'the board opened the entry as well');

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('A tutorial'));
      await tester.pumpAndSettle();
      expect(opened, ['3']);
    });
  });
}
