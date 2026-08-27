import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';
import 'package:chess_app/features/trainer_panel/widgets/trainer_panel_view.dart';
import 'package:chess_app/theme/app_colors.dart';

/// The panel a trainer opens the app to.
///
/// Two things are held here. The first is that it disappears completely for
/// anybody it has nothing to say to — it lives inside the "Ljudi" tab, above
/// somebody's list of people, and a stack of empty headings over that list
/// reads as a screen that failed to load. The second is width: every row here
/// puts a name next to a button, which is exactly the shape that overflows on a
/// 360 px phone and nowhere else, and a release build clips it in silence.
void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppColorTokens.dark],
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  TrainerPanelView view(
    TrainerPanel panel, {
    void Function(String)? onEnterLesson,
    void Function(PanelAssignment)? onOpenAssignment,
    void Function(int, String)? onOpenStudent,
  }) =>
      TrainerPanelView(
        panel: panel,
        onEnterLesson: onEnterLesson ?? (_) {},
        onOpenAssignment: onOpenAssignment ?? (_) {},
        onOpenStudent: onOpenStudent ?? (_, __) {},
      );

  final full = TrainerPanel(
    today: [
      PanelLesson(
        id: 1,
        roomCode: 'ABC123',
        title: 'Skakačeve viljuške',
        guests: const ['Ana Marić'],
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      ),
    ],
    dueSoon: [
      PanelAssignment(
        id: 2,
        title: 'Vezani napad',
        studentId: 11,
        studentName: 'Marko Ilić',
        totalItems: 12,
        attemptedItems: 6,
        dueAt: DateTime.now().add(const Duration(hours: 5)),
      ),
    ],
    awaitingReview: [
      PanelAssignment(
        id: 3,
        title: 'Uzvraćeni gambit',
        studentId: 12,
        studentName: 'Ana Marić',
        totalItems: 12,
        attemptedItems: 12,
        solvedItems: 10,
        completedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ],
    idle: [
      PanelIdleStudent(
        id: 13,
        name: 'Petar Nikolić',
        lastActiveAt: DateTime.now().subtract(const Duration(days: 9)),
      ),
    ],
    waiting: 1,
  );

  testWidgets('a trainer with nothing on is shown no panel at all',
      (tester) async {
    await tester.pumpWidget(wrap(view(TrainerPanel.empty)));
    await tester.pumpAndSettle();

    expect(find.text('Panel trenera'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('the four sections say what the job is', (tester) async {
    await tester.pumpWidget(wrap(view(full)));
    await tester.pumpAndSettle();

    expect(find.text('DANAS'), findsOneWidget);
    expect(find.text('ZA PREGLED'), findsOneWidget);
    expect(find.text('DOMAĆI ISTIČE'), findsOneWidget);
    expect(find.text('NIJE VEŽBAO'), findsOneWidget);

    // Each row names the person it is about, because the trainer's next move
    // depends on which student it is.
    expect(find.textContaining('Marko Ilić'), findsOneWidget);
    expect(find.textContaining('Petar Nikolić'), findsOneWidget);
    expect(find.textContaining('pre 9 dana'), findsOneWidget);
  });

  testWidgets('a section with nothing in it is not drawn', (tester) async {
    await tester.pumpWidget(wrap(view(TrainerPanel(
      idle: full.idle,
    ))));
    await tester.pumpAndSettle();

    expect(find.text('NIJE VEŽBAO'), findsOneWidget);
    expect(find.text('DANAS'), findsNothing);
    expect(find.text('ZA PREGLED'), findsNothing);
  });

  testWidgets('the panel fits a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A long name next to a button is the row that overflows, so the test uses
    // one rather than the tidy names above.
    await tester.pumpWidget(wrap(view(TrainerPanel(
      today: full.today,
      dueSoon: [
        PanelAssignment(
          id: 4,
          title: 'Uzvraćeni gambit i sve što ide uz njega',
          studentId: 14,
          studentName: 'Aleksandra Đorđević-Petrović',
          totalItems: 12,
          attemptedItems: 6,
          dueAt: DateTime.now().add(const Duration(hours: 5)),
        ),
      ],
      awaitingReview: full.awaitingReview,
      idle: full.idle,
    ))));
    await tester.pumpAndSettle();

    // In a test build an overflow throws; in release it is clipped without a
    // word, which is why this assertion is here rather than on a phone.
    expect(tester.takeException(), isNull);
  });

  testWidgets('each row acts on the thing it names', (tester) async {
    String? entered;
    int? opened;
    int? student;

    await tester.pumpWidget(wrap(view(
      full,
      onEnterLesson: (code) => entered = code,
      onOpenAssignment: (a) => opened = a.id,
      onOpenStudent: (id, _) => student = id,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Uđi'));
    expect(entered, 'ABC123');

    await tester.tap(find.text('Pregledaj'));
    expect(opened, 3, reason: 'the finished assignment, not the one still due');

    await tester.tap(find.text('Otvori').last);
    expect(student, 13);
  });

  test('an empty answer parses into an empty panel', () {
    final panel = TrainerPanel.fromJson(const {});

    expect(panel.isEmpty, isTrue);
    expect(panel.waiting, 0);
  });

  test('the badge number comes from the server, not from the lists', () {
    // The lists are capped and the count is not, so counting the rows on the
    // screen would quietly under-report a busy trainer's queue.
    final panel = TrainerPanel.fromJson(const {
      'awaitingReview': [
        {'id': 1, 'title': 'a', 'student_id': 2, 'student_name': 'A'},
      ],
      'counts': {'waiting': 7},
    });

    expect(panel.awaitingReview.length, 1);
    expect(panel.waiting, 7);
  });
}
