import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'support/landscape.dart' show loadRoboto;

/// Settings laid out for the window it is in
/// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D2 A and D6, phase 3): the
/// sections flow into columns, the phone keeps one, and the header says who
/// is signed in and offers the right door.
void main() {
  // Text measured in a real font: squares would be a layout of squares.
  setUpAll(loadRoboto);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.init();
    await AppSettingsService.instance.init();
  });

  final signedIn = UserSession(
    token: 't',
    id: 11,
    email: 'ana@example.com',
    name: 'Ana Petrović',
    role: 'korisnik',
  );

  const headings = [
    'ACCOUNT',
    'APPEARANCE',
    'BOARD AND ENGINE',
    'SPEECH (READING MESSAGES)',
    'HELP',
  ];

  Future<void> open(WidgetTester tester, Size size, UserSession session) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.preferences,
      routes: [
        GoRoute(
          path: AppRoutes.preferences,
          builder: (_, __) => SettingsScreen(session: session),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const Scaffold(body: Text('SIGN-IN SCREEN')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(fontFamily: 'Roboto'),
      ));
      await tester.pump(const Duration(milliseconds: 100));
    }, () => MockClient((_) async => http.Response('{}', 200)));
  }

  /// The distinct left edges the section headings are painted at.
  Set<double> columnLefts(WidgetTester tester) => {
        for (final h in headings)
          if (find.text(h).evaluate().isNotEmpty)
            tester.getTopLeft(find.text(h)).dx.roundToDouble(),
      };

  for (final (size, columns) in const [
    (Size(1536, 792), 4),
    (Size(900, 700), 3),
    (Size(360, 640), 1),
  ]) {
    testWidgets(
        '${size.width.toInt()} wide: $columns column(s), counted where they '
        'are painted', (tester) async {
      await open(tester, size, signedIn);

      expect(columnLefts(tester), hasLength(columns));
    });
  }

  testWidgets('on a phone the sections read top to bottom in their order',
      (tester) async {
    await open(tester, const Size(360, 640), signedIn);
    // The lazy list builds what it reaches; walk it down to the last one.
    await tester.scrollUntilVisible(find.text('HELP'), 300,
        scrollable: find.byType(Scrollable).first);

    final tops = [
      for (final h in headings) tester.getTopLeft(find.text(h)).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: headings[i]);
    }
  });

  testWidgets('wide, the first row reads Account, Appearance, Board, Speech',
      (tester) async {
    await open(tester, const Size(1536, 792), signedIn);
    final lefts = [
      for (final h in headings.take(4)) tester.getTopLeft(find.text(h)).dx,
    ];
    for (var i = 1; i < lefts.length; i++) {
      expect(lefts[i], greaterThan(lefts[i - 1]), reason: headings[i]);
    }
    // Help is dealt under Account, in the first column.
    expect(tester.getTopLeft(find.text('HELP')).dx,
        tester.getTopLeft(find.text('ACCOUNT')).dx);
  });

  for (final size in const [
    Size(360, 640),
    Size(900, 700),
    Size(1536, 792),
    Size(1920, 1080),
  ]) {
    testWidgets('nothing overflows at ${size.width.toInt()}', (tester) async {
      // An overflow throws in a test build; pumping is the check. The phone
      // is walked to the end so every section has been laid out.
      await open(tester, size, signedIn);
      await tester.scrollUntilVisible(find.text('HELP'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final size in const [Size(900, 700), Size(1536, 792)]) {
      testWidgets(
          'the board choices are square on ${platform.name} at '
          '${size.width.toInt()}', (tester) async {
        // Reset inside the body: the binding checks it is unset before any
        // tear-down runs.
        debugDefaultTargetPlatformOverride = platform;
        try {
          await open(tester, size, signedIn);

          final boards = find.byType(BoardThumbnail);
          expect(boards, findsWidgets);
          for (final e in boards.evaluate()) {
            final r = tester.getRect(find.byWidget(e.widget));
            expect(r.width, r.height);
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }

  testWidgets('„ACCOUNT" is one section', (tester) async {
    await open(tester, const Size(1536, 792), signedIn);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('STOCKFISH ENGINE'), findsNothing);
    expect(find.text('BOARD AND PANEL APPEARANCE'), findsNothing);
    expect(find.text('KEYBOARD SHORTCUTS'), findsNothing);
  });

  testWidgets('signed in: name, address, no badge, and „Sign out" asks first',
      (tester) async {
    await open(tester, const Size(1536, 792), signedIn);
    final header = find.byKey(const Key('settings-profile'));

    expect(find.descendant(of: header, matching: find.text('Ana Petrović')),
        findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('ana@example.com')),
        findsOneWidget);
    expect(
        find.descendant(of: header, matching: find.text('User')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
    expect(find.text('SIGN-IN SCREEN'), findsNothing);
  });

  testWidgets(
      'a guest is „Guest", with no address, and „Sign in" goes straight to '
      'the sign-in screen', (tester) async {
    await open(tester, const Size(1536, 792), UserSession.guest());
    final header = find.byKey(const Key('settings-profile'));

    expect(find.descendant(of: header, matching: find.text('Guest')),
        findsOneWidget);
    expect(find.descendant(of: header, matching: find.textContaining('@')),
        findsNothing);
    expect(find.descendant(of: header, matching: find.textContaining('Gost')),
        findsNothing);
    expect(find.byKey(const Key('settings-sign-out')), findsNothing);

    await tester.tap(find.byKey(const Key('settings-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('SIGN-IN SCREEN'), findsOneWidget);
  });

  testWidgets('the phone puts the header\'s button under the name',
      (tester) async {
    await open(tester, const Size(360, 640), signedIn);
    final name = tester.getRect(find.text('Ana Petrović'));
    final button = tester.getRect(find.byKey(const Key('settings-sign-out')));
    expect(button.top, greaterThan(name.bottom));
    // And the address is read whole, not cut by the button beside it.
    expect(find.text('ana@example.com'), findsOneWidget);
    final address = tester.getRect(find.text('ana@example.com'));
    expect(address.width, greaterThan(100));
  });
}
