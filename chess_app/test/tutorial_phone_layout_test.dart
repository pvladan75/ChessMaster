// The Tutorial Studio on a phone — phase 6b of docs/PLAN-REORGANIZACIJA.md,
// the gate §7 wrote before anyone built the layout.
//
// Lives in docs/gates/ until the phase makes it green; the implementer copies
// it into chess_app/test/ unchanged and leaves it there. Written 17.9.2026,
// red on master at 22fe515 for the right reason: on a 360 × 640 phone the
// studio's app bar overflows by 263 px before anything else is looked at,
// it still draws its desktop tabs — „Flow", „Tree", „PGN" — and none of the
// keys below exist. The desktop half of the script was run on its own first
// and is green, so a red here is the phone's.
//
// What §7 asks for, in order: (a) the same taps on the phone layout save the
// same `positionList` as the desktop layout does on the same controller —
// byte-equal; (b) every action of §7.2 is reached by tapping, none by
// keyboard; (c) nothing overflows at 360 × 640 or 640 × 360 — a test build
// throws where a release build clips. And the mutation the plan names: take
// the phone layout's Save away and watch (a) fail.
//
// If you believe a test in this gate is wrong, stop and say so in the report
// — do not work around it. The 6b worker did, twice, and both were the
// gate's: the override reset moved into [close], and the device slot is
// cleared between the two halves of the byte-equality test.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Answers every save with an id and remembers what it was sent.
class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.seen, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<({String method, String path, Map<String, dynamic> body})> seen;

  factory _RecordingApi() {
    final seen = <({String method, String path, Map<String, dynamic> body})>[];
    return _RecordingApi._(
      seen,
      MockClient((req) async {
        seen.add((
          method: req.method,
          path: req.url.path,
          body: req.body.isEmpty
              ? const <String, dynamic>{}
              : Map<String, dynamic>.from(jsonDecode(req.body) as Map),
        ));
        return http.Response(jsonEncode({'id': 77}), 201);
      }),
    );
  }

  List<Map<String, dynamic>> get saves => [
        for (final r in seen)
          if (r.method == 'POST' && r.path.endsWith('/lessons/save')) r.body,
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 'tok',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  /// The studio as a phone draws it: a touch platform, and a window narrower
  /// than [Breakpoints.wide]. The platform is read through the theme, which
  /// follows this override; a Windows window of the same width keeps the
  /// desktop's narrow branch.
  Future<_RecordingApi> openPhone(WidgetTester tester, Size size) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingApi();
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialStudioScreen(
          session: session,
          entry: TutorialEntry.fromAnalysis(
            TutorialHandover.position(_startFen),
          ),
          lessonApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow on opening');
    return api;
  }

  Future<_RecordingApi> openDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingApi();
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialStudioScreen(
          session: session,
          entry: TutorialEntry.fromAnalysis(
            TutorialHandover.position(_startFen),
          ),
          lessonApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  /// Tears the tree down without waiting out the draft's 600 ms debounce,
  /// and puts the platform back. **Inside the test, not in a `tearDown`**:
  /// the binding checks that the override is null before the test body has
  /// returned, so a `tearDown` is too late — the 6b worker proved it with a
  /// repro that had no app code in it at all.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    debugDefaultTargetPlatformOverride = null;
  }

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  Future<void> play(WidgetTester tester, String from, String to) async {
    board(tester).onMove(from, to, '');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow after $from$to');
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow after $key');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow after „$text"');
  }

  Future<void> type(WidgetTester tester, String key, String value) async {
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'overflow typing in $key');
  }

  /// A demonstration of two moves with a sentence each, then a question on
  /// the position they reached — the tutorial `tutorial_authoring_test`
  /// writes on the desktop, here written through the phone's keys.
  Future<void> phoneScript(WidgetTester tester) async {
    await type(tester, 'phone-title', 'Otvaranje u dva primera');
    await play(tester, 'e2', 'e4');
    await tapKey(tester, 'phone-tab-line');
    await type(tester, 'phone-comment', 'Beli odmah zauzima centar.');
    await play(tester, 'e7', 'e5');
    await type(tester, 'phone-comment', 'Crni odgovara isto.');

    await tapKey(tester, 'phone-tab-parts');
    await tapKey(tester, 'phone-new-part');
    await tapText(tester, 'New demonstration');
    await tapText(tester, 'From here');

    await tapKey(tester, 'phone-tab-task');
    await tapKey(tester, 'phone-task-kind');
    await tapText(tester, 'Ask for move on board');
    await type(tester, 'phone-task-text', 'Napadni pešaka na e5.');
    await play(tester, 'g1', 'f3');

    await tapKey(tester, 'phone-save');
  }

  /// The same tutorial through the desktop's keys.
  Future<void> desktopScript(WidgetTester tester) async {
    await type(tester, 'tutorial-title', 'Otvaranje u dva primera');
    await play(tester, 'e2', 'e4');
    await type(tester, 'example-sentence', 'Beli odmah zauzima centar.');
    await play(tester, 'e7', 'e5');
    await type(tester, 'example-sentence', 'Crni odgovara isto.');

    await tapKey(tester, 'add-show');
    await tapText(tester, 'From here');

    await tapKey(tester, 'example-kind');
    await tapText(tester, 'Ask for move on board');
    await type(tester, 'example-instruction', 'Napadni pešaka na e5.');
    await play(tester, 'g1', 'f3');

    await tapText(tester, 'Save tutorial');
  }

  group('portrait, 360 × 640', () {
    const portrait = Size(360, 640);

    testWidgets('opens as Line | Task | Parts, not Flow | Tree | PGN', (
      tester,
    ) async {
      await openPhone(tester, portrait);

      for (final tab in [
        'phone-tab-line',
        'phone-tab-task',
        'phone-tab-parts',
      ]) {
        expect(find.byKey(Key(tab)), findsOneWidget, reason: tab);
      }
      expect(find.text('Line'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Parts'), findsOneWidget);
      for (final desktop in ['Flow', 'Tree', 'PGN']) {
        expect(
          find.text(desktop),
          findsNothing,
          reason: '„$desktop" is the desktop\'s tab',
        );
      }
      expect(find.byType(ChessBoardWithOverlay), findsOneWidget);
      expect(find.byKey(const Key('phone-save')), findsOneWidget);

      await close(tester);
    });

    testWidgets('the same taps save the same positionList as the desktop', (
      tester,
    ) async {
      final phone = await openPhone(tester, portrait);
      await phoneScript(tester);
      expect(
        phone.saves,
        hasLength(1),
        reason: 'the phone\'s Save must send the tutorial, once',
      );
      final fromPhone = jsonEncode(phone.saves.single['positionList']);
      await close(tester);
      // The phone half left its draft in the device's slot, and the desktop
      // half — opened through the Studio's door, which adopts an open draft
      // by design — would carry on with it and PUT to the tutorial the phone
      // just made. Two clean opens, one slot each.
      await TutorialDraftService.instance.clear();

      final desktop = await openDesktop(tester);
      await desktopScript(tester);
      expect(desktop.saves, hasLength(1));
      final fromDesktop = jsonEncode(desktop.saves.single['positionList']);
      await close(tester);

      expect(
        fromPhone,
        fromDesktop,
        reason: 'one controller, two layouts: the wire must not know '
            'which one wrote the tutorial',
      );
      expect(phone.saves.single['title'], desktop.saves.single['title']);
    });

    testWidgets('every action of §7.2 is a tap away', (tester) async {
      await openPhone(tester, portrait);

      // Line: the move strip, the comment for the cursor's move, drawing and
      // the flip — the bar and the controls the room already shares.
      await play(tester, 'e2', 'e4');
      await tapKey(tester, 'phone-tab-line');
      expect(find.byKey(const Key('phone-comment')), findsOneWidget);
      expect(
        find.byType(BoardAnnotationBar),
        findsOneWidget,
        reason: 'arrows and squares are drawn with the shared bar',
      );
      final controls = tester.widget<MoveNavigationControls>(
        find.byType(MoveNavigationControls).first,
      );
      expect(controls.onFlipBoard, isNotNull, reason: 'the flip is reachable');

      // Task: the kind, the text, the answers.
      await tapKey(tester, 'phone-tab-task');
      await tapKey(tester, 'phone-task-kind');
      await tapText(tester, 'Ask for answer from list');
      expect(find.byKey(const Key('phone-task-text')), findsOneWidget);
      await tapKey(tester, 'phone-add-answer');
      expect(find.byKey(const Key('phone-choice-0')), findsOneWidget);
      expect(find.byKey(const Key('phone-choice-delete-0')), findsOneWidget);

      // Parts: the list, a new part of three kinds, up, down, clone, rename,
      // delete, and tapping a part to select it.
      await tapKey(tester, 'phone-tab-parts');
      await tapKey(tester, 'phone-new-part');
      for (final kind in [
        'New demonstration',
        'Find the move',
        'Choose the answer',
      ]) {
        expect(find.text(kind), findsOneWidget, reason: kind);
      }
      await tapText(tester, 'New demonstration');
      await tapText(tester, 'From here');
      expect(find.byKey(const Key('phone-part-0')), findsOneWidget);
      expect(find.byKey(const Key('phone-part-1')), findsOneWidget);
      for (final action in [
        'Move up',
        'Move down',
        'Clone part',
        'Rename',
        'Delete part',
      ]) {
        expect(find.byTooltip(action), findsWidgets, reason: action);
      }
      // The second part continues from e4; selecting the first stands on its
      // root, the starting position.
      expect(board(tester).controller.getFen(), isNot(_startFen));
      await tapKey(tester, 'phone-part-0');
      expect(
        board(tester).controller.getFen(),
        _startFen,
        reason: 'tapping a part selects it and the board follows',
      );

      // The overflow: what the app bar has no room for.
      await tapKey(tester, 'phone-more');
      for (final item in [
        'Undo',
        'Redo',
        'Preview tutorial',
        'Record narration',
        'Export video',
        'Save as .pgn',
        'Position setup',
      ]) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      await tapText(tester, 'Undo');
      expect(
        find.byKey(const Key('phone-part-1')),
        findsNothing,
        reason: 'Undo in the overflow is the controller\'s undo',
      );

      await close(tester);
    });
  });

  group('landscape, 640 × 360', () {
    const landscape = Size(640, 360);

    testWidgets('the board on the left, whole height; the tabs on the right', (
      tester,
    ) async {
      await openPhone(tester, landscape);

      final boardRect = tester.getRect(find.byType(ChessBoardWithOverlay));
      final tabs = tester.getTopLeft(find.byKey(const Key('phone-tab-line')));
      expect(
        boardRect.left,
        lessThan(tabs.dx),
        reason: 'the board stands left of the tabs',
      );
      expect(
        boardRect.height,
        greaterThan(200),
        reason: 'the board takes the height, not a strip of it',
      );
      for (final tab in [
        'phone-tab-line',
        'phone-tab-task',
        'phone-tab-parts',
      ]) {
        expect(find.byKey(Key(tab)), findsOneWidget, reason: tab);
      }

      // Writing does not overflow either: a move, a sentence, a part.
      await play(tester, 'e2', 'e4');
      await tapKey(tester, 'phone-tab-line');
      await type(tester, 'phone-comment', 'Centar.');
      await tapKey(tester, 'phone-tab-parts');
      await tapKey(tester, 'phone-new-part');
      await tapText(tester, 'New demonstration');
      await tapText(tester, 'New board');
      expect(find.byKey(const Key('phone-part-1')), findsOneWidget);

      await close(tester);
    });
  });
}
