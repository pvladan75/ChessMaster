// The board menu's two view controls, held to the boards they change.
//
// Until 17.9.2026 the board size slider lived in Settings, where it read as an
// app-wide choice while only three screens sized their board by it; and the
// repertoire walkthrough offered the coordinates switch over a board that drew
// no coordinates. Both are the „menu that does nothing" from either side.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';

import 'support/landscape.dart';

/// Every `BoardViewMenu(...)` argument list in [flat], paren-matched.
List<String> _menus(String flat) {
  final menus = <String>[];
  for (var i = flat.indexOf('BoardViewMenu(');
      i >= 0;
      i = flat.indexOf('BoardViewMenu(', i + 1)) {
    final open = flat.indexOf('(', i);
    var depth = 0, end = -1;
    for (var j = open; j < flat.length; j++) {
      if (flat[j] == '(') depth++;
      if (flat[j] == ')') {
        depth--;
        if (depth == 0) {
          end = j;
          break;
        }
      }
    }
    if (end > open) menus.add(flat.substring(open, end));
  }
  return menus;
}

/// Screen sources with line comments removed, so prose naming a setting does
/// not count as reading it.
Iterable<(String, String)> _screens() sync* {
  const owners = [
    'services/app_settings_service.dart',
    'widgets/board_view_menu.dart',
  ];
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final rel = f.path.replaceAll(r'\', '/').split('lib/').last;
    if (owners.contains(rel)) continue;
    final code = f
        .readAsLinesSync()
        .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
        .join(' ');
    yield (rel, code.replaceAll(RegExp(r'\s+'), ' '));
  }
}

void main() {
  test('the size slider is offered exactly where a board is sized by it', () {
    final offenders = <String>[];
    for (final (rel, flat) in _screens()) {
      final reads = flat.contains('boardSizeScale');
      final menus = _menus(flat);
      final offering = menus.where((m) => m.contains('boardSize: true'));
      if (reads && (menus.isEmpty || offering.length != menus.length)) {
        offenders.add('$rel: sizes its board by the scale, '
            '${menus.length - offering.length} of ${menus.length} menus '
            'offer no slider');
      }
      if (!reads && offering.isNotEmpty) {
        offenders.add('$rel: offers the slider, never reads the scale');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('a screen that offers the coordinates switch draws coordinates', () {
    final offenders = [
      for (final (rel, flat) in _screens())
        if (_menus(flat).isNotEmpty && !flat.contains('BoardWithCoordinates('))
          rel,
    ];
    expect(offenders, isEmpty,
        reason: 'the menu always carries „Coordinates":\n'
            '${offenders.join('\n')}');
  });

  testWidgets('the Analysis Studio board follows the slider while it shows',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    addTearDown(() => AppSettingsService.instance.setBoardSizeScale(1.0));

    await pumpAt(
        tester,
        const Size(360, 800),
        AnalysisStudioScreen(
          userSession: UserSession(
              id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
          initialFen:
              'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        ));
    final before =
        tester.getSize(find.byType(BoardWithCoordinates).first).width;

    // What the menu's slider calls; nothing is pushed or popped around it.
    await AppSettingsService.instance.setBoardSizeScale(0.6);
    await tester.pumpAndSettle();

    final after = tester.getSize(find.byType(BoardWithCoordinates).first).width;
    expect(after, lessThan(before * 0.7));
  });
}
