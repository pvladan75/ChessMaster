// Basic Flutter widget test for ChessApp.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/screens/login_screen.dart';

void main() {
  testWidgets('ChessApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginRegisterScreen(),
        ),
      ),
    );

    // Verify LoginRegisterScreen renders cleanly
    expect(find.byType(LoginRegisterScreen), findsOneWidget);
  });
}
