"""Arm H: Python and Stockfish build the tutorial, the model writes the words.

    python run_api.py H --provider deepseek --model deepseek-flash --reasoning-effort low
    python skeleton.py pvladan_2026-09-12            # print the prompt, call nothing

The owner's design of 13.9.2026. Every earlier arm let a model decide something
a program can decide exactly, and every error of the day lived in one of those
decisions: a FEN rebuilt in its head, a move copied a letter wrong, a question
on a position with four equal answers, a „better move" that was fourth. So here
the program decides all of that from the facts `make_facts.py` computed:

 * **candidate moments** - since phase 1b of docs/PLAN-ZAGONETKE-IZ-PARTIJE.md
   the moves the app's review judge called mistakes, worst first by winning
   chances lost, then the only moves the player found, at most `max_moments`
   of them (the verdicts are in the facts, `played.judged`, written by
   `chess_app/tool/judge_facts.dart`; until 1b, a cost of `min_cost` pawns);
 * for each, **a block of parts**: the last `lead_plies` moves of the game
   leading into it, and the answer as the best line from the facts;
 * every FEN, every move in the board's own SAN, every answer.

The model is left with the one decision it did well - which moments teach a
student the most - and the words: it chooses two or three moments by id and fills
the empty slots of those, each slot shown with the facts it may speak from.

**A tutorial is material for a film, and asks nothing** (the owner's word of
25.9.2026, `docs/PLAN-TUTORIJAL-VIDEO.md`): no moment offers a question, and no
slot is a question's answer. `correct` - the candidates as good as the best -
is still computed, because the alternative („other") part uses its length to
find the next move that is clearly worse, but it never leaves this file.

**The parameters are applied here, never stored in the facts.** A facts file is
engine output and the judge's verdicts on it; the shape of a tutorial can change
without analysing a game again.

**What the model returns is checked before it is used, and nothing is patched.**
A missing slot stays empty and is reported; a slot id that belongs to no chosen
moment is reported; a sentence that prints an evaluation, or says a move wins
when it captures nothing, or names a fork or a pin the board does not have, is
reported. The grader and the engine check then judge the assembled file the
same way they judge every other arm.

**One answer, two tutorials.** `tutorial.json` is the key moments;
`tutorial-game.json` is the whole game, with the same moments and the game moves
between them filled in by code (`whole_game`). `python skeleton.py --assemble
<run dir>` builds both again from a saved answer.
"""

import io
import json
import math
import os
import re
import sys

import chess
import chess.pgn
import chess.svg

HERE = os.path.dirname(os.path.abspath(__file__))
INPUT_DIR = os.path.join(HERE, 'input')

# No threshold since phase 1b of docs/PLAN-ZAGONETKE-IZ-PARTIJE.md: a moment is
# a move the app's review judge called a mistake, or the only move the player
# found - its verdict is in the facts, `played.judged`, written by
# `chess_app/tool/judge_facts.dart` - and a move counts as correct when it
# would not itself be a mistake (MISTAKE_LOSS chances of the best).
DEFAULTS = {
    'max_moments': 8,      # candidates offered to the model
    'lead_plies': 3,       # game moves shown before a moment
    'answer_plies': 4,     # moves of the best line shown as the answer
    'max_answer_plies': 8,  # ...and the most it is extended to, mid-sacrifice
}

VALUE = {chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3, chess.ROOK: 5,
         chess.QUEEN: 9}
NAME = {chess.PAWN: 'pawn', chess.KNIGHT: 'knight', chess.BISHOP: 'bishop',
        chess.ROOK: 'rook', chess.QUEEN: 'queen', chess.KING: 'king'}


# --- Facts --------------------------------------------------------------------

def facts_of(name):
    path = os.path.join(INPUT_DIR, '%s_facts.json' % name)
    if not os.path.exists(path):
        sys.exit('no facts for %s: run `python make_facts.py %s` first' % (name, name))
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def stamp_of(facts):
    """Which analysis this is, short enough to carry in a run's meta.json.

    A run is graded against the analysis it was given and against no other -
    the owner's rule of 13.9.2026 - and a facts file can be rebuilt at another
    depth between the run and the grading. Without a stamp that reads as the
    model having changed the answer, which is the one accusation this harness
    must never make wrongly. `check_positions.py` compares it and says so.
    """
    return '%s d%s mpv%s %s' % (facts.get('game'), facts.get('depth'),
                                facts.get('multipv'), facts.get('generated'))


def words_for(eval_text):
    """An evaluation from White's side, as the words a sentence may use."""
    if eval_text in (None, ''):
        return 'unknown'
    if eval_text == 'checkmate':
        return 'checkmate'
    if eval_text == 'draw':
        return 'a draw'
    if eval_text.startswith('#'):
        n = int(eval_text[1:])
        return ('White mates in %d' % n) if n > 0 else ('Black mates in %d' % -n)
    value = float(eval_text)
    side = 'White' if value > 0 else 'Black'
    level = _level(abs(value))
    if level == 0:
        return 'about even'
    return '%s is %s' % (side, ('slightly better', 'clearly better', 'winning')[level - 1])


# Where the words change, in pawns: under 0.5 about even, under 1.5 slightly
# better, under 3.0 clearly better, winning from there. One tuple, because the
# filler's lexicon judges a move by these same steps, and two copies of a
# threshold are how a phrase comes to disagree with the words beside it.
LEVELS = (0.5, 1.5, 3.0)


def _level(size):
    return sum(1 for step in LEVELS if size >= step)


def standing(eval_text, mover):
    """An evaluation as [mover] sees it, in the steps `words_for` speaks in.

    -4 to 4: 0 about even, 1 to 3 slightly better to winning, 4 a forced mate;
    negative when it is the other side's. None when the evaluation is unknown.
    """
    if eval_text in (None, '', 'unknown'):
        return None
    if eval_text == 'draw':
        return 0
    if eval_text == 'checkmate':
        # Only ever the evaluation after a move that mates, by the side that
        # moved - a position whose side to move is mated has no candidates.
        return 4
    if eval_text.startswith('#'):
        white, level = int(eval_text[1:]) > 0, 4
    else:
        value = float(eval_text)
        white, level = value > 0, _level(abs(value))
    return (level if white == (mover == 'White') else -level) if level else 0


def material(board):
    white = sum(VALUE.get(p.piece_type, 0) for p in board.piece_map().values() if p.color)
    black = sum(VALUE.get(p.piece_type, 0) for p in board.piece_map().values() if not p.color)
    return white - black


def play(board, san):
    """Play [san] on [board]; the facts about that one move, as data and words.

    **Data, not a sentence to copy.** The move used to arrive as „Black plays
    Qc7: the queen from d8 to c7", and it came back as „Black plays Qc7, the
    queen from d8 to c7" on 306 of 491 spoken sentences over the ten fixture
    games (the owner, 14.9.2026; `docs/PLAN-NARACIJA.md`). The board plays the
    move while its slot is read, so the move is named for the model's benefit
    and the voice rule says not to announce it. Whether it was played or only
    should have been is said by the slot's own ending, not by a verb here.
    """
    move = board.parse_san(san)
    mover = 'White' if board.turn else 'Black'
    piece = board.piece_at(move.from_square)
    captured = board.piece_at(move.to_square)
    if board.is_en_passant(move):
        captured = chess.Piece(chess.PAWN, not board.turn)
    words = ['%s by %s (%s %s-%s)' % (
        san, mover, NAME[piece.piece_type], chess.square_name(move.from_square),
        chess.square_name(move.to_square))]
    gain = 0
    if captured:
        words.append('it captures a %s' % NAME[captured.piece_type])
        gain = VALUE.get(captured.piece_type, 0)
    if move.promotion:
        words.append('it promotes to a %s' % NAME[move.promotion])
        gain += VALUE[move.promotion] - 1
    board.push(move)

    mate = board.is_checkmate()
    if mate:
        words.append('it is checkmate')
    elif board.is_check():
        words.append('it gives check')

    # What the moved piece attacks now: a fork is two enemy pieces worth more
    # than a pawn, or the king and one more.
    targets = []
    for square in board.attacks(move.to_square):
        other = board.piece_at(square)
        if other and other.color == board.turn and other.piece_type != chess.PAWN:
            targets.append('%s on %s' % (NAME[other.piece_type], chess.square_name(square)))
    if targets:
        words.append('the moved piece now attacks: ' + ', '.join(targets))
    fork = len(targets) >= 2

    pinned = [chess.square_name(sq) for sq in chess.SQUARES
              if board.piece_at(sq) and board.piece_at(sq).color == board.turn
              and board.piece_at(sq).piece_type != chess.KING
              and board.is_pinned(board.turn, sq)]
    if pinned:
        words.append('pinned to their king afterwards: ' + ', '.join(pinned))

    return {'words': '; '.join(words), 'gain': gain, 'mate': mate,
            'fork': fork, 'pin': bool(pinned),
            'to': chess.square_name(move.to_square)}


