import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/stockfish_service.dart';

import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/board_setup_dialog.dart';
import 'package:chess_app/widgets/create_course_dialog.dart';
import 'package:chess_app/widgets/save_position_dialog.dart';
import 'package:chess_app/widgets/matrix_filter_panel.dart';
import 'package:chess_app/widgets/move_history_view.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';
import 'package:chess_app/widgets/share_position_dialog.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/engine_line_dialog.dart';
import 'package:chess_app/models/recording_models.dart';

// 3. MULTIPLAYER CHESS GAME PAGE
class ChessGamePage extends StatefulWidget {
  final String roomCode;
  final UserSession userSession;

  const ChessGamePage({super.key, required this.roomCode, required this.userSession});

  @override
  State<ChessGamePage> createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  late String activeRole;
  bool isRecording = false;
  int? recordingStartTimeMs;
  List<TimelineEvent> recordedEvents = [];

  late ChessBoardController controller;
  late io.Socket socket;
  bool isConnected = false;
  String gameStatus = "Spajanje na game server...";
  
  PlayerColor boardOrientation = PlayerColor.white;
  String boardControl = 'trainer_only';
  bool allowStudentEngine = false;

  final StockfishService _stockfishService = StockfishService();
  bool isEngineEnabled = false;
  String currentEngineEval = "0.00";
  String bestEngineMove = "-";
  Map<int, AnalysisLine> engineLines = {};
  String engineThinkingMode = 'fast'; // 'fast', 'deep', 'infinite'

  final AgoraService _agoraService = AgoraService();
  List<dynamic> audioUsers = [];
  Set<int> activeSpeakers = {};
  bool isAudioMuted = false;
  bool isAudioConnecting = true;
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

