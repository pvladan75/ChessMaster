// The gate of phase 2 of docs/PLAN-FORENZIKA-PADA.md: the app applies the
// Windows engine's rule to every semantics update it sends, and writes a
// trail line for an update the engine is about to refuse — before that update
// leaves `build()`. The engine commits in two steps and the shadow follows
// both (`SemanticsShadow`); the refusal of 26.9.2026 was in the first.
//
// The binding is the app's own mixin over the test binding, for the whole
// file.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/crash_trail.dart';
import 'package:chess_app/services/semantics_shadow.dart';
import 'package:chess_app/widgets/app_slider.dart';

class _WatchedBinding = AutomatedTestWidgetsFlutterBinding with OrphanWatch;

/// One node through the builder's real interface; everything but the tree and
/// the three texts is the plainest value there is.
void _node(
  ui.SemanticsUpdateBuilder b,
  int id,
  List<int> children, {
  String label = '',
  String value = '',
  String tooltip = '',
}) {
  final identity =
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
  b.updateNode(
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
    labelAttributes: const [],
    value: value,
    valueAttributes: const [],
    increasedValue: '',
    increasedValueAttributes: const [],
    decreasedValue: '',
    decreasedValueAttributes: const [],
    hint: '',
    hintAttributes: const [],
    tooltip: tooltip,
    textDirection: TextDirection.ltr,
    transform: identity,
    hitTestTransform: identity,
    childrenInTraversalOrder: Int32List.fromList(children),
    childrenInHitTestOrder: Int32List.fromList(children),
    additionalActions: Int32List(0),
    controlsNodes: null,
    inputType: ui.SemanticsInputType.none,
    locale: null,
    minValue: '',
    maxValue: '',
  );
}

