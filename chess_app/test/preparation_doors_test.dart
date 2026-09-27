// The doors change, and the room loses Preparation — phase 4 of
// `docs/PLAN-PRIPREMA.md`.
//
// Until this phase Preparation was the live room entered with the room code
// `STUDIO`: twenty branches of `chess_game_screen.dart` asked for that code by
// name, the screen opened a socket it joined no room on, and its title read
// „Connecting..." until that socket was up. Phases 1–3 built
// `PreparationScreen`; nothing in the app could reach it. This file holds what
// phase 4 changes:
//
//  * **both doors open the new screen** — Teach's „Preparation" card and the
//    Library's „New exercise" — walked from the screen a person starts on, not
//    asked of a callback (rule 10);
//  * **the room has no special code**: a room entered as `STUDIO` is a room
//    like any other, with a way out and no recording;
//  * **`STUDIO` is written nowhere as a string** in `lib/`, `test/` or `site/`
//    but in the places listed here, each with its reason.
//
// Seven of the ten cases were red on master at d5f37089, before the phase
// was written: the path built the router's error page, both doors opened
// `ChessGamePage`, the `STUDIO` room had no way out, and the guard found the
// code written in `lib/` and in sixteen test files. The three that were green
// are the path's spelling, the guard's own check that it can see a literal,
// and the manual, which never named the code — that one is a fence for later
// and says nothing about this phase.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/preparation/screens/preparation_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/dart_source.dart';
import 'support/landscape.dart' show loadRoboto;

/// Written out rather than read from `AppRoutes`: a path is a contract (deep
/// links, restored navigation), and a test that reads the constant follows the
/// constant wherever it goes.
const _path = '/preparation';

