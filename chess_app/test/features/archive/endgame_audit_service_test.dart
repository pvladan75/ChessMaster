import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';

import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/models/user_session.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signIn(
      UserSession(
        token: 'test-token',
        id: 1,
        email: 'test@example.com',
        name: 'Tester',
        role: 'user',
      ),
      rememberMe: false,
    );
  });

  test('startEndgameAudit sends correct request', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/games/endgame/audit');
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Content-Type'], 'application/json');
      expect(jsonDecode(request.body), {'username': 'tester'});

      return http.Response(jsonEncode({'auditId': '123'}), 202);
    });

    final service = ArchiveApiService.withClient(client);
    final id = await service.startEndgameAudit('tester');
    expect(id, '123');
  });

  test('getEndgameMistakes handles string ids and sends correct params',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/games/endgame/mistakes');
      expect(request.url.queryParameters['limit'], '50');
      expect(request.method, 'GET');

      final response = {
        'mistakes': [
          {
            'id': '123',
            'game_id': '456',
            'ply': 20,
            'fen_before': '8/8/4k3/8/4P3/4K3/8/8 w - - 0 40',
            'played_uci': 'e3d3',
            'wdl_before': 2,
            'wdl_after': 0,
          }
        ]
      };
      return http.Response(jsonEncode(response), 200);
    });

    final service = ArchiveApiService.withClient(client);
    final mistakes = await service.getEndgameMistakes(limit: 50);
    expect(mistakes.length, 1);
    expect(mistakes.first.id, '123');
    expect(mistakes.first.gameId, '456');
    expect(mistakes.first.wdlBefore, 2);
  });
}
