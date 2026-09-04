import 'package:chess_app/core/services/serbian_plural.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_beats.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';

/// What the tour says at one stop.
///
/// Phase 5 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`. The failure mode of a talking
/// screen is not silence, it is a voice that reads every ply — so this carries
/// two answers, not one: the sentences, and whether this stop has earned a
/// voice at all.
class WalkthroughLine {
  const WalkthroughLine({required this.parts, required this.speak});

  /// The sentences, in order.
  ///
  /// A list rather than one string because the card draws them as separate
  /// lines and the voice is handed them joined — **two renderings of one
  /// list**, which is what keeps the rule the plan asks for: the sentence
  /// spoken is the sentence on screen, and a reader who turns speech off loses
  /// nothing but the sound. Composing them twice, once for the eye and once
  /// for the ear, is how a screen grows a second narration track that drifts.
  final List<String> parts;

  /// Whether this stop is worth interrupting the reader for.
  final bool speak;

  /// What the voice is handed.
  String get spoken => parts.join(' ');
}

/// The tour's sentence, and whether it is said out loud.
///
/// [replies] are the moves out of this stop **in tour order** — the caller
/// takes them from the cursor, which derives them from the walk, so this
/// function never re-decides an order that was settled in phase 3. [note] is
/// what the student wrote about the position this move leads to.
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
WalkthroughLine walkthroughLine(
  WalkthroughStop stop, {
  List<RepertoireTreeMove> replies = const [],
  String? note,
}) {
  final move = stop.move;
  final parts = <String>[];

  switch (stop.kind) {
    case MoveTreeNodeLook.authored:
      parts.add(move.isPrimary
          ? 'Vaš potez — glavna linija.'
          : 'Vaš potez — druga mogućnost.');
      break;
    case MoveTreeNodeLook.covered:
      final share = shareLabel(move.share);
      parts.add(share == null
          ? 'Protivnik igra ${move.san}.'
          : 'Protivnik igra ${move.san} — $share partija.');
      if (move.state == 'unopened') parts.add('Odluka bez uzetih odgovora.');
      break;
    case MoveTreeNodeLook.gap:
      final share = shareLabel(move.share);
      parts.add(share == null
          ? 'Na ${move.san} nemate odgovor.'
          : 'Na ${move.san}, $share partija, nemate odgovor.');
      break;
    case MoveTreeNodeLook.refused:
      // The tour never walks into a cut branch, so this line should never be
      // read. It is here because the answer to "what does this card say" must
      // exist for all four states — a stop with no sentence at all would be a
      // blank card, which is the one outcome nobody could diagnose.
      parts.add('Ovu granu ne spremam.');
      break;
  }

  // The opponent's replies, named. A listener who cannot see the chips must
  // still learn what is coming and which of it is unanswered — that is the
  // reason this clause exists rather than „ovde ima više odgovora".
  final theirs = [
    for (final reply in replies)
      if (!reply.mine) reply,
  ];
  final fork = theirs.length > 1;
  if (fork) {
    parts.add('Odavde protivnik ima ${theirs.length} '
        '${serbianCount(theirs.length, one: "odgovor", few: "odgovora", many: "odgovora")}: '
        '${_named(theirs)}.');
  }

  if (note != null && note.trim().isNotEmpty) {
    parts.add('Vaša napomena: ${note.trim()}');
  }

  return WalkthroughLine(
    parts: parts,
    speak: fork ||
        stop.kind == MoveTreeNodeLook.gap ||
        (note != null && note.trim().isNotEmpty),
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
/// Always spoken. It is the one beat that exists purely to stop the reader
/// being lost, so saying it only when the sound happens to be on would be
/// saying it at the wrong times.
WalkthroughLine walkthroughReturn(
  WalkthroughBeat beat, {
  List<RepertoireTreeMove> replies = const [],
}) {
  final parts = <String>[];
  final done = beat.done?.san;
  final next = beat.next?.san;

  if (done != null && next != null) {
    parts.add('Videli smo liniju posle $done. Sada ide $next.');
  } else if (next != null) {
    parts.add('Sada ide $next.');
  } else {
    parts.add('Vraćamo se na račvanje.');
  }

  final theirs = [
    for (final reply in replies)
      if (!reply.mine) reply,
  ];
  if (theirs.length > 1) {
    parts.add('Odavde protivnik ima ${theirs.length} '
        '${serbianCount(theirs.length, one: "odgovor", few: "odgovora", many: "odgovora")}: '
        '${_named(theirs)}.');
  }

  return WalkthroughLine(parts: parts, speak: true);
}

/// The replies as prose: at most three, then a count for the rest.
///
/// Three because the tour's order already puts what matters first — the
/// student's own work never ranks below an empty branch — so the tail of a
/// wide fork is the part they are least likely to be listening for, and an
/// eight-item spoken list is exactly the noise this phase exists to avoid.
/// They are all on the card as chips either way; this is only what is said.
String _named(List<RepertoireTreeMove> theirs) {
  final shown = theirs.take(3).map(_reply).toList();
  final rest = theirs.length - shown.length;
  if (rest > 0) {
    shown.add('još $rest '
        '${serbianCount(rest, one: "odgovor", few: "odgovora", many: "odgovora")}');
  }
  if (shown.length == 1) return shown.first;
  return '${shown.sublist(0, shown.length - 1).join(", ")} i ${shown.last}';
}

/// One reply, said the way the card writes it.
String _reply(RepertoireTreeMove move) {
  final share = shareLabel(move.share);
  final head = share == null ? move.san : '${move.san} u $share';
  return lookOfRepertoireMove(move) == MoveTreeNodeLook.gap
      ? '$head, bez odgovora'
      : head;
}
