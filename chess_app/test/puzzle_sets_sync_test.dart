// A puzzle set belongs to the account, not to the machine that made it.
//
// Reported by the owner, 21.9.2026: „Library - Puzzle sets na telefonu ne
// prikazuje puzzle uopšte, iako na istom nalogu u windows-u prikazuje."
//
// It was never a display fault. „Review entire game" runs the engine in the
// Analysis Studio and writes the result to `SharedPreferences` on **that
// device**, and `libraryKindWire` throws for that kind because it has no wire
// name at all. Windows showed his sets because Windows made them; the phone
// had none because none were made there. The account had nothing to do with
// it, which is exactly why the report reads as a bug.
//
// `PuzzleSetRepository` is the one place that now answers „what does this
// account have", and these cases are its rules. They read **the requests**
// through the service's `client` seam rather than overriding methods, because
// a fake that answers a question nobody asked cannot see the question go
// missing (rule 7).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/core/services/puzzle_set_api_service.dart';
import 'package:chess_app/core/services/puzzle_set_repository.dart';

LocalPuzzle _puzzle(String id) => LocalPuzzle(
      id: id,
      fen: '8/8/8/8/8/8/8/K6k w - - 0 1',
      themeLabel: 'fork',
      themeKey: 'fork',
      swing: 2.5,
      sourceMoveSan: 'Nf3',
      sourcePlyIndex: 4,
    );

SavedPuzzleSet _set(String id, String title, {int day = 20}) => SavedPuzzleSet(
      id: id,
      title: title,
      createdAt: DateTime(2026, 9, day),
      puzzles: [_puzzle('$id-a')],
    );

/// Seeds this device's own store, the way a machine that had run „Review
/// entire game" before the server knew about any of this would look.
Future<void> _seedDevice(List<SavedPuzzleSet> sets) async {
  SharedPreferences.setMockInitialValues({
    'analysis_studio_puzzle_sets':
        jsonEncode(sets.map((s) => s.toJson()).toList()),
  });
}

/// A server holding [onServer], recording every request it is asked for.
///
/// [reachable] false is not „an empty account" — it is a server that is not
/// there, which is the distinction the whole fallback rests on.
class _Server {
  _Server({List<SavedPuzzleSet> onServer = const [], this.reachable = true})
      : _sets = {for (final s in onServer) s.id: s};

  final Map<String, SavedPuzzleSet> _sets;
  final bool reachable;
  final List<String> requests = [];

  http.Client get client => MockClient((req) async {
        requests.add('${req.method} ${req.url.path}');
        if (!reachable) return http.Response('{}', 503);

        if (req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'items': _sets.values.map((s) => s.toJson()).toList(),
            }),
            200,
          );
        }
        final id = Uri.decodeComponent(req.url.pathSegments.last);
        if (req.method == 'PUT') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          _sets[id] = SavedPuzzleSet(
            id: id,
            title: body['title'] as String,
            createdAt: DateTime.parse(body['createdAt'] as String),
            puzzles: ((body['puzzles'] as List?) ?? const [])
                .whereType<Map>()
                .map((m) => LocalPuzzle.fromJson(Map<String, dynamic>.from(m)))
                .toList(),
          );
          return http.Response('{"id":"$id"}', 200);
        }
        if (req.method == 'DELETE') {
          final had = _sets.remove(id) != null;
          return http.Response('{}', had ? 200 : 404);
        }
        return http.Response('{}', 404);
      });

  int get puts => requests.where((r) => r.startsWith('PUT')).length;
  List<String> get ids => _sets.keys.toList()..sort();
}

PuzzleSetRepository _repo(_Server server) => PuzzleSetRepository(
      api: PuzzleSetApiService(authToken: 'tok', client: server.client),
    );

