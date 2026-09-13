"""Everything a person reads about one run, in one printout.

    python review_run.py out/H-api-deepseek-flash-...

Written on 13.9.2026 after the same inline script had been retyped for a dozen
runs. The grader says whether the app takes a file and `check_positions.py`
whether its boards and answers are right; neither can say what matters last -
whether the sentences are true and whether the tutorial chose or transcribed.
This prints the run's own report, every sentence beside the move it is written
on, every question with its accepted answers, and how much of the game the
demonstrations replay, so that reading them is the whole of the remaining work.
"""

import json
import os
import re
import sys

import chess
import chess.pgn

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    run = os.path.abspath(sys.argv[1])
    meta = json.load(open(os.path.join(run, 'meta.json'), encoding='utf-8'))
    game_name = meta.get('game', 'pvladan_2026-09-12')
    print('%s\n  seconds %s | finish %s | tokens %s' % (
        os.path.basename(run), meta.get('seconds'), meta.get('finish_reason'),
        meta.get('tokens')))
    for key in ('channel_error', 'outside_read_declared', 'positions', 'skeleton'):
        if meta.get(key):
            value = dict(meta[key]) if isinstance(meta[key], dict) else meta[key]
            if isinstance(value, dict):
                value.pop('parameters', None)
            print('  %s: %s' % (key, json.dumps(value, ensure_ascii=False)))

    path = os.path.join(run, 'tutorial.json')
    if not os.path.exists(path):
        print('  no tutorial.json')
        return
    tutorial = json.load(open(path, encoding='utf-8'))

    with open(os.path.join(HERE, 'input', '%s_plain.pgn' % game_name), encoding='utf-8') as fh:
        game = chess.pgn.read_game(fh)
    board, keys, sans = game.board(), {}, []
    for index, move in enumerate(game.mainline_moves()):
        keys.setdefault(' '.join(board.fen().split()[:2]), index)
        sans.append(board.san(move))
        board.push(move)

    print('\nTITLE: %s\nDESCRIPTION: %s' % (tutorial.get('title'), tutorial.get('description')))
    covered = set()
    for number, part in enumerate(tutorial.get('positionList', []), 1):
        ply = keys.get(' '.join((part.get('fen') or '').split()[:2]))
        print('--- part %d %s, at ply %s%s' % (number, part.get('kind'), ply,
                                              ' (Black below)' if part.get('blackOrientation') else ''))
        if part.get('kind') == 'show':
            text = re.sub(r'\[%(cal|csl)[^\]]*\]', '', part.get('pgn', ''))
            opening = re.match(r'\s*\{([^}]*)\}', text)
            if opening:
                print('   %-11s %s' % ('(position)', opening.group(1).strip()))
            for move, comment in re.findall(
                    r'((?:\d+\.+\s*)?[A-Za-z][A-Za-z0-9+#=x-]*)\s*\{([^}]*)\}', text):
                print('   %-11s %s' % (move.strip(), comment.strip()))
            plain = re.sub(r'\{[^}]*\}', ' ', part.get('pgn', ''))
            while re.search(r'\([^()]*\)', plain):
                plain = re.sub(r'\([^()]*\)', ' ', plain)
            moves = [re.sub(r'^\d+\.+', '', t).rstrip('!?') for t in plain.split()
                     if not re.match(r'^(\d+\.+|\*)$', t)]
            if ply is not None:
                for k, san in enumerate(m for m in moves if m):
                    if ply + k < len(sans) and sans[ply + k].rstrip('+#') == san.rstrip('+#'):
                        covered.add(ply + k)
                    else:
                        break
        elif part.get('kind') == 'ask_move':
            print('   ASK: %s -> %s %s' % (part.get('instruction'), part.get('solutionSan'),
                                          part.get('acceptedSans') or ''))
        else:
            print('   CHOICE: %s' % part.get('instruction'))
            for choice in part.get('choices', []):
                print('     [%s] %s' % ('x' if choice.get('correct') else ' ', choice.get('text')))
    print('\ncovers %d%% of the game\'s %d moves' % (round(100 * len(covered) / len(sans)), len(sans)))


if __name__ == '__main__':
    main()
