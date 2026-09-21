// The room's screen — phase 6 of docs/PLAN-SESIJA.md.
//
// What the phase decided, as things a reader can see: the bar carries the
// voice's state, the trainer's session switches and the way out; the right
// column is moves; a student's two answers to the trainer sit under the board
// on every width (F10: on a phone a student had no drawer, so „Show my
// position" could not be reached at all); and — the owner's word of 22.9.2026 —
// a student has no engine in the room.
//
// Measured rather than asked about: a board is a rectangle that must be square
// and whole on screen (CLAUDE.md, „clipping is not overflow"), and every
// control in the bar is measured on Android **and** Windows, because the
// desktop's compact density is what took 8 px off a button in phase 4.
//
// What this cannot reach: the voice's live states arrive over Socket.IO and
// from Agora, which a widget test has none of. The voice panel's own behaviour
// is in `room_voice_panel_test.dart`, pumped with the states directly.
//
// Real font (rule 8): with the test font the room's right column overflows.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/room_session_api.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

import 'support/landscape.dart' show loadRoboto, expectOnScreen, sizeLabel;

const _code = '192803';

const _phone = Size(360, 640);
const _sideways = Size(760, 360);
const _desk = Size(1400, 900);

final _voiceChip = find.byKey(const Key('room-voice-chip'));
final _session = find.byKey(const Key('room-session-button'));
final _more = find.byKey(const Key('room-more-menu'));
final _end = find.byKey(const Key('room-end-session'));
final _leave = find.byKey(const Key('room-leave-session'));
final _strip = find.byKey(const Key('room-student-strip'));

final _platforms =
    TargetPlatformVariant({TargetPlatform.android, TargetPlatform.windows});