# --- Moments ------------------------------------------------------------------

def cost_text(played):
    """What the move played cost, as words rather than as a number and a unit.

    `cost_pawns` is a number of pawns or the string `mate`, and printing it into
    `it cost %s pawns` wrote "it cost mate pawns" into nine slots of one Philidor
    prompt on 13.9.2026. The model read it as best it could and told a student
    that grabbing on h7 "cost pawns near the king". A broken sentence in the
    facts is a broken sentence in the tutorial.
    """
    cost = played.get('cost_pawns')
    if cost == 'mate':
        return played.get('cost_mate') or 'cost a forced mate'
    if cost is None:
        return 'cost an unknown amount'
    return 'cost %s pawns' % cost


def _cost_value(cost):
    return 1e9 if cost == 'mate' else (cost if isinstance(cost, (int, float)) else -1)


# --- The mistake rule's two numbers the skeleton reads -------------------------
#
# `chess_app/lib/core/services/mistake_rule.dart` is the one home; the verdicts
# themselves come from the app's judge. What is read here is only the curve and
# `A`, for the question's right answers - held to the app by the fixtures, as
# `words_for` is.

MISTAKE_LOSS = 10  # kMistakeLoss
FACTS_MATE = 100000  # kFactsMate: a mate is written as this less its distance


def chances_of_value(value):
    """`chancesOfValue`: winning chances of a facts value, 0 to 100."""
    if value > FACTS_MATE // 2:
        return 100.0
    if value < -(FACTS_MATE // 2):
        return 0.0
    return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * value)) - 1)


def judged_of(row):
    return (row.get('played') or {}).get('judged')


def _is_moment(row):
    """`_isMoment`: the verdict decides, and the facts' best move agrees."""
    judged = judged_of(row)
    if not judged or not row.get('candidates'):
        return False
    played_best = row['candidates'][0]['move'] == row['played']['move']
    if judged.get('mistake'):
        return not played_best
    return bool(judged.get('only')) and played_best


def moment_indices(rows, max_moments):
    """`momentIndices`: settled mistakes by chances lost, then only moves by
    gap, capped, in game order."""
    mistakes = [i for i, r in enumerate(rows)
                if _is_moment(r) and judged_of(r).get('mistake')]
    only = [i for i, r in enumerate(rows)
            if _is_moment(r) and not judged_of(r).get('mistake')]
    mistakes.sort(key=lambda i: (-(judged_of(rows[i]).get('lost') or 0), i))
    only.sort(key=lambda i: (-(judged_of(rows[i]).get('gap') or 0), i))
    return sorted((mistakes + only)[:max_moments])


def correct_candidates(candidates):
    """`correctCandidates`: every candidate that would not be a mistake."""
    best = chances_of_value(candidates[0]['value_for_mover'])
    return [c for c in candidates
            if best - chances_of_value(c['value_for_mover']) < MISTAKE_LOSS]


def share_words(share):
    """A share of a position's master games, as a reader would say it."""
    if share >= 0.10:
        return '%d%%' % round(100 * share)
    if share >= 0.001:
        return '%.1f%%' % (100 * share)
    return 'under 0.1%'


def book_words(row):
    """What the masters database says about the move played here.

    Absent for every position master games never reached, which after four to
    six moves of a club game is all of them. `make_facts.py` silences the motif
    detector for exactly the positions this speaks for: measured on the first
    three games, its opening sentences were things like "the black pawn on e5
    is attacked by the white knight on f3 and has no defender" on move two of a
    Philidor. What is worth saying in the book is what is played here.
    """
    book = row.get('book')
    if not book:
        return ''
    played = book.get('played') or {}
    reached = ('1 master game has reached this position' if book['games'] == 1
               else '%d master games have reached this position' % book['games'])
    if played.get('games') and book['games'] == 1:
        said = '%s, and it played %s' % (reached, played['move'])
    elif played.get('games'):
        said = '%s, and %s of them played %s' % (
            reached, share_words(played['share']), played['move'])
    else:
        said = '%s and not one of them played %s' % (
            reached, played.get('move', 'this move'))
    others = ', '.join('%s %s' % (a['move'], share_words(a['share']))
                       for a in book.get('alternatives') or [])
    if others:
        said += '; the other moves played here are %s' % others
    if book.get('opening'):
        said += '. The opening is the %s' % book['opening']
    return said


def gives_material(fen, mover, sans):
    """Whether `mover` is ever behind where they started inside `sans`.

    „The best move is a sacrifice", asked of the line rather than of the first
    move: on the ten fixture games not one best move gives material away
    immediately, and 29 of 69 best lines do so somewhere inside the plies
    shown. A rule that looked only at the first move would have been a rule
    that never fired.
    """
    board = chess.Board(fen)
    sign = 1 if mover == 'White' else -1
    start = sign * material(board)
    for san in sans:
        board.push_san(san)
        if sign * material(board) < start:
            return True
    return False


def answer_ply_count(fen, mover, line, cfg):
    """How many plies of `line` the answer part shows.

    `answer_plies` normally, but **never ending while the side that played it is
    still down material**. The owner found why on 14.9.2026, on „Punish, Count,
    Retreat": a line cut at four plies ended on a position where White was
    better with no visible reason, because the piece had been given and the
    point of giving it was the move after the cut.

    Measured over the ten fixture games before it was written: 16 of 69 answer
    parts ended with the mover down material, so it is about one in four rather
    than a corner case. On g01 `g7 Qe8 h7+ Kxg7 h8=R Qxh8` runs 0, 0, 0, -1,
    +3, -2 - cut at four it stops on „a pawn down", and one ply further it
    stops on the promotion, which is the whole idea of the line.

    Bounded by `max_answer_plies` rather than by the line, because the stored
    line is six plies today and this must not become „show the whole engine PV"
    the day that changes.
    """
    if not line:
        return 0
    board = chess.Board(fen)
    sign = 1 if mover == 'White' else -1
    start = sign * material(board)
    after = []
    for san in line:
        board.push_san(san)
        after.append(sign * material(board))
    cap = min(cfg['max_answer_plies'], len(after))
    cut = min(cfg['answer_plies'], cap)
    if cut == 0:
        return 0
    while cut < cap and after[cut - 1] < start:
        cut += 1
    return cut


def _stands(side, level):
    """`standing` as the words a narration uses, from [side]'s point of view."""
    if level is None:
        return 'the evaluation is unknown'
    if level == 4:
        return '%s has a forced mate' % side
    if level == -4:
        return '%s is getting mated' % side
    if level == 0:
        return 'it is about even'
    who = side if level > 0 else ('Black' if side == 'White' else 'White')
    return '%s is %s' % (who, ('slightly better', 'clearly better', 'winning')[abs(level) - 1])


def _points(n):
    return '1 point of material' if n == 1 else '%d points of material' % n


def _sacrifice(fen, mover, sans, end_eval):
    """Whether a shown line is material given for activity.

    Asked at the end of the line, never inside it: `answer_ply_count` already
    runs a line on while its mover is behind, so a line still behind where it
    ends is one whose compensation is not material - and the transient deficit
    inside `d4 cxd4 exd4` is a trade in progress, which is what „ever behind"
    called a sacrifice on the first draft of this.
    """
    if not sans:
        return False
    board = chess.Board(fen)
    sign = 1 if mover == 'White' else -1
    start = sign * material(board)
    for san in sans:
        board.push_san(san)
    end = standing(end_eval, mover)
    return sign * material(board) < start and end is not None and end >= 0 \
        and not _quick_mate(end_eval)


def _quick_mate(eval_text):
    return bool(eval_text) and eval_text.startswith('#') and abs(int(eval_text[1:])) <= 3


