import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/theme/app_colors.dart';

void main() {
  group('Theme extension registration', () {
    test('AppTheme.light registers AppColorTokens.light', () {
      final tokens = AppTheme.light.extension<AppColorTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.canvas, equals(AppColorTokens.light.canvas));
    });

    test('AppTheme.dark registers AppColorTokens.dark', () {
      final tokens = AppTheme.dark.extension<AppColorTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.canvas, equals(AppColorTokens.dark.canvas));
    });
  });
}
