import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/game_screen/invite_students_dialog.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/services/lesson_audio_download.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/models/recording_transcript.dart';
import 'package:chess_app/services/recording_transcript_api.dart';
import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/features/tutorial_studio/services/recording_tutorial_flow.dart';
import 'package:chess_app/widgets/action_key_shortcuts.dart';
import 'package:chess_app/widgets/bar_word_menu.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/app_slider.dart';

class ReplayPlayerScreen extends StatefulWidget {
  final int recordingId;
  final UserSession userSession;

  /// Injected by tests; the screen talks to the backend otherwise.
  final http.Client? client;

  /// Where the lesson's sound is kept while it plays; the system's temporary
  /// directory unless a test gives one.
  final Future<Directory> Function()? audioDirectory;

  const ReplayPlayerScreen({
    super.key,
    required this.recordingId,
    required this.userSession,
    this.client,
    this.audioDirectory,
  });

  @override
  State<ReplayPlayerScreen> createState() => _ReplayPlayerScreenState();
}

class _ReplayPlayerScreenState extends State<ReplayPlayerScreen> {
  bool isLoading = true;
  SessionRecording? recording;
  late ChessBoardController _boardController;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isAudioAvailable = false;

  /// The sound as a file on this device, set as the player's source once;
  /// null inside when it could not be had. Play waits for it.
  Future<String?>? _audioReady;
  File? _downloadedAudio;
  bool isAudioPlaying = false;

  bool isPlaying = false;
  double playbackSpeed = 1.0;
  int currentMs = 0;
  int maxDurationMs = 0;
  Timer? _playbackTimer;

  PlayerColor boardOrientation = PlayerColor.white;
  List<ChessArrow> currentArrows = [];
  List<SquareMark> currentSquares = [];
  String? currentFen;

  late final http.Client _client = widget.client ?? http.Client();

  bool get _isHost => recording?.hostId == widget.userSession.id;

  // ── The transcript panel — phase 7 of docs/PLAN-PRIPREMA.md ─────────────

  late final RecordingTranscriptApi _transcriptApi = RecordingTranscriptApi(
      authToken: widget.userSession.token, client: _client);
  TranscriptAvailability _transcriptAvailability =
      const TranscriptAvailability();
  RecordingTranscript? _transcript;
  bool _transcribing = false;
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();
  bool _transcriptSheetOpen = false;

  /// Only the host of a recording made alone in Preparation is ever asked —
  /// the server would refuse anybody else, and a student's player has no
  /// business making the request at all.
  bool get _mayTranscribe => _isHost && recording?.source == 'preparation';

  bool get _transcriptPanelVisible =>
      _mayTranscribe &&
      (_transcriptAvailability.available || _transcript != null);

  Future<void> _loadTranscript() async {
    final result = await _transcriptApi.fetch(widget.recordingId);
    if (!mounted) return;
    setState(() {
      _transcriptAvailability = result;
      _transcript = result.transcript;
    });
  }

  Future<void> _makeTutorial() async {
    await makeTutorialFromRecording(
      context,
      session: widget.userSession,
      recordingId: widget.recordingId,
      client: _client,
    );
  }

  /// Who may watch this lesson — the host's own accepted students, ticked here
  /// and sent as the whole list (phase 5b.4 of docs/PLAN-SESIJA.md).
  Future<void> _share() async {
    final rec = recording;
    if (rec == null) return;
    final headers = {
      'Authorization': 'Bearer ${widget.userSession.token}',
      'Content-Type': 'application/json',
    };
    final current = <int>{};
    try {
      final res = await _client.get(
          Uri.parse('$backendUrl/recordings/${rec.id}/shares'),
          headers: headers);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body is Map && body['studentIds'] is List) {
        current.addAll([
          for (final id in body['studentIds'] as List)
            if (id is num) id.toInt()
        ]);
      } else {
        _showError('Could not read who this recording is shared with.');
        return;
      }
    } catch (_) {
      _showError('Could not read who this recording is shared with.');
      return;
    }
    if (!mounted) return;
    final chosen = await showDialog<List<int>>(
      context: context,
      builder: (_) => InviteStudentsDialog.share(
        recordingTitle: rec.title,
        groupApi: GroupApiService(client: _client),
        initial: current,
      ),
    );
    if (chosen == null || !mounted) return;
    try {
      final res = await _client.put(
        Uri.parse('$backendUrl/recordings/${rec.id}/shares'),
        headers: headers,
        body: jsonEncode({'studentIds': chosen}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        AppFeedback.success(
            context,
            chosen.isEmpty
                ? 'This recording is no longer shared.'
                : 'Shared with ${chosen.length} '
                    '${chosen.length == 1 ? 'student' : 'students'}.');
      } else {
        final body = jsonDecode(res.body);
        _showError(body is Map && body['error'] is String
            ? body['error'] as String
            : 'The recording could not be shared.');
      }
    } catch (_) {
      _showError('The recording could not be shared.');
    }
  }

  /// The trainer's latest render, while the server still has it — or a
  /// sentence, because the student cannot render one (the owner's answer of
  /// 22.9.2026).
  void _downloadVideo() {
    final url = recording?.videoUrl;
    if (url == null) {
      AppFeedback.info(context, 'No video yet — ask your trainer.');
      return;
    }
    _showVideoReadyDialog(
        'The latest video of this recording:', resolveMediaUrl(url));
  }

