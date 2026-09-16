/// A repertoire as a PGN file — the owner's report of 16.9.2026, „razmotriti
/// mogućnost čuvanja repertoara kao pgn (sa upisom ili bez komentara koje je
/// korisnik uneo)".
///
/// Everything a PGN needs was already here: the server assembles the tree, the
/// comments are read beside it, and `PgnExporterService` writes variations. So
/// this file is two decisions and no new machinery.
///
/// **The drawing's tree is not the export's tree.** `repertoireTreeToNodes`
/// writes the card's label into `AnalysisNode.nag` — ` ★`, ` 45% ?` — and the
/// exporter writes `nag` straight after the move, so exporting the picture
/// would put `1. e4 ★ 45%` in the file. A reader that met that would be right
/// to refuse it. The tree is built again here, clean, and the label stays in
/// the widget it belongs to.
///
/// **Which move is the main one needs no convention.** The server hands a
/// position's moves back with the student's primary first and the opponent's
/// replies by descending share, and PGN's own main line is the first child at
/// every step — so the file's main line *is* the repertoire's, and the
/// alternates are its variations. Inventing a `{main}` marker beside that would
/// be a second spelling of something already said.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/repertoire/line_text.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// How deep an export asks for.
///
/// `GET /repertoire/tree` clamps `maxPly` to 40 and defaults to 16, and a
/// screen asks for what it can draw. A file is not a screen: it is asked for
/// once and read elsewhere, so it asks for everything the server will give and
/// says so when that was not everything.
const int repertoireExportMaxPly = 40;

/// Where a game starts when nothing says otherwise.
const String standardOpeningFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The repertoire as PGN text.
///
/// [comments] are the student's own notes, keyed by `fenKey` the way
/// `RepertoireApiService.comments` hands them back. Pass `const {}` to write
/// the moves alone — the export dialog offers both, and includes them by
/// default, because a line with no words in it is the one thing the book and
/// the engine can rebuild without any of this.
String repertoirePgn({
  required String name,
  required String color,
  required RepertoireTree tree,
  Map<String, RepertoireComment> comments = const {},
}) =>
    PgnExporterService.exportToPgn(
      repertoireExportTree(tree: tree, comments: comments),
      customHeaders: repertoirePgnHeaders(name: name, color: color),
    );

/// What the file says it is.
///
/// `[White]`/`[Black]` name the two sides of a repertoire rather than two
/// people: one of them is the student, and which one is the whole point of the
/// file. The exporter's other defaults — `Site`, `Date`, `Round`, `Result` —
/// are left as they are, and it adds `SetUp`/`FEN` itself when the tree does
/// not start from the first move.
Map<String, String> repertoirePgnHeaders({
  required String name,
  required String color,
}) {
  final mine = color == 'w' ? 'White' : 'Black';
  return {
    'Event': 'Repertoire: $name',
    'White': color == 'w' ? 'Repertoire' : 'Opponent',
    'Black': color == 'w' ? 'Opponent' : 'Repertoire',
    'Annotator': 'Repertoire ($mine)',
  };
}

/// The tree the export is written from.
///
/// A repertoire may begin anywhere — „build from here" on a position four moves
/// in — and `rootPath` is how it got there. Where that path replays from the
/// first move onto the root the server sent, the file is written **from move
/// one**, which is what every PGN reader wants and what makes the line
/// recognisable without a FEN. Where it does not — a repertoire extracted from
/// a position nobody walked to, a path that no longer replays — the root is
/// exported as a diagram and the line is named in a comment ahead of move one,
/// rather than a guess being stamped on the file.
///
/// The check is a second reading and not a promise: the path is replayed, and
/// it is used only when the position it lands on is the one the tree is about.
/// Same rule as a pasted game with no header, 8.9.2026.
AnalysisNode repertoireExportTree({
  required RepertoireTree tree,
  Map<String, RepertoireComment> comments = const {},
}) {
  String? noteAt(String fen) {
    final body = comments[fenKeyOf(fen)]?.body.trim();
    return body == null || body.isEmpty ? null : body;
  }

  final spine = _spineFromFirstMove(tree.rootFen, tree.rootPath, noteAt);
  final root = spine?.root ?? AnalysisNode(fen: tree.rootFen);
  final from = spine?.tip ?? root;

  if (spine == null) {
    // No spine, so the line is written rather than played. The student's own
    // note about the root keeps its own paragraph under it: two sentences from
    // two authors must not read as one.
    final line = numberedLine(tree.rootPath);
    final own = noteAt(tree.rootFen);
    root.comment = [
      if (line.isNotEmpty) 'Repertoire line: $line',
      if (own != null) own,
    ].join('\n');
  } else {
    from.comment = noteAt(tree.rootFen) ?? '';
  }

  void add(AnalysisNode parent, RepertoireTreeMove move) {
    final node = parent.addChild(
      childFen: move.fen,
      san: move.san,
      uci: move.uci,
    );
    node.comment = noteAt(move.fen) ?? '';
    for (final child in move.children) {
      add(node, child);
    }
  }

  for (final child in tree.children) {
    add(from, child);
  }
  return root;
}

/// The moves that led to the root, as nodes, when they really do lead there.
///
/// Null when [path] is empty, when a move in it will not play, or when the
/// position it ends on is not [rootFen] — any of which means this repertoire's
/// root is not reachable from the first move by the path it carries, and the
/// caller writes a diagram instead.
({AnalysisNode root, AnalysisNode tip})? _spineFromFirstMove(
  String rootFen,
  List<String> path,
  String? Function(String fen) noteAt,
) {
  if (path.isEmpty) {
    // A repertoire that starts at move one has no spine to build and needs
    // none — the root *is* the first position. One that starts elsewhere and
    // says nothing about how it got there cannot be placed, and is a diagram.
    if (fenKeyOf(rootFen) != fenKeyOf(standardOpeningFen)) return null;
    final only = AnalysisNode(fen: standardOpeningFen);
    return (root: only, tip: only);
  }

  final board = chess.Chess.fromFEN(standardOpeningFen);
  final root = AnalysisNode(fen: standardOpeningFen);
  var at = root;
  for (final san in path) {
    if (board.move(san) == false) return null;
    // Read off the move that was just played rather than out of
    // `getHistory({'verbose': true})`: that one undoes and replays the whole
    // game per call, and its map carries no promotion piece — so `e8=Q` and
    // `e8=N` would be written as one uci, which is two different lines wearing
    // one name.
    final played = board.history.last.move;
    at = at.addChild(
      childFen: board.fen,
      san: san,
      uci: '${played.fromAlgebraic}${played.toAlgebraic}'
          '${played.promotion?.name ?? ''}',
    );
    at.comment = noteAt(board.fen) ?? '';
  }
  if (fenKeyOf(board.fen) != fenKeyOf(rootFen)) return null;
  return (root: root, tip: at);
}
