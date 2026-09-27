/// „Translate…" on a tutorial — the doors of phase 9 of
/// `docs/PLAN-PRIPREMA.md`.
///
/// The server does the whole thing (`POST /lessons/:id/translate`,
/// `chess_backend/routes/lessonTranslation.js`): it asks the model to
/// translate every part's words, checks the answer, asks again once if it
/// failed the checks, and writes a **new** tutorial — the source is never
/// touched. This file only asks which language, sends the request, and opens
/// what came back.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Tutorials being translated right now, by id.
///
/// **The guard against a second start**, set before the first `await` of
/// every call — the same shape as `recording_tutorial_flow.dart`'s
/// `_inFlight`, and for the same reason: the door is drawn in more than one
/// place (the Library card, the studio's Details sheet) and either can be
/// tapped twice before the first request answers.
final Set<int> _inFlight = <int>{};

/// Translates the tutorial [lessonId] into a language the trainer chooses,
/// and opens the copy the server makes of it.
///
/// Returns the copy's id, or null when nothing was made — cancelled, refused,
/// or a second call for a tutorial whose first is still running.
Future<int?> translateTutorialCopy(
  BuildContext context, {
  required UserSession session,
  required int lessonId,
  required String? language,
  required LessonApiService api,
}) async {
  if (!_inFlight.add(lessonId)) return null;
  try {
    return await _run(context,
        session: session, lessonId: lessonId, language: language, api: api);
  } finally {
    _inFlight.remove(lessonId);
  }
}

Future<int?> _run(
  BuildContext context, {
  required UserSession session,
  required int lessonId,
  required String? language,
  required LessonApiService api,
}) async {
  final chosen = await _chooseLanguage(context,
      lessonId: lessonId, currentLanguage: language);
  if (chosen == null || !context.mounted) return null;

  final closeProgress = _showProgress(context);
  final LessonWriteResult result;
  try {
    result =
        await api.translateTutorial(lessonId: lessonId, language: chosen.code);
  } finally {
    await closeProgress();
  }
  if (!context.mounted) return null;

  if (!result.ok || result.id == null) {
    AppFeedback.error(
        context, result.error ?? 'Could not translate the tutorial.');
    return null;
  }

  final newId = result.id!;
  final lesson = {
    'id': newId,
    'title': result.title,
    'language': result.language,
    'position_list': result.steps,
  };
  // Not awaited: `Navigator.push`'s future completes when the pushed screen
  // is later popped, not when it is drawn — awaiting it here would hold this
  // whole flow open until the trainer leaves the studio again.
  unawaited(
      openTutorialEditor(context, session: session, api: api, lesson: lesson));
  AppFeedback.success(context, 'Translated into ${chosen.label}.');
  return newId;
}

/// „Translate into…" — every [TutorialLanguage] the tutorial is not already
/// in (all seven when it says none), one chosen at a time.
///
/// Wrapped in [_GuardRelease]: `Navigator.pop` completes this dialog's own
/// Future, but a screen torn down while the dialog is still open — the
/// trainer navigating away, or a test tree replaced wholesale — never pops
/// it, and that Future then never completes at all. A widget's `dispose`
/// fires either way, so the guard against a second start is released there
/// rather than only where this function returns.
Future<TutorialLanguage?> _chooseLanguage(
  BuildContext context, {
  required int lessonId,
  required String? currentLanguage,
}) {
  final offered = [
    for (final language in TutorialLanguage.all)
      if (language.code != currentLanguage) language,
  ];
  TutorialLanguage? chosen;
  return showDialog<TutorialLanguage>(
    context: context,
    builder: (dialogContext) => _GuardRelease(
      lessonId: lessonId,
      child: StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Translate into…'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The tutorial\'s words are sent to DeepSeek to be '
                  'translated. The translation is a copy — the tutorial '
                  'itself is not changed.',
                  style: AppText.body
                      .copyWith(color: dialogContext.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                // `RadioGroup` rather than a `groupValue` on every tile,
                // which is deprecated.
                RadioGroup<TutorialLanguage>(
                  groupValue: chosen,
                  onChanged: (value) => setState(() => chosen = value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final language in offered)
                        RadioListTile<TutorialLanguage>(
                          key: Key('translate-language-${language.code}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(language.label),
                          value: language,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('translate-cancel'),
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('translate-start'),
              onPressed: chosen == null
                  ? null
                  : () => Navigator.pop(dialogContext, chosen),
              child: const Text('Translate'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Releases [_inFlight]'s hold on [lessonId] as soon as this leaves the
/// tree, whatever took it out — an answer, a cancel, or the screen beneath
/// it disappearing while it was still open. See [_chooseLanguage].
class _GuardRelease extends StatefulWidget {
  const _GuardRelease({required this.lessonId, required this.child});

  final int lessonId;
  final Widget child;

  @override
  State<_GuardRelease> createState() => _GuardReleaseState();
}

class _GuardReleaseState extends State<_GuardRelease> {
  @override
  void dispose() {
    _inFlight.remove(widget.lessonId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A dialog that cannot be dismissed while the translation runs. Returns a
/// function that closes it, safe to call more than once.
Future<void> Function() _showProgress(BuildContext context) {
  var closed = false;
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Translating…',
              style: AppText.body
                  .copyWith(color: dialogContext.colors.textPrimary)),
        ],
      ),
    ),
  );
  return () async {
    if (closed) return;
    closed = true;
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await dialog;
    }
  };
}
