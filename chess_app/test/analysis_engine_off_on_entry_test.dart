// The Analysis screen opens with the engine idle.
//
// Asked for twice by the owner while checking the reorganisation live — on
// 17.9.2026 („U Analizu treba da se ulazi sa ugašenim engin-om") and again on
// 18.9 against TODO-provera 177.4. Since the shell put Analyse behind one tap,
// the screen is opened to look at a position far more often than to have it
// judged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

void main() {
  testWidgets('nothing is evaluated until the reader asks for it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900);
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

    // The eval bar is drawn only while the bar half is on, and the panel is
    // told the engine half is off — the two flags `isEnabled` is built from.
    expect(find.byType(HorizontalEvalBarWidget), findsNothing,
        reason: 'the eval bar is the engine talking before it was asked');
    final panel = tester
        .widget<StockfishAnalysisWidget>(find.byType(StockfishAnalysisWidget));
    expect(panel.isEngineEnabled, isFalse);
    expect(panel.isShowEvalBarEnabled, isFalse);
  });
}
