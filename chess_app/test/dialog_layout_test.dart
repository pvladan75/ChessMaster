import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/create_course_dialog.dart';
import 'package:chess_app/widgets/save_position_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AlertDialog wraps its children in an IntrinsicWidth. If the content is not
/// width-tight, that intrinsic pass walks into any lazy list below and
/// RenderShrinkWrappingViewport asserts ("does not support returning intrinsic
/// dimensions"), leaving the dialog unlaid out. These tests pump the dialogs
/// that embed such lists.
void main() {
  Future<void> pumpDialog(WidgetTester tester, Widget dialog) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Builder(builder: (context) => dialog))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  testWidgets('CreateCourseDialog lays out with saved positions', (tester) async {
    await pumpDialog(
      tester,
      CreateCourseDialog(
        userSession: session,
        lessons: List.generate(
          6,
          (i) => {'id': i, 'title': 'Pozicija $i', 'fen': 'fen$i'},
        ),
        onCourseCreated: () {},
      ),
    );
  });

  testWidgets('CreateCourseDialog lays out while editing an existing course',
      (tester) async {
    await pumpDialog(
      tester,
      CreateCourseDialog(
        userSession: session,
        lessons: List.generate(
          6,
          (i) => {'id': i, 'title': 'Pozicija $i', 'fen': 'fen$i'},
        ),
        onCourseCreated: () {},
        existingLesson: {
          'id': 99,
          'title': 'Kurs',
          'description': 'opis',
          'position_list': List.generate(
            4,
            (i) => {'id': i, 'title': 'Korak $i', 'fen': 'fen$i'},
          ),
        },
      ),
    );
  });

  testWidgets('SavePositionDialog lays out with the label suggestion list',
      (tester) async {
    await pumpDialog(
      tester,
      SavePositionDialog(
        availableUserLabels: List.generate(8, (i) => 'labela$i'),
        initialPersistedLabels: const [],
        initialShouldPersist: false,
        onSave: (_, __, ___, ____) {},
      ),
    );

    // The suggestion ListView only builds once the tag field has text.
    await tester.enterText(find.byType(TextField).last, 'labela');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Only the first suggestions are built — the list is 120px tall and lazy.
    expect(find.text('labela0'), findsOneWidget);
  });
}
