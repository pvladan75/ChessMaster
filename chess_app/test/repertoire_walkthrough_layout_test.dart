// The gate of phase 6 of docs/PLAN-EKRANI.md: the repertoire tour as the
// owner chose from `docs/skice/ekrani/compare_walk.png` — on a window the card
// (what the tour says, its reply chips) stands at the top of the right column
// with the tree under it, instead of under the board, where at 1536 x 792 it
// ran off the window and its chips were not on screen at all (§2.3). The phone
// is unchanged: the card under the board.
//
// The app's own theme with real Roboto, as phase 1 taught.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_walkthrough_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/speakable_info.dart';

import 'repertoire_walkthrough_screen_test.dart' show buildTestTree;
import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _small = Size(900, 700);
const _phone = Size(360, 640);

class _Api extends RepertoireApiService {
  _Api() : super(client: MockClient((_) async => http.Response('{}', 500)));

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
    String? breadth,
    int? maxPly,
    List<String> alongPath = const [],
  }) async =>
      buildTestTree();

  @override
  Future<Map<String, RepertoireComment>> comments(
          {required String color}) async =>
      const {};
}

Future<void> _pump(WidgetTester tester, Size size) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: RepertoireWalkthroughScreen(
      key: UniqueKey(),
      name: 'White: 1.e4 for club players',
      color: 'w',
      rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      api: _Api(),
    ),
  ));
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, Finder f) {
  expect(f, findsOneWidget);
  return tester.getRect(f);
}

Rect _rectOf(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Seen: inside the window and inside every box that scrolls it.
void _expectSeen(WidgetTester tester, Size size, Finder finder) {
  expectOnScreen(tester, size, finder);
  for (final element in finder.evaluate()) {
    final rect = _rectOf(element);
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Scrollable) {
        final box = _rectOf(ancestor);
        expect(
            box.contains(rect.topLeft) &&
                box.contains(rect.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: '${element.widget} is a scroll away at ${sizeLabel(size)}');
      }
      return true;
    });
  }
}

Finder get _card => find.byType(SpeakableInfo);
Finder get _board => find.byType(ChessBoardWithOverlay);
Finder get _tree => find.text('Variation Tree');

void main() {
  setUpAll(loadRoboto);

  for (final size in [_window, _small]) {
    testWidgets(
        'on a window of ${sizeLabel(size)}: the card beside the board, above '
        'the tree, every reply chip on screen', (tester) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.byType(ActionChip), findsWidgets,
          reason: 'the fixture opens on a fork');
      final board = _rect(tester, _board);
      final card = _rect(tester, _card);
      expect(card.left, greaterThanOrEqualTo(board.right),
          reason: 'the card is in the right column, not under the board');
      expect(_rect(tester, _tree).top, greaterThanOrEqualTo(card.bottom),
          reason: 'the tree under the card');
      _expectSeen(tester, size, _card);
      _expectSeen(tester, size, find.byType(ActionChip));
    });
  }

  testWidgets('on a 360 dp phone the card stays under the board',
      (tester) async {
    await _pump(tester, _phone);
    expect(tester.takeException(), isNull);
    expect(_rect(tester, _card).top,
        greaterThanOrEqualTo(_rect(tester, _board).bottom));
  });
}
