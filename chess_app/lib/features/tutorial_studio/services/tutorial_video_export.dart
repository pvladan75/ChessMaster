// tutorial_video_export.dart — one owner for „make a video of this tutorial".
//
// It is asked for from two places and they must not be two features: the saved
// tutorials list, where a trainer who wants the file goes, and the studio,
// where the tutorial is written and where the owner asked for it on 9.9.2026 —
// „bilo bi dobro da dijalog za renderovanje premestimo tamo gde se tutorijal
// pravi".
//
// So the refusals, the narration options, the request and the finished dialog
// live here, and both screens call one function. The alternative is the same
// sentence written twice and drifting apart on the third change.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_storage.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// What the trainer last chose, kept per trainer rather than per tutorial.
///
/// **Per tutorial would be better and costs a column.** A trainer whose
/// material is all in one language never notices the difference; one writing in
/// two would, and the day that happens `saved_lessons` gains a
/// `narration_voice` and this reads it as a default rather than as the answer.
/// Written down so the next person meets a decision rather than an oversight.
const _narrateKey = 'tutorial_video_narrate';
const _voiceKey = 'tutorial_video_voice';

/// Whether the last export asked for 1080p. Remembered for the same reason the
/// voice is: a trainer who publishes to YouTube publishes to it every time.
const _hdKey = 'tutorial_video_hd';

/// The two resolutions offered, and why there are two rather than three.
///
/// 720p is what a video watched on a phone wants, and it is the default. 1080p
/// exists for the one case that is genuinely different — a video put on
/// YouTube, which gives a 720p upload a lower bitrate ladder than a 1080p one,
/// and the caption text and the thin piece outlines are the first things to go
/// — and for a classroom projector. Measured on an eighteen-second film: 1.2 s
/// and 129 KB at 720p against 2.5 s and 192 KB at 1080p.
///
/// 480p is offered by the recorded-lesson dialog and deliberately not here. It
/// saves about 30 KB on that film, because this is flat graphics on flat colour
/// and h.264 has almost nothing to compress, and it pays for it in the one
/// thing that matters: the caption a child reads.
const _standardResolution = '720p';
const _highResolution = '1080p';

