/// The two doors onto other tutorials, in the studio that has to offer them.
///
/// The transfer itself is proved in `tutorial_parts_transfer_test.dart`, with
/// no widget tree. This file asks the other question, the one that has caught
/// this repository out more than once: **can a trainer reach it** — is the
/// menu drawn, does picking a tutorial and ticking its parts actually put them
/// in the draft, and does taking parts out reach the server as a tutorial of
/// its own while leaving the open one alone.
///
/// The menu is in the studio's bar and not in the contents panel, where every
/// other action on a part lives, because all three candidate surfaces were
/// already full — 2 px, 19 px and 33 px over in turn. Which is why the widths
/// below are part of the gate rather than a detail: this feature has already
/// broken the layout once for every place it was tried.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The two parts of the tutorial on the shelf. One fixture for both readers —
/// the picker's list and the tutorial it fetches — so the two can never
/// disagree about how many parts it has.
const _sourceSteps = [
  {
    'id': 's1',
    'fen': _startFen,
    'pgn': '{ the short side }',
    'kind': 'show',
  },
  {
    'id': 's2',
    'fen': _startFen,
    'pgn': '{ the long side }',
    'kind': 'show',
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
      token: 't', id: 7, email: 'a@b.c', name: 'Trainer', role: 'trener');

  /// What the shelf holds and what the tutorial behind it says.
  ///
  /// Two parts, each with a sentence of its own, because a part is named by
  /// what it says — a fixture whose parts say nothing would be picked from a
  /// list reading „Part 1, Part 2" and could not tell a right answer from an
  /// off-by-one.
  late List<Map<String, dynamic>> written;

  MockClient client() => MockClient((req) async {
        final path = req.url.path;
        // The shelf the course picker reads: `GET /lessons`, rows that carry a
        // `position_list`. A row without one is not a tutorial and the picker
        // skips it, so the fixture has to carry the steps here too.
        if (req.method == 'GET' && path.endsWith('/lessons')) {
          return http.Response(
              jsonEncode([
                {
                  'id': 42,
                  'title': 'Rook endings',
                  'position_list': _sourceSteps,
                },
              ]),
              200);
        }
        if (req.method == 'GET' && path.endsWith('/lessons/42')) {
          return http.Response(
              jsonEncode({
                'id': 42,
                'title': 'Rook endings',
                'tags': <String>[],
                'position_list': _sourceSteps,
              }),
              200);
        }
        if (req.method == 'POST' && path.endsWith('/lessons/save')) {
          written.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(
              jsonEncode({
                'id': 99,
                'lesson': {'id': 99},
              }),
              201);
        }
        return http.Response('[]', 200);
      });

  setUp(() async {
    written = [];
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Future<void> open(WidgetTester tester,
      {Size size = const Size(1600, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: const TutorialEntry.blank('Mine'),
        lessonApi: LessonApiService(authToken: 't', client: client()),
        positionLibrary:
            PositionLibraryService(authToken: 't', client: client()),
      ),
    ));
    await tester.pumpAndSettle();
    if (find.text('Continue').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byKey(const Key('parts-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(item)));
    await tester.pumpAndSettle();
  }

  testWidgets('the studio bar offers both doors', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('parts-menu')), findsOneWidget);
    await tester.tap(find.byKey(const Key('parts-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Add parts from a tutorial…'), findsOneWidget);
    expect(find.text('Take parts into a new tutorial…'), findsOneWidget);
    // The button it stands beside kept its own place: „Save as .pgn" was one
    // tap before this feature and must be one tap after it.
    await tester.tap(find.text('Add parts from a tutorial…'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'the bar draws and the menu is reachable at the narrowest wide '
      'window', (tester) async {
    // 840 is where the studio splits into two panes, and where the bar
    // overflowed by 33 px the first time this menu was put in it.
    await open(tester, size: const Size(840, 800));

    expect(tester.takeException(), isNull, reason: 'the bar overflows');
    expect(find.byKey(const Key('parts-menu')).hitTestable(), findsOneWidget,
        reason: 'drawn past the edge is the same as not drawn');
    // Its neighbour had to survive the menu being added beside it: „Save as
    // .pgn" was one tap before this feature and is one tap after it.
    expect(find.byKey(const Key('export-tutorial-pgn')).hitTestable(),
        findsOneWidget);
  });

  testWidgets('a phone reaches both doors through the menu it already has',
      (tester) async {
    // The phone layout is chosen by width **and** platform, so a test that
    // only narrows the window gets the desktop bar squeezed into 360 px —
    // which is not a screen this app ever draws, and measuring it says
    // nothing. The override is what puts the real layout under the test.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await open(tester, size: const Size(360, 740));
    expect(tester.takeException(), isNull, reason: 'the phone bar overflows');

    // A feature that exists on one layout and not the other is a feature a
    // trainer finds once and then cannot find again.
    await tester.tap(find.byKey(const Key('phone-more')));
    await tester.pumpAndSettle();
    expect(find.text('Add parts from a tutorial…'), findsOneWidget);
    expect(find.text('Take parts into a new tutorial…'), findsOneWidget);

    // Put back inside the test body, not in a tearDown: the framework checks
    // that no foundation debug variable outlived the test, and that check runs
    // before tearDowns do.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("another tutorial's parts arrive in the one being written",
      (tester) async {
    await open(tester);
    await openMenu(tester, 'parts-menu-add');

    // The shelf, then the parts of what was picked.
    await tester.tap(find.text('Rook endings').last);
    await tester.pumpAndSettle();

    expect(find.text('2 parts chosen'), findsOneWidget,
        reason: 'the picker read the parts of the tutorial that was chosen');
    await tester.tap(find.byKey(const Key('part-picker-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 parts added'), findsOneWidget);
    // Drawn in the contents panel, which is the only proof that they are in
    // the draft rather than merely fetched.
    expect(find.textContaining('the short side', skipOffstage: false),
        findsWidgets);
    expect(find.textContaining('the long side', skipOffstage: false),
        findsWidgets);
  });

  testWidgets('one part can be left behind', (tester) async {
    await open(tester);
    await openMenu(tester, 'parts-menu-add');
    await tester.tap(find.text('Rook endings').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('part-picker-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('part-picker-confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 part added'), findsOneWidget);
    expect(
        find.textContaining('the long side', skipOffstage: false), findsNothing,
        reason: 'the part that was unticked must not have come along');
  });

  testWidgets(
      'parts taken out are written as a tutorial of their own, and '
      'this one keeps them', (tester) async {
    await open(tester);
    await openMenu(tester, 'parts-menu-add');
    await tester.tap(find.text('Rook endings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('part-picker-confirm')));
    await tester.pumpAndSettle();
    // The „parts added" bar has to go before the next one is asked about:
    // a SnackBar queues behind the one showing, so the second message would
    // simply not be on screen yet and the assertion below would be about
    // timing rather than about what was saved.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await openMenu(tester, 'parts-menu-extract');
    await tester.tap(find.byKey(const Key('part-picker-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('part-picker-name')), 'The short side');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('part-picker-confirm')));
    await tester.pumpAndSettle();

    expect(written, hasLength(1));
    expect(written.single['title'], 'The short side');
    expect(written.single['positionList'], hasLength(1));

    expect(find.textContaining('saved, with 1 part'), findsOneWidget);
    // The source is untouched — the whole reason copying was chosen over
    // moving. Both parts are still in the contents panel.
    expect(find.textContaining('the short side', skipOffstage: false),
        findsWidgets);
    expect(find.textContaining('the long side', skipOffstage: false),
        findsWidgets);
  });
}
