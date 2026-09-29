import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/services/saved_sign_ins.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/fake_password_store.dart';

/// „Saved sign-in on this computer" in Settings: where „Remember me" kept
/// this account's password, and the way to take it back
/// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md` §4.1).
void main() {
  late FakePasswordStore store;
  const ana = 'ana@example.com';
  const kept = 'kept-Secret-7';

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
    SharedPreferences.setMockInitialValues({
      'remembered_emails': [ana],
    });
    await SessionService.instance.init();
  });

  tearDown(() => SavedSignIns.instance.debugUseStore(null));

  /// Settings in a window tall enough to hold every card, with a server that
  /// answers every question with nothing, so the statistics card never
  /// reaches a real network.
  Future<void> open(WidgetTester tester, UserSession session) async {
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

  testWidgets(
      'a kept password shows where it is kept, and Forget takes it and the '
      'address', (tester) async {
    store.kept[ana] = kept;
    await open(tester, signedIn);

    final row = find.byKey(const Key('saved-sign-in'));
    expect(row, findsOneWidget);
    expect(
        find.descendant(
            of: row,
            matching: find.textContaining('Windows Credential Manager')),
        findsOneWidget);

    await tester.tap(find.byKey(const Key('forget-saved-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(store.kept, isEmpty);
    expect(SavedSignIns.instance.addresses, isEmpty);
    expect(row, findsNothing);
    expect(find.textContaining('Forgotten.'), findsOneWidget);
  });

  testWidgets('with nothing kept there is no row', (tester) async {
    await open(tester, signedIn);

    expect(find.byKey(const Key('saved-sign-in')), findsNothing);
    // The screen is whole: the account section is drawn, only this row is
    // absent — an absence claim stands where the row would have been.
    expect(find.text('Birth year'), findsOneWidget);
  });

  testWidgets('a guest has no row, whatever is kept on the computer',
      (tester) async {
    final guest = UserSession.guest();
    store.kept[guest.email] = kept;
    SharedPreferences.setMockInitialValues({
      'remembered_emails': [guest.email],
    });
    await SessionService.instance.init();

    await open(tester, guest);

    expect(find.byKey(const Key('saved-sign-in')), findsNothing);
    expect(find.text('HELP'), findsOneWidget);
  });

  testWidgets('a store that will not let go is said, not reported as done',
      (tester) async {
    store.kept[ana] = kept;
    store.refuseDelete = true;
    await open(tester, signedIn);

    await tester.tap(find.byKey(const Key('forget-saved-sign-in')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('could not be removed'), findsOneWidget);
    expect(find.textContaining('Forgotten.'), findsNothing);
  });
}
