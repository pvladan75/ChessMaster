import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/home/dashboard_tab.dart';

/// The three-form plural, where the reader actually meets it.
///
/// `serbian_plural_test.dart` proves the helper. This proves the screens call
/// it — which is a different claim, and the one that was false: three sentences
/// carried a ternary whose two arms were the same word, so somebody had meant
/// to inflect and the code did nothing. Two of them sat inside a string
/// interpolation, where the copy gate cannot see them at all.
void main() {
  Future<void> pumpDashboard(WidgetTester tester, int due) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeDashboardTab(
          userName: 'Trener',
          codeController: TextEditingController(),
          recordings: const [],
          isLoadingRecordings: false,
          onCreateSessionTap: () {},
          onOpenStudio: () {},
          onOpenAssignments: () {},
          onOpenReviews: () {},
          dueReviewCount: due,
          onJoinRoom: (_) {},
          onRefreshRecordings: () {},
          onOpenReplay: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('one position waits, and the verb stays singular',
      (tester) async {
    await pumpDashboard(tester, 1);
    expect(find.text('1 pozicija čeka na ponavljanje.'), findsOneWidget);
  });

  testWidgets('two to four take the paucal, and the verb follows it',
      (tester) async {
    // „2 pozicije čekaju", not „2 pozicija čeka". This is the form the app was
    // never writing.
    await pumpDashboard(tester, 2);
    expect(find.text('2 pozicije čekaju na ponavljanje.'), findsOneWidget);
    await pumpDashboard(tester, 4);
    expect(find.text('4 pozicije čekaju na ponavljanje.'), findsOneWidget);
  });

  testWidgets('five and up go back to the singular verb', (tester) async {
    await pumpDashboard(tester, 5);
    expect(find.text('5 pozicija čeka na ponavljanje.'), findsOneWidget);
  });

  testWidgets('eleven to fourteen are the exception, on screen too',
      (tester) async {
    await pumpDashboard(tester, 12);
    expect(find.text('12 pozicija čeka na ponavljanje.'), findsOneWidget);
  });

  test('no ternary in lib/ has two identical arms', () {
    // The bug class, not the three instances. A `n == 1 ? "pozicija" :
    // "pozicija"` is somebody reaching for a plural and writing a no-op, and it
    // reads as handled at every glance afterwards — which is why all three
    // survived for months in a codebase that greps its own sources for worse.
    final offenders = <String>[];
    final ternary = RegExp(
      '''\\?\\s*(['"])((?:[^'"\\\\]|\\\\.)*)\\1\\s*:\\s*(['"])\\2\\3''',
    );
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (ternary.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'a ternary whose two arms are the same string does nothing:\n'
            '${offenders.join('\n')}');
  });
}