void main() {
  _WatchedBinding();

  late Directory support;
  List<String> orphanLines() {
    final f = File('${support.path}${Platform.pathSeparator}crash_logs'
        '${Platform.pathSeparator}trail.log');
    if (!f.existsSync()) return const [];
    return f
        .readAsStringSync()
        .split('\n')
        .where((l) => l.contains('semantics orphan'))
        .toList();
  }

  List<String> lastingLines() {
    final f = File('${support.path}${Platform.pathSeparator}crash_logs'
        '${Platform.pathSeparator}crash.log');
    if (!f.existsSync()) return const [];
    return f
        .readAsStringSync()
        .split('\n')
        .where((l) => l.contains('semantics '))
        .toList();
  }

  List<String> refusedLines() {
    final f = File('${support.path}${Platform.pathSeparator}crash_logs'
        '${Platform.pathSeparator}trail.log');
    if (!f.existsSync()) return const [];
    return f
        .readAsStringSync()
        .split('\n')
        .where((l) => l.contains('semantics refused'))
        .toList();
  }

  setUp(() async {
    support = Directory.systemTemp.createTempSync('semantics_shadow_');
    CrashTrail.instance.resetForTest();
    OrphanWatch.resetForTest();
    await CrashTrail.instance.init(supportDirectory: () async => support);
  });

  tearDown(() {
    CrashTrail.instance.resetForTest();
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  group('the rule', () {
    test('a node no parent lists is an orphan', () {
      final shadow = SemanticsShadow();
      expect(
          shadow.orphansOf({
            0: [1],
            1: []
          }),
          isEmpty);
      // 2 arrives, but 1 still lists nothing.
      expect(shadow.orphansOf({1: [], 2: []}), [2]);
    });

    test('a node that arrives with the parent that lists it is not', () {
      final shadow = SemanticsShadow();
      expect(
          shadow.orphansOf({
            0: [1],
            1: []
          }),
          isEmpty);
      expect(
          shadow.orphansOf({
            1: [2],
            2: []
          }),
          isEmpty);
    });

    test('a refused node is not kept', () {
      // The engine drops what it refused, so a later update cannot reach
      // anything through it: 3 is an orphan again when it comes back, even
      // though 1 has since listed 2.
      final shadow = SemanticsShadow();
      expect(
          shadow.orphansOf({
            0: [1],
            1: []
          }),
          isEmpty);
      expect(
          shadow.orphansOf({
            1: [],
            2: [3],
            3: []
          }),
          unorderedEquals([2, 3]));
      expect(
          shadow.orphansOf({
            1: [2]
          }),
          isEmpty);
      expect(
          shadow.orphansOf({
            3: [6],
            6: []
          }),
          unorderedEquals([3, 6]));
    });
  });

  group("the other rules, in the engine's words", () {
    test('an orphan is said as the engine says it', () {
      final shadow = SemanticsShadow();
      expect(
          shadow.refusalsOf({
            0: [1],
            1: [],
          }),
          isEmpty);
      expect(shadow.refusalsOf({1: [], 2: []}),
          ['2 will not be in the tree and is not the new root']);
    });

    test('a node that lists a child twice', () {
      expect(
          SemanticsShadow().refusalsOf({
            0: [1, 1],
            1: [],
          }),
          ['Node 0 has duplicate child id 1']);
    });

    // Superseded 26.9.2026, the evening it was written. The first draft called
    // this a refusal, and one live run wrote it five times where the engine's
    // own stream had nothing: the bridge takes a moved child off its old
    // parent itself, in a step before the update
    // (`CreateRemoveReparentedNodesUpdate`). A move whose old parent is not
    // in the update is therefore the ordinary case, and refusing it spent the
    // cap on noise before the real refusal a second later.
    test('a node taken by another parent, its old one not in the update, moves',
        () {
      final shadow = SemanticsShadow();
      expect(
          shadow.refusalsOf({
            0: [1, 2],
            1: [3],
            2: [],
            3: [],
          }),
          isEmpty);
      expect(
          shadow.refusalsOf({
            2: [3],
          }),
          isEmpty);
    });

    test('a node its old parent still lists in the same update is refused', () {
      // Step 1 took 3 off 1; the update then puts it back under 1 and under
      // 2, and the tree is asked to move it — which it cannot do in one go.
      final shadow = SemanticsShadow();
      shadow.refusalsOf({
        0: [1, 2],
        1: [3],
        2: [],
        3: [],
      });
      expect(
          shadow.refusalsOf({
            1: [3],
            2: [3],
          }),
          ['Node 3 is not marked for destruction, would be reparented to 2']);
    });

    test('a node its old parent lets go of in the same update moves freely',
        () {
      final shadow = SemanticsShadow();
      shadow.refusalsOf({
        0: [1, 2],
        1: [3],
        2: [],
        3: [],
      });
      expect(
          shadow.refusalsOf({
            1: [],
            2: [3],
          }),
          isEmpty);
    });

    test('two parents claiming a new node in one update', () {
      final shadow = SemanticsShadow();
      shadow.refusalsOf({
        0: [1, 2],
        1: [],
        2: [],
      });
      expect(
          shadow.refusalsOf({
            1: [4],
            2: [4],
            4: [],
          }),
          ['Node 4 is not marked for destruction, would be reparented to 2']);
    });
  });

  // The refusal of 26.9.2026 (node 13051, line 65 of the bridge): the step
  // that takes moved children off their old parents is itself an update, of
  // the old parents alone, and one of them can be inside a subtree that the
  // same step detaches.
  group('removing reparented nodes', () {
    test('an old parent inside a moving subtree will not be in the tree', () {
      final shadow = SemanticsShadow();
      shadow.refusalsOf({
        0: [1, 2],
        1: [5],
        5: [6],
        6: [7],
        2: [],
        7: [],
      });
      // 5 moves from 1 to 2; 7 moves from 6 to 1. Taking 5 off 1 throws the
      // subtree under 5 away, and 6 — an old parent in the same step — with
      // it.
      final verdict = shadow.judge({
        2: [5],
        5: [6],
        6: [],
        1: [7],
        7: [],
      });
      expect(verdict.orphans, [6]);
      expect(verdict.step, 'removing reparented');
      expect(verdict.why[6], 'lost 7 to 1, inside 5 moving to 2');
      expect(verdict.others, isEmpty);
    });

    test('the moving node itself losing a child is the same shape', () {
      final shadow = SemanticsShadow();
      shadow.refusalsOf({
        0: [1, 2],
        1: [5],
        5: [7],
        2: [],
        7: [],
      });
      final verdict = shadow.judge({
        2: [5],
        5: [],
        1: [7],
        7: [],
      });
      expect(verdict.orphans, [5]);
      expect(verdict.why[5], 'lost 7 to 1, inside 5 moving to 2');
    });

    test('a move with nothing lost inside it passes both steps', () {
      final shadow = SemanticsShadow();
      shadow.refusalsOf({
        0: [1, 2],
        1: [5],
        5: [6],
        2: [],
        6: [],
      });
      expect(
          shadow.refusalsOf({
            2: [5],
            5: [6],
          }),
          isEmpty);
      // And the tree the shadow keeps is the tree after the move.
      expect(
          shadow.refusalsOf({
            6: [8],
            8: [],
          }),
          isEmpty);
    });

    test('a refused removal keeps nothing of the update', () {
      final shadow = SemanticsShadow();
      shadow.refusalsOf({
        0: [1, 2],
        1: [5],
        5: [7],
        2: [],
        7: [],
      });
      shadow.judge({
        2: [5],
        5: [],
        1: [7],
        7: [],
      });
      // The bridge returned early: 5 is still under 1, 7 still under 5.
      expect(
          shadow.refusalsOf({
            5: [7]
          }),
          isEmpty);
    });
  });

  group('the builder', () {
    test('an orphan leaves a line with its label, value and tooltip', () {
      final shadow = SemanticsShadow();
      final first = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(first, 0, [1]);
      _node(first, 1, []);
      first.build();
      expect(orphanLines(), isEmpty);

      final second = OrphanWatchingBuilder(
          ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(second, 1, []);
      _node(second, 2, [],
          label: 'Playback speed', value: '50%', tooltip: 'Speed');
      second.build();
      final got = orphanLines();
      expect(got, hasLength(1));
      expect(got.single, contains('semantics orphan [2]'));
      expect(got.single, contains('"Playback speed"'));
      expect(got.single, contains('"50%"'));
      expect(got.single, contains('"Speed"'));
      // The trail is a ring of 40 and the crash may come later than that:
      // the same line is in crash.log, which is not.
      expect(lastingLines(), [contains('semantics orphan [2]')]);
    });

    test('a duplicate child leaves a refused line, in the trail and crash.log',
        () {
      final shadow = SemanticsShadow();
      final b = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(b, 0, [1, 1]);
      _node(b, 1, []);
      b.build();
      expect(refusedLines(), hasLength(1));
      expect(refusedLines().single,
          endsWith('semantics refused Node 0 has duplicate child id 1'));
      expect(lastingLines().single,
          contains('semantics refused Node 0 has duplicate child id 1'));
    });

    test('an old parent in a moving subtree is named by the label it was sent',
        () {
      final shadow = SemanticsShadow();
      final first = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(first, 0, [1, 2]);
      _node(first, 1, [5]);
      _node(first, 5, [6]);
      _node(first, 6, [7], label: 'Playback speed');
      _node(first, 2, []);
      _node(first, 7, []);
      first.build();
      expect(orphanLines(), isEmpty);

      // 6 lost a child, so the framework sends it again, texts and all.
      final second = OrphanWatchingBuilder(
          ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(second, 2, [5]);
      _node(second, 5, [6]);
      _node(second, 6, [], label: 'Playback speed');
      _node(second, 1, [7]);
      _node(second, 7, []);
      second.build();
      expect(orphanLines(), hasLength(1));
      expect(
          orphanLines().single,
          endsWith('semantics orphan [6] "Playback speed" "" "" '
              'while removing reparented: 6 lost 7 to 1, inside 5 moving to 2 '
              '— held back'));
      expect(lastingLines(), [contains('semantics orphan [6]')]);
    });

    test('a node the update does not carry is named by the last texts it had',
        () {
      final shadow = SemanticsShadow();
      final first = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(first, 0, [1, 2]);
      _node(first, 1, [5]);
      _node(first, 5, [7], tooltip: 'Speed');
      _node(first, 2, []);
      _node(first, 7, []);
      first.build();

      // 5 moves to 2 and loses 7 to 1, and the update happens not to carry
      // 5's texts: the shadow remembers them from the update that did.
      final second = OrphanWatchingBuilder(
          ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(second, 2, [5]);
      _node(second, 1, [7]);
      _node(second, 7, []);
      second.build();
      expect(orphanLines(), [contains('semantics orphan [5] "" "" "Speed"')]);
      expect(orphanLines().single, endsWith('— held back'));
    });

    test('no more than twenty orphan lines a process', () {
      final shadow = SemanticsShadow();
      final seed = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(seed, 0, []);
      seed.build();
      for (var i = 0; i < OrphanWatchingBuilder.orphanCap + 1; i++) {
        final b = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
            sendEarly: (_) {});
        _node(b, 100 + i, [], label: 'orphan $i');
        b.build();
      }
      final got = orphanLines();
      expect(got, hasLength(OrphanWatchingBuilder.orphanCap));
      expect(
          got.any(
              (l) => l.contains('orphan ${OrphanWatchingBuilder.orphanCap}')),
          isFalse);
    });

    test('lines of the other rules do not spend the orphan cap', () {
      // 26.9.2026: five lines of a rule that was wrong used up one shared cap
      // of five, and the refusal the engine actually made a second later was
      // never written.
      final shadow = SemanticsShadow();
      final seed = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
          sendEarly: (_) {});
      _node(seed, 0, [1]);
      _node(seed, 1, []);
      seed.build();
      for (var i = 0; i < OrphanWatchingBuilder.otherCap + 1; i++) {
        final b = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
            sendEarly: (_) {});
        _node(b, 1, [2, 2]);
        _node(b, 2, []);
        b.build();
      }
      expect(refusedLines(), hasLength(OrphanWatchingBuilder.otherCap));
      // Every orphan line the cap allows is still written after that — a
      // shared counter would have spent half of them already.
      for (var i = 0; i < OrphanWatchingBuilder.orphanCap; i++) {
        final b = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder.new, shadow,
            sendEarly: (_) {});
        _node(b, 100 + i, [], label: 'the real one $i');
        b.build();
      }
      expect(orphanLines(), hasLength(OrphanWatchingBuilder.orphanCap));
      expect(orphanLines().last, contains('"the real one 19"'));
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

    testWidgets("Flutter's own Slider in a dialog leaves a line",
        (tester) async {
      // The shape `move_tree_semantics_orphan_test` proves Flutter still
      // orphans (flutter/flutter#190357). The node it orphans carries no text
      // of its own (measured 26.9.2026), so the line is asserted by its ids;
      // the taps before it name the screen.
      final handle = tester.ensureSemantics();
      await openInDialog(tester, Slider(value: 0.5, onChanged: (_) {}));
      expect(orphanLines(), hasLength(1));
      expect(orphanLines().single,
          matches(RegExp(r'semantics orphan \[\d+(, \d+)*\]')));
      final ids = RegExp(r'semantics orphan (\[[^\]]*\])')
          .firstMatch(orphanLines().single)!
          .group(1)!;
      expect(lastingLines(), [contains('semantics orphan $ids')]);
      // Only the orphan: rules 2 and 3 must not fire on what Flutter sends
      // every day, or every line they write is a false alarm.
      expect(refusedLines(), isEmpty);
      handle.dispose();
    });

    testWidgets('AppSlider in a dialog leaves none', (tester) async {
      final handle = tester.ensureSemantics();
      await openInDialog(
          tester, AppSlider(value: 0.5, divisions: 4, onChanged: (_) {}));
      expect(orphanLines(), isEmpty);
      expect(refusedLines(), isEmpty);
      handle.dispose();
    });
  });

  test('main starts the app on the watching binding', () {
    final main =
        File('lib/main.dart').readAsLinesSync().map((l) => l.trim()).toList();
    expect(main, contains('AppBinding.ensureInitialized();'));
    expect(main, isNot(contains('WidgetsFlutterBinding.ensureInitialized();')));
  });
}
