// The Analysis board's panels, switched from the board.
//
// Until 17.9.2026 these checkboxes were in Settings, although only the
// Analysis Studio reads them: a reader had to leave the screen to change what
// that screen showed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';

import 'support/landscape.dart';

void main() {
  test('the panels are read by the Studio and chosen in its sheet', () {
    const readers = [
      'features/analysis_studio/screens/analysis_studio_screen.dart',
      'features/analysis_studio/widgets/analysis_panels_sheet.dart',
    ];
    const writer =
        'features/analysis_studio/widgets/analysis_panels_sheet.dart';
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final rel = f.path.replaceAll(r'\', '/').split('lib/').last;
      if (rel == 'services/app_settings_service.dart') continue;
      final code = f
          .readAsLinesSync()
          .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
          .join('\n');
      if (code.contains('isPanelVisible(') && !readers.contains(rel)) {
        offenders.add('$rel reads a panel switch');
      }
      if (code.contains('setPanelVisible(') && rel != writer) {
        offenders.add('$rel sets a panel switch');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('a panel unticked in the sheet leaves the board under it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    addTearDown(
        () => AppSettingsService.instance.setPanelVisible('move_tree', true));

    await pumpAt(
        tester,
        const Size(360, 800),
        AnalysisStudioScreen(
          userSession: UserSession(
              id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
          initialFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        ));
    final tree = find.byType(AnalysisMoveTreeWidget, skipOffstage: false);
    expect(tree, findsOneWidget);

    // On a phone the entry is behind the overflow menu.
    await tester.tap(find.byTooltip('More tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Panels'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Move tree'));
    await tester.pumpAndSettle();

    expect(AppSettingsService.instance.isPanelVisible('move_tree'), isFalse);
    expect(find.text('Panels'), findsOneWidget, reason: 'the sheet stays open');
    expect(tree, findsNothing);
  });
}
