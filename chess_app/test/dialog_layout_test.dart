import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/position_picker_dialog.dart';
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

  testWidgets('CreateCourseDialog lays out with saved positions',
      (tester) async {
    await pumpDialog(
      tester,
      CreateCourseDialog(
        userSession: session,
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

  testWidgets('PositionPickerDialog lays out with a full shelf',
      (tester) async {
    await pumpDialog(
      tester,
      PositionPickerDialog(
        service: PositionLibraryService(authToken: 't'),
        loader: ({kind, search}) async => List.generate(
          20,
          (i) => LibraryEntry(
            kind: LibraryKind.scan,
            id: 'cust_$i',
            title: 'Mat u 333 #$i',
            fen: '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
            assignable: true,
          ),
        ),
      ),
    );

    expect(find.text('Mat u 333 #0'), findsOneWidget);
  });

  testWidgets('an entry that cannot be homework says so instead of vanishing',
      (tester) async {
    await pumpDialog(
      tester,
      PositionPickerDialog(
        service: PositionLibraryService(authToken: 't'),
        purpose: PickerPurpose.homework,
        loader: ({kind, search}) async => [
          const LibraryEntry(
            kind: LibraryKind.position,
            id: '3',
            title: 'Završnica',
            fen: '8/8/8/8/8/8/8/K6k w - - 0 1',
            assignable: false,
            blockedReason: 'nema rešenje, pa odgovor ne može da se oceni',
          ),
        ],
      ),
    );

    // Hiding it would read as a bug — the trainer knows they saved it.
    expect(find.text('Završnica'), findsOneWidget);
    expect(find.textContaining('nema rešenje'), findsOneWidget);
  });

  testWidgets('an unreachable server is not reported as an empty shelf',
      (tester) async {
    await pumpDialog(
      tester,
      PositionPickerDialog(
        service: PositionLibraryService(authToken: 't'),
        loader: ({kind, search}) async => null,
      ),
    );

    expect(find.textContaining('Nije moguće doći do servera'), findsOneWidget);
    expect(find.textContaining('Nema sačuvanih pozicija'), findsNothing);
  });
}