/// Make a video of [draft], asking about the voice first when there is one.
///
/// Returns true when a file was produced. Every refusal is a sentence through
/// `AppFeedback` and nothing is sent: an empty tutorial renders no frames, and
/// ffmpeg given no frames fails with a message about a pipe rather than about a
/// tutorial.
Future<bool> exportTutorialVideo({
  required BuildContext context,
  required LessonApiService api,
  required int lessonId,
  required String title,
  required TutorialDraft draft,

  /// Where this device keeps recorded takes. Null means the app's own place;
  /// tests hand in a directory.
  NarrationTakeStore? narrationStore,
}) async {
  final video = tutorialVideoOf(draft);

  if (!_hasSomethingToShow(draft) || !canRenderVideo(video)) {
    AppFeedback.info(context, 'This tutorial has nothing to show yet.');
    return false;
  }
  if (!fitsInOneFilm(video)) {
    AppFeedback.info(
      context,
      'This tutorial is too long to render as one video (${video.seconds}s).',
    );
    return false;
  }

  // The trainer's own recording, if this device has one for this tutorial —
  // judged here the way the server will judge it, so a take that cannot be used
  // is explained beside the switch rather than refused after an upload.
  //
  // **Started, not awaited.** The dialog opens at once and the row appears when
  // the answer does, a few milliseconds later. Awaiting it put a platform call
  // for the app's folder in front of the dialog, and a dialog that waits on a
  // folder it may not need is one that does not open when that call does not
  // return — which is exactly what a widget test's clock does to it.
  //
  // The signature is walked once here and travels with everything that judges
  // the take: the dialog, the upload, and the render request.
  final signature = filmSignatureOf(filmBeatsOf(draft));
  final recording = _recordingFor(
    narrationStore ?? deviceNarrationStore(),
    lessonId,
    video.events.length,
    signature,
  );

  // Asked before anything is drawn on screen: a switch the server cannot honour
  // must not be offered, and a trainer who turns narration on and waits two
  // minutes for a refusal has been lied to by the interface.
  final tts = await api.fetchTtsVoices();
  if (!context.mounted) return false;

  final canSpeak = tts.available && tts.voices.isNotEmpty;
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return false;

  var narrate = true;
  String? voice;
  if (canSpeak) {
    narrate = prefs.getBool(_narrateKey) ?? true;
    final saved = prefs.getString(_voiceKey);
    final known =
        tts.voices.any((v) => (v['id'] ?? v['name'])?.toString() == saved);
    voice = known
        ? saved
        : (tts.voices.first['id'] ?? tts.voices.first['name'])?.toString();
  }
  var hd = prefs.getBool(_hdKey) ?? false;

  // Asked even where the server cannot speak: the quality is always a choice,
  // and a switch reachable only where piper is installed is a switch half the
  // trainers do not have.
  final chosen = await _askAboutExport(
    context: context,
    recording: recording,
    voices: canSpeak ? tts.voices : const [],
    narrate: narrate,
    voice: voice,
    hd: hd,
    onPreview: (wantsHd) => _showPreview(
      context: context,
      api: api,
      lessonId: lessonId,
      title: title,
      video: video,
      look: _lookOf(context),
      resolution: wantsHd ? _highResolution : _standardResolution,
    ),
  );
  if (chosen == null) return false; // cancelled, and nothing was sent
  hd = chosen.hd;
  await prefs.setBool(_hdKey, hd);
  if (canSpeak) {
    narrate = chosen.narrate;
    voice = chosen.voice;
    await prefs.setBool(_narrateKey, narrate);
    if (voice != null) await prefs.setString(_voiceKey, voice);
  }

  // Sent once per take: the server keeps the take's id beside the file, so the
  // export of a tutorial whose recording is already there sends only the
  // request.
  final mine = chosen.recording;
  if (mine != null) {
    if (!context.mounted) return false;
    final sent = await _sendRecordingIfNeeded(
      context: context,
      api: api,
      lessonId: lessonId,
      stored: mine,
      signature: signature,
    );
    if (!sent) return false;
  }

  if (!context.mounted) return false;
  final look = _lookOf(context);

  // The client names its own render so it can watch it. The export request and
  // the polling run side by side: the render happens *inside* that request, so
  // there is no job queue behind this and nothing to clean up if the app is
  // closed halfway.
  final jobId = 'job${DateTime.now().millisecondsSinceEpoch}'
      '${Random().nextInt(1 << 20)}';

  final render = api.exportVideo(
    lessonId: lessonId,
    events: video.events,
    seconds: video.seconds,
    title: title,
    look: look,
    resolution: hd ? _highResolution : _standardResolution,
    jobId: jobId,
    // The recording and a synthesised voice are two answers to one question,
    // and a film is never sent both.
    narrate: mine == null && canSpeak ? narrate : null,
    voice: mine == null && canSpeak ? voice : null,
    useRecording: mine == null ? null : true,
    takeId: mine?.takeId,
    // Asked of the server as well, and for a reason this dialog cannot cover:
    // the take on the server may have been recorded on another device, against
    // beats that have moved since. See `recordingForFilm`.
    signature: mine == null ? null : signature,
  );

  final result = await _showProgressWhile(
    context: context,
    api: api,
    jobId: jobId,
    render: render,
  );
  if (!context.mounted) return false;

  if (!result.ok) {
    AppFeedback.error(context, result.error ?? 'Video export failed.');
    return false;
  }

  await _showReady(
    context,
    result.message ??
        'Video rendered successfully, saved, and ready for download!',
    result.downloadUrl == null ? null : resolveMediaUrl(result.downloadUrl!),
  );
  return true;
}

/// Whether this tutorial has anything a film could be made of.
///
/// **Not the same question as `canRenderVideo`**, and the difference is a real
/// one that was hiding in the saved-tutorials list as a special case for a row
/// with no steps. A draft with a single untouched board still produces one
/// `init` event and a two-second dwell, so the film is technically renderable —
/// two seconds of an empty starting position with nothing said over it. Nobody
/// wants that file, and the server would charge a render for it.
///
/// A part counts when it has moves, or words, or something drawn on it: „look
/// at the d5 square" with an arrow and no moves is a whole tutorial.
bool _hasSomethingToShow(TutorialDraft draft) {
  return draft.sections.any((section) {
    final root = section.root;
    return root.children.isNotEmpty ||
        root.comment.trim().isNotEmpty ||
        root.arrows.isNotEmpty ||
        root.squares.isNotEmpty ||
        (section.instruction?.trim().isNotEmpty ?? false);
  });
}

