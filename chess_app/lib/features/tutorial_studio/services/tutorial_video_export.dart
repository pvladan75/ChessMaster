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
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/services/app_logger.dart';
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

/// Whether the last export wrote the sentences beside the board.
///
/// Remembered, and on by default: a tutorial's words are most of its teaching,
/// so a trainer who wants the board alone is choosing something and a trainer
/// who has never thought about it should get the film this app has always made.
///
/// **The voice is not part of this question.** The text still travels either
/// way - it is the script the voice reads and, in a silent film, what decides
/// how long a beat holds the screen - so turning the writing off leaves a
/// narrated film narrated. A trainer who wants neither picks „No voice".
const _captionsKey = 'tutorial_video_captions';

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
/// Returns where the render was left, or null when none was started — the
/// trainer cancelled the sheet, or it was refused. Every refusal is a sentence
/// through `AppFeedback`, and nothing is sent where the app can already tell:
/// an empty tutorial renders no frames, and ffmpeg given no frames fails with a
/// message about a pipe rather than about a tutorial. [RenderJobState.running]
/// is a render the trainer hid, still being drawn.
///
/// [onStarted] is told the job's id the moment the server has accepted it, so
/// a list can show that tutorial as rendering after the dialog is put away.
Future<RenderJobState?> exportTutorialVideo({
  required BuildContext context,
  required LessonApiService api,
  required int lessonId,
  required String title,
  required TutorialDraft draft,

  /// Where this device keeps recorded takes. Null means the app's own place;
  /// tests hand in a directory.
  NarrationTakeStore? narrationStore,
  ValueChanged<String>? onStarted,
}) async {
  final video = tutorialVideoOf(draft);

  if (!_hasSomethingToShow(draft) || !canRenderVideo(video)) {
    AppFeedback.info(context, 'This tutorial has nothing to show yet.');
    return null;
  }
  if (!fitsInOneFilm(video)) {
    AppFeedback.info(
      context,
      'This tutorial is too long to render as one video (${video.seconds}s).',
    );
    return null;
  }

  // The trainer's own recording, if this device has one for this tutorial —
  // judged here the way the server will judge it, so a take that cannot be used
  // is explained where it would have been offered rather than refused after an
  // upload.
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
  if (!context.mounted) return null;

  final canSpeak = tts.available && tts.voices.isNotEmpty;
  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return null;

  var narrate = true;
  String? voice;
  if (canSpeak) {
    narrate = prefs.getBool(_narrateKey) ?? true;
    final saved = prefs.getString(_voiceKey);
    final known =
        tts.voices.any((v) => (v['id'] ?? v['name'])?.toString() == saved);
    // **Null rather than the first voice on the list, and the sheet picks.**
    // The list is sorted by language, so „the first" was Afrikaans the moment a
    // cloud provider answered with 154 of them - a first-time trainer opened on
    // a language they had never heard of. `_openingLanguage` knows which
    // language to open on and takes the first voice of that one.
    //
    // Null also covers a remembered voice the server no longer offers, which is
    // what switching TTS_PROVIDER does to every id at once.
    voice = known ? saved : null;
  }
  var hd = prefs.getBool(_hdKey) ?? false;
  var captions = prefs.getBool(_captionsKey) ?? true;

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
    captions: captions,
    onSample: (voice) => (debugPlayVoiceSample ?? _playSample)(api, voice),
    // Both answers, because the preview exists to show the film that will be
    // drawn and the writing is now half of what that film looks like.
    onPreview: (wantsHd, wantsCaptions) => _showPreview(
      context: context,
      api: api,
      lessonId: lessonId,
      title: title,
      video: video,
      look: _lookOf(context),
      resolution: wantsHd ? _highResolution : _standardResolution,
      captions: wantsCaptions,
    ),
  );
  if (chosen == null) return null; // cancelled, and nothing was sent
  hd = chosen.hd;
  await prefs.setBool(_hdKey, hd);
  captions = chosen.captions;
  await prefs.setBool(_captionsKey, captions);
  if (canSpeak) {
    // **The recording is not remembered, and choosing it forgets nothing.** It
    // is the default wherever there is one to use, so picking it says nothing
    // about what the trainer wants when there is none — the tutorial edited
    // after recording, the next one not yet recorded — and must not overwrite
    // the answer they gave then.
    if (chosen.answer != _Voice.recording) {
      narrate = chosen.answer == _Voice.synthesised;
      await prefs.setBool(_narrateKey, narrate);
    }
    voice = chosen.voice;
    if (voice != null) await prefs.setString(_voiceKey, voice);
  }

  // Sent once per take: the server keeps the take's id beside the file, so the
  // export of a tutorial whose recording is already there sends only the
  // request.
  final mine = chosen.recording;
  if (mine != null) {
    if (!context.mounted) return null;
    final sent = await _sendRecordingIfNeeded(
      context: context,
      api: api,
      lessonId: lessonId,
      stored: mine,
      signature: signature,
    );
    if (!sent) return null;
  }

  if (!context.mounted) return null;
  final look = _lookOf(context);

  // **Answered when accepted, not when drawn** — item 5 of part two of
  // `docs/PLAN-SNIMANJE.md`. The server names the job; the film is drawn after
  // this request has come back, and the bar below follows it.
  final started = await api.exportVideo(
    lessonId: lessonId,
    events: video.events,
    seconds: video.seconds,
    title: title,
    look: look,
    resolution: hd ? _highResolution : _standardResolution,
    captions: captions,
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
  if (!context.mounted) return null;

  if (!started.ok) {
    AppFeedback.error(context, started.error ?? 'Video export failed.');
    return null;
  }
  final jobId = started.jobId!;
  onStarted?.call(jobId);
  if (started.alreadyRendering) {
    // Pressed again, or on another device, while a film of this tutorial was
    // being drawn. One film per tutorial, so the one already running is shown
    // — and the choices just made are not what it is being drawn with, which
    // is why this is said rather than left to be discovered.
    AppFeedback.info(
      context,
      'This tutorial is already rendering, so here is that video. Cancel it to '
      'render with different settings.',
    );
  }
  return watchTutorialRender(context: context, api: api, jobId: jobId);
}

