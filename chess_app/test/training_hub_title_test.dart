// The Training hub has one name — the tab's.
//
// Opened inside the home screen the tab header names it; opened as a screen of
// its own it draws its own AppBar, and that one said „Trening" until
// 11.9.2026, three days after the app went English. The language gate reads
// Serbian letters, and „Trening" has none, which is how „Deo 2" got through as
// well. Asking for the tab's name here catches the next one of those, whatever
// language it slips back in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/training/screens/training_hub_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/home_screen.dart';

void main() {
  testWidgets('opened on its own, the hub is called what its tab is called',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TrainingHubScreen(
        session: UserSession(
          token: 't',
          id: 1,
          email: 'a@b.c',
          name: 'Player',
          role: 'korisnik',
        ),
      ),
    ));
    await tester.pump();

    expect(
      find.descendant(
          of: find.byType(AppBar), matching: find.text(kTabNames.first)),
      findsOneWidget,
    );
  });
}
