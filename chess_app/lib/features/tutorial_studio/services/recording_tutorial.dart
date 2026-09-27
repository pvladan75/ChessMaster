/// A recording becomes a tutorial — phase 8 of `docs/PLAN-PRIPREMA.md`.
///
/// **The pure core, and the only place the rules R1–R8 of that plan are
/// written in the app.** A lesson recorded in Preparation is a timeline (what
/// stood on the board, and when) and a transcript (what was said, and when);
/// this turns the two into an ordinary tutorial and says where in the
/// recording's sound each of its beats begins. Nothing here touches a screen,
/// the network or a file.
///
/// The rules were measured on the owner's own recordings before a line of
/// this was written (phase 5, `tools/stt_measure/beats.js`, which is the
/// sketch this follows and not a second home: it is a measurement tool and
/// nothing loads it). In short:
///
///   * R1 — text is cut at sentences, and inside a sentence only where the
///     board changed while it was being said (phase 8b, the owner's word of
///     27.9.2026): at the start of the clause being said, or at the word
///     itself where that clause began more than [cutMaxEarlyMs] before;
///   * R2 — the board's timeline is positions, each with the stretches of
///     marks that stood on it; the marks are what the latest event said,
///     whatever its kind (the player's and the film's rule, `replayFrameAt`);
///   * R3 — a sentence, or the piece of one, belongs to the position standing
///     when it **ends** (D15): a trainer names a move and then plays it;
///   * R4 — on one position a new beat begins where the marks at the end of
///     what was said differ from those at the end of what was said before
///     it, or where the caption would pass its four lines;
///   * R5 — a move nobody spoke over is still a beat, wordless, because the
///     line has to be seen; a position merely passed through on the way to a
///     jump is not;
///   * R6 — a part ends where the board jumps: where the next position is not
///     one legal move from the one before, or a new board was set;
///   * R7 — a move is derived from the two positions around it, never read
///     from the event;
///   * R8 — no clock is carried into the tutorial. The markers are the
///     trainer's own voice's and live beside the draft, never in it.
///
/// **Every part is read back before anything is kept** (the rule of
/// 6.9.2026): the draft is written as the server would store it, read again
/// through [TutorialSection.fromStep] — [readStepTree], the child's own
/// parser — and walked as a film. The draft handed back *is* that reading, and
/// a reading that disagrees with what was built is a refusal, not a repair.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/models/recording_transcript.dart';
import 'package:chess_app/move_tree.dart';

/// A caption's room: four lines of about 42 letters (R4). Phase 5 measured
/// the longest caption the rules made on the owner's recordings at 160.
const int captionRoomLetters = 4 * 42;

/// How far back a cut may go to reach the start of the clause being said
/// (R1). Measured on the owner's five recordings, 27.9.2026: with whole
/// sentences a mark was on screen a median 6.7 s before it was drawn and up to
/// 15.3 s; with this, 1.4 s and at most 5.9 s, and no mark is dropped.
const int cutMaxEarlyMs = 6000;

/// The shortest piece a cut may leave in front of it (R1): marks drawn a word
/// apart are one picture, not a caption that flashes.
const int cutMinPieceMs = 1000;

/// A tutorial made from a recording, and the recording's voice laid over it.
class RecordingTutorial {
  const RecordingTutorial({
    required this.draft,
    required this.markersMs,
    required this.signature,
    required this.wordlessBeats,
  });

  /// The tutorial, **as read back** — what the server will be sent and what
  /// the studio will open. It carries no time from the recording.
  final TutorialDraft draft;

  /// Where each beat of [draft]'s film begins in the recording's sound, one
  /// per stop of `filmBeatsOf(draft)`, the first at 0 and each after it later
  /// than the one before.
  final List<int> markersMs;

  /// `filmPositionsSignatureOf` over [draft]'s film: what the copied voice is
  /// held to (D18).
  final String signature;

  /// How many beats have no sentence (R5).
  final int wordlessBeats;

  int get beats => markersMs.length;
}

