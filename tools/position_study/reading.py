"""The studies of a run as something to read — phase 0 of
docs/PLAN-STUDIJA-POZICIJE.md.

    python reading.py <run folder> <out.md> [<title>]

A run folder is what `chess_app/tool/position_study.dart` wrote: for every
position a PGN, the request and the model's answer. This sets each study out
as a player reads one — the position, then the moves with the comment under
the move it is about, the side lines indented — and says beside each what it
cost: searches, tokens, and the sentences the app's check refused.
"""
import json
import os
import re
import sys


def tokens(text):
    """The movetext as moves, comments and brackets."""
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == '{':
            end = text.index('}', i)
            out.append(('comment', text[i + 1:end].strip()))
            i = end + 1
        elif c in '()':
            out.append((c, c))
            i += 1
        elif c.isspace():
            i += 1
        else:
            m = re.match(r'[^\s(){}]+', text[i:])
            out.append(('move', m.group(0)))
            i += len(m.group(0))
    return out


def marks(comment):
    arrows = re.findall(r'\[%cal ([^\]]*)\]', comment)
    squares = re.findall(r'\[%csl ([^\]]*)\]', comment)
    words = re.sub(r'\s*\[%c[as]l [^\]]*\]', '', comment).strip()
    drawn = []
    names = {'R': 'red', 'G': 'green', 'B': 'blue', 'Y': 'yellow', 'O': 'orange'}
    for group in arrows:
        for a in group.split(','):
            drawn.append(f'{names.get(a[0], a[0])} arrow {a[1:3]}–{a[3:5]}')
    for group in squares:
        marked = [s for s in group.split(',') if s]
        if marked:
            colour = names.get(marked[0][0], marked[0][0])
            drawn.append(f'{colour} squares ' + ' '.join(s[1:] for s in marked))
    return words, drawn


def laid_out(movetext):
    """A nested list: a run of moves and the comment on its last move are one
    item, and a side line is a list under the item it turns off from."""
    lines = []
    depth = 0
    run = []
    said = []

    def flush():
        if not run and not said:
            return
        moves = f'**{" ".join(run)}**' if run else '*the position*'
        words = ' '.join(said)
        lines.append('  ' * depth + f'- {moves}' + (f' — {words}' if words else ''))
        run.clear()
        said.clear()

    for kind, value in tokens(movetext):
        if kind == 'move':
            if value == '*':
                continue
            if said:
                flush()
            run.append(value)
        elif kind == 'comment':
            words, drawn = marks(value)
            note = f' *({"; ".join(drawn)})*' if drawn else ''
            said.append(f'{words}{note}')
        elif kind == '(':
            flush()
            depth += 1
        else:
            flush()
            depth -= 1
    flush()
    return '\n'.join(lines)


def main():
    folder, out = sys.argv[1], sys.argv[2]
    title = sys.argv[3] if len(sys.argv) > 3 else 'Position studies'
    positions = json.load(open(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), 'positions.json'),
        encoding='utf-8'))
    report = open(os.path.join(folder, 'report.md'), encoding='utf-8').read()
    facts = {}
    for block in report.split('\n## ')[1:]:
        name = block.split(' ', 1)[0]
        facts[name] = [l[2:] for l in block.split('\n') if l.startswith('- ')]

    doc = [f'# {title}', '']
    total_tokens = total_slots = total_kept = 0
    for p in positions:
        pid = p['id']
        pgn_file = os.path.join(folder, f'{pid}.pgn')
        if not os.path.exists(pgn_file):
            continue
        pgn = open(pgn_file, encoding='utf-8').read()
        body = pgn.split('\n\n', 1)[1] if '\n\n' in pgn else pgn
        side = 'White' if p['fen'].split()[1] == 'w' else 'Black'
        doc += [f'## {pid} — {p["what"]}', '', f'`{p["fen"]}`', '',
                f'{side} to move.', '']
        for line in facts.get(pid, []):
            doc.append(f'- {line}')
            m = re.match(r'model: .*?, (\d+) tokens', line)
            if m:
                total_tokens += int(m.group(1))
            m = re.match(r'slots: (\d+) offered, \d+ written, (\d+) kept', line)
            if m:
                total_slots += int(m.group(1))
                total_kept += int(m.group(2))
        doc += ['', laid_out(body), '']
    doc[1:1] = [
        '',
        f'{total_kept} of {total_slots} comments kept after the check, '
        f'{total_tokens:,} tokens in all.',
    ]
    open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(doc) + '\n')
    print(out, total_kept, total_slots, total_tokens)


if __name__ == '__main__':
    main()
