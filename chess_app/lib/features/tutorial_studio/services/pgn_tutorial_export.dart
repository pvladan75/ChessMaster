/// A tutorial becomes a game, or several: phase 4 of
/// `docs/PLAN-PGN-TUTORIJAL.md`.
///
/// Point 2 of the owner's note of 12.9.2026 — „da li se tutorijali mogu
/// pretvoriti u pgn … ako se delovi ne nastavljaju jedan na drugi, onda se
/// prave odvojene partije u istom pgn fajlu". Phase 1 brought a game in; this
/// sends one back out, for a book, for another chess program, or for somebody
/// who does not have this app.
///
/// **Where the file is cut is the viewer's own question.** Two adjacent parts
/// are one game when the second stands on the position the first ran out at —
/// `MoveTree.samePosition(next.fen, endOfMainLine(previous).fen)` — which is
/// exactly the test `LessonViewerScreen` makes to decide whether to cross the
/// join without reloading the pieces. So the file is cut where the child's
/// board would have been rebuilt anyway, and a question cut into a game by
/// phase 2 comes back out as the one continuous game it was.
///
/// **Nothing here writes PGN.** `PgnExporterService` is the one writer —
/// reached through `StudioLessonStep.gameText`, because the tutorial feature
/// calls the exporter through that class and nowhere else — the
/// comments, the `[%cal]` arrows, the `[%csl]` squares, the variations and the
/// NAGs are all its work, and `[SetUp]`/`[FEN]` are written by it whenever a
/// game does not start from the opening position. What this file does is decide
/// which parts belong to which game and hand it a tree per game.
///
/// **What a PGN cannot carry**, and the trainer is told so before the file is
/// written: which way round a part's board is drawn, and the tutorial's own
/// title, labels and language.
library;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart';

/// The parts of [sections] grouped into games, each as one tree.
///
/// The trees are copies with fresh node ids: the draft is what the trainer is
/// still editing and an export must not reach into it. A tutorial always has at
/// least one part, so this always answers with at least one game — a tutorial
/// of nothing but a diagram exports as a game with no moves, which is a legal
/// PGN and says what that part said.
List<AnalysisNode> gameTreesOfTutorial(List<TutorialSection> sections) {
  final games = <AnalysisNode>[];
  AnalysisNode? tail;

  for (final section in sections) {
    final tree = copyTree(section.root);

    if (tail == null || !MoveTree.samePosition(tree.fen, tail.fen)) {
      games.add(tree);
      tail = endOfMainLine(tree);
      continue;
    }

    _joinOnto(tail, tree);
    tail = endOfMainLine(tail);
  }

  return games;
}

/// Every game of [draft], each as its own PGN text.
List<String> pgnGamesOfTutorial(TutorialDraft draft) {
  final games = gameTreesOfTutorial(draft.sections);
  return [
    for (var i = 0; i < games.length; i++)
      StudioLessonStep.gameText(
        games[i],
        headers: _headers(draft, game: i + 1, of: games.length),
      ),
  ];
}

/// The whole tutorial as the text of one `.pgn` file.
///
/// Games are separated by a blank line, which is the boundary `pgnGamesOf`
/// reads them back at and the one `chess_backend/services/gameArchiveImport.js`
/// already splits a database on. One rule, both directions.
String pgnFileOfTutorial(TutorialDraft draft) =>
    '${pgnGamesOfTutorial(draft).join('\n\n')}\n';

/// What the headers say about a tutorial's game.
///
/// `Event` is the tutorial's name, which is the one thing about a tutorial a
/// PGN has a proper home for — „Tutorial" for one that has not been named yet,
/// never the exporter's „Analysis Studio Session", which is what this app
/// stamps on every analysis and says nothing about what is inside. `White` and `Black` are `?` — the standard's own
/// „unknown" — rather than the exporter's „Player" against „Analysis Engine",
/// because nobody played this: it is a lesson. `Round` numbers the games of a
/// tutorial that came apart into several, so a reader can tell the third game
/// of one tutorial from a third game of anything else.
Map<String, String> _headers(TutorialDraft draft,
    {required int game, required int of}) {
  return {
    'Event': draft.title.trim().isEmpty ? 'Tutorial' : draft.title.trim(),
    'White': '?',
    'Black': '?',
    if (of > 1) 'Round': '$game',
  };
}

/// Hangs [next]'s line on [join], the position both describe.
///
/// The two nodes are the same board — that is what got us here — so what [next]
/// carries about it is written onto the node that is already in the game: the
/// sentence, the arrows and the coloured squares. „Insert a line here" drops a
/// continuation's sentence precisely because the part in front has just read it
/// out, so in a tutorial this app cut there is usually nothing to merge; in one
/// a trainer built by hand there often is.
///
/// **The drawings are merged rather than appended**, and that is not tidiness:
/// a cut *copies* the cursor's arrows and squares onto the part it makes,
/// because the board does not reload across a join and a circle that vanished
/// mid-film would be a flicker. Both parts therefore carry the same arrow, and
/// joining them back by concatenation would write it twice — which a reader
/// draws as one arrow over another.
void _joinOnto(AnalysisNode join, AnalysisNode next) {
  final text = next.comment.trim();
  if (text.isNotEmpty) {
    join.comment =
        join.comment.trim().isEmpty ? text : '${join.comment.trim()} $text';
  }
  for (final arrow in next.arrows) {
    if (!join.arrows.any((a) => a.toString() == arrow.toString())) {
      join.arrows.add(arrow);
    }
  }
  for (final square in next.squares) {
    if (!join.squares.any((s) => s.toString() == square.toString())) {
      join.squares.add(square);
    }
  }
  for (final child in next.children) {
    child.parent = join;
    join.children.add(child);
  }
}
