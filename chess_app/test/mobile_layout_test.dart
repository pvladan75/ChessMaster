// mobile_layout_test.dart
// Renders the new screens at phone sizes.
//
// The student side of the app — homework, tactics — is used on a phone almost
// exclusively, but it was written and checked on a desktop window. A RenderFlex
// overflow throws during layout, so pumping each screen at 360×640 turns "looks
// fine on my machine" into something CI can hold onto.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/widgets/create_assignment_dialog.dart';
import 'package:chess_app/features/assignments/widgets/parent_report_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';

/// The smallest screen worth supporting; anything narrower is vanishingly rare.
const _phone = Size(360, 640);
const _smallPhone = Size(320, 568);

Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: child,
    );

Future<void> _setScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('CreateAssignmentDialog on a phone', () {
    testWidgets('lays out at 360×640 without overflowing', (tester) async {
      await _setScreen(tester, _phone);

      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => CreateAssignmentDialog(
                    api: AssignmentApiService(authToken: ''),
                    studentId: 1,
                    studentName: 'Marko Petrović',
                    suggestedThemes: const ['pin', 'fork', 'hangingPiece'],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // A fixed 420px content box was wider than the room an AlertDialog leaves
      // on a 360px screen, which overflowed rather than shrinking.
      expect(tester.takeException(), isNull);
      expect(find.text('Zadaj'), findsOneWidget);
    });

    testWidgets('still lays out on a 320px screen', (tester) async {
      await _setScreen(tester, _smallPhone);

      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => CreateAssignmentDialog(
                    api: AssignmentApiService(authToken: ''),
                    studentId: 1,
                    studentName: 'Marko',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the title is prefilled from the suggested weak themes',
        (tester) async {
      await _setScreen(tester, _phone);

      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => CreateAssignmentDialog(
                    api: AssignmentApiService(authToken: ''),
                    studentId: 1,
                    studentName: 'Marko',
                    suggestedThemes: const ['pin'],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The obvious assignment should already be filled in, in Serbian.
      expect(find.text('Vežba: vezivanje'), findsOneWidget);
    });
  });

  group('ParentReportDialog on a phone', () {
    testWidgets('lays out at 320×568 without overflowing', (tester) async {
      await _setScreen(tester, _smallPhone);

      await tester.pumpWidget(_host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ParentReportDialog(
                    api: AssignmentApiService(authToken: ''),
                    studentId: 1,
                    studentName: 'Marko Petrović',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The parent needs to know no account is required, or they will not open it.
      expect(find.textContaining('nije mu potreban nalog'), findsOneWidget);
      expect(find.text('Napravi'), findsOneWidget);
    });
  });

  group('theme labels', () {
    testWidgets('the longest Serbian motif name does not overflow its row',
        (tester) async {
      await _setScreen(tester, _smallPhone);

      // Approximates the progress screen's row at its tightest: the longest
      // label the app can produce, on the narrowest screen it supports.
      final longest =
          themeLabels.values.reduce((a, b) => a.length >= b.length ? a : b);

      await tester.pumpWidget(_host(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(longest,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                const Expanded(
                    flex: 4, child: LinearProgressIndicator(value: 0.5)),
                const SizedBox(width: 10),
                const SizedBox(
                    width: 74,
                    child: Text('100% (99)', textAlign: TextAlign.right)),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
