// Deleting a tutorial that has a rendered video — the owner's decision of
// 22.9.2026.
//
// The film is reached only through its tutorial, so the server deletes it
// with the tutorial (`DELETE /lessons/:id`). The one dialog every screen uses
// says so when there is a film, and offers to download it first; that choice
// must delete nothing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_row_actions.dart';
import 'package:chess_app/theme/app_colors.dart';

const _videoSentence = 'Its video will be deleted too';

Future<List<String>> _deleteWith(WidgetTester tester,
    {required bool hasVideo, required String press}) async {
  final asked = <String>[];
  final client = MockClient((req) async {
    asked.add('${req.method} ${req.url.path}');
    if (req.url.path == '/lessons/9/video') {
      // No link to open: a test has no platform to open it in.
      return http.Response(jsonEncode({'error': 'Not yet.'}), 404);
    }
    return http.Response('{}', 200);
  });
  final actions = TutorialRowActions(
    lessonApi: LessonApiService(authToken: 't', client: client),
    assignmentApi: AssignmentApiService(authToken: 't', client: client),
    groupApi: GroupApiService(client: client),
  );
  final row = <String, dynamic>{
    'id': 9,
    'title': 'Lucena',
    'has_video': hasVideo,
  };
  bool? result;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await actions.delete(context, row),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();

  expect(find.textContaining(_videoSentence),
      hasVideo ? findsOneWidget : findsNothing);
  expect(find.byKey(const ValueKey('tutorial-delete-download-first')),
      hasVideo ? findsOneWidget : findsNothing);

  await tester.tap(press == 'download'
      ? find.byKey(const ValueKey('tutorial-delete-download-first'))
      : find.widgetWithText(TextButton, press));
  await tester.pumpAndSettle();
  expect(result, press == 'Delete',
      reason: 'the caller was told the row is gone when it is not, or the '
          'other way round');
  return asked;
}

void main() {
  testWidgets('a tutorial with a video says it goes too', (tester) async {
    final asked = await _deleteWith(tester, hasVideo: true, press: 'Delete');
    expect(asked, ['DELETE /lessons/9']);
  });

  testWidgets('„Download video" fetches the film and deletes nothing',
      (tester) async {
    final asked = await _deleteWith(tester, hasVideo: true, press: 'download');
    expect(asked, ['GET /lessons/9/video'],
        reason: 'the download was not asked for, or the tutorial was deleted');
  });

  testWidgets('a tutorial with no video is asked about as before',
      (tester) async {
    final asked = await _deleteWith(tester, hasVideo: false, press: 'Delete');
    expect(asked, ['DELETE /lessons/9']);
  });

  testWidgets('„Cancel" sends nothing', (tester) async {
    final asked = await _deleteWith(tester, hasVideo: true, press: 'Cancel');
    expect(asked, isEmpty);
  });
}