Future<GoRouter> _open(WidgetTester tester, String path,
    {Size size = const Size(1400, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: path,
    routes: appRouteTable,
    errorBuilder: appRouteErrorBuilder,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    theme: ThemeData(fontFamily: 'Roboto')
        .copyWith(extensions: const [AppColorTokens.light]),
    routerConfig: router,
  ));
  // Not pumpAndSettle: Home and the Library keep requests going that nothing
  // answers in a test.
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

/// Runs out a page transition: one pump lets the router rebuild, the second
/// finishes the slide.
Future<void> _arrive(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Takes the screen down, so that a case that failed half way does not leave
/// its screen standing for the next one.
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Every Dart file under [dir], and every page under `site/`.
Iterable<File> _files(String dir, String ending) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith(ending));

String _slashed(String path) => path.replaceAll('\\', '/');

/// Where `STUDIO` may still be written as a string, and why. A file that is
/// not here and writes it fails the guard; a file that is here and no longer
/// writes it fails too, so the list cannot outlive its reasons.
const _allowed = <String, String>{
  'test/preparation_doors_test.dart':
      'this file: the case that enters a room by that code, and the guard',
};

void main() {
  setUpAll(loadRoboto);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'test-token',
      'user_id': 1,
      'user_email': 'test@example.com',
      'user_name': 'Test',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
  });

  group('the path', () {
    test('is the one written here', () {
      expect(AppRoutes.preparation, _path);
    });

    testWidgets('leads to the screen', (tester) async {
      await _open(tester, _path);
      addTearDown(() => _close(tester));
      expect(find.byType(PreparationScreen), findsOneWidget,
          reason: '$_path does not build Preparation');
      expect(find.byType(ChessGamePage), findsNothing);
    });

    testWidgets('and the screen it builds is the signed-in account\'s',
        (tester) async {
      await _open(tester, _path);
      addTearDown(() => _close(tester));
      final screen =
          tester.widget<PreparationScreen>(find.byType(PreparationScreen));
      expect(screen.userSession.token, 'test-token',
          reason: 'a screen built for a guest saves nothing');
      expect(screen.userSession.id, 1);
    });
  });

  group('the doors', () {
    testWidgets('Teach\'s „Preparation" card opens the screen, not the room',
        (tester) async {
      await _open(tester, AppRoutes.home, size: const Size(1400, 1800));
      addTearDown(() => _close(tester));

      await tester.tap(find.text('Teach').first);
      await _arrive(tester);
      final card = find.ancestor(
          of: find.text('Preparation'), matching: find.byType(Card));
      expect(card, findsOneWidget,
          reason: 'the Teach tab has no Preparation card to press');
      await tester.tap(find.descendant(of: card, matching: find.text('Open')),
          warnIfMissed: false);
      await _arrive(tester);

      expect(find.byType(PreparationScreen), findsOneWidget,
          reason: 'the card opened something else');
      expect(find.byType(ChessGamePage), findsNothing,
          reason: 'the card still opens the room');
    });

    testWidgets('the Library\'s „New exercise" opens the screen, not the room',
        (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/library/positions')) {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        return http.Response('[]', 200);
      });
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/shelf',
        routes: [
          GoRoute(
            path: '/shelf',
            builder: (_, __) => LibraryScreen(
              session: SessionService.instance.current,
              initialChip: LibraryChip.exercises,
              positionLibrary:
                  PositionLibraryService(authToken: 'tok', client: client),
              lessonApi: LessonApiService(authToken: 'tok', client: client),
            ),
          ),
          ...appRouteTable,
        ],
        errorBuilder: appRouteErrorBuilder,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        theme: ThemeData(fontFamily: 'Roboto')
            .copyWith(extensions: const [AppColorTokens.light]),
        routerConfig: router,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      addTearDown(() => _close(tester));

      expect(find.text('New exercise'), findsOneWidget,
          reason: 'the door is not on the shelf, so nothing below is asked');
      await tester.tap(find.text('New exercise'));
      await _arrive(tester);

      expect(find.byType(PreparationScreen), findsOneWidget);
      expect(find.byType(ChessGamePage), findsNothing);
    });
  });

  group('the room has no special code', () {
    Future<void> room(WidgetTester tester, {required String role}) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/library/positions')) {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        if (req.url.path == '/trainer/students') {
          return http.Response(jsonEncode({'students': <dynamic>[]}), 200);
        }
        return http.Response('[]', 200);
      });
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto')
            .copyWith(extensions: const [AppColorTokens.light]),
        home: ChessGamePage(
          userSession: UserSession(
              id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
          roomCode: 'STUDIO',
          initialRole: role,
          lessonApi: LessonApiService(authToken: 'tok', client: client),
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
          groupApi: GroupApiService(client: client),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      addTearDown(() => _close(tester));
    }

    testWidgets('a student seat in it is a student seat', (tester) async {
      await room(tester, role: 'ucenik');
      expect(find.byKey(const Key('room-leave-session')), findsOneWidget,
          reason: 'a room with no way out: the code was read as Preparation');
      expect(find.text('Arrow drawing'), findsNothing);
      expect(find.text('Arrow drawing (Trainer)'), findsNothing,
          reason: 'the code made a student lead');
      expect(find.text('Board is locked by the trainer.'), findsOneWidget);
    });

    testWidgets('nothing in it records, whoever sits in it', (tester) async {
      await room(tester, role: 'trener');
      // Stands where it was drawn: in the bar, beside the way out.
      expect(find.byKey(const Key('room-end-session')), findsOneWidget,
          reason: 'the bar the button stood in is not the one on screen');
      expect(find.byKey(const Key('prep-record-lesson')), findsNothing);
      expect(find.byTooltip('Start recording'), findsNothing);
      // Nor under the names the button has on Preparation's own screen.
      expect(find.byKey(const Key('prep-record')), findsNothing);
      expect(find.byTooltip('Record'), findsNothing);
      expect(find.text('Record'), findsNothing);
      expect(find.text('Solo practice — classroom is off'), findsNothing);
      expect(find.text('Preparation controls'), findsNothing);
    });
  });

  group('the code is written nowhere', () {
    // As a string literal, read by structure (rule 4): comments tell the
    // history and may name it.
    bool writes(String literal) => literal.trim() == 'STUDIO';

    test('in lib/ or test/, but where this file says why', () {
      final found = <String>{};
      for (final dir in ['lib', 'test']) {
        for (final file in _files(dir, '.dart')) {
          if (literalsIn(file.readAsStringSync()).any(writes)) {
            found.add(_slashed(file.path));
          }
        }
      }
      expect(found.difference(_allowed.keys.toSet()), isEmpty,
          reason: 'the room\'s old code is asked for by name again');
      expect(_allowed.keys.toSet().difference(found), isEmpty,
          reason: 'a file is excused for a literal it no longer writes');
    });

    test('the guard can see one', () {
      expect(literalsIn("final a = roomCode == 'STUDIO';").any(writes), isTrue);
      expect(
          literalsIn("// it was 'STUDIO'\nfinal a = 1;").any(writes), isFalse);
    });

    test('nor in the manual', () {
      final site = Directory('../site');
      expect(site.existsSync(), isTrue,
          reason: 'the manual was not found, so nothing was read');
      final pages = _files(site.path, '.html').toList();
      expect(pages, isNotEmpty);
      final naming = [
        for (final page in pages)
          if (page.readAsStringSync().contains('STUDIO')) _slashed(page.path),
      ];
      expect(naming, isEmpty);
    });
  });
}
