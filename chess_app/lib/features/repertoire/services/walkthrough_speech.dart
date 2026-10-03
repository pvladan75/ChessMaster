import 'package:chess_app/core/speech/move_words.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_beats.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';

/// What the tour says at one stop.
///
/// Phase 5 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`, spoken from the shipped clips
/// since phase 4d of `docs/PLAN-GOVOR-IZ-KLIPOVA.md`. The failure mode of a
/// talking screen is not silence, it is a voice that reads every ply — so this
/// carries two answers, not one: the sentence, and whether this stop has earned
/// a voice at all.
class WalkthroughLine {
  const WalkthroughLine({required this.line, required this.speak, this.note});

  /// The stop's sentence. One list of tokens, two renderings: [text] is drawn
  /// and the same tokens are played, so the sentence heard is the sentence
  /// seen by construction — the rule the plan asks for, and the reason there is
  /// no second composition for the ear.
  final SpokenLine line;

  /// Whether this stop is worth interrupting the reader for.
  final bool speak;

  /// What the student wrote about this position. **Drawn under the line and
  /// never spoken**: it is the student's own free text, which no clip can say.
  final String? note;

  /// What is drawn.
  String get text => line.text;
}

/// The position before the move of stop [index]: the root for a first move,
/// otherwise the stop it follows. Read from the tour's own paths, never by
/// undoing a move.
String fenBeforeStop(List<WalkthroughStop> stops, int index, String rootFen) {
  final path = stops[index].path;
  if (path.length <= 1) return rootFen;
  final parent = path.sublist(0, path.length - 1);
  for (var j = index - 1; j >= 0; j--) {
    final other = stops[j].path;
    if (other.length != parent.length) continue;
    var same = true;
    for (var k = 0; k < parent.length; k++) {
      if (other[k] != parent[k]) {
        same = false;
        break;
      }
    }
    if (same) return stops[j].move.fen;
  }
  throw StateError('Stop $index has no parent stop in the tour.');
}

/// The tour's sentence, and whether it is said out loud.
///
/// [fenBefore] is the position the stop's own move is played from, and
/// [replies] are the moves out of this stop **in tour order** (played from the
/// stop's own position) — the caller takes them from the cursor, which derives
/// them from the walk, so this function never re-decides an order that was
/// settled in phase 3. [note] is what the student wrote about the position
/// this move leads to.
///
/// A stop earns a voice when it is a fork, a hole, or carries a note. An
/// ordinary move on the trunk is silent: the board moves, the card says what it
/// is, and nothing is read aloud. That is the whole anti-fatigue design, and it
/// is what makes the plan's budget — at most four spoken sentences in a
/// twelve-move trunk — hold by construction rather than by luck.
///
/// The plan's §4 also said an ordinary trunk move "gets its move announced".
/// Read literally alongside the budget those two cannot both be true — twelve
/// announcements is twelve sentences — so the announcement is the card's own
/// line and the strip's counter, and the voice keeps quiet. Said here because
/// the next person will read §4 and wonder.
///
/// A move the position does not allow is a fault in the data and throws: a
/// sentence with the move left out would be a different sentence said as if it
/// were this one.
WalkthroughLine walkthroughLine(
  WalkthroughStop stop, {
  required String fenBefore,
  List<RepertoireTreeMove> replies = const [],
  String? note,
}) {
  final move = stop.move;
  final tokens = <SpeechToken>[];

  switch (stop.kind) {
    case MoveTreeNodeLook.authored:
      tokens.add(move.isPrimary
          ? SpeechVocabulary.yourMoveMainLine
          : SpeechVocabulary.yourMoveAlternative);
      break;
    case MoveTreeNodeLook.covered:
      tokens.addAll(_moveAndShare(fenBefore, move));
      break;
    case MoveTreeNodeLook.gap:
      tokens.addAll(_moveAndShare(fenBefore, move));
      tokens.add(SpeechVocabulary.noReplyHere);
      break;
    case MoveTreeNodeLook.refused:
      // No repertoire card is drawn this way any more — the cut is gone — but
      // the look belongs to the tree widget, and a stop with no sentence would
      // be a blank card nobody could diagnose.
      break;
  }

  final fork = _forkClause(move.fen, replies);
  tokens.addAll(fork);

  final trimmed = note?.trim();
  final hasNote = trimmed != null && trimmed.isNotEmpty;
  if (hasNote) tokens.add(SpeechVocabulary.leftNote);

  return WalkthroughLine(
    line: SpokenLine(tokens),
    speak: fork.isNotEmpty || stop.kind == MoveTreeNodeLook.gap || hasNote,
    note: hasNote ? trimmed : null,
  );
}

