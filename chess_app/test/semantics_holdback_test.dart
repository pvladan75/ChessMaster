// The gate of phase 2b of docs/PLAN-FORENZIKA-PADA.md: the engine never sees
// what it would refuse. The builder the app hands the framework keeps every
// node's last data, and on `build()` sends the engine the shadow's plan
// instead of the framework's update — a first commit of its own for inner
// moves, every moved or missing subtree supplied from the cache, and a node
// nothing reaches held back until a parent lists it.
//
// The shapes are the two live ones: the crash of 26.9.2026 at 23:33 (a
// subtree moving under the root while old parents inside it lose children —
// nodes 13051 and 27377 in the engine's stream) and the September orphan
// (a node arriving before the parent that lists it).
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/crash_trail.dart';
import 'package:chess_app/services/semantics_shadow.dart';
import 'package:chess_app/widgets/app_slider.dart';

class _WatchedBinding = AutomatedTestWidgetsFlutterBinding with OrphanWatch;

final Float64List _identity =
    Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

NodeArgs _args(int id, List<int> children, {String label = ''}) => NodeArgs(
      id: id,
      flags: SemanticsFlags.none,
      actions: 0,
      maxValueLength: -1,
      currentValueLength: -1,
      textSelectionBase: -1,
      textSelectionExtent: -1,
      platformViewId: -1,
      scrollChildren: 0,
      scrollIndex: 0,
      traversalParent: -1,
      scrollPosition: 0,
      scrollExtentMax: 0,
      scrollExtentMin: 0,
      rect: const Rect.fromLTWH(0, 0, 10, 10),
      identifier: '',
      label: label,
      labelAttributes: null,
      value: '',
      valueAttributes: null,
      increasedValue: '',
      increasedValueAttributes: null,
      decreasedValue: '',
      decreasedValueAttributes: null,
      hint: '',
      hintAttributes: null,
      tooltip: null,
      textDirection: TextDirection.ltr,
      transform: _identity,
      hitTestTransform: _identity,
      children: children,
      childrenInHitTestOrder: children,
      additionalActions: Int32List(0),
      headingLevel: 0,
      linkUrl: null,
      role: SemanticsRole.none,
      controlsNodes: null,
      validationResult: SemanticsValidationResult.none,
      hitTestBehavior: ui.SemanticsHitTestBehavior.defer,
      inputType: ui.SemanticsInputType.none,
      locale: null,
      minValue: '',
      maxValue: '',
    );

/// A shadow holding [tree], every node of it in the cache, as the engine
/// would after taking it.
SemanticsShadow _shadowWith(Map<int, List<int>> tree) {
  final shadow = SemanticsShadow();
  for (final e in tree.entries) {
    shadow.remember(e.key, _args(e.key, e.value));
  }
  expect(shadow.commit(shadow.plan(tree)), isEmpty);
  expect(shadow.tree, tree);
  return shadow;
}

/// Sends [update] through [shadow]'s planner as the builder would: caches
/// the update's own nodes first.
Plan _plan(SemanticsShadow shadow, Map<int, List<int>> update) {
  for (final e in update.entries) {
    shadow.remember(e.key, _args(e.key, e.value));
  }
  return shadow.plan(update);
}

/// A real builder's stand-in that remembers what it was given; `build()`
/// still returns a real update so the framework can take it.
class _Recorder extends Fake implements ui.SemanticsUpdateBuilder {
  final Map<int, List<int>> nodes = {};
  final List<int> actions = [];

  @override
  void updateNode({
    required int id,
    required SemanticsFlags flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required int? traversalParent,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required Rect rect,
    required String identifier,
    required String label,
    List<StringAttribute>? labelAttributes,
    required String value,
    List<StringAttribute>? valueAttributes,
    required String increasedValue,
    List<StringAttribute>? increasedValueAttributes,
    required String decreasedValue,
    List<StringAttribute>? decreasedValueAttributes,
    required String hint,
    List<StringAttribute>? hintAttributes,
    String? tooltip,
    TextDirection? textDirection,
    required Float64List transform,
    required Float64List hitTestTransform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
    int headingLevel = 0,
    String? linkUrl,
    SemanticsRole role = SemanticsRole.none,
    required List<String>? controlsNodes,
    SemanticsValidationResult validationResult = SemanticsValidationResult.none,
    ui.SemanticsHitTestBehavior hitTestBehavior =
        ui.SemanticsHitTestBehavior.defer,
    required ui.SemanticsInputType inputType,
    required ui.Locale? locale,
    required String minValue,
    required String maxValue,
  }) {
    nodes[id] = childrenInTraversalOrder.toList();
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) =>
      actions.add(id);

