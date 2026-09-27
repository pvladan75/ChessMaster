// The flow's own guard — phase 8 of `docs/PLAN-PRIPREMA.md`. The gate
// (`recording_tutorial_doors_test.dart`) proves the guard blocks a second
// concurrent start; this proves the other half, that it lets go once the
// first has ended — however it ended, including a refusal — so the same
// recording can be tried again a moment later.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/services/recording_tutorial_flow.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

const _host = 1;
final _session =
    UserSession(token: 'tok', id: _host, email: 'e', name: 'N', role: 'trener');

Map<String, Object?> _recording() => {
      'id': 31,
      'room_id': null,
      // A room recording, refused before anything else is sent — the
      // cheapest way to end the flow quickly and watch the guard let go.
      'source': 'room',
      'host_id': _host,
      'host_name': 'Vladan',
      'title': 'Italijanska',
      'audio_url': null,
      'video_download_url': null,
      'duration_ms': 12000,
      'timeline_json': const [],
      'created_at': '2026-09-27T12:00:00.000Z',
    };

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

class _Server {
  _Server({this.unreachable = false});

  /// A server nobody can reach: the client throws, as a real one does.
  final bool unreachable;
  final requests = <http.Request>[];
  late final client = MockClient((req) async {
    requests.add(req);
    if (unreachable) throw http.ClientException('Connection refused');
    if (req.method == 'GET' && req.url.path == '/recordings/31') {
      return _json(_recording());
    }
    return _json(<Object>[], 200);
  });
  List<String> get calls =>
      [for (final r in requests) '${r.method} ${r.url.path}'];
}

Future<void> _pump(WidgetTester tester, _Server server) async {
  SharedPreferences.setMockInitialValues({});
  await TutorialDraftService.instance.clear();
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => makeTutorialFromRecording(context,
              session: _session, recordingId: 31, client: server.client),
          child: const Text('make'),
        ),
      ),
    ),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'the guard is released after a refusal: the same recording started '
      'again sends its requests again', (tester) async {
    final server = _Server();
    await _pump(tester, server);

    await tester.tap(find.text('make'));
    await tester.pumpAndSettle();
    expect(server.calls, ['GET /recordings/31'],
        reason: 'a room recording is refused before anything else is sent');

    await tester.tap(find.text('make'));
    await tester.pumpAndSettle();
    expect(server.calls, ['GET /recordings/31', 'GET /recordings/31'],
        reason: 'the guard let go, so the second start asks again rather '
            'than being read as a recording whose first run is still going');
  });

  testWidgets(
      'a server that cannot be reached is said, not thrown past the door, '
      'and the guard lets go', (tester) async {
    // Found at grading: the first request was the only one not behind a
    // service that answers a failure with a sentence.
    final server = _Server(unreachable: true);
    await _pump(tester, server);
    await tester.tap(find.text('make'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not read that recording.'), findsOneWidget);
    await tester.tap(find.text('make'));
    await tester.pumpAndSettle();
    expect(server.calls, ['GET /recordings/31', 'GET /recordings/31']);
  });
}