  @override
  void initState() {
    super.initState();
    if (widget.roomCode == 'STUDIO') {
      activeRole = 'trener';
      boardOrientation = PlayerColor.white;
      allowStudentEngine = true;
      boardControl = 'unrestricted';
    } else {
      activeRole = widget.userSession.role == 'trener' ? 'trener' : 'ucenik';
      boardOrientation = activeRole == 'trener'
          ? PlayerColor.white
          : PlayerColor.black;
    }
    controller = ChessBoardController();
    moveTree = MoveTree(startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    initSocket();
    
    // Fetch saved positions & user labels for all users
    fetchLessons();
    fetchUserLabels();

    // Set up Stockfish service evaluation listener
    _stockfishService.onEvaluationChanged = (evaluation, bestMove, continuation, multipv) {
      if (!mounted) return;
      setState(() {
        if (evaluation.isNotEmpty || continuation.isNotEmpty) {
          final currentFen = moveTree.current.fen;
          final updatedLine = AnalysisLine.fromPv(
            multipv: multipv,
            eval: evaluation.isNotEmpty ? evaluation : (engineLines[multipv]?.evaluation ?? '0.00'),
            pvString: continuation,
            startingFen: currentFen,
          );
          engineLines[multipv] = updatedLine;

          if (multipv == 1) {
            if (evaluation.isNotEmpty) {
              currentEngineEval = updatedLine.evaluation;
            }
            if (updatedLine.bestMoveSan.isNotEmpty) {
              bestEngineMove = updatedLine.bestMoveSan;
            }
          }
        }
      });
    };

    _initAudioChat();
  }

  @override
  void dispose() {
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
    _stockfishService.dispose();
    commentController.dispose();
    fenPasteController.dispose();
    pgnPasteController.dispose();
    searchController.dispose();
    super.dispose();
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

    final success = await _agoraService.joinChannel(widget.roomCode, widget.userSession.id);
    if (!success && mounted) {
      setState(() {
        isAudioConnecting = false;
      });
    }
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

  void _raiseHand() {
    socket.emit('audio_raise_hand', {
      'roomId': widget.roomCode,
      'userId': widget.userSession.id,
    });
    setState(() {
      isHandRaised = true;
    });
  }

  void _triggerEngineAnalysis() {
    if (isEngineEnabled) {
      setState(() {
        engineLines.clear();
        currentEngineEval = "0.00";
        bestEngineMove = "-";
      });
      final depth = engineThinkingMode == 'fast' ? 10 : 16;
      final isInfinite = engineThinkingMode == 'infinite';
      _stockfishService.analyzePosition(
        controller.getFen(),
        depth: depth,
        isInfinite: isInfinite,
      );
    }
  }

  List<EngineMove> _parseContinuation(String fen, String continuationStr) {
    final List<EngineMove> result = [];
    if (continuationStr.isEmpty) return result;

    final tokens = continuationStr.split(RegExp(r'\s+'));
    final tempGame = chess.Chess();
    tempGame.load(fen);

    for (var token in tokens) {
      token = token.trim();
      if (token.length < 4) continue;

      final from = token.substring(0, 2);
      final to = token.substring(2, 4);

      String? promotion;
      if (token.length == 5) {
        promotion = token.substring(4, 5);
      }

      final moveMap = {'from': from, 'to': to};
      if (promotion != null) {
        moveMap['promotion'] = promotion;
      }

      final success = tempGame.move(moveMap);
      if (success) {
        final moveObj = tempGame.history.last.move;
        tempGame.undo_move();
        final san = tempGame.move_to_san(moveObj);
        tempGame.move(moveMap);

        result.add(EngineMove(display: san, san: san, from: from, to: to));
      } else {
        break;
      }
    }

    return result;
  }

  void _playEngineMoves(List<EngineMove> moves, int limitIndex) {
    if (moves.isEmpty || limitIndex < 0 || limitIndex >= moves.length) return;
    for (int i = 0; i <= limitIndex; i++) {
      final m = moves[i];
      controller.makeMove(from: m.from, to: m.to);
      _handleLocalMoveMade(m.from, m.to);
    }
  }

  Widget _buildStockfishAnalysisWidget() {
    final sortedKeys = engineLines.keys.toList()..sort();
    final List<AnalysisLine> linesList = sortedKeys.map((k) => engineLines[k]!).toList();
    final isStudio = widget.roomCode == 'STUDIO';
    final isTrener = activeRole == 'trener' || isStudio;
    final isAllowedToUseEngine = isTrener || isStudio || allowStudentEngine;

    return StockfishAnalysisWidget(
      isEngineEnabled: isEngineEnabled,
      isAllowedToUseEngine: isAllowedToUseEngine,
      isOnline: _stockfishService.isOnline,
      isCustomEngineActive: _stockfishService.isCustomEngineActive,
      thinkingMode: engineThinkingMode,
      lines: linesList,
      orientation: boardOrientation,
      onToggleEngine: () async {
        setState(() {
          isEngineEnabled = !isEngineEnabled;
        });
        if (isEngineEnabled) {
          await _stockfishService.initEngine();
          engineLines.clear();
          _triggerEngineAnalysis();
        } else {
          _stockfishService.dispose();
          setState(() {
            currentEngineEval = "0.00";
            bestEngineMove = "-";
            engineLines.clear();
          });
        }
      },
      onChangeThinkingMode: (mode) {
        setState(() {
          engineThinkingMode = mode;
        });
        if (isEngineEnabled) {
          engineLines.clear();
          _triggerEngineAnalysis();
        }
      },
      onOpenSettings: (!kIsWeb && Platform.isWindows) ? _showEngineSettingsDialog : null,
      onLoadFenToMainBoard: (fen) {
        loadLessonPosition(fen, null);
        _showSuccess('Učitana pozicija iz linije analize!');
      },
    );
  }

  Widget _buildChessBoardWithOverlay(double boardSize) {
    final isTrener = widget.userSession.role == 'trener';
    final isAllowedToMove = isTrener || (boardControl != 'trainer_only');
    final isAllowedToUseEngine = isTrener || allowStudentEngine;

    final List<EngineArrow> engineArrows = (isEngineEnabled && isAllowedToUseEngine)
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

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !isAllowedToMove || isDrawingMode,
          child: ChessBoard(
            controller: controller,
            boardColor: BoardColor.brown,
            boardOrientation: boardOrientation,
            size: boardSize,
            onMove: () {
              final lastMove = controller.getPossibleMoves().isEmpty
                  ? null
                  : controller.game.history.last;
              if (lastMove != null) {
                final from = lastMove.move.fromAlgebraic;
                final to = lastMove.move.toAlgebraic;
                _handleLocalMoveMade(from, to);
              }
            },
          ),
        ),
        // Interactive paint overlay for trainer drawing arrows
        IgnorePointer(
          ignoring: !isDrawingMode,
          child: GestureDetector(
            onTapDown: (details) {
              if (!isDrawingMode) return;
              final localPos = details.localPosition;
              final square = getSquareFromOffset(localPos, boardSize, boardOrientation);
              
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
                      'arrows': moveTree.current.arrows.map((a) => {
                        'from': a.from,
                        'to': a.to,
                        'colorCode': a.colorCode
                      }).toList()
                    });
                    socket.emit('pgn_loaded', {
                      'roomId': widget.roomCode,
                      'pgn': moveTree.exportToPgn(),
                    });
                  }
                }
              });
            },
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: ChessBoardPainter(
                arrows: moveTree.current.arrows,
                engineArrows: engineArrows,
                boardSize: boardSize,
                orientation: boardOrientation,
                highlightedSquare: drawingStartSquare,
              ),
            ),
          ),
        ),
        // Non-interactive overlay to draw arrows for both when not in drawing mode
        if (!isDrawingMode)
          IgnorePointer(
            child: CustomPaint(
              size: Size(boardSize, boardSize),
              painter: ChessBoardPainter(
                arrows: moveTree.current.arrows,
                engineArrows: engineArrows,
                boardSize: boardSize,
                orientation: boardOrientation,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildColorButton(String code, ui.Color color, String tooltip) {
    final isSelected = selectedArrowColorCode == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedArrowColorCode = code;
        });
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected ? 1.0 : 0.4),
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(color: Colors.white, width: 2.0)
                : Border.all(color: Colors.transparent),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)]
                : [],
          ),
          child: isSelected
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  Widget _buildThinkingModeButton(String mode, String label, {bool isLocalOnly = false}) {
    final isSelected = engineThinkingMode == mode;
    final isOnline = _stockfishService.isOnline;
    final isDisabled = isLocalOnly && isOnline;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: ElevatedButton(
          onPressed: isDisabled
              ? null
              : () {
                  setState(() {
                    engineThinkingMode = mode;
                  });
                  _triggerEngineAnalysis();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected
                ? Colors.teal
                : Colors.blueGrey.withOpacity(isSelected ? 0.8 : 0.2),
            foregroundColor: isDisabled ? Colors.grey : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: Tooltip(
            message: isDisabled ? 'Nije podržano na webu/desktopu' : label,
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEngineSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentPath = prefs.getString('custom_engine_path') ?? '';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final hasCustom = currentPath != null && currentPath!.isNotEmpty;
            return AlertDialog(
              title: const Text('Podešavanja Šahovskog Engine-a'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trenutni engine:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasCustom
                        ? 'Sopstveni lokalni engine:\n$currentPath'
                        : 'Podrazumevani (Online / FFI paket)',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasCustom ? Colors.tealAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Možete izabrati bilo koji UCI kompatibilan šahovski engine (.exe) sa vašeg računara.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                if (hasCustom)
                  TextButton.icon(
                    onPressed: () async {
                      await prefs.remove('custom_engine_path');
                      setDialogState(() {
                        currentPath = '';
                      });
                      if (isEngineEnabled) {
                        // Restart engine
                        _stockfishService.dispose();
                        await _stockfishService.initEngine();
                        _triggerEngineAnalysis();
                      }
                      setState(() {});
                    },
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
                    label: const Text('Resetuj', style: TextStyle(color: Colors.redAccent)),
                  ),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['exe'],
                      );

                      if (result != null && result.files.single.path != null) {
                        final path = result.files.single.path!;
                        await prefs.setString('custom_engine_path', path);
                        setDialogState(() {
                          currentPath = path;
                        });
                        if (isEngineEnabled) {
                          // Restart engine with new custom executable
                          _stockfishService.dispose();
                          await _stockfishService.initEngine();
                          _triggerEngineAnalysis();
                        }
                        setState(() {});
                      }
                    } catch (e) {
                      _showError('Greška pri izboru fajla: $e');
                    }
                  },
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Izaberi .exe'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Zatvori'),
                ),
              ],
            );
          },
        );
      },
    );
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
    // Configure socket.io client connection to server
    socket = io.io(backendUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .enableForceNewConnection()
      .disableAutoConnect()
      .build());

    socket.connect();

    socket.onConnect((_) {
      setState(() {
        isConnected = true;
        gameStatus = "Soba: ${widget.roomCode}";
      });

      // Join room passing role and roomCode
      socket.emit('joinGame', {
        'roomId': widget.roomCode,
        'playerColor': widget.userSession.role == 'trener' ? 'white' : 'black',
        'userId': widget.userSession.id,
        'userName': widget.userSession.name,
        'role': widget.userSession.role,
      });
    });

    socket.onDisconnect((_) {
      setState(() {
        isConnected = false;
        gameStatus = "Prekinuta veza sa serverom";
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dozvole table promenjene: ${_getPermissionLabel(boardControl)}'),
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
            _stockfishService.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trener je okrenuo vašu tablu na: ${data['orientation'] == 'white' ? 'Beli' : 'Crni'}'),
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
        final parsed = MoveTree.parsePgn(data['pgn'], startingFen: moveTree.root.fen);
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
          if (roomMembers is List) {
            final me = (roomMembers as List).firstWhere(
              (m) => m['userId'] == widget.userSession.id,
              orElse: () => null,
            );
            if (me != null && me['role'] != null) {
              activeRole = me['role'];
            }
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
              content: Text('Učenik $studentName predlaže poziciju: "$title". Da li želite da je učitate na tablu?'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Učenik $studentName je podelio poziciju: "$title"'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trener vas je utišao. Možete podići ruku ako želite reč.'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Učenik $userName želi reč.'),
            backgroundColor: Colors.orangeAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  bool isRecordingPaused = false;
  int pauseStartTimeMs = 0;
  int totalPauseDurationMs = 0;

  void _recordEvent(String eventType, Map<String, dynamic> data) {
    if (!isRecording || isRecordingPaused || recordingStartTimeMs == null) return;
    final nowMs = (DateTime.now().millisecondsSinceEpoch - recordingStartTimeMs!) - totalPauseDurationMs;
    recordedEvents.add(TimelineEvent(
      timestampMs: nowMs,
      eventType: eventType,
      data: data,
    ));
  }

  String? _currentAudioPath;

  Future<void> _startRecording() async {
    try {
      _currentAudioPath = '${Directory.systemTemp.path}/session_audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _agoraService.startAudioRecording(_currentAudioPath!);
    } catch (e) {
      print('Error starting Agora audio recording: $e');
    }

    setState(() {
      isRecording = true;
      isRecordingPaused = false;
      pauseStartTimeMs = 0;
      totalPauseDurationMs = 0;
      recordingStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      recordedEvents = [
        TimelineEvent(
          timestampMs: 0,
          eventType: 'init',
          data: {
            'fen': moveTree.current.fen,
            'orientation': boardOrientation == PlayerColor.white ? 'white' : 'black',
            'boardControl': boardControl,
          },
        ),
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Snimanje časa i zvuka (glasa) je započeto! Svi potezi i govor se beleže.'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _pauseRecording() {
    if (!isRecording || isRecordingPaused) return;
    setState(() {
      isRecordingPaused = true;
      pauseStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Snimanje je pauzirano. Akcije se privremeno ne beleže.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resumeRecording() {
    if (!isRecording || !isRecordingPaused) return;
    final pauseDuration = DateTime.now().millisecondsSinceEpoch - pauseStartTimeMs;
    setState(() {
      totalPauseDurationMs += pauseDuration;
      isRecordingPaused = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Snimanje je nastavljeno! Svi sledstveni potezi se beleže u kombinovani snimak.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _stopRecording() async {
    print('[RECORDING_LOG] 1. Stopping Agora audio recording...');
    try {
      await _agoraService.stopAudioRecording().timeout(const Duration(seconds: 3));
      print('[RECORDING_LOG] 2. Agora audio recording stopped successfully.');
    } catch (e) {
      print('[RECORDING_LOG] 2. Agora audio recording stop error/timeout: $e');
    }

    final titleController = TextEditingController(text: 'Čas ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}');

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
              'Ukupno zabeleženo događaja: ${recordedEvents.length}',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sačuvaj snimak'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      print('[RECORDING_LOG] User cancelled recording save.');
      setState(() {
        isRecording = false;
        isRecordingPaused = false;
        recordingStartTimeMs = null;
        recordedEvents.clear();
      });
      return;
    }

    final title = titleController.text.trim();
    if (title.isEmpty) return;

    // Show loading progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Sačuvavam snimak časa i audio zapis... Molimo sačekajte.', style: TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );

    try {
      print('[RECORDING_LOG] 3. Preparing HTTP Multipart Request to $backendUrl/recordings/save ...');
      final request = http.MultipartRequest('POST', Uri.parse('$backendUrl/recordings/save'));
      request.headers['Authorization'] = 'Bearer ${widget.userSession.token}';
      request.fields['roomId'] = widget.roomCode;
      request.fields['title'] = title;
      request.fields['timelineJson'] = jsonEncode(recordedEvents.map((e) => e.toJson()).toList());

      if (_currentAudioPath != null) {
        final audioFile = File(_currentAudioPath!);
        if (await audioFile.exists()) {
          final size = await audioFile.length();
          print('[RECORDING_LOG] 4. Attaching audio file ($size bytes) from $_currentAudioPath ...');
          request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
        } else {
          print('[RECORDING_LOG] 4. Audio file path $_currentAudioPath does NOT exist on disk.');
        }
      } else {
        print('[RECORDING_LOG] 4. _currentAudioPath is NULL.');
      }

      print('[RECORDING_LOG] 5. Sending HTTP request...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      print('[RECORDING_LOG] 6. Streamed response received: status ${streamedResponse.statusCode}. Parsing body...');
      final response = await http.Response.fromStream(streamedResponse);
      print('[RECORDING_LOG] 7. Full server response body: ${response.body}');

      // Dismiss progress dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snimak časa je uspešno sačuvan! Dostupan je u odeljku Snimljeni časovi.'),
            backgroundColor: Colors.teal,
          ),
        );
      } else {
        final errData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errData['error'] ?? 'Greška pri čuvanju snimka.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      print('[RECORDING_LOG_ERROR] Exception in _stopRecording: $e');
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri čuvanju snimka: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() {
        isRecording = false;
        isRecordingPaused = false;
        recordingStartTimeMs = null;
        recordedEvents.clear();
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

      final uri = Uri.parse('$backendUrl/lessons').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
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

  // REST API: Save current board FEN with description and tags
  Future<void> saveCurrentPosition(String title, String description, List<String> tags) async {
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
  void _promptBranchingDialog(String from, String to, String san, String newFen) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Odigran je novi potez'),
          content: const Text('Ovaj potez stvara novu granu (varijaciju). Kako želite da ga dodate?'),
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
  void _handleLocalMoveMade(String from, String to) {
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
      final result = await FilePicker.platform.pickFiles(
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

  void _showCreateCourseDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CreateCourseDialog(
        userSession: widget.userSession,
        lessons: lessons,
        onCourseCreated: () => fetchLessons(),
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
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/friends'),
        headers: {'Authorization': 'Bearer ${widget.userSession.token}'},
      );
      if (res.statusCode == 200) {
        friendsList = jsonDecode(res.body);
      }
    } catch (e) {
      // quiet fail
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
              Text('Pozovi prijatelje u sesiju', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Soba: ${widget.roomCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.tealAccent)),
              const SizedBox(height: 8),
              const Text('Izaberite prijatelje koje želite da pozovete:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              if (friendsList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('Nemate sačuvanih prijatelja.', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                          title: Text(f['name'] ?? 'Prijatelj', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(f['email'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
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
                    body: jsonEncode({'friendIds': selectedFriendIds, 'roomCode': widget.roomCode}),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildMoveHistoryContainer() {
    return MoveHistoryView(
      moveTree: moveTree,
      currentNode: currentNode,
      onSelectNode: _selectNode,
    );
  }

  Widget buildNavigationControls() {
    final isTrener = widget.userSession.role == 'trener';
    final isAllowedToMove = isTrener || (boardControl != 'trainer_only');
    final canGoBack = currentNode != moveTree.root;
    final canGoForward = currentNode.children.isNotEmpty;
    final bool canNavigate = isAllowedToMove;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: canNavigate && canGoBack
                ? () => _selectNode(moveTree.root)
                : null,
            tooltip: 'Idi na početak',
          ),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: canNavigate && canGoBack
                ? () => _selectNode(currentNode.parent!)
                : null,
            tooltip: 'Prethodni potez',
          ),
          const Text(
            'Navigacija',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: canNavigate && canGoForward
                ? () => _selectNode(currentNode.children[0])
                : null,
            tooltip: 'Sledeći potez',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: canNavigate && canGoForward
                ? () {
                    MoveNode curr = currentNode;
                    while (curr.children.isNotEmpty) {
                      curr = curr.children[0];
                    }
                    _selectNode(curr);
                  }
                : null,
            tooltip: 'Idi na kraj',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStudio = widget.roomCode == 'STUDIO';
    final isTrener = activeRole == 'trener' || isStudio;
    final isAllowedToMove = isTrener || isStudio || (boardControl != 'trainer_only');
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 900;

    // Sizing of ChessBoard
    final boardSize = isWide
        ? min(media.size.height * 0.62, media.size.width * 0.42)
        : min(media.size.height * 0.65, media.size.width * 0.9);

    Widget buildCommentBox() {
      final isTrener = activeRole == 'trener' || widget.roomCode == 'STUDIO';
      final hasComment = currentNode.comment.isNotEmpty;
      
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Komentar za potez ${currentNode.san}:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            if (isTrener) ...[
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Unesite komentar...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentNode.comment = commentController.text.trim();
                  });
                  // Sync PGN to students
                  socket.emit('pgn_loaded', {
                    'roomId': widget.roomCode,
                    'pgn': moveTree.exportToPgn(),
                  });
                  _showSuccess('Komentar sačuvan i sinhronizovan!');
                },
                child: const Text('Sačuvaj komentar', style: TextStyle(fontSize: 12)),
              ),
            ] else ...[
              Text(
                hasComment ? currentNode.comment : 'Nema komentara za ovaj potez.',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      );
    }

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
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.input, color: Colors.deepPurpleAccent),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.playlist_add, color: Colors.deepPurpleAccent),
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
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                onSubmitted: (val) {
                  fetchLessons(searchQuery: val.trim());
                },
              ),
              const SizedBox(height: 8),
              _buildMatrixFilterPanel(),
              if (widget.userSession.role == 'ucenik' && widget.roomCode != 'STUDIO') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showShareStudentPositionModal,
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Prikaži moju poziciju treneru'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withOpacity(0.2),
                      foregroundColor: Colors.amberAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Text(
                    'Kategorija: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                  ChoiceChip(
                    label: const Text('Sve', style: TextStyle(fontSize: 10)),
                    selected: _lessonCategoryFilter == 'all',
                    onSelected: (val) {
                      if (val) setState(() => _lessonCategoryFilter = 'all');
                    },
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('Moje', style: TextStyle(fontSize: 10)),
                    selected: _lessonCategoryFilter == 'mine',
                    onSelected: (val) {
                      if (val) setState(() => _lessonCategoryFilter = 'mine');
                    },
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('Od trenera', style: TextStyle(fontSize: 10)),
                    selected: _lessonCategoryFilter == 'trainer',
                    onSelected: (val) {
                      if (val) setState(() => _lessonCategoryFilter = 'trainer');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              isLoadingLessons
                  ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
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
                          final isTrainerLesson = lesson['is_trainer_lesson'] == true;
                          final positionList = lesson['position_list'];
                          final isCourse = positionList != null && (positionList is List) && positionList.isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                isCourse
                                    ? Icons.collections_bookmark
                                    : (isTrainerLesson ? Icons.school : Icons.person),
                                color: isCourse
                                    ? Colors.deepPurpleAccent
                                    : (isTrainerLesson ? Colors.amberAccent : Colors.tealAccent),
                              ),
                              title: Text(
                                lesson['title'],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isTrainerLesson)
                                    const Text(
                                      'Sačuvana lekcija od trenera',
                                      style: TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                    ),
                                  if (isCourse)
                                    Text(
                                      'Kurs od ${positionList.length} pozicija',
                                      style: const TextStyle(fontSize: 10, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
                                    ),
                                  if (lesson['description'] != null && lesson['description'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      lesson['description'],
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                              onTap: () {
                                if (isCourse) {
                                  final firstPos = positionList[0];
                                  loadLessonPosition(firstPos['fen'], firstPos['pgn']);
                                  _showSuccess('Učitana 1. pozicija iz kursa: "${firstPos['title'] ?? lesson['title']}"');
                                } else {
                                  loadLessonPosition(lesson['fen'], lesson['pgn']);
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

    // Right Sidebar Content (Controls & History)
    Widget buildRightSidebar() {
      final isTrener = activeRole == 'trener';
      final isStudio = widget.roomCode == 'STUDIO';

      return Container(
        width: isWide ? 300 : double.infinity,
        color: Theme.of(context).cardColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isStudio ? 'Studio Kontrole' : 'Kontrola i Istorija',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (isStudio) ...[
                ElevatedButton.icon(
                  onPressed: _toggleLocalOrientation,
                  icon: const Icon(Icons.flip),
                  label: const Text('Okreni tablu'),
                ),
                const SizedBox(height: 12),
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
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDrawingMode ? Colors.teal : Colors.deepPurple.withValues(alpha: 0.3),
                        ),
                        icon: Icon(isDrawingMode ? Icons.check : Icons.gesture),
                        label: Text(isDrawingMode ? 'Završi crtanje' : 'Crtaj strelice'),
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
                          _recordEvent('arrow_drawn', {'arrows': <Map<String, dynamic>>[]});
                        },
                        icon: const Icon(Icons.layers_clear, size: 16),
                        label: const Text('Izbriši strelice', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.indigo.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.architecture, color: Colors.indigoAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Studio Režim (Samostalan rad - Učionica isključena)',
                            style: TextStyle(fontSize: 11, color: Colors.indigoAccent, fontWeight: FontWeight.bold),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'trainer_only', child: Text('Samo ja (Trener)')),
                    DropdownMenuItem(value: 'student_white', child: Text('Učenik igra kao Beli')),
                    DropdownMenuItem(value: 'student_black', child: Text('Učenik igra kao Crni')),
                    DropdownMenuItem(value: 'student_both', child: Text('Slobodna analiza')),
                  ],
                  onChanged: _changeStudentPermissions,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Dozvoli učeniku Stockfish', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  value: allowStudentEngine,
                  activeColor: Colors.tealAccent,
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleLocalOrientation,
                        icon: const Icon(Icons.flip),
                        label: const Text('Okreni tablu'),
                      ),
                    ),
                  ],
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
                          backgroundColor: isDrawingMode ? Colors.teal : Colors.deepPurple.withValues(alpha: 0.3),
                        ),
                        icon: Icon(isDrawingMode ? Icons.check : Icons.gesture),
                        label: Text(isDrawingMode ? 'Završi crtanje' : 'Crtaj strelice'),
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
                          _recordEvent('arrow_drawn', {'arrows': <Map<String, dynamic>>[]});
                          socket.emit('pgn_loaded', {
                            'roomId': widget.roomCode,
                            'pgn': moveTree.exportToPgn(),
                          });
                        },
                        icon: const Icon(Icons.layers_clear, size: 16),
                        label: const Text('Izbriši strelice', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Status dozvole: ${_getPermissionLabel(boardControl)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                          style: TextStyle(color: Colors.orange, fontSize: 13),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.lock_open, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          boardControl == 'student_white'
                              ? 'Možete vući samo bele figure.'
                              : boardControl == 'student_black'
                                  ? 'Možete vući samo crne figure.'
                                  : 'Slobodna analiza omogućena.',
                          style: const TextStyle(color: Colors.green, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleLocalOrientation,
                        icon: const Icon(Icons.flip),
                        label: const Text('Okreni tablu'),
                      ),
                    ),
                  ],
                ),
              ],

              if (!isStudio) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.amber.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        else
                          ...roomMembers.map<Widget>((member) {
                            final isMe = member['userId'] == widget.userSession.id;
                            final isMemberTrainer = member['role'] == 'trener';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 8),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${member['name']} ${isMe ? "(Ja)" : ""} ${isMemberTrainer ? "[Trener]" : "[Učenik]"}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (isTrener && !isMe) ...[
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 16),
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
                                            value: 'trener',
                                            child: Text('Promoviši u Trenera (Co-host)', style: TextStyle(fontSize: 12)),
                                          )
                                        else
                                          const PopupMenuItem(
                                            value: 'ucenik',
                                            child: Text('Vrati u Učenika', style: TextStyle(fontSize: 12)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          if (isTrener && !isStudio) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showInSessionInviteFriendsDialog,
                                icon: const Icon(Icons.person_add, size: 14),
                                label: const Text('Pozovi prijatelje u sesiju', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.tealAccent,
                                  side: const BorderSide(color: Colors.tealAccent),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (isAudioConnecting)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                              )
                            else if (audioError != null)
                              const Icon(Icons.warning, color: Colors.redAccent, size: 16)
                            else
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (audioError != null) ...[
                          Text(
                            audioError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (!isAudioConnecting && audioError == null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _toggleLocalMute,
                                  icon: Icon(isAudioMuted ? Icons.mic_off : Icons.mic),
                                  label: Text(isAudioMuted ? 'Uključi mikrofon' : 'Utišaj me'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAudioMuted ? Colors.redAccent.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                    foregroundColor: isAudioMuted ? Colors.redAccent : Colors.greenAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Učesnici u audio razgovoru:',
                            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ...audioUsers.map<Widget>((user) {
                            final isUserMuted = user['isMuted'] ?? false;
                            final isUserTalking = activeSpeakers.contains(user['userId']);
                            final isUserTrainer = user['role'] == 'trener';
                            final isMe = user['userId'] == widget.userSession.id;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Icon(
                                    isUserMuted ? Icons.mic_off : Icons.mic,
                                    size: 16,
                                    color: isUserTalking ? Colors.greenAccent : (isUserMuted ? Colors.redAccent : Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${user['userName']} ${isMe ? "(Ja)" : ""} ${isUserTrainer ? "[Trener]" : ""}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isUserTalking ? FontWeight.bold : FontWeight.normal,
                                        color: isUserTalking ? Colors.greenAccent : Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (isTrener && !isMe)
                                    IconButton(
                                      icon: Icon(isUserMuted ? Icons.volume_off : Icons.volume_up, size: 16),
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
                                      tooltip: isUserMuted ? 'Oduzmi utišanje' : 'Utišaj učenika',
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          if (audioUsers.isEmpty)
                            const Text(
                              'Nema povezanih korisnika.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          if (widget.userSession.role == 'trener' && audioUsers.length > 1) ...[
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                socket.emit('audio_mute_all_students', {'roomId': widget.roomCode});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withValues(alpha: 0.15),
                                foregroundColor: Colors.redAccent,
                              ),
                              child: const Text('Utišaj sve učenike'),
                            ),
                          ],
                          if (widget.userSession.role == 'ucenik' && isAudioMuted && isHandRaised) ...[
                            const SizedBox(height: 8),
                            const Center(
                              child: Text(
                                'Utišani ste. Ruka je podignuta...',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                              ),
                            ),
                          ] else if (widget.userSession.role == 'ucenik' && isAudioMuted) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _raiseHand,
                              icon: const Icon(Icons.pan_tool, size: 14),
                              label: const Text('Podigni ruku za reč'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                                foregroundColor: Colors.orangeAccent,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],

                if (isTrener && !isStudio) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: isRecording ? Colors.red.withValues(alpha: 0.15) : Colors.deepPurple.withValues(alpha: 0.15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isRecording
                                    ? (isRecordingPaused ? Icons.pause_circle_filled : Icons.fiber_manual_record)
                                    : Icons.videocam,
                                color: isRecording
                                    ? (isRecordingPaused ? Colors.orangeAccent : Colors.redAccent)
                                    : Colors.deepPurpleAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isRecording
                                    ? (isRecordingPaused ? 'Snimanje PAUZIRANO' : 'Snimanje U TOKU...')
                                    : 'Snimanje časa (Timeline)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isRecording
                                      ? (isRecordingPaused ? Colors.orangeAccent : Colors.redAccent)
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
                                    onPressed: isRecordingPaused ? _resumeRecording : _pauseRecording,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isRecordingPaused ? Colors.greenAccent : Colors.orangeAccent,
                                      side: BorderSide(color: isRecordingPaused ? Colors.greenAccent : Colors.orangeAccent),
                                    ),
                                    icon: Icon(isRecordingPaused ? Icons.play_arrow : Icons.pause, size: 14),
                                    label: Text(isRecordingPaused ? 'Nastavi' : 'Pauziraj', style: const TextStyle(fontSize: 12)),
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
                                    icon: const Icon(Icons.stop, color: Colors.white, size: 14),
                                    label: const Text('Sačuvaj', style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              onPressed: _startRecording,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurpleAccent,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                              label: const Text('Započni snimanje časa'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                const Divider(height: 24),
              const Text(
                'Potezi',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 180,
                child: _buildMoveHistoryContainer(),
              ),
              const SizedBox(height: 8),
              buildCommentBox(),
              const SizedBox(height: 12),
              // Reset Board Button
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: isAllowedToMove
                          ? () {
                              controller.resetBoard();
                              final startFen = controller.getFen();
                              socket.emit('move', {
                                'roomId': widget.roomCode,
                                'move': null,
                                'currentFen': startFen,
                                'role': widget.userSession.role,
                                'movePath': <String>[],
                              });
                              socket.emit('pgn_loaded', {
                                'roomId': widget.roomCode,
                                'pgn': '',
                              });
                              setState(() {
                                gameStatus = "Tabla je resetovana.";
                                moveTree = MoveTree(startingFen: startFen);
                                commentController.text = '';
                              });
                              _triggerEngineAnalysis();
                            }
                          : null,
                      icon: const Icon(Icons.restart_alt, color: Colors.redAccent),
                      label: const Text('Resetuj za sve', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected ? gameStatus : 'Uspostavljanje veze...'),
        centerTitle: true,
        actions: [
          Icon(
            isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      // Mobile layout has a Drawer for lessons listing (if Trainer)
      drawer: (!isWide && isTrener) ? Drawer(child: buildLeftSidebar()) : null,
      body: isWide
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
                            isTrener ? "Igrate kao Beli (Trener)" : "Igrate kao Crni (Učenik)",
                            style: TextStyle(color: Colors.grey[400], fontSize: 15),
                          ),
                          const SizedBox(height: 20),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isTrener ? "Igrate kao Beli (Trener)" : "Igrate kao Crni (Učenik)",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  _buildChessBoardWithOverlay(boardSize),
                  const SizedBox(height: 12),
                  // PGN navigators on mobile
                  SizedBox(
                    width: boardSize,
                    child: buildNavigationControls(),
                  ),
                  const SizedBox(height: 8),
                  // Stockfish analysis widget directly UNDER board on mobile
                  SizedBox(
                    width: boardSize,
                    child: _buildStockfishAnalysisWidget(),
                  ),
                  const SizedBox(height: 16),
                  // In Mobile mode, we present Right Sidebar content as a card beneath the board
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: buildRightSidebar(),
                  ),
                ],
              ),
            ),
    );
  }
}


