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
/// The two nodes are the same board — that is what got us here — so what
/// [next] carries about it joins what [join] already carries: each part's
/// sentences as beats of the one position, in order (D4 of
/// `docs/PLAN-PRIPREMA.md`). On `master`, with one beat to a position, the two
/// comments were glued into one; now there is room for both, so each stays
/// its own beat rather than being concatenated into a sentence neither part
/// wrote.
///
/// **A wordless first beat that carries the marks of the beat before it adds
/// nothing.** „Insert a line here" copies the cursor's marks onto the part it
/// makes (`AnalysisNode.rootLike`) precisely because the board does not
/// reload across a join — a circle that vanished mid-film would be a flicker
/// — and in a tutorial this app cut, that copy is usually all the new part's
/// first beat holds. A beat that says nothing new and draws nothing new is
/// not a second sentence; it is the same one the film has already shown.
void _joinOnto(AnalysisNode join, AnalysisNode next) {
  final joinedLast = join.lastBeat;
  for (var i = 0; i < next.beats.length; i++) {
    final beat = next.beats[i];
    if (i == 0 && beat.comment.trim().isEmpty && _sameMarks(beat, joinedLast)) {
      continue;
    }
    join.beats.add(beat.copy());
  }
  for (final child in next.children) {
    child.parent = join;
    join.children.add(child);
  }
}

/// Whether [a] and [b] draw exactly the same arrows and squares.
bool _sameMarks(NodeBeat a, NodeBeat b) =>
    a.arrows.map((x) => x.toString()).join(',') ==
        b.arrows.map((x) => x.toString()).join(',') &&
    a.squares.map((x) => x.toString()).join(',') ==
        b.squares.map((x) => x.toString()).join(',');
