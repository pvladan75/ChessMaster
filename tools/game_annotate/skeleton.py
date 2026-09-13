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
    size = abs(value)
    if size < 0.5:
        return 'about even'
    if size < 1.5:
        return '%s is slightly better' % side
    if size < 3.0:
        return '%s is clearly better' % side
    return '%s is winning' % side


def material(board):
    white = sum(VALUE.get(p.piece_type, 0) for p in board.piece_map().values() if p.color)
    black = sum(VALUE.get(p.piece_type, 0) for p in board.piece_map().values() if not p.color)
    return white - black


def play(board, san):
    """Play [san] on [board]; the facts about that one move, as data and words."""
    move = board.parse_san(san)
    mover = 'White' if board.turn else 'Black'
    piece = board.piece_at(move.from_square)
    captured = board.piece_at(move.to_square)
    if board.is_en_passant(move):
        captured = chess.Piece(chess.PAWN, not board.turn)
    words = ['%s plays %s: the %s from %s to %s' % (
        mover, san, NAME[piece.piece_type], chess.square_name(move.from_square),
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
                text = '%s; this is the game move; afterwards %s' % (
                    info['words'], words_for(game_move.get('eval')))
                if rows[r].get('motifs_after_played'):
                    text += '; on the board after it: %s' % rows[r]['motifs_after_played']
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
            parts.append({'kind': 'show', 'fen': rows[start]['fen'], 'black': black,
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
            parts.append({'kind': 'ask_move', 'fen': row['fen'], 'black': black,
                          'instruction': qid, 'solution': best['move'],
                          'accepted': [c['move'] for c in correct[1:]]})

        # The answer: the best line.
        board = chess.Board(row['fen'])
        before = material(board)
        moves = []
        for k, san in enumerate(best['line'].split()[:cfg['answer_plies']], 1):
            sid = '%s.answer.%d' % (mid, k)
            info = play(board, san)
            slots[sid] = info['words'] + ('; this is the best move' if k == 1
                                          else '; a move of the best line')
            facts[sid] = dict(info, motifs='')
            moves.append({'san': san, 'slot': sid})
        intro = '%s.answer.intro' % mid
        slots[intro] = (
            'the answer: %s plays %s instead of the game move %s. At the end of the '
            'best line %s; material White minus Black goes from %+d to %+d over the '
            'moves shown. The game move %s.' % (
                mover, best['move'], played['move'], words_for(best['eval']),
                before, material(board), cost_text(played)))
        change = material(board) - before
        facts[intro] = {'gain': max(0, change if not black else -change), 'mate': False,
                        'fork': False, 'pin': False, 'motifs': ''}
        parts.append({'kind': 'show', 'fen': row['fen'], 'black': black,
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
            'best': best['move'], 'asks': asks,
            'correct': [c['move'] for c in correct], 'board': board_here,
            'parts': parts, 'slots': slots, 'facts': facts,
        })
    return out


# --- The prompt ---------------------------------------------------------------

PROMPT = """# Write the words for a chess tutorial

A trainer's game is being turned into a tutorial that a student of 13 or older
walks through alone, on a board, with every sentence read aloud. The student plays
in a club and knows how the pieces move and what a fork and a pin are.

**Everything except the words is already done**, by a program and a chess
engine: every position, every move, every question and every correct answer.
None of it can change. You do two things.

1. **Choose** two or three of the moments below - the ones a student learns the
   most from - by their ids.
2. **Write** a title (under 60 characters), a one-sentence description, one or
   two tags, and the text of **every slot of the moments you chose**, and of no
   other slot.

## Rules for every sentence

- **Say only what the facts beside the slot say.** Do not judge a move yourself.
  A move wins material only if its facts say it captures something and the
  material count bears it out; a fork or a pin exists only if the facts name it.
- **No numbers for evaluations.** The facts turn them into words; use the words.
- **A move slot is about that one move**, not the move after it.
- **A question never names its answer**, neither the move nor the square it goes
  to. It says what the student should look for.
- One or two short sentences per slot, at most 140 characters.
- Teach, do not score: say what to notice, not only that a move was bad.

## Answer format

Return one JSON object and nothing else - no prose, no code fence:

{{"title": "...", "description": "...", "tags": ["..."], "chosen": ["m2", "m5"],
 "slots": {{"m2.lead.intro": "...", "m2.lead.1": "...", "m2.question": "...", "...": "..."}}}}

## The game

```
{game}
```

## The moments

{moments}
"""


def prompt(name, cfg=None):
    with open(os.path.join(INPUT_DIR, '%s_plain.pgn' % name), encoding='utf-8') as fh:
        game = fh.read().strip()
    blocks = []
    for m in moments(name, cfg):
        head = ('### %s - at %s, %s to move\nIn the game %s was played and it %s; '
                'the best move was %s. %s' % (
                    m['id'], m['label'], m['mover'], m['played'], m['cost_text'], m['best'],
                    ('There is a question here; correct answers: %s.' % ', '.join(m['correct']))
                    if m['asks'] else
                    'No question here: too many moves are about as good.'))
        if m['board']:
            head += '\nOn the board: %s' % m['board']
        lines = [head, '', 'Slots, in the order the student meets them:']
        for part in m['parts']:
            for sid in ([part.get('intro')] if part.get('intro') else []) + \
                       ([part['instruction']] if part.get('instruction') else []) + \
                       [mv['slot'] for mv in part.get('moves', [])]:
                lines.append('- `%s`: %s' % (sid, m['slots'][sid]))
        blocks.append('\n'.join(lines))
    return PROMPT.format(game=game, moments='\n\n'.join(blocks))


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
    return found


def assemble(run_dir, name, meta, answer_text, cfg=None):
    """Build `tutorial.json` from the skeleton and the model's words."""
    cfg = dict(DEFAULTS, **(cfg or {}))
    report = {'parameters': cfg, 'problems': [], 'missing_slots': [],
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
    steps = []
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
        for part in parts:
            step = {'title': 'Part %d' % (len(steps) + 1), 'fen': part['fen'],
                    'kind': part['kind']}
            if part['black']:
                step['blackOrientation'] = True
            if part['kind'] == 'show':
                step['pgn'] = _pgn(part, given)
            else:
                step['instruction'] = given.get(part['instruction'], '')
                step['solutionSan'] = part['solution']
                if part['accepted']:
                    step['acceptedSans'] = part['accepted']
                step['pgn'] = ''
            steps.append(step)
    report['unused_slots'] = sorted(set(given) - wanted)
    report['trimmed'] = trimmed

    tutorial = {
        'title': _clean(answer.get('title')),
        'description': _clean(answer.get('description')),
        'tags': [_clean(t) for t in (answer.get('tags') or [])][:2],
        'language': 'en',
        'positionList': steps,
    }
    with open(os.path.join(run_dir, 'tutorial.json'), 'w', encoding='utf-8') as fh:
        json.dump(tutorial, fh, ensure_ascii=False, indent=2)


if __name__ == '__main__':
    print(prompt(sys.argv[1] if len(sys.argv) > 1 else 'pvladan_2026-09-12'))
