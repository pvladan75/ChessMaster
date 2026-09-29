import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/login_screen.dart';
import 'package:chess_app/services/saved_sign_ins.dart';
import 'package:chess_app/services/session_service.dart';

import 'support/fake_password_store.dart';

/// The sign-in form with a password kept for „Remember me"
/// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md` §4.1, phase 1), against a store in
/// memory and a faked HTTP client — so every case asserts on the request
/// that actually went out, not on a method somebody promised to call
/// (CLAUDE.md rule 7).
void main() {
  late FakePasswordStore store;
  late List<http.Request> sent;

  const ana = 'ana@example.com';
  const ivan = 'ivan@example.com';
  const kept = 'kept-Secret-7';
  const typed = 'typed-Secret-8';

  http.Response accepted(String email) => http.Response(
        jsonEncode({
          'user': {'id': 11, 'email': email, 'name': 'Ana', 'role': 'korisnik'},
          'token': 'token-11',
        }),
        200,
      );

  http.Response refused(int status, String error) =>
      http.Response(jsonEncode({'error': error}), status);

  /// Puts [addresses] on the remembered list, first first, as a previous
  /// ticked sign-in on this device would have.
  Future<void> remembered(List<String> addresses) async {
    SharedPreferences.setMockInitialValues({'remembered_emails': addresses});
    await SessionService.instance.init();
  }

  /// The login screen under a router that has somewhere to go, inside a
  /// client that records every request and answers with [answer].
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) =>
              const LoginRegisterScreen(googleAvailableOverride: false),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
  }

  Future<T> withServer<T>(
    http.Response Function(http.Request) answer,
    Future<T> Function() body,
  ) =>
      http.runWithClient(
        body,
        () => MockClient((request) async {
          sent.add(request);
          return answer(request);
        }),
      );

  Finder field(String label) => find.descendant(
        of: find.ancestor(
          of: find.text(label),
          matching: find.byType(TextFormField),
        ),
        matching: find.byType(TextField),
      );

  TextField passwordField(WidgetTester tester) =>
      tester.widget<TextField>(field('Password'));
  TextField emailField(WidgetTester tester) =>
      tester.widget<TextField>(field('Email Address'));

  IconButton eye(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const Key('password-visibility')));

  /// The colour the eye's icon is actually drawn in.
  Color eyeColor(WidgetTester tester) {
    final icon = find.descendant(
        of: find.byKey(const Key('password-visibility')),
        matching: find.byType(Icon));
    return tester.widget<Icon>(icon).color ??
        IconTheme.of(tester.element(icon)).color!;
  }

  Map<String, dynamic> body(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapSignIn(WidgetTester tester) async {
    await tester.tap(find.text('Sign in with email'));
    await settle(tester);
  }

  setUp(() async {
    sent = [];
    store = FakePasswordStore();
    SavedSignIns.instance.debugUseStore(store);
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
    await SessionService.instance.init();
  });

  tearDown(() async {
    SavedSignIns.instance.debugUseStore(null);
  });

  /// No password is ever written beside the addresses — checked after every
  /// case that could have written one.
  Future<void> expectNoPasswordInPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      final value = '${prefs.get(key)}';
      expect(value.contains(kept) || value.contains(typed), isFalse,
          reason: '"$key" holds a password');
    }
  }

  testWidgets(
      'a kept password comes back with its address, hidden, and Enter signs '
      'in with it', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana]);

    await withServer((_) => accepted(ana), () async {
      await open(tester);

      expect(emailField(tester).controller!.text, ana);
      expect(passwordField(tester).controller!.text, kept);
      expect(passwordField(tester).obscureText, isTrue);

      // Nothing left to type: the button has the focus, so Enter is enough.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
    });

    expect(sent, hasLength(1));
    expect(sent.single.url.path, '/login');
    expect(body(sent.single), {'email': ana, 'password': kept});
    expect(find.text('HOME'), findsOneWidget);
    await expectNoPasswordInPrefs();
  });

  testWidgets(
      'a password is kept only after the server has accepted it, and it is '
      'the one it accepted', (tester) async {
    var writesWhenAsked = -1;
    await withServer((request) {
      writesWhenAsked = store.writes.length;
      return accepted(ana);
    }, () async {
      await open(tester);
      await tester.enterText(field('Email Address'), ana);
      await tester.enterText(field('Password'), typed);
      await tapSignIn(tester);
    });

    expect(writesWhenAsked, 0, reason: 'nothing kept before the answer');
    expect(store.kept[ana], typed);
    expect(SavedSignIns.instance.addresses, [ana]);
    await expectNoPasswordInPrefs();
  });

  testWidgets('a typed password the server refuses is never kept',
      (tester) async {
    await withServer((_) => refused(400, 'Invalid email or password'),
        () async {
      await open(tester);
      await tester.enterText(field('Email Address'), ana);
      await tester.enterText(field('Password'), typed);
      await tapSignIn(tester);
    });

    expect(sent, hasLength(1));
    expect(store.writes, isEmpty);
    expect(SavedSignIns.instance.addresses, isEmpty);
    expect(passwordField(tester).controller!.text, typed,
        reason: 'what the person typed is theirs to correct');
  });

  testWidgets(
      'a kept password the server refuses is forgotten, and the screen says '
      'so; the address stays', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana]);

    await withServer((_) => refused(400, 'Invalid email or password'),
        () async {
      await open(tester);
      await tapSignIn(tester);
    });

    expect(body(sent.single)['password'], kept);
    expect(store.kept, isEmpty);
    expect(SavedSignIns.instance.addresses, [ana]);
    expect(passwordField(tester).controller!.text, isEmpty);
    // The whole sentence, full stop included: the server's own sentence has
    // none, and without one the two ran together.
    expect(
        find.text('Invalid email or password. The saved password did not '
            'work, so it has been forgotten. Type it again.'),
        findsOneWidget);
  });

  for (final (what, answer) in [
    ('too many attempts', (_) => refused(429, 'Too many attempts.')),
    ('a server fault', (_) => refused(500, 'Server error during login')),
    (
      'no network',
      (http.Request _) => throw http.ClientException('no network'),
    ),
  ]) {
    testWidgets('$what says nothing about the kept password, so it stays',
        (tester) async {
      store.kept[ana] = kept;
      await remembered([ana]);

      await withServer(answer, () async {
        await open(tester);
        await tapSignIn(tester);
      });

      expect(body(sent.single)['password'], kept);
      expect(store.kept[ana], kept);
      expect(passwordField(tester).controller!.text, kept);
    });
  }

  testWidgets('unticked, nothing is kept and a kept one goes', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana]);

    await withServer((_) => accepted(ana), () async {
      await open(tester);
      await tester.tap(find.text('Remember me'));
      await tester.pump();
      await tester.enterText(field('Password'), typed);
      await tapSignIn(tester);
    });

    expect(body(sent.single)['password'], typed);
    expect(find.text('HOME'), findsOneWidget);
    expect(store.writes, isEmpty);
    expect(store.kept, isEmpty);
    expect(SavedSignIns.instance.addresses, isEmpty);
    await expectNoPasswordInPrefs();
  });

  testWidgets(
      'another address takes the kept password out of the field, and its own '
      'address brings it back', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana]);
    await open(tester);

    await tester.enterText(field('Email Address'), ivan);
    await tester.pump();
    expect(passwordField(tester).controller!.text, isEmpty,
        reason: 'a kept password is never sent with another address');

    await tester.enterText(field('Email Address'), ana);
    await tester.pump();
    expect(passwordField(tester).controller!.text, kept);
  });

  testWidgets('typing never loses to a kept password', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana, ivan]);
    await open(tester);

    await tester.enterText(field('Email Address'), ivan);
    await tester.pump();
    await tester.enterText(field('Password'), typed);
    await tester.enterText(field('Email Address'), ana);
    await tester.pump();

    expect(passwordField(tester).controller!.text, typed);
  });

  testWidgets(
      'choosing a remembered address fills its kept password, and one '
      'without leaves the field empty', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana, ivan]);
    await open(tester);

    await tester.tap(find.byKey(const Key('remembered-accounts')));
    await tester.pumpAndSettle();
    expect(find.text('Password saved'), findsOneWidget);
    expect(find.text('Address only'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remembered-$ivan')));
    await tester.pumpAndSettle();
    expect(emailField(tester).controller!.text, ivan);
    expect(passwordField(tester).controller!.text, isEmpty);

    await tester.tap(find.byKey(const Key('remembered-accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('remembered-$ana')));
    await tester.pumpAndSettle();
    expect(emailField(tester).controller!.text, ana);
    expect(passwordField(tester).controller!.text, kept);
  });

  testWidgets('× forgets the address and its password on this device',
      (tester) async {
    store.kept[ana] = kept;
    await remembered([ana, ivan]);
    await open(tester);

    await tester.tap(find.byKey(const Key('remembered-accounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forget-$ana')));
    await tester.pumpAndSettle();

    expect(store.kept, isEmpty);
    expect(SavedSignIns.instance.addresses, [ivan]);
    expect(passwordField(tester).controller!.text, isEmpty);
    expect(find.textContaining('is forgotten on this device'), findsOneWidget);
  });

  testWidgets('the eye shows what was typed, and never a kept password',
      (tester) async {
    store.kept[ana] = kept;
    await remembered([ana]);
    await open(tester);

    expect(eye(tester).onPressed, isNull,
        reason: 'a kept password is not shown to whoever is at the screen');
    expect(passwordField(tester).obscureText, isTrue);
    final lockedAlpha = eyeColor(tester).a;

    // Emptied and typed into, the field is the person's own. (Merely edited
    // it is not — the case below.)
    await tester.enterText(field('Password'), '');
    await tester.enterText(field('Password'), typed);
    await tester.pump();
    expect(eye(tester).onPressed, isNotNull);
    // And it looks it: the locked eye is drawn visibly fainter — luminance,
    // which reads for everybody, not a hue.
    expect(lockedAlpha, lessThan(0.5));
    expect(eyeColor(tester).a, greaterThan(0.9));

    await tester.tap(find.byKey(const Key('password-visibility')));
    await tester.pump();
    expect(passwordField(tester).obscureText, isFalse);
    await tester.tap(find.byKey(const Key('password-visibility')));
    await tester.pump();
    expect(passwordField(tester).obscureText, isTrue);

    // Shown, and then the kept one comes back: it comes back hidden.
    await tester.tap(find.byKey(const Key('password-visibility')));
    await tester.pump();
    await tester.enterText(field('Password'), '');
    await tester.enterText(field('Email Address'), ivan);
    await tester.enterText(field('Email Address'), ana);
    await tester.pump();
    expect(passwordField(tester).controller!.text, kept);
    expect(passwordField(tester).obscureText, isTrue);
    expect(eye(tester).onPressed, isNull);
  });

  testWidgets(
      'an edited kept password stays hidden until the field is emptied, and '
      'still leaves with its address', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana]);
    await open(tester);

    // One keystroke must not be the way to read the other thirteen.
    await tester.enterText(field('Password'), '${kept}x');
    await tester.pump();
    expect(eye(tester).onPressed, isNull);
    expect(passwordField(tester).obscureText, isTrue);

    await tester.enterText(field('Email Address'), ivan);
    await tester.pump();
    expect(passwordField(tester).controller!.text, isEmpty,
        reason: 'grown from a kept password, it goes with its address');

    await tester.enterText(field('Password'), typed);
    await tester.pump();
    expect(eye(tester).onPressed, isNotNull,
        reason: 'typed into an empty field, it is the person\'s own');
  });

  testWidgets(
      'an edited kept password the server refuses is not forgotten: it was '
      'not the kept one', (tester) async {
    store.kept[ana] = kept;
    await remembered([ana]);

    await withServer((_) => refused(400, 'Invalid email or password'),
        () async {
      await open(tester);
      await tester.enterText(field('Password'), '${kept}x');
      await tapSignIn(tester);
    });

    expect(body(sent.single)['password'], '${kept}x');
    expect(store.kept[ana], kept);
  });

  testWidgets('the eye works in registration too', (tester) async {
    await open(tester);
    await tester.tap(find.text("Don't have an account? Register with email"));
    await tester.pumpAndSettle();
    await tester.enterText(field('Password'), typed);
    await tester.tap(find.byKey(const Key('password-visibility')));
    await tester.pump();

    expect(passwordField(tester).obscureText, isFalse);
  });

  testWidgets(
      'a store that will not keep the password does not stop the sign-in, and '
      'says so', (tester) async {
    store.refuseWrite = true;
    await withServer((_) => accepted(ana), () async {
      await open(tester);
      await tester.enterText(field('Email Address'), ana);
      await tester.enterText(field('Password'), typed);
      await tapSignIn(tester);
    });

    expect(find.text('HOME'), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    await expectNoPasswordInPrefs();
  });

  testWidgets('the sentence under Remember me names where the password goes',
      (tester) async {
    await open(tester);

    expect(
        find.text('Your email and password are kept in Windows Credential '
            'Manager, and you stay signed in.'),
        findsOneWidget);
    expect(find.text('You stay signed in on this device.'), findsNothing);
  });
}
