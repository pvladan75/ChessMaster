// „Saved tutorials" on a phone — the owner's reports of 17.9.2026.
//
// First: the dialog listed no tutorials at all on a phone while Windows listed
// them all. Its content was capped at 400 dp and fourteen label chips, padded
// to 48 dp touch targets on Android, took all of it. The first fix capped the
// chips and the owner's next screenshots showed two more faults the fixture
// was too lucky to see: in portrait each row was four buttons and no title —
// the fixture's tutorials had no film, so three buttons, and short names —
// and in landscape the chips took the whole 411 dp again.
//
// The owner chose to retire the dialog: the button opens the Library, which
// already had the list, the search, the labels and the four actions. These
// tests stand on what the owner's phone actually holds — tutorials with a
// film, titles as long as a sentence, fourteen labels — in both orientations.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_theme.dart';

import 'support/shelf_over_lessons.dart';

/// The labels on the owner's screen.
const _labels = [
  'bishop pair',
  'calculation',
  'endgame',
  'forks',
  'French Defense',
  'king safety',
  'kingside attack',
  'mate',
  'missed chances',
  'opening',
  'pins',
  'Scandinavian Defense',
  'tactics',
  'turning point',
];

/// A tutorial is named by its first sentence.
String _title(int i) =>
    'Tutorial $i: the white knight takes the d5 square away from the black '
    'bishop';

List<Map<String, dynamic>> _rows() => [
      for (var i = 0; i < 10; i++)
        {
          'id': i + 1,
          'title': _title(i),
          'tags': [
            _labels[i % _labels.length],
            _labels[(i + 4) % _labels.length],
            _labels[(i + 9) % _labels.length],
          ],
          // A film on every row: the fourth button, which is what left the
          // owner's titles no width.
          'has_video': true,
          'position_list': [
            {'id': 's$i', 'fen': '8/8/8/8/8/8/8/K6k w - - 0 1'},
          ],
        },
      {
        'id': 99,
        'title': 'Trenerov tutorijal',
        'is_trainer_lesson': true,
        'position_list': [
          {'id': 't1', 'fen': '8/8/8/8/8/8/8/K6k w - - 0 1'},
        ],
      },
    ];

