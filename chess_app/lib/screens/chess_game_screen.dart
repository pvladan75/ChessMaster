import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chess_app/services/agora_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:chess/chess.dart' as chess;

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/local_recording_service.dart';
import 'package:chess_app/services/lesson_recorder.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/core/services/board_control_rules.dart' as rules;
import 'package:chess_app/models/pending_session_intent.dart';

import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/arrow_color_button.dart';
import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/game_screen/course_step_bar.dart';
import 'package:chess_app/widgets/board_setup_dialog.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/create_course_dialog.dart';
import 'package:chess_app/widgets/save_position_dialog.dart';
import 'package:chess_app/widgets/matrix_filter_panel.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';
import 'package:chess_app/widgets/share_position_dialog.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/features/groups/widgets/room_guests_dialog.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:go_router/go_router.dart';

// 3. MULTIPLAYER CHESS GAME PAGE
class ChessGamePage extends StatefulWidget {
  final String roomCode;
  final UserSession userSession;
  final String? initialRole;

  const ChessGamePage({
    super.key,
    required this.roomCode,
    required this.userSession,
    this.initialRole,
  });

  @override
  State<ChessGamePage> createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  late String activeRole;
  bool isRecording = false;

  /// Whether the room may be recorded, as the server last said.
  ///
  /// True until told otherwise: the app has never asked before, and the server
  /// is the lock — this only decides whether the button is drawn as available.
  /// A control that looks available and then fails is the same surprise as one
  /// that works while its button is hidden, which is why the reason is kept
  /// beside it and shown on the card.
  bool _recordingAllowed = true;
  String? _recordingBlockedReason;
  int? recordingStartTimeMs;

  /// Owns the recording clock and timeline. See [LessonRecorder] for why the
  /// pause arithmetic lives outside this screen.
  final LessonRecorder _recorder = LessonRecorder();

  late ChessBoardController controller;
  late io.Socket socket;
  bool isConnected = false;
  bool _isDisposing = false;
  String gameStatus = "Spajanje na game server...";

  PlayerColor boardOrientation = PlayerColor.white;
  String boardControl = 'trainer_only';
  bool allowStudentEngine = false;

  final StockfishService _stockfishService = StockfishService();
  bool isEngineEnabled = false;
  bool _showEvalBar = false;
  double _currentRawEval = 0.0;
  int _currentEvalDepth = 0;
  String currentEngineEval = "0.00";
  String bestEngineMove = "-";
  Map<int, AnalysisLine> engineLines = {};
  String engineThinkingMode = 'fast'; // 'fast', 'deep', 'infinite'

  /// This board's analysis dials — see [EngineAnalysisDials].
  int _analysisDepth = AppSettingsService.instance.analysisDepth;
  int _analysisLines = AppSettingsService.instance.analysisLines;

  final AgoraService _agoraService = AgoraService();
  List<dynamic> audioUsers = [];
  Set<int> activeSpeakers = {};
  bool isAudioMuted = false;

  /// Whether the server let this person be heard in this room at all.
  ///
  /// Not the same thing as [isAudioMuted]: muting is a choice made during a
  /// lesson and can be undone, this is a right. While it is false the app holds
  /// a subscriber token that cannot publish audio however the buttons are
  /// pressed, so no screen may offer one that pretends otherwise.
  bool mayUseMic = false;

  /// Whether this client is in the voice channel at all.
  ///
  /// Nothing joins it on entering the room any more (27.8.2026). Two reasons,
  /// and the second is the one that decides it: Agora bills every minute a
  /// person is *in* a channel, spoken in or not — and the microphone was being
  /// opened before anybody said they wanted to talk, in an app whose users are
  /// mostly children. **The channel is entered by whoever wants the
  /// conversation, on a button.**
  ///
  /// Everyone in the room still receives `audio_users_list`, so somebody who is
  /// not in the voice can see that a conversation is going on and join it. That
  /// is what keeps this from turning a lesson into silence.
  bool isVoiceOn = false;
  bool isAudioConnecting = false;
  String? audioError;
  bool isHandRaised = false;
  List<dynamic> roomMembers = [];

  bool isDrawingMode = false;
  String? drawingStartSquare;
  String selectedArrowColorCode = 'G'; // 'G', 'R', 'B', 'O'

  List<dynamic> lessons = [];
  bool isLoadingLessons = false;
  final TextEditingController fenPasteController = TextEditingController();
  final TextEditingController pgnPasteController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  List<String> moveHistory = [];

  late MoveTree moveTree;
  MoveNode get currentNode => moveTree.current;

  static List<String> _persistedLabels = [];
  static bool _shouldPersistLabels = false;

  List<String> _availableUserLabels = [];
  List<String> _selectedIncludeTags = [];
  List<String> _selectedExcludeTags = [];
  String _filterMatchMode = 'all'; // 'all' (AND) or 'any' (OR)
  String _lessonCategoryFilter = 'all'; // 'all', 'mine', 'trainer'

  // Active course being stepped through live (trainer-driven; students just see
  // whatever position loadLessonPosition broadcasts).
  List<dynamic>? _activeCourseItems;
  int _activeCourseIndex = 0;
  String? _activeCourseTitle;

  bool get isHost =>
      activeRole == 'host' ||
      activeRole == 'trener' ||
      widget.roomCode == 'STUDIO';
  bool get isTrener => isHost;

  /// Whether this client may drive the shared board — either by moving a piece
  /// or by stepping through the move tree. Both broadcast the new position to
  /// everyone in the room, so they answer to one rule rather than two.
  ///
  /// Navigation used to test `userSession.role` alone, so the room's own host —
  /// seated 'trener' by the server but registered 'korisnik' — failed the
  /// check, and since [boardControl] defaults to 'trainer_only' the whole
  /// navigation bar came up disabled. See [rules.canDriveSharedBoard].
  bool get canDriveSharedBoard => rules.canDriveSharedBoard(
        seatRole: activeRole,
        accountRole: widget.userSession.role,
        boardControl: boardControl,
        isStudio: widget.roomCode == 'STUDIO',
      );

