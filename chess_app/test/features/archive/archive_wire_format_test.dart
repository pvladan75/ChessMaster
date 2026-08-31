import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';

/// What actually goes on the wire, and what comes back off it.
///
/// The widget tests fake this service wholesale, so nothing in them can see a
/// request the server would refuse. Both bugs below were live: the screens hold
/// 'white'/'black' because that is what a segmented button shows, the backend's
/// `requireColor` accepts only 'w'/'b' and answers 400 for anything else, and
/// the repertoire diff therefore failed on every single load.
class _RecordingClient extends http.BaseClient {
  final List<Uri> gets = [];
  final List<Object?> postBodies = [];
  final String body;

  _RecordingClient({this.body = '{}'});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
    );
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    gets.add(url);
    return http.Response(body, 200);
  }

  @override
  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    gets.add(url);
    postBodies.add(body);
    return http.Response(this.body, 200);
  }
}

void main() {
  group('the colour the server actually accepts', () {
    test('the diff sends w, never white', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'subject': 'me',
          'color': 'w',
          'coveredGames': 0,
          'followedGames': 0,
          'leftGames': 0,
        }),
      );
      final api = ArchiveApiService.withClient(client);

      await api.getRepertoireDiff(username: 'me', color: 'white');

      expect(client.gets.single.queryParameters['color'], 'w');
    });

    test('black becomes b, and w and b pass through unchanged', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'subject': 'me',
          'color': 'b',
          'coveredGames': 0,
          'followedGames': 0,
          'leftGames': 0,
        }),
      );
      final api = ArchiveApiService.withClient(client);

      await api.getRepertoireDiff(username: 'me', color: 'black');
      expect(client.gets.last.queryParameters['color'], 'b');

      await api.getRepertoireDiff(username: 'me', color: 'w');
      expect(client.gets.last.queryParameters['color'], 'w');
    });

    test('no colour means the parameter is absent, not empty', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'subject': 'me',
          'color': null,
          'coveredGames': 0,
          'followedGames': 0,
          'leftGames': 0,
        }),
      );
      final api = ArchiveApiService.withClient(client);

      await api.getRepertoireDiff(username: 'me');

      expect(client.gets.single.queryParameters.containsKey('color'), false);
    });
  });

  group('what the server sends back', () {
    test('an unfiltered report has a null colour, and that is not an error',
        () {
      // The server answers `color: null` for "both colours". Cast as a non-null
      // String it threw on every unfiltered report.
      final diff = RepertoireDiff.fromJson({
        'subject': 'me',
        'color': null,
        'coveredGames': 340,
        'followedGames': 222,
        'leftGames': 118,
        'positions': const [],
      });

      expect(diff.color, isNull);
      expect(diff.leftGames, 118);
    });

    test('a move carries the uci a drill can play, and null is a bug report',
        () {
      final diff = RepertoireDiff.fromJson({
        'subject': 'me',
        'color': 'w',
        'coveredGames': 1,
        'followedGames': 0,
        'leftGames': 1,
        'unplayable': 1,
        'positions': [
          {
            'fenKey': 'k',
            'fen': 'x',
            'color': 'w',
            'ply': 6,
            'games': 2,
            'leftGames': 1,
            'prepared': [
              {'san': 'Nf3', 'uci': 'g1f3', 'games': 1, 'score': 0.5}
            ],
            'played': [
              {'san': 'Qh8', 'uci': null, 'games': 1, 'score': 0.0}
            ],
          }
        ],
      });

      expect(diff.positions.single.prepared.single.uci, 'g1f3');
      expect(diff.positions.single.played.single.uci, isNull);
      expect(diff.unplayable, 1, reason: 'counted, not hidden');
    });

    test('profile parsing works', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'byColor': [],
          'bySpeed': [],
          'byTermination': [],
          'byLength': [],
          'byPhase': [],
          'byYear': [],
          'byOpening': [],
        }),
      );
      final api = ArchiveApiService.withClient(client);

      final profile = await api.getPlayerProfile('testuser');
      expect(profile.byColor, isEmpty);
      expect(client.gets.single.path, '/games/profile');
      expect(client.gets.single.queryParameters['username'], 'testuser');
    });

    test('trainer archive parsing works', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'subject': 'testuser',
          'games': '4126', // postgres BIGINT
        }),
      );
      final api = ArchiveApiService.withClient(client);

      final archive = await api.getTrainerStudentArchive('123');
      expect(archive.subject, 'testuser');
      expect(archive.games, 4126);
      expect(client.gets.single.path, '/assignments/student/123/archive');
    });

    test('create homework sends correct payload', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'dryRun': true,
          'candidates': '37',
        }),
      );
      final api = ArchiveApiService.withClient(client);

      final res = await api.createHomeworkFromArchive(
        studentId: '123',
        dryRun: true,
      );

      final sent = jsonDecode(client.postBodies.single as String);
      expect(sent['studentId'], '123');
      expect(sent['dryRun'], true);
      expect(res.dryRun, true);
      expect(res.candidatesCount, 37);
    });

    test('getSubjects parses BIGINT and dates', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'subjects': [
            {
              'subject': 'pvladan',
              'games': 4126,
              'reached_tablebase': 471,
              'with_clocks': '3632',
              'oldest': '2015-03-11T19:22:04.000Z',
              'newest': null,
              'last_import_at': '2026-08-30T17:49:49.163Z'
            }
          ]
        }),
      );
      final api = ArchiveApiService.withClient(client);

      final subjects = await api.getSubjects();

      expect(client.gets.single.path, '/games/subjects');
      expect(subjects.length, 1);
      expect(subjects.first.subject, 'pvladan');
      expect(subjects.first.games, 4126);
      expect(subjects.first.withClocks, 3632);
      expect(subjects.first.oldest, '2015-03-11T19:22:04.000Z');
      expect(subjects.first.newest, isNull);
    });

    test('listImports fetches runs', () async {
      final client = _RecordingClient(
        body: jsonEncode({
          'runs': [
            {
              'id': '1',
              'source': 'pgn',
              'subject': 'pvladan',
              'status': 'done',
              'games_read': 4126,
              'games_stored': 0,
              'games_duplicate': 4126,
              'games_skipped': 0,
              'skipped_by_reason': {},
              'error': null,
              'started_at': '2026-08-30T17:40:00.000Z',
              'finished_at': '2026-08-30T17:49:49.163Z'
            }
          ]
        }),
      );
      final api = ArchiveApiService.withClient(client);

      final runs = await api.listImports();

      expect(client.gets.single.path, '/games/imports');
      expect(runs.length, 1);
      expect(runs.first.id, 1);
      expect(runs.first.subject, 'pvladan');
    });
  });
}