def game_story(rows):
    """The turning points of a game, in game order, as facts a narration may say.

    The owner's point of 14.9.2026: a comment's core is the swings - the first
    mistake that hands one side a big advantage, a chance one side gives the
    other and the other takes or misses, the last chance missed, and material
    given for activity. Every event is read off the evaluations and the board,
    so the model narrates it and cannot invent it. `docs/PLAN-NARACIJA.md`.

    Returns a list of {'ply', 'kind', 'side', 'text'}; `ply` is the row whose
    move the event is about, and `side` is who the event belongs to - the side
    that made the mistake, took or missed the chance, or gave the material.
    """
    events = []
    first_big = None
    missed = []

    def other(side):
        return 'Black' if side == 'White' else 'White'

    for i, row in enumerate(rows):
        played, cands = row.get('played'), row.get('candidates')
        if not played or not cands:
            continue
        mover = row['to_move']
        before = standing(cands[0].get('eval'), mover)
        after = standing(played.get('eval'), mover)
        if before is None or after is None:
            continue

        # Material for activity, among the game's own moves: the side is down
        # material against where it stood before this move, still so after
        # its own next move - so a trade half made is not a sacrifice - and
        # not worse for it, with no mate in three behind the evaluation.
        # And the material has to go where this move went: the reply takes on
        # the square this move landed on. Without it „16. Kh1 gives up
        # material" on g05 - a piece left loose earlier was taken after it.
        taken_there = False
        if i + 1 < len(rows) and rows[i + 1].get('played') is not None:
            here = chess.Board(row['fen'])
            landed = here.parse_san(played['move']).to_square
            here.push_san(played['move'])
            reply = here.parse_san(rows[i + 1]['played']['move'])
            taken_there = reply.to_square == landed and here.is_capture(reply)
        if taken_there and i + 2 < len(rows) and rows[i + 2].get('played') is not None:
            sign = 1 if mover == 'White' else -1
            later = chess.Board(rows[i + 2]['fen'])
            later.push_san(rows[i + 2]['played']['move'])
            given = sign * (material(later) - material(chess.Board(row['fen'])))
            then = standing(rows[i + 2]['played'].get('eval'), mover)
            if given <= -1 and then is not None and then >= 0 and \
                    not _quick_mate(rows[i + 2]['played'].get('eval')):
                events.append({'ply': i, 'kind': 'activity', 'side': mover, 'text': (
                    'with %s %s gives up material, and two moves later is still '
                    '%s behind and %s - material for activity' % (
                        played['label'], mover, _points(-given),
                        _stands(mover, then)))})

        if not (after <= -2 < before):
            continue
        # A chance handed to the other side.
        if first_big is None:
            first_big = i
            events.append({'ply': i, 'kind': 'first_big_mistake', 'side': mover, 'text': (
                '%s is the first mistake of the game that gives one side a big '
                'advantage: afterwards %s' % (played['label'], _stands(mover, after)))})
        nxt = rows[i + 1] if i + 1 < len(rows) else None
        if not nxt or not nxt.get('played') or not nxt.get('candidates'):
            continue
        reply = standing(nxt['played'].get('eval'), nxt['to_move'])
        if reply is None:
            continue
        if reply >= 2:
            events.append({'ply': i + 1, 'kind': 'chance_taken', 'side': other(mover), 'text': (
                '%s hands %s a chance, and %s takes it with %s: afterwards %s' % (
                    played['label'], other(mover), other(mover),
                    nxt['played']['label'], _stands(nxt['to_move'], reply)))})
        else:
            event = {'ply': i + 1, 'kind': 'chance_missed', 'side': other(mover), 'text': (
                '%s hands %s a chance, and %s misses it with %s: afterwards %s' % (
                    played['label'], other(mover), other(mover),
                    nxt['played']['label'], _stands(nxt['to_move'], reply)))}
            events.append(event)
            missed.append(event)
    if missed:
        last = missed[-1]
        last['kind'] = 'last_chance_missed'
        last['text'] = last['text'].replace(' misses it with ', ' misses it - the last chance of the game given and not taken - with ')
    events.sort(key=lambda e: e['ply'])
    return events


TACTICAL = ('fork', 'pin', 'skewer', 'hanging', 'attacked', 'defender', 'mate',
            'discovered', 'overload', 'deflect', 'trapped', 'defended only')
POSITIONAL = ('isolated', 'backward', 'doubled', 'weak', 'open file', 'open g-file',
              'bishop pair', 'centre', 'passed', 'outpost', 'space', 'squares',
              'half-open', 'pawn chain')


def game_arc(rows):
    """What the first words may promise and the last words may say.

    The owner, 14.9.2026: the beginning should tell what kind of game is coming
    - quiet or full of turns, a tactical or a positional fight - and the end who
    won, where the tutorial said only „The game ended here". Every number is
    read off the facts; the result is the board's (mate, stalemate) or the last
    evaluation, because the Analysis export records no result (`[Result "*"]`
    in every fixture game) and a resignation nobody recorded is not a fact.
    """
    events = game_story(rows)
    turns = [e for e in events if e['kind'] != 'activity']
    missed = [e for e in events if e['kind'] in ('chance_missed', 'last_chance_missed')]
    by_side = {side: sum(1 for e in missed if e['side'] == side) for side in ('White', 'Black')}
    tactical = positional = 0
    for row in rows:
        for sentence in re.split(r'(?<=[.])\s+', row.get('motifs_after_played') or ''):
            low = sentence.lower()
            if any(w in low for w in TACTICAL):
                tactical += 1
            elif any(w in low for w in POSITIONAL):
                positional += 1
    played = [r for r in rows if r.get('played')]
    last = rows[-1]
    board = chess.Board(last['fen'])
    moves = len(played)
    if board.is_checkmate():
        result = '%s is checkmated: %s wins' % (
            'White' if board.turn else 'Black', 'Black' if board.turn else 'White')
    elif board.is_stalemate():
        result = 'stalemate: a draw'
    elif last.get('candidates'):
        result = ('no result is recorded; when the game stops, %s'
                  % words_for(last['candidates'][0].get('eval')))
    else:
        result = 'no result is recorded and the last position has no evaluation'
    named = [r['book']['opening'] for r in rows if r.get('book') and r['book'].get('opening')]
    kind = ('mostly tactical' if tactical >= 2 * positional else
            'mostly positional' if positional > tactical else 'tactical and positional in turn')
    # Said per side and in words a count cannot be misread from: round 2 of the
    # measurement read „4 turning points (2 chances missed)" as „two chances
    # each side lets slip" (g10, 14.9.2026).
    character = ('%d moves; %d turning points in all; chances missed: %s; the motif '
                 'sentences of the game are %d tactical and %d positional - %s' % (
                     (moves + 1) // 2, len(turns),
                     'none' if not missed else ', '.join(
                         '%s missed %d' % (side, n) for side, n in by_side.items() if n),
                     tactical, positional, kind))
    opening = (
        'before the first move: %s%s. The program names the opening right after '
        'this, so do not name it. In one or two sentences tell the student what '
        'kind of game is coming - quiet or full of turns, a tactical or a '
        'positional fight - and what to watch for, without saying who wins and '
        'without naming a move.' % (
            character, ('; the opening is the %s' % named[-1]) if named else ''))
    ending = (
        'after the last move (%s): %s; %s. In one sentence end the story: who came '
        'out on top and what decided it, from the story of the game. Do not invent '
        'a resignation, a clock or a result that is not here.' % (
            played[-1]['played']['label'] if played else 'no moves', result,
            ('the last turning point: ' + turns[-1]['text']) if turns else
            'nothing in the story changed who stands better'))
    return {'opening': opening, 'ending': ending}


