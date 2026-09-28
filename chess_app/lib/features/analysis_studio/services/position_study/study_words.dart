/// The words of a position study — `docs/PLAN-STUDIJA-POZICIJE.md`, §3.
///
/// **The engine writes the facts, the model only the words.** This file is
/// the app's half: a study becomes items, each with the lines it may name and
/// the slots it offers, every slot beside the facts it may be written from;
/// that is the request `POST /study-words` reads. What comes back is judged
/// here — **the server checks shape, the app checks truth** — by the
/// tutorial's claim check in its third mode, and by one check of the study's
/// own: a word of the positional detector's vocabulary must be in the facts.
///
/// No HTTP and no engine: a study goes in, a request and a verdict come out.
library;

import 'package:chess_app/core/services/finding_sentences.dart'
    show joinSentences;
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_board.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/evaluation_words.dart'
    show standing, wordsForEngine;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart'
    show claimsFor;

enum StudyItemKind { position, move, trap, alternative, tempting, outcome }

/// One slot: its facts, and what its words are judged against.
class StudySlot {
  const StudySlot({required this.id, required this.text, required this.check});

  /// `s.position`, `m1.move`, `t1.greedy`.
  final String id;

  /// The facts, in words, this slot may be written from.
  final String text;

  /// What `claimsFor` reads: `text`, `motifs`, `gain`, `mate`, `lines`.
  final Map<String, dynamic> check;
}

/// One thing the study has something to say about.
class StudyItem {
  const StudyItem({
    required this.id,
    required this.kind,
    required this.label,
    required this.mover,
    required this.lines,
    required this.slots,
  });

  final String id;
  final StudyItemKind kind;
  final String label;
  final String mover;

  /// The lines this item's words may name moves from, by name.
  final Map<String, List<String>> lines;
  final List<StudySlot> slots;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'label': label,
        'mover': mover,
        'lines': lines,
        'slots': [
          for (final s in slots) {'id': s.id, 'text': s.text},
        ],
      };
}

class StudyWordsRequest {
  const StudyWordsRequest({
    required this.position,
    required this.side,
    required this.items,
  });

  /// Every piece on the board, in words ([pieceList]) — never a FEN.
  final String position;
  final String side;
  final List<StudyItem> items;

  Map<String, dynamic> toJson() => {
        'position': position,
        'side': side,
        'items': [for (final i in items) i.toJson()],
      };

  Iterable<StudySlot> get slots => items.expand((i) => i.slots);
}

/// What came back, judged: the words each slot kept, and why others did not.
class StudyWordsVerdict {
  const StudyWordsVerdict({required this.kept, required this.refused});

  /// Slot id → its words.
  final Map<String, String> kept;

  /// Every reason a slot was refused, in the check's own words.
  final List<String> refused;
}

