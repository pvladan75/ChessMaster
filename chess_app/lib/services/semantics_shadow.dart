import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import 'package:chess_app/services/crash_trail.dart';

/// The Windows engine's accessibility tree, shadowed in the app — phases 2 and
/// 2b of `docs/PLAN-FORENZIKA-PADA.md`.
///
/// The engine (`shell/platform/common/accessibility_bridge.cc`) builds a
/// `ui::AXTree` from what the framework sends, and refuses an update the tree
/// cannot take. Once refused, the bridge keeps pointers into the update it has
/// already freed, and a later commit reads them: the crashes of 20–22.9.2026
/// and of 26.9.2026, all in `SetRoleFromFlutterUpdate`. The engine says why
/// only on stderr, which an installed app has nowhere to send, and it names a
/// node by an id nothing maps back to a widget afterwards.
///
/// **The engine commits in two steps**, and the model follows both:
///
/// 1. `CreateRemoveReparentedNodesUpdate`: a tree cannot move a node in one
///    update, so every child that a node in the update lists while the tree
///    still holds it under another parent is first taken **off its old
///    parent**, and its subtree destroyed. That step is an update of the old
///    parents alone, and it is refused when one of those old parents is
///    itself inside a subtree the same step detaches — removing the outer
///    subtree throws away the inner old parent, and `ui::AXTree` answers
///    „N will not be in the tree and is not the new root" for it. That is the
///    refusal at line 65 of the bridge, the one the owner's stream showed on
///    26.9.2026 (nodes 13051 and 27377: leaving the room, whose subtree moved
///    under the root while two hundred Library rows inside it each lost a
///    child).
/// 2. The update itself: a node the update carries that nothing in the
///    resulting tree reaches is refused with the same words; a node listing
///    the same child twice, and a child claimed by two parents within one
///    update, are refused with the tree's other two messages. And a moved
///    subtree, destroyed in step 1, has to be **recreated from the update** —
///    which the framework does not fill: a reparented node is re-attached,
///    not re-sent, and its unchanged descendants are not sent either
///    (measured 26.9.2026 with a spy in front of the builder).
///
/// **Phase 2b — the engine never sees what it would refuse.** The builder the
/// app hands the framework ([OrphanWatchingBuilder]) keeps every node's last
/// full data ([NodeArgs]) and, on `build()`, asks the shadow for a [Plan]:
///
/// - inner moves — a child leaving an old parent that sits inside another
///   moving subtree — go into a **first commit of their own**, sent to the
///   view before the update returns: the old parents alone, with those
///   children dropped and nothing new, which the tree takes while the outer
///   subtree still stands;
/// - every moved subtree, and every child a node lists that the tree does not
///   hold, is **supplied whole from the cache** in the second commit;
/// - a node nothing reaches is **held back**, and sent from the cache the day
///   a parent lists it.
///
/// What the raw update would have been refused for is still written to the
/// trail and `crash.log`, marked as held back, so a live run can be compared
/// with the engine's own stream. Where the cache cannot supply a node the
/// builder sends the framework's update untouched and says so: never worse
/// than before.
class SemanticsShadow {
  /// id → children in traversal order, of every node the engine's tree holds.
  Map<int, List<int>> _tree = <int, List<int>>{};

  /// The last full data each node was sent with. Kept here rather than in the
  /// builder because a step-1 orphan is an **old** parent, sent in some
  /// earlier update, and because a moved or held-back node is re-sent from
  /// here.
  final Map<int, NodeArgs> _args = <int, NodeArgs>{};

  /// Nodes held back, with the update count at which they were held. A held
  /// node is adopted within a frame or two (the September shapes) or never;
  /// after [heldFor] updates its data goes.
  final Map<int, int> _held = <int, int>{};
  int _updates = 0;
  static const int heldFor = 60;

  void reset() {
    _tree = <int, List<int>>{};
    _args.clear();
    _held.clear();
    _updates = 0;
  }

  void remember(int id, NodeArgs args) => _args[id] = args;

  NodeTexts? textsOf(int id) {
    final a = _args[id];
    return a == null ? null : NodeTexts(a.label, a.value, a.tooltip);
  }