def moments(name, cfg=None):
    """The candidate moments of a game, each with its parts and its slots."""
    cfg = dict(DEFAULTS, **(cfg or {}))
    rows = facts_of(name)['rows']
    story = game_story(rows)

    picked = moment_indices(rows, cfg['max_moments'])

    out = []
    for number, i in enumerate(picked, 1):
        mid = 'm%d' % number
        row = rows[i]
        mover = row['to_move']
        best = row['candidates'][0]
        judged = judged_of(row)
        # An only move the player found: the game played the best move.
        only = not judged.get('mistake')
        # Every candidate as good as the best - used below by the alternative
        # („other") part to find the next move that is clearly worse. Never
        # asked of the student: a tutorial is material for a film, and asks
        # nothing.
        correct = correct_candidates(row['candidates'])
        board_here = rows[i - 1].get('motifs_after_played') if i > 0 else None
        if not board_here:
            # In the book the detector is quiet on purpose, and this is what
            # stands in its place.
            board_here = book_words(row) or None
        played = row['played']
        slots, facts, parts = {}, {}, []

        # The lead-in: the game moves that brought the board here.
        start = max(0, i - cfg['lead_plies'])
        if start < i:
            board = chess.Board(rows[start]['fen'])
            before = material(board)
            moves = []
            for r in range(start, i):
                game_move = rows[r]['played']
                sid = '%s.lead.%d' % (mid, len(moves) + 1)
                info = play(board, game_move['move'])
                text = ('%s; played in the game; afterwards %s'
                        % (info['words'], words_for(game_move.get('eval'))))
                if rows[r].get('motifs_after_played'):
                    text += '; on the board after it: %s' % rows[r]['motifs_after_played']
                book = book_words(rows[r])
                if book:
                    text += '. In the masters database: %s' % book
                slots[sid] = text
                facts[sid] = dict(info, motifs=rows[r].get('motifs_after_played') or '')
                moves.append({'san': game_move['move'], 'slot': sid, 'ply': r,
                              'fen_before': rows[r]['fen']})
            intro = '%s.lead.intro' % mid
            # „The board just before these moves, with Black to play. Material
            # is level." - the owner, 14.9.2026: a sentence with no meaning to a
            # listener, faithfully made of the fact this slot used to carry.
            start_eval = (rows[start]['candidates'][0].get('eval')
                          if rows[start].get('candidates') else None)
            slots[intro] = (
                'the scene, a few moves before the moment: %s to move, %s, %s. '
                'Say in one sentence where the fight stands here - who is '
                'pressing and what the game is about - so the moves after it '
                'are heard as part of the story. Do not describe the board, '
                'count material or say what is about to be played.' % (
                    rows[start]['to_move'], words_for(start_eval),
                    'material is level' if before == 0 else
                    '%s is %s up' % (
                        'White' if before > 0 else 'Black', _points(abs(before)))))
            facts[intro] = {'gain': 0, 'mate': False, 'fork': False, 'pin': False,
                            'motifs': ''}
            parts.append({'kind': 'show', 'fen': rows[start]['fen'],
                          'intro': intro, 'moves': moves, 'lead': True})

        # The answer: the best line.
        board = chess.Board(row['fen'])
        moves = []
        line_sans = best['line'].split()
        shown = answer_ply_count(row['fen'], mover, line_sans, cfg)
        # For an only move the line starts with the game's own move, and goes
        # on as the game did for as long as the two agree.
        on_game = only
        for k, san in enumerate(line_sans[:shown], 1):
            sid = '%s.answer.%d' % (mid, k)
            game_row = rows[i + k - 1] if i + k - 1 < len(rows) else None
            on_game = on_game and bool(game_row) and \
                (game_row.get('played') or {}).get('move') == san
            info = play(board, san)
            # A move of the best line did not happen, and the slot says so in
            # its own words: a student met „Black plays Qf6 instead of the game
            # move bxa3" on 13.9.2026 and, one click later, „Black plays Qf6 …
            # this is the best move" - the same voice for what happened and for
            # what should have.
            # **Not „the best line goes on".** That phrase was written here as
            # a fact and came back out of the model as a sentence, on every
            # ply of every answer line - „Black would answer Ra7. Not played
            # either; best line goes on." The owner read it on 15.9.2026 and
            # asked for it to stop. A fact a model has nothing to add to is a
            # fact it repeats, so the marker is the two words the prompt's
            # rule keys on and nothing more; the prompt now also says that a
            # move with nothing to tell gets an empty slot rather than a
            # sentence about the line continuing.
            if only:
                marker = ('; the move played in the game, the only one that held'
                          if k == 1 else
                          '; played in the game' if on_game else '; not played')
            else:
                marker = ('; the best move, which the game did not play' if k == 1
                          else '; not played')
            slots[sid] = info['words'] + marker
            if k == 1 and _sacrifice(row['fen'], mover, line_sans[:shown], best.get('eval')):
                slots[sid] += ('; this line gives material for activity: at its '
                               'end %s is still material down and %s, and not '
                               'because of a quick mate' % (
                                   mover, _stands(mover, standing(best.get('eval'), mover))))
            facts[sid] = dict(info, motifs='')
            moves.append({'san': san, 'slot': sid})
        # **The owner's order at a mistake**, 14.9.2026: first what was played -
        # drawn as a blue arrow and not played - then „The best move was…", and
        # only then the line, in a part of its own. The program says it; the
        # model is not asked to, and the answer part has no introduction.
        fork = '%s.fork' % mid
        played_move = chess.Board(row['fen']).parse_san(played['move'])
        # An only move is not named here either: the line after this part
        # plays it, and a move read before it is played is given away.
        program = {fork: (
            'In this position %s found the only move that held…' % mover
            if only else
            'In this position %s played %s. The best move was…' % (
                mover, played['move']))}
        parts.append({'kind': 'show', 'fen': row['fen'], 'intro': fork,
                      'moves': [], 'program': True,
                      # Square names, not indices: this is data the app's port reads back
                      # out of JSON, where a tuple of ints would be a third encoding.
                      'arrow': [chess.square_name(played_move.from_square),
                                chess.square_name(played_move.to_square)]})
        # Marked, not inferred from the slot ids: what follows this part is
        # the game again, and the student has to be told so.
        parts.append({'kind': 'show', 'fen': row['fen'],
                      'intro': None, 'moves': moves, 'sideline': True})

            # **And what the next-best move does instead, where the best one gives
        # something up.** The owner asked for it on 14.9.2026, and asked for it
        # scoped: „kad je žrtva opravdana i najbolji potez". Written first for
        # every moment with a worse alternative, it fired on 67 of the 69
        # fixture moments - a second part on almost every answer, which is not
        # what was asked and doubles what a child reads. Gated on the best line
        # actually giving material up it is 29 of 69, which is the question a
        # child really has there: why give that, and what was wrong with
        # keeping it.
        #
        # `correct` is every candidate within `near` of the best, so
        # `candidates[len(correct)]` is the best move that is **clearly** worse
        # - the first one it would be true to call second choice. Anything
        # inside `correct` is as good, and calling it the lesser move would be
        # a sentence the facts do not bear out.
        #
        # **A part of its own, not a variation of the answer part.** The
        # child's viewer breaks the narrated walk at a fork and asks them to
        # choose (`lesson_viewer_screen.dart`), so a variation here would stop
        # „Pusti tutorijal" at the very moment the answer is being shown, and
        # offer a choice between the right move and a worse one with nothing
        # said yet about either. The film ignores variations too - its beats
        # follow the spine - so as a variation this would be invisible in every
        # exported video. As a part it is read, spoken and filmed like any
        # other.
        others = row['candidates'][len(correct):]
        if others and gives_material(row['fen'], mover, line_sans[:shown]):
            other = others[0]
            other_sans = other['line'].split()
            other_shown = answer_ply_count(row['fen'], mover, other_sans, cfg)
            if other_shown:
                other_board = chess.Board(row['fen'])
                other_moves = []
                for k, san in enumerate(other_sans[:other_shown], 1):
                    sid = '%s.other.%d' % (mid, k)
                    info = play(other_board, san)
                    slots[sid] = info['words'] + (
                        '; the next best move, and not as good as %s'
                        % best['move'] if k == 1
                        else '; not played')
                    facts[sid] = dict(info, motifs='')
                    other_moves.append({'san': san, 'slot': sid})
                other_intro = '%s.other.intro' % mid
                slots[other_intro] = (
                    'the other line: the next best move here is not as good as '
                    '%s. At the end of it %s, against %s at the end of the best '
                    'line. Say that there was a second choice and that it is '
                    'weaker, in one sentence, without naming it - the move '
                    'after this sentence names it.' % (
                        best['move'], words_for(other.get('eval')),
                        words_for(best.get('eval'))))
                facts[other_intro] = {'gain': 0, 'mate': False, 'fork': False,
                                      'pin': False, 'motifs': ''}
                parts.append({'kind': 'show', 'fen': row['fen'],
                              'intro': other_intro, 'moves': other_moves,
                              'sideline': True, 'alternative': True})

        # Every slot's facts carry the very text the model was shown beside it,
        # so a claim is judged against what it was allowed to say rather than
        # against a narrower list. Without this the check flagged „mate" in
        # slots whose facts read „Black mates in 5".
        for sid, text in slots.items():
            facts[sid]['text'] = text

        out.append({
            'id': mid, 'index': i, 'label': row['label'], 'mover': mover,
            'played': played['label'],
            'kind': 'only' if only else 'mistake',
            'lost': judged.get('lost'),
            'cost': played.get('cost_pawns'),
            'cost_text': 'was the only move that held' if only else cost_text(played),
            'left_book': bool(played.get('left_book')),
            'best': best['move'], 'board': board_here,
            'parts': parts, 'slots': slots, 'facts': facts, 'program': program,
            'events': [e['text'] for e in story if e['ply'] == i],
        })

    # **The one moment the game turned on** - point 7 of the owner's live pass,
    # 14.9.2026. Every moment offered is already a mistake; what was missing is
    # which of them decided the game, so the model can weight it and the
    # whole-game tutorial can come back to it at the end (point 8).
    #
    # Ranked by whether the move changed who stands better before it is ranked
    # by what it cost, because a game already lost collects expensive blunders
    # that decide nothing. `mistake_kind` is that question and it is not asked a
    # second way here: it is the same classifier the filler's lexicon uses, so
    # the sentence the student reads at that move and the moment marked
    # decisive cannot disagree. Ties go to the earlier move - the game turned
    # the first time it turned.
    turning = decisive_moment(out, rows)
    for m in out:
        m['turning_point'] = m['id'] == turning
    return out


