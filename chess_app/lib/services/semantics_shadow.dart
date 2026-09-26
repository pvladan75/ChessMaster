import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import 'package:chess_app/services/crash_trail.dart';

/// The Windows engine's accessibility tree, shadowed in the app — phase 2 of
/// `docs/PLAN-FORENZIKA-PADA.md`.
///
/// The engine (`shell/platform/common/accessibility_bridge.cc`) builds a
/// `ui::AXTree` from what the framework sends, and refuses an update the tree
/// cannot take. Once refused, the bridge keeps pointers into the update it has
/// already freed, and a later commit reads them: the crashes of 20–22.9.2026
/// and of 26.9.2026, all in `SetRoleFromFlutterUpdate`. The engine says why
/// only on stderr, which an installed app has nowhere to send, and it names a
/// node by an id nothing maps back to a widget afterwards. So the app applies
/// the engine's rules to every update **before** handing it over, and writes
/// what the engine would refuse, with the node's texts, into the trail and
/// `crash.log` (`CrashTrail.recordLasting`).
///
/// **The engine commits in two steps**, and the model follows both:
///
/// 1. `CreateRemoveReparentedNodesUpdate`: a tree cannot move a node in one
///    update, so every child that a node in the update lists while the tree
///    still holds it under another parent is first taken **off its old
///    parent**. That step is an update of the old parents alone, and it is
///    refused when one of those old parents is itself inside a subtree that
///    the same step detaches — removing the outer subtree throws away the
///    inner old parent, and `ui::AXTree` answers „N will not be in the tree
///    and is not the new root" for it. That is the refusal at line 65 of the
///    bridge, the one the owner's stream showed on 26.9.2026 (node 13051).
///    The bridge returns without clearing its pending list, which is the
///    memory the crash then reads.
/// 2. The update itself: a node the update carries that nothing in the
///    resulting tree reaches is refused with the same words; a node listing
///    the same child twice, and a child claimed by two parents within one
///    update, are refused with the tree's other two messages.
///
/// What is **not** a refusal: a node moving to a new parent whose old parent
/// is not in the update. Step 1 exists for exactly that, and a first draft of
/// this class that called it one wrote five false alarms in one run on
/// 26.9.2026 and spent the whole cap on them, so the real refusal a second
/// later was never written.
class SemanticsShadow {
  /// id → children in traversal order, of every node the engine's tree holds.
  Map<int, List<int>> _tree = <int, List<int>>{};

  /// The last texts each node was sent with. Kept here rather than in the
  /// builder because a step-1 orphan is an **old** parent, sent in some
  /// earlier update, and the builder that carries the current update never
  /// saw it.
  final Map<int, NodeTexts> _texts = <int, NodeTexts>{};

  void reset() {
    _tree = <int, List<int>>{};
    _texts.clear();
  }

  void remember(int id, NodeTexts texts) => _texts[id] = texts;

  NodeTexts? textsOf(int id) => _texts[id];

  /// The ids the engine would refuse under the words „will not be in the tree
  /// and is not the new root", in either step.
  List<int> orphansOf(Map<int, List<int>> update) => judge(update).orphans;

  /// Every refusal, in the engine's own words.
  List<String> refusalsOf(Map<int, List<int>> update) {
    final verdict = judge(update);
    return [
      ...verdict.others,
      for (final id in verdict.orphans)
        '$id will not be in the tree and is not the new root',
    ];
  }

