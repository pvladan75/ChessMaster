"""Write the harness's own answers as the fixtures the app's port is judged against.

    python export_fixtures.py            # write chess_app/test/fixtures/game_tutorial/
    python export_fixtures.py --check    # exit 1 if they are no longer what this harness makes

Step 1 of `docs/PLAN-SKELET.md`. The skeleton is being ported into the app, and
a port is only as good as the thing it is compared with - so the comparison is
not written by hand. For each of the ten games of D this writes one file holding:

 * **the inputs**: the facts file, the plain PGN the prompt quotes, the skeleton
   parameters, and the model's answer exactly as it came (`answer.json` of the
   run whose tutorials the owner imported on 13.9.2026);
 * **what this harness makes of them**: the candidate moments with every slot's
   text and facts, the prompt, the assembly report (chosen, missing and unused
   slots, claims, trims, the whole-game counts), `tutorial.json` and
   `tutorial-game.json`.

Beside them, two case files the harness also answers: `evaluation_words_cases.json`
(`words_for` and `standing` at the edges of `LEVELS`) and `answer_cases.json`
(five bad answers on g01, with the report and tutorials made of each).

The expectations are **computed fresh from the code**, never copied out of a run
folder, and on export they are also compared with that run's files - so a
fixture cannot quietly describe a tutorial the harness no longer produces.

**`--check` is the other half of the drift guard.** The app's gate says the Dart
code agrees with these files; this says these files still agree with
`skeleton.py`. It needs no run folder: the answer is read back out of the
fixture, which is the only copy of it in the repository (`out/` is ignored).
Change the skeleton on either side and one of the two goes red.
"""

import argparse
import json
import os
import shutil
import sys
import tempfile

import skeleton

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
DEST = os.path.join(REPO, 'chess_app', 'test', 'fixtures', 'game_tutorial')

# The run of each game whose tutorials were imported and read on 13.9.2026.
# Named, not globbed: g01 has three runs, and the answer is the one thing a
# fixture cannot recompute.
RUNS = {
    'g01_scandinavian-defense': '20260913-204123',
    'g02_french-defense': '20260913-204148',
    'g03_scandinavian-defense': '20260913-204219',
    'g04_saragossa-opening': '20260913-204320',
    'g05_french-defense': '20260913-204429',
    'g06_zukertort-opening': '20260913-204502',
    'g07_english-opening': '20260913-204527',
    'g08_nimzowitsch-defense': '20260913-204608',
    'g09_caro-kann-defense': '20260913-204645',
    'g10_english-opening': '20260913-204726',
}

ABOUT = ('Written by tools/game_annotate/export_fixtures.py from skeleton.py. '
         'Do not edit by hand: change the harness, then run the script again.')


def run_dir(game):
    return os.path.join(HERE, 'out', 'H-api-deepseek-flash-effort-low-%s-%s'
                        % (game, RUNS[game]))


def read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def expected(game, answer, parameters):
    """What skeleton.py makes of this game and this answer, now."""
    folder = tempfile.mkdtemp(prefix='fixture-')
    try:
        meta = {}
        skeleton.assemble(folder, game, meta, answer, parameters)
        tutorials = {}
        for key, file_name in (('tutorial', 'tutorial.json'),
                               ('tutorialGame', 'tutorial-game.json')):
            path = os.path.join(folder, file_name)
            tutorials[key] = json.loads(read(path)) if os.path.exists(path) else None
    finally:
        shutil.rmtree(folder, ignore_errors=True)
    rows = skeleton.facts_of(game)['rows']
    evals = sorted({e for row in rows for e in
                    [c['eval'] for c in row.get('candidates') or []]
                    + [(row.get('played') or {}).get('eval')] if e is not None})
    return {
        # The two smallest functions, answered for every evaluation this game
        # carries: what a port is proved on first, before any of the rest.
        'wordsFor': {e: skeleton.words_for(e) for e in evals},
        'standing': [[e, mover, skeleton.standing(e, mover)]
                     for e in evals for mover in ('White', 'Black')],
        'moments': skeleton.moments(game, parameters),
        'prompt': skeleton.prompt(game, parameters),
        'report': meta.get('skeleton'),
        'tutorial': tutorials['tutorial'],
        'tutorialGame': tutorials['tutorialGame'],
    }


def fixture(game, answer):
    parameters = dict(skeleton.DEFAULTS)
    return {
        'about': ABOUT,
        'game': game,
        'parameters': parameters,
        'facts': skeleton.facts_of(game),
        'plainPgn': read(os.path.join(skeleton.INPUT_DIR, '%s_plain.pgn' % game)),
        'answer': answer,
        'expected': expected(game, answer, parameters),
    }


