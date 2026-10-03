// Preparation's tablebase and opening explorer — phase 3 of
// docs/PLAN-MOTOR-I-PANELI.md, drawn in docs/skice/paneli/compare_panels.png
// and chosen by the owner on 3.10.2026 (D1–D9 as recommended).
//
//   * D1 — switched on in the board view menu (▦), Analysis's rows and words;
//   * D2 — remembered by this screen; it starts with the engine shown and the
//     two look-ups hidden, and the engine itself off;
//   * D3 — a move tapped in a panel is the trainer's move, played on the board;
//   * D5 — nothing switched on changes the board's size or place;
//   * D7 — on a phone the look-ups stand under the engine in its tab;
//   * D8 — the look-ups go through `PositionLookups`: a hidden panel asks
//     nothing (counted on the requests that leave the app).

import 'dart:convert';

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
import 'package:chess_app/features/analysis_studio/widgets/syzygy_panel_widget.dart';
import 'package:chess_app/features/preparation/screens/preparation_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

import 'support/render_look.dart';

const _owners = Size(1536, 792);
const _smallest = Size(900, 700);
const _phone = Size(360, 640);

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
// Five pieces: the tablebase answers.
const _ending = '8/8/5k2/p7/P1K5/2N5/8/8 b - - 0 52';

/// An engine that asks the real one nothing.
class _Silent extends BoardEngine {
  @override
  void attach({
    required String Function() getFen,
    required void Function(String reason) onRefused,
    required void Function() onChanged,
  }) {}

  @override
  void triggerAnalysis(String fen) {}
}

final List<http.Request> _asked = [];

