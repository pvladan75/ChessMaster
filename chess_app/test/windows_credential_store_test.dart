// The real Windows Credential Manager, reached the way the app reaches it
// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D3). Every other test of „Remember
// me" runs against a store in memory; this is the one that proves the store
// in memory behaves like the real one.
//
// Windows only, by design: it tests the machine's own store, which is the
// point (CLAUDE.md rule 8 names this kind of test — here it is the subject,
// not an accident). CI runs on Ubuntu and skips this file.
@TestOn('windows')
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/windows_credential_store.dart';

void main() {
  // Its own prefix, new on every run, and every entry removed afterwards: the
  // owner's own entries live under `Mislisha/`, and this file never names it.
  final prefix = 'MislishaTest-${DateTime.now().microsecondsSinceEpoch}-'
      '${Random().nextInt(1 << 31)}/';
  final store = WindowsCredentialStore(prefix: prefix);
  const address = 'round.trip@example.com';
  const other = 'other@example.com';

  tearDown(() {
    store.delete(address);
    store.delete(other);
  });

  test('a password that was never kept reads as none, not as an error', () {
    expect(store.read(address), isNull);
    // And forgetting one that is not there is not an error either.
    store.delete(address);
  });

  test('a kept password comes back exactly, and the next write replaces it',
      () {
    const first = 'first-Šifra-ž 7 ♞';
    store.write(address, first);
    expect(store.read(address), first);
    expect(store.read('ROUND.TRIP@Example.com'), first,
        reason: 'one entry per address, whatever the case — as Windows '
            'compares the names');

    store.write(address, 'second');
    expect(store.read(address), 'second');
  });

  test('forgetting removes it', () {
    store.write(address, 'forget-me-1');
    store.delete(address);
    expect(store.read(address), isNull);
  });

  test('two addresses are two entries', () {
    store.write(address, 'one-1');
    store.write(other, 'two-2');
    store.delete(address);

    expect(store.read(address), isNull);
    expect(store.read(other), 'two-2');
  });

  test('a password too long for the store is refused, never cut short', () {
    expect(() => store.write(address, 'a' * 1281), throwsArgumentError);
    expect(store.read(address), isNull);
    store.write(address, 'a' * 1280);
    expect(store.read(address), 'a' * 1280);
  });
}
