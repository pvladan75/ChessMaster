// GET /games/:id/moves from the app's side — D4 of `docs/PLAN-SKELET.md`.
// A real ArchiveApiService over a fake transport, so the request itself is seen.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';

void main() {
  test('the game is asked for by id, and its moves come back as UCI', () async {
    late http.Request sent;
    final api = ArchiveApiService.withClient(MockClient((request) async {
      sent = request;
      return http.Response(
          jsonEncode({
            'startFen':
                'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            'moves': ['e2e4', 'e7e5'],
            'subjectColor': 'b',
          }),
          200);
    }));
    final game = await api.fetchGameMoves('77');
    expect(sent.method, 'GET');
    expect(sent.url.toString(), '$backendUrl/games/77/moves');
    expect(sent.headers['Authorization'], startsWith('Bearer '));
    expect(game.uciMoves, ['e2e4', 'e7e5']);
    expect(game.subjectColor, 'b');
  });

  test('a game no longer in the archive says so, not that the server failed',
      () async {
    final missing = ArchiveApiService.withClient(MockClient(
        (_) async => http.Response('{"error":"Game not found."}', 404)));
    await expectLater(
      missing.fetchGameMoves('77'),
      throwsA(predicate((e) => '$e'.contains('no longer in your archive'))),
    );
    final broken = ArchiveApiService.withClient(
        MockClient((_) async => http.Response('oops', 500)));
    await expectLater(
      broken.fetchGameMoves('77'),
      throwsA(predicate((e) => '$e'.contains('could not be loaded'))),
    );
  });
}