  @visibleForTesting
  Map<int, List<int>> get tree => Map.unmodifiable(_tree);

  @visibleForTesting
  Set<int> get heldIds => _held.keys.toSet();

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
  /// held it. With [dryRun] the tree is left as it was.
  Verdict judge(Map<int, List<int>> update, {bool dryRun = false}) {
    final before = dryRun ? Map<int, List<int>>.of(_tree) : null;
    final verdict = _judge(update);
    if (before != null) _tree = before;
    return verdict;
  }

  Verdict _judge(Map<int, List<int>> update) {
    final parentOf = _parents(_tree);

    // Step 1 — take reparented children off their old parents.
    final removed = <int, List<int>>{};
    final moved = _moves(update, parentOf);
    for (final m in moved.entries) {
      (removed[m.value.from] ??=
              List<int>.of(_tree[m.value.from] ?? const <int>[]))
          .remove(m.key);
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
          final holder = _movingHolder(id, parentOf, moved);
          why[id] = 'lost $left'
              '${holder == null ? '' : ', inside $holder moving to ${moved[holder]!.to}'}';
        }
        // The bridge returns here without touching its tree or clearing its
        // pending list; nothing is kept from this update.
        return Verdict(
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
    return Verdict(
      orphans: orphans,
      others: others,
      step: 'update',
      why: const <int, String>{},
    );
  }

  /// Phase 2b: what to send the engine instead of [update], so that it
  /// refuses nothing. Leaves the tree as it was; [commit] applies a plan.
  ///
  /// The draft is **verified against the model the engine is held to**
  /// ([judge], on a copy) before it is called a plan. On 27.9.2026 at 00:29
  /// a draft was sent while that model refused it, and the engine refused
  /// it in the same words (nodes 104 and 37 on Home); a draft the model
  /// refuses is never sent now ([Plan.verified]) — the framework's update
  /// goes as it came and the whole of it is kept aside for replay. What made
  /// that draft wrong was the first commit carrying old parents inside
  /// subtrees the same commit dropped; found by fuzzing, fixed in [_draft],
  /// and on 4000 random trees the draft has settled every time since, so
  /// nothing reshapes it here — a draft the model refuses is a shape to
  /// learn from, not to patch blind.
  Plan plan(Map<int, List<int>> update) {
    final candidate = _draft(update);
    final copy = clone();
    if (candidate.part1.isNotEmpty) {
      final first = copy.judge(candidate.part1);
      final refused = _words(first);
      if (refused != null) return candidate.unsettled('first commit: $refused');
    }
    final second = copy.judge(candidate.part2);
    final refused = _words(second);
    if (refused != null) return candidate.unsettled('second commit: $refused');
    return candidate.settled();
  }

  static String? _words(Verdict v) {
    if (v.orphans.isEmpty && v.others.isEmpty) return null;
    return [
      ...v.others,
      for (final id in v.orphans)
        '$id will not be in the tree and is not the new root',
    ].join('; ');
  }

  Plan _draft(Map<int, List<int>> update) {
    final parentOf = _parents(_tree);
    final moved = _moves(update, parentOf);

    // Inner moves: the old parent stands inside another moving subtree (or
    // is one). Their removal is the engine's step 1 on this update, and it
    // would throw the old parent away with the outer subtree — so they get a
    // commit of their own, first, while everything still stands.
    final inner = <int>{
      for (final m in moved.entries)
        if (_movingHolder(m.value.from, parentOf, moved, excluding: m.key) !=
            null)
          m.key,
    };
    final part1 = <int, List<int>>{};
    for (final c in inner) {
      final q = moved[c]!.from;
      (part1[q] ??= List<int>.of(_tree[q] ?? const <int>[])).remove(c);
    }
    // An old parent inside a subtree another entry of the first commit
    // drops needs no drop of its own — the outer drop takes its subtree, and
    // the tree would refuse it as gone.
    part1.removeWhere((q, _) {
      var below = q;
      for (var at = parentOf[q]; at != null; at = parentOf[at]) {
        final dropped = part1[at];
        if (dropped != null && !dropped.contains(below)) return true;
        below = at;
      }
      return false;
    });
    // The tree after that first commit: the dropped children's subtrees are
    // gone.
    var tree1 = <int, List<int>>{..._tree, ...part1};
    if (part1.isNotEmpty) {
      final reached1 = _reachable(tree1);
      tree1 = {
        for (final e in tree1.entries)
          if (reached1.contains(e.key)) e.key: e.value,
      };
    }
    // The engine's own step 1 on the second commit: the remaining moves,
    // whose old parents are outside every moving subtree.
    final parentOf1 = _parents(tree1);
    var tree2 = Map<int, List<int>>.of(tree1);
    for (final m in moved.entries) {
      if (inner.contains(m.key)) continue;
      final from = parentOf1[m.key];
      if (from == null || from == m.value.to) continue;
      tree2[from] = List<int>.of(tree2[from]!)..remove(m.key);
    }
    final reached2 = _reachable(tree2);
    tree2 = {
      for (final e in tree2.entries)
        if (reached2.contains(e.key)) e.key: e.value,
    };

    // The second commit: the update, plus every subtree the tree will not
    // hold when it arrives — a moved one (destroyed in step 1), a held-back
    // one now listed, a child never sent — from the cache. First the two
    // things the tree refuses outright and the app can repair: a child listed
    // twice is listed once, and a child two parents claim in one commit
    // stays with the one that is not its old parent (the framework's newer
    // word), or with the first to list it.
    final part2 = <int, List<int>>{
      for (final e in update.entries) e.key: e.value.toSet().toList(),
    };
    final claimants = <int, List<int>>{};
    for (final e in part2.entries) {
      for (final c in e.value) {
        (claimants[c] ??= <int>[]).add(e.key);
      }
    }
    for (final e in claimants.entries) {
      if (e.value.length < 2) continue;
      final old = moved[e.key]?.from;
      final keep =
          e.value.firstWhere((p) => p != old, orElse: () => e.value.first);
      for (final p in e.value) {
        if (p != keep) part2[p] = List<int>.of(part2[p]!)..remove(e.key);
      }
    }
    final supplied = <int>[];
    final failed = <int>[];
    final work = <int>[...update.keys];
    final seen = <int>{};
    while (work.isNotEmpty) {
      final id = work.removeLast();
      if (!seen.add(id)) continue;
      for (final child in part2[id] ?? const <int>[]) {
        if (part2.containsKey(child)) {
          work.add(child);
          continue;
        }
        if (tree2.containsKey(child)) continue;
        final cached = _args[child];
        if (cached == null) {
          failed.add(child);
          continue;
        }
        part2[child] = cached.children;
        supplied.add(child);
        work.add(child);
      }
    }
    // Held back: what nothing in the resulting tree reaches.
    final merged = <int, List<int>>{...tree2, ...part2};
    final reached = _reachable(merged);
    final held = [
      for (final id in part2.keys)
        if (!reached.contains(id)) id,
    ];
    for (final id in held) {
      part2.remove(id);
      supplied.remove(id);
    }
    return Plan(
      part1: part1,
      part2: part2,
      held: held,
      supplied: supplied,
      failed: failed,
      moved: moved.keys.toList(),
      movedFrom: {for (final m in moved.entries) m.key: m.value.from},
    );
  }

  /// A copy with the same tree and cache, for judging a plan without
  /// touching this one.
  SemanticsShadow clone() {
    final copy = SemanticsShadow();
    copy._tree = {
      for (final e in _tree.entries) e.key: List<int>.of(e.value),
    };
    copy._args.addAll(_args);
    return copy;
  }

  /// Applies a plan the way the engine will take it, both commits in order,
  /// and keeps the cache to what the tree and the held-back nodes need.
  /// Returns what the engine would still refuse — nothing, if the plan is
  /// right.
  List<String> commit(Plan plan) {
    _updates++;
    final refusals = <String>[
      if (plan.part1.isNotEmpty) ...refusalsOf(plan.part1),
      ...refusalsOf(plan.part2),
    ];
    for (final id in plan.held) {
      _held[id] = _updates;
    }
    _held.removeWhere(
      (id, at) => _tree.containsKey(id) || _updates - at > heldFor,
    );
    _args.removeWhere(
      (id, _) => !_tree.containsKey(id) && !_held.containsKey(id),
    );
    return refusals;
  }

  Map<int, ({int from, int to})> _moves(
    Map<int, List<int>> update,
    Map<int, int> parentOf,
  ) {
    final moved = <int, ({int from, int to})>{};
    for (final entry in update.entries) {
      for (final child in entry.value) {
        final old = parentOf[child];
        if (old == null || old == entry.key) continue;
        moved[child] = (from: old, to: entry.key);
      }
    }
    return moved;
  }

  /// The moving subtree that holds [id] in the old tree: the first node on
  /// the way up (itself included) that is on the move.
  int? _movingHolder(
    int id,
    Map<int, int> parentOf,
    Map<int, ({int from, int to})> moved, {
    int? excluding,
  }) {
    for (int? at = id; at != null; at = parentOf[at]) {
      if (at != excluding && moved.containsKey(at)) return at;
    }
    return null;
  }

  static Map<int, int> _parents(Map<int, List<int>> tree) => {
        for (final entry in tree.entries)
          for (final child in entry.value) child: entry.key,
      };

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

/// What the engine would refuse an update for.
class Verdict {
  const Verdict({
    required this.orphans,
    required this.others,
    required this.step,
    required this.why,
  });
  final List<int> orphans;
  final List<String> others;
  final String step;
  final Map<int, String> why;
}

/// What to send instead: [part1] first (old parents alone, children dropped),
/// then [part2] (the update with every needed subtree supplied and every
/// unreachable node held back). [failed] names children the cache could not
/// supply; a plan with any is not usable.
class Plan {
  const Plan({
    required this.part1,
    required this.part2,
    required this.held,
    required this.supplied,
    required this.failed,
    required this.moved,
    required this.movedFrom,
    this.verified = false,
    this.refusal,
  });
  final Map<int, List<int>> part1;
  final Map<int, List<int>> part2;
  final List<int> held;
  final List<int> supplied;
  final List<int> failed;
  final List<int> moved;

  /// Every moved child → the parent the tree held it under.
  final Map<int, int> movedFrom;

  /// The model of the engine took both commits. A plan that is not verified
  /// is never sent; the framework's update goes as it came instead.
  final bool verified;

  /// What the model still refused, when [verified] is false.
  final String? refusal;

  bool get changesAnything =>
      part1.isNotEmpty || held.isNotEmpty || supplied.isNotEmpty;

  Plan settled() => Plan(
        part1: part1,
        part2: part2,
        held: held,
        supplied: supplied,
        failed: failed,
        moved: moved,
        movedFrom: movedFrom,
        verified: true,
      );

  Plan unsettled(String refusal) => Plan(
        part1: part1,
        part2: part2,
        held: held,
        supplied: supplied,
        failed: failed,
        moved: moved,
        movedFrom: movedFrom,
        verified: false,
        refusal: refusal,
      );
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

/// Everything one `updateNode` call carries, kept so a node can be sent
/// again from the app's side.
class NodeArgs {
  const NodeArgs({
    required this.id,
    required this.flags,
    required this.actions,
    required this.maxValueLength,
    required this.currentValueLength,
    required this.textSelectionBase,
    required this.textSelectionExtent,
    required this.platformViewId,
    required this.scrollChildren,
    required this.scrollIndex,
    required this.traversalParent,
    required this.scrollPosition,
    required this.scrollExtentMax,
    required this.scrollExtentMin,
    required this.rect,
    required this.identifier,
    required this.label,
    required this.labelAttributes,
    required this.value,
    required this.valueAttributes,
    required this.increasedValue,
    required this.increasedValueAttributes,
    required this.decreasedValue,
    required this.decreasedValueAttributes,
    required this.hint,
    required this.hintAttributes,
    required this.tooltip,
    required this.textDirection,
    required this.transform,
    required this.hitTestTransform,
    required this.children,
    required this.childrenInHitTestOrder,
    required this.additionalActions,
    required this.headingLevel,
    required this.linkUrl,
    required this.role,
    required this.controlsNodes,
    required this.validationResult,
    required this.hitTestBehavior,
    required this.inputType,
    required this.locale,
    required this.minValue,
    required this.maxValue,
  });

  final int id;
  final SemanticsFlags flags;
  final int actions;
  final int maxValueLength;
  final int currentValueLength;
  final int textSelectionBase;
  final int textSelectionExtent;
  final int platformViewId;
  final int scrollChildren;
  final int scrollIndex;
  final int? traversalParent;
  final double scrollPosition;
  final double scrollExtentMax;
  final double scrollExtentMin;
  final Rect rect;
  final String identifier;
  final String label;
  final List<StringAttribute>? labelAttributes;
  final String value;
  final List<StringAttribute>? valueAttributes;
  final String increasedValue;
  final List<StringAttribute>? increasedValueAttributes;
  final String decreasedValue;
  final List<StringAttribute>? decreasedValueAttributes;
  final String hint;
  final List<StringAttribute>? hintAttributes;
  final String? tooltip;
  final TextDirection? textDirection;
  final Float64List transform;
  final Float64List hitTestTransform;
  final List<int> children;
  final List<int> childrenInHitTestOrder;
  final Int32List additionalActions;
  final int headingLevel;
  final String? linkUrl;
  final SemanticsRole role;
  final List<String>? controlsNodes;
  final SemanticsValidationResult validationResult;
  final ui.SemanticsHitTestBehavior hitTestBehavior;
  final ui.SemanticsInputType inputType;
  final ui.Locale? locale;
  final String minValue;
  final String maxValue;

  /// Sends this node into [b], with [childrenOverride] in place of its own
  /// children when a commit needs some of them dropped.
  void replayInto(ui.SemanticsUpdateBuilder b, {List<int>? childrenOverride}) {
    final kids = childrenOverride ?? children;
    final hit = childrenOverride == null
        ? childrenInHitTestOrder
        : [
            for (final c in childrenInHitTestOrder)
              if (kids.contains(c)) c,
          ];
    b.updateNode(
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
      childrenInTraversalOrder: Int32List.fromList(kids),
      childrenInHitTestOrder: Int32List.fromList(hit),
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
}

/// A custom action, kept until the commit it belongs to is built.
class _CustomAction {
  const _CustomAction(this.id, this.label, this.hint, this.overrideId);
  final int id;
  final String? label;
  final String? hint;
  final int overrideId;
}

/// The builder the app hands the framework: records everything, and on
/// `build()` sends the engine what the shadow planned instead.
class OrphanWatchingBuilder implements ui.SemanticsUpdateBuilder {
  OrphanWatchingBuilder(
    this._newReal,
    this._shadow, {
    required this.sendEarly,
  });

  /// Makes a real builder — one for each commit.
  final ui.SemanticsUpdateBuilder Function() _newReal;
  final SemanticsShadow _shadow;

  /// Hands the first commit to the view, before the second is returned.
  final void Function(ui.SemanticsUpdate update) sendEarly;

  final Map<int, List<int>> _children = <int, List<int>>{};
  final List<_CustomAction> _actions = <_CustomAction>[];

  /// Two caps, one a kind, so that no line of one kind can silence the other:
  /// on 26.9.2026 five lines of a rule that was wrong spent a single cap of
  /// five before the refusal the engine actually made.
  static const int orphanCap = 20;
  static const int otherCap = 10;
  static int _orphanLines = 0;
  static int _otherLines = 0;

  /// The last plan built, and every id ever held back, for the gate.
  static Plan? lastPlan;
  static final List<int> heldEver = <int>[];

  @visibleForTesting
  static void resetCapForTest() {
    _orphanLines = 0;
    _otherLines = 0;
    lastPlan = null;
    heldEver.clear();
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
    final kids = childrenInTraversalOrder.toList();
    _children[id] = kids;
    _shadow.remember(
      id,
      NodeArgs(
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
        traversalParent: traversalParent,
        scrollPosition: scrollPosition,
        scrollExtentMax: scrollExtentMax,
        scrollExtentMin: scrollExtentMin,
        rect: rect,
        identifier: identifier,
        label: label,
        labelAttributes: labelAttributes,
        value: value,
        valueAttributes: valueAttributes,
        increasedValue: increasedValue,
        increasedValueAttributes: increasedValueAttributes,
        decreasedValue: decreasedValue,
        decreasedValueAttributes: decreasedValueAttributes,
        hint: hint,
        hintAttributes: hintAttributes,
        tooltip: tooltip,
        textDirection: textDirection,
        transform: transform,
        hitTestTransform: hitTestTransform,
        children: kids,
        childrenInHitTestOrder: childrenInHitTestOrder.toList(),
        additionalActions: additionalActions,
        headingLevel: headingLevel,
        linkUrl: linkUrl,
        role: role,
        controlsNodes: controlsNodes,
        validationResult: validationResult,
        hitTestBehavior: hitTestBehavior,
        inputType: inputType,
        locale: locale,
        minValue: minValue,
        maxValue: maxValue,
      ),
    );
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) =>
      _actions.add(_CustomAction(id, label, hint, overrideId));

  @override
  ui.SemanticsUpdate build() {
    // What the engine would have refused, said first — that is the trail's
    // job, whatever happens next.
    final raw = _shadow.judge(_children, dryRun: true);
    _sayRaw(raw);

    final plan = _shadow.plan(_children);
    lastPlan = plan;
    heldEver.addAll(plan.held);
    if (plan.failed.isNotEmpty || !plan.verified) {
      // Never worse than before: the framework's own update, untouched — and
      // the whole of it kept aside, so the shape that could not be settled
      // can be replayed.
      _sayOther(plan.failed.isNotEmpty
          ? 'semantics hold-back failed, cache lacks ${plan.failed}; '
              'the update goes as it came'
          : 'semantics hold-back could not settle: ${plan.refusal}; '
              'the update goes as it came');
      _keepAside(plan);
      _shadow.judge(_children);
      return _replay(_children, actions: _actions);
    }
    if (plan.part1.isNotEmpty) {
      sendEarly(_replay(plan.part1));
    }
    final update = _replay(plan.part2, actions: _actions);
    final still = _shadow.commit(plan);
    if (still.isNotEmpty) {
      _sayOther('semantics hold-back left a refusal: ${still.join('; ')}');
    }
    return update;
  }

  static int _asides = 0;

  /// The tree, the update and the plan, as JSON beside the log.
  void _keepAside(Plan plan) {
    if (_asides >= 3) return;
    _asides++;
    String keys(Map<int, List<int>> m) => jsonEncode({
          for (final e in m.entries) '${e.key}': e.value,
        });
    CrashTrail.instance.recordAside(
      'unsettled-${DateTime.now().toUtc().millisecondsSinceEpoch}.json',
      '{"tree": ${keys(_shadow._tree)}, "update": ${keys(_children)}, '
          '"part1": ${keys(plan.part1)}, "part2": ${keys(plan.part2)}, '
          '"held": ${jsonEncode(plan.held)}, "failed": ${jsonEncode(plan.failed)}, '
          '"refusal": ${jsonEncode(plan.refusal)}}\n',
    );
  }

  ui.SemanticsUpdate _replay(
    Map<int, List<int>> nodes, {
    List<_CustomAction> actions = const [],
  }) {
    final b = _newReal();
    for (final entry in nodes.entries) {
      final args = _shadow._args[entry.key];
      if (args == null) continue;
      args.replayInto(b, childrenOverride: entry.value);
    }
    for (final a in actions) {
      b.updateCustomAction(
        id: a.id,
        label: a.label,
        hint: a.hint,
        overrideId: a.overrideId,
      );
    }
    return b.build();
  }

  void _sayRaw(Verdict verdict) {
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
          '${why.isEmpty ? '' : ': $why'} — held back');
    }
    for (final refusal in verdict.others) {
      _sayOther('semantics refused $refusal');
    }
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
      OrphanWatchingBuilder(
        () => super.createSemanticsUpdateBuilder(),
        _shadow,
        // The same view the framework hands its own update to
        // (`RenderView.updateSemantics`): the app has one.
        sendEarly: (update) => ui.PlatformDispatcher.instance.implicitView
            ?.updateSemantics(update),
      );

  @visibleForTesting
  static void resetForTest() {
    OrphanWatchingBuilder.resetCapForTest();
    final current = SemanticsBinding.instance;
    if (current is OrphanWatch) current._shadow.reset();
  }
}
