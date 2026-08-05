import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:url_launcher/url_launcher.dart';

class ReplayPlayerScreen extends StatefulWidget {
  final int recordingId;
  final UserSession userSession;

  const ReplayPlayerScreen({
    super.key,
    required this.recordingId,
    required this.userSession,
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
  bool isAudioPlaying = false;

  bool isPlaying = false;
  double playbackSpeed = 1.0;
  int currentMs = 0;
  int maxDurationMs = 0;
  Timer? _playbackTimer;

  PlayerColor boardOrientation = PlayerColor.white;
  List<ChessArrow> currentArrows = [];
  List<EngineArrow> currentEngineArrows = [];
  String? currentFen;

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
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchRecordingDetails() async {
    try {
      final response = await http.get(
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
            _audioPlayer.setSourceUrl(rec.audioUrl!);
          }
          if (rec.timelineEvents.isNotEmpty) {
            maxDurationMs = rec.timelineEvents.last.timestampMs;
            _applyEventAt(0);
          }
        });
      } else {
        _showError('Neuspešno učitavanje snimka.');
      }
    } catch (e) {
      _showError('Greška na mreži pri učitavanju snimka.');
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
      if (isAudioAvailable && recording?.audioUrl != null) {
        _audioPlayer.seek(Duration.zero);
      }
    }
    setState(() => isPlaying = true);
    if (isAudioAvailable && recording?.audioUrl != null) {
      final url = recording!.audioUrl!;
      _audioPlayer.setVolume(1.0);
      if (url.startsWith('http://') || url.startsWith('https://')) {
        _audioPlayer.play(UrlSource(url));
      } else if (File(url).existsSync()) {
        _audioPlayer.play(DeviceFileSource(url));
      } else {
        final filename = url.split('/').last.split('\\').last;
        _audioPlayer.play(UrlSource('$backendUrl/uploads/$filename'));
      }
      if (currentMs > 0) {
        _audioPlayer.seek(Duration(milliseconds: currentMs));
      }
    }
    _playbackTimer?.cancel();
    const intervalMs = 50;
    _playbackTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) return;
      final step = (intervalMs * playbackSpeed).toInt();
      final newMs = currentMs + step;
      if (newMs >= maxDurationMs) {
        setState(() {
          currentMs = maxDurationMs;
          isPlaying = false;
        });
        if (isAudioAvailable) {
          _audioPlayer.pause();
        }
        _applyEventAt(maxDurationMs);
        timer.cancel();
      } else {
        setState(() => currentMs = newMs);
        _applyEventAt(newMs);
      }
    });
  }

  void _pause() {
    _playbackTimer?.cancel();
    if (isAudioAvailable) {
      _audioPlayer.pause();
    }
    setState(() => isPlaying = false);
  }

  void _seekTo(int targetMs) {
    setState(() => currentMs = targetMs);
    if (isAudioAvailable) {
      _audioPlayer.seek(Duration(milliseconds: targetMs));
    }
    _applyEventAt(targetMs);
  }

  void _applyEventAt(int targetMs) {
    if (recording == null || recording!.timelineEvents.isEmpty) return;

    // Find the latest events at or before targetMs
    TimelineEvent? activeInit;
    TimelineEvent? activeFen;
    TimelineEvent? activeOrientation;
    TimelineEvent? activeArrow;

    for (final event in recording!.timelineEvents) {
      if (event.timestampMs > targetMs) break;

      if (event.eventType == 'init') {
        activeInit = event;
      } else if (event.eventType == 'move' || event.eventType == 'fen_change' || event.eventType == 'lesson_loaded') {
        activeFen = event;
      } else if (event.eventType == 'orientation_changed') {
        activeOrientation = event;
      } else if (event.eventType == 'arrow_drawn') {
        activeArrow = event;
      }
    }

    // Apply orientation
    if (activeOrientation != null) {
      final orient = activeOrientation.data['orientation'];
      if (orient == 'black') {
        boardOrientation = PlayerColor.black;
      } else if (orient == 'white') {
        boardOrientation = PlayerColor.white;
      }
    }

    // Apply FEN
    String? fenToLoad;
    if (activeFen != null) {
      fenToLoad = activeFen.data['fen'];
    } else if (activeInit != null) {
      fenToLoad = activeInit.data['fen'];
    }

    if (fenToLoad != null && fenToLoad != currentFen) {
      currentFen = fenToLoad;
      _boardController.loadFen(fenToLoad);
    }

    // Apply Drawn Arrows
    if (activeArrow != null && activeArrow.data['arrows'] is List) {
      final rawList = activeArrow.data['arrows'] as List;
      final arrowMs = activeArrow.timestampMs;
      final moveMs = activeFen?.timestampMs ?? 0;

      // Clear arrows if a move/fen change occurred after the arrow was drawn
      if (moveMs > arrowMs) {
        currentArrows = [];
      } else {
        currentArrows = rawList.map<ChessArrow>((a) => ChessArrow(
          from: a['from'] ?? '',
          to: a['to'] ?? '',
          colorCode: a['colorCode'] ?? 'G',
        )).toList();
      }
    } else {
      currentArrows = [];
    }
  }

  void _showExportMp4Dialog() {
    String selectedPerspective = 'trainer';
    String selectedResolution = '720p';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.video_call, color: Colors.deepPurpleAccent),
              SizedBox(width: 8),
              Text('Izvoz u MP4 Video', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Orijentacija table:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bela (Trener)', style: TextStyle(fontSize: 11)),
                      value: 'trainer',
                      groupValue: selectedPerspective,
                      onChanged: (val) => setDialogState(() => selectedPerspective = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Crna (Učenik)', style: TextStyle(fontSize: 11)),
                      value: 'student',
                      groupValue: selectedPerspective,
                      onChanged: (val) => setDialogState(() => selectedPerspective = val!),
                    ),
                  ),
                ],
              ),
              const Divider(),
              const Text(
                'Rezolucija i kvalitet videa:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedResolution,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: '1080p', child: Text('1080p (Full HD 1920x1080) - Ultra oštrina')),
                  DropdownMenuItem(value: '720p', child: Text('720p (HD 1280x720) - Balans (Preporučeno)')),
                  DropdownMenuItem(value: '480p', child: Text('480p (SD 854x480) - Kompaktan fajl')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedResolution = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Otkaži'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Započni izvoz'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final res = await http.post(
                    Uri.parse('$backendUrl/recordings/${widget.recordingId}/export-mp4'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${widget.userSession.token}'
                    },
                    body: jsonEncode({
                      'perspective': selectedPerspective,
                      'resolution': selectedResolution,
                    }),
                  );
                  final resData = jsonDecode(res.body);
                  if (res.statusCode == 200) {
                    final downloadUrl = resData['downloadUrl'];
                    _showVideoReadyDialog(resData['message'] ?? 'Izvoz završen.', downloadUrl);
                  } else {
                    _showError(resData['error'] ?? 'Izvoz u MP4 nije uspeo.');
                  }
                } catch (e) {
                  _showError('Greška na mreži pri pokretanju MP4 izvoza.');
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
          children: const [
            Icon(Icons.check_circle, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('MP4 Video spreman!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            if (downloadUrl != null) ...[
              const Text('Direktan link za preuzimanje:', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              SelectableText(
                downloadUrl,
                style: const TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
        actions: [
          if (downloadUrl != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Preuzmi MP4 Video'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Zatvori'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.teal),
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
        appBar: AppBar(title: const Text('Učitavanje snimka...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final rec = recording!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Predavač: ${rec.hostName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          if (rec.videoUrl != null)
            IconButton(
              tooltip: 'Preuzmi sačuvani MP4 Video',
              icon: const Icon(Icons.download_for_offline, color: Colors.tealAccent),
              onPressed: () => _showVideoReadyDialog('Sačuvani MP4 video za ovaj čas je spreman za preuzimanje:', rec.videoUrl),
            ),
          IconButton(
            tooltip: 'Izvezi u MP4 Video',
            icon: const Icon(Icons.video_call, color: Colors.deepPurpleAccent),
            onPressed: _showExportMp4Dialog,
          ),
          IconButton(
            tooltip: 'Okreni tablu (Flip Board)',
            icon: const Icon(Icons.swap_vert),
            onPressed: () {
              setState(() {
                boardOrientation = boardOrientation == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Interactive Board View
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        final boardSize = constraints.maxWidth;
                        return Stack(
                          children: [
                            ChessBoard(
                              controller: _boardController,
                              boardOrientation: boardOrientation,
                              enableUserMoves: false,
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: ChessBoardPainter(
                                  arrows: currentArrows,
                                  engineArrows: currentEngineArrows,
                                  boardSize: boardSize,
                                  orientation: boardOrientation,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Player Control Deck
            Container(
              padding: const EdgeInsets.all(16.0),
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
                        color: isPlaying ? Colors.tealAccent : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAudioAvailable ? 'Audio zapis usklađen' : 'Sinhronizovana reprodukcija poteza i strelica',
                        style: TextStyle(
                          fontSize: 11,
                          color: isPlaying ? Colors.tealAccent : Colors.grey,
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Scrubber Timeline
                  Row(
                    children: [
                      Text(_formatDuration(currentMs), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: currentMs.toDouble().clamp(0.0, maxDurationMs > 0 ? maxDurationMs.toDouble() : 1.0),
                          min: 0.0,
                          max: maxDurationMs > 0 ? maxDurationMs.toDouble() : 1.0,
                          onChanged: (val) => _seekTo(val.toInt()),
                        ),
                      ),
                      Text(_formatDuration(maxDurationMs), style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
                        backgroundColor: Colors.teal,
                        onPressed: _togglePlayPause,
                        child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      ),

                      // Speed Chips
                      DropdownButton<double>(
                        value: playbackSpeed,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 1.25, child: Text('1.25x', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 2.0, child: Text('2.0x', style: TextStyle(fontSize: 12))),
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
            ),
          ],
        ),
      ),
    );
  }
}
