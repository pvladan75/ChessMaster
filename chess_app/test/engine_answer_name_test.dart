// The bundled engine's answers are kept under a name, and the name must change
// when the engine does — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1.1.
//
// The answers are a function of exactly the binary (phase 0 of
// PLAN-SKELET.md). A file on Windows is named by its size and date; the engine
// built into the app has no file to stat, so it is named by the version of
// `packages/stockfish`. A change to that package's sources bumps its version,
// and this test fails until the name follows — or a new engine would be served
// the old one's answers.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/bundled_engine.dart';

void main() {
  test('the bundled engine is named by its package version', () {
    final pubspec = File('packages/stockfish/pubspec.yaml').readAsLinesSync();
    final version = pubspec
        .firstWhere((l) => l.startsWith('version:'))
        .substring('version:'.length)
        .trim();
    expect(bundledEngine, startsWith('stockfish-$version-'));
  });
}
