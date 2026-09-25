// A tutorial reaches a student as its film — phase 3 of
// docs/PLAN-TUTORIJAL-VIDEO.md, the app's half.
//
//  1. the student's screen says what the film is and hands its link to the
//     browser, on a phone and on a desktop, and says when it was downloaded;
//  2. a tutorial with no film cannot be sent from any of the three doors, and
//     each says why;
//  3. deleting a tutorial says how many students have not downloaded it;
//  4. Home has no „Due for review", and the trainer's review shows the date;
//  5. on a phone, one part turns from its own row.
//
// Every request is asserted on the request itself (a fake client), and the
// browser is a fake launcher asserted on the address it was handed.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/screens/video_assignment_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/widgets/assign_lesson_dialog.dart';
import 'package:chess_app/features/assignments/widgets/assignment_item_destination.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_row_actions.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/home/dashboard_tab.dart';

final _student =
    UserSession(token: 't', id: 9, email: 'a@b.c', name: 'Ana', role: 'ucenik');
final _trainer = UserSession(
    token: 't', id: 5, email: 'b@b.c', name: 'Trener', role: 'trener');

const _link = '/assignments/video-download/tutorial_77.mp4?token=abc';

AssignmentDetail _detail({
  DateTime? downloadedAt,
  bool ready = true,
}) =>
    AssignmentDetail(
      assignment: const Assignment(
        id: 70,
        title: 'Broken Pawns and Loose Pieces',
        kind: AssignmentKind.lesson,
        instructions: 'Watch it before Thursday.',
        trainerName: 'Trener',
        totalItems: 1,
      ),
      items: [
        AssignmentItem(puzzleId: null, position: 0, attemptedAt: downloadedAt),
      ],
      video: AssignmentVideo(
          ready: ready, seconds: 194, resolution: '720p', renderedAt: null),
    );