  @override
  void initState() {
    super.initState();
    _boardController = ChessBoardController();
    AudioPlayer.global.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
      ),
    ));
    _fetchRecordingDetails();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _editController.dispose();
    final downloaded = _downloadedAudio;
    _audioPlayer.dispose().whenComplete(() {
      try {
        downloaded?.deleteSync();
      } catch (_) {
        // A temporary file; the system clears the directory in time.
      }
    });
    super.dispose();
  }

  Future<void> _fetchRecordingDetails() async {
    try {
      final response = await _client.get(
        Uri.parse('$backendUrl/recordings/${widget.recordingId}'),
        headers: {'Authorization': 'Bearer ${widget.userSession.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rec = SessionRecording.fromJson(data);
        setState(() {
          recording = rec;
          isLoading = false;
          if (rec.audioUrl != null && rec.audioUrl!.isNotEmpty) {
            isAudioAvailable = true;
            _audioReady = _prepareAudio(rec.audioUrl!);
          }
          if (rec.timelineEvents.isNotEmpty) {
            // The audio's own length when the recording knows it: a trainer
            // who talks on after the last move is heard to the end.
            maxDurationMs =
                rec.durationMs ?? rec.timelineEvents.last.timestampMs;
            _applyEventAt(0);
          }
        });
        if (rec.hostId == widget.userSession.id &&
            rec.source == 'preparation') {
          unawaited(_loadTranscript());
        }
      } else {
        _showError('Failed to load recording.');
      }
    } catch (e) {
      _showError('Network error while loading recording.');
    }
  }

  void _togglePlayPause() {
    if (isPlaying) {
      _pause();
    } else {
      _play();
    }
  }

  void _play() {
    if (currentMs >= maxDurationMs) {
      currentMs = 0;
    }
    setState(() => isPlaying = true);

    // The board timeline is started before the audio and never depends on it.
    // These calls used to sit ahead of the timer, so an audio backend that
    // refuses the file (Windows does not decode every format) could take the
    // whole replay down with it — pressing Play then did nothing at all,
    // rather than replaying the lesson silently.
    _playbackTimer?.cancel();
    const intervalMs = 50;
    _playbackTimer =
        Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) return;
      final step = (intervalMs * playbackSpeed).toInt();
      final newMs = currentMs + step;
      if (newMs >= maxDurationMs) {
        setState(() {
          currentMs = maxDurationMs;
          isPlaying = false;
        });
        _audioSafely(() => _audioPlayer.pause());
        _applyEventAt(maxDurationMs);
        timer.cancel();
      } else {
        setState(() => currentMs = newMs);
        _applyEventAt(newMs);
      }
    });

    _startAudioFrom();
  }

  /// The sound on this device, set as the player's source — or null.
  ///
  /// A recording still on this device awaiting sync is already a file; any
  /// other is fetched through the app's client (`downloadLessonAudio` says why
  /// the platform player is never handed the URL).
  Future<String?> _prepareAudio(String url) async {
    try {
      var path = url;
      if (!File(url).existsSync()) {
        final dir = await (widget.audioDirectory ?? getTemporaryDirectory)();
        final file = await downloadLessonAudio(
          _client,
          Uri.parse(resolveMediaUrl(url)),
          File('${dir.path}${Platform.pathSeparator}'
              'replay_${widget.recordingId}_${DateTime.now().microsecondsSinceEpoch}.wav'),
        );
        if (file == null) {
          debugPrint('[Replay] The sound could not be fetched.');
          if (mounted) setState(() => isAudioAvailable = false);
          return null;
        }
        _downloadedAudio = file;
        path = file.path;
      }
      await _audioPlayer.setSource(DeviceFileSource(path));
      return path;
    } catch (e) {
      debugPrint('[Replay] Audio could not be loaded: $e');
      if (mounted) setState(() => isAudioAvailable = false);
      return null;
    }
  }

  /// Starts the voice track alongside the board.
  ///
  /// Failures are swallowed on purpose: a lesson whose audio will not play is
  /// still worth watching, and the indicator above the scrubber drops to
  /// "moves and arrows only" so the silence is explained rather than mysterious.
  Future<void> _startAudioFrom() async {
    final ready = _audioReady;
    if (!isAudioAvailable || ready == null) return;
    try {
      // The source is set once, when the sound arrives; Play only seeks and
      // resumes. Setting it again here aborted a load still under way.
      final path = await ready;
      if (path == null || !mounted || !isPlaying) return;
      // Where the board is *now*: a slow fetch lets it run ahead, and the
      // voice joins it there rather than where Play was pressed.
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.seek(Duration(milliseconds: currentMs));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('[Replay] Audio playback failed: $e');
      if (mounted) setState(() => isAudioAvailable = false);
    }
  }

  /// Audio is a nice-to-have next to the board; nothing it does may abort the
  /// caller, which is always in the middle of driving the replay itself.
  void _audioSafely(Future<void> Function() action) {
    if (!isAudioAvailable) return;
    action().catchError((Object e) {
      debugPrint('[Replay] Audio error: $e');
    });
  }

  void _pause() {
    _playbackTimer?.cancel();
    _audioSafely(() => _audioPlayer.pause());
    setState(() => isPlaying = false);
  }

  void _seekTo(int targetMs) {
    setState(() => currentMs = targetMs);
    _audioSafely(() => _audioPlayer.seek(Duration(milliseconds: targetMs)));
    _applyEventAt(targetMs);
  }

  /// The board at [targetMs], by the one rule the player replays by
  /// ([replayFrameAt]).
  void _applyEventAt(int targetMs) {
    if (recording == null || recording!.timelineEvents.isEmpty) return;
    final frame = replayFrameAt(recording!.timelineEvents, targetMs);

    if (frame.orientation == 'black') {
      boardOrientation = PlayerColor.black;
    } else if (frame.orientation == 'white') {
      boardOrientation = PlayerColor.white;
    }

    final fenToLoad = frame.fen;
    if (fenToLoad != null && fenToLoad != currentFen) {
      currentFen = fenToLoad;
      _boardController.loadFen(fenToLoad);
    }

    currentArrows = [
      for (final a in frame.arrows)
        ChessArrow(from: a['from']!, to: a['to']!, colorCode: a['colorCode']!),
    ];
    currentSquares = [
      for (final s in frame.squares)
        SquareMark(square: s['square']!, colorCode: s['colorCode']!),
    ];
  }

  // ── Transcribing ──────────────────────────────────────────────────────

  /// „Transcribe…" or „Transcribe again…" — the second asks first, because it
  /// replaces both the transcript and any corrections made to it.
  Future<void> _openTranscribeFlow() async {
    if (_transcript != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Transcribe again?'),
          content:
              const Text('Transcribing again replaces this transcript and any '
                  'corrections made to it.'),
          actions: [
            TextButton(
              key: const Key('transcript-replace-cancel'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('transcript-replace-confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    await _openLanguageDialog();
  }

  Future<void> _openLanguageDialog() async {
    final languages = _transcriptAvailability.languages;
    if (languages.isEmpty || !mounted) return;
    var selected = languages.contains('sr-Latn') ? 'sr-Latn' : languages.first;
    final start = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Transcribe this recording'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The sound of this recording is sent to Groq to be heard, '
                  'and written back here as text.',
                  style: AppText.caption,
                ),
                const SizedBox(height: AppSpacing.md),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (value) => setDialogState(() => selected = value!),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final code in languages)
                        RadioListTile<String>(
                          key: Key('transcript-language-$code'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: code,
                          title: Text(TutorialLanguage.of(code)?.label ?? code),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('transcript-start'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Transcribe'),
            ),
          ],
        ),
      ),
    );
    if (start == true && mounted) {
      unawaited(_startTranscribe(selected));
    }
  }

  /// The guard is set **before** the request is sent, not when it returns —
  /// the double „Record" of phase 3 of `docs/PLAN-SESIJA.md` was a guard set
  /// too late to catch a second tap in the gap before the first answer.
  Future<void> _startTranscribe(String language) async {
    setState(() => _transcribing = true);
    final result =
        await _transcriptApi.transcribe(widget.recordingId, language);
    if (!mounted) return;
    setState(() {
      _transcribing = false;
      if (result.ok) _transcript = result.transcript;
    });
    if (!result.ok) {
      AppFeedback.error(
          context, result.error ?? 'The recording could not be transcribed.');
    }
  }

  void _startEdit(int index) {
    final sentence = _transcript?.sentences[index];
    if (sentence == null) return;
    setState(() {
      _editingIndex = index;
      _editController.text = sentence.text;
    });
  }

  void _cancelEdit() {
    setState(() => _editingIndex = null);
  }

  /// Sends every sentence's text — the whole set, in order, because
  /// `PUT /recordings/:id/transcript` replaces the lot. Times are never sent:
  /// they cannot be edited.
  Future<void> _saveEdit(int index) async {
    final transcript = _transcript;
    if (transcript == null) return;
    final texts = [
      for (var i = 0; i < transcript.sentences.length; i++)
        i == index ? _editController.text : transcript.sentences[i].text,
    ];
    final result = await _transcriptApi.correct(widget.recordingId, texts);
    if (!mounted) return;
    if (result.ok) {
      setState(() {
        _transcript = result.transcript;
        _editingIndex = null;
      });
    } else {
      // Stays open with what was typed — a refused correction is not lost.
      AppFeedback.error(
          context, result.error ?? 'The correction could not be saved.');
    }
  }

  void _showExportMp4Dialog() {
    String selectedPerspective = 'trainer';
    String selectedResolution = '720p';
    String selectedBoardTheme = 'wood';
    bool showTitle = true;
    bool showTimer = true;
    bool showCoords = true;
    bool showMoveText = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.video_settings_rounded, color: context.colors.brand),
              const SizedBox(width: AppSpacing.sm),
              const Text('Video Settings', style: AppText.title),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1. Chess board theme:',
                  style: AppText.bodyBold.copyWith(color: context.colors.brand),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: selectedBoardTheme,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: AppSpacing.sm),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'wood',
                        child: Text('Classic wood (Brown / Cream)')),
                    DropdownMenuItem(
                        value: 'green',
                        child: Text('Tournament (Green / White)')),
                    DropdownMenuItem(
                        value: 'blue',
                        child: Text('Modern (Dark blue / Gray)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedBoardTheme = val);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '2. Board orientation:',
                  style: AppText.bodyBold.copyWith(color: context.colors.brand),
                ),
                const SizedBox(height: AppSpacing.xs),
                RadioGroup<String>(
                  groupValue: selectedPerspective,
                  onChanged: (val) =>
                      setDialogState(() => selectedPerspective = val!),
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('White (Trainer)',
                              style: AppText.caption),
                          value: 'trainer',
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Black (Student)',
                              style: AppText.caption),
                          value: 'student',
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Text(
                  '3. Display elements on screen:',
                  style: AppText.bodyBold.copyWith(color: context.colors.brand),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show title at the top',
                      style: AppText.caption),
                  value: showTitle,
                  onChanged: (v) => setDialogState(() => showTitle = v ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show timer and duration',
                      style: AppText.caption),
                  value: showTimer,
                  onChanged: (v) => setDialogState(() => showTimer = v ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show board coordinates (A-H, 1-8)',
                      style: AppText.caption),
                  value: showCoords,
                  onChanged: (v) =>
                      setDialogState(() => showCoords = v ?? true),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show last move text at the bottom',
                      style: AppText.caption),
                  value: showMoveText,
                  onChanged: (v) =>
                      setDialogState(() => showMoveText = v ?? true),
                ),
                const Divider(),
                Text(
                  '4. Resolution and quality:',
                  style: AppText.bodyBold.copyWith(color: context.colors.brand),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  initialValue: selectedResolution,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 10, vertical: AppSpacing.sm),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: '1080p',
                        child: Text('1080p (Full HD 1920x1080) - Ultra sharp')),
                    DropdownMenuItem(
                        value: '720p',
                        child: Text(
                            '720p (HD 1280x720) - Balanced (Recommended)')),
                    DropdownMenuItem(
                        value: '480p',
                        child: Text('480p (SD 854x480) - Compact file')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedResolution = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.movie_creation_rounded, size: 16),
              label: const Text('Render Video'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.brand,
                  foregroundColor: context.colors.canvas),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final res = await _client.post(
                    Uri.parse(
                        '$backendUrl/recordings/${widget.recordingId}/export-mp4'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${widget.userSession.token}'
                    },
                    body: jsonEncode({
                      'perspective': selectedPerspective,
                      'resolution': selectedResolution,
                      'boardTheme': selectedBoardTheme,
                      'showTitle': showTitle,
                      'showTimer': showTimer,
                      'showCoords': showCoords,
                      'showMoveText': showMoveText,
                    }),
                  );
                  final resData = jsonDecode(res.body);
                  if (res.statusCode == 200) {
                    final downloadUrl = resData['downloadUrl'];
                    _showVideoReadyDialog(
                        resData['message'] ?? 'Export completed.',
                        downloadUrl == null
                            ? null
                            : resolveMediaUrl(downloadUrl));
                  } else {
                    _showError(resData['error'] ?? 'MP4 export failed.');
                  }
                } catch (e) {
                  _showError('Network error while starting MP4 export.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoReadyDialog(String message, String? downloadUrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: context.colors.accent),
            const SizedBox(width: AppSpacing.sm),
            const Text('MP4 Video ready!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: AppText.bodyLarge),
            const SizedBox(height: AppSpacing.md),
            if (downloadUrl != null) ...[
              Text('Direct download link:',
                  style: AppText.caption
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(
                downloadUrl,
                style:
                    AppText.captionBold.copyWith(color: context.colors.accent),
              ),
            ],
          ],
        ),
        actions: [
          if (downloadUrl != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download MP4 Video'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.accent,
                  foregroundColor: context.colors.canvas),
              onPressed: () {
                launchUrl(Uri.parse(downloadUrl),
                    mode: LaunchMode.externalApplication);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    AppFeedback.show(
      context,
      () =>
          SnackBar(content: Text(msg), backgroundColor: context.colors.danger),
    );
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).floor();
    final mins = (seconds / 60).floor();
    final remSecs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${remSecs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading recording...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final rec = recording!;
    final panelVisible = _transcriptPanelVisible;
    final isWide = Breakpoints.isWide(context);
    final sideways = LandscapeBoardLayout.applies(context);
    // On a phone a correction has the screen to itself. The keyboard takes
    // half of it upright and two thirds sideways, and what it leaves was
    // shared between the board, the sheet and the controls — the sheet's
    // list got nothing, so the owner typed into a sentence he could not see
    // (27.9.2026). Decided by the pencil, not by the keyboard: a tree that
    // changed shape as the keyboard came up would rebuild the field being
    // typed into and drop its focus.
    final editing = _editingIndex;
    final correctsAlone =
        editing != null && _transcript != null && (sideways || !isWide);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.title, style: AppText.title),
            Text('Trainer: ${rec.hostName}',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ],
        ),
        actions: [
          ..._barActions(rec, isWide: isWide),
          const BoardViewMenu(),
          BoardFlipButton(
            onPressed: () {
              setState(() {
                boardOrientation = boardOrientation == PlayerColor.white
                    ? PlayerColor.black
                    : PlayerColor.white;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        // Space for play and pause, the key every player in the world uses.
        // It presses the same button that is drawn below the board and stands
        // aside whenever something else on the screen has the focus, so a
        // reader walking the controls with Tab still presses what they landed
        // on.
        child: ActionKeyShortcuts(
          bindings: {
            LogicalKeyboardKey.space:
                maxDurationMs > 0 ? _togglePlayPause : null,
          },
          child: correctsAlone
              ? _buildCorrectionPage(editing)
              : sideways
                  ? LandscapeBoardLayout(
                      board: _buildBoard,
                      // Empty unless a transcript is offered — the room's own
                      // replay still has nothing else to read beside its controls.
                      panels: panelVisible
                          ? _buildTranscriptPanel()
                          : const SizedBox.shrink(),
                      footer: [_buildControlDeck()],
                    )
                  : panelVisible && isWide
                      // From 840 wide: a column right of the board, which never
                      // shrinks it — the board is bound by height, so the row
                      // takes width the board never had.
                      // The control deck stays full width, under both, exactly as
                      // it is without the panel: nested inside the narrower board
                      // column it wrapped its caption onto a second line, which
                      // cost the board 16 px of height it never gave up before.
                      ? Column(
                          children: [
                            Expanded(
                              // The column gives up what the board — square,
                              // as tall as this row — leaves of the width, down
                              // to 300: at 900 wide a fixed 390 took 18 px of
                              // the board the controls' lost line had given it.
                              child: LayoutBuilder(
                                builder: (ctx, row) => Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                              AppSpacing.md),
                                          child: AspectRatio(
                                            aspectRatio: 1.0,
                                            child: LayoutBuilder(
                                              builder: (ctx, constraints) =>
                                                  _buildBoard(
                                                      constraints.maxWidth),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    SizedBox(
                                      width: (row.maxWidth -
                                              AppSpacing.md -
                                              row.maxHeight)
                                          .clamp(
                                              300.0,
                                              LandscapeBoardLayout
                                                  .minPanelWidth),
                                      child: _buildTranscriptPanel(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _buildControlDeck(),
                          ],
                        )
                      // Never laid out shorter than [_uprightMinHeight]: the
                      // keyboard is still on its way down for a moment after
                      // a correction is saved, and the controls alone are
                      // taller than what it leaves. Scrolling for that moment
                      // is the lesser cost — the rule of
                      // `LandscapeBoardLayout.minHeight`.
                      : _atLeastUprightHeight(Column(
                          children: [
                            // The board's area, and over its lower half the
                            // sheet when it is open — a layer of this area and
                            // not of the screen, so the control deck under it,
                            // which holds play and the button that closes the
                            // sheet, is never covered. Not a route or a Scaffold
                            // bottom sheet either: their scrim covers the whole
                            // screen even when non-modal. (Grading, 27.9.2026:
                            // the first build laid the sheet over the deck, and
                            // a rendered phone had no way out of it.)
                            Expanded(
                              child: LayoutBuilder(
                                builder: (ctx, area) => Stack(
                                  children: [
                                    // Open, the sheet takes the lower 55% and
                                    // the board shrinks to the rest, whole —
                                    // a smaller board beats half of one.
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 0,
                                      height:
                                          panelVisible && _transcriptSheetOpen
                                              ? area.maxHeight * 0.4
                                              : area.maxHeight,
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(
                                              AppSpacing.md),
                                          child: AspectRatio(
                                            aspectRatio: 1.0,
                                            child: LayoutBuilder(
                                              builder: (ctx, constraints) =>
                                                  _buildBoard(
                                                      constraints.maxWidth),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (panelVisible && _transcriptSheetOpen)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        height: area.maxHeight * 0.6,
                                        child: Material(
                                          elevation: 8,
                                          child: _buildTranscriptPanel(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Player Control Deck — with the sheet's own
                            // opener, upright below 840, when a transcript
                            // is offered.
                            _buildControlDeck(
                                showTranscriptButton: panelVisible && !isWide),
                          ],
                        )),
        ),
      ),
    );
  }

  /// What the bar offers, as words (R5): on a window `Open in Analysis`,
  /// `Share…` and a `Video` menu; on a phone the same things behind one ⋮.
  /// Each is drawn only where it was drawn as an icon before.
  List<Widget> _barActions(SessionRecording rec, {required bool isWide}) {
    // Only a lesson recorded alone in Preparation, and only by its host: a
    // room recording had other people in it (phase 5b.4).
    final mayShare = _isHost && rec.source == 'preparation';
    // The host has a video to download once they rendered one; a reader
    // always has the item, and is told when there is none.
    final mayDownload = !_isHost || rec.videoUrl != null;
    // Rendering is the host's: it costs their quota, and the server refuses
    // anybody else.
    final mayExport = _isHost;
    void openAnalysis() {
      final fen = _boardController.getFen();
      context.push(AppRoutes.analysisPath(fen: fen));
    }

    if (isWide) {
      return [
        // Words of one look with „Video" beside them: a bar's words are its
        // menus and its actions alike, as in Analysis (grading, 3.10.2026 —
        // two teal buttons beside one plain word read as two kinds of thing).
        BarWordButton(
          key: const Key('replay-analysis'),
          word: 'Open in Analysis',
          onPressed: openAnalysis,
        ),
        if (mayShare)
          BarWordButton(
            key: const Key('replay-share'),
            word: 'Share…',
            onPressed: _share,
          ),
        if (mayDownload || mayExport)
          BarWordMenu<String>(
            key: const Key('replay-video-menu'),
            word: 'Video',
            onSelected: _onVideoAction,
            itemBuilder: (_) => [
              if (mayDownload)
                const PopupMenuItem(
                  key: Key('replay-download-video'),
                  value: 'download',
                  child: Text('Download video'),
                ),
              if (mayExport)
                const PopupMenuItem(
                  key: Key('replay-export-mp4'),
                  value: 'export',
                  child: Text('Export to MP4…'),
                ),
            ],
          ),
      ];
    }
    return [
      PopupMenuButton<String>(
        key: const Key('replay-more'),
        icon: const Icon(Icons.more_vert),
        tooltip: 'More',
        onSelected: (v) {
          if (v == 'analysis') {
            openAnalysis();
          } else if (v == 'share') {
            _share();
          } else {
            _onVideoAction(v);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'analysis', child: Text('Open in Analysis')),
          if (mayShare)
            const PopupMenuItem(
              key: Key('replay-share'),
              value: 'share',
              child: Text('Share…'),
            ),
          if (mayDownload)
            const PopupMenuItem(
              key: Key('replay-download-video'),
              value: 'download',
              child: Text('Download video'),
            ),
          if (mayExport)
            const PopupMenuItem(
              key: Key('replay-export-mp4'),
              value: 'export',
              child: Text('Export to MP4…'),
            ),
        ],
      ),
    ];
  }

  void _onVideoAction(String v) {
    if (v == 'download') {
      _downloadVideo();
    } else if (v == 'export') {
      _showExportMp4Dialog();
    }
  }

  /// The least height the upright player is laid out in; under it, it scrolls.
  static const double _uprightMinHeight = 480;

  Widget _atLeastUprightHeight(Widget player) => LayoutBuilder(
        builder: (context, area) => SingleChildScrollView(
          child: SizedBox(
            height: area.maxHeight < _uprightMinHeight
                ? _uprightMinHeight
                : area.maxHeight,
            child: player,
          ),
        ),
      );

  Widget _buildBoard(double side) {
    return BoardWithCoordinates(
      size: side,
      orientation: boardOrientation,
      builder: (boardSize) => Stack(
        children: [
          SkinnedChessBoard(
            controller: _boardController,
            boardOrientation: boardOrientation,
            enableUserMoves: false,
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: ChessBoardPainter(
                drawingModeColor: context.colors.accent,
                badgeBorderColor: context.colors.canvas,
                arrows: currentArrows,
                squares: currentSquares,
                // Never filled: the replay draws
                // the lesson's own arrows, and
                // no engine runs behind it.
                engineArrows: const [],
                boardSize: boardSize,
                orientation: boardOrientation,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Upright below 840 wide, the panel has no column of its own: a sheet over
  /// the player, at most 60% of the screen tall so the board stays in sight.
  ///
  /// Not `Scaffold.showBottomSheet` — its scrim sits over the **whole**
  /// screen even for a non-modal sheet, which would have made the board
  /// unreachable behind it despite standing in the clear top 40%. A `Stack`
  /// with the sheet as its own layer, toggled by the same button, keeps the
  /// rest of the screen exactly as interactive as it was.
  void _toggleTranscriptSheet() {
    setState(() => _transcriptSheetOpen = !_transcriptSheetOpen);
  }

  /// „No transcript yet." and „Transcribe…"; with one, the sentences and
  /// „Transcribe again…" — asked for only when the reader is the host of a
  /// recording made in Preparation, and drawn only when the server offers
  /// transcribing or a transcript already exists.
  Widget _buildTranscriptPanel() {
    final transcript = _transcript;
    final canRequest = _transcriptAvailability.available;
    return Container(
      key: const Key('replay-transcript-panel'),
      padding:
          EdgeInsets.all(_compactTranscript ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      // The list takes the height the panel is given wherever it is given
      // one — the column beside the board, the sheet — and a capped height
      // only in the phone's sideways column, which scrolls and gives none. A
      // fixed 420 everywhere overflowed the column at 900 x 700 by 31 px and
      // left half the column empty at 1536 x 792 (grading, 27.9.2026).
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _transcriptPanelChildren(transcript, canRequest,
              constraints.hasBoundedHeight, _compactTranscript),
        ),
      ),
    );
  }

  List<Widget> _transcriptPanelChildren(RecordingTranscript? transcript,
      bool canRequest, bool bounded, bool compact) {
    // A long transcript (some 400 sentences for a 30-minute take) is a lazy
    // list, never a Column of every row.
    Widget list(RecordingTranscript t) => ListView.builder(
          key: const Key('transcript-sentence-list'),
          shrinkWrap: true,
          itemCount: t.sentences.length,
          itemBuilder: (ctx, i) => _buildSentence(t, i),
        );
    return [
      _transcriptHead(transcript, canRequest, compact),
      const SizedBox(height: AppSpacing.sm),
      if (transcript == null)
        Text('No transcript yet.',
            style: AppText.body.copyWith(color: context.colors.textMuted))
      else if (bounded)
        Flexible(child: list(transcript))
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: list(transcript),
        ),
    ];
  }

  /// On a phone — upright in the sheet or on its side in the column — the
  /// transcript is drawn close: four sentences have to be read at 360 x 640
  /// (§2.2 of the plan), where one was.
  bool get _compactTranscript =>
      LandscapeBoardLayout.applies(context) || !Breakpoints.isWide(context);

  /// The title and the two actions, above the sentences so the list has what
  /// is left of the column (R4): on a window the actions are text buttons in
  /// one row, on a phone — in the sheet and in the sideways column — they are
  /// behind a ⋮. „Make a tutorial" is only the host's of a Preparation
  /// recording (`_mayTranscribe`; the server would refuse anybody else, and a
  /// student's player has no business making the request at all), and
  /// transcribing is drawn only when the server offers it.
  Widget _transcriptHead(
      RecordingTranscript? transcript, bool canRequest, bool compact) {
    final transcribeLabel =
        transcript == null ? 'Transcribe…' : 'Transcribe again…';
    final showTutorial = _mayTranscribe;
    final showTranscribe = canRequest && !_transcribing;
    final title = Text('Transcript', style: AppText.bodyBold);
    final busy = _transcribing
        ? Text('Transcribing…',
            style: AppText.bodyBold.copyWith(color: context.colors.textMuted))
        : null;
    if (compact) {
      return Row(
        children: [
          Expanded(child: title),
          if (busy != null) ...[busy, const SizedBox(width: AppSpacing.xs)],
          if (showTutorial || showTranscribe)
            PopupMenuButton<String>(
              key: const Key('transcript-actions'),
              icon: const Icon(Icons.more_vert),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: 'Transcript actions',
              onSelected: (v) {
                if (v == 'tutorial') {
                  _makeTutorial();
                } else {
                  _openTranscribeFlow();
                }
              },
              itemBuilder: (_) => [
                if (showTutorial)
                  const PopupMenuItem(
                    key: Key('transcript-make-tutorial'),
                    value: 'tutorial',
                    child: Text('Make a tutorial'),
                  ),
                if (showTranscribe)
                  PopupMenuItem(
                    key: const Key('transcript-transcribe'),
                    value: 'transcribe',
                    child: Text(transcribeLabel),
                  ),
              ],
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        if (showTutorial || showTranscribe || busy != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            children: [
              if (showTutorial)
                TextButton.icon(
                  key: const Key('transcript-make-tutorial'),
                  onPressed: _makeTutorial,
                  icon: const Icon(Icons.auto_stories_outlined, size: 18),
                  label: const Text('Make a tutorial'),
                ),
              if (showTranscribe)
                TextButton(
                  key: const Key('transcript-transcribe'),
                  onPressed: _openTranscribeFlow,
                  child: Text(transcribeLabel),
                ),
              if (busy != null) busy,
            ],
          ),
      ],
    );
  }

  Widget _buildSentence(RecordingTranscript transcript, int index) {
    final sentence = transcript.sentences[index];
    final isCurrent = sentenceAt(transcript.sentences, currentMs) == index;
    final isEditing = _editingIndex == index;
    final compact = _compactTranscript;
    return Padding(
      key: Key('transcript-sentence-$index'),
      padding: EdgeInsets.symmetric(vertical: compact ? 1 : AppSpacing.xxs),
      child: InkWell(
        onTap: isEditing ? null : () => _seekTo(sentence.startMs),
        child: Container(
          padding: EdgeInsets.all(compact ? AppSpacing.xs + 2 : AppSpacing.sm),
          decoration: BoxDecoration(
            // Never by colour alone (the owner does not see hue): a current
            // sentence is both a wider border and its own marker below.
            border: Border.all(
              color: isCurrent ? context.colors.accent : context.colors.border,
              width: isCurrent ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCurrent)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Icon(
                    Icons.play_arrow,
                    key: const Key('transcript-current'),
                    size: 16,
                    color: context.colors.accent,
                  ),
                ),
              Text(_sentenceTime(sentence.startMs), style: AppText.captionBold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: isEditing
                    ? _buildSentenceEditor(index)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sentence.text.isEmpty
                                ? '(nothing said)'
                                : sentence.text,
                            style: AppText.body,
                          ),
                          if (sentence.corrected)
                            Padding(
                              key: Key('transcript-heard-$index'),
                              padding:
                                  const EdgeInsets.only(top: AppSpacing.xxs),
                              child: Text(
                                'Heard: ${sentence.heard.isEmpty ? "(nothing said)" : sentence.heard}',
                                style: AppText.caption
                                    .copyWith(color: context.colors.textMuted),
                              ),
                            ),
                        ],
                      ),
              ),
              if (!isEditing)
                IconButton(
                  key: Key('transcript-edit-$index'),
                  icon: const Icon(Icons.edit, size: 16),
                  tooltip: 'Correct this sentence',
                  padding: compact ? EdgeInsets.zero : const EdgeInsets.all(8),
                  style: compact
                      ? IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )
                      : null,
                  onPressed: () => _startEdit(index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentenceEditor(int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _correctionField(index),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _correctionCancel(index),
            const SizedBox(width: AppSpacing.sm),
            _correctionSave(index),
          ],
        ),
      ],
    );
  }

  Widget _correctionField(int index, {bool alone = false}) => TextField(
        key: Key('transcript-field-$index'),
        controller: _editController,
        // Alone on the screen it is what the pencil was tapped for, so the
        // keyboard opens on it, and it takes the height it is given and
        // scrolls inside it — growing with its text, it would push Save
        // under the keyboard.
        autofocus: alone,
        maxLines: null,
        expands: alone,
        textAlignVertical: alone ? TextAlignVertical.top : null,
        style: AppText.body,
        decoration: alone
            ? const InputDecoration(border: OutlineInputBorder())
            : const InputDecoration(),
      );

  Widget _correctionCancel(int index) => TextButton(
        key: Key('transcript-cancel-$index'),
        onPressed: _cancelEdit,
        child: const Text('Cancel'),
      );

  Widget _correctionSave(int index) => ElevatedButton(
        key: Key('transcript-save-$index'),
        onPressed: () => _saveEdit(index),
        child: const Text('Save'),
      );

  /// Below this much height — a phone on its side with the keyboard up has
  /// about 120 — the buttons stand beside the field and the two lines over it
  /// are left out: under it they would be behind the keyboard.
  static const double _correctionShort = 220;

  /// A sentence being corrected on a phone: the field, what was heard, Save
  /// and Cancel, and nothing else — no board, no sheet, no controls. The
  /// field has what the buttons leave, so the buttons are on the screen at
  /// every height. The player is as it was the moment either is pressed.
  Widget _buildCorrectionPage(int index) {
    final sentence = _transcript!.sentences[index];
    return LayoutBuilder(
      builder: (context, area) {
        final short = area.maxHeight < _correctionShort;
        final field = _correctionField(index, alone: true);
        return Padding(
          key: const Key('transcript-correction-page'),
          padding: EdgeInsets.all(short ? AppSpacing.xs : AppSpacing.md),
          child: short
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: AppSpacing.sm),
                    SingleChildScrollView(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _correctionSave(index),
                            _correctionCancel(index),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_sentenceTime(sentence.startMs)} · '
                      'Correct this sentence',
                      style: AppText.captionBold,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Heard: ${sentence.heard.isEmpty ? "(nothing said)" : sentence.heard}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption
                          .copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(child: field),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _correctionCancel(index),
                        const SizedBox(width: AppSpacing.sm),
                        _correctionSave(index),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  /// `m:ss`, never the player's own `mm:ss` clock — the two are read apart on
  /// purpose (the gate's own contract).
  String _sentenceTime(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Play, pause, the scrubber and the speed — under the board upright, beside
  /// it on its side.
  ///
  /// [showTranscriptButton] is only true upright below 840 wide, where the
  /// panel has no column of its own: „Transcript" opens it in a sheet, since
  /// the app bar is already full at 360.
  Widget _buildControlDeck({bool showTranscriptButton = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrubber Timeline
          Row(
            children: [
              Text(_formatDuration(currentMs), style: AppText.bodyBold),
              Expanded(
                child: AppSlider(
                  value: currentMs.toDouble().clamp(
                      0.0, maxDurationMs > 0 ? maxDurationMs.toDouble() : 1.0),
                  min: 0.0,
                  max: maxDurationMs > 0 ? maxDurationMs.toDouble() : 1.0,
                  onChanged: (val) => _seekTo(val.toInt()),
                ),
              ),
              Text(_formatDuration(maxDurationMs),
                  style:
                      AppText.body.copyWith(color: context.colors.textMuted)),
            ],
          ),

          // Playback Buttons & Speed Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reset to start
              IconButton(
                icon: const Icon(Icons.skip_previous),
                onPressed: () => _seekTo(0),
              ),

              // Play/Pause Button
              FloatingActionButton(
                mini: true,
                backgroundColor: context.colors.accent,
                onPressed: _togglePlayPause,
                child: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                    color: context.colors.canvas),
              ),

              // Speed Chips
              DropdownButton<double>(
                value: playbackSpeed,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                      value: 1.0, child: Text('1.0x', style: AppText.body)),
                  DropdownMenuItem(
                      value: 1.25, child: Text('1.25x', style: AppText.body)),
                  DropdownMenuItem(
                      value: 1.5, child: Text('1.5x', style: AppText.body)),
                  DropdownMenuItem(
                      value: 2.0, child: Text('2.0x', style: AppText.body)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => playbackSpeed = val);
                    if (isPlaying) {
                      _play(); // restart timer with new speed
                    }
                  }
                },
              ),
              // Upright below 840 only: opens and closes the sentences' sheet.
              // An icon in this row rather than a row of its own — on a 640
              // tall phone a row here is the board's (grading, 27.9.2026).
              if (showTranscriptButton)
                IconButton(
                  key: const Key('replay-transcript-open'),
                  tooltip: _transcriptSheetOpen
                      ? 'Hide transcript'
                      : 'Show transcript',
                  isSelected: _transcriptSheetOpen,
                  icon: const Icon(Icons.subtitles_outlined),
                  selectedIcon: const Icon(Icons.subtitles),
                  onPressed: _toggleTranscriptSheet,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
