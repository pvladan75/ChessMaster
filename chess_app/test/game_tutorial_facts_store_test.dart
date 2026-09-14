// Phase 2 of `docs/PLAN-SKELET.md`, rule 4: a game's answers kept on the
// device, so a build resumes and a second tutorial costs no engine time.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/facts_store.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

List<Map<String, dynamic>> _cands(String move) => [
      {'move': move, 'eval': '+0.20', 'value_for_mover': 20, 'line': move},
    ];

void main() {
  late Directory dir;
  late GameFactsStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('facts_store_');
    store = GameFactsStore(() async => dir);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('the key changes with the game, the depth and the engine', () {
    String key(
            {String start = _start,
            List<String> moves = const ['e2e4'],
            int depth = 18,
            String engine = 'a'}) =>
        factsKey(
            startFen: start, uciMoves: moves, depth: depth, engine: engine);
    final base = key();
    expect(key(), base);
    expect(key(moves: const ['d2d4']), isNot(base));
    expect(key(moves: const ['e2e4', 'e7e5']), isNot(base));
    expect(key(depth: 20), isNot(base));
    expect(key(engine: 'b'), isNot(base));
    expect(key(start: '8/8/8/8/8/6k1/4p3/4K3 w - - 0 1'), isNot(base));
  });

  test('answers written as they come are read back', () async {
    final rec = store.recorder('g1');
    rec.add('fen a', _cands('e4'));
    rec.add('fen b', _cands('d4'));
    await rec.flush();
    expect(
        await store.load('g1'), {'fen a': _cands('e4'), 'fen b': _cands('d4')});
  });

  test('a later write replaces the file whole, and leaves nothing beside it',
      () async {
    final rec = store.recorder('g1');
    rec.add('fen a', _cands('e4'));
    await rec.flush();
    rec.add('fen b', _cands('d4'));
    await rec.flush();
    expect((await store.load('g1')).keys, ['fen a', 'fen b']);
    expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['g1.json']);
  });

  test('many answers at once all arrive', () async {
    final rec = store.recorder('g1');
    for (var i = 0; i < 50; i++) {
      rec.add('fen $i', _cands('m$i'));
    }
    await rec.flush();
    expect(await store.load('g1'), hasLength(50));
  });

  test('a resumed build starts from what was kept', () async {
    final first = store.recorder('g1');
    first.add('fen a', _cands('e4'));
    await first.flush();
    final again = store.recorder('g1', initial: await store.load('g1'));
    again.add('fen b', _cands('d4'));
    await again.flush();
    expect((await store.load('g1')).keys, ['fen a', 'fen b']);
  });

  test('nothing kept, a torn file and a stranger\'s file all read as empty',
      () async {
    expect(await store.load('missing'), isEmpty);

    File('${dir.path}${Platform.pathSeparator}torn.json')
        .writeAsStringSync('{"version": 1, "key": "torn", "answ');
    expect(await store.load('torn'), isEmpty);

    // A file renamed onto another game's key is not that game's answers.
    final rec = store.recorder('g1');
    rec.add('fen a', _cands('e4'));
    await rec.flush();
    File('${dir.path}${Platform.pathSeparator}g1.json')
        .copySync('${dir.path}${Platform.pathSeparator}g2.json');
    expect(await store.load('g2'), isEmpty);

    // And a torn file is simply written over by the next build.
    final over = store.recorder('torn');
    over.add('fen a', _cands('e4'));
    await over.flush();
    expect(await store.load('torn'), hasLength(1));
  });

  test('the engine is named by its binary, and a missing one is loud',
      () async {
    final exe = File('${dir.path}${Platform.pathSeparator}stockfish.exe')
      ..writeAsStringSync('one');
    final first = await engineIdentity(exe.path);
    exe.writeAsStringSync('another build');
    expect(await engineIdentity(exe.path), isNot(first));
    await expectLater(
        engineIdentity('${dir.path}${Platform.pathSeparator}none'),
        throwsA(isA<FileSystemException>()));
  });
}
