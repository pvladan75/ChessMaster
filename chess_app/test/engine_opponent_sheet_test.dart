// The engine as an opponent, chosen on the screen where it plays.
//
// Owner, 17.9.2026: strength and think time were in Settings, read only by
// the exercise screen. They are now behind a button on that screen. When a
// trainer can set a position to be played against the engine, the strength
// will travel with the assignment — see the sheet's doc comment.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/engine_opponent_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'support/landscape.dart';

void main() {
  // Real glyphs: the screen below is measured, not just searched.
  setUpAll(loadRoboto);

  test('the opponent is read by the exercise screen and set only in its sheet',
      () {
    const reader = 'screens/ai_studio_screen.dart';
    const sheet = 'widgets/engine_opponent_sheet.dart';
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
      final reads = code.contains('enginePlayDepth') ||
          code.contains('defaultEngineMoveTimeSeconds');
      if (reads && rel != reader && rel != sheet) {
        offenders.add('$rel reads the opponent settings');
      }
      final sets = code.contains('setEnginePlayLevel(') ||
          code.contains('setEngineMoveTimeSeconds(');
      if (sets && rel != sheet) {
        offenders.add('$rel sets the opponent settings');
      }
      // And the other half: the screen that plays against the engine has to
      // offer the sheet wherever it offers its board menu — one header for
      // portrait and one for landscape — or the setting is read with no way
      // to change it on the screen it was moved to. A mutation that dropped
      // the portrait button passed the first version of this test.
      if (rel == reader) {
        final menus = 'BoardViewMenu('.allMatches(code).length;
        final buttons = 'EngineOpponentButton('.allMatches(code).length;
        if (buttons < menus) {
          offenders.add('$rel offers the board menu $menus times and the '
              'opponent button $buttons');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('the sheet sets the level and the think time', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    addTearDown(() async {
      await AppSettingsService.instance.setEnginePlayLevel('srednje');
      await AppSettingsService.instance.setEngineMoveTimeSeconds(2);
    });
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EngineOpponentSheet())));
    expect(find.text('2 s'), findsOneWidget);

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();
    expect(AppSettingsService.instance.enginePlayLevel, 'tesko');

    final slider =
        tester.getRect(find.byKey(const Key('engine-opponent-time')));
    await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
    await tester.pumpAndSettle();
    expect(AppSettingsService.instance.defaultEngineMoveTimeSeconds, 60);
    expect(find.text('60 s'), findsOneWidget);
  });

  // The half the source-reading guard above cannot see. Until 17.9.2026 the
  // exercise screen built its portrait header into a card and never placed it,
  // so on a phone held upright neither this button nor the board menu existed —
  // and counting them in the source said everything was fine (CLAUDE.md rule
  // 10: every layer can be right and the control still unreachable).
  testWidgets('both controls are reachable in portrait, on the real screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    await pumpAt(
      tester,
      const Size(360, 640),
      ProviderScope(
        child: AiStudioScreen(
          userSession: UserSession(
              id: 1, token: 't', email: 'e', name: 'N', role: 'korisnik'),
          initialCategory: 'basic_mate',
          basicMateLevel: 'Srednje',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Engine opponent'), findsOneWidget);
    expect(find.byType(BoardViewMenu), findsOneWidget);
    // The goal banner was dropped the same way and is back above the board:
    // upright, the screen said nowhere what was being asked.
    expect(find.textContaining('Practice:'), findsOneWidget);

    // And it opens from there, which is the point of it being on screen.
    await tester.tap(find.byTooltip('Engine opponent'));
    await tester.pumpAndSettle();
    expect(find.text('Strength'), findsOneWidget);
  });

  testWidgets('the button opens the sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: EngineOpponentButton()))));
    await tester.tap(find.byTooltip('Engine opponent'));
    await tester.pumpAndSettle();
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Maximum think time'), findsOneWidget);
  });
}