# Evaluations no game happens to carry, at the edges of `LEVELS` and in the
# spellings the facts use - so a port that moves a threshold by a hair fails on
# a case the harness answered, not on one written by hand.
BOUNDARIES = ['0.00', '+0.00', '-0.00', '+0.49', '+0.50', '-0.50', '-0.49',
              '+1.49', '+1.50', '-1.50', '+2.99', '+3.00', '-3.00', '-2.99',
              '+12.40', '-7.05', '#1', '#-1', '#12', '#-12', 'draw',
              'checkmate', '', None]

# What assembly does with an answer that is not a good one, on g01. The harness
# reports and does not patch; these hold the port to the same reports.
ANSWER_GAME = 'g01_scandinavian-defense'


def evaluation_cases():
    return {
        'about': ABOUT,
        'wordsFor': [[e, skeleton.words_for(e)] for e in BOUNDARIES],
        'standing': [[e, mover, skeleton.standing(e, mover)]
                     for e in BOUNDARIES + ['unknown'] for mover in ('White', 'Black')],
    }


def answer_cases(answer):
    real = json.loads(answer)
    chosen = real['chosen']
    dropped = dict(real, slots={k: v for k, v in real['slots'].items()
                                if not k.startswith(chosen[0] + '.lead.')})
    worded = dict(real, slots=dict(real['slots'], **{
        '%s.question' % chosen[0]: 'Find the fork that wins the knight with Qxe2+.'}))
    cases = [
        ('the answer is not JSON', 'Here are the moments I chose: m1, m3.'),
        ('a moment chosen that was not offered', json.dumps(dict(real, chosen=[chosen[0], 'm99']))),
        ('only one moment chosen', json.dumps(dict(real, chosen=[chosen[0]]))),
        ('a lead-in left without words', json.dumps(dropped)),
        ('a question that names a move and a fork', json.dumps(worded)),
    ]
    parameters = dict(skeleton.DEFAULTS)

    def judged(text):
        # The moments and the prompt do not depend on the answer, and g01's own
        # fixture already holds them: only what the answer changes is kept.
        made = expected(ANSWER_GAME, text, parameters)
        return {k: made[k] for k in ('report', 'tutorial', 'tutorialGame')}

    return {
        'about': ABOUT,
        'game': ANSWER_GAME,
        'cases': [dict(name=name, answer=text, expected=judged(text))
                  for name, text in cases],
    }


def _share_probe():
    """Shares a facts file can hold (`round(x, 4)`) whose percentage is a tie.

    Two rounding rules decide these and neither ten real games reach: Python's
    `round` is half-to-even only on a value that is *exactly* a half, and `'%.1f'`
    rounds an exact binary tie to even where Dart's `toStringAsFixed` rounds it
    up. Batch 70's report measured both mutations surviving the whole gate.
    """
    import math
    exact, near, tenths = [], [], []
    for k in range(1, 10001):
        s = round(k / 10000.0, 4)
        v = 100 * s
        frac = v - math.floor(v)
        if frac == 0.5 and s >= 0.10:
            exact.append(s)
        elif 0 < abs(frac - 0.5) < 1e-9 and s >= 0.10:
            near.append(s)
        if 0.001 <= s < 0.10 and ('%.1f' % v) != ('%.1f' % (v + 1e-12)):
            tenths.append(s)
    return exact[:6], near[:6], tenths[:8]


def with_facts(facts, fn):
    """Run [fn] with `skeleton.facts_of` answering [facts] - the harness's own
    code over a variant of a game, so an edge case is still the reference's
    answer and not a hand-written one."""
    original = skeleton.facts_of
    skeleton.facts_of = lambda name: facts
    try:
        return fn()
    finally:
        skeleton.facts_of = original


