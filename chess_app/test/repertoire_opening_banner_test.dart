import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/repertoire/widgets/opening_banner.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  testWidgets('OpeningBanner follows the last-named-position rule',
      (WidgetTester tester) async {
    const knownFen =
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
    const unknownFen =
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1 move2';

    OpeningBookEntry? mockLookup(String fen) {
      if (fen.contains('4P3')) {
        return OpeningBookEntry(
          eco: 'B00',
          name: 'King' 's Pawn Game',
          pgn: '1. e4',
        );
      }
      return null;
    }

    await tester.pumpWidget(wrap(
      OpeningBanner(
        fen: knownFen,
        lookup: mockLookup,
      ),
    ));

    expect(find.text('B00 · King' 's Pawn Game'), findsOneWidget);

    await tester.pumpWidget(wrap(
      OpeningBanner(
        fen: unknownFen,
        lookup: (_) => null,
      ),
    ));

    expect(find.text('B00 · King' 's Pawn Game'), findsOneWidget);
  });
}
