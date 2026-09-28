/// A position study from beginning to end — `docs/PLAN-STUDIJA-POZICIJE.md`.
///
/// The engine works the position out ([PositionStudyBuilder]), the model is
/// asked for the words ([StudyWordsAsker]), the app judges them
/// ([judgeStudyWords]) and the tree is written ([writeStudy]). **The lines
/// are written whatever the words come to**: a refusal, a timeout or a server
/// that cannot be reached costs the comments and nothing else, and the result
/// says which.
///
/// No screen and no HTTP of its own: the engine, the tablebase and the way
/// words are asked for are handed in.
library;

import 'package:chess_app/core/services/game_review_judge.dart'
    show TablebaseLookup;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_tree.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words_client.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;

export 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart'
    show
        PositionStudy,
        StudyCancelled,
        StudyRefused,
        kStudySearchBudget,
        StudyProgress;
export 'package:chess_app/features/analysis_studio/services/position_study/study_tree.dart'
    show StudyWritten;
export 'package:chess_app/features/analysis_studio/services/position_study/study_words_client.dart'
    show StudyWordsAsker, StudyWordsOutcome, requestStudyWords;

/// What a study came to.
class StudyResult {
  const StudyResult({
    required this.study,
    required this.written,
    required this.offered,
    required this.answered,
    required this.kept,
    required this.refusedClaims,
    required this.refusal,
  });

  final PositionStudy study;
  final StudyWritten written;

  /// Slots the words were asked for; zero when no words were asked for.
  final int offered;

  /// Slots the model wrote words for; it may leave one out.
  final int answered;

  /// Slots whose words were written into the tree: [answered] less the ones
  /// the app's check refused.
  final int kept;

  /// Why the app refused some of the words that came back.
  final List<String> refusedClaims;

  /// Why no words came back at all; null when some did, or none were asked
  /// for.
  final WordsRefusal? refusal;

  /// The engine searches that did not come back whole.
  List<String> get lostSearches => study.problems;
}

/// Studies the position [start] stands on and writes the study under it.
///
/// [ask] null studies without words: the lines and their marks of judgement,
/// and no comment. Throws [StudyRefused] for a position no study can be made
/// of and [StudyCancelled] when [isCancelled] says so — in both cases before
/// anything is written to the tree.
Future<StudyResult> runPositionStudy({
  required AnalysisNode start,
  required PositionAnalyzer analyzer,
  required int depth,
  TablebaseLookup? tablebase,
  StudyWordsAsker? ask,
  Duration searchTimeout = const Duration(seconds: 90),
  bool Function()? isCancelled,
  StudyProgress? onProgress,
  void Function()? onWriting,
}) async {
  final study = await PositionStudyBuilder(
    analyzer: analyzer,
    depth: depth,
    tablebase: tablebase,
    timeout: searchTimeout,
    isCancelled: isCancelled,
  ).build(start.fen, onProgress: onProgress);

  var offered = 0;
  var came = 0;
  var kept = const <String, String>{};
  var refusedClaims = const <String>[];
  WordsRefusal? refusal;
  if (ask != null) {
    final request = studyWordsRequest(study);
    offered = request.slots.length;
    onWriting?.call();
    final outcome = await ask(request.toJson(), comment: false);
    if (isCancelled?.call() ?? false) throw const StudyCancelled();
    final slots = outcome.slots;
    if (slots == null) {
      refusal = outcome.refusal;
    } else {
      final verdict = judgeStudyWords(request, slots);
      came = request.slots
          .where((s) => (slots[s.id] ?? '').trim().isNotEmpty)
          .length;
      kept = verdict.kept;
      refusedClaims = verdict.refused;
    }
  }

  final written = writeStudy(start, study, words: kept);
  return StudyResult(
    study: study,
    written: written,
    offered: offered,
    answered: came,
    kept: kept.length,
    refusedClaims: refusedClaims,
    refusal: refusal,
  );
}

/// A comment on one thing, or why there is none.
class StudyComment {
  const StudyComment.written(String this.text) : refusal = null;
  const StudyComment.refused(WordsRefusal this.refusal) : text = null;

  final String? text;
  final WordsRefusal? refusal;
}

const _untrue = WordsRefusal(
  'untrue',
  'The model wrote something the engine\'s analysis does not bear out, so '
      'the comment was thrown away. Try again.',
);

Future<StudyComment> _comment(
  StudyWordsRequest request,
  StudyWordsAsker ask,
) async {
  final outcome = await ask(request.toJson(), comment: true);
  final slots = outcome.slots;
  if (slots == null) return StudyComment.refused(outcome.refusal!);
  final verdict = judgeStudyWords(request, slots);
  if (verdict.kept.isEmpty) return const StudyComment.refused(_untrue);
  return StudyComment.written([
    for (final slot in request.slots)
      if (verdict.kept[slot.id] case final words?) words,
  ].join(' '));
}

WordsRefusal _engineRefusal(Object error) => WordsRefusal(
      'engine',
      error is StudyRefused
          ? error.reason
          : 'The engine could not analyse this position.',
    );

/// The comment on the move that led to [node] — „Generate AI comment".
Future<StudyComment> commentOnMove({
  required AnalysisNode node,
  required PositionAnalyzer analyzer,
  required int depth,
  required StudyWordsAsker ask,
  TablebaseLookup? tablebase,
  Duration searchTimeout = const Duration(seconds: 60),
}) async {
  final parent = node.parent;
  final uci = node.moveUci;
  if (parent == null || uci == null) {
    return const StudyComment.refused(
        WordsRefusal('no-move', 'There is no move here to comment on.'));
  }
  final StudyMoveFacts facts;
  try {
    facts = await PositionStudyBuilder(
      analyzer: analyzer,
      depth: depth,
      tablebase: tablebase,
      timeout: searchTimeout,
    ).moveFacts(parent.fen, uci);
  } on StudyRefused catch (e) {
    return StudyComment.refused(_engineRefusal(e));
  }
  return _comment(moveCommentRequest(facts), ask);
}

/// The comment on the position [fen] — the repertoire's „AI on position".
/// Answers the comment and the engine's first move with it.
Future<({StudyComment comment, String? bestMove})> commentOnPosition({
  required String fen,
  required PositionAnalyzer analyzer,
  required int depth,
  required StudyWordsAsker ask,
  TablebaseLookup? tablebase,
  Duration searchTimeout = const Duration(seconds: 60),
}) async {
  final PositionStudy study;
  try {
    study = await PositionStudyBuilder(
      analyzer: analyzer,
      depth: depth,
      tablebase: tablebase,
      timeout: searchTimeout,
    ).buildOverview(fen);
  } on StudyRefused catch (e) {
    return (
      comment: StudyComment.refused(_engineRefusal(e)),
      bestMove: null,
    );
  }
  return (
    comment: await _comment(positionCommentRequest(study), ask),
    bestMove: study.mainLine.first.move.san,
  );
}