def edge_cases():
    import copy
    exact, near, tenths = _share_probe()
    shares = exact + near + tenths + [0.0009, 0.001, 0.0999, 0.1, 0.1049, 0.9999]

    # A book variant of g01: every book row's shares replaced by the ties above,
    # so the lead-in and question slots that quote the book carry them.
    # Every book row gets the same breaking shares, not a walk through the list:
    # the first version dealt the list out in order, the rows a moment quotes
    # drew only exact halves the port already rounded right, and the test built
    # on it passed against code that was wrong. 0.545 is a near half Python
    # rounds up (`54.50000000000001`), 0.0025 and 0.0125 exact one-decimal ties.
    booked = copy.deepcopy(skeleton.facts_of('g01_scandinavian-defense'))
    for row in booked['rows']:
        book = row.get('book')
        if not book:
            continue
        if (book.get('played') or {}).get('games'):
            book['played']['share'] = 0.545
        for alt, share in zip(book.get('alternatives') or [], (0.0025, 0.0125, 0.545)):
            alt['share'] = share

    # A cost variant of g09, which has more candidates than `max_moments`: the
    # cost of the ninth-most-expensive move made equal to the eighth's, and two
    # more pairs made equal inside the cut, so the order of ties decides which
    # moments are offered and what they are numbered.
    tied = copy.deepcopy(skeleton.facts_of('g09_caro-kann-defense'))
    rows = tied['rows']
    heavy = [i for i, r in enumerate(rows)
             if r.get('played') and r.get('candidates')
             and skeleton._cost_value(r['played'].get('cost_pawns')) >= 1.0
             and r['played'].get('cost_pawns') != 'mate']
    by_cost = sorted(heavy, key=lambda i: rows[i]['played']['cost_pawns'], reverse=True)
    assert len(by_cost) > 9, 'g09 no longer has enough numeric candidates for a tie'
    # the later ply of each pair takes the earlier-sorted one's cost
    for a, b in ((by_cost[7], by_cost[8]), (by_cost[1], by_cost[2]), (by_cost[4], by_cost[5])):
        rows[b]['played']['cost_pawns'] = rows[a]['played']['cost_pawns']
    parameters = dict(skeleton.DEFAULTS)

    book_moments = with_facts(booked, lambda: skeleton.moments('booked', parameters))
    quoted = json.dumps(book_moments)
    for words in ('55%', '0.2%'):
        # A variant nobody quotes is a test that cannot fail.
        assert words in quoted, 'the book variant no longer reaches a slot: %s' % words

    # A question whose answer is castling. The rule „a question names its
    # answer or its square" has two halves, and for every other move the square
    # half catches what the answer half would - `Qxe2+` contains `e2` - so a
    # mutation deleting the answer half survived all 43 tests. Castling is the
    # one move where only that half can decide: `'O-O-O'[-2:]` is `-O`, which a
    # lowercased sentence never contains. g04's position after 13... Rdg8 has
    # O-O-O among its four candidates; swapping only the moves and their lines
    # makes it the best move while every number stays where it was, so the move
    # is legal and its line is the engine's own.
    castled = copy.deepcopy(skeleton.facts_of('g04_saragossa-opening'))
    row = next(r for r in castled['rows'] if r['label'] == '13... Rdg8')
    cands = row['candidates']
    k = next(i for i, c in enumerate(cands) if c['move'].startswith('O-O'))
    for key in ('move', 'line'):
        cands[0][key], cands[k][key] = cands[k][key], cands[0][key]
    castled_moments = with_facts(castled, lambda: skeleton.moments('castled', parameters))
    castle = next(m for m in castled_moments if m['label'] == '13... Rdg8')
    assert castle['asks'] and castle['best'].startswith('O-O'), castle['best']
    other = next(m['id'] for m in castled_moments if m['id'] != castle['id'])
    castled_answer = json.dumps({
        'title': 'Castling', 'description': 'A question naming its answer.',
        'tags': ['castling'], 'chosen': [castle['id'], other],
        'slots': {'%s.question' % castle['id']:
                  'White to move: find the move, %s, that tucks the king away.'
                  % castle['best']}})

    def assembled():
        folder = tempfile.mkdtemp(prefix='fixture-')
        try:
            meta = {}
            skeleton.assemble(folder, 'castled', meta, castled_answer, parameters)
            made = {}
            for key, file_name in (('tutorial', 'tutorial.json'),
                                   ('tutorialGame', 'tutorial-game.json')):
                path = os.path.join(folder, file_name)
                made[key] = json.loads(read(path)) if os.path.exists(path) else None
            made['report'] = meta.get('skeleton')
            return made
        finally:
            shutil.rmtree(folder, ignore_errors=True)

    castled_expected = with_facts(castled, assembled)
    assert ('%s.question names its answer or its square' % castle['id']
            in castled_expected['report']['claims']), castled_expected['report']['claims']

    return {
        'about': ABOUT,
        'castledFacts': castled,
        'castledAnswer': castled_answer,
        'castledExpected': castled_expected,
        'shareWords': [[s, skeleton.share_words(s)] for s in shares],
        'bookFacts': booked,
        'bookMoments': book_moments,
        'tiedFacts': tied,
        'tiedMoments': with_facts(tied, lambda: skeleton.moments('tied', parameters)),
        'tiedPairs': [[rows[a]['label'], rows[b]['label']] for a, b in
                      ((by_cost[7], by_cost[8]), (by_cost[1], by_cost[2]),
                       (by_cost[4], by_cost[5]))],
    }