/// Follows render [jobId] until it ends or the trainer hides it, and then says
/// what became of it: the finished dialog with its link, the server's sentence
/// for a failure, or that it was cancelled.
///
/// Returns the state it was left in — [RenderJobState.running] when hidden. Also
/// how a list reopens a render it found running.
Future<RenderJobState> watchTutorialRender({
  required BuildContext context,
  required LessonApiService api,
  required String jobId,
}) async {
  final ending = await _showProgress(context: context, api: api, jobId: jobId);
  if (ending == null) {
    if (context.mounted) {
      AppFeedback.info(
        context,
        'The video keeps rendering. You will get a notification when it is '
        'ready.',
      );
    }
    return RenderJobState.running;
  }
  if (!context.mounted) return ending.state;

  switch (ending.state) {
    case RenderJobState.done:
      await _showReady(
        context,
        ending.message ??
            'Video rendered successfully, saved, and ready for download!',
        ending.downloadUrl == null
            ? null
            : resolveMediaUrl(ending.downloadUrl!),
      );
    case RenderJobState.cancelled:
      AppFeedback.info(context, 'Video export cancelled.');
    case RenderJobState.failed:
      AppFeedback.error(context, ending.error ?? 'Video export failed.');
    case RenderJobState.unknown:
      AppFeedback.error(
        context,
        ending.error ?? 'This video render is no longer on the server.',
      );
    case RenderJobState.running:
      break;
  }
  return ending.state;
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

/// A bar that follows render [jobId], and closes itself when the render ends.
///
/// **Determinate, because the server actually knows.** The renderer draws a
/// known number of frames and reports each one, so this is a real percentage
/// rather than a spinner pretending to be one — „nema info o tome" was the
/// report, and a bar that moves at a made-up speed would have been the same
/// complaint with more pixels.
///
/// It stops at 99 until the render ends: the frames are drawn well before
/// ffmpeg has finished writing the file, and a bar that sits full while the app
/// still waits is worse than one that visibly has something left to do.
///
/// **And it can be put away** — item 5 of part two of `docs/PLAN-SNIMANJE.md`.
/// It used to hold the whole screen for the whole render, because the render
/// happened inside the request and closing the dialog could not cancel
/// anything: „ekran se zamrzne kad pošaljem na renderovanje". The film is drawn
/// after its request now, so „Hide" leaves it rendering and the trainer is
/// notified, and „Cancel render" stops it.
///
/// Returns the render's last answer, or null when it was hidden.
Future<RenderJobStatus?> _showProgress({
  required BuildContext context,
  required LessonApiService api,
  required String jobId,
}) async {
  var percent = 0;
  int? etaSeconds;
  var queuedAhead = 0;
  var cancelling = false;
  void Function(void Function())? refresh;
  final ending = Completer<RenderJobStatus?>();
  var asking = false;

  Future<void> poll() async {
    // One question at a time: a slow answer overtaken by the next poll would
    // otherwise be two readings racing for the same bar.
    if (asking || ending.isCompleted) return;
    asking = true;
    final at = await api.renderStatus(jobId);
    asking = false;
    if (at == null || ending.isCompleted) return;
    if (at.finished) {
      ending.complete(at);
      return;
    }
    // The bar never walks backwards: a poll that answers with an older reading
    // than the one on screen is a poll that raced, not a render that undid
    // itself. The estimate does follow the newest reading, because it is
    // supposed to fall as the render goes.
    if (at.percent < percent) return;
    refresh?.call(() {
      percent = at.percent;
      etaSeconds = at.etaSeconds;
      queuedAhead = at.queuedAhead;
    });
  }

  // The barrier stays: „Hide" is a decision, and a tap beside the dialog is
  // not one.
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You can hide this and keep working. You will get a '
                'notification when the video is ready.',
                style: AppText.caption.copyWith(color: ctx.colors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('render-cancel'),
              onPressed: cancelling
                  ? null
                  : () async {
                      setLocal(() => cancelling = true);
                      final ok = await api.cancelRender(jobId);
                      // Accepted: the next poll says so, and that is what
                      // closes this — a film finished in the same moment is
                      // still a film. Refused or unreachable: the render goes
                      // on, and so does this bar.
                      if (!ok && ctx.mounted) {
                        setLocal(() => cancelling = false);
                        AppFeedback.error(
                            ctx, 'The render could not be cancelled.');
                      }
                    },
              child: Text(cancelling ? 'Cancelling…' : 'Cancel render'),
            ),
            FilledButton(
              key: const Key('render-hide'),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hide'),
            ),
          ],
        );
      },
    ),
  );
  // Closed by „Hide", or by a back button: either way the film goes on.
  unawaited(dialog.then((_) {
    if (!ending.isCompleted) ending.complete(null);
  }));

  unawaited(poll());
  final poller =
      Timer.periodic(const Duration(milliseconds: 900), (_) => poll());
  final result = await ending.future;
  poller.cancel();
  if (result != null && context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
    await dialog;
  }
  return result;
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
  required bool captions,
}) async {
  final result = await api.previewFrames(
    lessonId: lessonId,
    events: video.events,
    seconds: video.seconds,
    title: title,
    look: look,
    resolution: resolution,
    captions: captions,
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

/// What a film sounds like — phase 6 of `docs/PLAN-SNIMANJE.md`.
///
/// **One question with three answers, not two switches.** Two switches can both
/// be on, and a film is never sent a recording and a synthesised voice; the
/// phase 4 sheet kept that true by hiding one switch while the other was on,
/// which is the same rule written as a layout. A radio cannot hold two answers.
enum _Voice { recording, synthesised, none }

class _ExportChoice {
  const _ExportChoice(
      this.answer, this.voice, this.hd, this.captions, this.recording);
  final _Voice answer;

  /// The synthesised voice in the dropdown, sent only when [answer] asks for it.
  final String? voice;
  final bool hd;

  /// Whether the sentences are written beside the board.
  final bool captions;

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

/// What to ask before a render: what the film sounds like, and the quality.
///
/// The sound is one question with up to three answers — the trainer's own
/// recording where this device has one that matches, a synthesised voice where
/// the server has one, and none — and it is drawn only when there are at least
/// two: an answer that cannot be honoured must not be offered, and a question
/// with one answer is not a question. The sheet still opens, because the
/// quality is a choice everywhere.
Future<_ExportChoice?> _askAboutExport({
  required BuildContext context,

  /// The lookup for this device's take: offered when it can be used, explained
  /// when it cannot, and neither while the lookup has not answered or found
  /// nothing.
  required Future<_Recording?> recording,
  required List<Map<String, dynamic>> voices,

  /// The synthesised voice's last answer, remembered per trainer.
  required bool narrate,
  required String? voice,
  required bool hd,
  required bool captions,

  /// Draws three stills of the film at the resolution now chosen, without
  /// rendering anything. The sheet stays open behind it: a preview is a look,
  /// not a decision.
  required Future<void> Function(bool hd, bool captions) onPreview,

  /// Speaks one sentence in a voice, so it can be heard before a film is spent
  /// on it. Answers false when the server had nothing to play.
  ///
  /// A callback rather than a player, so the sheet's tests never open an audio
  /// device — the same reason `NarrationPlayer` is an interface.
  required Future<bool> Function(String voice) onSample,
}) {
  var answer = voices.isNotEmpty && narrate ? _Voice.synthesised : _Voice.none;
  var chosen = voice;
  var language = _openingLanguage(voices, chosen);
  // **The sheet opens on a voice of the language it opens on.** Nothing
  // remembered - or nothing the server still offers, which is what the caller
  // sends null for - and the sheet picks rather than passing null on: piper
  // quietly took its first model when the voice was absent, while a cloud
  // provider refuses the request, which is a silent film for the want of a
  // default nobody wrote.
  //
  // It is written as „is the voice in this language's list" rather than „is it
  // null", because `DropdownButton` throws on a value that names no item, and a
  // voice whose entry carries no language at all is not in any list. A guard on
  // the control instead of a rule here was unreachable - a mutation deleting it
  // changed nothing, which is this repository's own test of whether a check is
  // a check.
  if (!_voicesIn(voices, language).any((v) => _idOf(v) == chosen)) {
    chosen = _firstVoiceOf(voices, language);
  }
  var wantsHd = hd;
  var wantsCaptions = captions;
  var previewing = false;
  var sampling = false;
  // The take, once the lookup answers. Chosen by default where there is one to
  // use: a trainer who recorded their voice over a tutorial and exports it
  // wants that voice.
  _Recording? found;
  void Function(void Function())? refresh;
  var closed = false;
  unawaited(recording.then((take) {
    if (closed) return;
    found = take;
    if (take?.stored != null) answer = _Voice.recording;
    refresh?.call(() {});
  }));

  return showDialog<_ExportChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        refresh = setLocal;
        final mine = found?.stored;
        final answers = [
          if (mine != null) _Voice.recording,
          if (voices.isNotEmpty) _Voice.synthesised,
          _Voice.none,
        ];
        final body = AppText.body.copyWith(color: ctx.colors.textPrimary);
        final note = AppText.caption.copyWith(color: ctx.colors.textMuted);
        final languages = _languagesOf(voices);
        final spoken = _voicesIn(voices, language);
        return AlertDialog(
          title: const Text('Export video'),
          // Measured, not assumed: with all three answers and the voice
          // dropdown, the sheet is 49 px taller than a 360 × 640 phone, and a
          // release build clips that without a word — the quality switch sat
          // under the buttons, where a tap on it pressed Export.
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Where the recording would be offered, and in its place: a take
              // that cannot make this film is not an answer to choose.
              if (found?.unusable != null)
                Row(
                  key: const Key('export-recording-unusable'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: ctx.colors.warning, size: 18),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(found!.unusable!, style: body)),
                  ],
                ),
              if (answers.length > 1) ...[
                if (found?.unusable != null)
                  const SizedBox(height: AppSpacing.sm),
                Text('Narration',
                    style: AppText.bodyBold
                        .copyWith(color: ctx.colors.textPrimary)),
                // `RadioGroup` rather than a `groupValue` on every tile, which
                // is deprecated — see `breadth_dialog.dart`.
                RadioGroup<_Voice>(
                  groupValue: answer,
                  onChanged: (v) => setLocal(() => answer = v!),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mine != null)
                        RadioListTile<_Voice>(
                          key: const Key('export-voice-recording'),
                          value: _Voice.recording,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              'My recording '
                              '(${narrationClockOf(mine.take.durationMs)})',
                              style: body),
                          subtitle: Text(
                              'Your own voice, and the board moves where you '
                              'pressed Space.',
                              style: note),
                        ),
                      if (voices.isNotEmpty)
                        RadioListTile<_Voice>(
                          key: const Key('export-voice-synthesised'),
                          value: _Voice.synthesised,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Synthesised voice', style: body),
                        ),
                      RadioListTile<_Voice>(
                        key: const Key('export-voice-none'),
                        value: _Voice.none,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('No voice', style: body),
                      ),
                    ],
                  ),
                ),
              ],
              if (answer == _Voice.synthesised) ...[
                const SizedBox(height: AppSpacing.xs),
                // **The language is its own control, and it comes first.** A
                // real Azure account answered with 655 voices across 154
                // languages on 11.9.2026; one dropdown of 655 is a list nobody
                // can scroll to the end of, and the language is what a trainer
                // is actually choosing - the voice has to match what they
                // wrote, and nothing anywhere detects that.
                //
                // Drawn only where there is more than one, by the same rule as
                // the narration question above: a question with one answer is
                // not a question. With piper's six voices in six languages it
                // appears; with one installed voice it does not.
                if (languages.length > 1)
                  Row(
                    children: [
                      Text('Language',
                          style: AppText.body
                              .copyWith(color: ctx.colors.textSecondary)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            key: const Key('export-voice-language'),
                            isExpanded: true,
                            value: language,
                            dropdownColor: ctx.colors.surface,
                            items: [
                              for (final code in languages)
                                DropdownMenuItem<String>(
                                  value: code,
                                  child: Text(
                                    _languageLabel(voices, code),
                                    style: AppText.body.copyWith(
                                        color: ctx.colors.textPrimary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (code) => setLocal(() {
                              language = code!;
                              // The voice follows the language it is in, or the
                              // sheet keeps one the list no longer shows and
                              // sends it anyway.
                              chosen = _firstVoiceOf(voices, language);
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Text('Voice',
                        style: AppText.body
                            .copyWith(color: ctx.colors.textSecondary)),
                    const SizedBox(width: AppSpacing.md),
                    // **Hear it before spending a render on it.** Auditioning by
                    // export is minutes and a queue slot per voice, and a cloud
                    // account offers hundreds — so one sentence, spoken by the
                    // voice under the cursor. The server says the same sentence
                    // a beat of that language would say, move and all: a sample
                    // of prose would not answer the question a trainer is
                    // actually asking, which is how this voice reads „Bc4".
                    IconButton(
                      key: const Key('export-voice-sample'),
                      tooltip: 'Hear this voice',
                      visualDensity: VisualDensity.compact,
                      icon: sampling
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: ctx.colors.accent),
                            )
                          : Icon(Icons.volume_up, color: ctx.colors.accent),
                      onPressed: sampling || chosen == null
                          ? null
                          : () async {
                              final voice = chosen!;
                              setLocal(() => sampling = true);
                              final heard = await onSample(voice);
                              // The sheet may be gone by the time a voice
                              // answers — a trainer who pressed Export while it
                              // was fetching is not waiting for this.
                              if (closed) return;
                              setLocal(() => sampling = false);
                              if (!heard && ctx.mounted) {
                                AppFeedback.error(ctx,
                                    'That voice could not be played. The server log says why.');
                              }
                            },
                    ),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const Key('export-voice-voice'),
                          isExpanded: true,
                          value: chosen,
                          dropdownColor: ctx.colors.surface,
                          items: [
                            for (final v in spoken)
                              DropdownMenuItem<String>(
                                value: _idOf(v),
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
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text('Comments beside the board',
                        style: AppText.bodyBold
                            .copyWith(color: ctx.colors.textPrimary)),
                  ),
                  Switch(
                    key: const Key('export-captions'),
                    value: wantsCaptions,
                    activeThumbColor: ctx.colors.accent,
                    onChanged: (v) => setLocal(() => wantsCaptions = v),
                  ),
                ],
              ),
              Text(
                wantsCaptions
                    ? 'Each sentence is written beside the board as it is read.'
                    : 'The board alone, centred. The voice still reads — pick '
                        '„No voice" above for a silent film.',
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
                        await onPreview(wantsHd, wantsCaptions);
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
                  _ExportChoice(answer, chosen, wantsHd, wantsCaptions,
                      answer == _Voice.recording ? found?.stored : null)),
              child: const Text('Export'),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() => closed = true);
}

/// One sentence in one voice, fetched and played on this device.
///
/// **A file rather than the bytes**: `audioplayers` plays a device file on
/// every target this app ships to, and its byte source does not — the same
/// reason `NarrationPlayer` plays a path. The file is overwritten by the next
/// sample and never grows: a trainer auditioning twenty voices leaves one file
/// behind, not twenty.
///
/// Answers false when there was nothing to play, and says nothing itself: the
/// sheet owns the sentence, because it owns the screen the trainer is looking
/// at.
/// The one thing a widget test cannot do: open an audio device.
///
/// Both halves of playing a sample are platform channels — `path_provider` for
/// somewhere to put the file and `audioplayers` to play it — and in a test
/// neither answers, so the button that waits for them spins for ever. A test
/// sets this to something that fetches and reports, which is everything about
/// the sample except the sound.
///
/// Same shape as `debugTutorialStudioAvailable`, and null in a real build.
Future<bool> Function(LessonApiService api, String voice)? debugPlayVoiceSample;

Future<bool> _playSample(LessonApiService api, String voice) async {
  final bytes = await api.fetchVoiceSample(voice);
  if (bytes == null || bytes.isEmpty) return false;
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/voice-sample.wav');
    await file.writeAsBytes(bytes, flush: true);
    final player = AudioPlayer();
    // Released when the sentence ends: a player per sample that is never
    // disposed is an audio session per voice a trainer auditions.
    player.onPlayerComplete.first.then((_) => player.dispose());
    await player.play(DeviceFileSource(file.path));
    return true;
  } catch (e) {
    AppLogger.log('[Export] Could not play a voice sample: $e');
    return false;
  }
}

/// The id the server knows a voice by, which is what travels in the request.
String _idOf(Map<String, dynamic> voice) =>
    (voice['id'] ?? voice['name'])?.toString() ?? '';

String _languageOf(Map<String, dynamic> voice) =>
    voice['language']?.toString() ?? '';

/// What to call a language in the picker.
///
/// The name the server sent where it sent one - Azure does, and „Serbian
/// (Latin, Serbia)" is the difference between choosing and guessing at
/// `sr-Latn-RS`. piper and Google send none and the code is what they have
/// always shown, so nothing here invents a table of 154 names.
String _languageLabel(List<Map<String, dynamic>> voices, String language) {
  for (final voice in voices) {
    if (_languageOf(voice) != language) continue;
    final named = voice['languageName']?.toString() ?? '';
    if (named.isNotEmpty) return named;
  }
  return language;
}

/// Every language on offer, in the order a person reads them.
///
/// Sorted by the label rather than by the code, because that is what the eye
/// scans down: „Serbian (Latin, Serbia)" sits under S, not under sr.
List<Map<String, dynamic>> _byLanguage(List<Map<String, dynamic>> voices) =>
    voices.where((v) => _languageOf(v).isNotEmpty).toList();

List<String> _languagesOf(List<Map<String, dynamic>> voices) {
  final codes =
      <String>{for (final v in _byLanguage(voices)) _languageOf(v)}.toList()
        ..sort((a, b) {
          final byName = _languageLabel(voices, a)
              .toLowerCase()
              .compareTo(_languageLabel(voices, b).toLowerCase());
          return byName != 0 ? byName : a.compareTo(b);
        });
  return codes;
}

/// The voices of one language, which is the whole of what the second control
/// lists.
List<Map<String, dynamic>> _voicesIn(
        List<Map<String, dynamic>> voices, String language) =>
    voices.where((v) => _languageOf(v) == language).toList();

/// The first voice of [language], which is what a change of language selects.
String? _firstVoiceOf(List<Map<String, dynamic>> voices, String language) {
  for (final voice in voices) {
    if (_languageOf(voice) == language) return _idOf(voice);
  }
  return voices.isEmpty ? null : _idOf(voices.first);
}

/// Which language the sheet opens on.
///
/// The remembered voice decides it where there is one, because a trainer who
/// chose „Nicholas" last time is not choosing Serbian again. Otherwise the
/// app's own language, then any other English, and only then the top of the
/// list - which is alphabetical, and would open a first-time trainer on
/// Afrikaans.
String _openingLanguage(List<Map<String, dynamic>> voices, String? chosen) {
  for (final voice in voices) {
    if (_idOf(voice) == chosen && _languageOf(voice).isNotEmpty) {
      return _languageOf(voice);
    }
  }
  final languages = _languagesOf(voices);
  if (languages.contains('en-US')) return 'en-US';
  for (final code in languages) {
    if (code.startsWith('en')) return code;
  }
  return languages.isEmpty ? '' : languages.first;
}

/// „Nicholas (Neural)" - the speaker, and not the language.
///
/// The language is the control above this one since 11.9.2026, so repeating it
/// on every row spends the width a name needs. Where the server sends only an
/// id, as piper does, the language is cut off the front of it: „en_US-lessac-
/// medium" is „lessac (medium)".
String _voiceLabel(Map<String, dynamic> voice) {
  final id = _idOf(voice);
  final name = voice['name']?.toString() ?? '';
  final tier = voice['tier']?.toString() ?? '';
  var label = name.isNotEmpty && name != id ? name : _speakerOf(voice);
  if (label.isEmpty) label = id;
  if (tier.isEmpty || label.toLowerCase().contains(tier.toLowerCase())) {
    return label;
  }
  return '$label ($tier)';
}

String _speakerOf(Map<String, dynamic> voice) {
  final id = _idOf(voice);
  final language = _languageOf(voice);
  final tier = voice['tier']?.toString() ?? '';
  var speaker = id;
  if (language.isNotEmpty && id.startsWith('$language-')) {
    speaker = id.substring(language.length + 1);
  } else if (id.contains('-')) {
    speaker = id.substring(id.indexOf('-') + 1);
  }
  return tier.isEmpty ? speaker : speaker.replaceAll('-$tier', '');
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
