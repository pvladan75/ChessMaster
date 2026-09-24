// The tablebase is paced and rate-limited — added to phase 1.2a of
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md by the lead, 24.9.2026.
//
// A game review asks the tablebase about every position with seven men or
// fewer, which in a long ending is 50-100 requests in a row. Measured
// 30.8.2026: a run of unpaced requests against tablebase.lichess.ovh draws a
// 429 after 84-98 of them at ~4.8/s, and a request sent while blocked only
// extends the block. The server already paces its own calls
// (`chess_backend/services/tablebaseService.js`, `TABLEBASE_GAP_MS`); this is
// the app doing the same, so the fake here is the client, never the method
// (rule 7), and every assertion is on the requests the client actually saw.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';

const _fenA = '8/8/8/8/8/4k3/8/4K3 w - - 0 1';
const _fenB = '8/8/8/8/8/4K3/8/4k3 b - - 0 1';

/// A clock the service and the test share: [sleep] advances it instead of
/// really waiting, so a test proves the gap the service asks for, not wall
/// time.
class _FakeClock {
  DateTime _now = DateTime(2026, 1, 1);
  DateTime now() => _now;
  Future<void> sleep(Duration d) async => _now = _now.add(d);
  void advance(Duration d) => _now = _now.add(d);
}

/// Fakes the client, not the method: records when each request actually
/// reached the network (by the shared clock) and answers whatever the test
/// queues up in [statusCodes].
class _FakeClient extends http.BaseClient {
  _FakeClient(this.clock);
  final _FakeClock clock;
  final List<DateTime> requestTimes = [];
  List<int> statusCodes = [200];

  /// Positions whose request never answers.
  final Set<String> silent = {};
  String body = jsonEncode({'category': 'draw', 'moves': []});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestTimes.add(clock.now());
    if (silent.any(
        (fen) => request.url.toString().contains(Uri.encodeComponent(fen)))) {
      return Completer<http.StreamedResponse>().future;
    }
    final code = statusCodes[requestTimes.length - 1 < statusCodes.length
        ? requestTimes.length - 1
        : statusCodes.length - 1];
    return http.StreamedResponse(Stream.value(utf8.encode(body)), code);
  }
}

void main() {
  group('pacing', () {
    test('two lookups of different positions are at least 1s apart', () async {
      final clock = _FakeClock();
      final client = _FakeClient(clock);
      final service = SyzygyTablebaseService.forTesting(
          client: client, now: clock.now, sleep: clock.sleep);

      await service.lookup(_fenA);
      await service.lookup(_fenB);

      expect(client.requestTimes, hasLength(2));
      expect(client.requestTimes[1].difference(client.requestTimes[0]),
          greaterThanOrEqualTo(const Duration(seconds: 1)));
    });

    test('a cached position is not delayed and sends nothing twice', () async {
      final clock = _FakeClock();
      final client = _FakeClient(clock);
      final service = SyzygyTablebaseService.forTesting(
          client: client, now: clock.now, sleep: clock.sleep);

      final first = await service.lookup(_fenA);
      final before = clock.now();
      final second = await service.lookup(_fenA);

      expect(client.requestTimes, hasLength(1));
      expect(clock.now(), before, reason: 'a cache hit never sleeps');
      expect(second, same(first));
    });

    test(
        'a 429 blocks for 60s; nothing is sent inside it, and it is never '
        'retried', () async {
      final clock = _FakeClock();
      final client = _FakeClient(clock)..statusCodes = [429];
      final service = SyzygyTablebaseService.forTesting(
          client: client, now: clock.now, sleep: clock.sleep);

      final blocked = await service.lookup(_fenA);
      expect(blocked, isNull);
      expect(client.requestTimes, hasLength(1));

      clock.advance(const Duration(seconds: 2));
      final duringBlock = await service.lookup(_fenB);
      expect(duringBlock, isNull);
      expect(client.requestTimes, hasLength(1),
          reason: 'nothing is sent while the block is on, not even a retry');
    });

    test('after the block passes, the next lookup asks again', () async {
      final clock = _FakeClock();
      final client = _FakeClient(clock)..statusCodes = [429, 200];
      final service = SyzygyTablebaseService.forTesting(
          client: client, now: clock.now, sleep: clock.sleep);

      expect(await service.lookup(_fenA), isNull);
      clock.advance(const Duration(seconds: 61));

      final after = await service.lookup(_fenB);
      expect(client.requestTimes, hasLength(2));
      expect(after, isNotNull);
      expect(after!.category, SyzygyCategory.draw);
    });

    test('two lookups asked together still go out a second apart', () async {
      final clock = _FakeClock();
      final client = _FakeClient(clock);
      final service = SyzygyTablebaseService.forTesting(
          client: client, now: clock.now, sleep: clock.sleep);

      await Future.wait([service.lookup(_fenA), service.lookup(_fenB)]);

      expect(client.requestTimes, hasLength(2));
      expect(client.requestTimes[1].difference(client.requestTimes[0]),
          greaterThanOrEqualTo(const Duration(seconds: 1)));
    });

    // The first version queued every lookup behind the last; one whose answer
    // never came held every later lookup forever — found when a widget test's
    // fake clock was thrown away with a request's timeout on it.
    test('a request that never answers does not hold the next one', () async {
      final clock = _FakeClock();
      final client = _FakeClient(clock)..silent.add(_fenA);
      final service = SyzygyTablebaseService.forTesting(
          client: client, now: clock.now, sleep: clock.sleep);

      unawaited(service.lookup(_fenA));
      final answer = await service
          .lookup(_fenB)
          .timeout(const Duration(seconds: 5), onTimeout: () => fail('held'));

      expect(answer, isNotNull);
      expect(client.requestTimes, hasLength(2));
    });
  });
}