def _changed_hands(rows, i):
    """Whether the move at [i] changed who stands better."""
    row = rows[i]
    best_eval = row['candidates'][0].get('eval')
    return mistake_kind(
        standing(best_eval, row['to_move']),
        standing(row['played'].get('eval'), row['to_move'])) is not None


def decisive_moment(moments_list, rows):
    """Which of `moments_list` the game turned on, by id; None when it is empty.

    Whether the move changed who stands better comes before what it cost,
    because a game already lost collects expensive blunders that decide
    nothing - on g01 a move costing a forced mate is passed over for one
    costing 2.11 pawns, because the first was played from a lost position and
    the second is where the position was lost. `mistake_kind` is that question
    and is not asked a second way here: it is the same classifier the filler's
    lexicon uses, so the sentence the student reads at that move and the moment
    called decisive cannot disagree. Ties go to the earlier move.

    Asked twice of two different lists, which is the point of it being a
    function. `moments` marks the decisive moment **of the game**, before the
    model has chosen anything, so the prompt can weight it. `whole_game` asks
    again of the moments the model actually chose, so the recap at the end is
    the most decisive part of the tutorial that exists rather than nothing at
    all when the model passed the marked one over.
    """
    if not moments_list:
        return None
    return max(moments_list,
               key=lambda m: (_changed_hands(rows, m['index']),
                              m.get('lost') or 0, -m['index']))['id']


# --- The prompt ---------------------------------------------------------------

# The template of the words prompt. **One copy, and it is the server's**: since
# 14.9.2026 the words route writes the prompt (docs/PLAN-SKELET.md, phase 3), and
# a second copy here would be two prompts agreeing by accident. Python's
# `str.format` fills it, and chess_backend/services/tutorialWords.js fills it the
# same way; its test holds the result to `expected.prompt` on every fixture game.
PROMPT_PATH = os.path.join(os.path.dirname(os.path.dirname(HERE)), 'chess_backend',
                           'services', 'prompts', 'tutorial_words.txt')
with io.open(PROMPT_PATH, encoding='utf-8') as _fh:
    PROMPT = _fh.read()


def book_summary(rows):
    """One line about the opening, for the prompt's header.

    The statistics belong to the positions master games reached, and those are
    the first four to six moves of a club game - while the moments a tutorial is
    built from are in the middlegame. So on the three games this was written
    against, the book reached a slot in exactly one: the agreed value, "name the
    opening", arrived nowhere in the other two. This is that one line, and it
    sits with the game rather than with a slot, because it is about the game.
    It is what the title and the description can be written from.
    """
    named = [r['book']['opening'] for r in rows
             if r.get('book') and r['book'].get('opening')]
    left = next((r for r in rows if (r.get('played') or {}).get('left_book')),
                None)
    if not named and not left:
        return ''
    said = []
    if named:
        said.append('The opening is the %s' % named[-1])
    if left:
        book = left['book']
        said.append('%s left the masters database: %d master game%s had reached '
                    'that position and not one played it'
                    % (left['played']['label'], book['games'],
                       '' if book['games'] == 1 else 's'))
    elif named:
        said.append('the game never left the masters database')
    return '. '.join(said) + '.'


def movetext_of(pgn):
    """The moves of a PGN without its headers.

    A trainer's game names its players, and they are the trainer's students -
    many of them minors - while the words are written by a model on somebody
    else's servers that has no use for a name. Until 14.9.2026 the prompt quoted
    the whole file; the ten fixture games only ever carried placeholder names
    ("Player", "Analysis Engine"), so what changed is what a real game would
    have sent.
    """
    lines = [line for line in pgn.strip().splitlines()
             if not line.lstrip().startswith('[')]
    return '\n'.join(lines).strip()


def words_request(name, cfg=None):
    """What the app sends the server for the words (docs/PLAN-SKELET.md, phase 3).

    **The skeleton as data, never a prompt**: a route that forwarded a prompt
    would be the server's key as an open proxy for anything. The server writes
    the prompt from this with `prompt_from_request`'s rules, and its test holds
    it to that function on every fixture game.
    """
    with open(os.path.join(INPUT_DIR, '%s_plain.pgn' % name), encoding='utf-8') as fh:
        game = movetext_of(fh.read())
    request_moments = []
    for m in moments(name, cfg):
        slots = []
        for part in m['parts']:
            if part.get('program'):
                continue
            for sid in ([part.get('intro')] if part.get('intro') else []) + \
                       ([part['instruction']] if part.get('instruction') else []) + \
                       [mv['slot'] for mv in part.get('moves', [])]:
                slots.append({'id': sid, 'text': m['slots'][sid]})
        request_moments.append({
            'id': m['id'], 'label': m['label'], 'mover': m['mover'],
            'played': m['played'], 'cost_text': m['cost_text'], 'best': m['best'],
            'left_book': m['left_book'],
            'turning_point': m['turning_point'],
            'board': m['board'], 'events': m['events'], 'slots': slots,
        })
    rows = facts_of(name)['rows']
    return {'game': game,
            'opening': book_summary(rows) or None,
            'story': [e['text'] for e in game_story(rows)],
            'arc': game_arc(rows),
            'moments': request_moments}


def prompt_from_request(request):
    """The prompt, from what the app sends - the one place it is written."""
    blocks = []
    for m in request['moments']:
        head = ('### %s - at %s, %s to move\nIn the game %s was played and it %s; '
                'the best move was %s.' % (
                    m['id'], m['label'], m['mover'], m['played'], m['cost_text'], m['best']))
        if m['turning_point']:
            # After the book hook and before the board, so a moment that is
            # both reads in one order.
            head += '\nThis is the moment the game turned on.'
        if m['left_book']:
            # The hook a moment inside the book is for: not "you
            # blundered", but "this is where you stopped playing what
            # masters play".
            head += '\nThis is the move that left the masters database.'
        for event in m.get('events') or []:
            head += '\nIn the story of the game: %s.' % event
        if m['board']:
            head += '\nOn the board: %s' % m['board']
        lines = [head, '', 'Slots, in the order the student meets them:']
        lines += ['- `%s`: %s' % (slot['id'], slot['text']) for slot in m['slots']]
        blocks.append('\n'.join(lines))
    opening = request.get('opening') or ''
    story = '\n'.join('- %s.' % line for line in request.get('story') or []) \
        or '- Nothing in this game changed who stands better by a big margin.'
    arc = request.get('arc') or {}
    return PROMPT.format(
        game=request['game'], opening=(opening + '\n\n') if opening else '',
        story=story, moments='\n\n'.join(blocks),
        arc='\n'.join('- `story.%s`: %s' % (k, arc[k]) for k in ('opening', 'ending')
                      if arc.get(k)))


def prompt(name, cfg=None):
    return prompt_from_request(words_request(name, cfg))


# --- Assembly -----------------------------------------------------------------

def _clean(text):
    text = str(text or '').replace('{', '(').replace('}', ')')
    return re.sub(r'\s+', ' ', text).strip()