MockClient _net() => MockClient((req) async {
      _asked.add(req);
      final body = req.url.path.endsWith('/opening-explorer')
          ? {
              'white': 10,
              'draws': 5,
              'black': 3,
              'moves': [
                {
                  'uci': 'e2e4',
                  'san': 'e4',
                  'white': 10,
                  'draws': 5,
                  'black': 3
                },
              ],
            }
          : {
              'category': 'loss',
              'dtz': -4,
              'dtm': -21,
              'checkmate': false,
              'stalemate': false,
              'insufficient_material': false,
              'moves': [
                {
                  'uci': 'f6e5',
                  'san': 'Ke5',
                  'category': 'win',
                  'dtz': 3,
                  'dtm': 20,
                  'zeroing': false,
                  'checkmate': false,
                  'stalemate': false,
                },
              ],
            };
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

int get _explorerAsked =>
    _asked.where((r) => r.url.path.endsWith('/opening-explorer')).length;
int get _tablebaseAsked =>
    _asked.where((r) => r.url.path.endsWith('/api/tablebase')).length;

/// [shown]: the panels this screen remembers as ticked; null — never ticked.
Future<void> _open(
  WidgetTester tester,
  Size size, {
  Set<String>? shown,
  String fen = _start,
}) async {
  SharedPreferences.setMockInitialValues({
    'remember_me': true,
    'user_token': 'tok',
    'user_id': 7,
    'user_email': 'a@b.c',
    'user_name': 'T',
    'user_role': 'korisnik',
    if (shown != null) 'app_panels_preparation': shown.toList(),
  });
  await SessionService.instance.init();
  await AppSettingsService.instance.init();
  _asked.clear();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  final net = _net();
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: PreparationScreen(
      key: UniqueKey(),
      userSession: UserSession(
          token: 'tok', id: 7, email: 'a@b.c', name: 'T', role: 'korisnik'),
      initialFen: fen,
      engine: _Silent(),
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
}

Rect _board(WidgetTester tester) {
  final board = find.byType(ChessBoardWithOverlay);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  return tester.getRect(board);
}

final _engine = find.byType(StockfishAnalysisWidget);
final _explorer = find.byType(OpeningExplorerPanelWidget);
final _tablebase = find.byType(SyzygyPanelWidget);

Future<void> _openViewMenu(WidgetTester tester) async {
  final menu = find.byType(BoardViewMenu);
  expect(menu, findsOneWidget, reason: 'no ▦ on the screen');
  await tester.tap(menu);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _closeMenu(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(loadRenderFonts);

  testWidgets('on arrival: the engine shown, the look-ups hidden and silent',
      (tester) async {
    await _open(tester, _owners);
    expect(_engine, findsOneWidget);
    expect(_explorer, findsNothing);
    expect(_tablebase, findsNothing);
    expect(_asked, isEmpty,
        reason: 'asked ${_asked.map((r) => r.url.path).toList()} '
            'for panels nobody ticked');
  });

  testWidgets('▦ offers Analysis\'s three rows', (tester) async {
    await _open(tester, _owners);
    await _openViewMenu(tester);
    expect(find.text('Panels'), findsOneWidget);
    for (final (label, _) in writingPanels) {
      expect(find.byKey(Key('preparation-panel-$label')), findsOneWidget,
          reason: '„$label" is not a row of ▦');
    }
    await _closeMenu(tester);
  });

  testWidgets('ticking the explorer shows it and asks about the board',
      (tester) async {
    await _open(tester, _owners);
    await _openViewMenu(tester);
    await tester
        .tap(find.byKey(const Key('preparation-panel-Opening Explorer')));
    await tester.pump();
    await _closeMenu(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_explorer, findsOneWidget);
    expect(_explorerAsked, 1);
    expect(_asked.single.url.queryParameters['fen'], _start);
    expect(
        writingPanelShown(PanelScope.preparation, 'opening_explorer'), isTrue,
        reason: 'the tick was not remembered for this screen');
  });

  testWidgets('a move tapped in the explorer is played on the board',
      (tester) async {
    await _open(tester, _owners, shown: {'opening_explorer'});
    expect(_explorer, findsOneWidget);
    final pick = tester.widget<OpeningExplorerPanelWidget>(_explorer);
    expect(pick.onMoveSelected, isNotNull,
        reason: 'the explorer offers no move to play');
    pick.onMoveSelected!('e2e4');
    await tester.pump(const Duration(milliseconds: 200));
    final fen = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
        .controller
        .getFen();
    expect(
        fen.split(' ').first, 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR',
        reason: 'the explorer\'s move did not reach the board');
    // And the explorer follows the board.
    expect(_asked.last.url.queryParameters['fen'],
        startsWith(fen.split(' ').first));
  });

  testWidgets('the tablebase answers an ending, for the distance to mate',
      (tester) async {
    await _open(tester, _owners, shown: {'syzygy'}, fen: _ending);
    expect(_tablebase, findsOneWidget);
    expect(_tablebaseAsked, 1);
    expect(_asked.single.url.queryParameters['mate'], '1');
    expect(_engine, findsNothing,
        reason: 'the engine was unticked and is still drawn');
  });

  for (final size in [_owners, _smallest]) {
    testWidgets('the board keeps its size and place at ${size.width.toInt()}',
        (tester) async {
      await _open(tester, size, shown: {});
      final bare = _board(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, size,
          shown: {'engine_analysis', 'opening_explorer', 'syzygy'});
      expect(_engine, findsOneWidget);
      expect(_explorer, findsOneWidget);
      expect(_board(tester), bare,
          reason: 'switching panels on moved or resized the board');
    });
  }

  testWidgets('on a phone the explorer stands under the engine in its tab',
      (tester) async {
    await _open(tester, _phone, shown: {'engine_analysis', 'opening_explorer'});
    await tester.tap(find.widgetWithText(Tab, 'Engine'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_engine, findsOneWidget);
    expect(_explorer, findsOneWidget);
    expect(
        tester.getRect(_explorer).top, greaterThan(tester.getRect(_engine).top),
        reason: 'the explorer is not under the engine');
  });
}
