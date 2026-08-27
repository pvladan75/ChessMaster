import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/screens/login_screen.dart';
import 'package:chess_app/services/session_service.dart';

/// The first screen anybody sees, and the one every reported confusion on
/// 27.8.2026 came from: three buttons in a column, one of which quietly did
/// something else than its neighbours.
///
/// What is pinned here is the shape — two ways in, separated, each saying which
/// one it is — rather than the wording, so the text can be improved without
/// breaking the test on a comma.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.init();
  });

  /// [google] stands in for a compile-time constant: whether this build was
  /// given an OAuth client that works on this platform. A test cannot change
  /// one, and both states matter — the Windows build has no Google sign-in
  /// until a desktop client is configured for it.
  Future<void> open(WidgetTester tester, {bool google = true}) async {
    await tester.pumpWidget(MaterialApp(
      home: LoginRegisterScreen(googleAvailableOverride: google),
    ));
    await tester.pump();
  }

  testWidgets('the two ways in are two blocks with a line between them',
      (tester) async {
    await open(tester);

    expect(find.textContaining('Google'), findsWidgets);
    expect(find.text('ili'), findsOneWidget);
    // Both buttons name the way in they use, so neither can be read as the
    // other one's confirmation.
    expect(find.text('Prijavi se email adresom'), findsOneWidget);
    expect(find.text('Nemate nalog? Registrujte se email adresom'),
        findsOneWidget);
  });

  testWidgets('Google registers too, and says so in both modes',
      (tester) async {
    await open(tester);

    // The button that also creates the account carries both words. It used to
    // say only "Prijavi se preko Google-a", so somebody without an account went
    // looking for a Google registration that does not exist.
    expect(find.text('Prijava / Registracija preko Google-a'), findsOneWidget);

    // Scrolled to first: the card is taller than the test window, and a button
    // below the fold cannot be tapped.
    final toRegister = find.text('Nemate nalog? Registrujte se email adresom');
    await tester.ensureVisible(toRegister);
    await tester.pumpAndSettle();
    await tester.tap(toRegister);
    await tester.pumpAndSettle();

    // And it is still there in registration mode, where it was missing
    // entirely — the one screen where somebody is definitely looking for a way
    // to make an account.
    expect(find.text('Prijava / Registracija preko Google-a'), findsOneWidget);
    expect(find.text('Registruj se email adresom'), findsOneWidget);
    expect(find.text('Ime i Prezime'), findsOneWidget);
  });

  testWidgets('"Zapamti me" says what it actually does', (tester) async {
    await open(tester);

    // It was read as "remember my password" and has never meant that: it keeps
    // the session so the form is not asked for at all.
    expect(find.text('Zapamti me'), findsOneWidget);
    expect(find.text('Ostajete prijavljeni na ovom uređaju.'), findsOneWidget);
  });

  testWidgets('the remembered address is filled in, the password never is',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'last_email': 'trener@example.com',
      'user_token': 'x',
    });
    await SessionService.instance.init();

    await open(tester);

    expect(find.text('trener@example.com'), findsOneWidget);

    // The password field is empty, and there is no stored password to fill it
    // from: that is the platform password manager's job, reached through the
    // autofill hints. `SharedPreferences` is a plain file on Windows, and most
    // of these accounts belong to children.
    final password = tester.widget<TextField>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Lozinka'),
          matching: find.byType(TextFormField),
        ),
        matching: find.byType(TextField),
      ),
    );
    expect(password.controller?.text ?? '', isEmpty);
    expect(password.obscureText, isTrue);
  });

  testWidgets('where Google cannot work, it is not offered', (tester) async {
    // `google_sign_in` does not support Windows at all, so an unconfigured
    // desktop build used to show a button that answered "nije podržan na ovoj
    // platformi" after the tap — a dead end dressed as an option. The email
    // form is whole either way.
    await open(tester, google: false);

    expect(find.textContaining('Google'), findsNothing);
    expect(find.text('ili'), findsNothing);
    expect(find.text('Prijavi se email adresom'), findsOneWidget);
    expect(find.text('Email Adresa'), findsOneWidget);
  });

  testWidgets('the sign-in card fits a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await open(tester);

    // A release build paints no overflow stripes, and this screen is the one
    // nobody can get past if a button runs off the edge.
    expect(tester.takeException(), isNull);
  });
}
