// The tutorial studio's engine, tablebase and opening explorer — phases 4 and
// 5 of docs/PLAN-MOTOR-I-PANELI.md, drawn in
// docs/skice/paneli/compare_panels.png and chosen by the owner on 3.10.2026:
// D1–D9 as recommended and **A**, a fourth tab „Engine" beside Flow · Tree ·
// PGN.
//
//   * first, the strip under the board back on the screen at 1536 × 792 —
//     measured a scroll away before the plan (§1);
//   * D1 — ▦ with Analysis's three rows; D2 — remembered by the studio, all
//     hidden at first;
//   * D3 — a move tapped in a panel goes through the studio's own move, so a
//     second move in a part opens a part;
//   * D4 — the engine's lines are read, not inserted;
//   * D5 — the board keeps its size and place, and the map stays beside it;
//   * D6 A — the panels behind a fourth tab, which appears when a row is
//     ticked;
//   * D7 — on a phone a third tab, „Engine", beside Line · Parts;
//   * D8 — the engine through `BoardEngine`, the look-ups through
//     `PositionLookups`: nothing ticked, nothing asked.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/board_engine.dart';
import 'package:chess_app/core/services/position_lookups.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/analysis_panels.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

import 'support/landscape.dart' show expectOnScreen;
import 'support/render_look.dart';

const _owners = Size(1536, 792);
const _phone = Size(360, 640);

/// Counts what the studio asks of the engine and asks the real one nothing.
class _Spy extends BoardEngine {
  int attached = 0;
  bool _on = false;

  @override
  void attach({
    required String Function() getFen,
    required void Function(String reason) onRefused,
    required void Function() onChanged,
  }) {
    if (_on) return;
    _on = true;
    attached++;
  }

  @override
  void detach() => _on = false;

  @override
  void triggerAnalysis(String fen) {}
}

final List<http.Request> _asked = [];