def _draw(node, played, masters):
    """The arrows of one node: blue for a move that was played, green for the
    moves masters play.

    Two colours because they answer two different questions, and the student
    meets both on one board at the departure from the book: „this is what was
    played" and „this is what the database plays". The codes are the app's own
    (`ChessArrow`), which is what `[%cal]` carries either way.
    """
    arrows = []
    if played:
        arrows.append(chess.svg.Arrow(chess.parse_square(played[0]),
                                      chess.parse_square(played[1]), color='blue'))
    for a in masters or []:
        arrows.append(chess.svg.Arrow(chess.parse_square(a[0]),
                                      chess.parse_square(a[1]), color='green'))
    if arrows:
        node.set_arrows(arrows)


def _pgn(part, words):
    game = chess.pgn.Game()
    game.setup(chess.Board(part['fen']))
    game.comment = words.get(part['intro'], '') if part.get('intro') else ''
    _draw(game, part.get('arrow'), part.get('arrows'))
    node = game
    for mv in part['moves']:
        node = node.add_variation(node.board().parse_san(mv['san']))
        node.comment = words.get(mv['slot'], '')
        _draw(node, None, mv.get('arrows'))
    exporter = chess.pgn.StringExporter(headers=False, variations=False, comments=True)
    text = game.accept(exporter).strip()
    if not text.endswith('*'):
        text += ' *'
    return text


def _claims(sid, text, facts, context=''):
    """What a sentence says that its facts do not bear out."""
    found = []
    low = text.lower()
    # A story carries a pin or a mate from one slot to the next, and a check
    # reading one slot at a time flagged „the pin is broken" on the move after
    # the pin (round one of docs/PLAN-NARACIJA.md). What was shown for the
    # moment so far - [context] - backs a word too; and a word said not to be
    # there („no mate") is not a claim that it is.
    low = re.sub(r"\b(no|not|without|never|isn't|is no longer)\b[^.,;]{0,24}", ' ', low)
    # What the model was shown beside this slot, and the motifs. A word is
    # backed when it is there; the rule it was given is „say only what the
    # facts beside the slot say", so that is the rule it is held to.
    shown = (facts.get('text', '') + ' ' + facts.get('motifs', '') + ' ' + context).lower()
    if re.search(r'[+-]\d+\.\d+|\b\d+\.\d+\b', text):
        found.append('%s prints an evaluation' % sid)
    if re.search(r'\b(win|wins|won|winning a)\b', low) and 'winning' not in low \
            and not facts.get('gain') and not facts.get('mate') \
            and 'winning' not in shown and ' mates in ' not in shown:
        found.append('%s says a move wins, and the facts show no material won' % sid)
    if re.search(r'\b(checkmate|mates|mate)\b', low) and not facts.get('mate') \
            and 'mate' not in shown:
        found.append('%s speaks of mate, and the facts of that slot have none' % sid)
    if 'fork' in low and not facts.get('fork') and 'fork' not in shown:
        found.append('%s names a fork the facts do not show' % sid)
    if re.search(r'\bpin', low) and not facts.get('pin') and 'pin' not in shown:
        found.append('%s names a pin the facts do not show' % sid)
    for word, key in (('skewer', 'skewer'), ('discover', 'discover'), ('trapped', 'trap')):
        if word in low and key not in shown:
            found.append('%s names a %s the facts do not show' % (sid, word))
    # A sentence written on the wrong move. `gpt-5.4-mini` on 13.9.2026 wrote
    # „White's queen goes to c4" on the slot for 22... Qc8 - the move before -
    # and nothing flagged it, because every word was true of *some* move.
    squares = set(re.findall(r'\b(?:to|on to|onto)\s+([a-h][1-8])\b', low))
    if facts.get('to') and squares and facts['to'] not in squares:
        found.append('%s says a piece goes to %s, and this move goes to %s' % (
            sid, ', '.join(sorted(squares)), facts['to']))
    return found


def assemble(run_dir, name, meta, answer_text, cfg=None):
    """Build `tutorial.json` from the skeleton and the model's words."""
    cfg = dict(DEFAULTS, **(cfg or {}))
    report = {'parameters': cfg, 'facts': stamp_of(facts_of(name)),
              'problems': [], 'missing_slots': [],
              'unused_slots': [], 'claims': []}
    meta['skeleton'] = report
    try:
        answer = json.loads(answer_text)
    except ValueError:
        report['problems'].append('the answer is not JSON')
        return

    offered = {m['id']: m for m in moments(name, cfg)}
    asked = answer.get('chosen') or []
    chosen = [c for c in asked if c in offered]
    report['chosen'] = chosen
    for c in asked:
        if c not in offered:
            report['problems'].append('chose %r, which was not offered' % c)
    if not 2 <= len(chosen) <= 3:
        report['problems'].append('chose %d moments, not two or three' % len(chosen))

    given = {k: _clean(v) for k, v in (answer.get('slots') or {}).items()}
    wanted = set()
    blocks = []
    previous = None
    trimmed = []
    for mid in sorted(chosen, key=lambda c: offered[c]['index']):
        moment = offered[mid]
        parts = []
        for part in moment['parts']:
            # Moments sit close together, and a lead-in that starts before the
            # moment already shown replays game moves the student has just seen:
            # on 13.9.2026 five models chose neighbouring moments and `25. Rd7
            # Re7` came round three times. The lead-in starts at the previous
            # moment instead; its opening sentence goes, because it described a
            # board that is no longer where the part begins, and a lead-in with
            # nothing left is dropped.
            if part.get('lead') and previous is not None and \
                    part['moves'] and part['moves'][0]['ply'] < previous:
                kept = [mv for mv in part['moves'] if mv['ply'] >= previous]
                trimmed.append('%s lead-in starts at ply %d instead of %d%s' % (
                    mid, previous, part['moves'][0]['ply'],
                    '' if kept else ', and is dropped'))
                if not kept:
                    continue
                part = dict(part, moves=kept, fen=kept[0]['fen_before'], intro=None)
            parts.append(part)
        previous = moment['index']

        used = set()
        for part in parts:
            used.update(s for s in [part.get('intro'), part.get('instruction')] if s)
            used.update(mv['slot'] for mv in part.get('moves', []))
        context = ' '.join((moment.get('events') or []) + [moment.get('board') or ''])
        for sid in moment['slots']:
            context += ' ' + moment['slots'][sid]
            if sid not in used:
                continue
            wanted.add(sid)
            # A move the model chose to leave in silence, which the voice rule
            # allows - never the first move of a best line.
            if given.get(sid) == '' and \
                    re.search(r'[.](lead|answer|other)[.][0-9]+$', sid) and \
                    not sid.endswith('.answer.1'):
                report.setdefault('silent_slots', []).append(sid)
                continue
            if not given.get(sid):
                report['missing_slots'].append(sid)
            else:
                report['claims'].extend(_claims(sid, given[sid], moment['facts'][sid],
                                                context))
        blocks.append((moment, parts))
    rows = facts_of(name)['rows']
    arc = game_arc(rows)
    story_facts = ' '.join(e['text'] for e in game_story(rows))
    for key in ('opening', 'ending'):
        sid = 'story.' + key
        wanted.add(sid)
        if not given.get(sid):
            report['missing_slots'].append(sid)
        else:
            report['claims'].extend(_claims(
                sid, given[sid], {'text': arc[key], 'motifs': ''}, story_facts))
    report['unused_slots'] = sorted(set(given) - wanted)
    report['trimmed'] = trimmed
    for moment, _ in blocks:
        given.update(moment.get('program') or {})

    head = {
        'title': _clean(answer.get('title')),
        'description': _clean(answer.get('description')),
        'tags': [_clean(t) for t in (answer.get('tags') or [])][:2],
        'language': 'en',
    }
    moments_only = [part for _, parts in blocks for part in parts]
    key_words = _framed(moments_only, _bridged(moments_only, given, {}), given)
    _write(run_dir, 'tutorial.json',
           dict(head, positionList=_steps(moments_only, key_words)))

    parts, words, report['game'] = whole_game(name, blocks, given, cfg)
    _write(run_dir, 'tutorial-game.json',
           dict(head, title=head['title'] + GAME_TITLE, positionList=_steps(parts, words)))