/// The app's own look, as the renderer takes it.
///
/// **Colours, not names.** The server used to be told „wood" and keep its own
/// idea of what wood is; the app has five board skins, three piece skins and a
/// light and a dark theme, and none of that survives a name. What travels is
/// what the trainer is looking at while they write, so the film they get back
/// is the screen they wrote it on.
///
/// The theme comes from the widget's own colours rather than from
/// `AppSettingsService.themeMode`, because `system` is not an answer — only the
/// resolved theme knows whether this device is light or dark right now.
Map<String, String> _lookOf(BuildContext context) {
  final board = AppSettingsService.instance.boardSkin;
  final pieces = AppSettingsService.instance.pieceSkin;
  final colors = context.colors;

  String hex(Color c) =>
      '#${((c.a * 255).round() << 24 | (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(8, '0').substring(2)}';

  return {
    'lightSquare': hex(board.lightSquare),
    'darkSquare': hex(board.darkSquare),
    'background': hex(colors.canvas),
    'text': hex(colors.textPrimary),
    'accent': hex(colors.accent),
    'whiteFill': hex(pieces.whiteFill),
    'whiteStroke': hex(pieces.whiteStroke),
    'blackFill': hex(pieces.blackFill),
    'blackStroke': hex(pieces.blackStroke),
    'blackDecoration': hex(pieces.blackDecoration),
  };
}

/// A modal bar that follows the render, and closes itself when it answers.
///
/// **Determinate, because the server actually knows.** The renderer draws a
/// known number of frames and reports each one, so this is a real percentage
/// rather than a spinner pretending to be one — „nema info o tome" was the
/// report, and a bar that moves at a made-up speed would have been the same
/// complaint with more pixels.
///
/// It stops at 99 until the export answers: the frames are drawn well before
/// ffmpeg has finished writing the file, and a bar that sits full while the app
/// still waits is worse than one that visibly has something left to do.
Future<LessonExportVideoResult> _showProgressWhile({
  required BuildContext context,
  required LessonApiService api,
  required String jobId,
  required Future<LessonExportVideoResult> render,
}) async {
  var percent = 0;
  int? etaSeconds;
  var queuedAhead = 0;
  void Function(void Function())? refresh;
  var closed = false;

  final poller = Timer.periodic(const Duration(milliseconds: 900), (_) async {
    final at = await api.renderProgress(jobId);
    if (at == null || refresh == null) return;
    // The bar never walks backwards: a poll that answers with an older reading
    // than the one on screen is a poll that raced, not a render that undid
    // itself. The estimate does follow the newest reading, because it is
    // supposed to fall as the render goes.
    if (at.percent < percent) return;
    refresh!(() {
      percent = at.percent;
      etaSeconds = at.etaSeconds;
      queuedAhead = at.queuedAhead;
    });
  });

  // Not dismissible: cancelling the dialog would not cancel the render, and a
  // screen that lets you dismiss work it cannot stop is lying about what the
  // button does.
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        refresh = setLocal;
        return AlertDialog(
          title: const Text('Exporting video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                // Indeterminate while it waits: a bar at 0 % that is not moving
                // says the render has begun and stalled, which is the one thing
                // it has not done.
                value: queuedAhead > 0 || percent <= 0 ? null : percent / 100,
                minHeight: 6,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                queuedAhead > 0
                    ? waitingText(queuedAhead)
                    : (percent <= 0
                        ? 'Starting…'
                        : '$percent%${remainingText(etaSeconds)}'),
                style: AppText.body.copyWith(color: ctx.colors.textSecondary),
              ),
            ],
          ),
        );
      },
    ),
  );

  try {
    return await render;
  } finally {
    poller.cancel();
    if (!closed && context.mounted) {
      closed = true;
      Navigator.of(context, rootNavigator: true).pop();
      await dialog;
    }
  }
}

/// „Your video will start rendering shortly", and how many are in front of it.
///
/// The server draws one film at a time — two side by side share one CPU and
/// finish together, both late — so an export can spend its first stretch
/// waiting for the machine. That is not a stalled render and must not look like
/// one: „Starting…" over an empty bar is exactly what a render that had begun
/// and frozen would show.
String waitingText(int ahead) {
  if (ahead <= 0) return 'Starting…';
  final films = ahead == 1 ? 'one video' : '$ahead videos';
  return 'Your video will start rendering shortly — $films ahead of it.';
}