/// The request for [study]'s words.
StudyWordsRequest studyWordsRequest(PositionStudy study) {
  final side = study.side;
  final other = otherSide(side);
  final main = [for (final s in study.mainLine) s.move];
  final mainSans = [for (final m in main) m.san];
  final best = main.first;
  final bestWords = _standing(study.evaluation);
  final items = <StudyItem>[];

  // --- The position ----------------------------------------------------------
  final tb = study.tablebase;
  final threat = study.threat;
  final everyLine = <String>{
    ...mainSans,
    if (threat != null) ...threat.line.map((m) => m.san),
    for (final a in study.alternatives) ...a.line.map((m) => m.san),
    for (final t in study.tempting) ...[
      t.move.san,
      ...t.defence.map((m) => m.san),
      if (t.greedy != null) ...[
        t.greedy!.move.san,
        ...t.greedy!.punishment.map((m) => m.san),
      ],
    ],
  }.toList();

  final settles = best.capture &&
      materialWords(study.outcomeFen) != study.material &&
      study.outcomeTablebase == null;
  final positionText = joinSentences([
    '$side is to move.',
    if (settles)
      'On the board as it stands: ${study.material} That is the middle of '
          'an exchange — once the captures of the main line are made: '
          '${materialWords(study.outcomeFen)}'
    else
      study.material,
    if (tb != null)
      'The tablebase knows the result with the best play: ${tb.words(side)}.'
    else if (bestWords != null)
      'With the best play, $bestWords.',
    if (tb != null) _keepers(tb, side),
    if (study.tactical.isNotEmpty)
      'Tactics on the board: ${study.tactical.join(' ')}',
    if (study.positional.isNotEmpty)
      'The structure: ${study.positional.join(' ')}',
  ]);
  final positionMotifs = [...study.tactical, ...study.positional].join(' ');
  _atStart = positionMotifs;
  final positionSlots = <StudySlot>[
    StudySlot(
      id: 's.position',
      text: positionText,
      check: _check(positionText, positionMotifs, lines: everyLine),
    ),
  ];
  if (threat != null) {
    final text = joinSentences([
      'If $side did nothing, $other would play ${threat.move.san}: '
          '${numbered(threat.line)}.',
      if (threat.mates)
        'It mates.'
      else if (threat.wonWords != null)
        'It wins ${threat.wonWords} for $other.',
      ..._story(threat.line, other),
      if (threat.motif != null)
        'On the board after ${threat.move.san}: ${threat.motif}',
    ]);
    positionSlots.add(StudySlot(
      id: 's.threat',
      text: text,
      check: _check(
        text,
        threat.motif ?? '',
        gain: threat.won,
        mate: threat.mates,
        lines: [...threat.line.map((m) => m.san), best.san],
      ),
    ));
  }
  items.add(StudyItem(
    id: 's',
    kind: StudyItemKind.position,
    label: 'the position',
    mover: side,
    lines: {
      'main': mainSans,
      if (threat != null) 'threat': [for (final m in threat.line) m.san],
    },
    slots: positionSlots,
  ));

  // --- The main line ---------------------------------------------------------
  var moves = 0;
  var traps = 0;
  for (var i = 0; i < study.mainLine.length; i++) {
    final step = study.mainLine[i];
    final move = step.move;
    final idea = i == 0 ? study.idea : null;

    final trap = step.trap;
    if (trap != null) {
      traps++;
      items.add(_trapItem(
        'w$traps',
        StudyItemKind.trap,
        trap,
        instead: move,
        insteadWords: _standing(step.evaluation),
      ));
    }

    if (!stepGetsWords(study, i)) continue;
    moves++;
    final left =
        i + 1 < study.mainLine.length ? study.mainLine[i + 1].trap : null;

    final stepTb = step.tablebase;
    final secondWords = step.secondEvaluation == null
        ? null
        : _standing(step.secondEvaluation!);
    final text = joinSentences([
      'The move ${move.label}, by ${move.mover} '
          '(the ${move.piece} from ${move.from} to ${move.to}).',
      if (step.forced)
        'It is the only legal move.'
      else if (step.onlyMove && stepTb != null)
        'It is the only move that keeps the result.'
      else if (step.onlyMove && step.second != null && secondWords != null)
        'It is the only move: with the next best, ${step.second}, '
            '$secondWords.',
      if (move.capture) 'It captures on ${move.to}.',
      if (move.mate) 'It is checkmate.' else if (move.check) 'It gives check.',
      if (step.motif != null) 'On the board after it: ${step.motif}',
      if (idea != null) _ideaWords(idea, move),
      if (left != null && left.recapture)
        'Taking back with ${left.move.san} would be a mistake: '
            '${numbered([left.move, ...left.punishment])}.'
      else if (left != null)
        'It leaves ${left.move.san} to be played, which takes '
            '${_pieceTaken(left.move)} on ${left.move.to} — and that is a '
            'trap: ${numbered([left.move, ...left.punishment])}.',
      if (stepTb != null && stepTb.outcome == TablebaseOutcome.loss)
        'The tablebase: ${stepTb.words(move.mover)}, whatever is played '
            'here.'
      else if (stepTb != null)
        'The tablebase: ${stepTb.words(move.mover)} before the move, and '
            'this move keeps it.'
      else if (_standing(step.evaluation) case final words?)
        'With it, $words.',
    ]);
    items.add(StudyItem(
      id: 'm$moves',
      kind: StudyItemKind.move,
      label: move.label,
      mover: move.mover,
      lines: {
        'main': mainSans.sublist(i),
        if (step.second != null) 'second': [step.second!],
        if (idea != null) 'idea': [idea.move.san],
        if (left != null)
          'trap': [left.move.san, ...left.punishment.map((m) => m.san)],
      },
      slots: [
        StudySlot(
          id: 'm$moves.move',
          text: text,
          check: _check(
            text,
            '${step.motif ?? ''} ${i == 0 ? _atStart : ''}',
            gain: (idea?.won ?? 0) > move.taken ? idea!.won : move.taken,
            mate: move.mate || (idea?.mates ?? false),
            lines: [
              ...mainSans,
              if (step.second != null) step.second!,
              if (idea != null) idea.move.san,
              if (left != null) ...[
                left.move.san,
                ...left.punishment.map((m) => m.san),
              ],
            ],
          ),
        ),
      ],
    ));
  }

  // --- The alternatives ------------------------------------------------------
  for (var i = 0; i < study.alternatives.length; i++) {
    final alt = study.alternatives[i];
    final words = _standing(alt.evaluation);
    final motif = _motifOf(alt.move);
    final text = joinSentences([
      'Also possible: ${alt.move.label}, as good as ${best.san} or nearly. '
          'Its line: ${numbered(alt.line)}.',
      if (words != null) 'With it, $words.',
      if (motif != null) 'On the board after it: $motif',
    ]);
    items.add(StudyItem(
      id: 'a${i + 1}',
      kind: StudyItemKind.alternative,
      label: alt.move.label,
      mover: alt.move.mover,
      lines: {
        'line': [for (final m in alt.line) m.san],
        'best': [best.san],
      },
      slots: [
        StudySlot(
          id: 'a${i + 1}.move',
          text: text,
          check: _check(
            text,
            '${motif ?? ''} $_atStart',
            lines: [...alt.line.map((m) => m.san), best.san],
          ),
        ),
      ],
    ));
  }

  // --- The tempting moves ----------------------------------------------------
  for (var i = 0; i < study.tempting.length; i++) {
    final t = study.tempting[i];
    final id = 't${i + 1}';
    final move = t.move;
    final reply = t.defence.first;
    final words = _standing(t.evaluation);
    final greedy = t.greedy;
    final all = <String>[
      move.san,
      if (t.natural.aim != null) t.natural.aim!.san,
      ...t.defence.map((m) => m.san),
      if (greedy != null) ...[
        greedy.move.san,
        ...greedy.punishment.map((m) => m.san),
        ...greedy.declined.map((m) => m.san),
      ],
      best.san,
    ];

    final moveText = joinSentences([
      'The move ${move.label} is what the eye goes to: ${_appeal(t.natural)}.',
      if (t.lost >= kMistakeLoss)
        'It is a mistake.'
      else if (t.lost >= kStudyCloseChoice)
        'It is worse than ${best.san}.'
      else
        'It is playable, and there is a trap behind it.',
      if (words != null && bestWords != null)
        'With ${best.san}, $bestWords; after ${move.san} and the best play, '
            '$words.',
      'The best play after it: ${numbered(t.defence)}.',
      if (t.mates)
        'It ends in mate for $other.'
      else if (t.wonWords != null)
        '$other wins ${t.wonWords}.',
      ..._story(t.defence, other),
    ]);
    final replyText = joinSentences([
      'The reply ${reply.label}, by ${reply.mover} '
          '(the ${reply.piece} from ${reply.from} to ${reply.to}).',
      if (reply.capture) 'It captures on ${reply.to}.',
      if (reply.check) 'It gives check.',
      if (t.motif != null) 'On the board after it: ${t.motif}',
      if (greedy != null)
        'It leaves ${greedy.move.san} to be played, and that is a trap: '
            '${numbered([greedy.move, ...greedy.punishment])}.',
    ]);
    final slots = <StudySlot>[
      StudySlot(
        id: '$id.move',
        text: moveText,
        check:
            _check(moveText, _atStart, gain: t.won, mate: t.mates, lines: all),
      ),
      StudySlot(
        id: '$id.reply',
        text: replyText,
        check: _check(replyText, t.motif ?? '',
            gain: greedy?.won ?? t.won,
            mate: t.mates || (greedy?.mates ?? false),
            lines: all),
      ),
    ];
    if (greedy != null) {
      slots.addAll(_trapSlots(
        id,
        greedy,
        names: ('greedy', 'punish'),
        instead: t.defence.length > 1 ? t.defence[1] : null,
        insteadWords: words,
        lines: all,
      ));
    }
    items.add(StudyItem(
      id: id,
      kind: StudyItemKind.tempting,
      label: move.label,
      mover: move.mover,
      lines: {
        'defence': [move.san, ...t.defence.map((m) => m.san)],
        if (t.natural.aim != null) 'aim': [t.natural.aim!.san],
        if (greedy != null)
          'trap': [
            greedy.move.san,
            ...greedy.punishment.map((m) => m.san),
          ],
        'best': [best.san],
      },
      slots: slots,
    ));
  }

  // --- Where the main line ends ----------------------------------------------
  final last = main.last;
  final endTb = study.outcomeTablebase;
  final endWords = _standing(study.outcomeEvaluation);
  final wonBySide = wonBetween(study.fen, study.outcomeFen, side);
  final wonByOther = wonBetween(study.fen, study.outcomeFen, other);
  final outcomeText = joinSentences([
    'The main line: ${numbered(main)}.',
    if (last.mate)
      'It ends in checkmate by ${last.mover}.'
    else if (endTb != null)
      'At its end the tablebase knows the result: '
          '${endTb.words(sideToMoveIn(study.outcomeFen))}.'
    else if (endWords != null)
      'At its end, $endWords.',
    if (wonBySide.words != null)
      'Over it $side has won ${wonBySide.words}.'
    else if (wonByOther.words != null)
      'Over it $other has won ${wonByOther.words}.'
    else
      'Over it no material has changed hands for good.',
    materialWords(study.outcomeFen),
    ..._story(main, side),
  ]);
  items.add(StudyItem(
    id: 'e',
    kind: StudyItemKind.outcome,
    label: 'after ${last.label}',
    mover: side,
    lines: {'main': mainSans},
    slots: [
      StudySlot(
        id: 'e.outcome',
        text: outcomeText,
        check: _check(
          outcomeText,
          '',
          gain: wonBySide.points > 0 ? wonBySide.points : wonByOther.points,
          mate: last.mate,
          lines: mainSans,
        ),
      ),
    ],
  ));

  return StudyWordsRequest(
    position: pieceList(study.fen),
    side: side,
    items: items,
  );
}

