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
import 'package:chess_app/widgets/action_key_shortcuts.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
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
  String? currentFen;

  late final http.Client _client = widget.client ?? http.Client();

  bool get _isHost => recording?.hostId == widget.userSession.id;

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
          IconButton(
            icon: Icon(Icons.biotech, color: context.colors.accent),
            tooltip: 'Export to Analysis 🔬',
            onPressed: () {
              final fen = _boardController.getFen();
              context.push(AppRoutes.analysisPath(fen: fen));
            },
          ),
          // Only a lesson recorded alone in Preparation, and only by its host:
          // a room recording had other people in it (phase 5b.4).
          if (_isHost && rec.source == 'preparation')
            IconButton(
              key: const Key('replay-share'),
              tooltip: 'Share with students…',
              icon: Icon(Icons.person_add, color: context.colors.accent),
              onPressed: _share,
            ),
          // The host has a video to download once they rendered one; a
          // reader always has the button, and is told when there is none.
          if (!_isHost || rec.videoUrl != null)
            IconButton(
              key: const Key('replay-download-video'),
              tooltip: 'Download video',
              icon: Icon(Icons.download_for_offline,
                  color: context.colors.accent),
              onPressed: _downloadVideo,
            ),
          // Rendering is the host's: it costs their quota, and the server
          // refuses anybody else.
          if (_isHost)
            IconButton(
              tooltip: 'Export to MP4 Video',
              icon: Icon(Icons.video_call, color: context.colors.brand),
              onPressed: _showExportMp4Dialog,
            ),
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
          child: LandscapeBoardLayout.applies(context)
              ? LandscapeBoardLayout(
                  board: _buildBoard,
                  // Nothing to read beside a replay but its controls.
                  panels: const SizedBox.shrink(),
                  footer: [_buildControlDeck()],
                )
              : Column(
                  children: [
                    // Interactive Board View
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: LayoutBuilder(
                              builder: (ctx, constraints) =>
                                  _buildBoard(constraints.maxWidth),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Player Control Deck
                    _buildControlDeck(),
                  ],
                ),
        ),
      ),
    );
  }

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

  /// Play, pause, the scrubber and the speed — under the board upright, beside
  /// it on its side.
  Widget _buildControlDeck() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAudioAvailable ? Icons.volume_up : Icons.graphic_eq,
                size: 14,
                color: isPlaying
                    ? context.colors.accent
                    : context.colors.textMuted,
              ),
              const SizedBox(width: 6),
              // Flexible: beside the board on a phone on its side the deck is
              // a column about 440 dp wide, and a Row clips in release.
              Flexible(
                child: Text(
                  isAudioAvailable
                      ? 'Audio track in sync'
                      : 'Synchronized playback of moves and arrows',
                  style: (isPlaying ? AppText.captionBold : AppText.caption)
                      .copyWith(
                    color: isPlaying
                        ? context.colors.accent
                        : context.colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

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
            ],
          ),
        ],
      ),
    );
  }
}
