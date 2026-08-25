import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/age_gate_screen.dart';
import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/services/session_service.dart';

/// The age gate, and the third state it must not lose.
///
/// The app has never known anybody's age, and the rules written for minors —
/// a minor is somebody's student and never their trainer, and a child starts
/// out listening rather than talking — refuse nothing until this gate fills
/// `users.birth_year`. That is the whole reason it exists, and it is why it
/// wraps the app rather than sitting at the end of the register form: most
/// accounts here never saw that form.
///
/// What is pinned hardest is the distinction between *"nobody has answered"*
/// and *"the server has not been asked yet"*. Collapsing those two would either
/// gate everybody whose backend is down, or let through exactly the accounts
/// this is for — this project's recurring failure, aimed at the one rule that
/// decides whether a child is treated as a child.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
  });

  Future<void> signIn() => SessionService.instance.signIn(
        UserSession(
          token: 'token',
          id: 7,
          email: 'ucenik@example.com',
          name: 'Učenik',
          role: 'korisnik',
        ),
        rememberMe: false,
      );

  /// A standing service wired to canned answers, with the requests it made.
  ({AccountStandingService service, List<String> posted}) fake({
    required Map<String, dynamic>? standing,
    Map<String, dynamic>? afterPost,
    int postStatus = 200,
    String? postError,
  }) {
    final posted = <String>[];
    var current = standing;
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posted.add(request.body);
        if (postStatus >= 300) {
          return http.Response(
            jsonEncode({'error': postError ?? 'Ne može.'}),
            postStatus,
          );
        }
        current = afterPost ?? current;
        return http.Response(jsonEncode({'ageKnown': true}), 200);
      }
      if (current == null) return http.Response('{}', 500);
      return http.Response(jsonEncode(current), 200);
    });
    return (service: AccountStandingService(client: client), posted: posted);
  }

  Map<String, dynamic> standingBody({
    required bool ageKnown,
    int? birthYear,
    int? age,
    bool minor = false,
  }) =>
      {
        'ageKnown': ageKnown,
        'birthYear': birthYear,
        'age': age,
        'minor': minor,
        'ageOfConsent': 16,
        'parentConsent': {
          'required': minor,
          'given': false,
          'parentEmailOnFile': false,
        },
      };

  Widget app(AccountStandingService standing) => MaterialApp(
        home: AgeGate(
          standing: standing,
          child: const Scaffold(body: Text('aplikacija')),
        ),
      );

  testWidgets('a server that never answered is not an answer', (tester) async {
    // The failure mode this replaces: treating silence as "adult" would leave
    // every account exactly where it was before the gate was written, and the
    // screen would look right while doing so.
    await signIn();
    final f = fake(standing: null);

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    expect(find.text('aplikacija'), findsOneWidget);
    expect(find.text('Godina rođenja'), findsNothing);
  });

  testWidgets('an account nobody has ever asked is stopped', (tester) async {
    await signIn();
    final f = fake(standing: standingBody(ageKnown: false));

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    expect(find.text('Godina rođenja'), findsWidgets);
    // The threshold shown is the server's, not a constant repeated here: two
    // numbers that can disagree are two numbers that will.
    expect(find.textContaining('mlađe od 16'), findsOneWidget);
  });

  testWidgets('a guest has no account to state anything about', (tester) async {
    final f = fake(standing: standingBody(ageKnown: false));

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    expect(find.text('aplikacija'), findsOneWidget);
    expect(find.byType(BirthYearScreen), findsNothing);
  });

  testWidgets('the app underneath cannot take the keyboard back',
      (tester) async {
    // Found live on 25.8.2026, and it is the difference between covering a
    // screen and taking it out of the focus tree. The gate is opaque, so no tap
    // reaches what is under it — but focus traversal happily reaches a sibling
    // in a `Stack`, and the app underneath is fully alive with autofocus of its
    // own. It took the focus back a frame after the gate appeared, so every
    // keystroke after the first went to a screen nobody could see and the field
    // looked frozen on what had been typed until then.
    //
    // The sequence here is the real one: the app is running and focused first,
    // and the gate arrives afterwards when the server answers.
    await signIn();
    final f = fake(standing: standingBody(ageKnown: false));
    final underneath = FocusNode(debugLabel: 'ekran ispod');
    addTearDown(underneath.dispose);

    await tester.pumpWidget(MaterialApp(
      home: AgeGate(
        standing: f.service,
        child: Scaffold(
          body: TextField(focusNode: underneath, autofocus: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(BirthYearScreen), findsOneWidget);

    // The invariant, asked in the rudest way available: while the gate is up,
    // nothing underneath holds the keyboard however hard it asks.
    underneath.requestFocus();
    await tester.pump();

    expect(underneath.hasFocus, isFalse);
    expect(underneath.canRequestFocus, isFalse);
  });

  testWidgets('a typed year can be typed over', (tester) async {
    // The symptom the focus bug produced, pinned from the user's side rather
    // than from the mechanism: whatever was typed first stayed, and no amount
    // of typing changed it.
    await signIn();
    final f = fake(
      standing: standingBody(ageKnown: false),
      afterPost: standingBody(ageKnown: true, birthYear: 1997, age: 28),
    );

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '2014');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1997');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(jsonDecode(f.posted.single)['birthYear'], 1997);
  });

  testWidgets('coming back to the field offers the year, not a full one',
      (tester) async {
    // Four digits behind a length limit is a field that ignores typing once it
    // is full — which reads as a field that cannot be changed at all. Selecting
    // what is there means typing replaces it.
    await signIn();
    final f = fake(
      standing:
          standingBody(ageKnown: true, birthYear: 2017, age: 8, minor: true),
    );
    await f.service.refresh();

    await tester.pumpWidget(MaterialApp(
      home: BirthYearScreen(standing: f.service, canCancel: true),
    ));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '2017');
    expect(field.controller!.selection.start, 0);
    expect(field.controller!.selection.end, 4);
  });

  testWidgets('a stated year opens the app', (tester) async {
    await signIn();
    final f = fake(
      standing: standingBody(ageKnown: false),
      afterPost:
          standingBody(ageKnown: true, birthYear: 2014, age: 11, minor: true),
    );

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '2014');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(jsonDecode(f.posted.single)['birthYear'], 2014);
    expect(find.byType(BirthYearScreen), findsNothing);
    expect(find.text('aplikacija'), findsOneWidget);
  });

  testWidgets('a year the server refuses leaves the gate standing',
      (tester) async {
    // The shape of bug this codebase keeps paying for: a step that fails and
    // then reports success one layer up. Here it would look identical to a
    // saved year and leave the account in the state the gate exists to end.
    await signIn();
    final f = fake(
      standing: standingBody(ageKnown: false),
      postStatus: 400,
      postError: 'Unesite godinu rođenja, između 1900. i 2026.',
    );

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1899');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.byType(BirthYearScreen), findsOneWidget);
    expect(find.textContaining('između 1900.'), findsWidgets);
  });

  testWidgets('an impossible year never leaves the phone', (tester) async {
    await signIn();
    final f = fake(standing: standingBody(ageKnown: false));

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    // Four digits, in the future. The field itself refuses letters and a fifth
    // digit, so this is the case that reaches the check.
    await tester.enterText(find.byType(TextField), '2999');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(f.posted, isEmpty);
    expect(find.byType(BirthYearScreen), findsOneWidget);
  });

  testWidgets('the gate is not a trap: signing out is a way through',
      (tester) async {
    // Whoever is holding the phone may be on the wrong account. A screen with
    // no other door would end the session for them, not the question.
    await signIn();
    final f = fake(standing: standingBody(ageKnown: false));

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Odjavi se'));
    await tester.pumpAndSettle();

    expect(SessionService.instance.isSignedIn, isFalse);
    expect(find.byType(BirthYearScreen), findsNothing);
  });

  testWidgets('correcting a year is possible, and only a saved one closes it',
      (tester) async {
    await signIn();
    final f = fake(
      standing:
          standingBody(ageKnown: true, birthYear: 2017, age: 8, minor: true),
      afterPost: standingBody(ageKnown: true, birthYear: 1997, age: 28),
    );
    await f.service.refresh();

    await tester.pumpWidget(MaterialApp(
      home: BirthYearScreen(standing: f.service, canCancel: true),
    ));
    await tester.pumpAndSettle();

    // The year already on file is offered, so a correction is an edit rather
    // than a re-entry.
    expect(find.text('2017'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1997');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(f.service.current?.birthYear, 1997);
    expect(f.service.current?.minor, isFalse);
  });

  testWidgets('signing out forgets whose standing it was', (tester) async {
    await signIn();
    final f = fake(standing: standingBody(ageKnown: true, birthYear: 1997));

    await tester.pumpWidget(app(f.service));
    await tester.pumpAndSettle();
    expect(f.service.current?.birthYear, 1997);

    await SessionService.instance.signOut();
    await tester.pumpAndSettle();

    // The next account's answer is the next account's business — a remembered
    // "already asked" would skip the gate for whoever signs in next.
    expect(f.service.current, isNull);
  });
}
