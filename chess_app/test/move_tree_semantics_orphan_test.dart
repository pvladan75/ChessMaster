// The Windows engine builds its accessibility tree from each node's
// `childrenInTraversalOrder` and refuses an update that carries a node no
// parent in the resulting tree lists ("N will not be in the tree and is not the
// new root"). Once refused, the tree stays broken and every later update is
// refused too; refused at the reparenting step, the bridge keeps pointers into
// a freed update and the next one reads them. That was the crash of
// 20–22.9.2026, in `AccessibilityBridge::SetRoleFromFlutterUpdate`, with any
// UI Automation client attached (Narrator, the touch keyboard).
//
// The live spy named the node: the popup of the variation tree's "Playback
// speed" button, a `Tooltip` inside a `PopupMenuButton` that has a tooltip of
// its own. Flutter 3.47 grafts one popup under the button and leaves the
// other under the overlay, where no traversal list names it (upstream:
// flutter/flutter#182444, #187198, PR #190431).
//
// So this file records what the framework actually sends and applies the
// engine's rule to it. The binding is replaced for the whole file.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/app_slider.dart';
import 'package:chess_app/widgets/board_view_menu.dart';

class _SpyBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _Spy();
}

/// One update: id -> childrenInTraversalOrder.
final List<Map<int, List<int>>> _updates = [];

class _Spy extends Fake implements ui.SemanticsUpdateBuilder {
  final ui.SemanticsUpdateBuilder _real = ui.SemanticsUpdateBuilder();
  final Map<int, List<int>> _nodes = {};

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
    _nodes[id] = childrenInTraversalOrder.toList();
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
    _updates.add(Map.of(_nodes));
    return _real.build();
  }
}

/// The engine's view of the tree, fed update by update. Returns, per update
/// that broke the rule, the ids it carried that nothing in the resulting tree
/// leads to.
List<String> _orphansAcross(List<Map<int, List<int>>> updates) {
  var tree = <int, List<int>>{};
  final problems = <String>[];
  for (var i = 0; i < updates.length; i++) {
    final merged = {...tree, ...updates[i]};
    final reached = <int>{};
    final stack = [0];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!merged.containsKey(id) || !reached.add(id)) continue;
      stack.addAll(merged[id]!);
    }
    final orphans = updates[i].keys.where((id) => !reached.contains(id));
    if (orphans.isNotEmpty) {
      problems.add('update $i: ${orphans.toList()}');
    }
    tree = {
      for (final e in merged.entries)
        if (reached.contains(e.key)) e.key: e.value,
    };
  }
  return problems;
}

/// The tree as it stands now, read off the owner, so the engine's model can
/// start from it rather than from the first recorded update.
Map<int, List<int>> _seed(WidgetTester tester) {
  final out = <int, List<int>>{};
  void walk(SemanticsNode n) {
    final kids = n.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    );
    out[n.id] = [for (final k in kids) k.id];
    kids.forEach(walk);
  }

  walk(tester
      .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
  return out;
}

/// Hovers [target] with a mouse until its tooltip [message] shows, and returns
/// what the engine would have refused along the way.
Future<List<String>> _hoverUntilShown(
  WidgetTester tester,
  Finder target,
  String message,
) async {
  final seed = _seed(tester);
  _updates.clear();
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  expect(find.text(message), findsWidgets, reason: 'the tooltip is showing');
  return _orphansAcross([seed, ..._updates]);
}

