"""What a game tutorial says, in the order a listener hears it.

    python spoken.py out/H-api-...                 # tutorial-game.json of one run
    python spoken.py out/H-api-... --file tutorial.json
    python spoken.py --compare A_DIR B_DIR --out compare.md

Written for docs/PLAN-NARACIJA.md (14.9.2026): whether a tutorial reads as a
story can only be judged by reading what is spoken, part by part, and a JSON of
PGN strings is not that. The counts beside it are the shapes the owner reported
- a move announced in its own slot, „the queen from d8 to c7", the same opening
words again and again - counted, not judged.
"""

import argparse
import io
import json
import os
import re
import sys

import chess
import chess.pgn

ANNOUNCE = re.compile(
    r'^(White|Black)\s+(plays|played|should have played|would answer|'
    r'could have played|answers|responds|chooses)\b')
FROM_TO = re.compile(r'\bthe (king|queen|rook|bishop|knight|pawn) from [a-h][1-8]\b')
MEANINGLESS = re.compile(r'board just before these moves', re.I)


def lines_of(step):
    """[(kind, san, text)] for one part, in the order it is read."""
    out = []
    if step.get('kind', 'show') != 'show':
        out.append(('question', None, step.get('instruction', '')))
        return out
    game = chess.pgn.read_game(io.StringIO(
        '[SetUp "1"]\n[FEN "%s"]\n\n%s' % (step['fen'], step.get('pgn') or '*')))
    arrows = ['%s%s' % (chess.square_name(a.tail), chess.square_name(a.head))
              for a in game.arrows()]
    out.append(('intro', ' '.join('arrow ' + a for a in arrows) or None,
                _said(game.comment)))
    for node in game.mainline():
        out.append(('move', node.san(), _said(node.comment)))
    return out


def _said(comment):
    """A comment as it is read aloud: the drawing commands are not words."""
    return re.sub(r'\s+', ' ', re.sub(r'\[%[a-z]+ [^\]]*\]', '', comment)).strip()


def read(run_dir, file_name):
    with open(os.path.join(run_dir, file_name), encoding='utf-8') as fh:
        return json.load(fh)


def counts(tutorial):
    moves = texts = announce = from_to = meaningless = silent = words = 0
    openings = {}
    for step in tutorial['positionList']:
        for kind, san, text in lines_of(step):
            if kind == 'move':
                moves += 1
                if not text:
                    silent += 1
            if not text:
                continue
            texts += 1
            words += len(text.split())
            if kind == 'move' and (ANNOUNCE.search(text) or
                                   (san and text.startswith(san.rstrip('+#')))):
                announce += 1
            if FROM_TO.search(text):
                from_to += 1
            if MEANINGLESS.search(text):
                meaningless += 1
            key = ' '.join(re.findall(r"[a-z']+", text.lower())[:3])
            openings[key] = openings.get(key, 0) + 1
    repeated = sum(n for n in openings.values() if n > 1)
    return {'parts': len(tutorial['positionList']), 'moves': moves,
            'spoken': texts, 'words': words, 'silent_moves': silent,
            'announces_its_move': announce, 'the_x_from_square': from_to,
            'board_just_before': meaningless,
            'sentences_sharing_first_3_words': repeated}


def transcript(tutorial):
    out = ['# %s' % tutorial.get('title', ''), '']
    for n, step in enumerate(tutorial['positionList'], 1):
        out.append('**Part %d** (%s)' % (n, step.get('kind', 'show')))
        for kind, san, text in lines_of(step):
            if kind == 'question':
                out.append('- ❓ %s' % text)
            elif kind == 'intro':
                if san or text:
                    out.append('- %s%s' % ('[%s] ' % san if san else '', text))
            else:
                out.append('- `%s` %s' % (san, text or '·'))
        out.append('')
    return '\n'.join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('runs', nargs='*')
    parser.add_argument('--file', default='tutorial-game.json')
    parser.add_argument('--compare', nargs=2, metavar=('BEFORE', 'AFTER'))
    parser.add_argument('--out')
    cfg = parser.parse_args()
    if cfg.compare:
        before, after = (read(d, cfg.file) for d in cfg.compare)
        text = '\n'.join([
            '| | before | after |', '|---|---|---|',
            *['| %s | %s | %s |' % (k, v, counts(after)[k])
              for k, v in counts(before).items()],
            '', '## Before', '', transcript(before),
            '## After', '', transcript(after)])
    else:
        text = '\n\n'.join(
            json.dumps(counts(read(d, cfg.file))) + '\n\n' + transcript(read(d, cfg.file))
            for d in cfg.runs)
    if cfg.out:
        with open(cfg.out, 'w', encoding='utf-8') as fh:
            fh.write(text)
    else:
        sys.stdout.buffer.write(text.encode('utf-8'))


if __name__ == '__main__':
    main()
