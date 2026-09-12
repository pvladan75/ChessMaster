/// Questions where the review marked a blunder: phase 2 of
/// `docs/PLAN-PGN-TUTORIJAL.md`.
///
/// „Po mogućstvu ili želji korisnika i `kind: ask_move`" — point 1 of the
/// owner's note. A game imported by phase 1 is one long demonstration; this
/// cuts it where „Review entire game" wrote `??` and a „Better move" line beside
/// it, so the child is asked for the move that should have been played.
///
/// **The cutting is `splitForQuestion`**, the same function the studio's „Traži
/// potez na tabli" uses, so a generated tutorial and a hand-built one come out
/// in one shape: a demonstration, a bare position that asks, and a continuation
/// carrying the answer — every part standing on a position that joins the one
/// before it, which is what makes this one board on the child's screen rather
/// than three.
///
/// **The continuation follows the game, not the better line.** The move played
/// is what happened; the engine's line stays a sideline under it. A tutorial
/// about your own game that silently carries on with a game you did not play is
/// a different artefact.
///
/// ## What option 3 buys, and what it does not
///
/// The experiment in `tools/game_annotate/` ended on one finding: a question
/// whose answer is merely *one of several* good moves marks a child wrong for
/// playing the best one, and `readTutorialJson` calls that CLEAN every time.
/// Three answers were on the table; the owner chose the third, „ask only where
/// the review's own threshold already did the filtering".
///
/// That is what this does — a question is made **only** where the review tagged
/// `??`, which means the move lost at least the trainer's threshold (two pawns
/// by default). It is worth being exact about what that does and does not buy,
/// because the difference is a child being told they are wrong:
///
///  * it filters **the moment**. Every question here stands where the game
///    actually turned, rather than somewhere a model found interesting.
///  * it does **not** filter **the answer's uniqueness**. A reviewed PGN carries
///    no evaluations — `GameAnalysisWalkerService` deliberately stopped writing
///    a number onto the node, „the engine's opinion wearing the reader's
///    handwriting" — so nothing in the file says whether a second move was just
///    as good. Only option 2, an engine search per question at import time,
///    removes that, and it makes importing a file wait on a search.
///
/// So the two mitigations that cost nothing are taken here instead: the question
/// **never claims the answer is the only move**, and the part right after it
/// shows the better line, so a child who played something else sees what was
/// meant rather than only „wrong".
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

/// How many questions one imported game may become.
///
/// A tutorial is four to ten parts and every question costs two or three of
/// them, so four questions is already a full tutorial. The third game of the
/// experiment had **eighteen** moves tagged at 0.8 pawns: without a ceiling, a
/// messy blitz game becomes forty parts that nobody walks through to the end.
const int defaultMaxQuestions = 4;

/// The mark „Review entire game" writes on a move that lost the threshold, and
/// the one it writes on the engine's own move beside it.
const String _blunder = '??';
const String _better = '!';

/// [whole] cut into demonstration / question / continuation at each blunder.
///
/// Returns [whole] on its own when there is nothing to ask about — a game with
/// no marks, a part that already asks something, or a part with no moves.
List<TutorialSection> sectionsWithQuestions(
  TutorialSection whole, {
  int maxQuestions = defaultMaxQuestions,
}) {
  if (maxQuestions <= 0) return [whole];

  final out = <TutorialSection>[];
  var rest = whole;
  // The continuation of a split opens with the move the question was about, so
  // searching it from the first ply would find that same blunder for ever.
  var skipFirstMove = false;
  var made = 0;

  while (made < maxQuestions) {
    if (!canSplitForQuestion(rest)) break;

    final found = _firstBlunder(rest.root, skipFirstMove: skipFirstMove);
    if (found == null) break;

    final parts = splitForQuestion(rest, found.cursor);
    final askIndex = parts.indexWhere((p) => p.kind == LessonStepKind.askMove);
    // `splitForQuestion` always makes one, and a shape that changed underneath
    // is worth stopping on rather than guessing at.
    if (askIndex < 0) break;

    out.addAll(parts.take(askIndex));
    out.add(_asked(parts[askIndex], found));
    made++;

    if (askIndex + 1 >= parts.length) return out;
    rest = parts[askIndex + 1];
    skipFirstMove = true;
  }

  out.add(rest);
  return out;
}