/// Whether the main line's move [i] is offered words: the first, an only
/// move, a move that leaves a trap behind it, and a move the detectors say
/// something about unless it needs no finding — a recapture is a move on the
/// board. **The one home of that rule**: the request numbers its items by it
/// and the tree finds its slots by it.
bool stepGetsWords(PositionStudy study, int i) {
  final step = study.mainLine[i];
  final leavesTrap =
      i + 1 < study.mainLine.length && study.mainLine[i + 1].trap != null;
  return i == 0 ||
      step.onlyMove ||
      leavesTrap ||
      (!step.trivial && step.motif != null);
}

/// The request for a comment on one position: [study]'s own first item and
/// nothing else — what the repertoire's „AI on position" asks.
StudyWordsRequest positionCommentRequest(PositionStudy study) {
  final whole = studyWordsRequest(study);
  return StudyWordsRequest(
    position: whole.position,
    side: whole.side,
    items: [whole.items.firstWhere((i) => i.kind == StudyItemKind.position)],
  );
}

/// The request for a comment on one move that was played — what „Generate
/// AI comment" asks.
StudyWordsRequest moveCommentRequest(StudyMoveFacts facts) {
  final move = facts.move;
  final best = facts.best;
  final other = otherSide(move.mover);
  final words = _standing(facts.evaluation);
  final bestWords = _standing(facts.bestEvaluation);
  final tb = facts.tablebase;
  final idea = facts.idea;
  final follows = facts.follows;
  final won = follows.isEmpty
      ? (points: 0, words: null)
      : wonBetween(move.fenBefore, follows.last.fenAfter, other);
  final keeps = tb == null || tb.keeping.any((k) => k.uci == move.uci);

  final text = joinSentences([
    'The move ${move.label}, by ${move.mover} '
        '(the ${move.piece} from ${move.from} to ${move.to}).',
    if (move.capture) 'It takes ${_pieceTaken(move)} on ${move.to}.',
    if (move.mate) 'It is checkmate.' else if (move.check) 'It gives check.',
    if (tb != null && keeps)
      'The tablebase: ${tb.words(move.mover)} before the move, and this '
          'move keeps it.'
    else if (tb != null)
      'The tablebase: ${tb.words(move.mover)} before the move, and this '
          'move gives it away. ${_keepers(tb, move.mover)}'
    else if (facts.isBest && facts.onlyMove)
      'It is the engine\'s move, and the only one: every other move is '
          'clearly worse.'
    else if (facts.isBest)
      'It is the engine\'s own move.'
    else if (facts.lost >= kMistakeLoss)
      'It is a mistake: the engine plays ${best.san}.'
    else if (facts.lost >= kStudyCloseChoice)
      'It is worse than the engine\'s ${best.san}.'
    else
      'It is as good as the engine\'s ${best.san}, or nearly.',
    if (tb == null && facts.isBest && words != null) 'With it, $words.',
    if (tb == null &&
        !facts.isBest &&
        words != null &&
        bestWords != null &&
        words != bestWords)
      'With ${best.san}, $bestWords; after ${move.san}, $words.'
    else if (tb == null && !facts.isBest && words != null)
      'After it, $words.',
    if (facts.motif != null) 'On the board after it: ${facts.motif}',
    if (idea != null) _ideaWords(idea, move),
    if (!facts.isBest && follows.isNotEmpty)
      'What follows it: ${numbered(follows)}.',
    if (!facts.isBest && won.words != null) '$other wins ${won.words}.',
    if (!facts.isBest) ..._story(follows, other),
    if (facts.declined.isNotEmpty)
      'Not taking on ${follows.first.to} does not help: '
          '${numbered(facts.declined)}.',
    if (!facts.isBest)
      'The engine\'s line instead: ${numbered(facts.bestLine)}.',
  ]);
  final lines = <String>[
    move.san,
    ...follows.map((m) => m.san),
    ...facts.declined.map((m) => m.san),
    ...facts.bestLine.map((m) => m.san),
    if (idea != null) idea.move.san,
  ];
  return StudyWordsRequest(
    position: pieceList(move.fenBefore),
    side: move.mover,
    items: [
      StudyItem(
        id: 'm1',
        kind: StudyItemKind.move,
        label: move.label,
        mover: move.mover,
        lines: {
          'played': [move.san, ...follows.map((m) => m.san)],
          if (!facts.isBest) 'best': [for (final m in facts.bestLine) m.san],
          if (idea != null) 'idea': [idea.move.san],
        },
        slots: [
          StudySlot(
            id: 'm1.move',
            text: text,
            check: _check(
              text,
              facts.motif ?? '',
              gain: facts.isBest
                  ? ((idea?.won ?? 0) > move.taken ? idea!.won : move.taken)
                  : won.points,
              mate: move.mate || (idea?.mates ?? false),
              lines: lines,
            ),
          ),
        ],
      ),
    ],
  );
}