/// Why a recording could not become a tutorial. A sentence a trainer can read.
class RecordingTutorialRefused implements Exception {
  const RecordingTutorialRefused(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

/// Makes a tutorial of a recording.
///
/// [events] is the recording's timeline and [durationMs] the length of its
/// sound; [sentences] its transcript, empty when it has none — the tutorial
/// then has its moves and its marks, every beat wordless, and the trainer's
/// voice still lies under it.
///
/// Throws [RecordingTutorialRefused] with the reason when it cannot.
RecordingTutorial recordingTutorialOf({
  required List<TimelineEvent> events,
  required int durationMs,
  required List<TranscriptSentence> sentences,
  String title = '',
  String? language,
}) {
  if (durationMs <= 0) {
    throw const RecordingTutorialRefused(
        'This recording has no sound to make a tutorial of.');
  }
  final positions = _positionsOf(events, durationMs);
  if (positions.isEmpty) {
    throw const RecordingTutorialRefused(
        'This recording has no board to make a tutorial of.');
  }

  final beats = _beatsOf(positions, _saidOf(sentences, _changesOf(positions)));
  final parts = _partsOf(beats, positions);
  final turns = _turnsOf(events);

  final built = TutorialDraft(
    title: title,
    language: language,
    sections: [
      for (final part in parts)
        _sectionOf(part, positions,
            black: _blackFor(turns, positions[part.first.position].aroseMs,
                positions[part.last.position].endMs)),
    ],
  );

  // Read back as the server will store it, and walked as the film will be.
  final readBack = TutorialDraft.fromLesson({
    'title': title,
    'language': language,
    'position_list': built.positionList,
  });
  for (var i = 0; i < readBack.sections.length; i++) {
    if (readBack.sections[i].rejectedMoves > 0) {
      throw RecordingTutorialRefused('Part ${i + 1} could not be read back: '
          '${readBack.sections[i].rejectedMoves} of its moves do not replay.');
    }
  }
  final stops = filmBeatsOf(readBack);
  final expected = [for (final part in parts) ...part];
  if (stops.length != expected.length) {
    throw RecordingTutorialRefused(
        'The tutorial read back with ${stops.length} beats where '
        '${expected.length} were made.');
  }
  for (var i = 0; i < stops.length; i++) {
    final made = expected[i];
    final read = stops[i];
    final fen = positions[made.position].fen;
    if (!MoveTree.samePosition(read.beat.node.fen, fen) ||
        read.caption != made.caption ||
        _marksKey(read.beat.say.arrows, read.beat.say.squares) !=
            _marksKey(made.marks.arrows, made.marks.squares)) {
      throw RecordingTutorialRefused(
          'Beat ${i + 1} of the tutorial did not read back as it was made.');
    }
  }

  return RecordingTutorial(
    draft: readBack,
    markersMs: _markersOf(expected, positions, durationMs),
    signature: filmPositionsSignatureOf(stops),
    wordlessBeats: expected.where((b) => b.said.isEmpty).length,
  );
}

// ------------------------------------------------------------------ board

class _Marks {
  const _Marks(this.arrows, this.squares);
  final List<ChessArrow> arrows;
  final List<SquareMark> squares;
}

class _Stretch {
  _Stretch(this.startMs, this.marks);
  final int startMs;
  final _Marks marks;
}

class _Position {
  _Position({
    required this.fen,
    required this.aroseMs,
    required this.newBoard,
  });

  final String fen;
  final int aroseMs;

  /// Set on the board rather than moved to — an `init`, a position loaded.
  final bool newBoard;

  final List<_Stretch> stretches = [];
  late int endMs;

  /// The move that arrived here from the position before, when one legal
  /// move does (R7) — `san`, `uci` and the position it makes, as the app's
  /// own board makes it.
  ({String san, String uci, String fen})? move;

  /// Whether the board jumped to get here (R6).
  bool jump = false;

  /// Whether it was only passed through on the way to a jump (R5).
  bool passedThrough = false;

  _Marks marksAt(int ms) {
    var found = stretches.first.marks;
    for (final s in stretches) {
      if (s.startMs <= ms) found = s.marks;
    }
    return found;
  }
}

/// The kinds that put a position on the board — the player's list
/// (`replayFrameAt`). Only `move` can be a move; the rest set a board.
const _positionKinds = {'init', 'move', 'fen_change', 'lesson_loaded'};

/// R2. The timeline as positions, each with its stretches of marks.
List<_Position> _positionsOf(List<TimelineEvent> events, int durationMs) {
  final positions = <_Position>[];
  for (final event in events) {
    final isPosition = _positionKinds.contains(event.eventType);
    if (!isPosition && event.eventType != 'arrow_drawn') continue;
    final marks = _marksOf(event.data);
    final fen = event.data['fen'];
    if (isPosition && fen is String && fen.trim().isNotEmpty) {
      positions.add(_Position(
        fen: fen,
        aroseMs: event.timestampMs,
        newBoard: event.eventType != 'move',
      )..stretches.add(_Stretch(event.timestampMs, marks)));
    } else if (positions.isNotEmpty) {
      // Marks on the position standing — and a position event with no
      // position in it is still an event that names marks.
      positions.last.stretches.add(_Stretch(event.timestampMs, marks));
    }
  }
  for (var i = 0; i < positions.length; i++) {
    final p = positions[i];
    p.endMs = i + 1 < positions.length
        ? positions[i + 1].aroseMs
        : (durationMs > p.aroseMs ? durationMs : p.aroseMs + 1);
    if (i == 0) continue;
    p.move = p.newBoard ? null : _moveBetween(positions[i - 1].fen, p.fen);
    p.jump = p.move == null;
  }
  return positions;
}

_Marks _marksOf(Map<String, dynamic> data) {
  final arrows = data['arrows'];
  final squares = data['squares'];
  return _Marks(
    [
      if (arrows is List)
        for (final a in arrows)
          if (a is Map && a['from'] is String && a['to'] is String)
            ChessArrow(
              from: a['from'] as String,
              to: a['to'] as String,
              colorCode: '${a['color'] ?? a['colorCode'] ?? 'G'}',
            ),
    ],
    [
      if (squares is List)
        for (final s in squares)
          if (s is Map && s['square'] is String)
            SquareMark(
              square: s['square'] as String,
              colorCode: '${s['color'] ?? s['colorCode'] ?? 'G'}',
            ),
    ],
  );
}

/// Every time the board was turned: from when, and whether Black was then at
/// the bottom. White until the first turn.
List<(int, bool)> _turnsOf(List<TimelineEvent> events) => [
      (0, false),
      for (final event in events)
        if (event.eventType == 'orientation_changed' &&
            event.data['orientation'] is String)
          (event.timestampMs, event.data['orientation'] == 'black'),
    ];

/// Which way round a part stands: **the way the board stood for most of it.**
/// A trainer turns the board to talk about a position from the other side,
/// usually a moment after it is set up — so the side at the part's first
/// instant is the one the trainer was about to leave.
bool _blackFor(List<(int, bool)> turns, int fromMs, int toMs) {
  var blackMs = 0;
  var whiteMs = 0;
  for (var i = 0; i < turns.length; i++) {
    final start = _max(turns[i].$1, fromMs);
    final end = i + 1 < turns.length ? turns[i + 1].$1 : toMs;
    final stood = (end < toMs ? end : toMs) - start;
    if (stood <= 0) continue;
    if (turns[i].$2) {
      blackMs += stood;
    } else {
      whiteMs += stood;
    }
  }
  return blackMs > whiteMs;
}

String _marksKey(List<ChessArrow> arrows, List<SquareMark> squares) {
  final a = [for (final x in arrows) '${x.colorCode}${x.from}${x.to}']..sort();
  final s = [for (final x in squares) '${x.colorCode}${x.square}']..sort();
  return '${a.join(',')}|${s.join(',')}';
}

String _placementAndSide(String fen) =>
    fen.trim().split(RegExp(r'\s+')).take(2).join(' ');

/// R7. The one legal move from [from] that makes [to], or null — a jump.
({String san, String uci, String fen})? _moveBetween(String from, String to) {
  final chess.Chess game;
  try {
    game = chess.Chess.fromFEN(from);
  } catch (_) {
    return null;
  }
  final target = _placementAndSide(to);
  for (final move in legalMoves(game)) {
    if (!playMove(game, move)) continue;
    final reached = game.fen;
    game.undo();
    if (_placementAndSide(reached) == target) {
      return (
        san: '${move['san']}',
        uci: '${move['from']}${move['to']}${move['promotion']}',
        fen: reached,
      );
    }
  }
  return null;
}

// ------------------------------------------------------------------- said

/// A moment the board changed: a position arising, or marks that differ from
/// the ones standing before them.
class _Change {
  const _Change(this.ms, {required this.board, required this.bare});
  final int ms;

  /// A position arose — a move, a jump, a board set.
  final bool board;

  /// Marks were taken off and none put on.
  final bool bare;
}

List<_Change> _changesOf(List<_Position> positions) {
  final changes = <_Change>[];
  for (var i = 0; i < positions.length; i++) {
    final stretches = positions[i].stretches;
    for (var j = 0; j < stretches.length; j++) {
      final marks = stretches[j].marks;
      final bare = marks.arrows.isEmpty && marks.squares.isEmpty;
      if (j == 0) {
        if (i > 0) {
          changes.add(_Change(stretches[j].startMs, board: true, bare: bare));
        }
        continue;
      }
      final before = stretches[j - 1].marks;
      if (_marksKey(marks.arrows, marks.squares) !=
          _marksKey(before.arrows, before.squares)) {
        changes.add(_Change(stretches[j].startMs, board: false, bare: bare));
      }
    }
  }
  return changes;
}

/// What was said in one breath of the board: a sentence, or the piece of one
/// between two cuts.
class _Said {
  const _Said(this.text, this.startMs, this.endMs);
  final String text;
  final int startMs;
  final int endMs;
}

/// R1. Everything said, in order, cut where the rule cuts.
List<_Said> _saidOf(
        List<TranscriptSentence> transcript, List<_Change> changes) =>
    [
      for (final s in transcript)
        // A sentence emptied by the trainer is one the vendor invented over
        // silence (phase 7): it has nothing to say, so it stands on no beat.
        if (s.text.trim().isNotEmpty) ..._piecesOf(s, changes),
    ];

final _space = RegExp(r'\s+');
final _notLetters = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final _endsClause = RegExp(r'[,;:]$');

String _bare(String word) => word.toLowerCase().replaceAll(_notLetters, '');

/// The words of [s] **as they stand**, each with the time it was said.
///
/// The server sends the words as heard. Where the trainer corrected the
/// sentence, the words that were left alone keep their times and hold the
/// rest in place: between two of them, as many new words as old ones take
/// the old ones' times one for one, and any other number shares the stretch
/// evenly. A correction changes text and never a time (phase 7), so this is
/// the only place a corrected word gets one.
///
/// Empty when the sentence came without its words.
List<TranscriptWord> _wordsOf(TranscriptSentence s) {
  final heard = s.words;
  if (heard.isEmpty) return const [];
  final tokens = [
    for (final t in s.text.trim().split(_space))
      if (t.isNotEmpty) t
  ];
  if (tokens.isEmpty) return const [];

  // The longest run of words the two share, in order.
  final a = [for (final w in heard) _bare(w.text)];
  final b = [for (final t in tokens) _bare(t)];
  final longest =
      List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      longest[i][j] = a[i].isNotEmpty && a[i] == b[j]
          ? longest[i + 1][j + 1] + 1
          : (longest[i + 1][j] >= longest[i][j + 1]
              ? longest[i + 1][j]
              : longest[i][j + 1]);
    }
  }

