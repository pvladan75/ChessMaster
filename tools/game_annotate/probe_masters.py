"""How far into a game does the Lichess masters database reach, and where does a
move stop being theory?

    python probe_masters.py pvladan_2026-09-12 french_2026-06-19
    python probe_masters.py --report                 # from the cache, no network

Written on 13.9.2026 to answer one question with a number instead of an
estimate: is it worth asking an opening database before spending eight to twelve
minutes of Stockfish on a game? What it measured is in the README, section
"What the masters database actually covers".

**Not being blocked is the whole design.** `chess_backend/services/
lichessPacing.js` already records what that takes, and this probe is stricter
than it has to be:

 * The masters endpoint answers **401** to an anonymous caller, so the server's
   own `LICHESS_API_TOKEN` is used - the same allowance every user of the app's
   opening panel shares. That is the reason for everything below.
 * One request every `GAP_S` seconds, where a token allows fifteen a second.
 * **Any answer that is not a 200 stops the probe.** A retry into a 429 is what
   turns one blocked minute into a blocked hour, for this address and so for
   every user of the app.
 * The walk stops at the first position no master game ever reached, because
   nothing after such a position can be in the database either. A whole game
   costs about a dozen requests.
 * Every answer is kept in `out/_masters/<game>.json`, and a position already
   there is never asked twice. `--report` re-reads the cache and sends nothing,
   so a threshold can be argued over without touching the network again.
"""

import argparse
import io
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

MASTERS = os.environ.get('LICHESS_MASTERS_URL',
                         'https://explorer.lichess.ovh/masters')
GAP_S = 1.2
UA = 'mislisha-annotate-probe/1.0 (one-off opening coverage measurement)'

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
INPUT = os.path.join(HERE, 'input')
CACHE = os.path.join(HERE, 'out', '_masters')


def token():
    path = os.path.join(REPO, 'chess_backend', '.env')
    for line in io.open(path, encoding='utf-8'):
        if line.startswith('LICHESS_API_TOKEN'):
            value = line.split('=', 1)[1].strip()
            if value:
                return value
    sys.exit('No LICHESS_API_TOKEN in chess_backend/.env, and the masters '
             'endpoint answers 401 without one.')


def ask(fen, bearer):
    url = '%s?%s' % (MASTERS, urllib.parse.urlencode(
        {'fen': fen, 'moves': 30, 'topGames': 0}))
    req = urllib.request.Request(url, headers={
        'User-Agent': UA, 'Authorization': 'Bearer %s' % bearer})
    with urllib.request.urlopen(req, timeout=30) as fh:
        return json.load(fh)


def book_walk(game, fens, bearer=None, gap_s=GAP_S):
    """What the masters database says about each of [fens], in order.

    Returns {fen: the explorer's answer} for the positions it knows, and stops
    at the first it does not: no master game reached anything after such a
    position, so asking is a request spent on a certain zero. Answers already in
    `out/_masters/<game>.json` cost nothing.

    This is the one place that talks to the explorer. `make_facts.py` calls it
    while building a game's facts, and the answers are written into the facts
    file - so the network is a build-time dependency and never a read-time one,
    and a facts file stays what it became tonight: a function of its inputs.

    A refusal returns what it has rather than raising. Half a book is a fact
    about the opening; a retry into a 429 is a blocked address, and the app's
    opening panel shares it.
    """
    cached = load(game)
    known, fetched = {}, 0
    for fen in fens:
        if fen not in cached:
            if bearer is None:
                bearer = token()
            time.sleep(gap_s)
            try:
                cached[fen] = ask(fen, bearer)
                fetched += 1
            except Exception as exc:
                save(game, cached)
                print('  masters: stopped at %s (%s); %d position(s) known'
                      % (fen.split()[0][:20], exc, len(known)), flush=True)
                return known
        if total_of(cached[fen]) == 0:
            break
        known[fen] = cached[fen]
    if fetched:
        save(game, cached)
    return known


def cache_path(game):
    return os.path.join(CACHE, '%s.json' % game)


def load(game):
    path = cache_path(game)
    if os.path.exists(path):
        with io.open(path, encoding='utf-8') as fh:
            return json.load(fh)
    return {}


