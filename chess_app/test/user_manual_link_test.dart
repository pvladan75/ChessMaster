// The two doors from the app to the user's manual — docs/PLAN-PRIRUCNIK.md.
//
// The manual is pages on the site, and the owner asked for it to be reachable
// from the app: a row in Settings, and a link on the F1 shortcuts page, which is
// where somebody lost in the app presses first. Both must open the one address
// the site serves the contents at (`manual_labels_test.dart` pins that address),
// and a browser that cannot open says where the manual is rather than nothing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/user_manual.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/screens/shortcuts_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Trener',
    role: 'korisnik',
  );

  final opened = <Uri>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    opened.clear();
    debugOpenUserManual = (uri) async {
      opened.add(uri);
      return true;
    };
  });

  tearDown(() => debugOpenUserManual = null);

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: SettingsScreen(session: session),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapRow(WidgetTester tester) async {
    // Scrolled to rather than `ensureVisible`: Settings is a lazily built
    // list, so a row below the fold is not in the tree until it is reached.
    final row = find.byKey(const Key('open-user-manual'));
    await tester.scrollUntilVisible(row, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('Settings has a row that opens the manual', (tester) async {
    await pumpSettings(tester);
    await tapRow(tester);

    expect(opened, [Uri.parse(kUserManualUrl)]);
    expect(find.textContaining('Could not open the user manual'), findsNothing);
  });

  testWidgets('the F1 page opens it too', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ShortcutsScreen()));
    await tester.tap(find.byKey(const Key('shortcuts-user-manual')));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse(kUserManualUrl)]);
  });

  testWidgets('a browser that will not open says where the manual is',
      (tester) async {
    for (final refuse in <Future<bool> Function(Uri)>[
      (_) async => false,
      (_) async => throw StateError('no browser'),
    ]) {
      debugOpenUserManual = refuse;
      await pumpSettings(tester);
      await tapRow(tester);

      expect(
          find.textContaining('chesstrainers.app/mislisha/manual'), findsOne);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