  final timed = <TranscriptWord>[];
  // What stands between two words that were left alone.
  void between(int fromHeard, int toHeard, int fromToken, int toToken) {
    final count = toToken - fromToken;
    if (count == 0) return;
    if (count == toHeard - fromHeard) {
      for (var k = 0; k < count; k++) {
        timed.add(TranscriptWord(
            text: tokens[fromToken + k],
            startMs: heard[fromHeard + k].startMs,
            endMs: heard[fromHeard + k].endMs));
      }
      return;
    }
    final from = toHeard > fromHeard
        ? heard[fromHeard].startMs
        : (fromHeard > 0 ? heard[fromHeard - 1].endMs : s.startMs);
    var to = toHeard > fromHeard
        ? heard[toHeard - 1].endMs
        : (toHeard < heard.length ? heard[toHeard].startMs : s.endMs);
    if (to < from) to = from;
    for (var k = 0; k < count; k++) {
      timed.add(TranscriptWord(
          text: tokens[fromToken + k],
          startMs: from + (to - from) * k ~/ count,
          endMs: from + (to - from) * (k + 1) ~/ count));
    }
  }

  var i = 0;
  var j = 0;
  var heldHeard = 0;
  var heldToken = 0;
  while (i < a.length && j < b.length) {
    if (a[i].isNotEmpty && a[i] == b[j]) {
      between(heldHeard, i, heldToken, j);
      timed.add(TranscriptWord(
          text: tokens[j], startMs: heard[i].startMs, endMs: heard[i].endMs));
      i++;
      j++;
      heldHeard = i;
      heldToken = j;
    } else if (longest[i + 1][j] >= longest[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  between(heldHeard, a.length, heldToken, b.length);
  return timed;
}

/// R1. [s] whole, or cut where the board changed while it was being said.
///
/// For each change, in order: the cut goes to the start of the clause being
/// said — after a comma, a semicolon or a colon, or where the piece that is
/// open began — when that is no more than [cutMaxEarlyMs] before the change,
/// and to the word being said otherwise. A cut that would leave less than
/// [cutMinPieceMs] in front of it is not made, and the change joins the piece
/// that is open.
///
/// **A move never takes the piece in which something was drawn before it.**
/// A piece belongs to the position standing when it ends (R3), so a clause
/// that holds an arrow and then the move would go to the new position and the
/// arrow to no beat at all; there the cut is at the move's own word. Marks
/// that arrive with a position — a jump to a move that holds an arrow — are
/// kept for as marks drawn by hand are.
List<_Said> _piecesOf(TranscriptSentence s, List<_Change> changes) {
  final whole = [_Said(s.text, s.startMs, s.endMs)];
  final words = _wordsOf(s);
  if (words.length < 2) return whole;

  final cuts = <({int word, int changeMs})>[];
  var open = 0;
  int? drawnAt;
  for (final change in changes) {
    // A change before the sentence falls in none of its words and cuts
    // nothing; one after it would fall in its last.
    if (change.ms >= s.endMs) continue;
    var said = 0;
    for (var i = 0; i < words.length; i++) {
      if (words[i].startMs <= change.ms) said = i;
    }
    var at = open;
    if (said > open) {
      var clause = open;
      for (var i = open + 1; i <= said; i++) {
        if (_endsClause.hasMatch(words[i - 1].text)) clause = i;
      }
      at = change.ms - words[clause].startMs <= cutMaxEarlyMs ? clause : said;
      final drawn = drawnAt;
      var keeps = false;
      if (change.board && drawn != null && words[at].startMs <= drawn) {
        at = said;
        keeps = words[at].startMs > drawn;
      }
      if (!keeps && words[at].startMs - words[open].startMs < cutMinPieceMs) {
        at = open;
      }
    }
    if (at > open) {
      cuts.add((word: at, changeMs: change.ms));
      open = at;
    }
    drawnAt = change.bare ? null : change.ms;
  }
  if (cuts.isEmpty) return whole;

  final pieces = <_Said>[];
  var from = 0;
  for (var k = 0; k <= cuts.length; k++) {
    final last = k == cuts.length;
    final to = last ? words.length : cuts[k].word;
    final mine = words.sublist(from, to);
    final startMs = k == 0 ? s.startMs : mine.first.startMs;
    // A piece ends before the change its cut was made for, so that change is
    // the next piece's and never this one's.
    var endMs = last
        ? s.endMs
        : (mine.last.endMs < cuts[k].changeMs
            ? mine.last.endMs
            : cuts[k].changeMs - 1);
    if (endMs < startMs) endMs = startMs;
    pieces.add(_Said(mine.map((w) => w.text).join(' '), startMs, endMs));
    from = to;
  }
  return pieces;
}

// ------------------------------------------------------------------ beats

class _Beat {
  _Beat({required this.position, required this.marks, required this.startMs});

  final int position;
  _Marks marks;

  /// Where the first thing said on the beat begins; where its position arose
  /// when it has none.
  final int startMs;
  final List<_Said> said = [];

  /// What the film writes under the board. Braces would close the PGN
  /// comment the sentence is kept in, and the reader gives a comment back
  /// with its spaces and line breaks as single spaces — so a corrected
  /// sentence with a line break in it is written the way it will be read.
  String get caption => said
      .map((s) => s.text.trim())
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('{', '(')
      .replaceAll('}', ')');
}

/// R3, R4 and R5, over what was said as R1 cut it.
List<_Beat> _beatsOf(List<_Position> positions, List<_Said> spoken) {
  // R3 — the position standing when the sentence ends. A move played at the
  // sentence's last millisecond has been played by then.
  final byPosition = List.generate(positions.length, (_) => <_Said>[]);
  for (final s in spoken) {
    var at = 0;
    for (var i = 0; i < positions.length; i++) {
      if (positions[i].aroseMs <= s.endMs) at = i;
    }
    byPosition[at].add(s);
  }

  final beats = <_Beat>[];
  for (var i = 0; i < positions.length; i++) {
    final p = positions[i];
    final mine = byPosition[i];
    if (mine.isEmpty) {
      // R5 — seen, unless the board left it by a jump.
      final next = i + 1 < positions.length ? positions[i + 1] : null;
      p.passedThrough = next != null && next.jump;
      if (!p.passedThrough) {
        beats.add(_Beat(
            position: i, marks: p.marksAt(p.endMs - 1), startMs: p.aroseMs));
      }
      continue;
    }
    _Beat? open;
    for (final s in mine) {
      final marks = p.marksAt(s.endMs < p.endMs ? s.endMs : p.endMs - 1);
      final letters =
          open == null ? 0 : open.caption.length + 1 + s.text.trim().length;
      if (open != null &&
          _marksKey(open.marks.arrows, open.marks.squares) ==
              _marksKey(marks.arrows, marks.squares) &&
          letters <= captionRoomLetters) {
        open.said.add(s);
        open.marks = marks;
      } else {
        open = _Beat(position: i, marks: marks, startMs: s.startMs)
          ..said.add(s);
        beats.add(open);
      }
    }
  }
  return beats;
}

/// R6. Beats run together into parts; a part ends where the board jumps.
///
/// Only the beat's own position is asked. The positions a beat can skip over
/// are the ones passed through, and a position is passed through only when
/// the next one is a jump — so after a skip the beat's own position always
/// jumped, and three quick presses of ← are one part and not three. (A loop
/// over the skipped positions was written first and could not change a
/// single answer; the mutation that removed it survived every case.)
List<List<_Beat>> _partsOf(List<_Beat> beats, List<_Position> positions) {
  final parts = <List<_Beat>>[];
  for (final beat in beats) {
    if (parts.isEmpty) {
      parts.add([beat]);
      continue;
    }
    final samePosition = parts.last.last.position == beat.position;
    if (!samePosition && positions[beat.position].jump) {
      parts.add([beat]);
    } else {
      parts.last.add(beat);
    }
  }
  return parts;
}

// ------------------------------------------------------------------ draft

TutorialSection _sectionOf(List<_Beat> part, List<_Position> positions,
    {required bool black}) {
  final first = positions[part.first.position];
  final root = AnalysisNode(fen: first.fen);
  var node = root;
  var at = part.first.position;
  var fresh = true;
  for (final beat in part) {
    if (beat.position != at) {
      // Within a part the positions follow one another by legal moves
      // (R6), so the node for the next one is its move from this one.
      final move = positions[beat.position].move!;
      final child = AnalysisNode(
        fen: move.fen,
        moveSan: move.san,
        moveUci: move.uci,
        parent: node,
      );
      node.children.add(child);
      node = child;
      at = beat.position;
      fresh = true;
    }
    final said = NodeBeat(
      comment: beat.caption,
      arrows: [...beat.marks.arrows],
      squares: [...beat.marks.squares],
    );
    if (fresh) {
      node.beats
        ..clear()
        ..add(said);
      fresh = false;
    } else {
      node.beats.add(said);
    }
  }
  return TutorialSection(root: root, blackOrientation: black);
}

// ---------------------------------------------------------------- markers

/// R8, with the trainer's own voice: a beat begins where its first sentence
/// does — so an arrow drawn or a move played in mid-sentence is on screen
/// from that sentence's start (D5) — and a wordless beat where its position
/// arose.
///
/// **Where those disagree, the board wins.** A trainer who plays three moves
/// inside one sentence gives that sentence to the last of the three (R3),
/// whose sentence then starts before the two wordless beats in front of it.
/// Moving the sentence's beat to the moment its own position arose keeps the
/// moves on screen when they were played and the voice on them; the only
/// thing late is the caption, by the length of the moves.
///
/// The film opens on the first beat at the sound's first sample, and a beat
/// never starts at or after its end.
List<int> _markersOf(
    List<_Beat> beats, List<_Position> positions, int durationMs) {
  final markers = List<int>.filled(beats.length, 0);
  for (var i = 1; i < beats.length; i++) {
    final raw = beats[i].startMs;
    markers[i] = raw > markers[i - 1]
        ? raw
        : _max(positions[beats[i].position].aroseMs, markers[i - 1] + 1);
  }
  // Nothing at or past the end of the sound.
  for (var i = beats.length - 1; i >= 1; i--) {
    final ceiling = i == beats.length - 1 ? durationMs - 1 : markers[i + 1] - 1;
    if (markers[i] > ceiling) markers[i] = ceiling;
  }
  for (var i = 1; i < markers.length; i++) {
    if (markers[i] <= markers[i - 1]) {
      throw RecordingTutorialRefused(
          'This recording is too short for its ${beats.length} beats.');
    }
  }
  return markers;
}

int _max(int a, int b) => a > b ? a : b;