/// The words in [slots] judged against [request]: a slot is kept only when
/// neither check finds anything in it.
StudyWordsVerdict judgeStudyWords(
  StudyWordsRequest request,
  Map<String, String> slots,
) {
  final kept = <String, String>{};
  final refused = <String>[];
  for (final slot in request.slots) {
    final text = slots[slot.id]?.trim();
    if (text == null || text.isEmpty) continue;
    // „Nothing has been won" is not a claim that something was: the
    // tutorial's check reads `no` and `not`, and not these.
    final read = text.replaceAll(
        RegExp(r'\b(nothing|neither|nobody|no one|none)\b[^.,;]{0,32}',
            caseSensitive: false),
        ' ');
    final claims = [
      ...claimsFor(slot.id, read, slot.check),
      ...structureClaims(slot.id, read, slot.check),
      ...defenderClaims(slot.id, read, slot.check),
    ];
    if (claims.isEmpty) {
      kept[slot.id] = text;
    } else {
      refused.addAll(claims);
    }
  }
  return StudyWordsVerdict(kept: kept, refused: refused);
}

/// The positional detector's vocabulary, and a few words of the same kind it
/// never says: each is a claim about the board, so the facts must carry it.
const List<(String said, String shown)> kStructureWords = [
  ('isolated', 'isolated'),
  ('doubled', 'doubled'),
  ('backward', 'backward'),
  ('passed pawn', 'passed pawn'),
  ('outpost', 'outpost'),
  ('bishop pair', 'bishop pair'),
  ('two bishops', 'bishop pair'),
  ('open file', 'open'),
  ('pawn island', 'island'),
  ('pawn shield', 'pawn shield'),
  ('zugzwang', 'zugzwang'),
  ('stalemate', 'stalemate'),
  ('perpetual', 'perpetual'),
  ('exchange up', 'exchange'),
  ('wins the exchange', 'exchange'),
];