  /// Applies [update] the way the bridge commits it, and returns what it
  /// would refuse: [orphans] under the tree's „will not be in the tree"
  /// words, [others] as the tree's other messages; [step] names which of the
  /// two commits refused (`'removing reparented'` or `'update'`), and [why]
  /// says, for a step-1 orphan, which child left it and which moving subtree
  /// held it.
  ({
    List<int> orphans,
    List<String> others,
    String step,
    Map<int, String> why,
  }) judge(Map<int, List<int>> update) {
    final parentOf = <int, int>{
      for (final entry in _tree.entries)
        for (final child in entry.value) child: entry.key,
    };

    // Step 1 — take reparented children off their old parents.
    final removed = <int, List<int>>{};
    final moved = <int, ({int from, int to})>{};
    for (final entry in update.entries) {
      for (final child in entry.value) {
        final old = parentOf[child];
        if (old == null || old == entry.key) continue;
        (removed[old] ??= List<int>.of(_tree[old] ?? const <int>[]))
            .remove(child);
        moved[child] = (from: old, to: entry.key);
      }
    }
    if (removed.isNotEmpty) {
      final afterRemoval = <int, List<int>>{..._tree, ...removed};
      final reached = _reachable(afterRemoval);
      final lost = [
        for (final id in removed.keys)
          if (!reached.contains(id)) id,
      ];
      if (lost.isNotEmpty) {
        final why = <int, String>{};
        for (final id in lost) {
          final left = [
            for (final m in moved.entries)
              if (m.value.from == id) '${m.key} to ${m.value.to}',
          ].join(', ');
          // The moving subtree that held it: walk up the old tree to the first
          // ancestor (itself included) that is on the move.
          int? holder;
          for (int? at = id; at != null; at = parentOf[at]) {
            if (moved.containsKey(at)) {
              holder = at;
              break;
            }
          }
          why[id] = 'lost $left'
              '${holder == null ? '' : ', inside $holder moving to ${moved[holder]!.to}'}';
        }
        // The bridge returns here without touching its tree or clearing its
        // pending list; nothing is kept from this update.
        return (
          orphans: lost,
          others: const <String>[],
          step: 'removing reparented',
          why: why,
        );
      }
      _tree = {
        for (final entry in afterRemoval.entries)
          if (reached.contains(entry.key)) entry.key: entry.value,
      };
    }

    // Step 2 — the update itself.
    final others = <String>[];
    final claimed = <int, int>{};
    for (final entry in update.entries) {
      final parent = entry.key;
      final seen = <int>{};
      for (final child in entry.value) {
        if (!seen.add(child)) {
          others.add('Node $parent has duplicate child id $child');
          continue;
        }
        final claimedBy = claimed[child];
        if (claimedBy != null && claimedBy != parent) {
          others.add('Node $child is not marked for destruction, '
              'would be reparented to $parent');
          continue;
        }
        claimed[child] = parent;
        // Step 1 took the child off an old parent the update does not carry.
        // An old parent the update **does** carry, and that still lists the
        // child, puts it back — and then the tree is asked to move it.
        final old = moved[child]?.from;
        if (old != null &&
            old != parent &&
            (update[old]?.contains(child) ?? false)) {
          others.add('Node $child is not marked for destruction, '
              'would be reparented to $parent');
        }
      }
    }
    final merged = <int, List<int>>{..._tree, ...update};
    final reached = _reachable(merged);
    final orphans = [
      for (final id in update.keys)
        if (!reached.contains(id)) id,
    ];
    _tree = {
      for (final entry in merged.entries)
        if (reached.contains(entry.key)) entry.key: entry.value,
    };
    // The update's own ids are spared: an orphan is by definition not in the
    // tree, and its texts are what the line about it is made of.
    _texts.removeWhere(
      (id, _) => !_tree.containsKey(id) && !update.containsKey(id),
    );
    return (
      orphans: orphans,
      others: others,
      step: 'update',
      why: const <int, String>{},
    );
  }

  static Set<int> _reachable(Map<int, List<int>> tree) {
    final reached = <int>{};
    final stack = <int>[0];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      final children = tree[id];
      if (children == null || !reached.add(id)) continue;
      stack.addAll(children);
    }
    return reached;
  }
}

/// What a node was last called: enough to recognise it in the trail.
class NodeTexts {
  const NodeTexts(this.label, this.value, this.tooltip);
  final String label;
  final String value;
  final String? tooltip;

  bool get hasAnyText =>
      label.isNotEmpty || value.isNotEmpty || (tooltip?.isNotEmpty ?? false);
}

/// The builder the app hands the framework: forwards everything to the real
/// one, and asks the shadow first.
class OrphanWatchingBuilder implements ui.SemanticsUpdateBuilder {
  OrphanWatchingBuilder(this._real, this._shadow);

  final ui.SemanticsUpdateBuilder _real;
  final SemanticsShadow _shadow;
  final Map<int, List<int>> _children = <int, List<int>>{};

  /// Two caps, one a kind, so that no line of one kind can silence the other:
  /// on 26.9.2026 five lines of a rule that was wrong spent a single cap of
  /// five before the refusal the engine actually made.
  static const int orphanCap = 20;
  static const int otherCap = 10;
  static int _orphanLines = 0;
  static int _otherLines = 0;

