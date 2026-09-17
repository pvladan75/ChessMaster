// The manual says which tab a job is behind — and it says the tab the app has.
//
// docs/PLAN-REORGANIZACIJA.md, Variant B: Home · Practise · Analyse · Teach.
// manual_labels_test holds that every quoted label exists; this holds that
// each page points at the right tab. Until phase 5 it also refused the labels
// the reorganisation retired, from a list beside the gates; with phase 5 those
// words are gone from lib/, so the labels test catches a page that quotes one.
//
// Written 17.9.2026, red on the manual as it stood (every page named
// „Sessions", „Library" or „People" as a tab).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'manual_labels_test.dart' show labelsIn;

const _manualDir = '../site/mislisha/manual';

/// Which tab each page's job is behind. A page may name more than one; the
/// one here is the one it must name.
const _tabOf = <String, List<String>>{
  'index': ['Home', 'Practise', 'Analyse', 'Teach'],
  'getting-started': ['Home', 'Practise', 'Analyse', 'Teach'],
  'students-and-trainers': ['Teach'],
  'write-a-tutorial': ['Teach'],
  'send-a-tutorial': ['Teach'],
  'student-progress': ['Teach', 'Home'],
  'live-session': ['Teach', 'Home'],
  'preparation': ['Teach'],
  'analysis': ['Analyse'],
  'repertoire': ['Practise'],
  'tutorial-video': ['Teach'],
  'practice': ['Practise'],
  'for-students': ['Home'],
};

String _html(String name) => File('$_manualDir/$name.html').readAsStringSync();

void main() {
  test(
      'every page in the map exists, and every page but the parents\' is in it',
      () {
    final pages = Directory(_manualDir)
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.html'))
        .map((n) => n.substring(0, n.length - 5))
        .toSet();
    expect(pages, containsAll(_tabOf.keys));
    expect(pages.difference(_tabOf.keys.toSet()), {'for-parents'},
        reason: 'a page nobody placed on a tab');
  });

  for (final entry in _tabOf.entries) {
    test('${entry.key} names its tab: ${entry.value.join(', ')}', () {
      final labels = labelsIn(_html(entry.key)).toSet();
      for (final tab in entry.value) {
        expect(labels, contains(tab),
            reason: '${entry.key} never quotes the „$tab" tab');
      }
    });
  }
}