/// „about a minute left", or nothing at all.
///
/// Rounded to something a person reads at a glance, and never precise: the
/// number comes from the frames drawn so far, and a render that says „37 s" and
/// takes 50 has been more wrong than one that said „about a minute". Under ten
/// seconds it stops counting down and says the work is nearly done, because a
/// last-second countdown is a promise the ffmpeg tail cannot keep.
String remainingText(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  if (seconds < 10) return ' · almost done';
  // Rounded first and compared afterwards: 59 s rounds to 60, and „about 60 s
  // left" is a number nobody writes.
  final tenSeconds = (seconds / 10).round() * 10;
  if (tenSeconds < 60) return ' · about $tenSeconds s left';
  final minutes = (seconds / 60).round();
  return ' · about $minutes ${minutes == 1 ? 'minute' : 'minutes'} left';
}

/// Three stills of the film, drawn by the server without rendering one.
///
/// **Nothing here is a second drawing of anything.** The frames are the film's
/// own — same events, same renderer, same caption layout — which is the only
/// reason a preview can be trusted to answer „is this what I will get".
Future<void> _showPreview({
  required BuildContext context,
  required LessonApiService api,
  required int lessonId,
  required String title,
  required TutorialVideo video,
  required Map<String, String> look,
  required String resolution,
}) async {
  final result = await api.previewFrames(
    lessonId: lessonId,
    events: video.events,
    seconds: video.seconds,
    title: title,
    look: look,
    resolution: resolution,
  );
  if (!context.mounted) return;

  if (!result.ok) {
    AppFeedback.error(context, result.error ?? 'Preview failed.');
    return;
  }

  var at = 0;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        key: const Key('preview-dialog'),
        title: Text('Preview · $resolution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The frame itself, sized by the dialog rather than by the image:
            // a 1080p still is 1920 px wide and a phone is not.
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(
                  result.frames[at],
                  key: ValueKey('preview-frame-$at'),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
            if (result.frames.length > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const Key('preview-back'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: at == 0 ? null : () => setLocal(() => at -= 1),
                  ),
                  Text('${at + 1} / ${result.frames.length}',
                      style: AppText.body
                          .copyWith(color: ctx.colors.textSecondary)),
                  IconButton(
                    key: const Key('preview-next'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: at == result.frames.length - 1
                        ? null
                        : () => setLocal(() => at += 1),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Stills of the opening, the middle and the end. Nothing was '
              'rendered and nothing counted against your quota.',
              style: AppText.caption.copyWith(color: ctx.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('preview-close'),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}

class _ExportChoice {
  const _ExportChoice(this.narrate, this.voice, this.hd, this.recording);
  final bool narrate;
  final String? voice;
  final bool hd;

  /// The trainer's own take, when that is the voice chosen — the take itself
  /// rather than a yes, so what is sent is what the dialog showed.
  final StoredNarration? recording;
}

/// A take on this device, and whether a film can be made of it.
class _Recording {
  const _Recording.usable(StoredNarration this.stored) : unusable = null;
  const _Recording.unusable(String this.unusable) : stored = null;
  final StoredNarration? stored;
  final String? unusable;
}

/// This tutorial's take on this device, or null when there is none — or no
/// directory to look in, which is not this dialog's fault to report.
Future<_Recording?> _recordingFor(
    NarrationTakeStore store, int lessonId, int beats, String signature) async {
  final NarrationLoad load;
  try {
    load = await store.load(lessonId);
  } catch (e) {
    debugPrint('[Export] Could not look for a recording: $e');
    return null;
  }
  if (load.unreadable) {
    return const _Recording.unusable(
        'Your recording on this device could not be read. Record it again.');
  }
  final stored = load.stored;
  if (stored == null) return null;

  // One decision, in `takeMismatchOf`, so this dialog and the recording screen
  // cannot come to disagree about whether a take is still the right one.
  final take = stored.take;
  return switch (takeMismatchOf(take, beats: beats, signature: signature)) {
    TakeMismatch.none => _Recording.usable(stored),
    TakeMismatch.silent => const _Recording.unusable(
        'Your recording is silent — nothing reached the microphone. Record '
        'it again.'),
    TakeMismatch.beatsChanged => _Recording.unusable(
        'Your recording was made when the tutorial had ${take.eventCount} '
        'beats, and it has $beats now. Record it again.'),
    TakeMismatch.edited => const _Recording.unusable(
        'The tutorial has been edited since your recording was made, so it no '
        'longer follows it. Record it again, or export without your voice.'),
    TakeMismatch.incomplete => _Recording.unusable(
        'Your recording stops at beat ${take.markersMs.length} of '
        '${take.eventCount}. Record it again to the end.'),
  };
}

/// Uploads [stored] unless the server already holds this very take.
///
/// Asked by the take's id rather than remembered on this device: the server
/// may have lost it, another device may have replaced it, and „I sent it once"
/// is the version of this that goes stale. When the server cannot be asked the
/// take is sent — a second upload replaces the first and costs bandwidth, where
/// guessing wrong the other way costs a film without the voice.
Future<bool> _sendRecordingIfNeeded({
  required BuildContext context,
  required LessonApiService api,
  required int lessonId,
  required StoredNarration stored,
  required String signature,
}) async {
  final local = stored.takeId;
  final onServer = await api.serverTakeId(lessonId);
  if (local != null && onServer == local) return true;
  if (!context.mounted) return false;

  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Uploading your recording'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinearProgressIndicator(minHeight: 6),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${narrationClockOf(stored.take.durationMs)} of audio. It is sent '
            'once for each recording.',
            style: AppText.body.copyWith(color: ctx.colors.textSecondary),
          ),
        ],
      ),
    ),
  );

  final NarrationUploadResult result;
  try {
    result = await api.uploadNarration(
      lessonId: lessonId,
      audioPath: stored.audioPath,
      markersMs: stored.take.markersMs,
      durationMs: stored.take.durationMs,
      beats: stored.take.eventCount,
      takeId: local,
      signature: signature,
    );
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await dialog;
    }
  }

  if (!result.ok) {
    if (context.mounted) {
      AppFeedback.error(
          context, result.error ?? 'Your recording could not be uploaded.');
    }
    return false;
  }
  return true;
}

