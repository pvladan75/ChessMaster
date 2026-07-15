import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/stockfish_service.dart';

class EngineMove {
  final String display;
  final String from;
  final String to;

  EngineMove({required this.display, required this.from, required this.to});
}

class AnalysisLine {
  final int multipv;
  final String evaluation;
  final String bestMove;
  final String continuation;
  final List<EngineMove> moves;

  AnalysisLine({
    required this.multipv,
    required this.evaluation,
    required this.bestMove,
    required this.continuation,
    required this.moves,
  });
}

// 3. MULTIPLAYER CHESS GAME PAGE
class ChessGamePage extends StatefulWidget {
  final String roomCode;
  final UserSession userSession;

  const ChessGamePage({super.key, required this.roomCode, required this.userSession});

  @override
  State<ChessGamePage> createState() => _ChessGamePageState();
}

class _ChessGamePageState extends State<ChessGamePage> {
  late ChessBoardController controller;
  late io.Socket socket;
  bool isConnected = false;
  String gameStatus = "Spajanje na game server...";
  
  PlayerColor boardOrientation = PlayerColor.white;
  String boardControl = 'trainer_only';

  final StockfishService _stockfishService = StockfishService();
  bool isEngineEnabled = false;
  String currentEngineEval = "0.00";
  String bestEngineMove = "-";
  Map<int, AnalysisLine> engineLines = {};

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

