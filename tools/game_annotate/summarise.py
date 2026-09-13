"""One table across many runs, around the four questions a batch is run to answer.

    python summarise.py out/H-api-deepseek-flash-*          # a table and the totals
    python summarise.py out/H-* --csv rows.csv              # the same, as data
    python summarise.py out/H-* --no-grade                  # skip the Dart grader

`review_run.py` reads one run and prints everything a person still has to read.
That is the right tool for three runs and the wrong one for thirty: nobody reads
thirty. This answers instead the four questions the owner and the lead agreed a
batch is for, on 13.9.2026, before the batch was run - which is the point of
agreeing them first, since a metric chosen after the numbers are in is a metric
chosen to suit them.

**1. Moment yield.** Does a game have two or three blunders worth teaching at
all? The skeleton offers moments where the move played cost at least a pawn, and
a moment can carry a question only when at most three moves are within 0.3 of
the best. A game with no askable moment cannot become the kind of tutorial this
pipeline is for, and nothing before this counted how often that happens.

**2. Selection quality.** Given five or more candidates, does the model choose
well? Two things are measurable without an opinion: how many of the moments it
chose can ask a question, and where the ones it chose stand in the order of what
they cost. A model that takes three silent moments while five askable ones sit in
front of it is choosing badly, and the cost-rank says whether it took the
teachable mistakes or the first three on the page.

**3. Move ambiguity.** A question is only fair when the answer is the answer. It
is counted here as the margin the analysis sent gives the best move, and whether
the moves within 0.3 of it are in `acceptedSans` - a question with a 0.05-pawn
margin and one accepted answer marks a student wrong for a move the engine
cannot separate.

**4. Opening header.** The prompt carries one line naming the opening and the
move that left the masters database. This says whether the model used it - in
the title, in the description, or in a sentence - which is what decides whether
that line is context or noise.

Nothing here judges whether a sentence is *true*: that still needs a person, and
`review_run.py` is where they read it.
"""

import argparse
import glob
import io
import json
import os
import re
import subprocess
import sys

import check_positions
import skeleton

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
NEAR = skeleton.DEFAULTS['near']


def load(path):
    with io.open(path, encoding='utf-8') as fh:
        return json.load(fh)


def grade(run_dir):
    """CLEAN / DAMAGED / REFUSED, from the app's own reader."""
    app = os.path.join(REPO, 'chess_app')
    try:
        out = subprocess.run(
            ['dart', 'run', 'tool/grade_tutorial.dart', run_dir],
            cwd=app, capture_output=True, text=True, encoding='utf-8',
            errors='replace', timeout=300)
    except Exception as exc:
        return 'grader failed (%s)' % exc
    for word in ('CLEAN', 'DAMAGED', 'REFUSED'):
        if re.search(r'^%s\b' % word, out.stdout or '', re.M):
            return word
    return 'no verdict'


_MOMENTS = {}


def moments_of(game):
    """The skeleton's moments, built once per game rather than once per use."""
    if game not in _MOMENTS:
        _MOMENTS[game] = skeleton.moments(game)
    return _MOMENTS[game]


def moment_yield(game):
    """(offered, askable) - what the skeleton had to offer for this game."""
    moments = moments_of(game)
    return len(moments), sum(1 for m in moments if m['asks'])


def selection(meta, game):
    """(chosen, askable among them, their mean rank by cost, 1 = the costliest)."""
    moments = moments_of(game)
    by_id = {m['id']: m for m in moments}
    order = sorted(moments, key=lambda m: skeleton._cost_value(m['cost']),
                   reverse=True)
    rank = {m['id']: i + 1 for i, m in enumerate(order)}
    chosen = [c for c in ((meta.get('skeleton') or {}).get('chosen') or [])
              if c in by_id]
    if not chosen:
        return 0, 0, None
    asks = sum(1 for c in chosen if by_id[c]['asks'])
    return len(chosen), asks, sum(rank[c] for c in chosen) / float(len(chosen))