/// What to ask before a render: the voice, where there is one, and the quality.
///
/// An empty [voices] means the server cannot speak, and then the narration half
/// is not drawn at all — a switch that cannot be honoured must not be offered.
/// The sheet still opens, because the quality is a choice everywhere.
Future<_ExportChoice?> _askAboutExport({
  required BuildContext context,

  /// The lookup for this device's take: offered when it can be used, explained
  /// when it cannot, and neither while the lookup has not answered or found
  /// nothing.
  required Future<_Recording?> recording,
  required List<Map<String, dynamic>> voices,
  required bool narrate,
  required String? voice,
  required bool hd,

  /// Draws three stills of the film at the resolution now chosen, without
  /// rendering anything. The sheet stays open behind it: a preview is a look,
  /// not a decision.
  required Future<void> Function(bool hd) onPreview,
}) {
  var wants = narrate;
  var chosen = voice;
  var wantsHd = hd;
  var previewing = false;
  // The take, once the lookup answers. On by default where there is one to
  // use: a trainer who recorded their voice over a tutorial and exports it
  // wants that voice.
  _Recording? found;
  var useMine = false;
  void Function(void Function())? refresh;
  var closed = false;
  unawaited(recording.then((answer) {
    if (closed) return;
    found = answer;
    useMine = answer?.stored != null;
    refresh?.call(() {});
  }));

  return showDialog<_ExportChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        refresh = setLocal;
        return AlertDialog(
          title: const Text('Export video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (found?.stored != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          'Use my recording '
                          '(${narrationClockOf(found!.stored!.take.durationMs)})',
                          style: AppText.bodyBold
                              .copyWith(color: ctx.colors.textPrimary)),
                    ),
                    Switch(
                      key: const Key('export-use-recording'),
                      value: useMine,
                      activeThumbColor: ctx.colors.accent,
                      onChanged: (v) => setLocal(() => useMine = v),
                    ),
                  ],
                ),
                Text(
                  useMine
                      ? 'Your own voice, and the board moves where you pressed '
                          'Space.'
                      : 'The video goes out without your recording.',
                  style: AppText.caption.copyWith(color: ctx.colors.textMuted),
                ),
              ],
              if (found?.unusable != null)
                Row(
                  key: const Key('export-recording-unusable'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: ctx.colors.warning, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(found!.unusable!,
                          style: AppText.body
                              .copyWith(color: ctx.colors.textPrimary)),
                    ),
                  ],
                ),
              if (found != null && voices.isNotEmpty && !useMine)
                const Divider(),
              if (voices.isNotEmpty && !useMine)
                Row(
                  children: [
                    Expanded(
                      child: Text('Narrate this video',
                          style: AppText.bodyBold
                              .copyWith(color: ctx.colors.textPrimary)),
                    ),
                    Switch(
                      value: wants,
                      activeThumbColor: ctx.colors.accent,
                      onChanged: (v) => setLocal(() => wants = v),
                    ),
                  ],
                ),
              if (voices.isNotEmpty && wants && !useMine) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text('Voice',
                        style: AppText.body
                            .copyWith(color: ctx.colors.textSecondary)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: chosen,
                          dropdownColor: ctx.colors.surface,
                          items: [
                            for (final v in voices)
                              DropdownMenuItem<String>(
                                value: (v['id'] ?? v['name'])?.toString() ?? '',
                                child: Text(
                                  _voiceLabel(v),
                                  style: AppText.body
                                      .copyWith(color: ctx.colors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setLocal(() => chosen = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('A narrated export takes longer.',
                    style:
                        AppText.caption.copyWith(color: ctx.colors.textMuted)),
              ],
              if (found != null || voices.isNotEmpty) const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text('Higher quality (1080p)',
                        style: AppText.bodyBold
                            .copyWith(color: ctx.colors.textPrimary)),
                  ),
                  Switch(
                    value: wantsHd,
                    activeThumbColor: ctx.colors.accent,
                    onChanged: (v) => setLocal(() => wantsHd = v),
                  ),
                ],
              ),
              Text(
                wantsHd
                    ? 'For YouTube or a projector. Slower to render, larger file.'
                    : '720p, which is what a video watched on a phone wants.',
                style: AppText.caption.copyWith(color: ctx.colors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            // **Before the render, not after it.** A film costs tens of seconds
            // of the one render slot, and until this the only way to find out
            // that a part stood the wrong way round, or that a sentence is too
            // long for the caption band, was to render the whole thing.
            TextButton.icon(
              key: const Key('export-preview'),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Preview'),
              onPressed: previewing
                  ? null
                  : () async {
                      setLocal(() => previewing = true);
                      try {
                        await onPreview(wantsHd);
                      } finally {
                        // The sheet is still the one the trainer is standing in, so it
                        // is still the one that has to stop saying „…".
                        if (ctx.mounted) setLocal(() => previewing = false);
                      }
                    },
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx,
                  _ExportChoice(
                      wants, chosen, wantsHd, useMine ? found?.stored : null)),
              child: const Text('Export'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() => closed = true);
}

/// „en_US-lessac-medium" reads as „en-US · lessac (medium)".
///
/// The language first, because that is what a trainer is choosing: the voice
/// has to match the language they wrote in, and nothing here detects it.
String _voiceLabel(Map<String, dynamic> voice) {
  final id = (voice['id'] ?? voice['name'])?.toString() ?? '';
  final language = voice['language']?.toString() ?? '';
  final tier = voice['tier']?.toString() ?? '';
  final speaker = id.contains('-')
      ? id.substring(id.indexOf('-') + 1).replaceAll('-$tier', '')
      : id;
  if (language.isEmpty) return id;
  return tier.isEmpty ? '$language · $speaker' : '$language · $speaker ($tier)';
}

Future<void> _showReady(
    BuildContext context, String message, String? downloadUrl) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: ctx.colors.accent),
          const SizedBox(width: AppSpacing.sm),
          // Flexible: a dialog title is drawn in the theme's headline size and
          // „Video ready!" at that size wants more width than a phone has.
          const Flexible(child: Text('Video ready!')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppText.bodyLarge),
          if (downloadUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Direct download link:',
                style: AppText.caption.copyWith(color: ctx.colors.textMuted)),
            const SizedBox(height: AppSpacing.xs),
            SelectableText(downloadUrl,
                style: AppText.captionBold.copyWith(color: ctx.colors.accent)),
          ],
        ],
      ),
      actions: [
        if (downloadUrl != null)
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ctx.colors.accent,
              foregroundColor: ctx.colors.canvas,
            ),
            onPressed: () => launchUrl(Uri.parse(downloadUrl),
                mode: LaunchMode.externalApplication),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
