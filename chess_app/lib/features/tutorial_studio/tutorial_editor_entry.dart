import 'package:flutter/material.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/lessons/widgets/lesson_step_editor_panel.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/models/user_session.dart';

/// The one door to editing a saved tutorial, and the one place that decides
/// which editor opens.
///
/// D8 of `docs/PLAN-STUDIO-REDIZAJN.md`. On Windows the studio is the editor and
/// `LessonStepEditorPanel` is never drawn; everywhere else the panel stays,
/// frozen, because it is reachable from the library and from the room on
/// **every** platform — and deleting it outright would remove tutorial editing
/// from Android altogether, a capability loss nobody asked for dressed up as
/// tidying. The double work the owner met is a desktop problem and it disappears
/// completely on the desktop.
///
/// **One predicate, one door.** Both callers used to build the panel themselves,
/// so the platform question would have had to be written twice — and a
/// condition written twice is the fault this repository has paid for more than
/// once. Deleting the panel later is now one edit here.
///
/// Nothing is unlinked until its refusals are proved somewhere else: the studio
/// makes all of §7's, and `test/tutorial_studio_refusals_test.dart` is the
/// proof.
Future<void> openTutorialEditor(
  BuildContext context, {
  required UserSession session,
  required LessonApiService api,
  required Map<String, dynamic> lesson,
}) {
  if (isTutorialStudioAvailable) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lesson),
        lessonApi: api,
      ),
    ));
  }

  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(
        title: Text(lesson['title']?.toString() ?? 'Koraci tutorijala'),
      ),
      body: LessonStepEditorPanel(
        session: session,
        api: api,
        lesson: lesson,
      ),
    ),
  ));
}
