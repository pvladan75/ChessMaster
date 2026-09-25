import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/account_local_state.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/local_puzzle_service.dart';
import 'package:chess_app/services/session_service.dart';

/// **What one account left on the device must not greet the next one.**
///
/// Reported live on 18.9.2026 (TODO-provera 177.2): a brand-new account was
/// made on this workstation, signed in, and Home offered „Resume analysis" —
/// which opened the tree the *previous* account had been working on.
/// `signOut()` cleared the credentials and deliberately nothing else, and every
/// scratch key on the device is written unscoped.
///
/// The other half is the one that is easy to break while fixing the first: a
/// guest analysing and then signing in is the same person finishing the same
/// thought, and must not lose the tree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A draft with one move in it — [AnalysisDraftService.load] refuses to
  /// restore a bare starting position, so a tree with no children would pass
  /// this test by being unreadable rather than by being cleared.
  Future<void> writeDraft() async {
    final root = AnalysisNode(fen: 'startpos');
    root.children.add(AnalysisNode(
      fen: 'after-e4',
      parent: root,
      moveSan: 'e4',
      moveUci: 'e2e4',
    ));
    await AnalysisDraftService.instance.flush(
      rootNode: root,
      currentNode: root.children.first,
      blackOrientation: false,
      epoch: AccountLocalState.epoch,
    );
  }

  Future<bool> hasDraft() async =>
      await AnalysisDraftService.instance.load() != null;

  UserSession user(int id) => UserSession(
        token: 'token-$id',
        id: id,
        email: 'u$id@example.test',
        name: 'User $id',
        role: 'korisnik',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService.instance.signOut();
  });

  test('a second account does not inherit the first one\'s analysis draft',
      () async {
    await SessionService.instance.signIn(user(11), rememberMe: true);
    await writeDraft();
    expect(await hasDraft(), isTrue, reason: 'the draft was never written');

    await SessionService.instance.signOut();
    expect(await hasDraft(), isFalse,
        reason: 'signing out left the tree on the device');

    await SessionService.instance.signIn(user(22), rememberMe: true);
    expect(await hasDraft(), isFalse);
  });

  test('a sign-in straight into another account clears it too', () async {
    await SessionService.instance.signIn(user(11), rememberMe: true);
    await writeDraft();

    // No sign-out in between: the app was killed, or the login screen was
    // reached from a route that never went through it.
    await SessionService.instance.signIn(user(22), rememberMe: true);
    expect(await hasDraft(), isFalse);
  });

  test('the same account signing back in keeps its draft', () async {
    await SessionService.instance.signIn(user(11), rememberMe: true);
    await writeDraft();

    await SessionService.instance.signIn(user(11), rememberMe: true);
    expect(await hasDraft(), isTrue);
  });

  test('a guest who signs in carries their own work into the account',
      () async {
    // setUp left the guest in place.
    await writeDraft();
    await SessionService.instance.signIn(user(11), rememberMe: true);
    expect(await hasDraft(), isTrue,
        reason: 'the guest and the account are one person here');
  });

  test('the room and the solved-puzzle list go with the account', () async {
    await SessionService.instance.signIn(user(11), rememberMe: true);
    await GameSessionService.instance.setActive('123456', 'host');
    await LocalPuzzleService.instance.markPuzzleAsSolved('mate-7');

    await SessionService.instance.signOut();

    expect(GameSessionService.instance.roomCode, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('solved_local_puzzles'), isNull);
    expect(prefs.getString('active_room_code'), isNull);
  });

  // The tutorials kept their own engine answers, one file a game, until
  // 25.9.2026 (`GameFactsStore`, deleted in phase 1b of
  // docs/PLAN-ZAGONETKE-IZ-PARTIJE.md). Nothing writes there now, but a device
  // that ran an older version still has the folder, and its file names say
  // which games were analysed.
  test("the tutorials' old answers folder goes with the account", () async {
    // It lives under the support directory, which the test points at a
    // folder of its own through the plugin's channel.
    final support = Directory.systemTemp.createTempSync('support_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => support.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      if (support.existsSync()) support.deleteSync(recursive: true);
    });

    await SessionService.instance.signIn(user(11), rememberMe: true);
    final old = Directory('${support.path}${Platform.pathSeparator}game_facts')
      ..createSync(recursive: true);
    File('${old.path}${Platform.pathSeparator}0a1b2c.json')
        .writeAsStringSync('{"version": 1}');

    await SessionService.instance.signOut();
    await AccountLocalState.engineAnswersWiped;
    expect(old.existsSync(), isFalse,
        reason: 'the next account would find which games were analysed here');
  });

  test('what cannot be re-made is not deleted', () async {
    // A recording that has not reached the server and a named puzzle set are
    // the two things this sweep must walk past — see [AccountLocalState].
    SharedPreferences.setMockInitialValues({
      'local_session_recordings_list': <String>['{"id":"local_1"}'],
      'analysis_studio_puzzle_sets': '[{"id":"puzzleset_1"}]',
      AccountLocalState.ownerKey: 11,
    });

    await SessionService.instance.signIn(user(22), rememberMe: true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('local_session_recordings_list'), hasLength(1));
    expect(prefs.getString('analysis_studio_puzzle_sets'), isNotNull);
  });

  test('a restart that brings nobody back clears the last account\'s draft',
      () async {
    await SessionService.instance.signIn(user(11), rememberMe: false);
    await writeDraft();

    // `remember_me` is off, so the next start is a guest one.
    await SessionService.instance.init();
    expect(SessionService.instance.current.isGuest, isTrue);
    expect(await hasDraft(), isFalse);
  });
}
