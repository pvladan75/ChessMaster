// An engine is named by its binary — what `EvalCache` keys the desktop
// engine's answers by (`exe:<identity>`), and the tutorial's with them.
//
// Moved here on 25.9.2026 from game_tutorial_facts_store_test.dart, when the
// tutorial's own per-game store (`GameFactsStore`) was deleted
// (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1b): the identity outlived it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/engine_identity.dart';

void main() {
  test('the engine is named by its binary, and a missing one is loud',
      () async {
    final dir = Directory.systemTemp.createTempSync('engine_identity_');
    addTearDown(() => dir.deleteSync(recursive: true));
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