/// The same question part, asking for the engine's move instead of the one that
/// was played.
///
/// `splitForQuestion` takes the move that already followed as the answer, which
/// is right when a trainer cuts a line themselves — here that move is the
/// blunder. Everything else it decided is kept: the position, the marks drawn on
/// it, which way round the board opens, and which part carries the step id.
TutorialSection _asked(TutorialSection question, _Blunder found) {
  return TutorialSection(
    stepId: question.stepId,
    root: question.root,
    title: question.title,
    kind: LessonStepKind.askMove,
    instruction: askingSentence(
      fen: question.root.fen,
      playedSan: found.played.moveSan ?? '',
    ),
    solutionSan: found.better.moveSan,
    blackOrientation: question.blackOrientation,
  );
}

/// What the child is asked, in one sentence.
///
/// **It claims nothing about the answer being the only move**, which is the
/// whole of option 3's cheap half: „what should White have played" is true even
/// where two moves are equally good, and „find the only move that saves the
/// rook" is the sentence the experiment caught being false.
String askingSentence({required String fen, required String playedSan}) {
  final side = sideToMoveIn(fen);
  return '$side played $playedSan here, and it was a mistake. '
      'What should $side have played instead?';
}

/// „White" or „Black", read off the position rather than counted from the root:
/// a game can start anywhere, and a part opening on a black-to-move position is
/// ordinary.
String sideToMoveIn(String fen) {
  final fields = fen.split(' ');
  return fields.length > 1 && fields[1] == 'b' ? 'Black' : 'White';
}

/// A blunder on the main line, with the engine's move beside it.
class _Blunder {
  const _Blunder({
    required this.cursor,
    required this.played,
    required this.better,
  });

  /// The position the question is asked from — where the blunder was played.
  final AnalysisNode cursor;

  /// The move that was played there, which the question names.
  final AnalysisNode played;

  /// The engine's move, which is the answer.
  final AnalysisNode better;
}

/// The first blunder down the main line that has a „Better move" beside it.
///
/// Both marks are required. A `??` with no alternative is a move somebody
/// disapproved of and nothing to ask about; the sideline is where the answer
/// comes from, and it came from the engine when the review wrote it.
_Blunder? _firstBlunder(AnalysisNode root, {bool skipFirstMove = false}) {
  var node = root;
  var ply = 0;
  while (node.children.isNotEmpty) {
    final played = node.children.first;
    ply++;
    if (!(skipFirstMove && ply == 1) && played.nag == _blunder) {
      for (final sibling in node.children.skip(1)) {
        if (sibling.nag == _better && (sibling.moveSan ?? '').isNotEmpty) {
          return _Blunder(cursor: node, played: played, better: sibling);
        }
      }
    }
    node = played;
  }
  return null;
}

/// The same tutorial with questions cut into it — the entry point phase 3 calls.
///
/// Every part is judged again by [problemsWithStep], because the parts are not
/// the ones that were judged before: a question that cannot be answered from its
/// own position has to be reported here rather than at the server.
ImportedTutorial withQuestionsFromBlunders(
  ImportedTutorial source, {
  int maxQuestions = defaultMaxQuestions,
}) {
  if (!source.openable) return source;

  final sections = <TutorialSection>[];
  for (final step in source.positionList) {
    final part = TutorialSection.fromStep(step);
    sections.addAll(sectionsWithQuestions(part, maxQuestions: maxQuestions));
  }

  final positionList = <Map<String, dynamic>>[];
  final problems = <ImportProblem>[];
  for (var i = 0; i < sections.length; i++) {
    final json = sections[i].toJson(index: i);
    // The server mints step ids; a generated part has no business naming one,
    // and two parts cut from one step must never carry the same id.
    json.remove('id');
    positionList.add(json);
    problems.addAll(problemsWithStep(json, partNumber: i + 1));
  }

  return ImportedTutorial(
    title: source.title,
    description: source.description,
    tags: source.tags,
    language: source.language,
    positionList: positionList,
    problems: problems,
    fileName: source.fileName,
  );
}

/// How many questions [source] would become — for a dialog that says so before
/// a trainer chooses.
int questionsAvailableIn(ImportedTutorial source,
    {int maxQuestions = defaultMaxQuestions}) {
  if (!source.openable) return 0;
  var found = 0;
  for (final step in source.positionList) {
    final parts = sectionsWithQuestions(TutorialSection.fromStep(step),
        maxQuestions: maxQuestions);
    found += parts.where((p) => p.kind == LessonStepKind.askMove).length;
  }
  return found;
}

/// Whether [san] can be played in [fen] — the same question `problemsWithStep`
/// asks, kept here so a caller can check one move without building a step.
bool moveFits(String fen, String san) {
  try {
    return chess.Chess.fromFEN(fen).move(san) == true;
  } catch (_) {
    return false;
  }
}
