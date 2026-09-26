// The gate of phase 2 of docs/PLAN-FORENZIKA-PADA.md: the app applies the
// Windows engine's rule to every semantics update it sends, and writes a
// trail line for an update the engine is about to refuse — before that update
// leaves `build()`, because the crash of 26.9.2026 came one update after the
// refusal.
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

    test('a node its parent still lists, taken by another', () {
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

  group('the builder', () {
    test('an orphan leaves a line with its label, value and tooltip', () {
      final shadow = SemanticsShadow();
      final first = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder(), shadow);
      _node(first, 0, [1]);
      _node(first, 1, []);
      first.build();
      expect(orphanLines(), isEmpty);

      final second = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder(), shadow);
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
      final b = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder(), shadow);
      _node(b, 0, [1, 1]);
      _node(b, 1, []);
      b.build();
      expect(refusedLines(), hasLength(1));
      expect(refusedLines().single,
          endsWith('semantics refused Node 0 has duplicate child id 1'));
      expect(lastingLines().single,
          contains('semantics refused Node 0 has duplicate child id 1'));
    });

    test('no more than five lines a process', () {
      final shadow = SemanticsShadow();
      final seed = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder(), shadow);
      _node(seed, 0, []);
      seed.build();
      for (var i = 0; i < 6; i++) {
        final b = OrphanWatchingBuilder(ui.SemanticsUpdateBuilder(), shadow);
        _node(b, 100 + i, [], label: 'orphan $i');
        b.build();
      }
      final got = orphanLines();
      expect(got, hasLength(5));
      expect(got.any((l) => l.contains('orphan 5')), isFalse);
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