def extras(answer_of_g01):
    return {'evaluation_words_cases.json': evaluation_cases(),
            'answer_cases.json': answer_cases(answer_of_g01),
            'edge_cases.json': edge_cases()}


def dump(data):
    return json.dumps(data, ensure_ascii=False, indent=1) + '\n'


def first_difference(a, b, path='$'):
    """Where two JSON values part, as a path - a whole-file mismatch says nothing."""
    if type(a) is not type(b) and not (isinstance(a, (int, float)) and isinstance(b, (int, float))):
        return '%s: %s against %s' % (path, type(a).__name__, type(b).__name__)
    if isinstance(a, dict):
        for key in list(a) + [k for k in b if k not in a]:
            if key not in a or key not in b:
                return '%s.%s: present on one side only' % (path, key)
            found = first_difference(a[key], b[key], '%s.%s' % (path, key))
            if found:
                return found
        return None
    if isinstance(a, list):
        if len(a) != len(b):
            return '%s: %d items against %d' % (path, len(a), len(b))
        for i, (x, y) in enumerate(zip(a, b)):
            found = first_difference(x, y, '%s[%d]' % (path, i))
            if found:
                return found
        return None
    if a != b:
        shown = lambda v: repr(v) if len(repr(v)) < 120 else repr(v)[:117] + '...'
        return '%s: %s against %s' % (path, shown(a), shown(b))
    return None


def export():
    os.makedirs(DEST, exist_ok=True)
    total = 0
    answers = {}
    for game in RUNS:
        folder = run_dir(game)
        answer = read(os.path.join(folder, 'answer.json'))
        answers[game] = answer
        data = fixture(game, answer)
        # The run's own files are what the owner imported; a fixture that
        # disagrees with them describes some other tutorial.
        for key, file_name in (('tutorial', 'tutorial.json'),
                               ('tutorialGame', 'tutorial-game.json')):
            made = json.loads(read(os.path.join(folder, file_name)))
            found = first_difference(made, data['expected'][key])
            if found:
                sys.exit('%s: the run folder\'s %s is not what skeleton.py makes now - '
                         're-assemble the run first (python skeleton.py --assemble). %s'
                         % (game, file_name, found))
        text = dump(data)
        with open(os.path.join(DEST, '%s.json' % game), 'w', encoding='utf-8',
                  newline='\n') as fh:
            fh.write(text)
        total += len(text.encode('utf-8'))
        report = data['expected']['report']
        print('%-26s %2d moments offered, %d chosen, %d parts / %d parts, %d claims, %d KB'
              % (game, len(data['expected']['moments']), len(report.get('chosen') or []),
                 len(data['expected']['tutorial']['positionList']),
                 len(data['expected']['tutorialGame']['positionList']),
                 len(report.get('claims') or []), len(text.encode('utf-8')) // 1024))
    for file_name, data in extras(answers[ANSWER_GAME]).items():
        text = dump(data)
        with open(os.path.join(DEST, file_name), 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(text)
        total += len(text.encode('utf-8'))
        print('%-26s %d KB' % (file_name, len(text.encode('utf-8')) // 1024))
    print('%d fixtures and %d case files, %d KB -> %s' % (
        len(RUNS), len(extras(answers[ANSWER_GAME])), total // 1024,
        os.path.relpath(DEST, REPO)))


def check():
    stale = 0
    for game in RUNS:
        path = os.path.join(DEST, '%s.json' % game)
        if not os.path.exists(path):
            print('%s: missing' % game)
            stale += 1
            continue
        stored = json.loads(read(path))
        fresh = fixture(game, stored['answer'])
        found = first_difference(stored, fresh)
        if found:
            print('%s: STALE - %s' % (game, found))
            stale += 1
        else:
            print('%s: current' % game)
    g01 = os.path.join(DEST, '%s.json' % ANSWER_GAME)
    if os.path.exists(g01):
        for file_name, fresh in extras(json.loads(read(g01))['answer']).items():
            path = os.path.join(DEST, file_name)
            found = ('missing' if not os.path.exists(path)
                     else first_difference(json.loads(read(path)), fresh))
            print('%s: %s' % (file_name, 'STALE - %s' % found if found else 'current'))
            stale += 1 if found else 0
    if stale:
        print('%d of %d fixtures are not what the harness makes now; '
              'run export_fixtures.py' % (stale, len(RUNS)))
    sys.exit(1 if stale else 0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--check', action='store_true')
    if parser.parse_args().check:
        check()
    else:
        export()
