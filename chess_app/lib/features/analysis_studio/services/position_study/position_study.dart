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
///
/// **In the reader's language** (`docs/PLAN-JEZIK-STUDIJE.md`): with a
/// `language` the server writes the English and translates it in the same
/// request. The English is still what is judged — the check reads English
/// words — and the tree is given, for every slot the check kept, that slot's
/// translation. A slot whose translation the server refused is left out and
/// counted; **the English is never written in its place** (L3).
library;

import 'package:chess_app/core/services/game_review_judge.dart'
    show TablebaseLookup;
import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_tree.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words_client.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;
import 'package:chess_app/services/app_settings_service.dart';

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
    show
        StudyWordsAsker,
        StudyWordsOutcome,
        StudyTranslation,
        requestStudyWords;

/// The language the reader chose for a study's comments in „Study this
/// position", as a code the server takes — or null for English, which is
/// asked for as it always was. A code this build does not know is English.
String? chosenStudyLanguage() {
  final language =
      TutorialLanguage.of(AppSettingsService.instance.studyLanguage);
  if (language == null || language == TutorialLanguage.english) return null;
  return language.code;
}

/// The sentence that says a comment was written in [language] and where that
/// is chosen; null for English, which needs no saying.
String? studyLanguageNote(String? language) {
  final chosen = TutorialLanguage.of(language);
  if (chosen == null || chosen == TutorialLanguage.english) return null;
  return 'Written in ${chosen.label}, the language chosen in '
      '„Study this position".';
}

/// The request as it is sent: [request] and, for any language but English,
/// the language its words are to be translated into.
Map<String, dynamic> _sent(StudyWordsRequest request, String? language) => {
      ...request.toJson(),
      if (language != null && language != TutorialLanguage.english.code)
        'language': language,
    };

const _untranslated = WordsRefusal(
  'untranslated',
  'The server did not translate the comments, so none were written. Try '
      'again.',
);

/// The words of the [kept] slots as they go into the tree: themselves in
/// English, or each one's translation — without the ones whose translation
/// was refused. [refusal] when no translation came back at all.
({Map<String, String> words, int untranslated, WordsRefusal? refusal})
    _inLanguage(
  Map<String, String> kept,
  StudyWordsOutcome outcome,
  String? language,
) {
  if (language == null || language == TutorialLanguage.english.code) {
    return (words: kept, untranslated: 0, refusal: null);
  }
  final translated = outcome.translated;
  if (translated == null || translated.language != language) {
    return (
      words: const <String, String>{},
      untranslated: kept.length,
      refusal: _untranslated,
    );
  }
  final words = <String, String>{
    for (final id in kept.keys)
      if (translated.slots[id] case final text? when text.trim().isNotEmpty)
        id: text.trim(),
  };
  return (
    words: words,
    untranslated: kept.length - words.length,
    refusal: null,
  );
}

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
    this.language,
    this.untranslated = 0,
  });

  final PositionStudy study;
  final StudyWritten written;

  /// Slots the words were asked for; zero when no words were asked for.
  final int offered;

  /// Slots the model wrote words for; it may leave one out.
  final int answered;

  /// Slots whose words the app's check kept: [answered] less the ones it
  /// refused. In English these are the words in the tree; in another
  /// language the tree holds [kept] less [untranslated].
  final int kept;

  /// The language the comments were asked in; null for English, and when no
  /// words were asked for.
  final String? language;

  /// Slots the check kept whose translation the server refused, and which
  /// were therefore left out of the tree.
  final int untranslated;

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
  String? language,
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
  var words = const <String, String>{};
  var untranslated = 0;
  var refusedClaims = const <String>[];
  WordsRefusal? refusal;
  if (ask != null) {
    final request = studyWordsRequest(study);
    offered = request.slots.length;
    onWriting?.call();
    final outcome = await ask(_sent(request, language), comment: false);
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
      final said = _inLanguage(kept, outcome, language);
      words = said.words;
      untranslated = said.untranslated;
      refusal = said.refusal;
    }
  }

  final written = writeStudy(start, study, words: words);
  return StudyResult(
    study: study,
    written: written,
    offered: offered,
    answered: came,
    kept: kept.length,
    refusedClaims: refusedClaims,
    refusal: refusal,
    language: ask == null ? null : language,
    untranslated: untranslated,
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

const _lostInTranslation = WordsRefusal(
  'untranslated',
  'The comment could not be translated, so it was thrown away. Try again.',
);

Future<StudyComment> _comment(
  StudyWordsRequest request,
  StudyWordsAsker ask,
  String? language,
) async {
  final outcome = await ask(_sent(request, language), comment: true);
  final slots = outcome.slots;
  if (slots == null) return StudyComment.refused(outcome.refusal!);
  final verdict = judgeStudyWords(request, slots);
  if (verdict.kept.isEmpty) return const StudyComment.refused(_untrue);
  final said = _inLanguage(verdict.kept, outcome, language);
  if (said.refusal != null) return StudyComment.refused(said.refusal!);
  if (said.words.isEmpty) {
    return const StudyComment.refused(_lostInTranslation);
  }
  return StudyComment.written([
    for (final slot in request.slots)
      if (said.words[slot.id] case final words?) words,
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
  String? language,
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
  return _comment(moveCommentRequest(facts), ask, language);
}

/// The comment on the position [fen] — the repertoire's „AI on position".
/// Answers the comment and the engine's first move with it.
Future<({StudyComment comment, String? bestMove})> commentOnPosition({
  required String fen,
  required PositionAnalyzer analyzer,
  required int depth,
  required StudyWordsAsker ask,
  String? language,
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
    comment: await _comment(positionCommentRequest(study), ask, language),
    bestMove: study.mainLine.first.move.san,
  );
}
