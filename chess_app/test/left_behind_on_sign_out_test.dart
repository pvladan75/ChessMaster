import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_controller.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// **A screen that closes after the sign-out must not hand its work on.**
///
/// Reported live twice: on 18.9.2026 (TODO-provera 177.2) and again on
/// 20.9.2026, after the first fix — a new account signed in and was offered
/// the previous account's analysis. The first fix wiped the draft on sign-out,
/// and that part works. What it could not see is the order on the way out:
/// `signOut()` wipes, *then* `context.go(login)` tears the shell down, and the
/// Analysis screen's `dispose` flushes the tree it still holds. By then the
/// device belongs to the guest, and a guest's work is adopted by whoever signs
/// in next — so the wipe was undone a frame after it ran.
///
/// The tutorial studio flushes on the way out in the same way, so it is held
/// to the same rule here.
///
/// Every case stands on the real order: the writer is made while the first
/// account is signed in, the sign-out runs, *then* the writer writes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  UserSession user(int id) => UserSession(
        token: 'token-$id',
        id: id,
        email: 'u$id@example.test',
        name: 'User $id',
        role: 'korisnik',
      );

  /// A draft with one move in it, written straight into the key rather than
  /// through the service, so this file says nothing about how the service
  /// wants to be called. A bare root would not load at all and pass the test
  /// by being unreadable.
  Map<String, Object> seededDraft() => {
        'analysis_studio_draft': jsonEncode({
          'tree': {
            'fen': start,
            'children': [
              {'fen': afterE4, 'moveSan': 'e4', 'moveUci': 'e2e4'}
            ],
          },
          'path': [0],
          'blackOrientation': false,
          'savedAt': '2026-09-21T10:00:00.000',
        }),
      };

  Future<void> settleDisk(WidgetTester tester) => tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));

  testWidgets(
      'the Analysis screen torn down after sign-out does not reach the next '
      'account', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
    await SessionService.instance.signIn(user(11), rememberMe: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('analysis_studio_draft',
        seededDraft()['analysis_studio_draft']! as String);

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(userSession: user(11)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await settleDisk(tester);

    // The shell's order: the session ends first, the screens go after.
    await SessionService.instance.signOut();
    expect(await AnalysisDraftService.instance.load(), isNull,
        reason: 'the sign-out itself must still wipe the draft');

    await tester.pumpWidget(const SizedBox());
    await settleDisk(tester);

    await SessionService.instance.signIn(user(22), rememberMe: true);
    expect(await AnalysisDraftService.instance.load(), isNull,
        reason: 'account 22 was handed account 11\'s tree');
  });

  test('a tutorial flushed after sign-out does not reach the next account',
      () async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
    await SessionService.instance.signIn(user(11), rememberMe: true);

    final c = TutorialDraftController(
      draft: TutorialDraft(
        title: 'Opposition',
        sections: [
          TutorialSection.blank(fen: TutorialDraft.startFen, title: 'Part 1')
        ],
      ),
    );
    addTearDown(c.dispose);
    await c.flush();
    expect(await TutorialDraftService.instance.load(), isNotNull,
        reason: 'the fixture never wrote a draft, so the rest proves nothing');

    await SessionService.instance.signOut();
    await c.flush();

    await SessionService.instance.signIn(user(22), rememberMe: true);
    expect(await TutorialDraftService.instance.load(), isNull,
        reason: 'account 22 was handed account 11\'s tutorial');
  });

  test('a guest\'s tutorial still goes with them into their account', () async {
    // The other half of the rule, and the easy one to break while fencing the
    // first: nothing was wiped, so a writer from before the sign-in writes.
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();

    final c = TutorialDraftController(
      draft: TutorialDraft(
        title: 'Opposition',
        sections: [
          TutorialSection.blank(fen: TutorialDraft.startFen, title: 'Part 1')
        ],
      ),
    );
    addTearDown(c.dispose);

    await SessionService.instance.signIn(user(11), rememberMe: true);
    await c.flush();
    expect(await TutorialDraftService.instance.load(), isNotNull);
  });

  testWidgets('a guest\'s analysis still goes with them into their account',
      (tester) async {
    SharedPreferences.setMockInitialValues(seededDraft());
    await SessionService.instance.signOut();

    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(userSession: UserSession.guest()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await settleDisk(tester);
    // The screen holds the tree now. Take it off the disk, so the only way it
    // can be there at the end is the screen's own write on the way out — with
    // the seed left in place this case stayed green when every write was
    // refused, because it was reading the fixture back.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('analysis_studio_draft');

    await SessionService.instance.signIn(user(11), rememberMe: true);
    await tester.pumpWidget(const SizedBox());
    await settleDisk(tester);

    expect(await AnalysisDraftService.instance.load(), isNotNull);
  });
}
