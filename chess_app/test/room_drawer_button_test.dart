// The room's ☰ is a target you can hit.
//
// Reported live by the owner, 20.9.2026, against TODO-provera 205 point 8:
// „radi, ali je u takvom delu ekrana, da jedva odgovara na pritisak" — it
// works, but it sits in such a part of the screen that it barely responds.
//
// Measured on master before anything was changed:
//
//   portrait  360 x 760 : app bar 56, button 48 x 48 at (4, 4)
//   landscape 760 x 360 : app bar 44, button 48 x 44 at (4, 0)
//   landscape 932 x 430 : app bar 44, button 48 x 44 at (4, 0)
//
// Nobody placed that button. The room's `AppBar` sets no `leading`, so
// Flutter draws its own `DrawerButton` whenever the `Scaffold` has a drawer,
// and it lands wherever the bar leaves it. In landscape the bar is 44 tall
// (`LandscapeBoardLayout` trades 12 dp of chrome for the board on a 360 dp
// screen), and the button ends up pressed into the very corner — four logical
// pixels from the left edge, flush against the top one.
//
// The left edge of a phone in landscape is where Android puts its
// back-gesture strip, so a press there competes with the system for the
// touch. **That this is the cause is a hypothesis, not a measurement** — it
// cannot be confirmed from a widget test, only on the device. What the cases
// below do assert is the part that is measurable and true either way: the
// target clears the edges it was jammed against, and it is never smaller than
// the bar allows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

http.Client _server() => MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/library/positions')) {
        return http.Response('{"items":[]}', 200);
      }
      return http.Response('[]', 200);
    });

/// Opens the room at [size], optionally behind a system gesture strip of
/// [gestureLeft] logical pixels down the left edge — which is what an Android
/// phone held sideways actually hands the app.
Future<void> _room(
  WidgetTester tester,
  Size size, {
  double gestureLeft = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.systemGestureInsets = FakeViewPadding(left: gestureLeft);
  addTearDown(tester.view.reset);

  final client = _server();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: ChessGamePage(
      userSession: UserSession(
          id: 1, token: 'tok', email: 'e', name: 'N', role: 'trener'),
      roomCode: 'STUDIO',
      initialRole: 'trener',
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Where the drawer's button is painted, whoever drew it.
///
/// Found by what it does rather than by which class draws it: Flutter's
/// implied `DrawerButton` and one placed by hand are the same control to a
/// reader, and the claim here is about the rectangle, not the widget.
Rect _button(WidgetTester tester) {
  final finder = _finder;
  expect(finder, findsOneWidget,
      reason: 'the room has no way to open its side panel at this size');
  return tester.getRect(finder);
}

/// The `IconButton` itself, not the `Tooltip` inside it.
///
/// This distinction cost the first run of this gate: `find.byTooltip` reports
/// a 40 px box — the icon — while the rectangle that answers a finger is the
/// button around it, which master draws 48 wide. A gate that measured the
/// tooltip would have been red on master for a reason that was not the fault,
/// and green later for a reason that was not the fix.
final Finder _finder = find.byWidgetPredicate(
    (w) => w is IconButton && w.tooltip == 'Open navigation menu');

void main() {
  testWidgets('on a phone held upright it is the full 48 square',
      (tester) async {
    // Unchanged, and this case is here to keep it that way: portrait has the
    // room for Material's minimum and already had it.
    await _room(tester, const Size(360, 760));
    final r = _button(tester);
    expect(r.width, greaterThanOrEqualTo(48));
    expect(r.height, greaterThanOrEqualTo(48));
  });

  testWidgets('held sideways it still fills the bar it is given',
      (tester) async {
    await _room(tester, const Size(760, 360));
    final r = _button(tester);
    expect(r.width, greaterThanOrEqualTo(48),
        reason: 'the bar is short here, so the width is what is left to give');
    expect(r.height,
        greaterThanOrEqualTo(LandscapeBoardLayout.compactToolbarHeight),
        reason: 'the target is smaller than the bar that holds it');
  });

  testWidgets('it is not jammed into the corner', (tester) async {
    // The corner is the complaint. Four logical pixels from the left edge is
    // what master gives, and the left edge of a landscape phone is a place the
    // system is also listening to.
    await _room(tester, const Size(760, 360));
    final r = _button(tester);
    expect(r.left, greaterThanOrEqualTo(8));
  });

  testWidgets('it clears the system gesture strip', (tester) async {
    // 48 is the widest back-gesture inset Android asks for. A button that
    // starts inside it is a button the system may answer instead.
    await _room(tester, const Size(760, 360), gestureLeft: 48);
    final r = _button(tester);
    expect(r.left, greaterThanOrEqualTo(48),
        reason: 'the button begins inside the back-gesture strip');
    // Moving it in is only half of it: the slot it sits in has to grow by the
    // same amount, or the button is merely squeezed instead of moved. Added
    // after a mutation survived — leaving `leadingWidth` at its default kept
    // every other case green while shrinking this button to 8 px.
    expect(r.width, greaterThanOrEqualTo(48),
        reason: 'the button was pushed in but not given the room to go');
  });

  testWidgets('and it still opens the panel', (tester) async {
    // The point of all of the above. A target that is easy to hit and opens
    // nothing is not an improvement.
    await _room(tester, const Size(760, 360), gestureLeft: 48);
    await tester.tap(_finder);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
  });
}