/// The words of [kStructureWords] that [text] says and [facts] do not show.
List<String> structureClaims(
    String sid, String text, Map<String, dynamic> facts) {
  final low = text.toLowerCase().replaceAll(
      RegExp(r"\b(no|not|without|never|isn't|is no longer)\b[^.,;]{0,24}"),
      ' ');
  final shown = '${facts['text'] ?? ''} ${facts['motifs'] ?? ''}'.toLowerCase();
  return [
    for (final (said, backing) in kStructureWords)
      if (low.contains(said) && !shown.contains(backing))
        '$sid says „$said", and the facts of that slot do not',
  ];
}

final _undefended =
    RegExp(r'\b(no defender|undefended|unprotected|unguarded|hanging|hangs|'
        r'en prise|loose)\b');
final _square = RegExp(r'\b[a-h][1-8]\b');

/// Whether a piece has a defender is a claim about one piece, so it is
/// checked by the square: a clause of [text] that says a piece is undefended
/// and names squares must find, for one of them, a sentence of the facts
/// that says „no defender" of that square. A clause that names no square
/// needs the facts to say it of something.
///
/// Phase 0 found this one: the facts said the pawn on d5 had no defender,
/// and the model wrote that the knight on b1 had none.
List<String> defenderClaims(
    String sid, String text, Map<String, dynamic> facts) {
  final shown = '${facts['text'] ?? ''} ${facts['motifs'] ?? ''}'.toLowerCase();
  final backing = [
    for (final sentence in shown.split(RegExp(r'(?<=[.!?])\s+')))
      if (sentence.contains('no defender') || sentence.contains('hanging'))
        {for (final m in _square.allMatches(sentence)) m.group(0)!},
  ];
  final out = <String>[];
  for (final clause
      in text.toLowerCase().split(RegExp(r'[.;!?]|, (?:and|but|so|while) '))) {
    if (!_undefended.hasMatch(clause)) continue;
    final squares = {for (final m in _square.allMatches(clause)) m.group(0)!};
    final borne = squares.isEmpty
        ? backing.isNotEmpty
        : backing.any((known) => known.intersection(squares).isNotEmpty);
    if (!borne) {
      out.add('$sid says a piece'
          '${squares.isEmpty ? '' : ' on ${(squares.toList()..sort()).join(', ')}'}'
          ' has no defender, and the facts of that slot do not');
    }
  }
  return out;
}

