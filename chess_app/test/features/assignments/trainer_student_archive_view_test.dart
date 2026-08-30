import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/mistake_recurrence.dart';
import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/assignments/widgets/trainer_student_archive_view.dart';

void main() {
  Widget pumpApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  testWidgets('renders trend without before-and-after messaging',
      (tester) async {
    // A test that fails if the trend is labelled as a before-and-after.
    // The brief says: "It must never be drawn, labelled, or described as "before and after"
    // Every section populated on purpose. The first draft of this test left
    // `mistakes` and `recurrence` null, so most of the view never rendered and
    // a "pre i posle" written into any other section escaped the guard
    // entirely — proved by mutation, which is the only reason it is known.
    // The brief's rule is about the whole screen, so the fixture has to draw
    // the whole screen.
    final archive = TrainerStudentArchive(
      games: 100,
      subject: 'testuser',
      mistakes: const MistakeSummaryCounts(
        total: 12,
        due: 3,
        mature: 4,
        byKind: {'engine': 8, 'tablebase': 4},
      ),
      recurrence: const MistakeRecurrence(
        motifs: [
          RecurrenceBucket(key: 'fork', count: 5, worstSwing: 300, example: '1')
        ],
        endings: [
          RecurrenceBucket(key: 'KPRkpr', count: 3, worstSwing: 0, example: '2')
        ],
      ),
      trend: [
        const TrendMonth(month: '2025-01', games: 10, score: 0.5),
        const TrendMonth(month: '2025-02', games: 20, score: 0.6),
      ],
    );

    await tester.pumpWidget(pumpApp(TrainerStudentArchiveView(
      studentId: 1,
      archive: archive,
      onRefresh: () {},
    )));
    await tester.pumpAndSettle();

    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((e) => e.data ?? '')
        .join(' ')
        .toLowerCase();

    expect(text.contains('pre i posle'), isFalse,
        reason: 'Trend must not be labelled before-and-after');
    expect(text.contains('before'), isFalse);
    expect(text.contains('after'), isFalse);

    expect(find.text('Aktivnost u poslednjih 12 meseci'), findsOneWidget);
    expect(find.textContaining('2025-01'), findsOneWidget);
  });

  testWidgets('renders empty state correctly', (tester) async {
    final archive = const TrainerStudentArchive(
      games: 0,
      subject: null,
    );

    await tester.pumpWidget(pumpApp(TrainerStudentArchiveView(
      studentId: 1,
      archive: archive,
      onRefresh: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Učenik još nije uvezao partije'), findsOneWidget);
  });

  testWidgets('renders error message', (tester) async {
    await tester.pumpWidget(pumpApp(TrainerStudentArchiveView(
      studentId: 1,
      archive: null,
      error: 'Greška pri učitavanju',
      onRefresh: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Greška pri učitavanju'), findsOneWidget);
  });
}
