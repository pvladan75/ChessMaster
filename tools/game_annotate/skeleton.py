"""Arm H: Python and Stockfish build the tutorial, the model writes the words.

    python run_api.py H --provider deepseek --model deepseek-flash --reasoning-effort low
    python skeleton.py pvladan_2026-09-12            # print the prompt, call nothing

The owner's design of 13.9.2026. Every earlier arm let a model decide something
a program can decide exactly, and every error of the day lived in one of those
decisions: a FEN rebuilt in its head, a move copied a letter wrong, a question
on a position with four equal answers, a „better move" that was fourth. So here
the program decides all of that from the facts `make_facts.py` computed:

 * **candidate moments** - positions where the move played cost at least
   `min_cost` pawns, the `max_moments` most expensive of them;
 * for each, **a block of parts**: the last `lead_plies` moves of the game
   leading into it, a question when the moves within `near` pawns of the best
   number at most `max_correct` (all of them accepted), and the answer as the
   best line from the facts;
 * every FEN, every move in the board's own SAN, every answer.

The model is left with the one decision it did well - which moments teach a
student the most - and the words: it chooses two or three moments by id and fills
the empty slots of those, each slot shown with the facts it may speak from.

**The parameters are applied here, never stored in the facts.** A facts file is
raw engine output, so a threshold can change without analysing a game again.

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
import os
import re
import sys

import chess
import chess.pgn

HERE = os.path.dirname(os.path.abspath(__file__))
INPUT_DIR = os.path.join(HERE, 'input')

DEFAULTS = {
    'min_cost': 1.0,       # pawns a move must have cost to be a moment
    'near': 0.3,           # pawns within the best that still count as correct
    'max_correct': 3,      # more equally good moves than this, and no question
    'max_moments': 8,      # candidates offered to the model
    'lead_plies': 3,       # game moves shown before a moment
    'answer_plies': 4,     # moves of the best line shown as the answer
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


def play(board, san, verb='plays'):
    """Play [san] on [board]; the facts about that one move, as data and words.

    `verb` is how the move is introduced, and it is the whole of how a
    student tells what happened from what should have. A move of the best
    line never happened, and "Black plays Qf6" reads exactly like the game -
    which is what a student met on 13.9.2026, one click after "instead of
    the game move bxa3". The model copies the voice it is given, so the
    voice is what carries it.
    """
    move = board.parse_san(san)
    mover = 'White' if board.turn else 'Black'
    piece = board.piece_at(move.from_square)
    captured = board.piece_at(move.to_square)
    if board.is_en_passant(move):
        captured = chess.Piece(chess.PAWN, not board.turn)
    words = ['%s %s %s: the %s from %s to %s' % (
        mover, verb, san, NAME[piece.piece_type], chess.square_name(move.from_square),
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


def moments(name, cfg=None):
    """The candidate moments of a game, each with its parts and its slots."""
    cfg = dict(DEFAULTS, **(cfg or {}))
    rows = facts_of(name)['rows']

    heavy = [i for i, row in enumerate(rows)
             if row.get('played') and row.get('candidates')
             and _cost_value(row['played'].get('cost_pawns')) >= cfg['min_cost']]
    picked = sorted(sorted(heavy, key=lambda i: _cost_value(rows[i]['played']['cost_pawns']),
                           reverse=True)[:cfg['max_moments']])

    out = []
    for number, i in enumerate(picked, 1):
        mid = 'm%d' % number
        row = rows[i]
        mover = row['to_move']
        black = mover == 'Black'
        best = row['candidates'][0]
        near = int(round(cfg['near'] * 100))
        correct = [c for c in row['candidates']
                   if best['value_for_mover'] - c['value_for_mover'] <= near]
        asks = len(correct) <= cfg['max_correct']
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
            slots[intro] = ('the board before these moves (%s to move); material White '
                            'minus Black is %+d before them and %+d after them' % (
                                rows[start]['to_move'], before, material(board)))
            facts[intro] = {'gain': 0, 'mate': False, 'fork': False, 'pin': False,
                            'motifs': ''}
            parts.append({'kind': 'show', 'fen': rows[start]['fen'],
                          'intro': intro, 'moves': moves, 'lead': True})

        # The question.
        if asks:
            qid = '%s.question' % mid
            slots[qid] = (
                '%s to move. The best move is %s, and afterwards %s. Also counted '
                'correct: %s. What follows the best move: %s. In the game %s was '
                'played instead; it %s and afterwards %s.%s Ask for the '
                'move in one sentence, without naming it or its destination square.' % (
                    mover, best['move'], words_for(best['eval']),
                    ', '.join(c['move'] for c in correct[1:]) or 'nothing else',
                    best['line'], played['move'], cost_text(played),
                    words_for(played.get('eval')),
                    (' On the board: %s.' % board_here) if board_here else ''))
            facts[qid] = {'gain': 0, 'mate': False, 'fork': False, 'pin': False,
                          'motifs': board_here or '', 'question': True,
                          'names': [best['move'], best['move'].rstrip('+#')[-2:]]}
            parts.append({'kind': 'ask_move', 'fen': row['fen'],
                          'instruction': qid, 'solution': best['move'],
                          'accepted': [c['move'] for c in correct[1:]]})

        # The answer: the best line.
        board = chess.Board(row['fen'])
        before = material(board)
        moves = []
        for k, san in enumerate(best['line'].split()[:cfg['answer_plies']], 1):
            sid = '%s.answer.%d' % (mid, k)
            info = play(board, san,
                        verb='should have played' if k == 1
                        else 'would answer')
            # A move of the best line did not happen, and „this is the best
            # move" does not say so. On 13.9.2026 a student met „Black plays
            # Qf6 instead of the game move bxa3" and, one click later, „Black
            # plays Qf6 … this is the best move" - the same verb for what
            # happened and for what should have. The model copies the voice it
            # is given, so the voice it is given carries the difference now.
            slots[sid] = info['words'] + (
                '; not played - the best move the game missed' if k == 1
                else '; not played - the line goes on')
            facts[sid] = dict(info, motifs='')
            moves.append({'san': san, 'slot': sid})
        intro = '%s.answer.intro' % mid
        slots[intro] = (
            'the answer: %s should have played %s instead of the game move %s, '
            'which is what actually happened. At the end of the '
            'best line %s; material White minus Black goes from %+d to %+d over the '
            'moves shown. The game move %s.' % (
                mover, best['move'], played['move'], words_for(best['eval']),
                before, material(board), cost_text(played)))
        change = material(board) - before
        facts[intro] = {'gain': max(0, change if not black else -change), 'mate': False,
                        'fork': False, 'pin': False, 'motifs': ''}
        parts.append({'kind': 'show', 'fen': row['fen'],
                      'intro': intro, 'moves': moves})

        # Every slot's facts carry the very text the model was shown beside it,
        # so a claim is judged against what it was allowed to say rather than
        # against a narrower list. Without this the check flagged „mate" in
        # slots whose facts read „Black mates in 5".
        for sid, text in slots.items():
            facts[sid]['text'] = text

        out.append({
            'id': mid, 'index': i, 'label': row['label'], 'mover': mover,
            'played': played['label'], 'cost': played.get('cost_pawns'),
            'cost_text': cost_text(played),
            'left_book': bool(played.get('left_book')),
            'best': best['move'], 'asks': asks,
            'correct': [c['move'] for c in correct], 'board': board_here,
            'parts': parts, 'slots': slots, 'facts': facts,
        })
    return out


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
            for sid in ([part.get('intro')] if part.get('intro') else []) + \
                       ([part['instruction']] if part.get('instruction') else []) + \
                       [mv['slot'] for mv in part.get('moves', [])]:
                slots.append({'id': sid, 'text': m['slots'][sid]})
        request_moments.append({
            'id': m['id'], 'label': m['label'], 'mover': m['mover'],
            'played': m['played'], 'cost_text': m['cost_text'], 'best': m['best'],
            'asks': m['asks'], 'correct': m['correct'], 'left_book': m['left_book'],
            'board': m['board'], 'slots': slots,
        })
    return {'game': game,
            'opening': book_summary(facts_of(name)['rows']) or None,
            'moments': request_moments}


def prompt_from_request(request):
    """The prompt, from what the app sends - the one place it is written."""
    blocks = []
    for m in request['moments']:
        head = ('### %s - at %s, %s to move\nIn the game %s was played and it %s; '
                'the best move was %s. %s' % (
                    m['id'], m['label'], m['mover'], m['played'], m['cost_text'], m['best'],
                    ('There is a question here; correct answers: %s.' % ', '.join(m['correct']))
                    if m['asks'] else
                    'No question here: too many moves are about as good.'))
        if m['left_book']:
            # The hook a moment inside the book is for: not "you
            # blundered", but "this is where you stopped playing what
            # masters play".
            head += '\nThis is the move that left the masters database.'
        if m['board']:
            head += '\nOn the board: %s' % m['board']
        lines = [head, '', 'Slots, in the order the student meets them:']
        lines += ['- `%s`: %s' % (slot['id'], slot['text']) for slot in m['slots']]
        blocks.append('\n'.join(lines))
    opening = request.get('opening') or ''
    return PROMPT.format(
        game=request['game'], opening=(opening + '\n\n') if opening else '',
        moments='\n\n'.join(blocks))


def prompt(name, cfg=None):
    return prompt_from_request(words_request(name, cfg))


# --- Assembly -----------------------------------------------------------------

def _clean(text):
    text = str(text or '').replace('{', '(').replace('}', ')')
    return re.sub(r'\s+', ' ', text).strip()


def _pgn(part, words):
    game = chess.pgn.Game()
    game.setup(chess.Board(part['fen']))
    game.comment = words.get(part['intro'], '') if part.get('intro') else ''
    node = game
    for mv in part['moves']:
        node = node.add_variation(node.board().parse_san(mv['san']))
        node.comment = words.get(mv['slot'], '')
    exporter = chess.pgn.StringExporter(headers=False, variations=False, comments=True)
    text = game.accept(exporter).strip()
    if not text.endswith('*'):
        text += ' *'
    return text


def _claims(sid, text, facts):
    """What a sentence says that its facts do not bear out."""
    found = []
    low = text.lower()
    # What the model was shown beside this slot, and the motifs. A word is
    # backed when it is there; the rule it was given is „say only what the
    # facts beside the slot say", so that is the rule it is held to.
    shown = (facts.get('text', '') + ' ' + facts.get('motifs', '')).lower()
    if re.search(r'[+-]\d+\.\d+|\b\d+\.\d+\b', text):
        found.append('%s prints an evaluation' % sid)
    if re.search(r'\b(win|wins|won|winning a)\b', low) and 'winning' not in low \
            and not facts.get('gain') and not facts.get('mate') and not facts.get('question') \
            and 'winning' not in shown:
        found.append('%s says a move wins, and the facts show no material won' % sid)
    if re.search(r'\b(checkmate|mates|mate)\b', low) and not facts.get('mate') \
            and 'mate' not in shown and not facts.get('question'):
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
    if facts.get('question'):
        answer = facts['names'][0].rstrip('+#')
        if answer and answer in text or facts['names'][1] in low:
            found.append('%s names its answer or its square' % sid)
        # And any other move written in notation. A bare square ("the pawn on
        # b7") is a place on the board and fair to name; a move with its piece
        # letter or its capture is notation, and on 13.9.2026 two questions of
        # twenty-nine named the move played in the game - which the slot hands
        # the model, and which eliminates a candidate as surely as the answer
        # would.
        others = [m for m in re.findall(
            r'\b([KQRBN][a-h]?[1-8]?x?[a-h][1-8][+#]?|[a-h]x[a-h][1-8][+#]?'
            r'|O-O(?:-O)?)\b', text) if m.rstrip('+#') != answer]
        if others:
            found.append('%s names %s, a move that is not the answer'
                         % (sid, ', '.join(sorted(set(others)))))
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
        for sid in moment['slots']:
            if sid not in used:
                continue
            wanted.add(sid)
            if not given.get(sid):
                report['missing_slots'].append(sid)
            else:
                report['claims'].extend(_claims(sid, given[sid], moment['facts'][sid]))
        blocks.append((moment, parts))
    report['unused_slots'] = sorted(set(given) - wanted)
    report['trimmed'] = trimmed

    head = {
        'title': _clean(answer.get('title')),
        'description': _clean(answer.get('description')),
        'tags': [_clean(t) for t in (answer.get('tags') or [])][:2],
        'language': 'en',
    }
    moments_only = [part for _, parts in blocks for part in parts]
    _write(run_dir, 'tutorial.json', dict(head, positionList=_steps(moments_only, given)))

    parts, words, report['game'] = whole_game(name, blocks, given, cfg)
    _write(run_dir, 'tutorial-game.json',
           dict(head, title=head['title'] + GAME_TITLE, positionList=_steps(parts, words)))


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
        if part['kind'] == 'show':
            step['pgn'] = _pgn(part, words)
        else:
            step['instruction'] = words.get(part['instruction'], '')
            step['solutionSan'] = part['solution']
            if part['accepted']:
                step['acceptedSans'] = part['accepted']
            step['pgn'] = ''
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
    'resumed': [
        'Back in the game, {mover} played {move} instead; afterwards {after}.',
        'Returning to the game, {mover} played {move} instead; afterwards {after}.',
        'Back on the board, the game continued with {move} instead; afterwards {after}.',
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


def filler_words(rows, r, cfg, resumed, used):
    """The sentence code writes on a game move no chosen moment narrates.

    Most such moves get none: a whole game of sentences like „White plays Nf3"
    is a narration nobody listens to past move ten, and the narrated walk
    already waits over a move with no words. Four moves get one, each built
    from the facts alone and in the voice of what was played:

     * the move a moment's answer just refuted, where the game resumes -
       without it the student is back on the board with no word of why;
     * a costly mistake the model did not choose, when it changes who is
       better (`mistake_kind`) - a swing in silence reads as though nothing
       happened;
     * the move that left the masters database, which the per-position
       statistics could only ever say when a lead-in happened to reach it
       (one game in ten, measured) and which a whole game always reaches;
     * the last move, for how the game ended.

    [used] counts each lexicon pool's uses in this tutorial.
    """
    row = rows[r]
    played = row['played']
    mover = row['to_move']
    after = words_for(played.get('eval'))
    said = []
    if resumed:
        # `words_for` can answer without a subject, and „afterwards about even"
        # is what three of ten games said before this.
        said.append(_pick('resumed', used).format(
            mover=mover, move=played['move'],
            after=('it is ' + after) if after in ('about even', 'a draw', 'checkmate')
            else 'the evaluation is unknown' if after == 'unknown' else after))
    elif _cost_value(played.get('cost_pawns')) >= cfg['min_cost'] and row.get('candidates'):
        best = row['candidates'][0]['eval']
        kind = mistake_kind(standing(best, mover), standing(played.get('eval'), mover))
        if kind:
            said.append('%s plays %s. %s With the best move: %s. After this one: %s.' % (
                mover, played['move'], _pick(kind, used), words_for(best), after))
    book = row.get('book')
    if played.get('left_book') and book:
        said.append('This move left the masters database: %s reached this position '
                    'and none played it.' % ('1 master game' if book['games'] == 1
                                             else '%d master games' % book['games']))
    return ' '.join(said)


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
                                used=report['lexicon'])
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
                'intro': intro, 'moves': moves}

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
                           moves=filler['moves'] + first['moves'])] + mparts[1:]
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
    report['parts'] = len(parts)
    return parts, words, report


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