Future<void> _room(WidgetTester tester, Size size,
    {required String role}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final client = MockClient((req) async {
    if (req.url.path.endsWith('/library/positions')) {
      return http.Response(jsonEncode({'items': []}), 200);
    }
    if (req.url.path == '/trainer/students') {
      return http.Response(jsonEncode({'students': []}), 200);
    }
    return http.Response('[]', 200);
  });

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Center(child: Text('HOME'))),
        routes: [
          GoRoute(
            path: 'room',
            builder: (_, __) => ChessGamePage(
              userSession: UserSession(
                  id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
              roomCode: _code,
              initialRole: role,
              lessonApi: LessonApiService(authToken: 'tok', client: client),
              positionLibrary:
                  PositionLibraryService(authToken: 'tok', client: client),
              groupApi: GroupApiService(client: client),
              roomSessionApi: RoomSessionApi(authToken: 'tok', client: client),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  // Built inside the test body, so the theme's density follows the platform
  // the variant set.
  await tester.pumpWidget(MaterialApp.router(
    theme: ThemeData(fontFamily: 'Roboto')
        .copyWith(extensions: const [AppColorTokens.light]),
    routerConfig: router,
  ));
  router.push('/room');
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Rect _board(WidgetTester tester) =>
    tester.getRect(find.byType(BoardWithCoordinates).first);

/// Square, and whole inside the window.
void _expectBoard(WidgetTester tester, Size size) {
  final board = _board(tester);
  expect(board.width, closeTo(board.height, 0.01),
      reason: 'board is ${board.size} at ${sizeLabel(size)}');
  final screen = Offset.zero & size;
  expect(screen.contains(board.topLeft), isTrue);
  expect(screen.contains(board.bottomRight - const Offset(1, 1)), isTrue,
      reason: 'board runs off the window at ${sizeLabel(size)}');
}

/// Wholly on screen and big enough to hit.
void _expectTappable(WidgetTester tester, Size size, Finder finder) {
  expectOnScreen(tester, size, finder);
  final rect = tester.getRect(finder);
  expect(rect.width >= 40 && rect.height >= 40, isTrue,
      reason: '$finder is ${rect.size} at ${sizeLabel(size)}');
}

Future<void> _openPanel(WidgetTester tester, Finder button) async {
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _closePanel(WidgetTester tester) async {
  // The end drawer closes on the scrim, left of the panel.
  await tester.tapAt(const Offset(10, 300));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadRoboto);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'tok',
      'user_id': 1,
      'user_email': 'e',
      'user_name': 'N',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
    await GameSessionService.instance.clear();
  });

  group('the bar', () {
    for (final size in [_phone, _sideways]) {
      for (final seat in ['trener', 'ucenik']) {
        testWidgets(
            'holds voice, session and the way out — $seat at '
            '${sizeLabel(size)}', (tester) async {
          await _room(tester, size, role: seat);
          expect(tester.takeException(), isNull);

          _expectTappable(tester, size, _voiceChip);
          _expectTappable(tester, size, _more);
          _expectTappable(tester, size, seat == 'trener' ? _end : _leave);
          if (seat == 'trener') {
            _expectTappable(tester, size, _session);
          } else {
            expect(_session, findsNothing,
                reason: 'the session switches are the leader\'s');
          }
          // The cloud went: the title already says „Connecting...".
          expect(find.byIcon(Icons.cloud_off), findsNothing);
          expect(find.byIcon(Icons.cloud_done), findsNothing);

          _expectBoard(tester, size);
          await _close(tester);
        }, variant: _platforms);
      }
    }

    testWidgets('⋮ carries Export to Analysis and Settings', (tester) async {
      await _room(tester, _phone, role: 'ucenik');
      await _openPanel(tester, _more);
      expect(find.text('Export to Analysis'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      await tester.tapAt(const Offset(10, 600));
      await tester.pump(const Duration(milliseconds: 400));
      await _close(tester);
    });
  });

  group('the right column is moves', () {
    const leftTheColumn = [
      'Students may move',
      'Present in classroom',
      'Audio Classroom',
      'Turn on voice',
      'Force student board to:',
      'Invite students to session',
    ];

    testWidgets('nothing of the session or the voice is in the room itself',
        (tester) async {
      await _room(tester, _phone, role: 'trener');
      for (final label in leftTheColumn) {
        expect(find.text(label, skipOffstage: false), findsNothing,
            reason: '„$label" is still on the room screen');
      }
      await _close(tester);
    });

    testWidgets('the Session panel holds the trainer\'s switches',
        (tester) async {
      await _room(tester, _phone, role: 'trener');
      await _openPanel(tester, _session);
      expect(tester.takeException(), isNull);
      for (final label in [
        'Students may move',
        'Present in classroom',
        'Invite students to session',
        'Force student board to:',
        'Room access',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      await _closePanel(tester);
      expect(find.text('Students may move'), findsNothing);
      await _close(tester);
    });

    for (final seat in ['trener', 'ucenik']) {
      testWidgets('the voice chip opens the voice panel — $seat',
          (tester) async {
        await _room(tester, _phone, role: seat);
        await _openPanel(tester, _voiceChip);
        expect(tester.takeException(), isNull);
        expect(find.text('Turn on voice'), findsOneWidget);
        await _closePanel(tester);
        await _close(tester);
      });
    }
  });

  group('a student answers under the board', () {
    const answers = [
      'Show my position to trainer',
      'Yes',
      'No',
      "I didn't understand"
    ];

    for (final size in [_phone, _sideways, _desk]) {
      testWidgets('on screen without scrolling at ${sizeLabel(size)}',
          (tester) async {
        await _room(tester, size, role: 'ucenik');
        expect(tester.takeException(), isNull);
        expect(_strip, findsOneWidget);
        for (final label in answers) {
          final button =
              find.descendant(of: _strip, matching: find.text(label));
          expectOnScreen(tester, size, button);
          expect(button.hitTestable(), findsOneWidget, reason: label);
        }
        // Held sideways the strip is beside the board, not under it.
        if (size != _sideways) {
          expect(tester.getRect(_strip).top,
              greaterThanOrEqualTo(_board(tester).bottom));
        }
        expect(find.text('Show my position to trainer', skipOffstage: false),
            findsOneWidget,
            reason: 'one door: the strip, not the left column as well');
        await _close(tester);
      });
    }

    testWidgets('the leader has no strip', (tester) async {
      await _room(tester, _phone, role: 'trener');
      expect(_strip, findsNothing);
      expect(find.text('Show my position to trainer', skipOffstage: false),
          findsNothing);
      await _close(tester);
    });
  });

  group('a student has no engine in the room', () {
    for (final size in [_phone, _desk]) {
      testWidgets(
          'no engine panel and no bar for a student, both for the '
          'leader, at ${sizeLabel(size)}', (tester) async {
        await _room(tester, size, role: 'ucenik');
        expect(find.byType(StockfishAnalysisWidget, skipOffstage: false),
            findsNothing);
        expect(find.byType(HorizontalEvalBarWidget, skipOffstage: false),
            findsNothing);
        await _close(tester);

        await _room(tester, size, role: 'trener');
        expect(find.byType(StockfishAnalysisWidget, skipOffstage: false),
            findsOneWidget,
            reason: 'the scan must be able to see the panel it looks for');
        await _close(tester);
      });
    }

    testWidgets('nobody is offered the switch', (tester) async {
      await _room(tester, _phone, role: 'trener');
      await _openPanel(tester, _session);
      expect(find.text('Allow Stockfish for student', skipOffstage: false),
          findsNothing);
      await _closePanel(tester);
      await _close(tester);
    });
  });
}
