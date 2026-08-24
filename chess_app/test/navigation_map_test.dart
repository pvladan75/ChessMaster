import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The routing table read as text, because that is where it can go wrong.
///
/// `AppRoutes` and the router are two lists that have to agree, and nothing in
/// Dart makes them. A path added to one and forgotten in the other compiles,
/// passes analysis, and fails in the hand of whoever taps it - the same shape
/// as everything else this project keeps getting caught by.
void main() {
  final routes = File('lib/routing/app_routes.dart').readAsStringSync();
  final router = File('lib/routing/app_router.dart').readAsStringSync();

  /// Every `static const String name = '/path';` in AppRoutes.
  final declared = RegExp(r"static const String (\w+) = '([^']+)';")
      .allMatches(routes)
      .map((m) => (name: m[1]!, path: m[2]!))
      .toList();

  test('the routing table is not empty, or this test proves nothing', () {
    expect(declared.length, greaterThan(8));
  });

  test('every declared route is built by the router', () {
    final missing = [
      for (final route in declared)
        if (!router.contains('path: AppRoutes.${route.name}')) route.name,
    ];
    expect(missing, isEmpty,
        reason: 'ove rute postoje u AppRoutes a ruter ih ne gradi: '
            '${missing.join(', ')}');
  });

  test('the router names its paths, rather than writing them out', () {
    // A hand-written path in the router is a second copy of the contract, and
    // the copy is the one that will be right when the other is renamed.
    final literals = RegExp(r"path: '([^']+)'").allMatches(router);
    expect([for (final m in literals) m[1]!], isEmpty,
        reason:
            'putanja upisana rukom u ruteru, umesto konstante iz AppRoutes');
  });

  test('no two routes share a path', () {
    final paths = declared.map((r) => r.path).toList();
    expect(paths.toSet().length, paths.length,
        reason: 'dve konstante pokazuju na istu putanju');
  });

  test('paths are absolute and lower case, parameters aside', () {
    // They are a contract, not a label: no trailing slash, no spaces, no
    // capitals in the fixed part. Parameters keep their own case, because
    // `:roomCode` is read as a name in code and reads worse as `:roomcode`.
    for (final route in declared) {
      expect(route.path, startsWith('/'), reason: route.name);
      expect(route.path, isNot(endsWith('/')), reason: route.name);
      expect(route.path, isNot(contains(' ')), reason: route.name);
      final fixed = route.path
          .split('/')
          .where((segment) => !segment.startsWith(':'))
          .join('/');
      expect(fixed, equals(fixed.toLowerCase()), reason: route.name);
    }
  });
}
