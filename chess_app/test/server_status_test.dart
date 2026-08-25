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

  group('an expired token and a deleted account are not the same refusal', () {
    // Both arrive as 401, and until 25.8.2026 the server could not tell them
    // apart either — a token outlived the account it named, by up to a week.
    // Now it says which, and flattening that back into one status here would
    // undo the fix at the last step: one waits for the same person to sign in
    // again, the other has nobody to sign back in as.
    test('a stale token is expired, and waits', () {
      expect(
        ServerStatusService.statusFor(
            401, '{"error":"Invalid or expired token"}'),
        ServerStatus.expired,
      );
    });

    test('a deleted account is gone, and the session with it', () {
      expect(
        ServerStatusService.statusFor(
            401, '{"error":"Nalog više ne postoji.","reason":"account-gone"}'),
        ServerStatus.gone,
      );
    });

    test('a refusal with no reason falls back to the vaguer one', () {
      // An older server, or a body that is not JSON at all. Guessing "gone"
      // from silence would sign people out on a proxy's error page.
      for (final body in ['', 'nije json', '{}', '<html>502</html>']) {
        expect(ServerStatusService.statusFor(403, body), ServerStatus.expired,
            reason: 'primljeno: $body');
      }
    });

    test('an unverifiable account is not a deleted one', () {
      // The server answers 503 when it cannot reach its own database. Reading
      // that as "you were deleted" would throw away every session at once, for
      // the length of an outage.
      expect(ServerStatusService.statusFor(503, '{"reason":"unverifiable"}'),
          ServerStatus.offline);
    });

    test('an answer is never "not asked"', () {
      // `unknown` means nobody asked, and it is the one state that says nothing
      // on screen. A server that answered and still left the app silent would
      // be the same hole this service was written to close.
      for (final code in [200, 204, 400, 401, 403, 404, 429, 500, 502, 503]) {
        expect(ServerStatusService.statusFor(code, ''),
            isNot(ServerStatus.unknown),
            reason: 'kod: $code');
      }
    });
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
