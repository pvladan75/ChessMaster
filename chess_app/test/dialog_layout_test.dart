import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/position_picker_dialog.dart';
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
            hasSolution: true,
            isExercise: true,
          ),
        ),
      ),
    );

    expect(find.text('Mat u 333 #0'), findsOneWidget);
  });

  testWidgets('an entry that cannot be homework says so instead of vanishing',
      (tester) async {
    // The fixture was a bare position until `docs/PLAN-EXERCISE.md` phase 4,
    // 18.9.2026: for `PickerPurpose.homework` a position is no longer greyed
    // out, it is not offered at all — only an exercise can be homework. This
    // rule (blocked-but-visible) still applies to an exercise the server
    // refuses, so the fixture moved to a scan. Narrowed again 19.9.2026
    // (phase 10): a scan with **no solution** is not an exercise and is not
    // listed — what stays visible is an exercise the trainer can fix, one
    // marked for review.
    await pumpDialog(
      tester,
      PositionPickerDialog(
        service: PositionLibraryService(authToken: 't'),
        purpose: PickerPurpose.homework,
        loader: ({kind, search}) async => [
          const LibraryEntry(
            kind: LibraryKind.scan,
            id: 'cust_3',
            title: 'Završnica',
            fen: '8/8/8/8/8/8/8/K6k w - - 0 1',
            hasSolution: true,
            isExercise: true,
            needsReview: true,
            assignable: false,
            blockedReason: 'is marked for review',
          ),
        ],
      ),
    );

    // Hiding it would read as a bug — the trainer knows they saved it.
    expect(find.text('Završnica'), findsOneWidget);
    expect(find.text('is marked for review'), findsOneWidget);
  });

  testWidgets('a bare position is not offered for homework, only an exercise',
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
            assignable: true,
          ),
          const LibraryEntry(
            kind: LibraryKind.scan,
            id: 'cust_9',
            title: 'Mate in 1',
            fen: '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
            assignable: true,
            hasSolution: true,
            isExercise: true,
          ),
        ],
      ),
    );

    expect(find.text('Završnica'), findsNothing);
    expect(find.text('Mate in 1'), findsOneWidget);
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

    expect(find.textContaining('Cannot reach server'), findsOneWidget);
    expect(find.textContaining('No saved positions'), findsNothing);
  });
}
