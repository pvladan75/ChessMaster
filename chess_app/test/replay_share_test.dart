// A recording made in Preparation, in the player: the host shares it, a student downloads the
// trainer's latest render — phases 5b.4 and 5b.5 of docs/PLAN-SESIJA.md.
//
// The server decides who may read and who may share (`recordingShares.js`);
// this holds the screen to offering only what the server will do: a share
// button for the host of a lesson recorded in Preparation and for nobody else,
// the render's download for a reader, and „No video yet — ask your trainer"
// when there is none — never an export button the server refuses a student.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/theme/app_colors.dart';

const _host = 1;
const _mila = 3;
const _marko = 4;

final _share = find.byKey(const Key('replay-share'));
final _download = find.byKey(const Key('replay-download-video'));

Map<String, Object?> _row({
  String source = 'preparation',
  String? video,
  int durationMs = 95000,
}) =>
    {
      'id': 5,
      'room_id': null,
      'source': source,
      'host_id': _host,
      'host_name': 'Vladan',
      'title': 'Lucena',
      'audio_url': null,
      'video_download_url': video,
      'duration_ms': durationMs,
      'timeline_json': [
        {
          'timestampMs': 0,
          'eventType': 'init',
          'data': {'fen': '8/8/8/8/8/8/8/K6k w - - 0 1'}
        },
        {
          'timestampMs': 400,
          'eventType': 'move',
          'data': {'fen': '8/8/8/8/8/8/8/1K5k b - - 1 1'}
        },
      ],
      'created_at': '2026-09-22T12:00:00.000Z',
    };

class _Server {
  _Server(this.row);
  final Map<String, Object?> row;
  final puts = <http.Request>[];

  late final client = MockClient((req) async {
    final path = req.url.path;
    if (path == '/recordings/5' && req.method == 'GET') {
      return http.Response(jsonEncode(row), 200);
    }
    if (path == '/recordings/5/shares' && req.method == 'GET') {
      return http.Response(
          jsonEncode({
            'studentIds': [_mila]
          }),
          200);
    }
    if (path == '/recordings/5/shares' && req.method == 'PUT') {
      puts.add(req);
      return http.Response(jsonEncode({'added': []}), 200);
    }
    if (path == '/trainer/students') {
      return http.Response(
          jsonEncode({
            'students': [
              {'id': _mila, 'name': 'Mila', 'status': 'accepted'},
              {'id': _marko, 'name': 'Marko', 'status': 'accepted'},
            ]
          }),
          200);
    }
    if (path == '/groups') return http.Response('[]', 200);
    return http.Response('[]', 200);
  });
}

Future<void> _player(WidgetTester tester, _Server server,
    {int me = _host}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData().copyWith(extensions: const [AppColorTokens.light]),
    home: ReplayPlayerScreen(
      recordingId: 5,
      userSession:
          UserSession(id: me, token: 'tok', email: 'e', name: 'N', role: 'x'),
      client: server.client,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the host shares a lesson, with the current list ticked',
      (tester) async {
    final server = _Server(_row());
    await _player(tester, server);
    await tester.tap(_share);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final mila = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('invite-student-$_mila')));
    expect(mila.value, isTrue, reason: 'already shared with Mila');
    await tester.tap(find.byKey(const ValueKey('invite-student-$_marko')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(server.puts, hasLength(1));
    expect(jsonDecode(server.puts.single.body), {
      'studentIds': [_mila, _marko]
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unticking everybody takes the share back', (tester) async {
    final server = _Server(_row());
    await _player(tester, server);
    await tester.tap(_share);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('invite-student-$_mila')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('invite-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(jsonDecode(server.puts.single.body), {'studentIds': []});
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a room recording is not offered for sharing', (tester) async {
    await _player(tester, _Server(_row(source: 'room')));
    expect(_share, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a student has no share and no export, and is told when there '
      'is no video', (tester) async {
    await _player(tester, _Server(_row()), me: _mila);
    expect(_share, findsNothing);
    expect(find.byTooltip('Export to MP4 Video'), findsNothing,
        reason: 'rendering is the trainer\'s');
    await tester.tap(_download);
    await tester.pump();
    expect(find.text('No video yet — ask your trainer.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a student with a render on the server gets its link',
      (tester) async {
    await _player(
        tester,
        _Server(
            _row(video: '/recordings/export-download/r.mp4?token=for-mila')),
        me: _mila);
    await tester.tap(_download);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('for-mila'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the lesson plays to the end of its audio, not its last move',
      (tester) async {
    await _player(tester, _Server(_row(durationMs: 95000)));
    expect(find.text('01:35'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
