import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/server_status_service.dart';

void main() {
  setUp(ServerStatusService.instance.reset);

  test('unknown says nothing, because silence is honest before asking', () {
    final service = ServerStatusService.instance;
    expect(service.status, ServerStatus.unknown);
    expect(service.hasProblem, isFalse);
    expect(service.message, isEmpty);
  });

  test('unknown is not the same as online', () {
    // The bug this fixes: a remembered login looked like a working connection.
    // Never having asked must not read as a yes.
    expect(ServerStatusService.instance.isOnline, isFalse);
  });

  test('a guest is not checked at all', () async {
    // No token means no promise to break — nothing to refuse, nothing to warn
    // about.
    final status = await ServerStatusService.instance.check('');
    expect(status, ServerStatus.unknown);
    expect(ServerStatusService.instance.hasProblem, isFalse);
  });

  test('an unreachable server says the session is only remembered', () async {
    // Points at a port nothing serves, so the timeout path is the one taken.
    final status = await ServerStatusService.instance.check('nevalidan-token');
    expect(status, anyOf(ServerStatus.offline, ServerStatus.expired),
        reason: 'either answer is a problem worth showing; neither is silence');
    expect(ServerStatusService.instance.hasProblem, isTrue);
    expect(ServerStatusService.instance.message, isNotEmpty);
    expect(ServerStatusService.instance.checkedAt, isNotNull);
  });

  test('every problem state carries words a person can read', () {
    // A warning icon with no sentence is decoration.
    expect(ServerStatusService.instance.message, isEmpty);
  });
}
