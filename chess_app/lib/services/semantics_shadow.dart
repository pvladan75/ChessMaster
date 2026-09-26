import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import 'package:chess_app/services/crash_trail.dart';

/// The Windows engine's own rules, in one class: an update the engine refuses
/// leaves its tree broken from then on, and a few updates later — seconds or
/// minutes, whenever the heap gives the page back — it reads freed memory and
/// the app dies (`AccessibilityBridge::SetRoleFromFlutterUpdate`, the crashes
/// of 20–22.9 and 26.9.2026). docs/PLAN-FORENZIKA-PADA.md, phase 2.
///
/// The engine refuses an update for three reasons, and [refusalsOf] says each
/// in the engine's own words (`ax_tree.cc`), so a line of ours can be put
/// beside the engine's stderr and compared id for id:
///
/// 1. `N will not be in the tree and is not the new root` — a node nothing
///    in the resulting tree reaches from node 0. The one seen live
///    (26.9.2026, 22:29:50, three times before the crash); [orphansOf].
/// 2. `Node P has duplicate child id C` — one node lists a child twice.
/// 3. `Node C is not marked for destruction, would be reparented to P` — a
///    node its parent still lists after the update is listed by another
///    parent too, from the tree or from the same update.
///
/// `test/move_tree_semantics_orphan_test.dart` carried a private copy of rule
/// 1 (`_orphansAcross`) before this class existed; it now imports this one.
class SemanticsShadow {
  Map<int, List<int>> _tree = <int, List<int>>{};

  /// Forgets the tree this shadow has kept, so the next update is judged from
  /// nothing — a test's own reset, mirroring [OrphanWatch.resetForTest].
  void reset() => _tree = <int, List<int>>{};

  /// Takes [update] into the kept tree and returns the ids it carried that
  /// nothing in the resulting tree reaches (rule 1).
  List<int> orphansOf(Map<int, List<int>> update) => judge(update).orphans;

  /// Takes [update] into the kept tree and returns every refusal the engine
  /// would print for it, in its words: rules 2 and 3 first, then rule 1.
  List<String> refusalsOf(Map<int, List<int>> update) {
    final verdict = judge(update);
    return [
      ...verdict.others,
      for (final id in verdict.orphans)
        '$id will not be in the tree and is not the new root',
    ];
  }

  /// One step of the engine's model: [update] is judged against the kept
  /// tree, then merged into it, and only what node 0 reaches is kept — the
  /// engine drops what it refused, so a later update cannot reach anything
  /// through it. `others` holds rules 2 and 3 as the engine words them.
  ({List<int> orphans, List<String> others}) judge(
    Map<int, List<int>> update,
  ) {
    final others = <String>[];
    final parentOf = <int, int>{
      for (final entry in _tree.entries)
        for (final child in entry.value) child: entry.key,
    };
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
        final old = parentOf[child];
        if (old == null || old == parent) continue;
        final stillListed =
            (update[old] ?? _tree[old] ?? const <int>[]).contains(child);
        if (stillListed) {
          others.add('Node $child is not marked for destruction, '
              'would be reparented to $parent');
        }
      }
    }

    final merged = <int, List<int>>{..._tree, ...update};
    final reached = <int>{};
    final stack = <int>[0];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      final children = merged[id];
      if (children == null || !reached.add(id)) continue;
      stack.addAll(children);
    }
    final orphans = [
      for (final id in update.keys)
        if (!reached.contains(id)) id,
    ];
    _tree = {
      for (final entry in merged.entries)
        if (reached.contains(entry.key)) entry.key: entry.value,
    };
    return (orphans: orphans, others: others);
  }
}

/// One node's texts, as far as this builder is concerned — enough to name an
/// orphan in the trail without carrying the rest of the update.
class _NodeTexts {
  const _NodeTexts(this.label, this.value, this.tooltip);
  final String label;
  final String value;
  final String? tooltip;

  bool get hasAnyText =>
      label.isNotEmpty || value.isNotEmpty || (tooltip?.isNotEmpty ?? false);
}

/// Forwards every call to a real [ui.SemanticsUpdateBuilder], while keeping
/// enough of what it saw — each node's children and its label, value and
/// tooltip — to ask [SemanticsShadow] whether this update orphans anything.
///
/// An orphan writes one line to [CrashTrail] **before** the real [build]
/// returns the update the engine is about to refuse — a native crash can
/// follow within the same frame, and nothing after this call is guaranteed to
/// run. No test can see that ordering (a write after the real `build()` would
/// still leave the same line on disk by the time anything reads it), so it is
/// asserted here in prose instead: the write happens first because the value
/// it is racing is the process staying alive, not another line of code.
class OrphanWatchingBuilder implements ui.SemanticsUpdateBuilder {
  OrphanWatchingBuilder(this._real, this._shadow);

  final ui.SemanticsUpdateBuilder _real;
  final SemanticsShadow _shadow;

  final Map<int, List<int>> _children = <int, List<int>>{};
  final Map<int, _NodeTexts> _texts = <int, _NodeTexts>{};

  static const int _cap = 5;
  static int _linesWritten = 0;

  /// Resets the cap counter this class shares across every instance in the
  /// process. `OrphanWatch.resetForTest` calls this.
  @visibleForTesting
  static void resetCapForTest() => _linesWritten = 0;

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
    _texts[id] = _NodeTexts(label, value, tooltip);
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
      var chosen = _texts[orphans.first];
      for (final id in orphans) {
        final texts = _texts[id];
        if (texts != null && texts.hasAnyText) {
          chosen = texts;
          break;
        }
      }
      final label = chosen?.label ?? '';
      final value = chosen?.value ?? '';
      final tooltip = chosen?.tooltip ?? '';
      _say('semantics orphan $orphans "$label" "$value" "$tooltip"');
    }
    for (final refusal in verdict.others) {
      _say('semantics refused $refusal');
    }
    return _real.build();
  }

  /// Into the trail and into `crash.log`, which is not a ring: the crash may
  /// come seconds or minutes after the refusal (docs/PLAN-FORENZIKA-PADA.md).
  static void _say(String line) {
    if (_linesWritten >= _cap) return;
    _linesWritten++;
    CrashTrail.instance.recordLasting(line);
  }
}

/// Overrides [SemanticsBinding.createSemanticsUpdateBuilder] so every
/// semantics update the app sends goes through [OrphanWatchingBuilder]. Costs
/// nothing while no client has semantics on: the builder is created only
/// when the owner asks for one.
mixin OrphanWatch on SemanticsBinding {
  final SemanticsShadow _shadow = SemanticsShadow();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      OrphanWatchingBuilder(super.createSemanticsUpdateBuilder(), _shadow);

  /// Resets the cap counter and the shadow this binding holds, so a test
  /// starts the next case with neither.
  @visibleForTesting
  static void resetForTest() {
    OrphanWatchingBuilder.resetCapForTest();
    final current = SemanticsBinding.instance;
    if (current is OrphanWatch) current._shadow.reset();
  }
}