void main() {
  test('a set made on another machine shows up here', () async {
    // The owner's report, as a rule. This device has never run an extraction
    // and must still see what the account holds.
    await _seedDevice(const []);
    final server = _Server(onServer: [_set('from-windows', 'Game vs Ana')]);

    final sets = await _repo(server).load();

    expect(sets.map((s) => s.id), ['from-windows']);
  });

  test('sets this device made before the server knew are lifted to it',
      () async {
    // The one-time migration, and the reason the owner's existing work is not
    // stranded on the machine that made it.
    await _seedDevice([_set('old-1', 'Older', day: 12)]);
    final server = _Server(onServer: [_set('from-windows', 'Game vs Ana')]);

    final sets = await _repo(server).load();

    expect(server.ids, ['from-windows', 'old-1']);
    expect(sets.map((s) => s.id).toSet(), {'from-windows', 'old-1'});
    expect(server.puts, 1);
  });

  test('lifting the same set twice does not make a second one', () async {
    // The upload runs on every start and on every device, so a write that was
    // not idempotent would multiply the owner's sets rather than share them.
    await _seedDevice([_set('old-1', 'Older', day: 12)]);
    final server = _Server();

    final repo = _repo(server);
    await repo.load();
    final putsAfterFirst = server.puts;
    await repo.load();

    expect(putsAfterFirst, 1);
    expect(server.puts, 1, reason: 'the second load uploaded it again');
    expect(server.ids, ['old-1']);
  });

  test('a server that cannot be reached is not an empty account', () async {
    // The distinction the fallback rests on. `list()` answers null rather
    // than `[]` for exactly this, so an unreachable server never reads as
    // „your sets are gone".
    await _seedDevice([_set('mine', 'Made here')]);
    final server = _Server(reachable: false);

    final sets = await _repo(server).load();

    expect(sets.map((s) => s.id), ['mine']);
  });

  test('the newest set is first, whichever side it came from', () async {
    await _seedDevice([_set('device', 'Made here', day: 19)]);
    final server =
        _Server(onServer: [_set('server', 'From the account', day: 12)]);

    final sets = await _repo(server).load();

    expect(sets.map((s) => s.id), ['device', 'server']);
  });

  test('a set saved here reaches the account', () async {
    final server = _Server();
    await _seedDevice(const []);

    final saved = await _repo(server)
        .save(title: 'Game vs Bob', puzzles: [_puzzle('p1')]);

    expect(server.ids, [saved.id]);
    // And it survives on the device, so a refused request never costs the
    // engine pass that produced it.
    expect((await LocalPuzzleSetStorageService.instance.loadSets()).length, 1);
  });

  test('deleting takes it off both', () async {
    await _seedDevice([_set('doomed', 'Goes away')]);
    final server = _Server(onServer: [_set('doomed', 'Goes away')]);

    expect(await _repo(server).delete('doomed'), isTrue);

    expect(server.ids, isEmpty);
    expect(await LocalPuzzleSetStorageService.instance.loadSets(), isEmpty);
  });

  test('a refused delete keeps the set here and says so', () async {
    // Added 21.9.2026 with the Library's own delete button. Until then the
    // device copy went whatever the server answered, so a refused delete read
    // as done and the set came back on the next reachable load — the shape
    // this codebase keeps paying for: a step that reports success and fails
    // one load later.
    await _seedDevice([_set('kept', 'Still wanted')]);
    final server =
        _Server(onServer: [_set('kept', 'Still wanted')], reachable: false);

    final deleted = await _repo(server).delete('kept');

    expect(deleted, isFalse, reason: 'a refusal was reported as success');
    expect(
        (await LocalPuzzleSetStorageService.instance.loadSets())
            .map((s) => s.id),
        ['kept'],
        reason: 'the device copy went while the account still has it');
  });

  test('a set deleted elsewhere stops haunting this device', () async {
    // The cache is replaced after a reachable load, not merged into, or a set
    // removed on the desktop would come back every time the phone lifted it
    // again.
    await _seedDevice([_set('gone', 'Deleted on the desktop')]);
    final server = _Server(onServer: [_set('kept', 'Still there')]);

    final repo = _repo(server);
    await repo.load();
    // The lift puts `gone` back on the server, which is right — this device
    // still had it. Deleting it there and loading again must settle it.
    await repo.delete('gone');
    final after = await repo.load();

    expect(after.map((s) => s.id), ['kept']);
    expect(
        (await LocalPuzzleSetStorageService.instance.loadSets())
            .map((s) => s.id),
        ['kept']);
  });
}
