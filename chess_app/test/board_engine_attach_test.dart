// Preparation's engine is attached the moment the screen is shown — phase 1
// of docs/PLAN-MOTOR-I-PANELI.md.
//
// Before it, `PreparationScreen` attached only when its `TickerMode` changed,
// and on arrival it does not change: a spy counted 0 attaches, as the first
// screen and pushed over another. With nobody attached the engine's answers
// went to no one, so the lines a trainer switched on never came — and no test
// could see it, because every engine in the screen's tests overrides
// `triggerAnalysis` and never asks the real service anything.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/board_engine.dart';
import 'package:chess_app/features/preparation/screens/preparation_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

/// Counts what the screen asks of the engine and asks the real one nothing.
class _Spy extends BoardEngine {
  int attached = 0;
  int detached = 0;
  bool _on = false;

  @override
  void attach({
    required String Function() getFen,
    required void Function(String reason) onRefused,
    required void Function() onChanged,
  }) {
    if (_on) return; // as the real one: only the first attach counts
    _on = true;
    attached++;
  }

  @override
  void detach() {
    if (!_on) return;
    _on = false;
    detached++;
  }

  @override
  void triggerAnalysis(String fen) {}
}

Future<_Spy> _open(WidgetTester tester, {required bool pushed}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1536, 792);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  final spy = _Spy();
  final screen = PreparationScreen(
    userSession: UserSession(
        token: 't', id: 7, email: 'a@b.c', name: 'T', role: 'korisnik'),
    engine: spy,
  );
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: nav,
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: pushed ? const Scaffold(body: Text('below')) : screen,
  ));
  if (pushed) {
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => screen));
  }
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return spy;
}

void main() {
  testWidgets('attached on arrival as the first screen', (tester) async {
    final spy = await _open(tester, pushed: false);
    expect(spy.attached, 1, reason: 'the engine was never attached');
  });

  testWidgets('attached on arrival when pushed over another screen',
      (tester) async {
    final spy = await _open(tester, pushed: true);
    expect(spy.attached, 1, reason: 'the engine was never attached');
  });

  testWidgets('released under a screen on top, attached again on return',
      (tester) async {
    final spy = await _open(tester, pushed: false);
    final nav = Navigator.of(tester.element(find.byType(PreparationScreen)));
    nav.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('on top'))));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(spy.detached, 1, reason: 'kept the engine under a screen on top');
    nav.pop();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(spy.attached, 2, reason: 'not attached again on return');
  });
}