def save(game, cached):
    os.makedirs(CACHE, exist_ok=True)
    with io.open(cache_path(game), 'w', encoding='utf-8') as fh:
        json.dump(cached, fh, ensure_ascii=False, indent=1, sort_keys=True)


def rows_of(game):
    path = os.path.join(INPUT, '%s_facts.json' % game)
    with io.open(path, encoding='utf-8') as fh:
        return json.load(fh)['rows']


def total_of(data):
    return data['white'] + data['draws'] + data['black']


def collect(game, bearer):
    """Ask about this game's positions until the database runs out."""
    rows, cached = rows_of(game), load(game)
    sent = 0
    for row in rows:
        fen = row['fen']
        if fen not in cached:
            time.sleep(GAP_S)
            try:
                cached[fen] = ask(fen, bearer)
                sent += 1
            except urllib.error.HTTPError as exc:
                save(game, cached)
                print('  STOPPED: HTTP %s at %s - not retrying'
                      % (exc.code, row['label']))
                return cached, False, sent
            except Exception as exc:
                save(game, cached)
                print('  STOPPED: %s at %s' % (exc, row['label']))
                return cached, False, sent
        if total_of(cached[fen]) == 0:
            break
    save(game, cached)
    return cached, True, sent


def report(game, cached, min_share, min_games):
    """What the database says about this game, and what a rule would have done.

    `min_share` is the share of a position's games that played the move, and
    `min_games` is what the position itself needs before a share means anything.
    The second is not a refinement of the first, it is what makes it usable: in
    a position with nine master games every move is rare, and in the Philidor
    `2... d6` is 2.2% of its position and is a named opening with 6450 games
    behind it.
    """
    rows = rows_of(game)
    lines, in_book, left, first_rare = [], 0, None, None
    for i, row in enumerate(rows, 1):
        data = cached.get(row['fen'])
        if data is None:
            break
        here = total_of(data)
        if here == 0:
            left = i
            break
        in_book = i
        played = (row.get('played') or {}).get('move')
        hit = next((m for m in data['moves'] if m['san'] == played), None)
        count = total_of(hit) if hit else 0
        share = count / float(here)
        rare = share < min_share and here >= min_games
        if rare and first_rare is None:
            first_rare = (i, (row.get('played') or {}).get('label'),
                          count, here, share)
        lines.append('  %2d  %-16s %8d here  %-7s %7d (%5.1f%%)%s' % (
            i, row['label'], here, played or '-', count, 100 * share,
            '  RARE' if rare else ''))
    return lines, in_book, left or (in_book + 1), first_rare, len(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('games', nargs='*')
    parser.add_argument('--report', action='store_true',
                        help='read the cache and send nothing')
    parser.add_argument('--min-share', type=float, default=0.10,
                        help="share of a position's games below which the move "
                             'played counts as rare')
    parser.add_argument('--min-games', type=int, default=50,
                        help='games a position needs before a share means '
                             'anything')
    cfg = parser.parse_args()

    games = cfg.games or [f[:-len('_facts.json')]
                          for f in sorted(os.listdir(INPUT))
                          if f.endswith('_facts.json')]
    bearer = None if cfg.report else token()
    total_sent = 0
    for game in games:
        if cfg.report:
            cached, ok, sent = load(game), True, 0
        else:
            cached, ok, sent = collect(game, bearer)
        total_sent += sent
        lines, in_book, left, rare, positions = report(
            game, cached, cfg.min_share, cfg.min_games)
        print('\n%s  (%d positions)' % (game, positions))
        print('\n'.join(lines))
        print('  -> the database runs out at position %d; %d of %d positions '
              'are in it (%d%%)'
              % (left, in_book, positions, round(100.0 * in_book / positions)))
        if rare:
            print('  -> first rare move (<%.0f%% of a position with %d+ games): '
                  'position %d, %s, %d of %d (%.1f%%)'
                  % (100 * cfg.min_share, cfg.min_games, rare[0], rare[1],
                     rare[2], rare[3], 100 * rare[4]))
        else:
            print('  -> no move in the book was rare under this rule')
        if not ok:
            break
    if total_sent:
        print('\n%d requests sent, one every %.1f s' % (total_sent, GAP_S))


if __name__ == '__main__':
    main()
