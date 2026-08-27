import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';

Widget wrap(PlayerColor orientation, {double size = 320}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: BoardWithCoordinates(
            size: size,
            orientation: orientation,
            builder: (inner) => SizedBox(
              key: const ValueKey('tabla'),
              width: inner,
              height: inner,
              child: const ColoredBox(color: Colors.brown),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('white at the bottom puts rank 1 below rank 8, and a left of h',
      (tester) async {
    await tester.pumpWidget(wrap(PlayerColor.white));

    // Positions, not just presence: which way round they run is the whole
    // reason the labels are there, and a reversed list would still contain
    // every letter.
    expect(tester.getCenter(find.text('8')).dy,
        lessThan(tester.getCenter(find.text('1')).dy));
    expect(tester.getCenter(find.text('a')).dx,
        lessThan(tester.getCenter(find.text('h')).dx));
  });

  testWidgets('a flipped board flips the labels with it', (tester) async {
    await tester.pumpWidget(wrap(PlayerColor.black));

    expect(tester.getCenter(find.text('1')).dy,
        lessThan(tester.getCenter(find.text('8')).dy));
    expect(tester.getCenter(find.text('h')).dx,
        lessThan(tester.getCenter(find.text('a')).dx));
  });

  testWidgets('the whole thing fits the size it was given', (tester) async {
    // The caller has already worked out how much room it has, so the labels
    // come out of that rather than being added to it - otherwise a board sized
    // to a 360 dp phone overflows by the width of the gutter, and in a release
    // build that is silent.
    await tester.pumpWidget(wrap(PlayerColor.white, size: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final box = tester.getSize(find.byType(BoardWithCoordinates));
    expect(box.width, 200);
    expect(box.height, 200);
  });

  testWidgets('every file and rank is labelled once', (tester) async {
    await tester.pumpWidget(wrap(PlayerColor.white));

    for (final file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
      expect(find.text(file), findsOneWidget, reason: 'linija $file');
    }
    for (var rank = 1; rank <= 8; rank++) {
      expect(find.text('$rank'), findsOneWidget, reason: 'red $rank');
    }
  });

  /// The switch, which is app-wide: turning the labels off in a lesson leaves
  /// them off in the endgame trainer, because a person who finds them cluttered
  /// means all of them. Added 27.8.2026 after the user asked for it on every
  /// screen a board appears on.
  group('showing them is a setting', () {
    // The setting writes itself to disk, and without this the write never
    // answers: `SharedPreferences.getInstance()` waits on a platform channel
    // that no test binding is listening to, so the await simply never returns
    // and the test hangs rather than fails. Cost twenty minutes to see.
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => AppSettingsService.instance.setShowBoardCoordinates(true));

    testWidgets('off means no labels, and the board keeps the whole size',
        (tester) async {
      await AppSettingsService.instance.setShowBoardCoordinates(false);
      await tester.pumpWidget(wrap(PlayerColor.white, size: 320));

      expect(find.text('a'), findsNothing);
      expect(find.text('1'), findsNothing);
      // The point of switching it here rather than in every caller: with the
      // labels gone the board takes the gutter back, instead of leaving a
      // strip of empty floor where they used to be.
      expect(tester.getSize(find.byKey(const ValueKey('tabla'))).width, 320);
    });

    testWidgets('back on, and the labels are back', (tester) async {
      await AppSettingsService.instance.setShowBoardCoordinates(false);
      await tester.pumpWidget(wrap(PlayerColor.white));
      expect(find.text('a'), findsNothing);

      await AppSettingsService.instance.setShowBoardCoordinates(true);
      await tester.pump();

      expect(find.text('a'), findsOneWidget,
          reason: 'tabla sluša podešavanje, ne svoj prvi build');
    });

    testWidgets('the button flips it, and says which way it goes',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: BoardCoordinatesButton()),
      ));

      expect(find.byIcon(Icons.grid_on), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(AppSettingsService.instance.showBoardCoordinates, isFalse);
      expect(find.byIcon(Icons.grid_off), findsOneWidget,
          reason: 'dugme koje ne pokazuje stanje je dugme koje se pritiska '
              'dvaput da bi se videlo šta radi');
    });
  });
}