// --- A trap, as an item or as two slots of another ------------------------------

StudyItem _trapItem(
  String id,
  StudyItemKind kind,
  StudyTrap trap, {
  required StudyMove instead,
  required String? insteadWords,
}) {
  final lines = [
    trap.move.san,
    ...trap.punishment.map((m) => m.san),
    ...trap.declined.map((m) => m.san),
    instead.san,
  ];
  return StudyItem(
    id: id,
    kind: kind,
    label: trap.move.label,
    mover: trap.move.mover,
    lines: {
      'trap': [trap.move.san, ...trap.punishment.map((m) => m.san)],
      'best': [instead.san],
    },
    slots: _trapSlots(
      id,
      trap,
      names: ('capture', 'punish'),
      instead: instead,
      insteadWords: insteadWords,
      lines: lines,
    ),
  );
}

List<StudySlot> _trapSlots(
  String id,
  StudyTrap trap, {
  required (String, String) names,
  required StudyMove? instead,
  required String? insteadWords,
  required List<String> lines,
}) {
  final capture = trap.move;
  final punisher = otherSide(capture.mover);
  final first = trap.punishment.first;
  final words = _standing(trap.evaluation);
  final took = _pieceTaken(capture);
  final captureText = joinSentences([
    if (trap.recapture) ...[
      'The recapture ${capture.label}, by ${capture.mover}: it takes back '
          '$took on ${capture.to}, and looks automatic.',
      'It is a mistake.',
    ] else ...[
      'The capture ${capture.label}, by ${capture.mover}: it takes $took '
          'on ${capture.to}.',
      if ((standing(_harness(trap.evaluation), capture.mover) ?? 0) < 0)
        'It is a trap: it wins material and loses the position.'
      else
        'It is a mistake: it wins material and gives up more than that in '
            'position, though ${capture.mover} is not worse after it.',
    ],
    if (instead != null && insteadWords != null && insteadWords != words)
      'With ${instead.san} instead, $insteadWords.',
    if (words != null && insteadWords != words)
      'After ${capture.san}, $words.'
    else if (words != null)
      'With ${instead?.san ?? 'the best move'} $words, and after '
          '${capture.san} by more.',
    'What punishes it: ${numbered(trap.punishment)}.',
  ]);
  final punishText = joinSentences([
    'The move ${first.label}, by $punisher '
        '(the ${first.piece} from ${first.from} to ${first.to}), punishes '
        '${capture.san}.',
    if (first.capture) 'It captures on ${first.to}.',
    if (first.mate) 'It is checkmate.' else if (first.check) 'It gives check.',
    ..._story(trap.punishment, punisher),
    if (trap.declined.isNotEmpty)
      'Not taking on ${first.to} does not help: '
          '${numbered(trap.declined)} is the engine\'s own defence, and '
          'it loses as well.',
    if (trap.mates)
      'The line ends in mate for $punisher.'
    else if (trap.wonWords != null)
      'By the end of the line $punisher has won ${trap.wonWords}, counting '
          'what ${capture.san} took.',
    if (trap.motif != null) 'On the board after it: ${trap.motif}',
    if (words != null) 'After it, $words.',
  ]);
  return [
    StudySlot(
      id: '$id.${names.$1}',
      text: captureText,
      check: _check(captureText, '',
          gain: capture.taken, mate: trap.mates, lines: lines),
    ),
    StudySlot(
      id: '$id.${names.$2}',
      text: punishText,
      check: _check(punishText, trap.motif ?? '',
          gain: trap.won, mate: trap.mates, lines: lines),
    ),
  ];
}

