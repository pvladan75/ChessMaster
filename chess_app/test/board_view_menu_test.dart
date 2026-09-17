import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  Widget pumpMenu({bool arrows = false, bool boardSize = false}) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            BoardViewMenu(arrows: arrows, boardSize: boardSize),
          ],
        ),
      ),
    );
  }

  testWidgets('shows only coordinates when arrows is false', (tester) async {
    // 360x640 is required by the brief
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(pumpMenu(arrows: false));
    await tester.tap(find.byType(BoardViewMenu));
    await tester.pumpAndSettle();

    expect(find.text('Coordinates'), findsOneWidget);
    expect(find.text('Arrows for the selected move'), findsNothing);
    expect(find.text('Arrows with statistics'), findsNothing);
    expect(find.text('Engine arrows'), findsNothing);
  });

  testWidgets('shows all switches when arrows is true', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(pumpMenu(arrows: true));
    await tester.tap(find.byType(BoardViewMenu));
    await tester.pumpAndSettle();

    expect(find.text('Coordinates'), findsOneWidget);
    expect(find.text('Arrows for the selected move'), findsOneWidget);
    expect(find.text('Arrows with statistics'), findsOneWidget);
    expect(find.text('Engine arrows'), findsOneWidget);
  });

  testWidgets('no size slider unless the screen asks for one', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(pumpMenu(arrows: true));
    await tester.tap(find.byType(BoardViewMenu));
    await tester.pumpAndSettle();

    expect(find.text('Board size'), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('the size slider sets the board scale', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(() => AppSettingsService.instance.setBoardSizeScale(1.0));

    await tester.pumpWidget(pumpMenu(boardSize: true));
    await tester.tap(find.byType(BoardViewMenu));
    await tester.pumpAndSettle();
    expect(find.text('Board size'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // The left end of the track is the smallest board.
    final slider = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(slider.left + 4, slider.center.dy));
    await tester.pumpAndSettle();
    expect(AppSettingsService.instance.boardSizeScale, 0.6);
    expect(find.text('60%'), findsOneWidget);
  });
}
