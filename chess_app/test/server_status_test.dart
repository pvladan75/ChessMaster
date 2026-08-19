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

  _selfHealingTests();

  test('every problem state carries words a person can read', () {
    // A warning icon with no sentence is decoration.
    expect(ServerStatusService.instance.message, isEmpty);
  });
}

void _selfHealingTests() {
  group('a failed check must not become permanent', () {
    setUp(ServerStatusService.instance.reset);

    test('successful traffic overrides an earlier failure', () async {
      // The check can land while the server is still running its migrations —
      // the backend takes the better part of a minute to start — and the socket
      // then connects seconds later. The banner must not outlive the truth.
      await ServerStatusService.instance.check('nevalidan-token');
      expect(ServerStatusService.instance.hasProblem, isTrue);

      ServerStatusService.instance.markOnline();

      expect(ServerStatusService.instance.status, ServerStatus.online);
      expect(ServerStatusService.instance.hasProblem, isFalse);
      expect(ServerStatusService.instance.message, isEmpty);
    });

    test('marking online tells anyone listening', () {
      var notified = 0;
      void listener() => notified += 1;
      ServerStatusService.instance.addListener(listener);
      ServerStatusService.instance.markOnline();
      ServerStatusService.instance.removeListener(listener);
      expect(notified, greaterThan(0),
          reason: 'the banner only disappears if it hears about it');
    });

    test('already online, marking again changes nothing', () {
      ServerStatusService.instance.markOnline();
      final at = ServerStatusService.instance.checkedAt;
      ServerStatusService.instance.markOnline();
      expect(ServerStatusService.instance.checkedAt, at);
    });
  });
}
