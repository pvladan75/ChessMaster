// Basic Flutter widget test for ChessApp.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/main.dart';

void main() {
  testWidgets('ChessApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChessApp());

    // Verify the root widget renders without crashing
    expect(find.byType(ChessApp), findsOneWidget);
  });
}