def _framed(parts, words, given):
    """The story's first words before the first part, its last after the last."""
    out = dict(words)
    if not parts:
        return out
    opening, ending = given.get('story.opening'), given.get('story.ending')
    if opening:
        first = parts[0]
        key = first.get('intro') or _first_text_key(first, out)
        if key:
            first_said = (out.get(key) or '').strip()
            out[key] = ('%s %s' % (opening, first_said)).strip()
    if ending:
        last = parts[-1]
        keys = [mv['slot'] for mv in last.get('moves') or []] or \
            [k for k in (last.get('intro'), last.get('instruction')) if k]
        if keys:
            said = (out.get(keys[-1]) or '').replace('The game ended here.', '').strip()
            out[keys[-1]] = ('%s %s' % (said, ending)).strip()
    return out


def _write(run_dir, file_name, tutorial):
    with open(os.path.join(run_dir, file_name), 'w', encoding='utf-8') as fh:
        json.dump(tutorial, fh, ensure_ascii=False, indent=2)


def _steps(parts, words):
    """The tutorial's `positionList`: each part as the app stores a step."""
    steps = []
    for part in parts:
        # No `blackOrientation`, in either mode. Each moment used to be shown
        # from its mover's side, and a whole game turned the board over by
        # itself in six of ten; the owner settled it on 13.9.2026 - one side
        # throughout, because the reader and the video export can turn it.
        step = {'title': 'Part %d' % (len(steps) + 1), 'fen': part['fen'],
                'kind': part['kind']}
        step['pgn'] = _pgn(part, words)
        steps.append(step)
    return steps


# --- The whole game -----------------------------------------------------------

# Two tutorials of one game carry one title from the model, and a library
# showing the same name twice cannot say which is which.
GAME_TITLE = ' (whole game)'


# The phrases code may say on a game move, by what the facts establish about it.
# Every phrase is true by construction of the pool it is in - none says
# „material", „initiative" or „decisive", because nothing the filler reads
# measures those, and a confident sentence no fact backs is the one thing arm H
# exists to prevent. Chosen by how often the pool has been used in this
# tutorial, never by ply: two slips three plies apart share `ply % 3`.
LEXICON = {
    # Said where the game picks up straight after a sideline and the move that
    # carries it already has words of its own - a moment's lead-in, in either
    # mode. Short, because it is a prefix and not the sentence.
    'back_to_game': [
        'Back to the game.',
        'Now back to the game as it was played.',
        'Returning to the moves of the game.',
    ],
    # Where the game picks up again on a moment's own board. The story voice
    # (docs/PLAN-NARACIJA.md): the same facts, told.
    'resumed': [
        'Back in the game, {mover} played {move}, and {after}.',
        'Returning to the game, {mover} chose {move}, and {after}.',
        'But the game went on with {move}, and {after}.',
    ],
    'story_first_big_mistake': [
        'This is the first mistake of the game that hands one side a big advantage.',
    ],
    'story_chance_taken': [
        '{mover} takes the chance.',
        'And {mover} does not let the chance go.',
    ],
    'story_chance_missed': [
        '{mover} lets the chance go.',
        'The chance was there, and {mover} misses it.',
    ],
    'story_last_chance_missed': [
        'That was the last chance of the game, and {mover} lets it go.',
    ],
    'story_activity': [
        '{mover} is down material, and has activity for it.',
    ],
    # The mover was better and now it is about even.
    'advantage_gone': [
        'This lets the advantage go.',
        'The advantage is gone after this move.',
        'This throws the advantage away.',
    ],
    # The other side is better now and was not before, short of winning.
    'opponent_better': [
        'This hands the opponent the better game.',
        'After this, the opponent has the better position.',
        'This gives the opponent the upper hand.',
    ],
    # The other side is winning now and was not before.
    'opponent_winning': [
        'A serious mistake: from here the opponent is winning.',
        'A serious mistake, and it leaves the opponent winning.',
        'This is the move that leaves the opponent winning.',
    ],
    # The best move had a forced mate, and this one has none.
    'misses_mate': [
        'This misses a forced mate.',
        'There was a forced mate here, and this move misses it.',
        'This lets a forced mate slip away.',
    ],
}


def mistake_kind(before, after):
    """The pool for a costly move, from its `standing` with the best move and after it.

    None means silence, and two kinds are silent on purpose: a side that was
    better and still is, only less so, and a side already worse that is worse
    still but not yet lost. Neither changes who is better, and in a blitz game
    they are most of the costly moves - ten sentences with different adjectives
    are still ten interruptions.
    """
    if before is None or after is None or after >= before:
        return None
    if after <= -3 < before:
        return 'opponent_winning'
    if before == 4:
        return 'misses_mate'
    if before < 0 or after > 0:
        return None
    return 'advantage_gone' if after == 0 else 'opponent_better'


def _pick(pool, used):
    n = used.get(pool, 0)
    used[pool] = n + 1
    return LEXICON[pool][n % len(LEXICON[pool])]


def filler_words(rows, r, cfg, resumed, used, events=None):
    """The sentence code writes on a game move no chosen moment narrates.

    Most such moves get none: a whole game of sentences like „White plays Nf3"
    is a narration nobody listens to past move ten, and the narrated walk
    already waits over a move with no words. Three moves get one, each built
    from the facts alone and in the voice of what was played:

     * the move a moment's answer just refuted, where the game resumes -
       without it the student is back on the board with no word of why;
     * a costly mistake the model did not choose, when it changes who is
       better (`mistake_kind`) - a swing in silence reads as though nothing
       happened;
     * the last move, for how the game ended.

    [used] counts each lexicon pool's uses in this tutorial.
    """
    row = rows[r]
    played = row['played']
    mover = row['to_move']
    said = []
    if resumed:
        said.append(_pick('resumed', used).format(
            mover=mover, move=played['move'],
            after=_stands(mover, standing(played.get('eval'), mover))))
    elif (played.get('judged') or {}).get('mistake') and row.get('candidates'):
        best = row['candidates'][0]['eval']
        kind = mistake_kind(standing(best, mover), standing(played.get('eval'), mover))
        if kind:
            # „White plays b4. This hands the opponent the better game. With the
            # best move: about even. After this one: Black is slightly better."
            # was the driest sentence of every tutorial; the board plays b4.
            said.append('%s Now %s.' % (
                _pick(kind, used), _stands(mover, standing(played.get('eval'), mover))))
    # The turning points the model did not narrate, said where they happened.
    for event in events or []:
        said.append(_pick('story_' + event['kind'], used).format(mover=mover))
    return ' '.join(said)


def _first_text_key(part, words):
    """The first slot of `part` the student actually reads words from.

    A part is read introduction, then question, then move by move; an empty
    slot is read as nothing at all, so it is skipped rather than written into.
    """
    keys = []
    if part.get('intro'):
        keys.append(part['intro'])
    if part.get('instruction'):
        keys.append(part['instruction'])
    keys.extend(mv['slot'] for mv in (part.get('moves') or []))
    for key in keys:
        if (words.get(key) or '').strip():
            return key
    return keys[0] if keys else None


def _bridged(parts, words, used):
    """„Back to the game" wherever the game resumes straight after a sideline.

    The answer part is a line that was **not** played, and the part after it is
    the game again - a change of footing the student was never told about. In
    whole-game mode the filler already says it (`resumed`), but only where a
    filler exists: two mistakes close together leave none, because the second
    moment's lead-in reaches back past the first, and then the game resumed
    with no word at all. In key-moments mode there is no filler ever, so it was
    missing at every join. The owner asked for it on 14.9.2026, having seen
    both halves of one tutorial.

    Written here rather than asked of the model, and rotated through three
    wordings rather than fixed, because the same sentence three times in one
    tutorial is what a reader stops seeing.

    A part that already carries a `resumed` sentence is left alone: that
    sentence says the same thing and says it with the move.
    """
    out = dict(words)
    after_sideline = False
    for part in parts:
        if after_sideline and not part.get('sideline') and not part.get('resumed'):
            key = _first_text_key(part, out)
            if key:
                said = (out.get(key) or '').strip()
                out[key] = ('%s %s' % (_pick('back_to_game', used), said)).strip()
        after_sideline = bool(part.get('sideline'))
    return out