def questions(run_dir, game, parts):
    """Per question: the margin the analysis sent, and whether the ties are
    accepted. Returns (count, thin, unfair)."""
    sent = check_positions.facts_rows(game)
    count = thin = unfair = 0
    if not sent:
        return 0, 0, 0
    for part in parts:
        if part.get('kind') != 'ask_move':
            continue
        row = sent.get(' '.join((part.get('fen') or '').split()[:2]))
        cands = (row or {}).get('candidates') or []
        if not cands:
            continue
        count += 1
        best = cands[0]['value_for_mover']
        near = int(round(NEAR * 100))
        ties = [c['move'] for c in cands[1:]
                if best - c['value_for_mover'] <= near]
        if ties:
            thin += 1
            accepted = set(part.get('acceptedSans') or [])
            if not set(ties) <= accepted:
                unfair += 1
    return count, thin, unfair


def book_reach(run_dir, game, tutorial):
    """(positions in the database, prompt slots offering them, sentences using
    one).

    Not one of the four agreed questions - it measures the reach of the change
    that landed the same evening. The statistics belong to the first four to six
    moves and the moments are in the middlegame, so on the three games C was
    written against a prompt slot mentioned the book in one of three.

    **Offered and used are two counts, not one.** The first version counted
    skeleton slot texts and reported them as "tutorials with a slot that names
    the book" - but a skeleton slot is what the model was told, and whether it
    said any of it back is the other question entirely, and the one that decides
    whether the statistics are worth sending. Metric 4 beside this already reads
    the model's own words; this one was reading the prompt and labelled as if it
    were not.
    """
    facts = skeleton.facts_of(game)
    # The prompt the run was actually sent, not one rebuilt from today's facts.
    # The first version rebuilt it, and on a run made before the statistics
    # existed it reported slots that run was never given - the same fault the
    # facts stamp was added for two commits ago, in a tool written after it.
    path = os.path.join(run_dir, 'prompt.md')
    offered = 0
    if os.path.exists(path):
        with io.open(path, encoding='utf-8') as fh:
            offered = sum(1 for line in fh
                          if line.lstrip().startswith('- `m') and 'master game' in line)
    written = sum(1 for p in tutorial.get('positionList') or []
                  if re.search(r'master game|masters (database|play)',
                               (p.get('instruction') or '') + ' '
                               + (p.get('pgn') or ''), re.I))
    return facts.get('in_book', 0), offered, written


