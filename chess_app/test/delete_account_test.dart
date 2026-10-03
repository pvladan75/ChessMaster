import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/login_screen.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/services/saved_sign_ins.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/delete_account_dialog.dart';

import 'support/fake_password_store.dart';

/// „Delete account" in Settings (the owner's decisions of 3.10.2026): the
/// account's password confirms it, or the typed word for an account that has
/// none; the request is sent once; and when the server says it is gone, this
/// device forgets the session, the address and the kept password.
///
/// The server is faked at the client and every case asserts on the request —
/// what was sent, and how many times.
void main() {
  late FakePasswordStore store;
  const ana = 'ana@example.com';

  final signedIn = UserSession(
    token: 't',
    id: 11,
    email: ana,
    name: 'Ana',
    role: 'korisnik',
  );

  setUp(() async {
    store = FakePasswordStore();
    SavedSignIns.instance.debugUseStore(store);
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.init();
    await SessionService.instance
        .signIn(signedIn, rememberMe: true, password: 'kept-Secret-7');
  });

  tearDown(() async {
    await SessionService.instance.signOut();
    SessionService.instance.acknowledgeExpiry();
    SavedSignIns.instance.debugUseStore(null);
  });

  /// A server that says which proof it wants and answers `/me/delete` with
  /// [answer]. Every delete request it was sent is in `sent`.
  ({AccountStandingService standing, List<Map<String, dynamic>> sent}) server({
    String confirmedBy = 'password',
    bool reachable = true,
    FutureOr<http.Response> Function()? answer,
  }) {
    final sent = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (!reachable) throw const FormatException('no route to host');
      if (request.url.path == '/me/standing') {
        return http.Response(
            jsonEncode({
              'ageKnown': true,
              'birthYear': 1990,
              'deletionConfirmedBy': confirmedBy,
            }),
            200);
      }
      if (request.url.path == '/me/delete' && request.method == 'POST') {
        expect(request.headers['Authorization'], 'Bearer t');
        sent.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
        return await (answer?.call() ??
            http.Response(jsonEncode({'deleted': true}), 200));
      }
      return http.Response('{}', 404);
    });
    return (standing: AccountStandingService(client: client), sent: sent);
  }

  Future<void> openDialog(
    WidgetTester tester,
    AccountStandingService standing, {
    Size size = const Size(1000, 800),
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showDeleteAccountDialog(context, standing: standing),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final proof = find.byKey(const Key('delete-account-proof'));
  final confirm = find.byKey(const Key('delete-account-confirm'));
  bool enabled(WidgetTester tester) =>
      tester.widget<FilledButton>(confirm).onPressed != null;

  testWidgets('the password is sent, and a deleted account leaves this device',
      (tester) async {
    final s = server();
    await openDialog(tester, s.standing);

    expect(tester.widget<TextField>(proof).obscureText, isTrue);
    expect(find.text('Your password'), findsOneWidget);
    expect(enabled(tester), isFalse, reason: 'nothing typed yet');
    expect(store.kept[ana], 'kept-Secret-7');

    await tester.enterText(proof, 'my password');
    await tester.pump();
    expect(enabled(tester), isTrue);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(s.sent, [
      {'password': 'my password'}
    ]);
    expect(find.text('Delete account'), findsNothing,
        reason: 'the dialog closed');
    expect(SessionService.instance.isSignedIn, isFalse);
    expect(SessionService.instance.expiryReason,
        SessionService.accountDeletedReason);
    expect(store.kept, isEmpty, reason: 'the kept password went with it');
    expect(SavedSignIns.instance.addresses, isEmpty);
    expect(s.standing.current, isNull,
        reason: 'the next account is not shown the standing of this one');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_token'), isNull);
  });

  testWidgets('a refusal is shown, and nothing on this device changes',
      (tester) async {
    final s = server(
        answer: () => http.Response(
            jsonEncode({'error': 'Wrong password.', 'code': 'wrong-password'}),
            400));
    await openDialog(tester, s.standing);
    await tester.enterText(proof, 'not it');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(s.sent.length, 1);
    expect(
        tester.widget<Text>(find.byKey(const Key('delete-account-error'))).data,
        'Wrong password.');
    expect(proof, findsOneWidget, reason: 'the dialog stays');
    expect(enabled(tester), isTrue, reason: 'and may be tried again');
    expect(SessionService.instance.isSignedIn, isTrue);
    expect(SessionService.instance.expiryReason, isNull);
    expect(store.kept[ana], 'kept-Secret-7');
  });

  testWidgets('an account with no password types the word, exactly',
      (tester) async {
    final s = server(confirmedBy: 'word');
    await openDialog(tester, s.standing);

    expect(tester.widget<TextField>(proof).obscureText, isFalse);
    expect(find.text('Type DELETE to confirm'), findsOneWidget);
    for (final wrong in ['delete', 'DELET', 'DELETE ']) {
      await tester.enterText(proof, wrong);
      await tester.pump();
      expect(enabled(tester), isFalse, reason: '"$wrong"');
    }
    // Enter in the field goes through the same lock as the button.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(s.sent, isEmpty);

    await tester.enterText(proof, 'DELETE');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(s.sent, [
      {'confirm': 'DELETE'}
    ]);
    expect(SessionService.instance.isSignedIn, isFalse);
  });

  testWidgets('two taps and an Enter while the request is out send it once',
      (tester) async {
    final answer = Completer<http.Response>();
    final s = server(answer: () => answer.future);
    await openDialog(tester, s.standing);
    await tester.enterText(proof, 'my password');
    await tester.pump();

    await tester.tap(confirm);
    await tester.pump();
    await tester.tap(confirm, warnIfMissed: false);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(s.sent.length, 1);
    expect(SessionService.instance.isSignedIn, isTrue,
        reason: 'nothing ends before the server has answered');
    // The field and Cancel are locked too: neither would stop the request.
    expect(tester.widget<TextField>(proof).enabled, isFalse);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNull);

    answer.complete(http.Response(jsonEncode({'deleted': true}), 200));
    await tester.pumpAndSettle();
    expect(s.sent.length, 1);
    expect(SessionService.instance.isSignedIn, isFalse);
  });

  testWidgets('a server that cannot be reached offers nothing to confirm',
      (tester) async {
    final s = server(reachable: false);
    await openDialog(tester, s.standing);

    expect(find.byKey(const Key('delete-account-unreachable')), findsOneWidget);
    expect(proof, findsNothing);
    expect(enabled(tester), isFalse);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(SessionService.instance.isSignedIn, isTrue);
  });

  testWidgets('an answer that is not „deleted" is not taken for one',
      (tester) async {
    final s = server(answer: () => http.Response('{}', 200));
    await openDialog(tester, s.standing);
    await tester.enterText(proof, 'my password');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-account-error')), findsOneWidget);
    expect(SessionService.instance.isSignedIn, isTrue);
  });

  testWidgets('on a 360 dp phone with the keyboard up the field is reachable',
      (tester) async {
    final s = server();
    await openDialog(tester, s.standing,
        size: const Size(360, 640), keyboard: 300);

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(proof);
    await tester.pump();
    final field = tester.getRect(proof);
    expect(field.bottom, lessThanOrEqualTo(640 - 300),
        reason: 'the field is above the keyboard: $field');
    expect(tester.getRect(confirm).right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });

  group('the door in Settings', () {
    Future<void> openSettings(WidgetTester tester, UserSession session) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: SettingsScreen(session: session),
        ));
        await tester.pump(const Duration(milliseconds: 100));
      }, () => MockClient((_) async => http.Response('{}', 200)));
    }

    final door = find.byKey(const Key('open-delete-account'));

    testWidgets('a signed-in account has it, and it opens the dialog',
        (tester) async {
      await openSettings(tester, signedIn);
      expect(door, findsOneWidget);

      await http.runWithClient(() async {
        await tester.tap(door);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }, () => MockClient((_) async => http.Response('{}', 404)));
      expect(confirm, findsOneWidget);
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    });

    testWidgets('a guest has no account to delete', (tester) async {
      await SessionService.instance.signOut();
      await openSettings(tester, UserSession.guest());

      expect(door, findsNothing);
      // The section it would stand in is drawn; only the account's rows are
      // absent.
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.byKey(const Key('settings-sign-in')), findsOneWidget);
    });
  });

  testWidgets('the sign-in screen says the account was deleted, once',
      (tester) async {
    await SessionService.instance
        .expire(reason: SessionService.accountDeletedReason);
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const LoginRegisterScreen(),
    ));
    await tester.pump();

    expect(find.text('Your account has been deleted.'), findsOneWidget);
    expect(find.textContaining('no longer exists'), findsNothing);
    expect(SessionService.instance.expiryReason, isNull,
        reason: 'shown, so acknowledged');
  });
}