/// What the tour says when it comes back to a fork before taking another line.
///
/// The owner's own words for what was missing: „kad prodje prva linija, pa
/// treba da se pokaže druga iz iste pozicije, bilo bi dobro da se opet vratimo
/// na poziciju iz koje se račva". So the sentence names both halves — the line
/// just finished and the one about to start — because „we are back at a fork"
/// on its own does not tell a reader *which* fork out of the several they have
/// walked through.
///
/// [forkFen] is the fork's own position, which both named moves are played
/// from. Always spoken. It is the one beat that exists purely to stop the
/// reader being lost, so saying it only when the sound happens to be on would
/// be saying it at the wrong times.
WalkthroughLine walkthroughReturn(
  WalkthroughBeat beat, {
  required String forkFen,
  List<RepertoireTreeMove> replies = const [],
}) {
  final tokens = <SpeechToken>[];
  final done = beat.done;
  final next = beat.next;

  if (done != null && next != null) {
    tokens
      ..add(SpeechVocabulary.weSawLineAfter)
      ..addAll(MoveWords.bare(_facts(forkFen, done)))
      ..add(SpeechVocabulary.nowComes)
      ..addAll(MoveWords.bare(_facts(forkFen, next)));
  } else if (next != null) {
    tokens
      ..add(SpeechVocabulary.nowComes)
      ..addAll(MoveWords.bare(_facts(forkFen, next)));
  } else {
    tokens.add(SpeechVocabulary.backToFork);
  }

  tokens.addAll(_forkClause(forkFen, replies));
  return WalkthroughLine(line: SpokenLine(tokens), speak: true);
}

/// The facts of [move] played from [fen].
MoveFacts _facts(String fen, RepertoireTreeMove move) {
  final uci = move.uci;
  final facts = uci.length < 4
      ? null
      : MoveWords.factsOf(
          fen,
          uci.substring(0, 2),
          uci.substring(2, 4),
          promotion: uci.length > 4 ? uci.substring(4, 5) : null,
        );
  if (facts == null) {
    throw StateError('The tour cannot say ${move.san} ($uci) from $fen.');
  }
  return facts;
}

/// The share as „in 42 of 100 games", or nothing when the move has none.
/// Under one in a hundred it is said as such rather than as „0". [head] is the
/// opening „In" of a sentence of its own; without it the share follows a move
/// inside the same sentence.
List<SpeechToken> _share(double share, {required bool head}) {
  final percent = share * 100;
  if (percent <= 0) return const [];
  if (percent < 1) return [SpeechVocabulary.lessThanOneIn100];
  return [
    head ? SpeechVocabulary.inHead : SpeechVocabulary.inGames,
    SpeechVocabulary.numberInside(percent.round().clamp(1, 100)),
    SpeechVocabulary.of100Games,
  ];
}

List<SpeechToken> _moveAndShare(String fenBefore, RepertoireTreeMove move) => [
      ...MoveWords.line(_facts(fenBefore, move)).tokens,
      ..._share(move.share, head: true),
    ];

/// The opponent's replies, named, or nothing when there is no fork. A listener
/// who cannot see the chips must still learn what is coming and which of it is
/// unanswered — that is the reason this clause exists rather than „ovde ima
/// više odgovora".
///
/// At most three are named, then a count for the rest. Three because the
/// tour's order already puts what matters first — the student's own work never
/// ranks below an empty branch — so the tail of a wide fork is the part they
/// are least likely to be listening for, and an eight-item spoken list is
/// exactly the noise this phase exists to avoid. They are all on the card as
/// chips either way; this is only what is said.
///
/// A reply that has no share is named alone, and two such replies in a row run
/// together as one sentence: the table has no token to close the first.
List<SpeechToken> _forkClause(String fen, List<RepertoireTreeMove> replies) {
  final theirs = [
    for (final reply in replies)
      if (!reply.mine) reply,
  ];
  if (theirs.length < 2) return const [];

  final tokens = <SpeechToken>[
    SpeechVocabulary.opponentHasReplies,
    SpeechVocabulary.numberInside(theirs.length),
    SpeechVocabulary.repliesTail,
  ];
  for (final reply in theirs.take(3)) {
    tokens.addAll(MoveWords.bare(_facts(fen, reply)));
    tokens.addAll(_share(reply.share, head: false));
    if (lookOfRepertoireMove(reply) == MoveTreeNodeLook.gap) {
      tokens.add(SpeechVocabulary.noReply);
    }
  }
  final rest = theirs.length - 3;
  if (rest == 1) {
    tokens.add(SpeechVocabulary.oneMoreReply);
  } else if (rest >= 2) {
    tokens
      ..add(SpeechVocabulary.andHead)
      ..add(SpeechVocabulary.numberInside(rest))
      ..add(SpeechVocabulary.moreRepliesTail);
  }
  return tokens;
}
