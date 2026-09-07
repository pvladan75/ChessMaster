// The fork, on the screen the child is already looking at.
//
// A step's line may branch, and until now the only way to meet the other
// branch was to press „Sledeći potez" on the strip, which opens a sheet. So a
// sideline the trainer wrote was invisible: nothing said there was a choice,
// and the narrated walk — which stops at a fork on purpose, rather than taking
// the first child in silence — simply ended with no explanation.
//
// It costs most in the shape „Traži potez na tabli" now writes: the
// continuation part *opens* on the fork, because the answer and its
// alternatives are the first thing in it. Reported live on 7.9.2026, in the
// owner's words „ne prikazuje se druga grana, samo jedna".
//
// The rule the batch-52 chooser already had holds here too, and is the second
// test below: a step with nothing to choose must never be asked to choose.

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // After 1. e4 e5 2. Nf3 — the position the continuation of a split part
  // opens on, with Black to move and two answers written for it.
  const forkFen =
      'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2';

  const forkPgn = '[SetUp "1"]\n'
      '[FEN "$forkFen"]\n\n'
      '2... Nc6 { Italijanka. } (2... d6 { Filidor. } 3. d4) '
      '3. Bb5 { Španska. } *';

  const straightPgn = '[SetUp "1"]\n'
      '[FEN "$forkFen"]\n\n'
      '2... Nc6 { Italijanka. } 3. Bb5 { Španska. } *';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  Future<void> open(WidgetTester tester, String pgn) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(
        session: session,
        detail: AssignmentDetail(
          assignment: const Assignment(
            id: 5,
            title: 'Otvaranje',
            kind: AssignmentKind.lesson,
            totalItems: 1,
          ),
          items: const [AssignmentItem(puzzleId: null, position: 0)],
          steps: [
            LessonStep(title: 'Nastavak', fen: forkFen, pgn: pgn),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('both moves of a fork are on the screen, not behind a button',
      (tester) async {
    await open(tester, forkPgn);

    expect(find.text('Odavde ide više linija — kojom?'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Nc6'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'd6'), findsOneWidget,
        reason: 'the sideline is the whole reason this row exists');
  });

  testWidgets('a line with nothing to choose is never asked to choose',
      (tester) async {
    await open(tester, straightPgn);

    expect(find.text('Odavde ide više linija — kojom?'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('pressing the sideline walks the board down it', (tester) async {
    await open(tester, forkPgn);

    await tester.tap(find.widgetWithText(ActionChip, 'd6'));
    await tester.pumpAndSettle();

    // The note on the branch that was taken, which is the trainer's own proof
    // of which line the board is on.
    expect(find.text('Filidor.'), findsOneWidget);
    expect(find.text('Italijanka.'), findsNothing);

    // And there is nothing left to choose one move down it.
    expect(find.text('Odavde ide više linija — kojom?'), findsNothing);
  });

  testWidgets('and the main line is still one press away', (tester) async {
    await open(tester, forkPgn);

    await tester.tap(find.widgetWithText(ActionChip, 'Nc6'));
    await tester.pumpAndSettle();

    expect(find.text('Italijanka.'), findsOneWidget);
    expect(find.text('Filidor.'), findsNothing);
  });
}
