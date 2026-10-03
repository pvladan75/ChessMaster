// Analysis on the one home of the look-ups — phase 2 of
// docs/PLAN-MOTOR-I-PANELI.md (D8).
//
// Before it the screen fetched the tablebase and the opening explorer on every
// position change whether their panels were shown or not. Now it hands the
// board to `PositionLookups` and tells it which panels are shown; a hidden
// panel asks nothing. Counted on the requests that leave the app.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/position_lookups.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/dart_source.dart';

const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

/// The look-ups' own network: every request to the tablebase or the book.
final List<http.Request> _asked = [];

MockClient _lookupNet() => MockClient((req) async {
      _asked.add(req);
      return http.Response(
          jsonEncode({'white': 1, 'draws': 1, 'black': 1, 'moves': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

/// Everything else the screen asks, answered and not counted.
MockClient _otherNet() =>
    MockClient((req) async => http.Response(jsonEncode(<Object>[]), 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));

int get _explorerAsked =>
    _asked.where((r) => r.url.path.endsWith('/opening-explorer')).length;
int get _tablebaseAsked => _asked.length - _explorerAsked;

Future<void> _open(WidgetTester tester, {required List<String> hidden}) async {
  SharedPreferences.setMockInitialValues({
    'remember_me': true,
    'user_token': 'tok',
    'user_id': 7,
    'user_email': 'a@b.c',
    'user_name': 'N',
    'user_role': 'korisnik',
    'app_hidden_panels': hidden,
  });
  await SessionService.instance.init();
  await AppSettingsService.instance.init();
  _asked.clear();
  final other = _otherNet();
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(other));
  addTearDown(AnalysisPersistenceService.resetInstance);
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  final net = _lookupNet();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: AnalysisStudioScreen(
      key: UniqueKey(),
      userSession: UserSession(
          token: 'tok', id: 7, email: 'a@b.c', name: 'N', role: 'korisnik'),
      initialFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      lessonApi: LessonApiService(authToken: 'tok', client: other),
      exerciseApi: ExerciseApiService(authToken: 'tok', client: other),
      lookups: PositionLookups(
        tablebase: SyzygyTablebaseService.forTesting(
            client: net, token: 'tok', sleep: (_) async {}),
        explorer: OpeningExplorerService.withClient(net),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  final board = find.byType(ChessBoardWithOverlay);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  tester.widget<ChessBoardWithOverlay>(board).onMove(from, to, '');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with both panels hidden Analysis asks nothing', (tester) async {
    await _open(tester, hidden: ['syzygy', 'opening_explorer']);
    await _play(tester, 'e2', 'e4');
    await _play(tester, 'e7', 'e5');
    expect(_asked, isEmpty,
        reason: 'asked ${_asked.map((r) => r.url.path).toList()} '
            'for panels nobody can see');
  });

  testWidgets('a shown explorer is asked about the board', (tester) async {
    await _open(tester, hidden: ['syzygy']);
    await _play(tester, 'e2', 'e4');
    expect(_explorerAsked, greaterThan(0));
    expect(_asked.any((r) => r.url.queryParameters['fen'] == _afterE4), isTrue,
        reason: 'the explorer was not asked about the position after 1. e4');
    expect(_tablebaseAsked, 0);
  });

  testWidgets('ticking the explorer asks about the board already there',
      (tester) async {
    await _open(tester, hidden: ['syzygy', 'opening_explorer']);
    await _play(tester, 'e2', 'e4');
    expect(_asked, isEmpty);
    await AppSettingsService.instance.setPanelVisible('opening_explorer', true);
    await tester.pumpAndSettle();
    expect(_asked.any((r) => r.url.queryParameters['fen'] == _afterE4), isTrue,
        reason: 'a ticked panel waited for the next move');
  });

  test('the screen keeps no fetching of its own', () {
    final code = codeOf(
        File('lib/features/analysis_studio/screens/analysis_studio_screen.dart')
            .readAsStringSync());
    for (final copy in [
      'SyzygyTablebaseService',
      'OpeningExplorerService',
      '_syzygyRequestId',
      '_openingExplorerRequestId',
    ]) {
      expect(code, isNot(contains(copy)),
          reason: '$copy: the look-ups have one home, PositionLookups');
    }
  });
}