def opening_used(run_dir, game, tutorial):
    """Where the header's opening line shows up in what the model wrote."""
    line = skeleton.book_summary(skeleton.facts_of(game)['rows'])
    if not line:
        return '-', ''
    name = re.search(r'The opening is the ([^.]+)', line)
    if not name:
        return '-', line
    # The distinctive half: "French Defense: La Bourdonnais Variation" is used
    # when "French" appears, and a model that writes "Defense" has said nothing.
    words = [w for w in re.split(r'[^A-Za-z]+', name.group(1))
             if len(w) > 3 and w.lower() not in
             ('defense', 'defence', 'game', 'opening', 'variation', 'attack',
              'system', 'line', 'main')]
    if not words:
        return '-', line
    where = []
    for field in ('title', 'description'):
        text = (tutorial.get(field) or '').lower()
        if any(w.lower() in text for w in words):
            where.append(field)
    body = ' '.join((p.get('instruction') or '') + ' ' + (p.get('pgn') or '')
                    for p in tutorial.get('positionList') or []).lower()
    if any(w.lower() in body for w in words):
        where.append('a sentence')
    return ('+'.join(where) if where else 'no'), line


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('runs', nargs='+')
    parser.add_argument('--csv')
    parser.add_argument('--no-grade', action='store_true')
    cfg = parser.parse_args()

    dirs = []
    for pattern in cfg.runs:
        dirs.extend(sorted(d for d in glob.glob(pattern) if os.path.isdir(d)))
    if not dirs:
        sys.exit('no run directories matched')

    rows = []
    for run_dir in dirs:
        meta_path = os.path.join(run_dir, 'meta.json')
        tut_path = os.path.join(run_dir, 'tutorial.json')
        if not os.path.exists(meta_path):
            continue
        meta = load(meta_path)
        game = meta.get('game')
        row = {'run': os.path.basename(run_dir), 'game': game,
               'seconds': meta.get('seconds'),
               'verdict': 'no tutorial.json'}
        if os.path.exists(tut_path):
            tutorial = load(tut_path)
            parts = tutorial.get('positionList') or []
            row['verdict'] = '(not graded)' if cfg.no_grade else grade(run_dir)
            row['offered'], row['askable'] = moment_yield(game)
            row['chosen'], row['chose_asking'], row['rank'] = selection(meta, game)
            row['questions'], row['thin'], row['unfair'] = questions(
                run_dir, game, parts)
            row['opening'], row['opening_line'] = opening_used(
                run_dir, game, tutorial)
            (row['in_book'], row['book_offered'],
             row['book_written']) = book_reach(run_dir, game, tutorial)
            row['drifted'] = bool(check_positions.facts_drift(run_dir, game))
            row['parts'] = len(parts)
        rows.append(row)

    print('%-24s %-8s %7s %7s %6s %5s %11s %6s %s' % (
        'game', 'verdict', 'moments', 'chosen', 'rank', 'quest', 'ambiguous',
        'book*', 'opening used'))
    print('-' * 110)
    for r in rows:
        if 'offered' not in r:
            print('%-26s %-9s  %s' % (r['game'][:26], r['verdict'], ''))
            continue
        print('%-23s%1s %-8s %3d/%-3d %3d/%-3d %6s %5d %11s %6s %s' % (
            r['game'][:23], '!' if r.get('drifted') else ' ', r['verdict'],
            r['askable'], r['offered'], r['chose_asking'], r['chosen'],
            '%.1f' % r['rank'] if r['rank'] else '-',
            r['questions'],
            '%d thin,%d bad' % (r['thin'], r['unfair']),
            '%d>%d/%d' % (r['book_written'], r['book_offered'],
                          r['in_book']),
            r['opening']))

    full = [r for r in rows if 'offered' in r]
    if full:
        print('-' * 110)
        drifted = [r for r in full if r.get('drifted')]
        if drifted:
            print('! %d run(s) were given a different analysis from the one on '
                  "disk; their moment counts and ranks are read against today's "
                  'facts, not the ones they saw' % len(drifted))
        print('1. moment yield      : %d of %d games offer 2+ askable moments, '
              '%d offer none' % (
                  sum(1 for r in full if r['askable'] >= 2), len(full),
                  sum(1 for r in full if r['askable'] == 0)))
        crowded = [r for r in full if r['offered'] >= 5]
        print('2. selection         : %d games offered 5+ moments; in them the '
              'model chose %d asking of %d, mean cost-rank %s' % (
                  len(crowded),
                  sum(r['chose_asking'] for r in crowded),
                  sum(r['chosen'] for r in crowded),
                  '%.1f' % (sum(r['rank'] for r in crowded if r['rank'])
                            / max(1, len([r for r in crowded if r['rank']])))
                  if crowded else '-'))
        print('3. move ambiguity    : %d questions, %d on a position with a '
              'rival within %.2f, %d of those not accepting it' % (
                  sum(r['questions'] for r in full),
                  sum(r['thin'] for r in full), NEAR,
                  sum(r['unfair'] for r in full)))
        used = [r for r in full if r['opening'] not in ('-', 'no')]
        print('4. opening header    : used in %d of %d tutorials (%s)' % (
            len(used), len(full),
            ', '.join(sorted({r['opening'] for r in used})) or 'nowhere'))
        print('   book reach        : %d positions in the database across the '
              'games; the chosen moments offered the model %d slots naming it, '
              'and %d sentences used one'
              % (sum(r['in_book'] for r in full),
                 sum(r['book_offered'] for r in full),
                 sum(r['book_written'] for r in full)))
        print('                       (the column is written>offered/in the '
              'database; offered is the prompt, written is the model)')
        print('   verdicts          : %s' % ', '.join(
            '%s %d' % (v, sum(1 for r in full if r['verdict'] == v))
            for v in sorted({r['verdict'] for r in full})))

    if cfg.csv:
        import csv
        with io.open(cfg.csv, 'w', encoding='utf-8', newline='') as fh:
            writer = csv.DictWriter(fh, fieldnames=sorted(
                {k for r in rows for k in r}))
            writer.writeheader()
            writer.writerows(rows)
        print('\nwritten: %s' % cfg.csv)


if __name__ == '__main__':
    main()
