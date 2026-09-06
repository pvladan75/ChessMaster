import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';

void main() {
  testWidgets('removing a choice updates the state correctly', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = UserSession(
      token: 'tok',
      id: 7,
      email: 'a@b.c',
      name: 'Trener',
      role: 'trener',
    );

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: const TutorialEntry.blank(''),
      ),
    ));
    await tester.pumpAndSettle();

    // Select ask_choice
    await tester.tap(find.byKey(const Key('example-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Traži odgovor iz liste').last);
    await tester.pumpAndSettle();

    // Add two choices
    await tester.tap(find.text('Dodaj odgovor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dodaj odgovor'));
    await tester.pumpAndSettle();

    // They should be rendered
    expect(find.byKey(const Key('example-choice-0')), findsOneWidget);
    expect(find.byKey(const Key('example-choice-1')), findsOneWidget);

    // Delete the first one
    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pumpAndSettle();

    // Now there is only one choice left
    expect(find.byKey(const Key('example-choice-0')), findsOneWidget);
    expect(find.byKey(const Key('example-choice-1')), findsNothing);
  });
}
