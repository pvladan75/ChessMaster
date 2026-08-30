import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.init();
    await SessionService.instance.signIn(
        UserSession(
          token: 'test-token',
          id: 1,
          email: 'test@example.com',
          name: 'Tester',
          role: 'user',
        ),
        rememberMe: false);
  });

  test('startEndgameAudit handles 409 already running', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/games/endgame/audit');
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          "error": "Provera završnica je već u toku.",
          "reason": "already-running",
          "auditId": "7",
          "subject": "pvladan"
        })),
        409,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = ArchiveApiService.withClient(client);

    try {
      await service.startEndgameAudit('pvladan');
      fail('Should have thrown EndgameAuditAlreadyRunningException');
    } catch (e) {
      expect(e, isA<EndgameAuditAlreadyRunningException>());
      final err = e as EndgameAuditAlreadyRunningException;
      expect(err.auditId, '7');
      expect(err.subject, 'pvladan');
    }
  });
}