  @visibleForTesting
  static void resetCapForTest() {
    _orphanLines = 0;
    _otherLines = 0;
  }

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
    _children[id] = childrenInTraversalOrder.toList();
    _shadow.remember(id, NodeTexts(label, value, tooltip));
    _real.updateNode(
      id: id,
      flags: flags,
      actions: actions,
      maxValueLength: maxValueLength,
      currentValueLength: currentValueLength,
      textSelectionBase: textSelectionBase,
      textSelectionExtent: textSelectionExtent,
      platformViewId: platformViewId,
      scrollChildren: scrollChildren,
      scrollIndex: scrollIndex,
      traversalParent: traversalParent ?? -1,
      scrollPosition: scrollPosition,
      scrollExtentMax: scrollExtentMax,
      scrollExtentMin: scrollExtentMin,
      rect: rect,
      identifier: identifier,
      label: label,
      labelAttributes: labelAttributes ?? const <StringAttribute>[],
      value: value,
      valueAttributes: valueAttributes ?? const <StringAttribute>[],
      increasedValue: increasedValue,
      increasedValueAttributes:
          increasedValueAttributes ?? const <StringAttribute>[],
      decreasedValue: decreasedValue,
      decreasedValueAttributes:
          decreasedValueAttributes ?? const <StringAttribute>[],
      hint: hint,
      hintAttributes: hintAttributes ?? const <StringAttribute>[],
      tooltip: tooltip ?? '',
      textDirection: textDirection,
      transform: transform,
      hitTestTransform: hitTestTransform,
      childrenInTraversalOrder: childrenInTraversalOrder,
      childrenInHitTestOrder: childrenInHitTestOrder,
      additionalActions: additionalActions,
      headingLevel: headingLevel,
      linkUrl: linkUrl ?? '',
      role: role,
      controlsNodes: controlsNodes,
      validationResult: validationResult,
      hitTestBehavior: hitTestBehavior,
      inputType: inputType,
      locale: locale,
      minValue: minValue,
      maxValue: maxValue,
    );
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) =>
      _real.updateCustomAction(
        id: id,
        label: label,
        hint: hint,
        overrideId: overrideId,
      );

  @override
  ui.SemanticsUpdate build() {
    final verdict = _shadow.judge(_children);
    final orphans = verdict.orphans;
    if (orphans.isNotEmpty) {
      // The first orphan that has any text names the line; an orphan with no
      // text of its own (measured 26.9.2026: the node Flutter orphans for a
      // nested tooltip or a slider's overlay carries none) still gets a line,
      // by its ids alone — which is what the engine's stderr names too.
      var chosen = _shadow.textsOf(orphans.first);
      for (final id in orphans) {
        final texts = _shadow.textsOf(id);
        if (texts != null && texts.hasAnyText) {
          chosen = texts;
          break;
        }
      }
      final label = chosen?.label ?? '';
      final value = chosen?.value ?? '';
      final tooltip = chosen?.tooltip ?? '';
      final why = [
        for (final id in orphans)
          if (verdict.why[id] != null) '$id ${verdict.why[id]}',
      ].join('; ');
      _sayOrphan('semantics orphan $orphans "$label" "$value" "$tooltip" '
          'while ${verdict.step == 'update' ? 'updating' : verdict.step}'
          '${why.isEmpty ? '' : ': $why'}');
    }
    for (final refusal in verdict.others) {
      _sayOther('semantics refused $refusal');
    }
    return _real.build();
  }

  static void _sayOrphan(String line) {
    if (_orphanLines >= orphanCap) return;
    _orphanLines++;
    CrashTrail.instance.recordLasting(line);
  }

  static void _sayOther(String line) {
    if (_otherLines >= otherCap) return;
    _otherLines++;
    CrashTrail.instance.recordLasting(line);
  }
}

/// The app's binding is `WidgetsFlutterBinding with OrphanWatch`
/// (`lib/app_binding.dart`); the gate's is the test binding with the same
/// mixin, so what the gate proves is what the app runs.
mixin OrphanWatch on SemanticsBinding {
  final SemanticsShadow _shadow = SemanticsShadow();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      OrphanWatchingBuilder(super.createSemanticsUpdateBuilder(), _shadow);

  @visibleForTesting
  static void resetForTest() {
    OrphanWatchingBuilder.resetCapForTest();
    final current = SemanticsBinding.instance;
    if (current is OrphanWatch) current._shadow.reset();
  }
}
