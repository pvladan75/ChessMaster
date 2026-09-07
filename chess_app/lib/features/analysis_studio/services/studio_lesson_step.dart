import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/pgn_span.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/move_tree.dart';

/// One lesson step, built from one node of the analysis tree.
///
/// It exists so that the step's position and the step's line cannot come from
/// different places. They used to: the studio sent `_currentNode.fen` as the
/// position and the export of `_rootNode` as the line, and standing anywhere
/// but the root those two describe different games. The reader skips a move it
/// cannot play without a word, so the trainer was told the step was saved and
/// the child got a still picture.
///
/// Taking one node and answering for both fields is the fix; [line] is the same
/// read the student's screen performs, so [replays] is a claim about that
/// screen rather than about this class.
class StudioLessonStep {
  const StudioLessonStep({
    required this.fen,
    required this.pgn,
    required this.reading,
  });

  /// The position the student's board opens on.
  final String fen;

  /// The line that runs on from it, with each move's words and drawings.
  final String pgn;

  /// What [pgn] comes to when it is read back against [fen] — the same read
  /// the student's screen performs.
  final LessonStepLine reading;

  /// The moves of the step, with each one's words and drawings beside it.
  PgnLine get line => reading.line;

  /// True when every move of the line belongs to this step's position.
  bool get replays => reading.replays;

  int get rejectedMoves => reading.rejectedMoves;

  static StudioLessonStep from(AnalysisNode anchor) {
    final fen = anchor.fen;
    final pgn = PgnExporterService.exportToPgn(anchor);
    return StudioLessonStep(
      fen: fen,
      pgn: pgn,
      reading: LessonStepLine.read(fen: fen, pgn: pgn),
    );
  }

  /// The line as text, with the map of where each node sits inside it.
  ///
  /// **For showing, not for saving.** A save goes through [from], which pairs
  /// the `fen` and the `pgn` and then reads its own work back through the
  /// child's reader; this one is what the „PGN" tab draws and what its caret
  /// and its right-click menu are aimed by. It lives here because the studio is
  /// not allowed to reach for the exporter itself, and that rule is what keeps
  /// the pairing in one place.
  static PgnWithSpans textWithSpans(AnalysisNode anchor) =>
      PgnExporterService.exportWithSpans(anchor);

  Map<String, dynamic> toJson({required String title}) => {
        'fen': fen,
        'pgn': pgn,
        'title': title,
      };
}