LessonApiService _api() => LessonApiService(
      authToken: 't',
      client: MockClient((req) async {
        if (req.url.path == '/lessons/labels') {
          return http.Response(jsonEncode(_labels), 200);
        }
        return http.Response(
          jsonEncode(_rows()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openSaved(
    WidgetTester tester,
    Size size,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _api();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TutorialLibraryCard(
              session: UserSession(
                token: 't',
                id: 1,
                email: 'e',
                name: 'n',
                role: 'x',
              ),
              api: api,
              positionLibrary: shelfOver(api),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Saved tutorials'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Inside the test: the binding checks the override before a tearDown runs.
    debugDefaultTargetPlatformOverride = null;
  }

  /// The first row's title and its four buttons are all on the screen, and a
  /// finger can reach each one.
  void expectFirstRowUsable(WidgetTester tester) {
    expect(tester.takeException(), isNull,
        reason: 'a release build clips this without a word');
    expect(find.byType(LibraryScreen), findsOneWidget);

    final screen = tester.getRect(find.byType(LibraryScreen));
    final title = find.text(_title(0)).hitTestable();
    expect(title, findsOneWidget,
        reason: 'the first tutorial is on screen, not under the filters');
    expect(tester.getSize(title).width, greaterThanOrEqualTo(120),
        reason: 'the title has room to be read — the owner saw rows of icons '
            'and no names');

    final row = find.ancestor(of: find.text(_title(0)), matching: libraryRow);
    for (final tooltip in [
      'Export video',
      'Download video',
      'Send to student',
      'Delete tutorial',
    ]) {
      final button =
          find.descendant(of: row, matching: find.byTooltip(tooltip));
      expect(button.hitTestable(), findsOneWidget, reason: tooltip);
      final box = tester.getRect(button);
      expect(box.left, greaterThanOrEqualTo(screen.left), reason: tooltip);
      expect(box.right, lessThanOrEqualTo(screen.right), reason: tooltip);
    }
  }

  for (final (name, size) in [
    ('portrait 411 × 914', const Size(411, 914)),
    ('portrait 360 × 640', const Size(360, 640)),
    ('landscape 914 × 411', const Size(914, 411)),
    ('landscape 640 × 360', const Size(640, 360)),
  ]) {
    testWidgets('$name: the tutorials, their names and their buttons',
        (tester) async {
      await openSaved(tester, size, TargetPlatform.android);
      expect(tester.takeException(), isNull);
      // On a screen held sideways the filters scroll away with the rows, so
      // the first row may start below the fold — reachable by scrolling,
      // which is what a finger does, and then whole.
      await tester.ensureVisible(find.text(_title(0)));
      await tester.pumpAndSettle();
      expectFirstRowUsable(tester);
      await close(tester);
    });
  }

  testWidgets('it opens on the trainer\'s own tutorials', (tester) async {
    await openSaved(tester, const Size(411, 914), TargetPlatform.android);

    expect(find.text('Trenerov tutorijal'), findsNothing,
        reason: 'what this account writes, not what its trainer does');

    // Somebody else's is one tap away, and has nothing to send or delete.
    await tester.tap(find.widgetWithText(FilterChip, 'From trainer'));
    await tester.pumpAndSettle();
    final theirs = find.ancestor(
        of: find.text('Trenerov tutorijal'), matching: libraryRow);
    expect(theirs, findsOneWidget);
    expect(find.descendant(of: theirs, matching: find.byType(IconButton)),
        findsNothing);

    await close(tester);
  });

  testWidgets('search and a label still narrow the list', (tester) async {
    await openSaved(tester, const Size(411, 914), TargetPlatform.android);

    await tester.enterText(find.byType(TextField).first, 'Tutorial 7');
    await tester.pumpAndSettle();
    expect(find.text(_title(7)), findsOneWidget);
    expect(find.text(_title(3)), findsNothing);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Label Filter Matrix'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('bishop pair').last);
    await tester.pumpAndSettle();
    // Tutorial 0 carries „bishop pair"; Tutorial 1 does not.
    expect(find.text(_title(0)), findsOneWidget);
    expect(find.text(_title(1)), findsNothing);

    await close(tester);
  });

  // Until 20.9.2026 this case was „on Windows the rows keep their buttons
  // beside the title", and asserted that the send button sat within 24 px of
  // the title's own line. Phase 3b of `docs/PLAN-LISTE.md` **superseded that
  // rule**, deliberately: a row is now a card in an `AdaptiveCardGrid`, a card
  // is never wider than 420, and `LibraryList.actionsBesideFrom` — the 480 px
  // threshold that put the actions beside the title — could no longer be
  // reached and was deleted. A wide window is answered with more cards, not
  // with one stretched row.
  //
  // What this file exists for is untouched and still asserted by
  // [expectFirstRowUsable]: the title has room to be read, and all four
  // buttons are on the screen and reachable. What replaces the old line is the
  // new arrangement — the buttons are **under** the title and inside that
  // entry's own card, so a grid cannot put a row's actions over its neighbour.
  testWidgets('on Windows the buttons are under the title, on its own card',
      (tester) async {
    await openSaved(tester, const Size(1400, 900), TargetPlatform.windows);
    expectFirstRowUsable(tester);

    final card = find.ancestor(of: find.text(_title(0)), matching: libraryRow);
    final title = tester.getRect(find.text(_title(0)));
    final send = tester.getRect(
        find.descendant(of: card, matching: find.byTooltip('Send to student')));

    expect(send.top, greaterThan(title.bottom),
        reason: 'the actions are no longer under the title');
    expect(tester.getRect(card).contains(send.center), isTrue,
        reason: 'a button is drawn outside the card it belongs to');

    await close(tester);
  });
}
