import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/jwt_expiry.dart';
import 'package:chess_app/services/session_service.dart';

/// **A session the server has dropped must not go on looking like one.**
///
/// Reported live on 22.8.2026: the app said the login had expired and still
/// considered the user signed in, so getting back in meant finding "Odjava"
/// first and signing out of something that was already gone. The socket was
/// refused (`[SOCKET AUTH] Rejected connection: jwt expired`), the dashboard
/// showed its banner, and nothing turned either into being signed out.
///
/// The other half of the rule is the one that is easier to break: **"I could
/// not tell" must never arrive as "you are out."** A server that is unreachable,
/// a token this app cannot parse, a socket that failed for any of the ordinary
/// reasons — none of those is a refusal, and treating them as one would sign
/// people out of a working session every time the wifi drops.
void main() {
  /// A token that says it dies at [expiry]. Unsigned: nothing here verifies a
  /// token, and the app must not either — `exp` is read, never trusted as proof.
  String tokenExpiring(DateTime expiry) {
    String segment(Map<String, dynamic> claims) => base64Url
        .encode(utf8.encode(jsonEncode(claims)))
        .replaceAll('=', ''); // real JWTs are unpadded
    return '${segment({'alg': 'HS256'})}.'
        '${segment({'id': 1, 'exp': expiry.millisecondsSinceEpoch ~/ 1000})}.'
        'not-a-signature';
  }

  final now = DateTime.utc(2026, 8, 27, 12);

  group('what a token says about its own death', () {
    test('a token past its exp is expired', () {
      final token = tokenExpiring(now.subtract(const Duration(minutes: 1)));
      expect(isJwtExpired(token, now: now), isTrue);
    });

    test('a token with hours left is not', () {
      final token = tokenExpiring(now.add(const Duration(hours: 6)));
      expect(isJwtExpired(token, now: now), isFalse);
    });

    test('one about to die counts as dead', () {
      // The alternative is a request that leaves the app and comes back
      // refused: the same end, one round trip later and one step further from
      // the place that could explain it.
      final token = tokenExpiring(now.add(const Duration(seconds: 5)));
      expect(isJwtExpired(token, now: now), isTrue);
    });

    test('a token this cannot read is not called expired', () {
      // The rule the server's account guard is built on, in the other
      // direction: silence about a right is not the right, and it is not the
      // refusal either.
      expect(isJwtExpired('test-token', now: now), isFalse);
      expect(isJwtExpired('a.b.c', now: now), isFalse);
      expect(isJwtExpired('', now: now), isFalse);
      expect(jwtExpiry('nonsense'), isNull);
    });

    test('a token with no exp claim says nothing', () {
      final noExp = '${base64Url.encode(utf8.encode('{}')).replaceAll('=', '')}'
          '.${base64Url.encode(utf8.encode('{"id":1}')).replaceAll('=', '')}'
          '.sig';
      expect(jwtExpiry(noExp), isNull);
      expect(isJwtExpired(noExp, now: now), isFalse);
    });
  });

  group('a refusal at the socket, told apart from a bad connection', () {
    test("the server's own sentence is a refusal", () {
      expect(
        looksLikeRefusedToken('Invalid or expired authentication token'),
        isTrue,
      );
      expect(looksLikeRefusedToken(Exception('jwt expired')), isTrue);
    });

    test('a server that is simply not there is not', () {
      // Signing somebody out because the wifi dropped would be worse than the
      // bug this file is about.
      expect(looksLikeRefusedToken('websocket error'), isFalse);
      expect(looksLikeRefusedToken('xhr poll error'), isFalse);
      expect(looksLikeRefusedToken('timeout'), isFalse);
      expect(looksLikeRefusedToken(null), isFalse);
    });
  });

  group('the session itself', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SessionService.instance.signOut();
    });

    test('a stored token that has run out is not restored', () async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'user_token': tokenExpiring(DateTime.now().toUtc().subtract(
              const Duration(days: 1),
            )),
        'user_id': 7,
        'user_email': 'vladan@example.com',
        'last_email': 'vladan@example.com',
        'user_name': 'Vladan',
        'user_role': 'trener',
      });

      await SessionService.instance.init();

      expect(SessionService.instance.isSignedIn, isFalse,
          reason: 'inače aplikacija pozdravi po imenu, a svaki zahtev iza tog '
              'pozdrava bude odbijen');
      expect(SessionService.instance.sessionExpired, isTrue);
      expect(SessionService.instance.expiryReason, 'expired');
      // The address stays: signing out says "not right now", not "forget me",
      // and an expiry says even less than that.
      expect(SessionService.instance.lastEmail, 'vladan@example.com');
    });

    test('a stored token with time left is restored as before', () async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'user_token':
            tokenExpiring(DateTime.now().toUtc().add(const Duration(days: 6))),
        'user_id': 7,
        'user_email': 'vladan@example.com',
        'user_name': 'Vladan',
        'user_role': 'trener',
      });

      await SessionService.instance.init();

      expect(SessionService.instance.isSignedIn, isTrue);
      expect(SessionService.instance.sessionExpired, isFalse);
    });

    test('expiring clears the session and keeps the reason', () async {
      await SessionService.instance.signIn(
        UserSession(
            token: 'abc', id: 1, email: 'a@b.c', name: 'A', role: 'korisnik'),
        rememberMe: true,
      );

      await SessionService.instance.expire(reason: 'account-gone');

      expect(SessionService.instance.isSignedIn, isFalse);
      expect(SessionService.instance.expiryReason, 'account-gone');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_token'), isNull,
          reason: 'slip koji server ne prima ne sme da ostane na disku');
    });

    test('three refused requests are one trip to the login screen', () async {
      await SessionService.instance.signIn(
        UserSession(
            token: 'abc', id: 1, email: 'a@b.c', name: 'A', role: 'korisnik'),
        rememberMe: true,
      );

      var notifications = 0;
      void count() => notifications++;
      SessionService.instance.addListener(count);
      addTearDown(() => SessionService.instance.removeListener(count));

      await SessionService.instance.expire();
      await SessionService.instance.expire();
      await SessionService.instance.expire();

      expect(notifications, 1);
    });

    test('a guest has nothing to expire, and is not sent anywhere', () {
      // `expire()` is called from wherever a refusal is heard, and some of
      // those places are reached by somebody who never signed in. Setting the
      // flag for them would push a guest to the login screen over somebody
      // else's dead token.
      expect(SessionService.instance.isSignedIn, isFalse);
      SessionService.instance.expire();
      expect(SessionService.instance.sessionExpired, isFalse);
    });

    test('signing in again forgets that anything expired', () async {
      await SessionService.instance.signIn(
        UserSession(
            token: 'abc', id: 1, email: 'a@b.c', name: 'A', role: 'korisnik'),
        rememberMe: false,
      );
      await SessionService.instance.expire();
      expect(SessionService.instance.sessionExpired, isTrue);

      await SessionService.instance.signIn(
        UserSession(
            token: 'abc', id: 1, email: 'a@b.c', name: 'A', role: 'korisnik'),
        rememberMe: false,
      );

      expect(SessionService.instance.sessionExpired, isFalse);
    });
  });

  group('and the app leaves the screen it was on', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SessionService.instance.signOut();
    });

    /// The app's own redirect and the app's own refresh wiring, over two
    /// stand-in screens. The real route table is not used on purpose: its home
    /// screen opens sockets and fetches, which would make this a test of
    /// everything.
    Widget appWith(GlobalKey<NavigatorState> key) {
      final router = GoRouter(
        navigatorKey: key,
        initialLocation: '/somewhere',
        refreshListenable: SessionService.instance,
        redirect: expiredSessionRedirect,
        routes: [
          GoRoute(
              path: '/somewhere',
              builder: (_, __) => const Text('a lesson in progress')),
          GoRoute(
              path: AppRoutes.login, builder: (_, __) => const Text('prijava')),
        ],
      );
      return MaterialApp.router(routerConfig: router);
    }

    testWidgets('an expired session lands on the login screen from anywhere',
        (tester) async {
      await tester.pumpWidget(appWith(GlobalKey<NavigatorState>()));
      expect(find.text('a lesson in progress'), findsOneWidget);

      await SessionService.instance.signIn(
        UserSession(
            token: 'abc', id: 1, email: 'a@b.c', name: 'A', role: 'korisnik'),
        rememberMe: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('a lesson in progress'), findsOneWidget,
          reason: 'prijava sama po sebi ne pomera nikoga');

      await SessionService.instance.expire();
      await tester.pumpAndSettle();

      expect(find.text('prijava'), findsOneWidget);
    });

    testWidgets('a guest is left alone', (tester) async {
      // Signing in is optional in this app. A rule that read "not signed in →
      // login" would lock the door on the people it was never about.
      await tester.pumpWidget(appWith(GlobalKey<NavigatorState>()));
      await tester.pumpAndSettle();

      expect(find.text('a lesson in progress'), findsOneWidget);
      expect(SessionService.instance.isSignedIn, isFalse);
    });

    testWidgets('once the reason has been shown, nothing keeps redirecting',
        (tester) async {
      await tester.pumpWidget(appWith(GlobalKey<NavigatorState>()));
      await SessionService.instance.signIn(
        UserSession(
            token: 'abc', id: 1, email: 'a@b.c', name: 'A', role: 'korisnik'),
        rememberMe: false,
      );
      await SessionService.instance.expire();
      await tester.pumpAndSettle();
      expect(find.text('prijava'), findsOneWidget);

      // What the login screen does after it has said why they are there.
      SessionService.instance.acknowledgeExpiry();
      await tester.pumpAndSettle();

      expect(SessionService.instance.sessionExpired, isFalse,
          reason: 'inače „Nastavi kao Gost" vraća pravo nazad na prijavu');
    });
  });
}