// --- Words ---------------------------------------------------------------------

Map<String, dynamic> _check(
  String text,
  String motifs, {
  int gain = 0,
  bool mate = false,
  required List<String> lines,
}) =>
    {
      // „a win for Black" is what the tablebase's sentence says; the
      // tutorial's check looks for „winning".
      'text': text.contains('a win for ') ? '$text (winning)' : text,
      'motifs': motifs,
      'gain': gain,
      'mate': mate,
      // A promotion is named with and without what the pawn becomes: a
      // sentence says „cxb8" as readily as „cxb8=Q+".
      'lines': [
        for (final san in lines) ...[
          san,
          if (san.contains('=')) san.split('=').first,
        ],
      ],
    };

/// What is true of the start, for the checks of the items that start there —
/// set by [studyWordsRequest] as it writes the position's own slot.
String _atStart = '';

/// The app's spelling of an evaluation (`M3`, `-M2`) in the harness's
/// (`#3`, `#-2`), which `standing` reads.
String _harness(String evaluation) {
  final m = RegExp(r'^(-)?M(\d+)$').firstMatch(evaluation.trim());
  return m == null ? evaluation.trim() : '#${m.group(1) ?? ''}${m.group(2)}';
}

/// An evaluation as a clause that stands on its own: „it is about even",
/// „White is clearly better", „White mates in 3".
String? _standing(String evaluation) {
  final words = wordsForEngine(evaluation);
  return switch (words) {
    null || 'unknown' => null,
    'about even' || 'a draw' || 'checkmate' => 'it is $words',
    _ => words,
  };
}