MockClient _net() => MockClient((req) async {
      _asked.add(req);
      return http.Response(
          jsonEncode({
            'white': 10,
            'draws': 5,
            'black': 3,
            'moves': [
              {'uci': 'c7c5', 'san': 'c5', 'white': 10, 'draws': 5, 'black': 3},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

final _session = UserSession(
    token: 'tok', id: 7, email: 'a@b.c', name: 'Trener', role: 'trener');

Future<_Spy> _open(WidgetTester tester, Size size, {Set<String>? shown}) async {
  SharedPreferences.setMockInitialValues({
    'remember_me': true,
    'user_token': 'tok',
    'user_id': 7,
    'user_email': 'a@b.c',
    'user_name': 'Trener',
    'user_role': 'trener',
    if (shown != null) 'app_panels_studio': shown.toList(),
  });
  await SessionService.instance.init();
  await AppSettingsService.instance.init();
  await TutorialDraftService.instance.clear();
  _asked.clear();
  // The phone's layout is chosen by the platform as well as the width. The
  // override is reset by [_onPhone] inside the test body: the framework checks
  // its debug variables before any tearDown runs.
  if (size.width < 600) {
    expect(debugDefaultTargetPlatformOverride, TargetPlatform.android,
        reason: 'open a phone through _onPhone');
  }
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
  final spy = _Spy();
  final net = _net();
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: TutorialStudioScreen(
      session: _session,
      entry: const TutorialEntry.blank('Ruy Lopez'),
      engine: spy,
      lookups: PositionLookups(
        tablebase: SyzygyTablebaseService.forTesting(
            client: net, token: 'tok', sleep: (_) async {}),
        explorer: OpeningExplorerService.withClient(net),
      ),
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return spy;
}

/// Runs [body] as Android, and puts the platform back before the test ends.
Future<void> _onPhone(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  final board = find.byType(ChessBoardWithOverlay);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  tester.widget<ChessBoardWithOverlay>(board).onMove(from, to, '');
  await tester.pump(const Duration(milliseconds: 200));
}

Rect _rectOf(Element e) {
  final box = e.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Inside the window and inside every scrolling box around it.
void _expectSeen(WidgetTester tester, Size size, Finder finder) {
  expectOnScreen(tester, size, finder);
  for (final element in finder.evaluate()) {
    final rect = _rectOf(element);
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Scrollable) {
        final box = _rectOf(ancestor);
        expect(
            box.contains(rect.topLeft) &&
                box.contains(rect.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: '${element.widget} is a scroll away');
      }
      return true;
    });
  }
}

final _engine = find.byType(StockfishAnalysisWidget);
final _explorer = find.byType(OpeningExplorerPanelWidget);

/// The tab itself, not the engine panel's own word „Engine".
final _engineTab = find.byKey(const Key('studio-tab-engine'));

Future<void> _openEngineTab(WidgetTester tester) async {
  expect(_engineTab, findsOneWidget, reason: 'there is no „Engine" tab');
  expect(find.descendant(of: _engineTab, matching: find.text('Engine')),
      findsOneWidget,
      reason: 'the tab does not say „Engine"');
  await tester.tap(_engineTab);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadRenderFonts);

  group('the studio on a window', () {
    testWidgets('the strip under the board is on the screen at 1536 x 792',
        (tester) async {
      await _open(tester, _owners);
      final strip = find.byType(MoveNavigationControls);
      expect(strip, findsOneWidget);
      _expectSeen(tester, _owners, strip);
    });

    testWidgets('nothing ticked: no Engine tab, nothing asked; ▦ offers three',
        (tester) async {
      final spy = await _open(tester, _owners);
      expect(_engineTab, findsNothing);
      expect(_engine, findsNothing);
      expect(_explorer, findsNothing);
      expect(_asked, isEmpty);
      expect(spy.attached, lessThanOrEqualTo(1));
      final menu = find.byType(BoardViewMenu);
      expect(menu, findsOneWidget, reason: 'the studio has no ▦');
      await tester.tap(menu);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final (label, _) in writingPanels) {
        expect(find.byKey(Key('studio-panel-$label')), findsOneWidget,
            reason: '„$label" is not a row of ▦');
      }
      await tester.tapAt(const Offset(4, 400));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('a ticked explorer brings the Engine tab, and asks the board',
        (tester) async {
      await _open(tester, _owners);
      await setWritingPanelShown(PanelScope.studio, 'opening_explorer', true);
      await tester.pump(const Duration(milliseconds: 200));
      await _openEngineTab(tester);
      expect(_explorer, findsOneWidget);
      expect(_asked, isNotEmpty, reason: 'the explorer asked nothing');
      expect(_asked.last.url.queryParameters['fen'],
          startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR'));
      // The Flow, Tree and PGN tabs are still there beside it.
      for (final tab in ['Flow', 'Tree', 'PGN']) {
        expect(find.text(tab), findsWidgets, reason: tab);
      }
    });

    testWidgets('the engine\'s lines are read, not inserted (D4)',
        (tester) async {
      final spy = await _open(tester, _owners, shown: {'engine_analysis'});
      await _openEngineTab(tester);
      expect(_engine, findsOneWidget);
      final panel = tester.widget<StockfishAnalysisWidget>(_engine);
      expect(panel.onInsertLineAsVariation, isNull,
          reason: 'a whole line would open parts nobody played');
      expect(panel.onLoadFenToMainBoard, isNull);
      expect(panel.isEngineEnabled, isFalse,
          reason: 'the engine is off on arrival');
      expect(spy.attached, 1, reason: 'the studio never attached its engine');
    });

    testWidgets('the board keeps its size and place, and the map its column',
        (tester) async {
      await _open(tester, _owners, shown: {});
      final bare = tester.getRect(find.byType(ChessBoardWithOverlay));
      expect(find.byKey(const Key('map-column')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, _owners,
          shown: {'engine_analysis', 'opening_explorer', 'syzygy'});
      await _openEngineTab(tester);
      expect(tester.getRect(find.byType(ChessBoardWithOverlay)), bare,
          reason: 'switching panels on moved or resized the board');
      expect(find.byKey(const Key('map-column')), findsOneWidget,
          reason: 'the map lost its column beside the board');
    });

    testWidgets('a move tapped in the explorer opens a part, as on the board',
        (tester) async {
      await _open(tester, _owners, shown: {'opening_explorer'});
      await _play(tester, 'e2', 'e4');
      await _play(tester, 'e7', 'e5');
      expect(find.textContaining('of 1'), findsWidgets);
      await tester.tap(find.byTooltip('Previous move'));
      await tester.pump(const Duration(milliseconds: 200));
      await _openEngineTab(tester);
      final pick = tester.widget<OpeningExplorerPanelWidget>(_explorer);
      expect(pick.onMoveSelected, isNotNull);
      pick.onMoveSelected!('c7c5'); // beside the part's own 1... e5
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('of 2'), findsWidgets,
          reason: 'the explorer\'s move went past the studio\'s part rule');
    });
  });

  group('the studio on a phone', () {
    testWidgets('a third tab, Engine, beside Line and Parts', (tester) async {
      await _onPhone(() async {
        await _open(tester, _phone, shown: {'opening_explorer'});
        for (final tab in ['Line', 'Parts']) {
          expect(find.text(tab), findsOneWidget, reason: tab);
        }
        await _openEngineTab(tester);
        expect(_explorer, findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });

    testWidgets('nothing ticked, no Engine tab', (tester) async {
      await _onPhone(() async {
        await _open(tester, _phone);
        expect(_engineTab, findsNothing);
        expect(_asked, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  });
}
