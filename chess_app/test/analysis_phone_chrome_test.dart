// How much of a 360 dp phone the Analysis screen spends before the board.
//
// Reported live twice on 18.9.2026. First: three headers above the board and a
// navigation strip on two rows (TODO-provera 180.2, 180.3, 180.5). The row of
// „My games"/„Scan a book" went, the strip went dense, and the four move
// actions moved to a row of their own — „malo je bolje, ali nije najbolje",
// because two cards of chrome still stood between the board and anything worth
// reading. This is the second answer: one row, with the move in the middle of
// the arrows and its four actions behind one button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

void main() {
  Future<void> openPhone(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(
        userSession: UserSession(
            token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the strip is one row and carries the move', (tester) async {
    await openPhone(tester);

    final strip = find.byType(MoveNavigationControls);
    expect(strip, findsOneWidget);
    expect(tester.getSize(strip).height, lessThanOrEqualTo(56.0),
        reason: 'one row of dense buttons plus the container margin');

    // At the root there is no move, so the centre says nothing rather than
    // naming the strip.
    expect(find.text('Navigation'), findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets('a move with nothing written on it spends no height',
      (tester) async {
    await openPhone(tester);
    // The comment panel is content: with no comment and no NAG anywhere, it is
    // not drawn at all.
    expect(find.byIcon(Icons.edit), findsNothing,
        reason: 'the comment panel draws its edit hint only when it is drawn');
  });

  testWidgets('the four move actions are one button and a sheet on a phone',
      (tester) async {
    await openPhone(tester);

    final more = find.byTooltip('What to do with this move');
    expect(more, findsOneWidget,
        reason: 'nine targets do not fit 360 dp; one does');
    // And the four icons are not also in the row.
    expect(find.byTooltip('Add Comment'), findsNothing);

    await tester.tap(more);
    await tester.pumpAndSettle();
    for (final label in [
      'Add comment',
      'Generate AI comment',
      'NAG symbols (!, ?)',
      'Delete this move',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('a wide window keeps the four as icons', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(
        userSession: UserSession(
            token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add Comment'), findsOneWidget);
    expect(find.byTooltip('What to do with this move'), findsNothing,
        reason: 'a desktop has room for the icons and no need of a sheet');
  });
}