def whole_game(name, blocks, given, cfg):
    """The chosen moments with every game move between them put back.

    The moments are exactly the parts of `tutorial.json`, words and trims and
    all; nothing here changes what the model wrote or which moments it chose.
    What is added is a part of game moves in front of each moment - from where
    the game last left off to where the moment's lead-in begins - and one after
    the last, to the end of the game. Each added part ends on the position the
    next part starts on, so the student's board carries straight on into the
    lead-in. After a moment's answer the game resumes on the moment's own
    board, with the move that was played there.

    Returns (parts, words, report).
    """
    rows = facts_of(name)['rows']
    end = sum(1 for row in rows if row.get('played'))
    if any(not rows[r].get('played') for r in range(end)):
        # A gap would silently join the moves on either side of it into a line
        # that does not replay.
        raise ValueError('%s: a row inside the game has no move played' % name)
    words = dict(given)
    story = game_story(rows)
    parts = []
    report = {'filler_parts': 0, 'filler_moves': 0, 'filler_sentences': 0,
              'lexicon': {}}

    def fill(start, stop):
        if start >= stop:
            return
        board = chess.Board(rows[start]['fen'])
        intro = 'game.%d.intro' % start
        if start == 0:
            named = [row['book']['opening'] for row in rows
                     if row.get('book') and row['book'].get('opening')]
            if named:
                words[intro] = 'The opening is the %s.' % named[-1]
        moves = []
        for r in range(start, stop):
            san = rows[r]['played']['move']
            sid = 'game.%d' % r
            text = filler_words(rows, r, cfg, resumed=(r == start and start > 0),
                                used=report['lexicon'],
                                events=[e for e in story if e['ply'] == r])
            board.push_san(san)
            if r == end - 1:
                text = (text + ' ' + ('Checkmate.' if board.is_checkmate()
                                      else 'Stalemate.' if board.is_stalemate()
                                      else 'The game ended here.')).strip()
            if text:
                words[sid] = text
                report['filler_sentences'] += 1
            moves.append({'san': san, 'slot': sid, 'ply': r})
        report['filler_moves'] += len(moves)
        report['filler_sentences'] += 1 if words.get(intro) else 0
        return {'kind': 'show', 'fen': rows[start]['fen'],
                'intro': intro, 'moves': moves, 'resumed': start > 0}

    cursor = 0
    report['merged'] = 0
    for moment, mparts in blocks:
        first = mparts[0]
        stop = first['moves'][0]['ply'] if first.get('lead') else moment['index']
        filler = fill(cursor, stop)
        if filler and first.get('lead'):
            # The game moves and the lead-in are one stretch of one game, and
            # as two parts the first was sometimes a single move (`22... bxa3`
            # alone, on g01). The lead-in's opening sentence described the
            # board the filler ends on, so it becomes that last move's comment,
            # after whatever code said there.
            last = filler['moves'][-1]['slot']
            joined = ' '.join(t for t in (words.get(last), words.get(first.get('intro')))
                              if t)
            if joined:
                words[last] = joined
            mparts = [dict(first, fen=filler['fen'], intro=filler['intro'],
                           moves=filler['moves'] + first['moves'],
                           resumed=filler['resumed'])] + mparts[1:]
            report['merged'] += 1
        elif filler:
            parts.append(filler)
            report['filler_parts'] += 1
        parts.extend(mparts)
        cursor = moment['index']
    filler = fill(cursor, end)
    if filler:
        parts.append(filler)
        report['filler_parts'] += 1
    # **The moment the game turned, once more at the end** - point 8 of the
    # owner's live pass, 14.9.2026, and whole-game mode only: in key-moments
    # mode the tutorial is short enough that the recap would repeat a part the
    # student has just read.
    #
    # The same position and the same line, so the words are the ones already
    # written for it and nothing new is asked of the model; only the sentence
    # that frames it is new, and that is written here rather than asked for.
    recap = _recap(blocks, words, rows)
    if recap:
        parts.append(recap)
        report['recap'] = recap['moment']

    left = _masters_departure(parts, words, rows)
    if left is not None:
        report['left_book_at'] = left

    words = _bridged(parts, words, report['lexicon'])
    # The recap is the last part, and the story ends on the game's own last move
    # rather than on a line that was never played.
    words = _framed([p for p in parts if not p.get('moment')], words, given)
    report['parts'] = len(parts)
    return parts, words, report


def _masters_departure(parts, words, rows):
    """Where the game stopped following the masters, said on the last position
    that really was in the database.

    The sentence used to be `filler_words`' last line, written onto the move
    that left the book - which in PGN is the comment on the position *after*
    it. So a student stood on a position no master game had ever reached and
    read „698 master games reached this position and none played it". The
    owner read it on 15.9.2026 and asked for the statistic to be written where
    it is true: on the position before the move, together with the moves the
    database does play there, drawn as arrows.

    The three arrows and the three names are the same three moves
    (`book['alternatives']`, already capped at three by `add_book`), because a
    list of names with no arrows is a list a listener cannot follow and an
    arrow with no name is a line nobody can look up.

    Nothing is mutated in place: a moment's parts are shared with the
    key-moments tutorial, which was assembled before this runs.

    Returns the row index the sentence was written at, or None.
    """
    r = next((i for i, row in enumerate(rows)
              if (row.get('played') or {}).get('left_book') and row.get('book')),
             None)
    if r is None:
        return None
    row = rows[r]
    book = row['book']
    reached = ('1 master game' if book['games'] == 1
               else '%d master games' % book['games'])
    alternatives = book.get('alternatives') or []
    played = ''
    if alternatives:
        played = ' and played %s' % ', '.join(
            '%s %s' % (a['move'], share_words(a['share'])) for a in alternatives)
    sentence = ('Up to here the game followed the masters database: %s reached '
                'this position%s. %s played %s, which none of them did.' % (
                    reached, played, row['to_move'], row['played']['move']))

    board = chess.Board(row['fen'])
    arrows = []
    for a in alternatives:
        move = board.parse_san(a['move'])
        arrows.append([chess.square_name(move.from_square),
                       chess.square_name(move.to_square)])

    for index, part in enumerate(parts):
        moves = part.get('moves') or []
        at = next((i for i, mv in enumerate(moves) if mv.get('ply') == r), None)
        if at is None:
            continue
        if at > 0:
            # The move before it: its comment is read on the position the
            # departing move is about to be played from.
            slot = moves[at - 1]['slot']
            fresh = list(moves)
            if arrows:
                fresh[at - 1] = dict(fresh[at - 1], arrows=arrows)
            parts[index] = dict(part, moves=fresh)
        else:
            # It is the part's first move, so that position is the part's own
            # board and the sentence belongs to the root.
            slot = part.get('intro') or 'game.book.%d' % r
            fresh = dict(part, intro=slot)
            if arrows:
                fresh['arrows'] = arrows
            parts[index] = fresh
        words[slot] = ' '.join(t for t in (words.get(slot), sentence) if t).strip()
        return r
    return None


def _recap(blocks, words, rows):
    """The decisive part again, with a closing sentence."""
    chosen = decisive_moment([m for m, _ in blocks], rows)
    for moment, mparts in blocks:
        if moment['id'] != chosen:
            continue
        answer = next((p for p in mparts
                       if p.get('sideline') and not p.get('alternative')), None)
        if answer is None or not answer.get('moves'):
            return None
        # No pawns counted aloud, and the move played drawn again as it was at
        # the moment itself.
        words['recap.intro'] = (
            'Looking back, the game turned on %s. This is what was there '
            'instead.' % moment['played'])
        fork = next((p for p in mparts if p.get('arrow')), None)
        return {'kind': 'show', 'fen': answer['fen'], 'intro': 'recap.intro',
                'moves': answer['moves'], 'sideline': True,
                'moment': moment['id'], 'arrow': fork and fork['arrow']}
    return None


def reassemble(run_dir):
    """Build both tutorials of a finished run again from its saved answer.

    No model is asked: the answer is `answer.json` as it came, so a change to
    the assembly - the whole-game mode of 13.9.2026 was the first - can be
    tried on every run already made.
    """
    with open(os.path.join(run_dir, 'meta.json'), encoding='utf-8') as fh:
        meta = json.load(fh)
    with open(os.path.join(run_dir, 'answer.json'), encoding='utf-8') as fh:
        answer = fh.read()
    assemble(run_dir, meta['game'], meta, answer,
             (meta.get('skeleton') or {}).get('parameters'))
    with open(os.path.join(run_dir, 'meta.json'), 'w', encoding='utf-8') as fh:
        fh.write(json.dumps(meta, ensure_ascii=False, indent=1))
    return meta['skeleton']


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--assemble':
        for folder in sys.argv[2:]:
            got = reassemble(folder)
            print('%s  %s' % (os.path.basename(folder.rstrip('/\\')), got.get('game')))
    else:
        print(prompt(sys.argv[1] if len(sys.argv) > 1 else 'pvladan_2026-09-12'))
