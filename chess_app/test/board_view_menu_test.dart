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

  Widget pumpMenu({bool arrows = false}) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: [
            BoardViewMenu(arrows: arrows),
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
}