  @override
  void initState() {
    super.initState();
    controller = ChessBoardController();
    // Default orientation: Trainer is White, Student is Black
    boardOrientation = widget.userSession.role == 'trener'
        ? PlayerColor.white
        : PlayerColor.black;
    moveTree = MoveTree(startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    initSocket();
    
    // Fetch saved lessons for trainer
    if (widget.userSession.role == 'trener') {
      fetchLessons();
    }

    // Set up Stockfish service evaluation listener
    _stockfishService.onEvaluationChanged = (evaluation, bestMove, continuation, multipv) {
      setState(() {
        if (evaluation.isNotEmpty || continuation.isNotEmpty) {
          final movesList = _parseContinuation(controller.getFen(), continuation);
          engineLines[multipv] = AnalysisLine(
            multipv: multipv,
            evaluation: evaluation.isNotEmpty ? evaluation : (engineLines[multipv]?.evaluation ?? '0.00'),
            bestMove: bestMove.isNotEmpty ? bestMove : (engineLines[multipv]?.bestMove ?? '-'),
            continuation: continuation,
            moves: movesList,
          );

          if (multipv == 1) {
            if (evaluation.isNotEmpty) {
              currentEngineEval = evaluation;
            }
            if (bestMove.isNotEmpty) {
              bestEngineMove = bestMove.toUpperCase();
            }
          }
        }
      });
    };
  }

  @override
  void dispose() {
    _stockfishService.dispose();
    commentController.dispose();
    fenPasteController.dispose();
    pgnPasteController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _triggerEngineAnalysis() {
    if (isEngineEnabled) {
      setState(() {
        engineLines.clear();
        currentEngineEval = "0.00";
        bestEngineMove = "-";
      });
      _stockfishService.analyzePosition(controller.getFen());
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

        result.add(EngineMove(display: san, from: from, to: to));
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

  Widget _buildContinuationRow() {
    if (engineLines.isEmpty) return const SizedBox.shrink();

    final sortedKeys = engineLines.keys.toList()..sort();
    final List<Widget> lineWidgets = [];

    final parts = controller.getFen().split(' ');
    final isWhite = parts[1] == 'w';

    for (final multipv in sortedKeys) {
      final line = engineLines[multipv]!;
      if (line.moves.isEmpty) continue;

      final List<InlineSpan> spans = [];
      int moveNum = int.tryParse(parts[5]) ?? 1;

      spans.add(TextSpan(
        text: '(${line.evaluation}) ',
        style: TextStyle(
          color: line.evaluation.startsWith('+') || line.evaluation.startsWith('M')
              ? Colors.greenAccent
              : line.evaluation.startsWith('-')
                  ? Colors.redAccent
                  : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ));

      for (int i = 0; i < line.moves.length; i++) {
        final move = line.moves[i];
        final currentIsWhite = (i % 2 == 0) ? isWhite : !isWhite;

        if (currentIsWhite) {
          spans.add(TextSpan(
            text: '$moveNum. ',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ));
        } else if (i == 0) {
          spans.add(TextSpan(
            text: '$moveNum... ',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ));
        }

        spans.add(TextSpan(
          text: '${move.display} ',
          style: const TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.w500,
            fontSize: 11,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _playEngineMoves(line.moves, i);
            },
        ));

        if (!currentIsWhite) {
          moveNum++;
        }
      }

      lineWidgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: RichText(
          text: TextSpan(children: spans),
        ),
      ));
    }

    if (lineWidgets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Linije analize (kliknite potez za kretanje):',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lineWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildChessBoardWithOverlay(double boardSize) {
    final isTrener = widget.userSession.role == 'trener';
    final isAllowedToMove = isTrener || (boardControl != 'trainer_only');

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
        'playerColor': widget.userSession.role == 'trener' ? 'white' : 'black'
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

  // REST API: Fetch saved lessons (with optional search)
  Future<void> fetchLessons({String? searchQuery}) async {
    setState(() => isLoadingLessons = true);
    try {
      String url = '$backendUrl/lessons';
      if (searchQuery != null && searchQuery.isNotEmpty) {
        url += '?search=${Uri.encodeComponent(searchQuery)}';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          lessons = data;
        });
      }
    } catch (e) {
      _showError('Greška prilikom učitavanja lekcija sa servera.');
    } finally {
      setState(() => isLoadingLessons = false);
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
    socket.emit('move', {
      'roomId': widget.roomCode,
      'move': (from != null && to != null) ? {'from': from, 'to': to} : null,
      'currentFen': newFen ?? controller.getFen(),
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
      builder: (context) {
        return AlertDialog(
          title: Text('Izaberite partiju (${games.length})'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return ListTile(
                  title: Text(game.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    game.pgnBody.length > 60
                        ? '${game.pgnBody.substring(0, 60)}...'
                        : game.pgnBody,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                  onTap: () {
                    Navigator.pop(context);
                    _loadSinglePgnGame(game);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
          ],
        );
      },
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

      // Load root/start position FEN
      controller.loadFen(moveTree.root.fen);
      
      // Sync starting position via socket
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

  void _showSaveDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final tagsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sačuvaj trenutnu lekciju'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Naziv lekcije',
                    hintText: 'Npr. Sicilijanska odbrana - Zmajeva varijanta',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Opšti komentar / Opis',
                    hintText: 'Opis teme lekcije ili ključne smernice',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tagovi (odvojeni zarezom)',
                    hintText: 'otvaranje, taktika, sicilijanka',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final desc = descController.text.trim();
                final tagsRaw = tagsController.text.trim();
                
                if (title.isEmpty) {
                  _showError('Unesite naziv lekcije.');
                  return;
                }

                final List<String> tags = tagsRaw.isEmpty
                    ? []
                    : tagsRaw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

                saveCurrentPosition(title, desc, tags);
                Navigator.pop(context);
              },
              child: const Text('Sačuvaj'),
            ),
          ],
        );
      },
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

  List<InlineSpan> _buildSpans(MoveNode node, BuildContext context) {
    final List<InlineSpan> spans = [];
    _collectSpans(node, spans, context, true);
    return spans;
  }

  void _collectSpans(MoveNode node, List<InlineSpan> spans, BuildContext context, bool showMoveNumber) {
    if (node.children.isEmpty) return;

    final mainChild = node.children[0];
    final parts = node.fen.split(' ');
    final isWhite = parts[1] == 'w';
    final moveNum = int.tryParse(parts[5]) ?? 1;

    if (isWhite) {
      spans.add(TextSpan(
        text: '$moveNum. ',
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
      ));
    } else if (showMoveNumber) {
      spans.add(TextSpan(
        text: '$moveNum... ',
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
      ));
    }

    final isMainActive = currentNode == mainChild;

    spans.add(TextSpan(
      text: '${mainChild.san} ',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: isMainActive ? Colors.greenAccent : Colors.white,
        backgroundColor: isMainActive ? Colors.green.withOpacity(0.3) : Colors.transparent,
      ),
      recognizer: TapGestureRecognizer()..onTap = () => _selectNode(mainChild),
    ));

    if (mainChild.comment.isNotEmpty) {
      spans.add(TextSpan(
        text: '{${mainChild.comment}} ',
        style: const TextStyle(color: Colors.yellowAccent, fontStyle: FontStyle.italic, fontSize: 12),
      ));
    }

    // Variations
    for (int i = 1; i < node.children.length; i++) {
      final varChild = node.children[i];
      spans.add(const TextSpan(
        text: '( ',
        style: TextStyle(color: Colors.grey, fontSize: 11),
      ));

      if (isWhite) {
        spans.add(TextSpan(
          text: '$moveNum. ',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ));
      } else {
        spans.add(TextSpan(
          text: '$moveNum... ',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ));
      }

      final isVarActive = currentNode == varChild;

      spans.add(TextSpan(
        text: '${varChild.san} ',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.normal,
          color: isVarActive ? Colors.greenAccent : Colors.grey[400],
          backgroundColor: isVarActive ? Colors.green.withOpacity(0.3) : Colors.transparent,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _selectNode(varChild),
      ));

      if (varChild.comment.isNotEmpty) {
        spans.add(TextSpan(
          text: '{${varChild.comment}} ',
          style: const TextStyle(color: Colors.yellowAccent, fontStyle: FontStyle.italic, fontSize: 10),
        ));
      }

      _collectSpans(varChild, spans, context, false);

      spans.add(const TextSpan(
        text: ') ',
        style: TextStyle(color: Colors.grey, fontSize: 11),
      ));
    }

    final nextShowMoveNumber = node.children.length > 1;
    _collectSpans(mainChild, spans, context, nextShowMoveNumber);
  }

  Widget _buildMoveHistoryContainer() {
    final List<InlineSpan> spans = _buildSpans(moveTree.root, context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: spans.isEmpty
          ? const Center(
              child: Text(
                'Nema odigranih poteza.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: RichText(
                text: TextSpan(
                  children: spans,
                ),
              ),
            ),
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
    final isTrener = widget.userSession.role == 'trener';
    final isAllowedToMove = isTrener || (boardControl != 'trainer_only');
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 900;

    // Sizing of ChessBoard
    final boardSize = isWide
        ? min(media.size.height * 0.62, media.size.width * 0.42)
        : min(media.size.height * 0.65, media.size.width * 0.9);

    Widget buildCommentBox() {
      final isTrener = widget.userSession.role == 'trener';
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lekcije i Pozicije',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (isTrener) ...[
                ElevatedButton.icon(
                  onPressed: _showSaveDialog,
                  icon: const Icon(Icons.save),
                  label: const Text('Sačuvaj lekciju'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _openLocalPgnFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Otvori PGN fajl'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
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
              ],
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
              const SizedBox(height: 12),
              const Text(
                'Sačuvane lekcije',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: isLoadingLessons
                    ? const Center(child: CircularProgressIndicator())
                    : lessons.isEmpty
                        ? const Center(
                            child: Text(
                              'Nema sačuvanih lekcija.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: lessons.length,
                            itemBuilder: (context, index) {
                              final lesson = lessons[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(
                                    lesson['title'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (lesson['description'] != null && lesson['description'].toString().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          lesson['description'],
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                      if (lesson['tags'] != null && (lesson['tags'] as List).isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: (lesson['tags'] as List).map<Widget>((t) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                t.toString(),
                                                style: const TextStyle(fontSize: 9, color: Colors.blueAccent),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Kreirano: ${lesson['created_at'].toString().split('T')[0]}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                                    onPressed: () => loadLessonPosition(lesson['fen'], lesson['pgn']),
                                    tooltip: 'Učitaj lekciju',
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      );
    }

    // Right Sidebar Content (Controls & History)
    Widget buildRightSidebar() {
      return Container(
        width: isWide ? 300 : double.infinity,
        color: Theme.of(context).cardColor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kontrola i Istorija',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (isTrener) ...[
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
                          backgroundColor: isDrawingMode ? Colors.teal : Colors.deepPurple.withOpacity(0.3),
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
              const Divider(height: 24),
              Card(
                color: Colors.deepPurple.withOpacity(0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology, color: Colors.tealAccent),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Stockfish Analiza',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _stockfishService.isOnline ? 'Online (Cloud)' : 'Lokalni Engine',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: isEngineEnabled,
                            activeThumbColor: Colors.tealAccent,
                            activeTrackColor: Colors.tealAccent.withOpacity(0.5),
                            onChanged: (val) {
                              setState(() {
                                isEngineEnabled = val;
                                if (isEngineEnabled) {
                                  _stockfishService.initEngine();
                                  _triggerEngineAnalysis();
                                } else {
                                  _stockfishService.dispose();
                                  currentEngineEval = "0.00";
                                  bestEngineMove = "-";
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      if (isEngineEnabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Ocena', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  currentEngineEval,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: currentEngineEval.startsWith('+') || currentEngineEval.startsWith('M')
                                        ? Colors.greenAccent
                                        : currentEngineEval.startsWith('-')
                                            ? Colors.redAccent
                                            : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.withOpacity(0.3)),
                            Column(
                              children: [
                                const Text('Najbolji potez', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  bestEngineMove,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.tealAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        _buildContinuationRow(),
                      ],
                    ],
                  ),
                ),
              ),
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

Offset getSquareCenter(String square, double boardSize, PlayerColor orientation) {
  if (square.length < 2) return Offset.zero;
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0); // 0 to 7
  final rank = int.parse(square[1]) - 1; // 0 to 7

  double col = file.toDouble();
  double row = 7.0 - rank.toDouble();

  if (orientation == PlayerColor.black) {
    col = 7.0 - file.toDouble();
    row = rank.toDouble();
  }

  final squareSize = boardSize / 8;
  final x = col * squareSize + squareSize / 2;
  final y = row * squareSize + squareSize / 2;

  return Offset(x, y);
}

String getSquareFromOffset(Offset localOffset, double boardSize, PlayerColor orientation) {
  final squareSize = boardSize / 8;
  int col = (localOffset.dx / squareSize).floor();
  int row = (localOffset.dy / squareSize).floor();

  if (col < 0) col = 0;
  if (col > 7) col = 7;
  if (row < 0) row = 0;
  if (row > 7) row = 7;

  int fileIndex = col;
  int rankIndex = 7 - row;

  if (orientation == PlayerColor.black) {
    fileIndex = 7 - col;
    rankIndex = row;
  }

  final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
  final rank = rankIndex + 1;

  return '$file$rank';
}

class ChessBoardPainter extends CustomPainter {
  final List<ChessArrow> arrows;
  final double boardSize;
  final PlayerColor orientation;
  final String? highlightedSquare;

  ChessBoardPainter({
    required this.arrows,
    required this.boardSize,
    required this.orientation,
    this.highlightedSquare,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = boardSize / 8;

    // Draw highlighted starting square for drawing mode
    if (highlightedSquare != null) {
      final center = getSquareCenter(highlightedSquare!, boardSize, orientation);
      final paint = Paint()
        ..color = Colors.tealAccent.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, squareSize * 0.4, paint);
    }

    // Draw arrows
    for (final arrow in arrows) {
      final start = getSquareCenter(arrow.from, boardSize, orientation);
      final end = getSquareCenter(arrow.to, boardSize, orientation);

      if (start == Offset.zero || end == Offset.zero) continue;

      final ui.Color color = _getColor(arrow.colorCode);
      final paint = Paint()
        ..color = color.withOpacity(0.75)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw line
      canvas.drawLine(start, end, paint);

      // Draw arrowhead
      final dir = end - start;
      final length = dir.distance;
      if (length < 5) continue;

      final u = dir / length; // Unit vector
      final headLength = 16.0;
      final headWidth = 10.0;

      // Point back along the line
      final backPoint = end - u * headLength;
      
      // Orthogonal vectors for arrowhead sides
      final ortho = Offset(-u.dy, u.dx);
      final p1 = backPoint + ortho * headWidth;
      final p2 = backPoint - ortho * headWidth;

      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      final headPaint = Paint()
        ..color = color.withOpacity(0.75)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, headPaint);
    }
  }

  ui.Color _getColor(String code) {
    switch (code) {
      case 'R':
        return Colors.red;
      case 'G':
        return Colors.green;
      case 'B':
        return Colors.blue;
      case 'O':
        return Colors.orange;
      default:
        return Colors.tealAccent;
    }
  }

  @override
  bool shouldRepaint(covariant ChessBoardPainter oldDelegate) {
    return oldDelegate.arrows != arrows ||
        oldDelegate.boardSize != boardSize ||
        oldDelegate.orientation != orientation ||
        oldDelegate.highlightedSquare != highlightedSquare;
  }
}
