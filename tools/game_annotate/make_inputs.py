"""The two inputs the arms are fed, from one source file.

    python make_inputs.py SOURCE [--name game]

SOURCE is any text file with a PGN in it - the file the owner pasted a reviewed
game into, or a plain export. It writes two files into `input/`:

  <name>_reviewed.pgn   the text exactly as it came, comments and all
  <name>_plain.pgn      the same game with every comment, glyph and variation
                        removed - the moves and nothing else

**The reviewed file is copied, never re-exported.** It is the app's own output
and the thing arm B is about; a round trip through another library would make
the experiment measure that library's idea of a comment. Only the plain one is
derived, because removing things is the whole job.

**And then the two are compared move for move.** A stripped input that quietly
lost a move would make arm A a different game from arm B, and the comparison
between them - which is the entire point - would be measuring the strip.
"""

import argparse
import io
import os
import re
import sys

try:
    import chess
    import chess.pgn
except ImportError:
    sys.exit('python-chess is missing: pip install chess')


HERE = os.path.dirname(os.path.abspath(__file__))
INPUT_DIR = os.path.join(HERE, 'input')


def extract(text):
    """The first PGN in [text], headers included.

    A source file may be a question with a game pasted into it, so the prose
    around it is dropped: from the first `[Event` to the result token that ends
    the movetext.
    """
    start = text.find('[Event ')
    if start < 0:
        # No headers at all is a game from the standard opening position - the
        # same rule the app itself applies to a pasted line.
        start = 0
    body = text[start:]
    end = game_end(body)
    if end is not None:
        body = body[:end]
    body = body.strip() + '\n'
    # Loud rather than quiet. The first version looked for the result on a line
    # of its own, and the app writes it after the last comment (`… } *`), so
    # the owner's questions below the game went into every game-one prompt for
    # a day - to every model, and into the thinking of one of them.
    if not re.search(r'(^|\s)(1-0|0-1|1/2-1/2|\*)\s*$', body):
        sys.exit('the game does not end with a result token (1-0, 0-1, 1/2-1/2 '
                 'or *), so where it stops cannot be told')
    return body


def game_end(body):
    """Where the movetext's result token ends, or None.

    Read as the PGN reader reads it: a `*` or a `1-0` inside a `{ comment }`
    or a `( variation )` is not the end of the game, and a result token counts
    only between whitespace. The first such token at the top level is the end.
    """
    depth, i, n = 0, 0, len(body)
    in_headers = True
    while i < n:
        ch = body[i]
        if in_headers:
            if ch == '[':
                close = body.find(']', i)
                i = n if close < 0 else close + 1
                continue
            if not ch.isspace():
                in_headers = False
            else:
                i += 1
                continue
        if ch == '{':
            close = body.find('}', i)
            i = n if close < 0 else close + 1
            continue
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth = max(0, depth - 1)
        elif depth == 0 and (i == 0 or body[i - 1].isspace()):
            for token in ('1/2-1/2', '1-0', '0-1', '*'):
                stop = i + len(token)
                if body.startswith(token, i) and (stop == n or body[stop].isspace()):
                    return stop
        i += 1
    return None


def plain(pgn_text):
    """[pgn_text] with the annotations taken out, as one game's moves."""
    game = chess.pgn.read_game(io.StringIO(pgn_text))
    if game is None:
        sys.exit('no game could be read out of that text')

    board = game.board()
    out = chess.pgn.Game()
    out.setup(board)
    node = out

    for move in game.mainline_moves():
        node = node.add_variation(move)
    out.headers.update({k: v for k, v in game.headers.items()
                        if k in ('Event', 'Site', 'Date', 'Round',
                                 'White', 'Black', 'Result', 'SetUp', 'FEN')})

    exporter = chess.pgn.StringExporter(headers=True, variations=False,
                                        comments=False)
    return out.accept(exporter) + '\n'


def moves_of(pgn_text):
    game = chess.pgn.read_game(io.StringIO(pgn_text))
    board = game.board()
    out = []
    for move in game.mainline_moves():
        out.append(board.san(move))
        board.push(move)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('source')
    parser.add_argument('--name', default='game')
    cfg = parser.parse_args()

    with open(cfg.source, encoding='utf-8') as fh:
        text = fh.read()

    reviewed = extract(text)
    stripped = plain(reviewed)

    before, after = moves_of(reviewed), moves_of(stripped)
    if before != after:
        sys.exit('the stripped game is not the same game: %d moves against %d'
                 % (len(before), len(after)))

    os.makedirs(INPUT_DIR, exist_ok=True)
    paths = []
    for suffix, body in (('reviewed', reviewed), ('plain', stripped)):
        path = os.path.join(INPUT_DIR, '%s_%s.pgn' % (cfg.name, suffix))
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(body)
        paths.append(path)

    print('%d moves, same in both.' % len(before))
    for path in paths:
        print('  %s  (%d characters)' % (os.path.relpath(path, HERE),
                                         os.path.getsize(path)))


if __name__ == '__main__':
    main()
