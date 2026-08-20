import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/custom_assignment_overview_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The grid is the answer to "a child stuck on the third position cannot reach
/// the fourth". What it has to get right is the three states: done and right,
/// done and wrong, and not touched — the last two being the pair a student most
/// needs to tell apart.
void main() {
  const fen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  AssignmentDetail detail({required int attempted}) {
    final ids = ['cust_1', 'cust_2', 'cust_3'];
    return AssignmentDetail(
      assignment: const Assignment(
        id: 4,
        title: 'Mat u 333',
        instructions: 'Uradi do petka',
        totalItems: 3,
      ),
      items: [
        AssignmentItem(
          puzzleId: ids[0],
          position: 0,
          solved: true,
          attemptedAt: DateTime(2026, 8, 20),
          playedSan: 'Ra8#',
        ),
        AssignmentItem(
          puzzleId: ids[1],
          position: 1,
          solved: false,
          attemptedAt: attempted >= 2 ? DateTime(2026, 8, 20) : null,
        ),
        AssignmentItem(puzzleId: ids[2], position: 2),
      ],
      customPositions: [
        for (final id in ids)
          CustomPosition(
            puzzleId: id,
            fen: fen,
            sideToMove: 'w',
            instruction: 'Beli matira u jednom potezu',
          ),
      ],
    );
  }

  Future<void> pump(WidgetTester tester, AssignmentDetail d) async {
    await tester.pumpWidget(MaterialApp(
      home: CustomAssignmentOverviewScreen(session: session, detail: d),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('every position is shown, whatever state it is in',
      (tester) async {
    await pump(tester, detail(attempted: 2));

    // Not only the ones left to do: the point of the grid is that the whole
    // assignment is visible at once.
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('2.'), findsOneWidget);
    expect(find.text('3.'), findsOneWidget);
  });

  testWidgets('wrong and untouched are marked differently', (tester) async {
    await pump(tester, detail(attempted: 2));

    expect(find.text('tačno'), findsOneWidget);
    expect(find.text('netačno'), findsOneWidget);
    expect(find.text('nije urađeno'), findsOneWidget);
  });

  testWidgets('the move played is shown where it was recorded', (tester) async {
    await pump(tester, detail(attempted: 2));

    expect(find.text('tvoj potez: Ra8#'), findsOneWidget);
    // The second was answered before the move was ever stored, and that is not
    // the same as having played nothing.
    expect(find.text('potez nije zabeležen'), findsOneWidget);
  });

  testWidgets('a started assignment offers to continue, not to begin again',
      (tester) async {
    await pump(tester, detail(attempted: 2));

    expect(find.text('Nastavi'), findsOneWidget);
    expect(find.text('Počni'), findsNothing);
    expect(find.textContaining('1 / 3'), findsNothing);
    expect(find.textContaining('2 / 3 urađeno'), findsOneWidget);
  });

  testWidgets('the free order is said out loud, not left to be discovered',
      (tester) async {
    await pump(tester, detail(attempted: 1));

    expect(find.textContaining('kojim redom hoćeš'), findsOneWidget);
  });
}
