// The home screen on a phone held sideways.
//
// Reported 16.9.2026: Settings could not be reached — the rail's bell, four
// destinations and Settings do not fit 360 dp of height, and the last one was
// cut off without a word — and the tab's title was drawn over the status bar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/home_screen.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart';

void main() {
  setUpAll(loadRoboto);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final session = UserSession(
      token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik');

  /// The phone's status bar, which is what the title was drawn under.
  const statusBar = 24.0;

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: statusBar);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: HomeScreen(session: session),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final size in landscapePhones) {
    testWidgets('on a phone held sideways at ${sizeLabel(size)}',
        (tester) async {
      await pumpHome(tester, size);
      expect(tester.takeException(), isNull);

      // Settings and the bell are on screen, in the title row.
      expectOnScreen(tester, size, find.byTooltip('Settings'));
      expectOnScreen(
          tester, size, find.byTooltip('Notifications and Invitations'));
      final title = tester.getRect(find.text('Home').last);
      final settings = tester.getRect(find.byTooltip('Settings'));
      expect(settings.center.dy, closeTo(title.center.dy, 24),
          reason: 'Settings is in the title row, not somewhere below it');

      // The title is below the status bar, not under it.
      expect(title.top, greaterThanOrEqualTo(statusBar));

      // Every destination of the rail is on screen.
      for (final tab in kTabNames) {
        expectOnScreen(tester, size, find.text(tab).first);
      }
    });
  }

  testWidgets('a desktop window keeps Settings at the foot of the rail',
      (tester) async {
    await pumpHome(tester, const Size(1280, 800));
    expect(tester.takeException(), isNull);
    final settings = tester.getRect(find.byTooltip('Settings'));
    expect(settings.top, greaterThan(600));
    expect(settings.left, lessThan(100));
  });
}
