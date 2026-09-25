// Phase 5 of `docs/PLAN-TUTORIJAL-VIDEO.md`: the tutorial from a game asks
// nothing. A tutorial is material for a film (D10), so the skeleton makes no
// question part, offers no question slot and says nothing about one in the
// request for its words — and the tutorials it makes are the ones the app
// handed over on master, where `withoutQuestions` dropped the question part
// after the fact.
//
// **The expectations are literals measured on master**, not the harness's
// fixtures: `export_fixtures.py` is rewritten in this phase, so a comparison
// with its output would follow the code it is meant to judge. The part counts
// are written below; the FEN of every part, in order, is in
// `show_parts_on_master.json`, written once by the lead from master at
// e6a8c93a.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/words_request.dart';

const _fixtures = 'test/fixtures/game_tutorial';

/// Parts of (the key moments, the whole game) per game, as `withoutQuestions`
/// gave them on master.
const _partsOnMaster = {
  'g01_scandinavian-defense': (9, 11),
  'g02_french-defense': (9, 11),
  'g03_scandinavian-defense': (11, 13),
  'g04_saragossa-opening': (8, 10),
  'g05_french-defense': (8, 10),
  'g06_zukertort-opening': (11, 13),
  'g07_english-opening': (10, 12),
  'g08_nimzowitsch-defense': (6, 8),
  'g09_caro-kann-defense': (9, 11),
  'g10_english-opening': (10, 12),
};

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<String> _fens(Map<String, dynamic> tutorial) => [
      for (final step in tutorial['positionList'] as List)
        (step as Map)['fen'] as String,
    ];

void main() {
  final master = (_read('$_fixtures/show_parts_on_master.json')['games']
      as Map<String, dynamic>);

  test('the ten games are the ten measured on master', () {
    expect(master.keys.toList()..sort(), _partsOnMaster.keys.toList()..sort());
  });

  for (final entry in _partsOnMaster.entries) {
    final name = entry.key;
    final (moments, whole) = entry.value;

    group(name, () {
      final game = _read('$_fixtures/$name.json');
      final facts = game['facts'] as Map<String, dynamic>;
      final measured = master[name] as Map<String, dynamic>;

      test('the recorded answer holds no question slot', () {
        final answer = jsonDecode(game['answer'] as String) as Map;
        final slots = (answer['slots'] as Map).keys.cast<String>();
        expect(slots.where((s) => s.endsWith('.question')), isEmpty);
      });

      test('no moment offers a question, a part that asks or an answer list',
          () {
        for (final m in skeletonMoments(facts)) {
          final id = m['id'];
          expect(
              (m['slots'] as Map).keys.where((k) => '$k'.contains('question')),
              isEmpty,
              reason: '$id offers a question slot');
          for (final part in m['parts'] as List) {
            expect((part as Map)['kind'], 'show', reason: '$id: $part');
            expect(part.containsKey('instruction'), isFalse, reason: '$id');
            expect(part.containsKey('solution'), isFalse, reason: '$id');
          }
          expect(m.containsKey('asks'), isFalse, reason: '$id');
        }
      });

      test('the words request says nothing about a question', () {
        final request = wordsRequestOf(facts, movetext: '1. e4');
        for (final m in request['moments'] as List) {
          expect((m as Map).containsKey('asks'), isFalse);
          expect(m.containsKey('correct'), isFalse);
          for (final s in m['slots'] as List) {
            expect('${(s as Map)['id']}', isNot(contains('question')));
          }
        }
      });

      test(
          'assembles with no missing slot, the unused ones of master, and '
          'the parts master handed over', () {
        final made = assembleSkeleton(facts, game['answer'] as String);
        expect(made.report['problems'], isEmpty);
        expect(made.report['missing_slots'], isEmpty);
        expect(made.report['unused_slots'], measured['unused']);

        final tutorial = made.tutorial!;
        final tutorialGame = made.tutorialGame!;
        expect((tutorial['positionList'] as List).length, moments);
        expect((tutorialGame['positionList'] as List).length, whole);
        expect(_fens(tutorial), measured['tutorial']);
        expect(_fens(tutorialGame), measured['tutorialGame']);

        for (final step in [
          ...tutorial['positionList'] as List,
          ...tutorialGame['positionList'] as List,
        ]) {
          final s = step as Map;
          expect(s['kind'] ?? 'show', 'show');
          expect((s['instruction'] as String?) ?? '', isEmpty);
          expect(s.containsKey('solutionSan'), isFalse);
          expect(s.containsKey('acceptedSans'), isFalse);
        }
      });
    });
  }
}
