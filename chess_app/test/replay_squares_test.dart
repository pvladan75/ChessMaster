// The player draws the squares a lesson marked — phase 3 of
// `docs/PLAN-PRIPREMA.md`.
//
// `replayFrameAt` reading `squares` is `lesson_timeline_readers_test.dart`'s
// to hold. This holds the screen to **drawing** what the rule answered (rule
// 10: every layer can be right and the feature still dead): the frame's squares
// reach the painter over the board, and leave it when the position changes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/app_slider.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

const _lucena = '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1';
const _afterRc4 = '1K1k4/1P6/8/8/2R5/8/r7/8 b - - 1 1';

http.Client _server() => MockClient((req) async {
      if (req.url.path == '/recordings/5' && req.method == 'GET') {
        return http.Response(
            jsonEncode({
              'id': 5,
              'room_id': null,
              'source': 'preparation',
              'host_id': 1,
              'host_name': 'Trainer',
              'title': 'Lucena',
              'audio_url': null,
              'duration_ms': 2000,
              'timeline_json': [
                {
                  'timestampMs': 0,
                  'eventType': 'init',
                  'data': {
                    'fen': _lucena,
                    'pgn': '',
                    'arrows': [
                      {'from': 'c1', 'to': 'c4', 'color': 'G'},
                    ],
                    'squares': [
                      {'square': 'c4', 'color': 'Y'},
                      {'square': 'd4', 'color': 'R'},
                    ],
                  },
                },
                {
                  'timestampMs': 1000,
                  'eventType': 'move',
                  'data': {'fen': _afterRc4, 'from': 'c1', 'to': 'c4'},
                },
              ],
              'created_at': '2026-09-27T12:00:00.000Z',
            }),
            200);
      }
      return http.Response('[]', 200);
    });

ChessBoardPainter _painter(WidgetTester tester) {
  final painters = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<ChessBoardPainter>()
      .toList();
  expect(painters, hasLength(1),
      reason: 'the player draws its marks through one painter');
  return painters.single;
}

void main() {
  testWidgets('squares are drawn on the position they were marked on',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData().copyWith(extensions: const [AppColorTokens.light]),
      home: ReplayPlayerScreen(
        recordingId: 5,
        userSession:
            UserSession(id: 1, token: 'tok', email: 'e', name: 'N', role: 'x'),
        client: _server(),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    var painter = _painter(tester);
    expect([for (final s in painter.squares) '${s.colorCode}${s.square}'],
        ['Yc4', 'Rd4']);
    expect([for (final a in painter.arrows) '${a.colorCode}${a.from}${a.to}'],
        ['Gc1c4']);

    // To the end of the recording, past the move.
    final slider = find.byType(AppSlider);
    expect(slider, findsOneWidget);
    tester.widget<AppSlider>(slider).onChanged!(2000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    painter = _painter(tester);
    expect(painter.squares, isEmpty,
        reason: 'a square outlived the position it was marked on');
    expect(painter.arrows, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