  @override
  ui.SemanticsUpdate build() => ui.SemanticsUpdateBuilder().build();
}

/// A shadow whose model refuses every second commit once told to — the
/// builder's fallback cannot be reached through the real planner.
class _RefusingShadow extends SemanticsShadow {
  bool refuseFromNow = false;

  @override
  Plan plan(Map<int, List<int>> update) {
    final real = super.plan(update);
    return refuseFromNow ? real.unsettled('forced by the gate') : real;
  }
}

/// One framework update through the builder: [nodes] as the framework sends
/// them (children only; the rest is plain).
void _send(OrphanWatchingBuilder b, Map<int, List<int>> nodes) {
  for (final e in nodes.entries) {
    _args(e.key, e.value).replayInto(b);
  }
}

void main() {
  _WatchedBinding();
  late Directory support;

  List<String> lines(String kind) {
    final f = File('${support.path}${Platform.pathSeparator}crash_logs'
        '${Platform.pathSeparator}trail.log');
    if (!f.existsSync()) return const [];
    return f
        .readAsStringSync()
        .split('\n')
        .where((l) => l.contains('semantics $kind'))
        .toList();
  }

  setUp(() async {
    support = Directory.systemTemp.createTempSync('semantics_holdback_');
    CrashTrail.instance.resetForTest();
    OrphanWatch.resetForTest();
    await CrashTrail.instance.init(supportDirectory: () async => support);
  });
  tearDown(() {
    CrashTrail.instance.resetForTest();
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  group('the plan', () {
    // 5 moves from 1 to 2; 7 moves from 6 to 1. The engine's own first step
    // would take 5 off 1 and throw 6 away with it, then fail to take 7 off 6.
    const Map<int, List<int>> before = {
      0: [1, 2],
      1: [5],
      5: [6],
      6: [7],
      2: [],
      7: <int>[],
    };
    const Map<int, List<int>> update = {
      2: [5],
      5: [6],
      6: <int>[],
      1: [7],
      7: <int>[],
    };

    test('the inner move gets a commit of its own, first', () {
      final shadow = _shadowWith(before);
      expect(shadow.judge(update, dryRun: true).orphans, [6],
          reason: 'the raw update is the refused shape');
      final plan = _plan(shadow, update);
      expect(plan.part1, {
        6: <int>[],
      });
      expect(plan.part2.keys, unorderedEquals([2, 5, 6, 1, 7]));
      expect(plan.held, isEmpty);
      expect(plan.failed, isEmpty);
      expect(shadow.tree, before, reason: 'planning changes nothing');

      expect(shadow.commit(plan), isEmpty,
          reason: 'the engine takes both commits');
      expect(shadow.tree, {
        0: [1, 2],
        1: [7],
        2: [5],
        5: [6],
        6: <int>[],
        7: <int>[],
      });
    });

    test('the moving node itself losing a child is the same shape', () {
      final shadow = _shadowWith({
        0: [1, 2],
        1: [5],
        5: [7],
        2: [],
        7: <int>[],
      });
      final plan = _plan(shadow, {
        2: [5],
        5: <int>[],
        1: [7],
        7: <int>[],
      });
      expect(plan.part1, {
        5: <int>[],
      });
      expect(shadow.commit(plan), isEmpty);
    });

    test('a subtree that moves without its descendants is supplied whole', () {
      // The framework re-attaches a moved node and sends neither it nor its
      // unchanged descendants (measured 26.9.2026); the engine destroys the
      // subtree in step 1 and needs it back in step 2.
      final shadow = _shadowWith({
        0: [1, 2],
        1: [5],
        5: [6],
        6: <int>[],
        2: <int>[],
      });
      final plan = _plan(shadow, {
        1: <int>[],
        2: [5],
      });
      expect(plan.part1, isEmpty);
      expect(plan.part2, {
        1: <int>[],
        2: [5],
        5: [6],
        6: <int>[],
      });
      expect(plan.supplied, unorderedEquals([5, 6]));
      expect(shadow.commit(plan), isEmpty);
      expect(shadow.tree[2], [5]);
      expect(shadow.tree[5], [6]);
    });

    test('a node nothing reaches is held back and sent when a parent lists it',
        () {
      final shadow = _shadowWith({
        0: [1],
        1: <int>[],
      });
      final first = _plan(shadow, {
        2: [3],
        3: <int>[],
      });
      expect(first.held, unorderedEquals([2, 3]));
      expect(first.part2, isEmpty);
      expect(shadow.commit(first), isEmpty);
      expect(shadow.tree, {
        0: [1],
        1: <int>[],
      });
      expect(shadow.heldIds, {2, 3});

      final second = _plan(shadow, {
        1: [2],
      });
      expect(second.part2, {
        1: [2],
        2: [3],
        3: <int>[],
      });
      expect(second.supplied, unorderedEquals([2, 3]));
      expect(shadow.commit(second), isEmpty);
      expect(shadow.tree[1], [2]);
      expect(shadow.heldIds, isEmpty);
    });

    test('a held node is forgotten after ${SemanticsShadow.heldFor} updates',
        () {
      final shadow = _shadowWith({
        0: [1],
        1: <int>[],
      });
      shadow.commit(_plan(shadow, {
        2: <int>[],
      }));
      expect(shadow.heldIds, {2});
      for (var i = 0; i <= SemanticsShadow.heldFor; i++) {
        shadow.commit(shadow.plan(const {}));
      }
      expect(shadow.heldIds, isEmpty);
      expect(
          _plan(shadow, {
            1: [2]
          }).failed,
          [2]);
    });

    test('a child listed twice is listed once, and two claimants become one',
        () {
      final shadow = _shadowWith({
        0: [1, 2],
        1: [3],
        2: <int>[],
        3: <int>[],
      });
      expect(
          shadow.judge({
            0: [1, 1, 2]
          }, dryRun: true).others,
          ['Node 0 has duplicate child id 1']);
      final twice = _plan(shadow, {
        0: [1, 1, 2],
      });
      expect(twice.part2, {
        0: [1, 2],
      });
      expect(shadow.commit(twice), isEmpty);

      // 1 still lists 3 while 2 takes it: the tree cannot move it in one
      // commit, so 3 goes with 2 alone.
      final claimed = _plan(shadow, {
        1: [3],
        2: [3],
      });
      // And 3, moved, is supplied again for the tree to recreate.
      expect(claimed.part2, {
        1: <int>[],
        2: [3],
        3: <int>[],
      });
      expect(claimed.supplied, [3]);
      expect(shadow.commit(claimed), isEmpty);
      expect(shadow.tree[2], [3]);
    });

    // Found by fuzzing on 27.9.2026, after a plan drafted by rules alone was
    // sent and the engine refused it (00:29, nodes 104 and 37 on Home): the
    // first commit carried old parents inside subtrees the same commit
    // dropped.
    test('an old parent inside a subtree the first commit drops is omitted',
        () {
      final shadow = _shadowWith({
        0: [1],
        1: [2],
        2: [3, 4],
        3: <int>[],
        4: [5],
        5: <int>[],
      });
      final plan = _plan(shadow, {
        0: [3, 5, 2],
        3: <int>[],
        5: [1, 4],
        1: <int>[],
        2: <int>[],
        4: <int>[],
      });
      expect(plan.verified, isTrue, reason: plan.refusal);
      expect(
          plan.part1,
          {
            1: <int>[],
          },
          reason: '2 and 4 are inside what 1 drops');
      expect(shadow.commit(plan), isEmpty);
      expect(shadow.tree[0], [3, 5, 2]);
      expect(shadow.tree[5], [1, 4]);
    });

    test('the other two shapes the fuzzer found settle too', () {
      final a = _shadowWith({
        0: [1, 2, 3],
        1: <int>[],
        2: [4],
        3: [5, 8, 10],
        4: [6],
        5: <int>[],
        6: [7],
        7: <int>[],
        8: [9],
        9: <int>[],
        10: <int>[],
      });
      final planA = _plan(a, {
        0: [6],
        6: [2, 10, 9],
        2: [4, 1, 3],
        4: <int>[],
        1: [7],
        3: <int>[],
        7: [100],
        100: <int>[],
        8: <int>[],
      });
      expect(planA.verified, isTrue, reason: planA.refusal);
      expect(a.commit(planA), isEmpty);
      expect(planA.held, contains(8),
          reason: 'updated and dropped in one frame');

      final b = _shadowWith({
        0: [1, 2, 5],
        1: [3],
        2: [4],
        3: [10],
        4: [9],
        5: [6, 7],
        6: <int>[],
        7: [8],
        8: <int>[],
        9: <int>[],
        10: <int>[],
      });
      final planB = _plan(b, {
        0: [8],
        8: [5],
        5: [4, 7, 6, 9],
        4: [1],
        7: <int>[],
        6: [2],
        2: [3],
        1: <int>[],
        3: <int>[],
      });
      expect(planB.verified, isTrue, reason: planB.refusal);
      expect(b.commit(planB), isEmpty);
    });

    test('every plan over 4000 random trees is one the model takes', () {
      // The class, not three shapes: random trees, random rebuilds (moves,
      // drops, new nodes, a node updated and dropped in one frame), and
      // every plan the cache can supply must be verified and commit clean.
      final rng = Random(7);
      var planned = 0;
      for (var round = 0; round < 4000; round++) {
        final n = 4 + rng.nextInt(9);
        final tree = <int, List<int>>{0: []};
        for (var id = 1; id < n; id++) {
          tree[rng.nextInt(id)]!.add(id);
          tree[id] = [];
        }
        final shadow = _shadowWith(tree);
        final ids = tree.keys.toList();
        final newTree = <int, List<int>>{0: []};
        final alive = <int>[0];
        final shuffled = ids.where((i) => i != 0).toList()..shuffle(rng);
        for (final id in shuffled) {
          if (rng.nextInt(6) == 0) continue;
          newTree[alive[rng.nextInt(alive.length)]]!.add(id);
          newTree[id] = [];
          alive.add(id);
        }
        for (var k = 0; k < rng.nextInt(3); k++) {
          newTree[alive[rng.nextInt(alive.length)]]!.add(100 + k);
          newTree[100 + k] = [];
          alive.add(100 + k);
        }
        final update = <int, List<int>>{};
        for (final e in newTree.entries) {
          final old = tree[e.key];
          if (old == null ||
              old.join(',') != e.value.join(',') ||
              rng.nextInt(4) == 0) {
            update[e.key] = e.value;
          }
        }
        for (final id in ids) {
          if (!newTree.containsKey(id) && rng.nextInt(3) == 0) update[id] = [];
        }
        if (update.isEmpty) continue;
        final plan = _plan(shadow, update);
        if (plan.failed.isNotEmpty) continue;
        planned++;
        expect(plan.verified, isTrue,
            reason: 'round $round: $tree then $update — ${plan.refusal}');
        expect(shadow.commit(plan), isEmpty,
            reason: 'round $round: $tree then $update');
      }
      expect(planned, greaterThan(3000));
    });

    test('a child the cache never saw cannot be supplied', () {
      final shadow = _shadowWith({
        0: [1],
        1: <int>[],
      });
      expect(
          _plan(shadow, {
            1: [9]
          }).failed,
          [9]);
    });
  });

  group('the builder', () {
    late List<_Recorder> made;
    late List<String> order;

    OrphanWatchingBuilder builder(SemanticsShadow shadow) =>
        OrphanWatchingBuilder(
          () {
            final r = _Recorder();
            made.add(r);
            return r;
          },
          shadow,
          sendEarly: (_) => order.add('early'),
        );

    setUp(() {
      made = [];
      order = [];
    });

    test('the inner move is sent first, the rest returned, the line written',
        () {
      final shadow = SemanticsShadow();
      final seed = builder(shadow);
      _send(seed, {
        0: [1, 2],
        1: [5],
        5: [6],
        6: [7],
        2: [],
        7: <int>[],
      });
      _args(6, [7], label: 'TacticsCourse.pdf').replayInto(seed);
      seed.build();
      expect(order, isEmpty);
      expect(lines('orphan'), isEmpty);

      final b = builder(shadow);
      _send(b, {
        2: [5],
        5: [6],
        6: <int>[],
        1: [7],
        7: <int>[],
      });
      b.build();
      order.add('returned');
      expect(order, ['early', 'returned'],
          reason: 'the first commit reaches the view before the second');
      expect(made, hasLength(3), reason: 'seed, first commit, second commit');
      expect(made[1].nodes, {
        6: <int>[],
      });
      expect(made[2].nodes.keys, unorderedEquals([2, 5, 6, 1, 7]));
      expect(lines('orphan'), hasLength(1));
      expect(
          lines('orphan').single,
          endsWith('semantics orphan [6] "" "" "" while removing reparented: '
              '6 lost 7 to 1, inside 5 moving to 2 — held back'));
      expect(lines('hold-back'), isEmpty);
    });

    test('a moved subtree reaches the engine whole', () {
      final shadow = SemanticsShadow();
      final seed = builder(shadow);
      _send(seed, {
        0: [1, 2],
        1: [5],
        5: [6],
        6: <int>[],
        2: <int>[],
      });
      seed.build();
      final b = builder(shadow);
      _send(b, {
        1: <int>[],
        2: [5],
      });
      b.build();
      expect(order, isEmpty);
      expect(made.last.nodes, {
        1: <int>[],
        2: [5],
        5: [6],
        6: <int>[],
      });
    });

    test('an orphan is kept from the engine and sent once adopted', () {
      final shadow = SemanticsShadow();
      final seed = builder(shadow);
      _send(seed, {
        0: [1],
        1: <int>[],
      });
      seed.build();

      final b = builder(shadow);
      _send(b, {
        1: <int>[],
        2: <int>[],
      });
      _args(2, [], label: 'Playback speed').replayInto(b);
      b.build();
      expect(made.last.nodes, {
        1: <int>[],
      });
      expect(lines('orphan'), [
        endsWith('semantics orphan [2] "Playback speed" "" "" while updating '
            '— held back'),
      ]);

      final c = builder(shadow);
      _send(c, {
        1: [2],
      });
      c.build();
      expect(made.last.nodes, {
        1: [2],
        2: <int>[],
      });
    });

    test('a plan the model refuses is never sent; the update goes as it came',
        () {
      // Forced by a shadow whose model refuses everything after a point: the
      // gate cannot make the real planner fail to settle (that is what the
      // random-tree case proves), so the fallback is driven by a stand-in.
      final shadow = _RefusingShadow();
      final seed = builder(shadow);
      _send(seed, {
        0: [1],
        1: <int>[],
      });
      seed.build();
      shadow.refuseFromNow = true;
      final b = builder(shadow);
      _send(b, {
        1: [2],
        2: <int>[],
      });
      b.build();
      expect(order, isEmpty, reason: 'nothing sent early');
      expect(
          made.last.nodes,
          {
            1: [2],
            2: <int>[],
          },
          reason: 'the framework\'s update, untouched');
      expect(lines('hold-back'), [contains('could not settle')]);
      final aside =
          Directory('${support.path}${Platform.pathSeparator}crash_logs')
              .listSync()
              .where((f) => f.path.contains('unsettled-'))
              .toList();
      expect(aside, hasLength(1), reason: 'the update is kept aside');
      expect(File(aside.single.path).readAsStringSync(),
          allOf(contains('"update"'), contains('"tree"')));
    });

    test('what the cache cannot supply goes as it came, and says so', () {
      final shadow = SemanticsShadow();
      final seed = builder(shadow);
      _send(seed, {
        0: [1],
        1: <int>[],
      });
      seed.build();
      final b = builder(shadow);
      _send(b, {
        1: [9],
      });
      b.build();
      expect(order, isEmpty);
      expect(made.last.nodes, {
        1: [9],
      });
      expect(lines('hold-back'), [
        contains('semantics hold-back failed, cache lacks [9]'),
      ]);
    });

    test('custom actions ride with the commit the framework gets back', () {
      final shadow = SemanticsShadow();
      final b = builder(shadow);
      _send(b, {
        0: [1],
        1: <int>[],
      });
      b.updateCustomAction(id: 42, label: 'Move variation earlier');
      b.build();
      expect(made.single.actions, [42]);
    });
  });

  group('the binding', () {
    Future<void> openInDialog(WidgetTester tester, Widget w) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: c,
                builder: (_) => Dialog(child: SizedBox(width: 300, child: w)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byWidget(w), findsOneWidget, reason: 'the slider is showing');
    }

    testWidgets("Flutter's own Slider in a dialog is held back, not refused",
        (tester) async {
      final handle = tester.ensureSemantics();
      await openInDialog(tester, Slider(value: 0.5, onChanged: (_) {}));
      expect(lines('orphan'), hasLength(1));
      expect(lines('orphan').single, endsWith('— held back'));
      expect(OrphanWatchingBuilder.heldEver, isNotEmpty,
          reason: 'the orphan was kept from the engine');
      expect(lines('hold-back'), isEmpty,
          reason: 'every commit the engine got was one it takes');
      handle.dispose();
    });

    testWidgets('AppSlider in a dialog needs nothing held', (tester) async {
      final handle = tester.ensureSemantics();
      await openInDialog(
          tester, AppSlider(value: 0.5, divisions: 4, onChanged: (_) {}));
      expect(lines('orphan'), isEmpty);
      expect(OrphanWatchingBuilder.heldEver, isEmpty);
      handle.dispose();
    });
  });
}