String? _motifOf(StudyMove move) => studyMotif(move.fenBefore, move.san);

/// Moves as a book numbers them: `8. dxc6 Bxh1 9. Rxa7`, `8... Nxc6 9. f3`.
String numbered(List<StudyMove> line) {
  final out = <String>[];
  for (var i = 0; i < line.length; i++) {
    final m = line[i];
    final number = fullmoveOf(m.fenBefore);
    if (m.whiteMoved) {
      out.add('$number. ${m.san}');
    } else if (i == 0) {
      out.add('$number... ${m.san}');
    } else {
      out.add(m.san);
    }
  }
  return out.join(' ');
}

String _pieceTaken(StudyMove capture) =>
    capture.captured == null ? 'material' : 'the ${capture.captured}';

String _appeal(NaturalMove natural) {
  final move = natural.move;
  final aim = natural.aim;
  return switch (natural.kind) {
    NaturalKind.capture => 'it takes ${_pieceTaken(move)} on ${move.to}',
    NaturalKind.check => 'it gives check',
    NaturalKind.attack =>
      'it attacks ${_pieceTaken(aim!)} on ${aim.to}, and ${aim.san} is '
          'what it is played for',
  };
}

String _keepers(StudyTablebase tb, String side) {
  String list(List<({String uci, String san})> moves) =>
      moves.take(6).map((m) => m.san).join(', ');
  if (tb.outcome == TablebaseOutcome.loss) {
    return 'Nothing $side plays changes that.';
  }
  if (tb.spoiling.isEmpty) return 'Every move keeps it.';
  if (tb.keeping.length == 1) {
    return 'Only ${tb.keeping.first.san} keeps it; every other move gives '
        'it away.';
  }
  return 'The moves that keep it: ${list(tb.keeping)}. '
      'The moves that give it away: ${list(tb.spoiling)}'
      '${tb.spoiling.length > 6 ? ' and others' : ''}.';
}

String _ideaWords(StudyIdea idea, StudyMove first) {
  final what = idea.mates
      ? ', which mates'
      : idea.wonWords != null
          ? ', which wins ${idea.wonWords}'
          : '';
  if (idea.threatens && idea.inMainLine) {
    return 'It threatens ${idea.move.san}$what, and the main line goes on '
        'to play it.';
  }
  if (idea.threatens) {
    return 'It threatens ${idea.move.san}$what; the reply '
        '${idea.stoppedBy ?? ''} meets that.';
  }
  return 'It prepares ${idea.move.san}, which the main line goes on to play.';
}

/// What a line's moves do that its notation does not say: a piece given up,
/// a pawn queening. One sentence each, for [hero]'s moves only.
List<String> _story(List<StudyMove> line, String hero) {
  final out = <String>[];
  for (var i = 0; i < line.length; i++) {
    final m = line[i];
    if (m.mover != hero) continue;
    if (m.san.contains('=')) {
      final what = m.san.contains('=Q') ? 'queen' : 'piece';
      out.add(m.capture
          ? 'With ${m.san} the pawn takes the ${m.captured} on ${m.to} and '
              'becomes a $what.'
          : 'With ${m.san} the pawn reaches ${m.to} and becomes a $what.');
    }
    final next = i + 1 < line.length ? line[i + 1] : null;
    if (next != null &&
        next.capture &&
        next.to == m.to &&
        _value(m.piece) > m.taken &&
        _value(m.piece) >= 3) {
      final price = m.captured == null ? 'nothing' : 'a ${m.captured}';
      out.add('${m.san} gives up the ${m.piece} on ${m.to} for $price: '
          '${next.san} takes it.');
    }
  }
  return out;
}

int _value(String piece) => switch (piece) {
      'queen' => 9,
      'rook' => 5,
      'bishop' || 'knight' => 3,
      'pawn' => 1,
      _ => 0,
    };