  @override
  void initState() {
    super.initState();
    if (widget.roomCode == 'STUDIO') {
      activeRole = 'host';
      boardOrientation = PlayerColor.white;
      allowStudentEngine = true;
      boardControl = 'unrestricted';
    } else {
      activeRole = widget.initialRole ?? 'korisnik';
      boardOrientation =
          activeRole == 'host' ? PlayerColor.white : PlayerColor.black;

      if (widget.userSession.isGuest) {
        // A guest reached a real room directly (shared link, restored deep
        // link...), bypassing Home's login gate. Send them to log in first,
        // then straight back into this same room once they have.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go(
            AppRoutes.login,
            extra: PendingSessionIntent.joinInviteRoom(widget.roomCode,
                role: widget.initialRole),
          );
        });
      } else {
        // Marks this room as the user's active session so they can find
        // their way back to it after stepping away (Home shows a "resume"
        // banner) and so Home blocks starting/joining a different one until
        // they explicitly leave — see the AppBar's "Napusti sesiju" action.
        GameSessionService.instance.setActive(widget.roomCode, activeRole);
      }
    }
    controller = ChessBoardController();
    moveTree = MoveTree(
        startingFen:
            'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    // The Preferences route overlays this screen without unmounting it, so a
    // toggle like move-input-mode needs an explicit listener to take effect
    // immediately rather than waiting for some unrelated setState.
    AppSettingsService.instance.addListener(_onAppSettingsChanged);
    initSocket();

    // Fetch saved positions & user labels for all users
    fetchLessons();
    fetchUserLabels();

    // Set up Stockfish service evaluation listener
    _stockfishService.onEvaluationChanged =
        (evaluation, bestMove, continuation, multipv, depth, isFinal,
            [analyzedFen = '']) {
      if (!mounted) return;
      if (!isEngineEnabled) return;
      // Nothing to say about the position. It is not a score of zero, and
      // writing it into the bar would draw a won game as equal.
      if (evaluation.isEmpty) return;

      double parsedEval = 0.0;
      final numVal = double.tryParse(evaluation);
      if (numVal != null) {
        parsedEval = numVal;
      } else if (evaluation.contains('M')) {
        final mateNum =
            int.tryParse(evaluation.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        parsedEval = evaluation.contains('-')
            ? (-10000.0 + mateNum)
            : (10000.0 - mateNum);
      }

      setState(() {
        if (multipv == 1) {
          _currentRawEval = parsedEval;
          _currentEvalDepth = depth;
          currentEngineEval = evaluation;
        }

        if (evaluation.isNotEmpty || continuation.isNotEmpty) {
          final currentFen = moveTree.current.fen;
          final updatedLine = AnalysisLine.fromPv(
            multipv: multipv,
            depth: depth,
            eval: evaluation.isNotEmpty
                ? evaluation
                : (engineLines[multipv]?.evaluation ?? '0.00'),
            pvString: continuation,
            startingFen: currentFen,
          );
          engineLines[multipv] = updatedLine;

          if (multipv == 1 && updatedLine.bestMoveSan.isNotEmpty) {
            bestEngineMove = updatedLine.bestMoveSan;
          }
        }
      });
    };

    _stockfishService.onMultiPVUpdated = (linesMap) {
      if (!mounted) return;
      if (!isEngineEnabled) return;
      setState(() {
        engineLines.addAll(linesMap);
      });
    };

    _stockfishService.attach(
      this,
      getFen: () => controller.getFen(),
      isEnabled: () => isEngineEnabled,
      onEvaluation: _stockfishService.onEvaluationChanged,
      onMultiPV: _stockfishService.onMultiPVUpdated,
    );

    // No `_initAudioChat()` here. Entering a room is not asking for a
    // conversation — see [isVoiceOn]. The studio has no voice at all: there is
    // nobody to talk to, and its token request was refused (`no-room`) anyway.
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _isDisposing = true;
    AppSettingsService.instance.removeListener(_onAppSettingsChanged);
    _stockfishService.detach(this);
    socket.emit('leaveGame', {
      'roomId': widget.roomCode,
      'userId': widget.userSession.id,
    });
    socket.emit('audio_leave', {
      'roomId': widget.roomCode,
      'userId': widget.userSession.id,
    });
    socket.disconnect();
    socket.dispose();
    _agoraService.leaveChannel();
    commentController.dispose();
    fenPasteController.dispose();
    pgnPasteController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// Who is in the voice right now, other than me.
  ///
  /// The roster is broadcast to the whole room, not only to the people in the
  /// channel, which is what lets somebody who has not turned their voice on see
  /// that the lesson is being spoken. Without that, "glas je na dugme" would
  /// mean a student sitting in silence not knowing there is anything to hear.
  List<String> get _voiceUsersOther => audioUsers
      .where((u) => u is Map && u['userId'] != widget.userSession.id)
      .map<String>((u) => (u['userName'] ?? 'Učesnik').toString())
      .toList();

  /// Enters the voice channel because somebody asked for it.
  ///
  /// The one door in: no screen and no socket event may open the voice on a
  /// person's behalf. A right that changes while the voice is off is remembered
  /// by the server and applies the next time this is pressed — see
  /// [_rejoinVoice].
  Future<void> _joinVoice() async {
    if (isVoiceOn || widget.roomCode == 'STUDIO') return;
    setState(() => isVoiceOn = true);
    await _initAudioChat();
  }

  /// Leaves the voice channel without leaving the lesson.
  ///
  /// `audio_leave` is what stops the meter on the server, so it is sent even
  /// though the channel is already left — the two are different things and the
  /// server only learns about the first one from us.
  Future<void> _leaveVoice() async {
    await _agoraService.leaveChannel();
    socket.emit('audio_leave', {
      'roomId': widget.roomCode,
      'userId': widget.userSession.id,
    });
    if (!mounted) return;
    setState(() {
      isVoiceOn = false;
      isAudioConnecting = false;
      audioError = null;
      isAudioMuted = false;
      mayUseMic = false;
      isHandRaised = false;
    });
  }

  Future<void> _initAudioChat() async {
    setState(() {
      isAudioConnecting = true;
      audioError = null;
    });

    _agoraService.onActiveSpeakersChanged = (speakers) {
      if (mounted) {
        setState(() {
          activeSpeakers = speakers;
        });
      }
    };

    _agoraService.onMuteStateChanged = (muted) {
      if (mounted) {
        setState(() {
          isAudioMuted = muted;
        });
      }
    };

    _agoraService.onJoinStateChanged = (joined, err) {
      if (mounted) {
        setState(() {
          isAudioConnecting = false;
          audioError = err;
        });

        if (joined) {
          socket.emit('audio_join', {
            'roomId': widget.roomCode,
            'userId': widget.userSession.id,
            'userName': widget.userSession.name,
            'role': widget.userSession.role,
            'isMuted': _agoraService.isMuted,
          });
        }
      }
    };

    final success = await _agoraService.joinChannel(
      widget.roomCode,
      widget.userSession.id,
      userToken: widget.userSession.token,
    );
    if (mounted) {
      setState(() {
        mayUseMic = _agoraService.maySpeak;
        if (!success) {
          isAudioConnecting = false;
          // Back to the button, with the reason above it. Leaving the panel in
          // the "voice is on" shape after a join that never happened would offer
          // "Isključi glas" for a channel nobody is in, and hide the one control
          // that would let them try again.
          isVoiceOn = false;
        }
      });
    }
  }

  /// Rejoins the voice channel, which is the only way a changed right takes
  /// effect: the role lives in the token, and a token is issued once at join.
  ///
  /// Used when the trainer grants or takes back the microphone while the lesson
  /// is running. Waiting for the next lesson would make "oduzmi mikrofon" mean
  /// something other than what anybody pressing it expects.
  Future<void> _rejoinVoice() async {
    // Nothing to rejoin, and joining here would open a channel the person never
    // asked for — which is the whole thing [isVoiceOn] exists to prevent. The
    // right itself is not lost: the server is asked again at the next join.
    if (!isVoiceOn) return;
    await _agoraService.leaveChannel();
    await _initAudioChat();
  }

  void _toggleLocalMute() {
    final nextMute = !isAudioMuted;
    _agoraService.toggleMute(nextMute);
    socket.emit('audio_mute_toggle', {
      'roomId': widget.roomCode,
      'userId': widget.userSession.id,
      'isMuted': nextMute,
    });
  }

  /// The three ready answers, and nothing else.
  ///
  /// A fixed set rather than free text on purpose: it is everything a lesson
  /// needs answered by voice — and it is the reason this app is not a place
  /// where a child can be asked for their address.
  static const Map<String, String> _quickAnswers = {
    'da': 'Da',
    'ne': 'Ne',
    'nejasno': 'Nisam razumeo/la',
  };

  String? _quickAnswerText(String? key) => _quickAnswers[key ?? ''];

  void _sendQuickAnswer(String key) {
    socket.emit('quick_answer', {
      'roomId': widget.roomCode,
      'answer': key,
    });
  }

  /// Grants or takes back a student's microphone, for good rather than for this
  /// minute.
  ///
  /// Deliberately not the same control as „Utišaj učenika" a few lines below:
  /// muting is a courtesy the client honours, this is the row the voice token is
  /// minted from. The student's app rejoins the channel when it hears about it,
  /// which is what makes taking it back mean anything at all.
  Future<void> _setStudentVoice(int studentId, bool mayTalk) async {
    try {
      final res = await http.patch(
        Uri.parse('$backendUrl/trainer/students/$studentId/voice'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}',
        },
        body: jsonEncode({'level': mayTalk ? 'talk' : 'listen'}),
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        final data = jsonDecode(res.body);
        AppFeedback.show(
            context,
            () => SnackBar(
                  content: Text(data['error']?.toString() ?? 'Nije uspelo.'),
                  backgroundColor: Colors.redAccent,
                ));
        return;
      }
      AppFeedback.show(
          context,
          () => SnackBar(
                content: Text(mayTalk
                    ? 'Učenik je dobio mikrofon.'
                    : 'Učeniku je oduzet mikrofon — i dalje sluša i odgovara na tabli.'),
                backgroundColor: mayTalk ? Colors.green : Colors.orange,
              ));
    } catch (e) {
      if (!mounted) return;
      AppFeedback.show(
          context,
          () => const SnackBar(
                content: Text('Server nije dostupan.'),
                backgroundColor: Colors.redAccent,
              ));
    }
  }

  void _raiseHand() {
    socket.emit('audio_raise_hand', {
      'roomId': widget.roomCode,
      'userId': widget.userSession.id,
    });
    setState(() {
      isHandRaised = true;
    });
  }

  /// A dial moved: remember it and ask the engine again about this position.
  void _applyAnalysisDials({int? depth, int? lines}) {
    setState(() {
      if (depth != null) _analysisDepth = depth;
      if (lines != null) _analysisLines = lines;
    });
    if (depth != null) AppSettingsService.instance.setAnalysisDepth(depth);
    if (lines != null) AppSettingsService.instance.setAnalysisLines(lines);
    _triggerEngineAnalysis();
  }

  void _triggerEngineAnalysis() {
    if (isEngineEnabled) {
      setState(() {
        engineLines.clear();
        currentEngineEval = "0.00";
        bestEngineMove = "-";
        _currentRawEval = 0.0;
        _currentEvalDepth = 0;
      });
      // The board's own dials, not two numbers written into this line. They
      // used to be 10 or 16 plies and three lines, fixed, with no way to ask
      // this board for more.
      final isInfinite = engineThinkingMode == 'infinite';
      _stockfishService.setMultiPV(_analysisLines);
      _stockfishService.analyzePosition(
        controller.getFen(),
        depth: _analysisDepth,
        isInfinite: isInfinite,
      );
    }
  }

  Widget _buildStockfishAnalysisWidget() {
    final sortedKeys = engineLines.keys.toList()..sort();
    final List<AnalysisLine> linesList =
        sortedKeys.map((k) => engineLines[k]!).toList();
    final isStudio = widget.roomCode == 'STUDIO';
    final isTrener = activeRole == 'trener' || isStudio;
    final isAllowedToUseEngine = isTrener || isStudio || allowStudentEngine;

    return StockfishAnalysisWidget(
      isEngineEnabled: isEngineEnabled,
      isAllowedToUseEngine: isAllowedToUseEngine,
      analysisDepth: _analysisDepth,
      analysisLines: _analysisLines,
      onAnalysisDepthChanged: (value) => _applyAnalysisDials(depth: value),
      onAnalysisLinesChanged: (value) => _applyAnalysisDials(lines: value),
      isOnline: _stockfishService.isOnline,
      isCustomEngineActive: _stockfishService.isCustomEngineActive,
      lines: linesList,
      orientation: boardOrientation,
      isShowEvalBarEnabled: _showEvalBar,
      onToggleShowEvalBar: () {
        setState(() {
          _showEvalBar = !_showEvalBar;
        });
      },
      onToggleEngine: () async {
        setState(() {
          isEngineEnabled = !isEngineEnabled;
        });
        if (isEngineEnabled) {
          await _stockfishService.initEngine();
          engineLines.clear();
          _triggerEngineAnalysis();
        } else {
          _stockfishService.stopAnalysis();
          setState(() {
            currentEngineEval = "0.00";
            bestEngineMove = "-";
            engineLines.clear();
          });
        }
      },
      onOpenSettings:
          (!kIsWeb && Platform.isWindows) ? _showEngineSettingsDialog : null,
      onForceRestart: () {
        _stockfishService.stopAnalysis();
        _triggerEngineAnalysis();
      },
      onLoadFenToMainBoard: (fen) {
        loadLessonPosition(fen, null);
        _showSuccess('Učitana pozicija iz linije analize!');
      },
    );
  }

  Widget _buildChessBoardWithOverlay(double boardSize) {
    final isHost = activeRole == 'host' ||
        activeRole == 'trener' ||
        widget.userSession.role == 'trener' ||
        widget.roomCode == 'STUDIO';
    final isAllowedToMove = canDriveSharedBoard;
    final isAllowedToUseEngine = isHost || allowStudentEngine;

    final List<EngineArrow> engineArrows =
        (isEngineEnabled && isAllowedToUseEngine)
            ? engineLines.values
                .map((line) => EngineArrow(
                      from: line.fromSquare,
                      to: line.toSquare,
                      evalText: line.evaluation,
                      rank: line.multipv,
                    ))
                .where((a) => a.from.isNotEmpty && a.to.isNotEmpty)
                .toList()
            : [];

    return BoardWithCoordinates(
      size: boardSize,
      orientation: boardOrientation,
      builder: (size) => ChessBoardWithOverlay(
        controller: controller,
        boardOrientation: boardOrientation,
        boardSize: size,
        isAllowedToMove: isAllowedToMove,
        isDrawingMode: isDrawingMode,
        drawingStartSquare: drawingStartSquare,
        arrows: moveTree.current.arrows,
        engineArrows: engineArrows,
        onMove: _handleLocalMoveMade,
        onSquareTapForDrawing: (square) {
          setState(() {
            if (drawingStartSquare == null) {
              drawingStartSquare = square;
            } else {
              final start = drawingStartSquare!;
              drawingStartSquare = null;
              if (start != square) {
                moveTree.current.arrows.add(ChessArrow(
                  from: start,
                  to: square,
                  colorCode: selectedArrowColorCode,
                ));
                _recordEvent('arrow_drawn', {
                  'arrows': moveTree.current.arrows
                      .map((a) => {
                            'from': a.from,
                            'to': a.to,
                            'colorCode': a.colorCode
                          })
                      .toList()
                });
                socket.emit('pgn_loaded', {
                  'roomId': widget.roomCode,
                  'pgn': moveTree.exportToPgn(),
                });
              }
            }
          });
        },
      ),
    );
  }

  Widget _buildColorButton(String code, ui.Color color, String tooltip) {
    return ArrowColorButton(
      color: color,
      tooltip: tooltip,
      isSelected: selectedArrowColorCode == code,
      onTap: () {
        setState(() {
          selectedArrowColorCode = code;
        });
      },
    );
  }

  Future<void> _showEngineSettingsDialog() async {
    if (!mounted) return;
    await showEngineSettingsDialog(
      context,
      stockfishService: _stockfishService,
      isEngineEnabled: isEngineEnabled,
    );
    if (mounted) setState(() {});
  }

  List<String> getPathToNode(MoveNode node) {
    final List<String> path = [];
    MoveNode? curr = node;
    while (curr != null && curr.san != 'Root') {
      path.insert(0, curr.san);
      curr = curr.parent;
    }
    return path;
  }

  MoveNode? findNodeByPath(MoveNode rootNode, List<String> path) {
    MoveNode curr = rootNode;
    for (var san in path) {
      MoveNode? child;
      for (final c in curr.children) {
        if (c.san == san) {
          child = c;
          break;
        }
      }
      if (child == null) return null;
      curr = child;
    }
    return curr;
  }

  void initSocket() {
    // Configure socket.io client connection to server.
    // The auth token is what the server trusts for identity and host privileges —
    // the role sent in joinGame below is only an optimistic local default.
    socket = io.io(
        backendUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNewConnection()
            .disableAutoConnect()
            .setAuth({'token': widget.userSession.token})
            .build());

    socket.connect();

    socket.onConnect((_) {
      final isStudio = widget.roomCode == 'STUDIO';
      setState(() {
        isConnected = true;
        gameStatus = isStudio ? 'Šahovski studio' : "Soba: ${widget.roomCode}";
      });

      // The studio is a local board, not a room: there is no `rooms` row named
      // STUDIO and there must not be one. Asking to join it made the guest list
      // answer the only way it can — `no-room` — and the screen did what a
      // refusal says to do: a snackbar reading "Ne postoji soba sa tim kodom"
      // and straight back out. Joining also put every studio in the world into
      // one socket room called STUDIO, so one person's moves were broadcast
      // into somebody else's analysis.
      if (isStudio) return;

      // Join room passing role and roomCode
      socket.emit('joinGame', {
        'roomId': widget.roomCode,
        'playerColor': widget.userSession.role == 'trener' ? 'white' : 'black',
        'userId': widget.userSession.id,
        'userName': widget.userSession.name,
        'role': widget.userSession.role,
      });
    });

    // A room reached with a token the server will not take any more. The
    // handshake is refused before anything on this screen asks for anything, so
    // this is the earliest and clearest place it can be heard — and ending the
    // session here is what takes the user to the login screen instead of
    // leaving them in front of a board that never fills.
    socket.onConnectError((err) {
      if (!looksLikeRefusedToken(err)) return;
      unawaited(SessionService.instance.expire());
    });

    socket.onDisconnect((_) {
      if (_isDisposing || !mounted) return;
      setState(() {
        isConnected = false;
        gameStatus = "Prekinuta veza sa serverom";
      });
    });

    // The server rejects privileged actions it did not authorize; surface that
    // instead of letting the action fail silently.
    socket.on('action_denied', (data) {
      if (!mounted) return;
      final reason = (data is Map && data['reason'] != null)
          ? data['reason'].toString()
          : 'Nemate ovlašćenje za ovu akciju.';
      AppFeedback.show(
        context,
        () =>
            SnackBar(content: Text(reason), backgroundColor: Colors.redAccent),
      );
    });

    // The room has a guest list now, and a refusal has to arrive as a sentence.
    // Left unhandled it would read as "connecting…" forever, which is the same
    // silent failure this project keeps meeting — and here it would be worse,
    // because the person refused is usually somebody who simply mistyped the
    // code.
    socket.on('join_refused', (data) {
      if (!mounted) return;
      final reason = (data is Map ? data['reason']?.toString() : null) ?? '';
      const messages = {
        'no-room': 'Ne postoji soba sa tim kodom.',
        'guest-not-allowed':
            'Ova soba ne prima goste — prijavite se ili tražite poziv.',
        'not-invited': 'Niste na spisku za ovu sobu. Tražite poziv od trenera.',
      };
      final text = messages[reason] ?? 'Ulazak u sobu nije dozvoljen.';
      AppFeedback.show(
        context,
        () => SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
      );
      // And out, rather than sitting in a room that never fills: the board
      // would stay empty and the reason would scroll away with the snackbar.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    });

    socket.on('gameState', (data) {
      if (data != null) {
        setState(() {
          if (data['currentFen'] != null) {
            controller.loadFen(data['currentFen']);
            moveTree = MoveTree(startingFen: data['currentFen']);
            commentController.text = '';
          }
          if (data['boardControl'] != null) {
            boardControl = data['boardControl'];
          }
          if (data['allowStudentEngine'] != null) {
            allowStudentEngine = data['allowStudentEngine'];
          }
        });
      }
    });

    socket.on('permissions_updated', (data) {
      if (data != null && data['boardControl'] != null) {
        setState(() {
          boardControl = data['boardControl'];
        });
        AppFeedback.show(
          context,
          () => SnackBar(
            content: Text(
                'Dozvole table promenjene: ${_getPermissionLabel(boardControl)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    socket.on('engine_permission_updated', (data) {
      if (data != null && data['allowStudentEngine'] != null) {
        setState(() {
          allowStudentEngine = data['allowStudentEngine'];
          // If permission is revoked, force disable and turn off engine for ucenik
          if (!allowStudentEngine && widget.userSession.role == 'ucenik') {
            isEngineEnabled = false;
            _stockfishService.stopAnalysis();
            currentEngineEval = "0.00";
            bestEngineMove = "-";
            engineLines.clear();
            _showError('Trener je onemogućio kompjutersku analizu za učenike.');
          }
        });
      }
    });

    socket.on('flip_board_forced', (data) {
      if (data != null && data['orientation'] != null) {
        setState(() {
          boardOrientation = data['orientation'] == 'white'
              ? PlayerColor.white
              : PlayerColor.black;
        });
        AppFeedback.show(
          context,
          () => SnackBar(
            content: Text(
                'Trener je okrenuo vašu tablu na: ${data['orientation'] == 'white' ? 'Beli' : 'Crni'}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    socket.on('moveMade', (data) {
      if (data != null) {
        setState(() {
          if (data['currentFen'] != null) {
            final newFen = data['currentFen'];
            controller.loadFen(newFen);
            _recordEvent('move', {'fen': newFen, 'move': data['move']});

            if (data['move'] == null) {
              // This is a navigation jump
              if (data['movePath'] != null) {
                final List<String> path = List<String>.from(data['movePath']);
                final matched = findNodeByPath(moveTree.root, path);
                if (matched != null) {
                  moveTree.current = matched;
                  commentController.text = matched.comment;
                }
              }
            } else {
              // Standard move played by peer
              final from = data['move']['from'];
              final to = data['move']['to'];

              // Check if we already have it
              MoveNode? matchingChild;
              for (final c in currentNode.children) {
                if (c.from == from && c.to == to) {
                  matchingChild = c;
                  break;
                }
              }

              if (matchingChild != null) {
                moveTree.current = matchingChild;
                commentController.text = matchingChild.comment;
              } else {
                // Compute SAN representation of the move
                final tempGame = chess.Chess();
                tempGame.load(currentNode.fen);
                final success = tempGame.move({'from': from, 'to': to});
                String san = '$from➔$to';
                if (success) {
                  final moveObj = tempGame.history.last.move;
                  tempGame.undo_move();
                  san = tempGame.move_to_san(moveObj);
                }

                final newNode = MoveNode(
                  san: san,
                  fen: newFen,
                  from: from,
                  to: to,
                  parent: currentNode,
                );
                currentNode.children.add(newNode);
                moveTree.current = newNode;
                commentController.text = '';
              }
            }
            _triggerEngineAnalysis();
          }
        });
      }
    });

    // Real-time synchronization when Trainer loads PGN
    socket.on('pgn_loaded', (data) {
      if (data != null && data['pgn'] != null) {
        final path = getPathToNode(moveTree.current);
        final parsed =
            MoveTree.parsePgn(data['pgn'], startingFen: moveTree.root.fen);
        if (parsed != null) {
          final matchingNode = findNodeByPath(parsed.root, path);
          parsed.current = matchingNode ?? parsed.root;
          setState(() {
            moveTree = parsed;
            commentController.text = moveTree.current.comment;
          });
        }
      }
    });

    socket.on('room_members_list', (data) {
      if (mounted) {
        setState(() {
          roomMembers = data;
          final me = roomMembers.firstWhere(
            (m) => m['userId'] == widget.userSession.id,
            orElse: () => null,
          );
          if (me != null && me['role'] != null) {
            activeRole = me['role'];
          }
        });
      }
    });

    socket.on('user_role_changed', (data) {
      if (data != null && mounted) {
        final targetUserId = data['targetUserId'];
        final newRole = data['newRole'];
        if (targetUserId == widget.userSession.id) {
          setState(() {
            activeRole = newRole;
          });
          AppFeedback.show(
            context,
            () => SnackBar(
              content: Text(
                newRole == 'trener'
                    ? 'Promovisani ste u ulogu Trenera! Sada imate punu kontrolu nad tablom i sesijom.'
                    : 'Vaša uloga je vraćena na Učenik.',
              ),
              backgroundColor: newRole == 'trener' ? Colors.teal : Colors.amber,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });

    // Whether this room may be recorded, sent whenever the roster changes —
    // the only moment the answer can change.
    socket.on('recording_consent', (data) {
      if (data == null || !mounted) return;
      setState(() {
        _recordingAllowed = data['allowed'] != false;
        _recordingBlockedReason = data['reason'] as String?;
      });
    });

    // The lock answering: the recording was started without permission. The
    // local recorder is stopped and thrown away rather than offered for saving
    // — a refused recording that is still on the device waiting for a "Sačuvaj"
    // is a refused recording that gets saved.
    socket.on('recording_denied', (data) {
      if (data == null || !mounted) return;
      final reason = data['reason'] as String? ??
          'Zvuk se snima samo dok ste sami u sobi.';
      setState(() {
        _recordingAllowed = false;
        _recordingBlockedReason = reason;
      });
      _discardRecording(reason);
    });

    // Somebody walked into a lesson that was being recorded, and their parent
    // has not agreed to that. What was recorded before they arrived is kept —
    // they were not in it — so this stops the way the trainer would.
    socket.on('recording_must_stop', (data) {
      if (data == null || !mounted) return;
      final reason = data['reason'] as String? ??
          'Snimanje je zaustavljeno — u sobu je ušao još neko.';
      setState(() {
        _recordingAllowed = false;
        _recordingBlockedReason = reason;
      });
      if (isRecording) {
        // Stop first, tell afterwards. The other way round cost exactly this
        // rule once already: `showSnackBar` threw "deactivated widget's
        // ancestor", and the line below it — the one that actually stops
        // recording a child whose parent refused — never ran.
        unawaited(_stopRecording());
        AppFeedback.warning(context, '$reason Snimanje je zaustavljeno.');
      }
    });

    socket.on('recording_status_update', (data) {
      if (data != null && mounted) {
        final status = data['status'];
        final startTimeMs = data['recordingStartTimeMs'];
        final isPaused = data['paused'] ?? false;
        final updatedBy = data['updatedBy'] ?? 'Domaćin';

        setState(() {
          if (status == 'started') {
            isRecording = true;
            isRecordingPaused = false;
            recordingStartTimeMs =
                startTimeMs ?? DateTime.now().millisecondsSinceEpoch;
          } else if (status == 'paused') {
            isRecordingPaused = true;
          } else if (status == 'resumed') {
            isRecordingPaused = false;
          } else if (status == 'stopped') {
            isRecording = false;
            isRecordingPaused = false;
          }
        });

        AppFeedback.show(
          context,
          () => SnackBar(
            content: Text(status == 'started'
                ? '$updatedBy je započeo snimanje sesije.'
                : (status == 'paused'
                    ? '$updatedBy je pauzirao snimanje.'
                    : (status == 'resumed'
                        ? '$updatedBy je nastavio snimanje.'
                        : '$updatedBy je zaustavio snimanje.'))),
            duration: const Duration(seconds: 2),
            backgroundColor:
                status == 'started' ? Colors.redAccent : Colors.amber,
          ),
        );
      }
    });

    socket.on('student_position_shared', (data) {
      if (data != null && mounted) {
        final String studentName = data['studentName'] ?? 'Učenik';
        final String title = data['title'] ?? 'Pozicija';
        final String fen = data['fen'];
        final String? pgn = data['pgn'];

        if (widget.userSession.role == 'trener') {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.share, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Predložena pozicija'),
                ],
              ),
              content: Text(
                  'Učenik $studentName predlaže poziciju: "$title". Da li želite da je učitate na tablu?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Zatvori'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    loadLessonPosition(fen, pgn);
                  },
                  child: const Text('Učitaj na tablu'),
                ),
              ],
            ),
          );
        } else {
          AppFeedback.show(
            context,
            () => SnackBar(
              content:
                  Text('Učenik $studentName je podelio poziciju: "$title"'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      }
    });

    // AGORA AUDIO CLASSROOM LISTENERS
    socket.on('audio_users_list', (data) {
      if (mounted) {
        setState(() {
          audioUsers = data;
          final selfAudioUser = audioUsers.firstWhere(
            (u) => u['userId'] == widget.userSession.id,
            orElse: () => null,
          );
          if (selfAudioUser != null) {
            isHandRaised = selfAudioUser['handRaised'] ?? false;
          }
        });
      }
    });

    // The trainer granted or took back the microphone. The right lives in the
    // voice token, and a token is issued once when the channel is joined — so
    // the channel is joined again. Without this, "oduzmi mikrofon" would mean
    // "from the next lesson", which is not what anybody pressing it expects.
    socket.on('voice_level_changed', (data) async {
      if (!mounted) return;
      final mayTalk = data is Map && data['level'] == 'talk';
      // Said differently while the voice is off, because "mikrofon je uključen"
      // would be a sentence about something that is not happening: nothing is
      // open until this person opens it.
      final voiceOn = isVoiceOn;
      AppFeedback.show(
        context,
        () => SnackBar(
          content: Text(mayTalk
              ? (voiceOn
                  ? 'Trener vam je dao reč. Mikrofon je uključen.'
                  : 'Trener vam je dao reč. Važi čim uključite glas.')
              : (voiceOn
                  ? 'Trener je isključio vaš mikrofon. I dalje čujete čas i '
                      'odgovarate na tabli.'
                  : 'Trener je isključio vaš mikrofon.')),
          backgroundColor: mayTalk ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      await _rejoinVoice();
    });

    // A ready answer from a student who is listening. It is the whole reason
    // listening-only is a lesson rather than a broadcast: the trainer asks
    // "jasno?" and gets an answer without anybody's voice being published.
    socket.on('quick_answer', (data) {
      if (!mounted || data is! Map) return;
      final who = data['userName']?.toString() ?? 'Učenik';
      final said = _quickAnswerText(data['answer']?.toString());
      if (said == null) return;
      AppFeedback.show(
        context,
        () => SnackBar(
          content: Text('$who: $said'),
          backgroundColor: Colors.blueGrey,
          duration: const Duration(seconds: 3),
        ),
      );
    });

    socket.on('audio_force_mute_student', (data) {
      final targetUserId = data['targetUserId'];
      if (targetUserId == 'all' || targetUserId == widget.userSession.id) {
        if (widget.userSession.role == 'ucenik') {
          _agoraService.toggleMute(true);
          socket.emit('audio_mute_toggle', {
            'roomId': widget.roomCode,
            'userId': widget.userSession.id,
            'isMuted': true,
          });
          AppFeedback.show(
            context,
            () => const SnackBar(
              content: Text(
                  'Trener vas je utišao. Možete podići ruku ako želite reč.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });

    socket.on('audio_force_unmute_student', (data) {
      final targetUserId = data['targetUserId'];
      if (targetUserId == widget.userSession.id) {
        if (widget.userSession.role == 'ucenik') {
          _agoraService.toggleMute(false);
          socket.emit('audio_mute_toggle', {
            'roomId': widget.roomCode,
            'userId': widget.userSession.id,
            'isMuted': false,
          });
          AppFeedback.show(
            context,
            () => const SnackBar(
              content: Text('Trener vam je dozvolio reč.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });

    socket.on('audio_hand_raised_alert', (data) {
      final userName = data['userName'];
      if (widget.userSession.role == 'trener') {
        AppFeedback.show(
          context,
          () => SnackBar(
            content: Text('Učenik $userName želi reč.'),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  /// Mirrors whether *someone in the room* is recording, which the server tells
  /// every client. Separate from [_recorder], which is only ever active on the
  /// device that actually started the recording — a student sees the indicator
  /// but buffers nothing.
  bool isRecordingPaused = false;

  void _recordEvent(String eventType, Map<String, dynamic> data) {
    // The recorder decides whether to keep this; callers are scattered all over
    // this screen and each one checking first is how one of them forgets.
    _recorder.record(eventType, data);
  }

  String? _currentAudioPath;

  /// Throws away a recording that should never have started.
  ///
  /// Separate from `_stopRecording`, which offers to save: there is nothing
  /// here to offer. The audio file is stopped and the buffered events dropped.
  Future<void> _discardRecording(String reason) async {
    try {
      await _agoraService
          .stopAudioRecording()
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      print('[RECORDING_LOG] Discard: audio stop failed: $e');
    }
    _recorder.reset();
    if (!mounted) return;
    setState(() {
      isRecording = false;
      isRecordingPaused = false;
      recordingStartTimeMs = null;
    });
    AppFeedback.warning(context, '$reason Snimak nije sačuvan.');
  }

  Future<void> _startRecording() async {
    // Asked before anything is recorded, so a refused room never produces a
    // file at all. The server refuses again on its own; this is what keeps
    // somebody else's voice from being captured for the second it takes to be
    // told so. Since 26.8.2026 the rule is not consent but solitude: audio is
    // recorded by an adult alone in the room, and a lesson is never recorded.
    if (!_recordingAllowed) {
      AppFeedback.warning(
        context,
        _recordingBlockedReason ?? 'Zvuk se snima samo dok ste sami u sobi.',
      );
      return;
    }

    try {
      _currentAudioPath =
          '${Directory.systemTemp.path}/session_audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _agoraService.startAudioRecording(_currentAudioPath!);
    } catch (e) {
      print('Error starting Agora audio recording: $e');
    }

    if (!mounted) return;

    _recorder.start(
      initialEventType: 'init',
      initialData: {
        'fen': moveTree.current.fen,
        'orientation':
            boardOrientation == PlayerColor.white ? 'white' : 'black',
        'boardControl': boardControl,
      },
    );

    setState(() {
      isRecording = true;
      isRecordingPaused = false;
      recordingStartTimeMs = _recorder.startedAtMs;
    });

    socket.emit('recording_status_update', {
      'roomId': widget.roomCode,
      'status': 'started',
      'recordingStartTimeMs': recordingStartTimeMs,
      'fen': moveTree.current.fen
    });

    AppFeedback.warning(context,
        'Snimanje časa i zvuka (glasa) je započeto! Svi potezi i govor se beleže.');
  }

  void _pauseRecording() {
    if (!isRecording || isRecordingPaused) return;
    _recorder.pause();
    setState(() => isRecordingPaused = true);

    socket.emit('recording_status_update', {
      'roomId': widget.roomCode,
      'status': 'paused',
      'paused': true,
    });

    AppFeedback.show(
      context,
      () => const SnackBar(
        content: Text('Snimanje je pauzirano. Akcije se privremeno ne beleže.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resumeRecording() {
    if (!isRecording || !isRecordingPaused) return;
    _recorder.resume();
    setState(() => isRecordingPaused = false);

    socket.emit('recording_status_update', {
      'roomId': widget.roomCode,
      'status': 'resumed',
      'paused': false,
    });

    AppFeedback.show(
      context,
      () => const SnackBar(
        content: Text(
            'Snimanje je nastavljeno! Svi sledstveni potezi se beleže u kombinovani snimak.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _stopRecording() async {
    socket.emit('recording_status_update', {
      'roomId': widget.roomCode,
      'status': 'stopped',
    });
    print('[RECORDING_LOG] 1. Stopping Agora audio recording...');
    try {
      await _agoraService
          .stopAudioRecording()
          .timeout(const Duration(seconds: 3));
      print('[RECORDING_LOG] 2. Agora audio recording stopped successfully.');
    } catch (e) {
      print('[RECORDING_LOG] 2. Agora audio recording stop error/timeout: $e');
    }

    if (!mounted) return;

    final titleController = TextEditingController(
        text:
            'Čas ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Završetak i sačuvanje snimka časa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unesite naziv snimljenog časa:'),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Naziv časa',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ukupno zabeleženo događaja: ${_recorder.eventCount}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Prekini bez čuvanja'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sačuvaj snimak'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      print('[RECORDING_LOG] User cancelled recording save.');
      _recorder.reset();
      setState(() {
        isRecording = false;
        isRecordingPaused = false;
        recordingStartTimeMs = null;
      });
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) return;

    try {
      print('[RECORDING_LOG] 1. Saving recording instantly on device...');
      // stop() hands over its own copies, so the reset below cannot empty them
      // out from under the upload.
      final recorded = _recorder.stop();
      final List<int> participantIds = [];
      for (var m in roomMembers) {
        if (m is Map && m['userId'] is int) {
          participantIds.add(m['userId'] as int);
        }
      }

      await LocalRecordingService.saveLocally(
        roomId: widget.roomCode,
        title: title,
        events: recorded.events,
        pauses: recorded.pauses,
        audioPath: _currentAudioPath,
        participants: participantIds,
      );

      if (!mounted) return;

      AppFeedback.show(
        context,
        () => const SnackBar(
          content: Text(
              'Snimak časa je sačuvan na vašem uređaju! Sinhronizacija sa serverom se vrši u pozadini.'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 4),
        ),
      );

      // Sync first, and only then say what came back — the same order the rest
      // of this screen owes to `_stopRecording`. The server's answer is not
      // decoration: it is where the trainer learns that the recording was cut
      // short by a parent's refusal, or that the refusal could not be checked
      // at all before they share it.
      //
      // In its own `try`, and after the local save has already been reported:
      // the recording is on the device either way, and a sync that throws must
      // not come out as "greška pri čuvanju lokalnog snimka" — that is the same
      // lie in a smaller size.
      List<String> notices = const [];
      try {
        notices = await LocalRecordingService.syncPendingRecordings(
            widget.userSession.token);
      } catch (e) {
        print('[SYNC_RECORDING_ERROR] $e');
      }
      if (!mounted) return;
      if (notices.isNotEmpty) {
        // One sentence, not a queue of them: a device that was offline for a
        // week comes back with several, and the rest are in the log.
        AppFeedback.warning(
          context,
          notices.length == 1
              ? notices.first
              : '${notices.first} (još ${notices.length - 1} napomena servera '
                  'je u dnevniku.)',
        );
      }
    } catch (e) {
      print('[RECORDING_LOG_ERROR] Exception in instant local save: $e');
      if (!mounted) return;
      AppFeedback.show(
        context,
        () => SnackBar(
            content: Text('Greška pri čuvanju lokalnog snimka: $e'),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        isRecording = false;
        isRecordingPaused = false;
        recordingStartTimeMs = null;
        _recorder.reset();
      });
    }
  }

  String _getPermissionLabel(String control) {
    switch (control) {
      case 'trainer_only':
        return 'Samo Trener';
      case 'student_white':
        return 'Učenik vuče samo Bele';
      case 'student_black':
        return 'Učenik vuče samo Crne';
      case 'student_both':
        return 'Slobodna analiza';
      default:
        return control;
    }
  }

  void _toggleLocalOrientation() {
    setState(() {
      boardOrientation = boardOrientation == PlayerColor.white
          ? PlayerColor.black
          : PlayerColor.white;
    });
  }

  void _changeStudentPermissions(String? newPermission) {
    if (newPermission == null) return;
    socket.emit('change_permissions', {
      'roomId': widget.roomCode,
      'boardControl': newPermission,
    });
  }

  void _forceStudentOrientation(String targetOrientation) {
    socket.emit('force_flip_board', {
      'roomId': widget.roomCode,
      'orientation': targetOrientation,
    });
  }

  Future<void> fetchUserLabels() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/lessons/labels'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}'
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _availableUserLabels = List<String>.from(data);
          });
        }
      }
    } catch (e) {
      print('Error fetching user labels: $e');
    }
  }

  // REST API: Fetch saved lessons (with search and matrix label filters)
  Future<void> fetchLessons({
    String? searchQuery,
    List<String>? includeTags,
    List<String>? excludeTags,
    String? matchMode,
  }) async {
    setState(() => isLoadingLessons = true);
    try {
      final queryParams = <String, String>{};
      final queryText = searchQuery ?? searchController.text.trim();
      if (queryText.isNotEmpty) {
        queryParams['search'] = queryText;
      }
      final includes = includeTags ?? _selectedIncludeTags;
      if (includes.isNotEmpty) {
        queryParams['includeTags'] = includes.join(',');
      }
      final excludes = excludeTags ?? _selectedExcludeTags;
      if (excludes.isNotEmpty) {
        queryParams['excludeTags'] = excludes.join(',');
      }
      queryParams['matchMode'] = matchMode ?? _filterMatchMode;

      final uri = Uri.parse('$backendUrl/lessons')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            lessons = data;
          });
        }
      }
    } catch (e) {
      _showError('Greška prilikom učitavanja lekcija sa servera.');
    } finally {
      if (mounted) {
        setState(() => isLoadingLessons = false);
      }
    }
  }

  Future<void> _confirmDeleteLesson(Map<String, dynamic> lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obriši lekciju?'),
        content: Text('"${lesson['title']}" će biti trajno obrisana.'),
        actions: [
          TextButton(
              child: const Text('Otkaži'),
              onPressed: () => Navigator.pop(ctx, false)),
          TextButton(
            child:
                const Text('Obriši', style: TextStyle(color: Colors.redAccent)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('$backendUrl/lessons/${lesson['id']}'),
        headers: {'Authorization': 'Bearer ${widget.userSession.token}'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _showSuccess('Lekcija obrisana.');
        fetchLessons();
      } else {
        _showError('Brisanje nije uspelo.');
      }
    } catch (e) {
      if (mounted) _showError('Greška na mreži pri brisanju.');
    }
  }

  // Rename/re-describe a single (non-course) saved position. FEN/PGN stay
  // untouched — reposition it via Board Setup and save a new one for that.
  Future<void> _editSinglePosition(Map<String, dynamic> lesson) async {
    final titleController = TextEditingController(text: lesson['title'] ?? '');
    final descController =
        TextEditingController(text: lesson['description'] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Izmeni poziciju'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Naziv'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Opis (opciono)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              child: const Text('Otkaži'),
              onPressed: () => Navigator.pop(ctx, false)),
          ElevatedButton(
              child: const Text('Sačuvaj'),
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirmed != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) {
      _showError('Unesite naziv.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$backendUrl/lessons/${lesson['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}',
        },
        body: jsonEncode({
          'title': title,
          'description': descController.text.trim(),
          'tags': lesson['tags'],
          'fen': lesson['fen'],
          'pgn': lesson['pgn'],
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _showSuccess('Pozicija izmenjena.');
        fetchLessons();
      } else {
        _showError('Izmena nije uspela.');
      }
    } catch (e) {
      if (mounted) _showError('Greška na mreži pri izmeni.');
    }
  }

  // REST API: Save current board FEN with description and tags
  Future<void> saveCurrentPosition(
      String title, String description, List<String> tags) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/lessons/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}'
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'tags': tags,
          'fen': controller.getFen(),
          'pgn': moveTree.exportToPgn(),
        }),
      );

      if (response.statusCode == 201) {
        _showSuccess('Lekcija sa varijacijama je uspešno sačuvana!');
        fetchLessons();
      } else {
        final data = jsonDecode(response.body);
        _showError(data['error'] ?? 'Neuspešno čuvanje lekcije');
      }
    } catch (e) {
      _showError('Greška na mreži pri čuvanju lekcije.');
    }
  }

  // Socket: Load lesson position to board and broadcast
  void loadLessonPosition(String fen, String? pgn) {
    _recordEvent('lesson_loaded', {'fen': fen, 'pgn': pgn});
    if (pgn != null && pgn.isNotEmpty) {
      final parsed = MoveTree.parsePgn(pgn, startingFen: fen);
      if (parsed != null) {
        setState(() {
          moveTree = parsed;
          commentController.text = moveTree.current.comment;
        });

        controller.loadFen(moveTree.current.fen);

        socket.emit('move', {
          'roomId': widget.roomCode,
          'move': null,
          'currentFen': moveTree.current.fen,
          'role': widget.userSession.role,
          'movePath': getPathToNode(moveTree.current),
        });

        socket.emit('pgn_loaded', {
          'roomId': widget.roomCode,
          'pgn': pgn,
        });

        _showSuccess('Lekcija sa varijacijama je učitana!');
        _triggerEngineAnalysis();
        return;
      }
    }

    setState(() {
      controller.loadFen(fen);
      moveTree = MoveTree(startingFen: fen);
      commentController.text = '';
      moveHistory.add('Učitana lekcija/FEN pozicija');
    });

    socket.emit('move', {
      'roomId': widget.roomCode,
      'move': null,
      'currentFen': fen,
      'role': widget.userSession.role,
      'movePath': <String>[],
    });

    socket.emit('pgn_loaded', {
      'roomId': widget.roomCode,
      'pgn': '',
    });

    _showSuccess('Pozicija učitana i sinhronizovana!');
    _triggerEngineAnalysis();
  }

  // Steps the active live course to [newIndex] and broadcasts that step's
  // position (with its own PGN/comments, if any) via loadLessonPosition.
  void _goToCourseStep(int newIndex) {
    final items = _activeCourseItems;
    if (items == null || newIndex < 0 || newIndex >= items.length) return;
    setState(() => _activeCourseIndex = newIndex);
    final step = items[newIndex];
    loadLessonPosition(step['fen'], step['pgn']);
    _showSuccess(
        'Korak ${newIndex + 1}/${items.length}: "${step['title'] ?? _activeCourseTitle ?? ''}"');
  }

  Widget _buildCourseStepBar() {
    final items = _activeCourseItems;
    if (items == null || !isTrener) return const SizedBox.shrink();
    return CourseStepBar(
      items: items,
      activeIndex: _activeCourseIndex,
      courseTitle: _activeCourseTitle,
      onGoToStep: _goToCourseStep,
      onClose: () => setState(() => _activeCourseItems = null),
    );
  }

  // Jump to specific MoveNode in active history and broadcast state
  void _selectNode(MoveNode node) {
    _recordEvent('fen_change', {'fen': node.fen});
    setState(() {
      moveTree.current = node;
      commentController.text = node.comment;
      drawingStartSquare = null;
    });

    controller.loadFen(node.fen);

    socket.emit('move', {
      'roomId': widget.roomCode,
      'move': null,
      'currentFen': node.fen,
      'role': widget.userSession.role,
      'movePath': getPathToNode(node)
    });

    _triggerEngineAnalysis();
  }

  // Branching/variation promotion helper
  void _promptBranchingDialog(
      String from, String to, String san, String newFen) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Odigran je novi potez'),
          content: const Text(
              'Ovaj potez stvara novu granu (varijaciju). Kako želite da ga dodate?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final newNode = MoveNode(
                  san: san,
                  fen: newFen,
                  from: from,
                  to: to,
                  parent: currentNode,
                );
                setState(() {
                  currentNode.children.add(newNode);
                  moveTree.current = newNode;
                  commentController.text = '';
                });
                _broadcastMoveAndState(from, to, newFen);
              },
              child: const Text('Dodaj kao novu varijaciju'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final newNode = MoveNode(
                  san: san,
                  fen: newFen,
                  from: from,
                  to: to,
                  parent: currentNode,
                );
                setState(() {
                  currentNode.children.insert(0, newNode);
                  moveTree.current = newNode;
                  commentController.text = '';
                });
                _broadcastMoveAndState(from, to, newFen);
              },
              child: const Text('Postavi kao glavnu liniju'),
            ),
          ],
        );
      },
    );
  }

  void _broadcastMoveAndState([String? from, String? to, String? newFen]) {
    final effectiveFen = newFen ?? controller.getFen();
    _recordEvent('move', {
      'fen': effectiveFen,
      'move': (from != null && to != null) ? {'from': from, 'to': to} : null,
    });

    socket.emit('move', {
      'roomId': widget.roomCode,
      'move': (from != null && to != null) ? {'from': from, 'to': to} : null,
      'currentFen': effectiveFen,
      'role': widget.userSession.role,
      'movePath': getPathToNode(moveTree.current),
    });

    socket.emit('pgn_loaded', {
      'roomId': widget.roomCode,
      'pgn': moveTree.exportToPgn(),
    });

    _triggerEngineAnalysis();
  }

  // Handle local moves played by user (branching/promoting or direct adding)
  void _handleLocalMoveMade(String from, String to, String promotion) {
    // Compute SAN representation of the move
    final tempGame = chess.Chess();
    tempGame.load(currentNode.fen);
    // The promotion has to be named or the move is not found at all, and the
    // lesson's move list would show "e7➔e8" where the board shows a queen.
    // The position itself travels to the room as a FEN, so this is about what
    // the move is *called* — which is what everybody reads afterwards.
    final success = tempGame.move({
      'from': from,
      'to': to,
      if (promotion.isNotEmpty) 'promotion': promotion,
    });
    String san = '$from➔$to';
    if (success) {
      final moveObj = tempGame.history.last.move;
      tempGame.undo_move();
      san = tempGame.move_to_san(moveObj);
    }

    final newFen = controller.getFen();

    // Check if matching move is already in children
    MoveNode? matchingChild;
    for (final c in currentNode.children) {
      if (c.from == from && c.to == to) {
        matchingChild = c;
        break;
      }
    }

    if (matchingChild != null) {
      _selectNode(matchingChild);
      return;
    }

    // Branching condition: if there are already variations
    if (currentNode.children.isNotEmpty) {
      _promptBranchingDialog(from, to, san, newFen);
    } else {
      final newNode = MoveNode(
        san: san,
        fen: newFen,
        from: from,
        to: to,
        parent: currentNode,
      );
      setState(() {
        currentNode.children.add(newNode);
        moveTree.current = newNode;
        commentController.text = '';
        drawingStartSquare = null;
      });
      _broadcastMoveAndState(from, to, newFen);
    }
  }

  Future<void> _openLocalPgnFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pgn'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        String content = '';

        if (pickedFile.bytes != null) {
          content = utf8.decode(pickedFile.bytes!);
        } else if (pickedFile.path != null) {
          final file = File(pickedFile.path!);
          content = await file.readAsString();
        } else {
          _showError('Nemoguće pročitati sadržaj fajla.');
          return;
        }

        final games = MoveTree.splitGames(content);
        if (games.isEmpty) {
          _showError('Izabrani fajl ne sadrži važeće PGN partije.');
          return;
        }

        if (games.length == 1) {
          _loadSinglePgnGame(games[0]);
        } else {
          _showGameSelectorDialog(games);
        }
      }
    } catch (e) {
      _showError('Greška pri čitanju PGN fajla: $e');
    }
  }

  void _showGameSelectorDialog(List<PgnGameInfo> games) {
    showDialog(
      context: context,
      builder: (ctx) => GameSelectorDialog(
        games: games,
        onGameSelected: (game) => _loadSinglePgnGame(game),
      ),
    );
  }

  void _loadSinglePgnGame(PgnGameInfo game) {
    String? startingFen;
    for (final key in game.headers.keys) {
      if (key.toLowerCase() == 'fen') {
        startingFen = game.headers[key];
        break;
      }
    }
    final parsed = MoveTree.parsePgn(game.pgnBody, startingFen: startingFen);
    if (parsed != null && parsed.root.children.isNotEmpty) {
      setState(() {
        moveTree = parsed;
        commentController.text = moveTree.current.comment;
      });

      controller.loadFen(moveTree.root.fen);

      socket.emit('move', {
        'roomId': widget.roomCode,
        'move': null,
        'currentFen': moveTree.root.fen,
        'role': widget.userSession.role,
        'movePath': <String>[],
      });

      socket.emit('pgn_loaded', {
        'roomId': widget.roomCode,
        'pgn': moveTree.exportToPgn(),
      });

      _showSuccess('Učitana partija: ${game.displayName}');
      _triggerEngineAnalysis();
    } else {
      _showError('Neuspešno parsiranje PGN partije.');
    }
  }

  Widget _buildMatrixFilterPanel() {
    return MatrixFilterPanel(
      availableUserLabels: _availableUserLabels,
      selectedIncludeTags: _selectedIncludeTags,
      selectedExcludeTags: _selectedExcludeTags,
      filterMatchMode: _filterMatchMode,
      onFilterChanged: (include, exclude, mode) {
        setState(() {
          _selectedIncludeTags = include;
          _selectedExcludeTags = exclude;
          _filterMatchMode = mode;
        });
        fetchLessons();
      },
    );
  }

  void _showShareStudentPositionModal() {
    showDialog(
      context: context,
      builder: (ctx) => ShareStudentPositionDialog(
        roomMembers: roomMembers,
        onShareToMember: (member) {
          final currentFen = moveTree.current.fen;
          socket.emit('student_shares_position', {
            'roomId': widget.roomCode,
            'targetUserId': member['userId'],
            'fen': currentFen,
            'studentName': widget.userSession.name,
          });
          _showSuccess('Pozicija poslana treneru (${member['name']})!');
        },
      ),
    );
  }

  void _showBoardSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => BoardSetupDialog(
        onFenGenerated: (generatedFen) {
          loadLessonPosition(generatedFen, null);
          _showSuccess('Postavljena pozicija učitana na tablu!');
        },
      ),
    );
  }

  void _showCreateCourseDialog({Map<String, dynamic>? existingLesson}) {
    showDialog(
      context: context,
      builder: (ctx) => CreateCourseDialog(
        userSession: widget.userSession,
        onCourseCreated: () => fetchLessons(),
        existingLesson: existingLesson,
      ),
    );
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SavePositionDialog(
        availableUserLabels: _availableUserLabels,
        initialPersistedLabels: _persistedLabels,
        initialShouldPersist: _shouldPersistLabels,
        onSave: (title, desc, dialogActiveTags, persistChecked) {
          saveCurrentPosition(title, desc, dialogActiveTags);
          if (persistChecked) {
            _persistedLabels = List<String>.from(dialogActiveTags);
            _shouldPersistLabels = true;
          } else {
            _persistedLabels = [];
            _shouldPersistLabels = false;
          }
          fetchUserLabels();
        },
      ),
    );
  }

  void _showInSessionInviteFriendsDialog() async {
    List<dynamic> friendsList = [];
    String? loadError;
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/friends'),
        headers: {'Authorization': 'Bearer ${widget.userSession.token}'},
      );
      if (res.statusCode == 200) {
        // The route answers `{ "friends": [...] }`. Decoding it straight into a
        // list threw a TypeError on every call there has ever been, and the
        // `catch` below swallowed it under a comment that said "quiet fail" —
        // so this dialog told **everybody** they had no friends, a trainer with
        // a full class included. Found live 25.8.2026, in a room with two
        // accepted students in it.
        final data = jsonDecode(res.body);
        friendsList = (data is Map ? data['friends'] : data) as List? ?? [];
      } else {
        loadError = 'Spisak nije mogao da se učita (${res.statusCode}).';
      }
    } catch (e) {
      // Not quiet any more. "I could not ask" must never come out as "you have
      // nobody" — the same three-answer rule the account guard and the
      // recording consent both needed.
      loadError = 'Spisak nije mogao da se učita.';
      print('[INVITE] Neuspelo dobavljanje spiska prijatelja: $e');
    }

    if (!mounted) return;
    final List<int> selectedFriendIds = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.person_add, color: Colors.tealAccent),
              SizedBox(width: 8),
              Text('Pozovi prijatelje u sesiju',
                  style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Soba: ${widget.roomCode}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.tealAccent)),
              const SizedBox(height: 8),
              const Text('Izaberite prijatelje koje želite da pozovete:',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              if (loadError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(loadError,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.orangeAccent)),
                )
              else if (friendsList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                      'Nemate nikoga na spisku. Na njemu su učenici i treneri '
                      'sa prihvaćenom vezom.',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Column(
                      children: friendsList.map((f) {
                        final fId = f['id'] as int;
                        final isSel = selectedFriendIds.contains(fId);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(f['name'] ?? 'Prijatelj',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(f['email'] ?? '',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                          value: isSel,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedFriendIds.add(fId);
                              } else {
                                selectedFriendIds.remove(fId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Otkaži'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 14),
              label: Text('Pošalji pozivnice (${selectedFriendIds.length})'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                if (selectedFriendIds.isEmpty) return;
                try {
                  await http.post(
                    Uri.parse('$backendUrl/invitations/send'),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${widget.userSession.token}'
                    },
                    body: jsonEncode({
                      'friendIds': selectedFriendIds,
                      'roomCode': widget.roomCode
                    }),
                  );
                  _showSuccess('Pozivnice uspešno poslate prijateljima!');
                } catch (e) {
                  _showError('Greška pri slanju pozivnica.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccess(String message) {
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// The one cursor this screen is walked by. The strip's buttons and the arrow
  /// keys read it from here rather than each building their own, so there is no
  /// second copy to fall out of step.
  MoveCursor _moveCursor() => MoveTreeCursor(
        moveTree: moveTree,
        currentNode: currentNode,
        onSelect: _selectNode,
      );

  Widget buildNavigationControls() {
    return MoveNavigationControls(
      cursor: _moveCursor(),
      canNavigate: canDriveSharedBoard,
      onFlipBoard: _toggleLocalOrientation,
      // Beside the flip button, which is the other control here that changes
      // how the board is read rather than what is on it. Not in the app bar:
      // that bar already carries five actions and a status icon, and a sixth
      // is how a row runs past the edge of a 360 dp phone with no warning
      // painted in a release build.
      trailing: const [BoardCoordinatesButton()],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudio = widget.roomCode == 'STUDIO';
    final isHost = activeRole == 'host' || activeRole == 'trener' || isStudio;
    final isAllowedToMove = isHost ||
        isStudio ||
        (boardControl != 'host_only' && boardControl != 'trainer_only');
    final media = MediaQuery.of(context);
    final isWide = Breakpoints.isWide(context);
    // A phone in landscape is rarely "wide" by dp width, but stacking
    // everything vertically (the portrait layout) leaves no room for
    // anything but the board in that limited height — it needs the same
    // side-by-side board+sidebar split as wide layouts, just without the
    // inline left (lessons) sidebar, which stays in the Drawer.
    final isLandscape = media.orientation == Orientation.landscape;

    // Sizing of ChessBoard
    final boardSize = (isWide
            ? min(media.size.height * 0.62, media.size.width * 0.42)
            : isLandscape
                ? min(media.size.height * 0.75, media.size.width * 0.42)
                : min(media.size.height * 0.65, media.size.width * 0.9)) *
        AppSettingsService.instance.boardSizeScale;

    // Left Sidebar Content (Lessons Management)
    Widget buildLeftSidebar() {
      return Container(
        width: 300,
        color: Theme.of(context).cardColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lekcije i Pozicije',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showBoardSetupDialog,
                  icon: const Icon(Icons.dashboard_customize, size: 16),
                  label: const Text('Postavi poziciju (Board Setup)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showSaveDialog,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Sačuvaj trenutnu poziciju'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openLocalPgnFile,
                  icon: const Icon(Icons.file_open, size: 16),
                  label: const Text('Otvori PGN fajl'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (isTrener) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showCreateCourseDialog,
                    icon: const Icon(Icons.collections_bookmark, size: 16),
                    label: const Text('Kreiraj lekciju (Više pozicija)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fenPasteController,
                      decoration: const InputDecoration(
                        hintText: 'Nalepi FEN string...',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:
                        const Icon(Icons.input, color: Colors.deepPurpleAccent),
                    onPressed: () {
                      final fen = fenPasteController.text.trim();
                      if (fen.isNotEmpty) {
                        loadLessonPosition(fen, null);
                        fenPasteController.clear();
                      } else {
                        _showError('Molimo vas zalepite ispravan FEN.');
                      }
                    },
                    tooltip: 'Učitaj FEN',
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pgnPasteController,
                      decoration: const InputDecoration(
                        hintText: 'Nalepi PGN partiju...',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.playlist_add,
                        color: Colors.deepPurpleAccent),
                    onPressed: () {
                      final pgnStr = pgnPasteController.text.trim();
                      if (pgnStr.isNotEmpty) {
                        final parsed = MoveTree.parsePgn(pgnStr);
                        if (parsed != null && parsed.root.children.isNotEmpty) {
                          setState(() {
                            moveTree = parsed;
                            commentController.text = moveTree.current.comment;
                            pgnPasteController.clear();
                          });

                          controller.loadFen(parsed.root.fen);
                          socket.emit('move', {
                            'roomId': widget.roomCode,
                            'move': null,
                            'currentFen': parsed.root.fen,
                            'role': widget.userSession.role,
                            'movePath': <String>[],
                          });

                          socket.emit('pgn_loaded', {
                            'roomId': widget.roomCode,
                            'pgn': pgnStr,
                          });

                          _showSuccess('PGN partija učitana!');
                          _triggerEngineAnalysis();
                        } else {
                          _showError('Neuspešno parsiranje PGN-a.');
                        }
                      } else {
                        _showError('Nalepite PGN tekst.');
                      }
                    },
                    tooltip: 'Učitaj PGN',
                  )
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Pretraga lekcija',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Pretraži po nazivu ili tagu...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      searchController.clear();
                      fetchLessons();
                    },
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                onSubmitted: (val) {
                  fetchLessons(searchQuery: val.trim());
                },
              ),
              const SizedBox(height: 8),
              _buildMatrixFilterPanel(),
              if (widget.userSession.role == 'ucenik' &&
                  widget.roomCode != 'STUDIO') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showShareStudentPositionModal,
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Prikaži moju poziciju treneru'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
                      foregroundColor: Colors.amberAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  const Text(
                    'Kategorija: ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.grey),
                  ),
                  ChoiceChip(
                    label: const Text('Sve', style: TextStyle(fontSize: 10)),
                    selected: _lessonCategoryFilter == 'all',
                    onSelected: (val) {
                      if (val) setState(() => _lessonCategoryFilter = 'all');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Moje', style: TextStyle(fontSize: 10)),
                    selected: _lessonCategoryFilter == 'mine',
                    onSelected: (val) {
                      if (val) setState(() => _lessonCategoryFilter = 'mine');
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Od trenera',
                        style: TextStyle(fontSize: 10)),
                    selected: _lessonCategoryFilter == 'trainer',
                    onSelected: (val) {
                      if (val) {
                        setState(() => _lessonCategoryFilter = 'trainer');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              isLoadingLessons
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator()))
                  : () {
                      final displayedLessons = lessons.where((l) {
                        if (_lessonCategoryFilter == 'mine') {
                          return l['is_trainer_lesson'] != true;
                        } else if (_lessonCategoryFilter == 'trainer') {
                          return l['is_trainer_lesson'] == true;
                        }
                        return true;
                      }).toList();

                      if (displayedLessons.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Nema sačuvanih lekcija u ovoj kategoriji.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayedLessons.length,
                        itemBuilder: (context, index) {
                          final lesson = displayedLessons[index];
                          final isTrainerLesson =
                              lesson['is_trainer_lesson'] == true;
                          final positionList = lesson['position_list'];
                          final isCourse = positionList != null &&
                              (positionList is List) &&
                              positionList.isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: BoardThumbnail(
                                fen: isCourse
                                    ? ((positionList.first['fen'] as String?) ??
                                        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR')
                                    : ((lesson['fen'] as String?) ??
                                        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR'),
                                size: 40,
                              ),
                              title: Text(
                                lesson['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isTrainerLesson)
                                    const Text(
                                      'Sačuvana lekcija od trenera',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.amberAccent,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  if (isCourse)
                                    Text(
                                      'Kurs od ${positionList.length} pozicija',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.deepPurpleAccent,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  if (lesson['description'] != null &&
                                      lesson['description']
                                          .toString()
                                          .isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      lesson['description'],
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isTrainerLesson
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 18, color: Colors.grey),
                                          tooltip: 'Izmeni',
                                          onPressed: () => isCourse
                                              ? _showCreateCourseDialog(
                                                  existingLesson:
                                                      Map<String, dynamic>.from(
                                                          lesson))
                                              : _editSinglePosition(
                                                  Map<String, dynamic>.from(
                                                      lesson)),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18,
                                              color: Colors.redAccent),
                                          tooltip: 'Obriši',
                                          onPressed: () => _confirmDeleteLesson(
                                              Map<String, dynamic>.from(
                                                  lesson)),
                                        ),
                                      ],
                                    ),
                              onTap: () {
                                if (isCourse) {
                                  setState(() {
                                    _activeCourseItems = positionList;
                                    _activeCourseIndex = 0;
                                    _activeCourseTitle = lesson['title'];
                                  });
                                  final firstPos = positionList[0];
                                  loadLessonPosition(
                                      firstPos['fen'], firstPos['pgn']);
                                  _showSuccess(
                                      'Učitan korak 1/${positionList.length} iz kursa: "${firstPos['title'] ?? lesson['title']}"');
                                } else {
                                  setState(() => _activeCourseItems = null);
                                  loadLessonPosition(
                                      lesson['fen'], lesson['pgn']);
                                }
                              },
                            ),
                          );
                        },
                      );
                    }(),
            ],
          ),
        ),
      );
    }

    Widget buildRightSidebar() {
      final isHost = activeRole == 'host' ||
          activeRole == 'trener' ||
          widget.userSession.role == 'trener' ||
          widget.roomCode == 'STUDIO';
      final isStudio = widget.roomCode == 'STUDIO';

      // Material, not a coloured Container: the sidebar hosts a SwitchListTile,
      // and a ColoredBox between a ListTile and its nearest Material hides the
      // tile's own background and ink splashes behind an opaque layer. Flutter
      // asserts on exactly that, every frame, which is enough to drown the UI
      // thread in error output on desktop.
      return SizedBox(
        width: isWide ? 300 : double.infinity,
        child: Material(
          color: Theme.of(context).cardColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isStudio
                      ? 'Studio Kontrole'
                      : (isHost
                          ? 'Host Kontrole & Istorija'
                          : 'Kontrola i Istorija'),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (isStudio) ...[
                  const Divider(height: 12),
                  const Text(
                    'Crtanje strelica',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              isDrawingMode = !isDrawingMode;
                              drawingStartSquare = null;
                            });
                          },
                          icon: Icon(isDrawingMode ? Icons.check : Icons.brush),
                          label: Text(isDrawingMode
                              ? 'Završi crtanje'
                              : 'Nacrtaj strelicu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDrawingMode ? Colors.amber : Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isDrawingMode) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildColorButton('G', Colors.green, 'Zelena'),
                        _buildColorButton('R', Colors.red, 'Crvena'),
                        _buildColorButton('B', Colors.blue, 'Plava'),
                        _buildColorButton('O', Colors.orange, 'Narandžasta'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              moveTree.current.arrows.clear();
                              drawingStartSquare = null;
                            });
                            _recordEvent('arrow_drawn',
                                {'arrows': <Map<String, dynamic>>[]});
                          },
                          icon: const Icon(Icons.layers_clear, size: 16),
                          label: const Text('Izbriši strelice',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.indigo.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.architecture,
                              color: Colors.indigoAccent, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Studio Režim (Samostalan rad - Učionica isključena)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.indigoAccent,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (isTrener) ...[
                  DropdownButtonFormField<String>(
                    initialValue: boardControl,
                    decoration: const InputDecoration(
                      labelText: 'Dozvole za Učenika',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'trainer_only',
                          child: Text('Samo ja (Trener)')),
                      DropdownMenuItem(
                          value: 'student_white',
                          child: Text('Učenik igra kao Beli')),
                      DropdownMenuItem(
                          value: 'student_black',
                          child: Text('Učenik igra kao Crni')),
                      DropdownMenuItem(
                          value: 'student_both',
                          child: Text('Slobodna analiza')),
                    ],
                    onChanged: _changeStudentPermissions,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Dozvoli učeniku Stockfish',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    value: allowStudentEngine,
                    activeThumbColor: Colors.tealAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() {
                        allowStudentEngine = val;
                      });
                      socket.emit('change_engine_permission', {
                        'roomId': widget.roomCode,
                        'allowStudentEngine': val,
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Prisili tablu učeniku na:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _forceStudentOrientation('white'),
                          child: const Text('Beli'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _forceStudentOrientation('black'),
                          child: const Text('Crni'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 12),
                  const Text(
                    'Crtanje strelica (Trener)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              isDrawingMode = !isDrawingMode;
                              drawingStartSquare = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDrawingMode
                                ? Colors.teal
                                : Colors.deepPurple.withValues(alpha: 0.3),
                          ),
                          icon:
                              Icon(isDrawingMode ? Icons.check : Icons.gesture),
                          label: Text(isDrawingMode
                              ? 'Završi crtanje'
                              : 'Crtaj strelice'),
                        ),
                      ),
                    ],
                  ),
                  if (isDrawingMode) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildColorButton('G', Colors.green, 'Zelena'),
                        _buildColorButton('R', Colors.red, 'Crvena'),
                        _buildColorButton('B', Colors.blue, 'Plava'),
                        _buildColorButton('O', Colors.orange, 'Narandžasta'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              moveTree.current.arrows.clear();
                              drawingStartSquare = null;
                            });
                            _recordEvent('arrow_drawn',
                                {'arrows': <Map<String, dynamic>>[]});
                            socket.emit('pgn_loaded', {
                              'roomId': widget.roomCode,
                              'pgn': moveTree.exportToPgn(),
                            });
                          },
                          icon: const Icon(Icons.layers_clear, size: 16),
                          label: const Text('Izbriši strelice',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Status dozvole: ${_getPermissionLabel(boardControl)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  if (!isAllowedToMove)
                    const Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange, size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tabla je zaključana od strane trenera.',
                            style:
                                TextStyle(color: Colors.orange, fontSize: 13),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.lock_open,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            boardControl == 'student_white'
                                ? 'Možete vući samo bele figure.'
                                : boardControl == 'student_black'
                                    ? 'Možete vući samo crne figure.'
                                    : 'Slobodna analiza omogućena.',
                            style: const TextStyle(
                                color: Colors.green, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                ],
                if (!isStudio) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.amber.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.people, color: Colors.amber, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Prisutni u učionici',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (roomMembers.isEmpty)
                            const Text(
                              'Učitavanje prisutnih...',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            )
                          else
                            ...roomMembers.map<Widget>((member) {
                              final isMe =
                                  member['userId'] == widget.userSession.id;
                              final isMemberTrainer =
                                  member['role'] == 'trener';
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.fiber_manual_record,
                                        color: Colors.greenAccent, size: 8),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${member['name']} ${isMe ? "(Ja)" : ""} ${isMemberTrainer ? "[Trener]" : "[Učenik]"}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    if (isHost && !isMe) ...[
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            size: 16),
                                        tooltip: 'Promeni ulogu',
                                        onSelected: (newRole) {
                                          socket.emit('change_user_role', {
                                            'roomId': widget.roomCode,
                                            'targetUserId': member['userId'],
                                            'newRole': newRole,
                                          });
                                        },
                                        itemBuilder: (ctx) => [
                                          if (!isMemberTrainer)
                                            const PopupMenuItem(
                                              value: 'host',
                                              child: Text(
                                                  'Promoviši u Hosta (Co-host)',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                            )
                                          else
                                            const PopupMenuItem(
                                              value: 'korisnik',
                                              child: Text('Vrati u Korisnika',
                                                  style:
                                                      TextStyle(fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          if (isTrener && !isStudio) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showInSessionInviteFriendsDialog,
                                icon: const Icon(Icons.person_add, size: 14),
                                label: const Text('Pozovi prijatelje u sesiju',
                                    style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.tealAccent,
                                  side: const BorderSide(
                                      color: Colors.tealAccent),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.blueGrey.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.mic, color: Colors.blueAccent),
                                  SizedBox(width: 8),
                                  Text(
                                    'Audio Učionica',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              if (!isVoiceOn)
                                const Icon(Icons.mic_off,
                                    color: Colors.blueGrey, size: 16)
                              else if (isAudioConnecting)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.blueAccent),
                                )
                              else if (audioError != null)
                                const Icon(Icons.warning,
                                    color: Colors.redAccent, size: 16)
                              else
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Above the switch, and shown whether the voice is on
                          // or off: a join that was refused turns the panel back
                          // off, and the reason has to survive that.
                          if (audioError != null) ...[
                            Text(
                              audioError!,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // The voice is off until somebody asks for it. What
                          // this offers depends on whether a conversation is
                          // already going on, because those are two different
                          // questions: "do I want to start talking" and "the
                          // lesson is being spoken and I am not hearing it".
                          if (!isVoiceOn) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _voiceUsersOther.isEmpty
                                    ? Colors.blueGrey.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _voiceUsersOther.isEmpty
                                        ? Icons.mic_off
                                        : Icons.record_voice_over,
                                    size: 16,
                                    color: _voiceUsersOther.isEmpty
                                        ? Colors.blueGrey
                                        : Colors.greenAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _voiceUsersOther.isEmpty
                                          ? 'Glas je isključen. Mikrofon se ne '
                                              'otvara dok ga sami ne uključite.'
                                          : 'U razgovoru: '
                                              '${_voiceUsersOther.join(', ')}.',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _joinVoice,
                              icon: const Icon(Icons.headset_mic, size: 16),
                              label: Text(_voiceUsersOther.isEmpty
                                  ? 'Uključi glas'
                                  : 'Priključi se razgovoru'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.green.withValues(alpha: 0.2),
                                foregroundColor: Colors.greenAccent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ],
                          if (isVoiceOn &&
                              !isAudioConnecting &&
                              audioError == null) ...[
                            // A button that cannot work must not be drawn. While
                            // the server says this person only listens, the app
                            // holds a subscriber token: "Uključi mikrofon" would
                            // light up, the roster would say they are speaking,
                            // and nobody would hear them.
                            if (!mayUseMic)
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.blueGrey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.headset,
                                        size: 16, color: Colors.blueGrey),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Slušate čas. Odgovarate dugmadima ispod '
                                        'i potezima na tabli.',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _toggleLocalMute,
                                      icon: Icon(isAudioMuted
                                          ? Icons.mic_off
                                          : Icons.mic),
                                      label: Text(isAudioMuted
                                          ? 'Uključi mikrofon'
                                          : 'Utišaj me'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isAudioMuted
                                            ? Colors.redAccent
                                                .withValues(alpha: 0.2)
                                            : Colors.green
                                                .withValues(alpha: 0.2),
                                        foregroundColor: isAudioMuted
                                            ? Colors.redAccent
                                            : Colors.greenAccent,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            // The ready answers. This is what makes a listening
                            // seat a lesson rather than a broadcast: the trainer
                            // asks whether it is clear and gets an answer,
                            // without a child's voice being published — or
                            // recorded. Wrap, not Row: three labels do not fit a
                            // 360 dp phone, and in a release build the third one
                            // would simply be cut off past the edge with no
                            // warning drawn.
                            if (!isTrener)
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final entry in _quickAnswers.entries)
                                    OutlinedButton(
                                      onPressed: () =>
                                          _sendQuickAnswer(entry.key),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        foregroundColor: Colors.lightBlueAccent,
                                      ),
                                      child: Text(entry.value,
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              'Učesnici u audio razgovoru:',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            ...audioUsers.map<Widget>((user) {
                              final isUserMuted = user['isMuted'] ?? false;
                              // Told by the server, unlike the mute flag beside
                              // it, which is whatever the client reported about
                              // itself.
                              final userMaySpeak = user['maySpeak'] == true;
                              final isUserTalking =
                                  activeSpeakers.contains(user['userId']);
                              final isUserTrainer = user['role'] == 'trener';
                              final isMe =
                                  user['userId'] == widget.userSession.id;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      !userMaySpeak
                                          ? Icons.headset
                                          : (isUserMuted
                                              ? Icons.mic_off
                                              : Icons.mic),
                                      size: 16,
                                      color: isUserTalking
                                          ? Colors.greenAccent
                                          : (!userMaySpeak
                                              ? Colors.blueGrey
                                              : (isUserMuted
                                                  ? Colors.redAccent
                                                  : Colors.grey)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${user['userName']} ${isMe ? "(Ja)" : ""} ${isUserTrainer ? "[Trener]" : ""}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isUserTalking
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isUserTalking
                                              ? Colors.greenAccent
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                    // Two different controls, deliberately kept
                                    // apart: this one is the right, read again
                                    // every time a voice token is minted, and
                                    // the one beside it is a courtesy for the
                                    // next few minutes.
                                    if (isTrener && !isMe && !isUserTrainer)
                                      IconButton(
                                        icon: Icon(
                                            userMaySpeak
                                                ? Icons.mic
                                                : Icons.mic_off,
                                            size: 16,
                                            color: userMaySpeak
                                                ? Colors.greenAccent
                                                : Colors.blueGrey),
                                        onPressed: () => _setStudentVoice(
                                            user['userId'] as int,
                                            !userMaySpeak),
                                        tooltip: userMaySpeak
                                            ? 'Oduzmi mikrofon (ostaje da sluša)'
                                            : 'Daj mikrofon',
                                      ),
                                    if (isTrener && !isMe && userMaySpeak)
                                      IconButton(
                                        icon: Icon(
                                            isUserMuted
                                                ? Icons.volume_off
                                                : Icons.volume_up,
                                            size: 16),
                                        onPressed: () {
                                          if (isUserMuted) {
                                            socket.emit('audio_allow_speech', {
                                              'roomId': widget.roomCode,
                                              'targetUserId': user['userId'],
                                            });
                                          } else {
                                            socket.emit('audio_mute_student', {
                                              'roomId': widget.roomCode,
                                              'targetUserId': user['userId'],
                                            });
                                          }
                                        },
                                        tooltip: isUserMuted
                                            ? 'Oduzmi utišanje'
                                            : 'Utišaj učenika',
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (audioUsers.isEmpty)
                              const Text(
                                'Nema povezanih korisnika.',
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            if (widget.userSession.role == 'trener' &&
                                audioUsers.length > 1) ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  socket.emit('audio_mute_all_students',
                                      {'roomId': widget.roomCode});
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.red.withValues(alpha: 0.15),
                                  foregroundColor: Colors.redAccent,
                                ),
                                child: const Text('Utišaj sve učenike'),
                              ),
                            ],
                            if (widget.userSession.role == 'ucenik' &&
                                isAudioMuted &&
                                isHandRaised) ...[
                              const SizedBox(height: 8),
                              const Center(
                                child: Text(
                                  'Utišani ste. Ruka je podignuta...',
                                  style: TextStyle(
                                      color: Colors.orangeAccent, fontSize: 11),
                                ),
                              ),
                            ] else if (widget.userSession.role == 'ucenik' &&
                                isAudioMuted) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _raiseHand,
                                icon: const Icon(Icons.pan_tool, size: 14),
                                label: const Text('Podigni ruku za reč'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.orange.withValues(alpha: 0.2),
                                  foregroundColor: Colors.orangeAccent,
                                ),
                              ),
                            ],
                          ],
                          // Outside the block above on purpose: a voice that
                          // came up with an error is exactly the one somebody
                          // needs to be able to switch off.
                          if (isVoiceOn) ...[
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _leaveVoice,
                              icon: const Icon(Icons.call_end, size: 16),
                              label: const Text('Isključi glas'),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (isTrener && !isStudio) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: isRecording
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.deepPurple.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isRecording
                                    ? (isRecordingPaused
                                        ? Icons.pause_circle_filled
                                        : Icons.fiber_manual_record)
                                    : Icons.videocam,
                                color: isRecording
                                    ? (isRecordingPaused
                                        ? Colors.orangeAccent
                                        : Colors.redAccent)
                                    : Colors.deepPurpleAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isRecording
                                    ? (isRecordingPaused
                                        ? 'Snimanje PAUZIRANO'
                                        : 'Snimanje U TOKU...')
                                    : 'Snimanje časa (Timeline)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isRecording
                                      ? (isRecordingPaused
                                          ? Colors.orangeAccent
                                          : Colors.redAccent)
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (isRecording) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isRecordingPaused
                                        ? _resumeRecording
                                        : _pauseRecording,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isRecordingPaused
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                      side: BorderSide(
                                          color: isRecordingPaused
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent),
                                    ),
                                    icon: Icon(
                                        isRecordingPaused
                                            ? Icons.play_arrow
                                            : Icons.pause,
                                        size: 14),
                                    label: Text(
                                        isRecordingPaused
                                            ? 'Nastavi'
                                            : 'Pauziraj',
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _stopRecording,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    icon: const Icon(Icons.stop,
                                        color: Colors.white, size: 14),
                                    label: const Text('Sačuvaj',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              onPressed:
                                  _recordingAllowed ? _startRecording : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurpleAccent,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.fiber_manual_record,
                                  color: Colors.white, size: 16),
                              label: const Text('Započni snimanje'),
                            ),
                            // The reason stands under the button rather than
                            // waiting for it to be pressed: a disabled control
                            // with no explanation is a bug report.
                            if (!_recordingAllowed &&
                                _recordingBlockedReason != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.family_restroom,
                                      color: Colors.orangeAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _recordingBlockedReason!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.orangeAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      // Leaving disposes the socket, the Agora channel and every buffered
      // recording event. Never let that happen silently mid-recording.
      canPop: !isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !isRecording) return;
        // Just stepping out — the active session stays intact so the user
        // can resume it later (see the "Napusti sesiju" action for the only
        // thing that actually ends it).
        final proceed = await _resolveRecordingBeforeLeaving();
        if (!context.mounted || !proceed) return;
        context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isConnected ? gameStatus : 'Uspostavljanje veze...'),
          centerTitle: true,
          actions: [
            // Only the person whose room it is: the guest list decides who gets
            // in, and that is not a decision a seat in the room grants.
            if (activeRole == 'trener' && widget.roomCode != 'STUDIO')
              IconButton(
                icon: const Icon(Icons.groups, color: Colors.tealAccent),
                tooltip: 'Ko sme u sobu',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => RoomGuestsDialog(
                    roomCode: widget.roomCode,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.biotech, color: Colors.tealAccent),
              tooltip: 'Izvezi u Tablu za Analizu 🔬',
              onPressed: () {
                context.push(AppRoutes.analysisPath(fen: controller.getFen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.grey),
              tooltip: 'Podešavanja',
              onPressed: () async {
                // Settings sits on top of the room; the socket and the audio
                // channel keep running underneath instead of being torn down.
                await context.push(AppRoutes.preferences);
                if (mounted) setState(() {});
              },
            ),
            if (widget.roomCode != 'STUDIO')
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: 'Napusti sesiju',
                onPressed: _leaveSessionExplicitly,
              ),
            Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 16),
          ],
        ),
        // Mobile layout has a Drawer for lessons listing (if Trainer)
        drawer:
            (!isWide && isTrener) ? Drawer(child: buildLeftSidebar()) : null,
        body: MoveKeyboardShortcuts(
          cursor: _moveCursor(),
          // _selectNode does its own setState.
          onChanged: () {},
          // Same condition the strip already uses: a seat that does not
          // drive the shared board must not drive it with the keyboard
          // either.
          enabled: canDriveSharedBoard,
          child: Column(children: [
            _buildCourseStepBar(),
            Expanded(
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildLeftSidebar(),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isHost
                                        ? "Igrate kao Beli (Host)"
                                        : "Igrate kao Crni (Korisnik)",
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 15),
                                  ),
                                  const SizedBox(height: 12),
                                  if (_showEvalBar) ...[
                                    SizedBox(
                                      width: boardSize,
                                      child: HorizontalEvalBarWidget(
                                        eval: _currentRawEval,
                                        evalString: currentEngineEval,
                                        depth: _currentEvalDepth,
                                        orientation: boardOrientation,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  _buildChessBoardWithOverlay(boardSize),
                                  const SizedBox(height: 12),
                                  // PGN navigators
                                  SizedBox(
                                    width: boardSize,
                                    child: buildNavigationControls(),
                                  ),
                                  const SizedBox(height: 8),
                                  // Stockfish analysis widget directly UNDER board
                                  SizedBox(
                                    width: boardSize,
                                    child: _buildStockfishAnalysisWidget(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        buildRightSidebar(),
                      ],
                    )
                  : isLandscape
                      // Phone landscape: no room to stack board + everything else
                      // vertically, so it goes side by side instead — board (+nav)
                      // on the left, everything else in one scrollable pane on the
                      // right. The left (lessons) sidebar stays in the Drawer.
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      isHost
                                          ? "Igrate kao Beli (Host)"
                                          : "Igrate kao Crni (Korisnik)",
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    if (_showEvalBar) ...[
                                      SizedBox(
                                        width: boardSize,
                                        child: HorizontalEvalBarWidget(
                                          eval: _currentRawEval,
                                          evalString: currentEngineEval,
                                          depth: _currentEvalDepth,
                                          orientation: boardOrientation,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    _buildChessBoardWithOverlay(boardSize),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: boardSize,
                                      child: buildNavigationControls(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 1, thickness: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildStockfishAnalysisWidget(),
                                    const SizedBox(height: 8),
                                    buildRightSidebar(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              isHost
                                  ? "Igrate kao Beli (Host)"
                                  : "Igrate kao Crni (Korisnik)",
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            if (_showEvalBar) ...[
                              SizedBox(
                                width: boardSize,
                                child: HorizontalEvalBarWidget(
                                  eval: _currentRawEval,
                                  evalString: currentEngineEval,
                                  depth: _currentEvalDepth,
                                  orientation: boardOrientation,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            _buildChessBoardWithOverlay(boardSize),
                            const SizedBox(height: 8),
                            // PGN navigators on mobile (fixed)
                            SizedBox(
                              width: boardSize,
                              child: buildNavigationControls(),
                            ),
                            const SizedBox(height: 8),
                            // Scrollable sidebar below the fixed board — the Stockfish
                            // eval toggles ("Prikaži evaluaciju" / "Prikaži
                            // evaluacionu liniju") live in here too now instead of
                            // being pinned above it, so they scroll with everything
                            // else rather than staying fixed on screen.
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildStockfishAnalysisWidget(),
                                    const SizedBox(height: 8),
                                    buildRightSidebar(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Offers to save the in-progress recording before leaving the room.
  /// Returns true once the recording is resolved (stopped/saved or
  /// discarded) and it's safe to proceed with leaving; false if the user
  /// backed out and is still recording.
  Future<bool> _resolveRecordingBeforeLeaving() async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Snimanje je u toku'),
        content: Text(
          'Napuštanjem sobe prekidate vezu i gubite ${_recorder.eventCount} zabeleženih događaja.\n\n'
          'Da li želite prvo da zaustavite i sačuvate snimak?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Ostani u sobi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Izađi bez čuvanja',
                style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Zaustavi i sačuvaj'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == 'cancel') return false;

    if (choice == 'save') {
      // _stopRecording runs its own title/save dialog and clears the buffer.
      await _stopRecording();
      if (!mounted) return false;
      // Bail out if the user backed out of that dialog and is still recording.
      if (isRecording) return false;
    } else {
      setState(() {
        isRecording = false;
        isRecordingPaused = false;
        recordingStartTimeMs = null;
        _recorder.reset();
      });
    }

    return true;
  }

  /// The only path that actually ends the session (as opposed to just
  /// stepping out of the screen): clears [GameSessionService] so Home stops
  /// offering to resume it and no longer blocks starting/joining another.
  Future<void> _leaveSessionExplicitly() async {
    if (isRecording && !await _resolveRecordingBeforeLeaving()) return;
    await GameSessionService.instance.clear();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}