Widget _app(Widget home) => MaterialApp(
      theme:
          ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
      home: home,
    );

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---- 1. the student's screen -----------------------------------------------

  for (final size in const [Size(360, 640), Size(1280, 800)]) {
    testWidgets(
        'at ${size.width.toInt()}: the film is described, and its link goes '
        'to the browser', (tester) async {
      _size(tester, size);
      final asked = <String>[];
      final launched = <Uri>[];
      final api = AssignmentApiService(
        authToken: 't',
        client: MockClient((req) async {
          asked.add('${req.method} ${req.url.path}');
          return http.Response(
              jsonEncode({'status': 'ready', 'downloadUrl': _link}), 200);
        }),
      );

      await tester.pumpWidget(_app(VideoAssignmentScreen(
        session: _student,
        detail: _detail(),
        api: api,
        launch: (uri) async {
          launched.add(uri);
          return true;
        },
      )));
      await tester.pumpAndSettle();

      expect(find.text('Broken Pawns and Loose Pieces'), findsOneWidget);
      expect(find.text('Watch it before Thursday.'), findsOneWidget);
      expect(find.text('3 min 14 s · 720p'), findsOneWidget);
      expect(find.text('Not downloaded yet.'), findsOneWidget);
      expect(asked, isEmpty, reason: 'nothing is asked until the button');

      await tester.tap(find.byKey(const Key('video-assignment-download')));
      await tester.pumpAndSettle();

      expect(asked, ['GET /assignments/70/video'],
          reason: 'a fresh link, from this assignment');
      expect(launched, [Uri.parse(resolveMediaUrl(_link))]);
      expect(find.text('The download has started in your browser.'),
          findsOneWidget);
    });
  }

  testWidgets('a downloaded film says when, and can be downloaded again',
      (tester) async {
    _size(tester, const Size(360, 640));
    await tester.pumpWidget(_app(VideoAssignmentScreen(
      session: _student,
      detail: _detail(downloadedAt: DateTime(2026, 9, 25, 14)),
      api: AssignmentApiService(
          authToken: 't',
          client: MockClient((_) async => http.Response('', 500))),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Downloaded on 25.9.2026.'), findsOneWidget);
    expect(find.text('Download again'), findsOneWidget);
  });

  testWidgets('a film that is gone offers no download, and says what to do',
      (tester) async {
    _size(tester, const Size(360, 640));
    await tester.pumpWidget(_app(VideoAssignmentScreen(
      session: _student,
      detail: _detail(ready: false),
      api: AssignmentApiService(
          authToken: 't',
          client: MockClient((_) async => http.Response('', 500))),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-assignment-download')), findsNothing);
    expect(find.byKey(const Key('video-assignment-gone')), findsOneWidget);
  });

  testWidgets('a link the server refuses opens nothing, and says why',
      (tester) async {
    _size(tester, const Size(360, 640));
    final launched = <Uri>[];
    await tester.pumpWidget(_app(VideoAssignmentScreen(
      session: _student,
      detail: _detail(),
      api: AssignmentApiService(
        authToken: 't',
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'status': 'none',
              'error': 'This video is no longer available. Ask your trainer '
                  'to send it again.',
            }),
            404)),
      ),
      launch: (uri) async {
        launched.add(uri);
        return true;
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('video-assignment-download')));
    await tester.pumpAndSettle();

    expect(launched, isEmpty);
    expect(find.textContaining('no longer available'), findsOneWidget);
  });

  testWidgets('a tutorial assignment opens on its film', (tester) async {
    _size(tester, const Size(360, 640));
    await tester.pumpWidget(_app(assignmentItemScreen(
      session: _student,
      detail: _detail(),
    )));
    await tester.pumpAndSettle();
    expect(find.byType(VideoAssignmentScreen), findsOneWidget);
  });

  // ---- 2. no film, no send -----------------------------------------------------

  testWidgets('the Library row: no film offers the export, and sends nothing',
      (tester) async {
    final asked = <String>[];
    final client = MockClient((req) async {
      asked.add('${req.method} ${req.url.path}');
      return http.Response('[]', 200);
    });
    final actions = TutorialRowActions(
      lessonApi: LessonApiService(authToken: 't', client: client),
      assignmentApi: AssignmentApiService(authToken: 't', client: client),
      groupApi: GroupApiService(client: client),
    );
    final row = <String, dynamic>{
      'id': 9,
      'title': 'Lucena',
      'has_video': false
    };
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => actions.send(context, row),
          child: const Text('go'),
        ),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Export the video first'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-send-export-first')),
        findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(asked, isEmpty,
        reason: 'no students were asked for, and nothing was sent');
  });

  testWidgets('the Library row: with a film, the students are offered',
      (tester) async {
    final asked = <String>[];
    final client = MockClient((req) async {
      asked.add('${req.method} ${req.url.path}');
      return http.Response(
          jsonEncode({
            'students': [
              {'id': 3, 'name': 'Ana', 'status': 'accepted'}
            ]
          }),
          200);
    });
    final actions = TutorialRowActions(
      lessonApi: LessonApiService(authToken: 't', client: client),
      assignmentApi: AssignmentApiService(authToken: 't', client: client),
      groupApi: GroupApiService(client: client),
    );
    final row = <String, dynamic>{
      'id': 9,
      'title': 'Lucena',
      'has_video': true
    };
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => actions.send(context, row),
          child: const Text('go'),
        ),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Export the video first'), findsNothing);
    expect(find.text('Send the video to a student'), findsOneWidget);
  });

  testWidgets('the student’s page: a tutorial with no film cannot be chosen',
      (tester) async {
    _size(tester, const Size(360, 640));
    final rows = [
      {
        'id': 1,
        'title': 'With a film',
        'position_list': [{}, {}],
        'has_video': true,
      },
      {
        'id': 2,
        'title': 'Without one',
        'position_list': [{}],
        'has_video': false,
      },
      {'id': 3, 'title': 'A single position', 'position_list': null},
    ];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(Scaffold(
        body: AssignLessonDialog(
          api: AssignmentApiService(
              authToken: 't',
              client: MockClient((_) async => http.Response('{}', 500))),
          session: _trainer,
          studentId: 3,
          studentName: 'Ana',
        ),
      )));
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => http.Response(jsonEncode(rows), 200)));

    RadioListTile<int> tile(int id) => tester
        .widget<RadioListTile<int>>(find.byKey(ValueKey('send-video-$id')));
    expect(tile(1).enabled, isTrue);
    expect(tile(2).enabled, isFalse);
    expect(find.text('No video yet — export it first'), findsOneWidget);
    expect(find.byKey(const ValueKey('send-video-3')), findsNothing,
        reason: 'a single position has no film, and is sent as an exercise');
  });

  // ---- 3. deleting strands somebody ------------------------------------------

  testWidgets('deleting says how many have not downloaded the film',
      (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmTutorialDelete(context,
              title: 'Lucena', hasVideo: true, waitingDownloads: 2),
          child: const Text('go'),
        ),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 students have not downloaded its video yet'),
        findsOneWidget);
  });

  // ---- 4. Home and the review -------------------------------------------------

  testWidgets('Home has no „Due for review", and says videos', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _size(tester, const Size(1280, 2000));
    await tester.pumpWidget(_app(Scaffold(
      body: HomeDashboardTab(
        userName: 'Ana',
        liveSessions: const [],
        recordings: const [],
        isLoadingRecordings: false,
        panel: const TrainerPanel(),
        onOpenPanelAssignment: (_) {},
        onOpenStudent: (_, __) {},
        hasTrainer: true,
        onOpenAssignments: () {},
        onJoinSession: (_) {},
        onRefreshRecordings: () {},
        onOpenReplay: (_) {},
      ),
    )));
    await tester.pumpAndSettle();

    final flow = find.byKey(const Key('home-shortcut-flow'));
    expect(flow, findsOneWidget);
    expect(find.descendant(of: flow, matching: find.text('Set for me')),
        findsOneWidget);
    expect(find.descendant(of: flow, matching: find.text('Due for review')),
        findsNothing);
    expect(
        find.text('Drills and videos your trainer set you, and your progress.'),
        findsOneWidget);
  });

  for (final downloaded in [false, true]) {
    testWidgets(
        'the trainer’s review of a film says '
        '${downloaded ? 'when it was downloaded' : 'it is not downloaded yet'}',
        (tester) async {
      _size(tester, const Size(360, 640));
      final review = {
        'assignment': {
          'id': 70,
          'title': 'Broken Pawns and Loose Pieces',
          'kind': 'lesson',
        },
        'viewer': {'isTrainer': true, 'isStudent': false},
        'items': [
          {
            'itemId': 1,
            'position': 0,
            'kind': 'video',
            'title': 'Broken Pawns and Loose Pieces',
            'attempted': downloaded,
            'attemptedAt': downloaded ? '2026-09-25T12:00:00' : null,
            'solved': null,
          },
        ],
        'notes': [],
      };
      await tester.pumpWidget(_app(AssignmentReviewScreen(
        session: _trainer,
        assignmentId: 70,
        title: 'Broken Pawns and Loose Pieces',
        api: AssignmentApiService(
          authToken: 't',
          client: MockClient((req) async => http.Response(
              req.url.path.endsWith('/review') ? jsonEncode(review) : '{}',
              200)),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('review-video-status')), findsOneWidget);
      expect(
          find.text(
              downloaded ? 'Downloaded on 25.9.2026.' : 'Not downloaded yet.'),
          findsWidgets);
      expect(find.text(downloaded ? 'Downloaded' : 'Not downloaded yet'),
          findsOneWidget,
          reason: 'the summary says the same');
    });
  }

  // ---- 5. the phone turns one part -----------------------------------------------

  testWidgets('on a phone, a part turns from its own row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    _size(tester, const Size(360, 640));

    await tester.pumpWidget(_app(TutorialStudioScreen(
      session: _trainer,
      entry: TutorialEntry.fromAnalysis(TutorialHandover.position(
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')),
      lessonApi: LessonApiService(
          authToken: 't',
          client: MockClient((_) async => http.Response('{}', 200))),
    )));
    await tester.pumpAndSettle();

    PlayerColor shown() => tester
        .widget<BoardWithCoordinates>(find.byType(BoardWithCoordinates).first)
        .orientation;
    expect(shown(), PlayerColor.white);

    await tester.tap(find.byKey(const Key('phone-tab-parts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('turn-part-0')));
    await tester.pumpAndSettle();

    expect(shown(), PlayerColor.black);
    expect(find.byTooltip('Turn this part (Black at the bottom now)'),
        findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    debugDefaultTargetPlatformOverride = null;
  });
}