/// Hovers every tooltip on the screen in turn, and returns the message of each
/// whose showing the engine would have refused.
Future<List<String>> _hoverEveryTooltip(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  final view = tester.view.physicalSize / tester.view.devicePixelRatio;
  final bad = <String>[];
  var hovered = 0;
  final targets = [
    for (final e in find.byType(Tooltip).evaluate())
      if (e.renderObject is RenderBox &&
          (e.renderObject! as RenderBox).hasSize &&
          (e.renderObject! as RenderBox).attached)
        (
          (e.widget as Tooltip).message ?? '?',
          (e.renderObject! as RenderBox).localToGlobal(
            (e.renderObject! as RenderBox).size.center(Offset.zero),
          ),
        ),
  ];
  for (final (message, at) in targets) {
    if (!(Offset.zero & view).contains(at)) continue;
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    final seed = _seed(tester);
    _updates.clear();
    await mouse.moveTo(at);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    if (_orphansAcross([seed, ..._updates]).isNotEmpty) bad.add(message);
    hovered++;
  }
  // A sweep that hovered nothing is green on any screen.
  expect(hovered, greaterThan(0), reason: 'the sweep reached a tooltip');
  return bad;
}

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  _SpyBinding();

  test('the rule itself catches an orphan', () {
    expect(
      _orphansAcross([
        {
          0: [1],
          1: [],
        },
        // 2 arrives, but 1 still lists nothing.
        {1: [], 2: []},
      ]),
      ['update 1: [2]'],
    );
    expect(
      _orphansAcross([
        {
          0: [1],
          1: [],
        },
        {
          1: [2],
          2: [],
        },
      ]),
      isEmpty,
    );
  });

  testWidgets('one tooltip on a button is grafted under it', (tester) async {
    // The control for the case below: the rule does not flag every tooltip.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: IconButton(
              tooltip: 'Flip board',
              icon: const Icon(Icons.flip),
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      await _hoverUntilShown(tester, find.byType(IconButton), 'Flip board'),
      isEmpty,
    );
    handle.dispose();
  });

  testWidgets('Flutter still orphans a tooltip nested in another', (
    tester,
  ) async {
    // This is Flutter's fault, not the app's, and it is why the app must not
    // nest them. The day this fails, upstream has fixed it — say so in
    // docs/LESSONS.md and delete this case.
    final handle = tester.ensureSemantics();
    const message = 'Playback speed: Normal';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PopupMenuButton<int>(
              tooltip: message,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 1, child: Text('x')),
              ],
              child: const Tooltip(
                message: message,
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.speed, size: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      await _hoverUntilShown(tester, find.byIcon(Icons.speed), message),
      isNotEmpty,
    );
    handle.dispose();
  });

  testWidgets('hovering the tree\'s playback speed orphans nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    final root = AnalysisNode(id: 'root', fen: _start);
    root.addChild(childFen: '$_start 2', san: 'e4', uci: 'e2e4');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VisualMoveTreeWidget(
            rootNode: root,
            activeNode: root,
            onSelectNode: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      await _hoverUntilShown(
        tester,
        find.byIcon(Icons.speed),
        'Playback speed: Normal',
      ),
      isEmpty,
    );
    handle.dispose();
  });

  testWidgets('no tooltip on the Analysis screen sits inside another', (
    tester,
  ) async {
    // Every panel at its default, so every button the screen can draw is on it.
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppColorTokens.dark],
        ),
        home: AnalysisStudioScreen(
          userSession: UserSession(
            token: 't',
            id: 1,
            email: 'a@b.c',
            name: 'N',
            role: 'korisnik',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(Tooltip),
      findsAtLeastNWidgets(20),
      reason: 'the screen and its tooltips were built',
    );
    final nested = find.descendant(
      of: find.byType(Tooltip),
      matching: find.byType(Tooltip),
    );
    expect(
      [for (final e in nested.evaluate()) (e.widget as Tooltip).message],
      isEmpty,
    );
  });

  testWidgets('no tooltip in Preparation orphans a node when it shows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    final client = MockClient((_) async => http.Response('[]', 200));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppColorTokens.dark],
        ),
        home: ChessGamePage(
          userSession: UserSession(
            id: 1,
            token: 'tok',
            email: 'e',
            name: 'N',
            role: 'x',
          ),
          roomCode: 'STUDIO',
          initialRole: 'trener',
          lessonApi: LessonApiService(authToken: 'tok', client: client),
          positionLibrary: PositionLibraryService(
            authToken: 'tok',
            client: client,
          ),
          groupApi: GroupApiService(client: client),
          lessonRecordingApi: LessonRecordingApi(
            authToken: 'tok',
            client: client,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byType(Tooltip),
      findsAtLeastNWidgets(5),
      reason: 'the room and its tooltips were built',
    );
    expect(await _hoverEveryTooltip(tester), isEmpty);
    handle.dispose();
  });

  testWidgets('no tooltip on Analysis orphans a node when it shows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    tester.view.physicalSize = const Size(1280, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppColorTokens.dark],
        ),
        home: AnalysisStudioScreen(
          userSession: UserSession(
            token: 't',
            id: 1,
            email: 'a@b.c',
            name: 'N',
            role: 'korisnik',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(await _hoverEveryTooltip(tester), isEmpty);
    handle.dispose();
  });

  // The second source the live spy caught, in Preparation: opening „Board
  // view", whose menu holds the board-size `Slider`. A slider in a pushed
  // route leaves an empty node under the overlay (flutter/flutter#190357).
  for (final boardSize in [false, true]) {
    testWidgets('opening Board view (boardSize: $boardSize) orphans nothing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsService.instance.init();
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [BoardViewMenu(boardSize: boardSize)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final seed = _seed(tester);
      _updates.clear();

      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();
      expect(find.text('Coordinates'), findsOneWidget, reason: 'menu is open');
      expect(
        find.byType(AppSlider),
        boardSize ? findsOneWidget : findsNothing,
      );

      expect(_orphansAcross([seed, ..._updates]), isEmpty);
      handle.dispose();
    });
  }

  // Every way the app shows a slider after the first screen. Flutter's own
  // slider orphans a node in each (measured 22.9.2026); AppSlider must not.
  final ways = <String, Future<void> Function(BuildContext, Widget)>{
    'dialog': (c, w) => showDialog<void>(
          context: c,
          builder: (_) => Dialog(child: SizedBox(width: 300, child: w)),
        ),
    'bottom sheet': (c, w) => showModalBottomSheet<void>(
          context: c,
          builder: (_) => SizedBox(height: 200, child: w),
        ),
    'pushed screen': (c, w) => Navigator.of(c).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Center(child: w)),
          ),
        ),
  };

  Future<List<String>> openWith(
      WidgetTester tester, String way, Widget w) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => ways[way]!(c, w),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final seed = _seed(tester);
    _updates.clear();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byWidget(w), findsOneWidget, reason: 'the slider is showing');
    return _orphansAcross([seed, ..._updates]);
  }

  for (final way in ways.keys) {
    testWidgets('AppSlider in a $way orphans nothing', (tester) async {
      final handle = tester.ensureSemantics();
      final slider = AppSlider(value: 0.5, divisions: 4, onChanged: (_) {});
      expect(await openWith(tester, way, slider), isEmpty);
      handle.dispose();
    });
  }

  testWidgets('Flutter still orphans its own Slider in a dialog', (
    tester,
  ) async {
    // Why AppSlider exists. The day this fails, flutter/flutter#190357 is
    // fixed upstream — say so in docs/LESSONS.md and delete this case.
    final handle = tester.ensureSemantics();
    final slider = Slider(value: 0.5, onChanged: (_) {});
    expect(await openWith(tester, 'dialog', slider), isNotEmpty);
    handle.dispose();
  });
}
