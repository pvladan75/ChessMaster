import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/login_screen.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'support/landscape.dart' show loadRoboto;

/// The sign-in screen on a wide window: the brand on the left, the form on
/// the right (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D1 B, phase 2) — and the
/// phone exactly as it was.
void main() {
  // Text measured in a real font: the test font draws every glyph as a
  // square, so „does the label fit" would be a question about squares.
  setUpAll(loadRoboto);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.init();
  });

  final panel = find.byKey(const Key('sign-in-brand-panel'));
  final form = find.byKey(const Key('sign-in-form'));

  Future<void> open(WidgetTester tester, Size size,
      {bool google = true, double? box}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) {
            final screen = LoginRegisterScreen(googleAvailableOverride: google);
            return box == null
                ? screen
                : Center(child: SizedBox(width: box, child: screen));
          },
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => Scaffold(
              body: Text('HOME as ${SessionService.instance.current.name}')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(fontFamily: 'Roboto'),
    ));
    await tester.pump();
  }

  for (final size in const [Size(1536, 792), Size(900, 700)]) {
    group('${size.width.toInt()} x ${size.height.toInt()}', () {
      testWidgets('the brand panel stands left of the form, with no bar',
          (tester) async {
        await open(tester, size);

        expect(panel, findsOneWidget);
        expect(form, findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        final p = tester.getRect(panel);
        final f = tester.getRect(form);
        expect(p.left, 0);
        expect(p.right, lessThanOrEqualTo(f.left));
        // A literal, not the constant: a test that reads the constant it tests
        // follows it wherever it moves (it did — the mutation survived).
        expect(f.width, lessThanOrEqualTo(440));
        // Centred in its half, give or take a pixel.
        final half = Rect.fromLTRB(p.right, 0, size.width, size.height);
        expect((f.center.dx - half.center.dx).abs(), lessThan(1.5));
        // The form is the whole form: its heading, its fields, its button.
        for (final label in [
          'Sign In',
          'Email Address',
          'Password',
          'Sign in with email'
        ]) {
          expect(find.descendant(of: form, matching: find.text(label)),
              findsOneWidget,
              reason: label);
        }
      });

      testWidgets('the panel\'s board is square', (tester) async {
        await open(tester, size);
        final board = tester.getRect(
            find.descendant(of: panel, matching: find.byType(BoardThumbnail)));
        expect(board.width, board.height);
        expect(board.width, greaterThan(100));
      });

      testWidgets('„Continue as Guest" sits in the form half and enters',
          (tester) async {
        await open(tester, size);
        final guest = find.text('Continue as Guest');
        expect(guest, findsOneWidget);
        expect(tester.getCenter(guest).dx,
            greaterThan(tester.getRect(panel).right));

        await tester.tap(guest);
        await tester.pumpAndSettle();
        expect(find.textContaining('HOME as'), findsOneWidget);
      });

      testWidgets('the Google label is read whole', (tester) async {
        await open(tester, size);
        final paragraph = tester.renderObject<RenderParagraph>(
            find.text('Sign in / Register with Google'));
        expect(paragraph.didExceedMaxLines, isFalse);
      });
    });
  }

  for (final size in const [Size(360, 640), Size(760, 360)]) {
    testWidgets(
        'a phone ${size.width.toInt()} x ${size.height.toInt()} keeps the '
        'screen as it was', (tester) async {
      await open(tester, size);

      expect(panel, findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text('Sign In')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Continue as Guest')),
          findsOneWidget);
      // The trophy and the name are the form's own again.
      expect(find.text('Mislisha'), findsOneWidget);
    });
  }

  testWidgets(
      'decided by the width the screen is given, not by the window: a wide '
      'window holding a 600 px box has no panel', (tester) async {
    await open(tester, const Size(1536, 792), box: 600);

    expect(panel, findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('without Google and while verifying, the halves stay',
      (tester) async {
    await open(tester, const Size(1536, 792), google: false);
    expect(panel, findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);

    await tester.tap(find.text("Don't have an account? Register with email"));
    await tester.pumpAndSettle();
    expect(panel, findsOneWidget);
    expect(find.descendant(of: form, matching: find.text('Register')),
        findsOneWidget);
    expect(find.descendant(of: form, matching: find.text('Full Name')),
        findsOneWidget);
  });
}
