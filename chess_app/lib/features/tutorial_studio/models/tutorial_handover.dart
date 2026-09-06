import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

/// What the Analysis Studio hands over when a trainer turns a line into a
/// tutorial.
///
/// The point of the door is that a line worked out with the engine becomes a
/// tutorial **without being retyped**, so this carries the tree and not only a
/// FEN. Which of the two the trainer meant is asked in the Studio, where they
/// can see what they are standing in.
class TutorialHandover {
  const TutorialHandover({required this.root, this.blackOrientation = false});

  /// The position the first example opens on, with whatever runs on from it.
  final AnalysisNode root;

  /// Which way the board was turned when the trainer left the Studio. A tutorial
  /// about black's defence read from white's side is a different lesson.
  final bool blackOrientation;

  /// Only the position under the board — an empty tree to write into.
  factory TutorialHandover.position(String fen,
          {bool blackOrientation = false}) =>
      TutorialHandover(
        root: AnalysisNode(fen: fen),
        blackOrientation: blackOrientation,
      );

  /// [anchor] and everything below it, **copied**.
  ///
  /// Copied rather than shared: the Studio keeps showing the tree it was
  /// started from, and a tutorial that edited those nodes in place would rewrite
  /// the trainer's analysis behind their back. `fromJson` mints fresh ids as it
  /// goes, which is the same reason clone does — see decision 2.
  factory TutorialHandover.tree(AnalysisNode anchor,
          {bool blackOrientation = false}) =>
      TutorialHandover(
        root: AnalysisNode.fromJson(anchor.toJson()),
        blackOrientation: blackOrientation,
      );
}
