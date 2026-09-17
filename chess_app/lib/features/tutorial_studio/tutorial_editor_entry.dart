import 'package:flutter/material.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/models/user_session.dart';

/// The one door to editing a saved tutorial.
///
/// Decision 5 of `docs/PLAN-TUTORIJAL.md` made the Tutorial Studio
/// Windows-only and kept a second, simpler editor for everywhere else,
/// because the studio's layout assumed a wide screen. §7.3 of
/// `docs/PLAN-REORGANIZACIJA.md` reversed that on 17.9.2026: the studio's
/// state moved into `TutorialDraftController` and a phone layout was built
/// over the same controller, so nothing is platform-bound in the studio any
/// more. The second editor and the platform guard are retired, and this door
/// opens the studio unconditionally.
Future<void> openTutorialEditor(
  BuildContext context, {
  required UserSession session,
  required LessonApiService api,
  required Map<String, dynamic> lesson,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => TutorialStudioScreen(
      session: session,
      entry: TutorialEntry.saved(lesson),
      lessonApi: api,
    ),
  ));
}
