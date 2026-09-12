// „Flow", „Tree" and „PGN" stay on screen while the cards under them scroll.
//
// The owner's report of 12.9.2026, off a screenshot of the studio: „Flow, tree
// i pgn kartice ne treba da se skrivaju prilikom skrolovanja, tj. skrolovanje
// ne sme na njih da utiče. Skroluje se samo ono ispod njih."
//
// Two layouts, two mechanisms, one claim. On a wide window the strip sits
// outside a scroll view of its own; on a narrow one the board and the parts
// list are above it in the same scroll, so it is a pinned sliver. Both are
// asserted here, because a fix to one of them says nothing about the other —
// and the narrow branch is the one the report came from.

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
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_flow_panel.dart';
import 'package:chess_app/models/user_session.dart';

const String _openFen = '8/8/8/3k4/8/8/4K3/7R w - - 0 1';

/// Long enough that „Flow" has more cards than a narrow window can hold, which
/// is the only situation in which any of this is observable.
const String _pgn = '1. Rh4 { The rook cuts the fourth rank. } '
    'Ke5 { The king must stay on the fifth. } '
    '2. Kf3 { White walks closer. } Kd5 { And Black steps aside. } '
    '3. Rh5+ { Check, and the rank falls. } Kd6 { Down one more. } '
    '4. Kf4 { Closer again. } Kc6 { Sideways. } '
    '5. Ke5 { The kings face each other. } Kb6 { Running. } *';

class _Api extends LessonApiService {
  _Api()
      : super(
            authToken: 'tok',
            client: MockClient((req) async {
              return http.Response(jsonEncode({'id': 77}), 200);
            }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trainer',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  // One id per test: the studio adopts a stored draft whose `lessonId` matches
  // and flushes its own on dispose.
  var nextLessonId = 900;

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    });

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved({
          'id': nextLessonId++,
          'title': 'Rook and king',
          'position_list': [
            {
              'id': 'step-1',
              'fen': _openFen,
              'title': 'Part 1',
              'kind': 'show',
              'pgn': _pgn,
            },
          ],
        }),
        lessonApi: _Api(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final tabs = find.byKey(const Key('tok-tab'));

  /// „Flow"'s own cards, which is what scrolls under the strip. Scoped, because
  /// the studio draws more than one `IndexedStack`.
  final cards = find.byType(TutorialFlowPanel);

  testWidgets('on a narrow window the strip is pinned, not scrolled away',
      (tester) async {
    await open(tester, const Size(700, 620));

    expect(find.byType(CustomScrollView), findsOneWidget,
        reason: 'the narrow layout is slivers, so the strip can be pinned');

    // The board and the parts list are above it, so the strip starts well below
    // the fold — a pinned sliver holds a place in the viewport once it reaches
    // it, and is not even built before that.
    // Driven through the scroll position rather than by a gesture: the board
    // fills a narrow viewport and takes drags for itself — it is a board, and a
    // drag on it is a piece being moved.
    final page = tester.state<ScrollableState>(find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first);

    page.position.jumpTo(page.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tabs, findsOneWidget, reason: 'the strip is there at the bottom');

    final atTop = tester.getTopLeft(tabs).dy;
    final cardsAtBottom = tester.getTopLeft(cards).dy;
    expect(atTop, greaterThanOrEqualTo(0.0), reason: 'still on screen');
    expect(tester.getBottomLeft(tabs).dy, lessThanOrEqualTo(620.0),
        reason: 'and whole');

    // And the part that is the whole report: a different scroll position moves
    // the cards and leaves the strip where it is.
    page.position.jumpTo(page.position.maxScrollExtent - 300);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(cards).dy, greaterThan(cardsAtBottom + 100),
        reason: 'what is under the strip scrolled');
    expect(tester.getTopLeft(tabs).dy, atTop,
        reason: 'and the strip did not move');
  });

  testWidgets('on a wide window scrolling the cards cannot move the strip',
      (tester) async {
    await open(tester, const Size(1100, 800));

    final before = tester.getTopLeft(tabs).dy;
    final cardBefore = tester.getTopLeft(cards).dy;

    // Dragged from a point just under the strip: the panel itself is taller
    // than its viewport, so its centre is off screen and a gesture aimed there
    // lands nowhere.
    await tester.dragFrom(
        tester.getTopLeft(tabs) + const Offset(120, 90), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(cards).dy, lessThan(cardBefore - 100),
        reason: 'the cards scrolled');
    expect(tester.getTopLeft(tabs).dy, before,
        reason: 'and the strip did not move at all');
  });
}
