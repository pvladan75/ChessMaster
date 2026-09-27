/// „Make a tutorial" from a recording — the doors of phase 8 of
/// `docs/PLAN-PRIPREMA.md`.
///
/// The core (`recording_tutorial.dart`) turns a recording into a tutorial and
/// says where each beat begins in its sound; the server copies the sound
/// itself (`POST /lessons/:id/narration/from-recording`, T4: the app never
/// uploads it). **This file composes nothing of its own** — the tutorial
/// saved is the core's `draft.positionList`, the voice's body is its
/// `markersMs`, `beats` and `signature` — it only asks, in order, and says
/// what came back.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/services/recording_tutorial.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/recording_transcript_api.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Recordings a tutorial is being made from right now, by id.
///
/// **The guard against a second start.** Module-level rather than a widget's
/// state, because the door is drawn twice (the Library card, the player) and
/// either can be tapped twice before the first request answers — the double
/// „Record" of phase 3, the double „Start" of 22.9.2026. Set before the first
/// `await` of every call, so a guard that waits for the thing to exist cannot
/// itself be the gap it is meant to close.
final Set<int> _inFlight = <int>{};

/// Makes a tutorial of the recording [recordingId], asks it questions on the
/// way where it must, and opens the Tutorial Studio on what was made.
///
/// Returns the new tutorial's id, or null when none was made — refused,
/// cancelled, or a second call for a recording whose first is still running.
Future<int?> makeTutorialFromRecording(
  BuildContext context, {
  required UserSession session,
  required int recordingId,
  required http.Client client,
}) async {
  if (!_inFlight.add(recordingId)) return null;
  try {
    return await _run(context,
        session: session, recordingId: recordingId, client: client);
  } finally {
    _inFlight.remove(recordingId);
  }
}

Future<int?> _run(
  BuildContext context, {
  required UserSession session,
  required int recordingId,
  required http.Client client,
}) async {
  final headers = {
    'Authorization': 'Bearer ${session.token}',
    'Content-Type': 'application/json',
  };

  final recRes = await client.get(
    Uri.parse('$backendUrl/recordings/$recordingId'),
    headers: headers,
  );
  final recJson = _decoded(recRes);
  if (recJson == null) {
    if (context.mounted) {
      AppFeedback.error(context, 'Could not read that recording.');
    }
    return null;
  }
  final recording = SessionRecording.fromJson(recJson);
  if (recording.source != 'preparation') {
    if (context.mounted) {
      AppFeedback.error(context,
          'Only a lesson recorded in Preparation can become a tutorial.');
    }
    return null;
  }

  final transcriptApi =
      RecordingTranscriptApi(authToken: session.token, client: client);
  final availability = await transcriptApi.fetch(recordingId);
  if (!context.mounted) return null;

  final transcript = availability.transcript;
  if (transcript == null) {
    final withoutWords = await _askWithoutWords(context);
    if (withoutWords != true || !context.mounted) return null;
  }

  final RecordingTutorial core;
  try {
    core = recordingTutorialOf(
      events: recording.timelineEvents,
      durationMs: recording.durationMs ?? 0,
      sentences: transcript?.sentences ?? const [],
      title: recording.title,
      language: transcript?.language,
    );
  } on RecordingTutorialRefused catch (e) {
    if (context.mounted) AppFeedback.error(context, e.reason);
    return null;
  }

  if (!context.mounted) return null;
  final closeProgress = _showProgress(context);
  final api = LessonApiService(authToken: session.token, client: client);

  final LessonWriteResult saved;
  try {
    saved = await api.saveTutorial(
      title: recording.title,
      positionList: core.draft.positionList,
      language: LanguageWrite.of(transcript?.language),
    );
  } finally {
    await closeProgress();
  }
  if (!context.mounted) return saved.ok ? saved.id : null;
  if (!saved.ok || saved.id == null) {
    AppFeedback.error(context, saved.error ?? 'Could not save the tutorial.');
    return null;
  }
  final lessonId = saved.id!;

  final voice = await api.attachRecordingVoice(
    lessonId: lessonId,
    recordingId: recordingId,
    markersMs: core.markersMs,
    beats: core.beats,
    signature: core.signature,
  );
  if (!context.mounted) return lessonId;

  final lesson = {
    'id': lessonId,
    'title': saved.title ?? recording.title,
    'language': saved.language,
    'position_list': saved.steps,
  };
  // Do the thing, then say it: a refused voice leaves the tutorial made, so
  // the studio opens either way. Not awaited — awaiting the push would wait
  // for the studio to be closed before the voice's own message could show.
  unawaited(
      openTutorialEditor(context, session: session, api: api, lesson: lesson));
  if (!voice.ok && context.mounted) {
    AppFeedback.error(
        context,
        'The tutorial was made without your voice. ${voice.error ?? ''}'
            .trim());
  }
  return lessonId;
}

Map<String, dynamic>? _decoded(http.Response res) {
  if (res.statusCode != 200) return null;
  try {
    final body = jsonDecode(res.body);
    return body is Map ? Map<String, dynamic>.from(body) : null;
  } catch (_) {
    return null;
  }
}

/// „This recording has no transcript." — asked once, before anything is made.
///
/// Answers true for „Make it without words", false or null for „Cancel" and
/// for a dialog dismissed any other way.
Future<bool?> _askWithoutWords(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No transcript'),
        content: Text(
          'This recording has no transcript. Made without words, the '
          'tutorial will still have its moves and your voice, but no words.',
          style: AppText.body.copyWith(color: ctx.colors.textPrimary),
        ),
        actions: [
          TextButton(
            key: const Key('recording-tutorial-cancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('recording-tutorial-without-words'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Make it without words'),
          ),
        ],
      ),
    );

/// A dialog that cannot be dismissed while the tutorial is made. Returns a
/// function that closes it, safe to call more than once.
Future<void> Function() _showProgress(BuildContext context) {
  var closed = false;
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Making the tutorial…',
              style: AppText.body.copyWith(color: ctx.colors.textPrimary)),
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
