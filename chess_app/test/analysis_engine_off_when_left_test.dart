// Leaving the Analysis screen stops the engine, and it stays off on return.
//
// Asked for by the owner on 21.9.2026 („da se evaluacija motora zaustavlja
// kad se napušta ekran … motor ostaje ugašen"). The Analyse tab lives in the
// shell's `IndexedStack`, which keeps a hidden tab's state — and its tickers —
// alive, so switching tabs never disposed the screen and the engine searched on
// for a board nobody was looking at. A full-screen route pushed over Analysis
// was the same: the screen underneath stayed attached.
//
// Both ways out are one signal: `TickerMode` goes false for a hidden tab (the
// shell says so) and for a route covered by an opaque one (the `Overlay` says
// so). A dialog is not leaving — it is drawn over a board that is still seen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

void main() {
  StockfishAnalysisWidget panel(WidgetTester tester) =>
      tester.widget<StockfishAnalysisWidget>(
          find.byType(StockfishAnalysisWidget, skipOffstage: false));

  /// Both halves on — the eval panel and the bar — so a fix that turns off
  /// only one of them is seen.
  Future<void> switchEngineOn(WidgetTester tester) async {
    panel(tester).onToggleEngine();
    panel(tester).onToggleShowEvalBar!();
    await tester.pump();
    expect(panel(tester).isEngineEnabled, isTrue,
        reason: 'the fixture never switched the engine on');
    expect(panel(tester).isShowEvalBarEnabled, isTrue);
  }

  void expectEngineOff(WidgetTester tester, String when) {
    expect(panel(tester).isEngineEnabled, isFalse,
        reason: 'the engine is still on $when');
    expect(panel(tester).isShowEvalBarEnabled, isFalse,
        reason: 'the eval bar is still on $when');
  }

  testWidgets('a full-screen route over Analysis switches the engine off',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(
        userSession: UserSession(
            token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik'),
      ),
    ));
    await tester.pumpAndSettle();
    await switchEngineOn(tester);

    // A dialog is not leaving: the board is still in front of the reader.
    showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('over the board')));
    await tester.pumpAndSettle();
    expect(panel(tester).isEngineEnabled, isTrue,
        reason: 'a dialog over the board is not leaving the screen');
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('somewhere else'))));
    await tester.pumpAndSettle();
    expectEngineOff(tester, 'while another screen covers it');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expectEngineOff(tester, 'after coming back');
  });

  testWidgets('switching away from the Analyse tab switches the engine off',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'test-token',
      'user_id': 1,
      'user_email': 'test@example.com',
      'user_name': 'Test',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: appRouteTable,
      errorBuilder: appRouteErrorBuilder,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Not pumpAndSettle: the shell keeps requests and a socket going that
    // nothing answers in a test.
    await tester.pump(const Duration(milliseconds: 200));

    Future<void> openTab(String label) async {
      await tester.tap(find.text(label).first);
      await tester.pump(const Duration(milliseconds: 300));
    }

    await openTab('Analyse');
    expect(find.byType(AnalysisStudioScreen), findsOneWidget);
    await switchEngineOn(tester);

    await openTab('Home');
    expectEngineOff(tester, 'with another tab in front');

    await openTab('Analyse');
    expectEngineOff(tester, 'after coming back to the tab');
  });
}
