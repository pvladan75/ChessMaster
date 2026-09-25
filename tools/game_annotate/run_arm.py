"""One arm of the experiment: build the prompt, run the model, keep everything.

    python run_arm.py A                    # the bare game, no tools
    python run_arm.py B                    # the reviewed game, no tools
    python run_arm.py C --max-calls 40     # the reviewed game and the engine
    python run_arm.py A --dry-run          # write the prompt and stop

The three arms differ in exactly two things - what the model is given and
whether it may call the engine - so that the difference between their answers is
about that and not about the wording of the task. `brief.md` is one file for all
three.

**The format contract is quoted, never retyped.** `docs/PGN-TUTORIAL-FORMAT.md`
holds the prompt block the app's own importer was measured against; this script
lifts it out of that document at run time. A second copy in this folder would be
a second contract the day either one is edited, and the repository already
records what two copies of one rule cost.

**Everything a run produced is kept together**, under `out/<arm>-<stamp>/`: the
prompt as it was sent, the model's reply, the file it wrote, and the engine log.
An experiment whose inputs cannot be reread is an anecdote.

**Arms A and B are given a budget of zero engine calls rather than no tool.**
A refusal is written to the log, so „did it reach for the engine when it did not
have one" is a question the run can answer afterwards. Nothing enforces the
absence of a tool that leaves no trace.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
FORMAT_DOC = os.path.join(REPO, 'docs', 'PGN-TUTORIAL-FORMAT.md')
BRIEF = os.path.join(HERE, 'brief.md')
INPUT_DIR = os.path.join(HERE, 'input')
OUT_DIR = os.path.join(HERE, 'out')

TOPIC = ('this game - what the two sides did well, where it went wrong, and '
         'what a student can take from it into their own games')
LEVEL = 'a club player of 13 or older who knows how the pieces move'
LANGUAGE = 'en'

ARMS = {
    'A': {
        'input': 'plain',
        'engine': False,
        'note': ('This is the game as it was played, with no notes on it. '
                 'Nobody has told you which moves were mistakes.'),
    },
    'B': {
        'input': 'reviewed',
        'engine': False,
        'note': ('This is the game after the app\'s own „Review entire game" '
                 'pass. The `{ }` comments were written by that pass, not by a '
                 'person, and they are machine notes rather than teaching '
                 'prose:\n\n'
                 ' * each sentence describes the board after the move it '
                 'follows. A sentence saying something is *no longer* so '
                 'records that a motif stopped being true. It is a state '
                 'change, not something to tell a student.\n'
                 ' * `??` on a move and a `( ... { Better move } ... )` '
                 'variation after it are the engine\'s: the move played lost '
                 'something, and the variation is what it preferred.\n\n'
                 'Use them as evidence. Do not copy them into the tutorial.'),
    },
    'C': {
        'input': 'reviewed',
        'engine': True,
        'note': None,     # filled in from B's note, which it shares
    },
    # B+FEN, 13.9.2026. Arm B with every position of the game handed over, and
    # the model naming a part's position by the move it follows instead of
    # writing a FEN. Every failure of the vendor trial was a board the model had
    # rebuilt in its head; this arm asks what is left when it no longer has to.
    'F': {
        'input': 'reviewed',
        'engine': False,
        'note': None,     # B's note, plus the table of positions
    },
    # Facts, 13.9.2026. The owner's line: a model must not assess moves. So it
    # gets the bare game and, for every position, what Stockfish at depth 20
    # says - the best four with evaluations, the move played and its cost,
    # whether the best move stands out - plus the app's motifs. It chooses and
    # explains; `make_facts.py` did the assessing, once, for every model alike.
    'G': {
        'input': 'plain',
        'engine': False,
        'note': None,     # the facts table and its rules
    },
    # The skeleton, 13.9.2026: Python and Stockfish build the whole tutorial,
    # the model chooses moments and writes only the words. `skeleton.py`.
    # Through `run_api.py` only - its prompt is not the brief.
    'H': {
        'input': 'plain',
        'engine': False,
        'note': None,
    },
}

# The arms whose parts name a position rather than write one.
POSITION_TABLE_ARMS = ('F', 'G')

TOOL_TEXT = """## The engine

Stockfish is on this machine and you may call it. Two commands, both printing
one JSON object:

    python "{analyze}" fen "<FEN>" --depth 18 --multipv 3 --session {session}
    python "{analyze}" line --fen "<FEN>" --moves "Nxf3 Bxf3 Bxf3" --session {session}

`fen` analyses a position: the best lines in SAN, every evaluation from White's
point of view (`+0.85` means White stands better by that much, `#3` means White
mates in three), and the list of legal moves.

`line` replays moves from a position and tells you, move by move, whether each
one is legal and whether its `+` or `#` is true - and then analyses the position
it ends on. `--eval-each` gives an evaluation after every move instead of only
at the end. `--no-eval` checks the moves and runs no search at all, which costs
nothing.

**Use `line` to check your own work.** Every `fen` you are about to write into
the tutorial, and every line you are about to write into a `pgn`, can be replayed
here first. The faults it reports are exactly the faults the app refuses.

**And use `fen --multipv` on any position you are about to ask a question
about.** If the second move on the list is about as good as the first, that is
what `"acceptedSans"` is for - or a sign to ask somewhere else. A question whose
answer is merely one of several good moves marks a student wrong for playing the
best one, and nothing in the app can catch that.

**You have {calls} engine searches for this task.** `line --no-eval` and
`budget` are free. Spend them where the game is actually unclear, not evenly:
going three moves deeper into one critical position is worth more than a shallow
look at twenty. When they are gone you will be told so, and you must finish the
tutorial with what you know.

Say in your reply which positions you spent them on and why.
"""

OUTPUT_TO_FILE = """Write the tutorial as a single JSON object into the file

    {path}

Write nothing else to that file - no prose around it, no code fence. Everything
you want to say to the person running this experiment goes in your reply, not in
the file."""

GAME_AS_FILE = """It is the file **{name}**, in the directory you are working in.
Read it first; it is the only thing in there."""

CLOSING = """Reply with, briefly:

 * how many parts you wrote and what each one teaches, in one line each;
 * which claims you were least sure of;
 * anything about the game you wanted to check and could not.

**Everything you need is in this brief.** Do not go looking through the file
system for anything else - this is one arm of a comparison, and a file written
by another arm, or a note describing what is being compared, makes the answer
worthless rather than better. If you do read anything outside your working
directory, say what and why in your reply: an experiment that cannot say what
its subject saw is not an experiment."""

NO_TOOL_TEXT = """## No engine

You have no engine and no tablebase for this task. Work from the position in
front of you, and where you are not certain of a line, write a shorter one you
are certain of.
"""

POSITIONS_TEXT = """## Positions: name them, do not write them

The table below holds every position of this game. `start` is the position
before the first move; every other row is the position right after the move it
is labelled with.

**In this task you do not write `fen`.** Give every part a `"from"` field
instead, holding the label of the row the part starts from, copied exactly as
the table writes it - for example `"from": "14... Qc7"` - and leave `fen` out.
The position is filled in from this table when your file is read, so it cannot
come out wrong. This overrides the contract's rule that every part carries a
`fen`; every other rule of the contract still holds, and a part's `pgn` still
begins with the first move made *from* that position.

A part can only start on a row of this table. To show a better move instead of
the one that was played, start the part on the position before the mistake and
play the better move from there.

{table}
"""


FACTS_TEXT = """## The facts: every position, already assessed

You are not asked to assess a single move, and you must not. Stockfish has
analysed every position of this game at depth {depth}, and the blocks below are
its assessment. Each block is one position:

 * its label and FEN - `start` is the position before the first move, and every
   other label is the move that led to it;
 * `best moves`: the {multipv} best moves, best first, each with its evaluation
   and the line that follows. **Evaluations are in pawns from White's side**:
   `+1.50` means White is better by a pawn and a half, `-0.80` that Black is
   better, `#3` that White mates in three and `#-3` that Black does;
 * `best move stands out`: whether the best move leads the second by at least
   {margin} pawns, or is a mate the second is not. This is decided for you;
 * `played`: the move actually played from this position, the evaluation after
   it, what it cost the side that played it against the best move, and its rank
   among the best moves;
 * `on the board after it`: what the app's motif detector found on the board
   after that move - descriptions of the position, not verdicts.

The rules this sets, on top of the brief:

1. **Every claim about who is better, what a move wins or loses, or which move
   is best comes from these blocks and nothing else.** If a block does not say
   it, do not write it. A capture that is taken straight back is not a win, and
   the evaluation after it shows that.
2. **An `ask_move` goes only on a position whose best move stands out**, and its
   answer is that position's best move. Where the best move does not stand out,
   the position can still be shown, or carry an `ask_choice` about an idea -
   never „find the best move".
3. **Numbers are for you, not for the student.** Turn an evaluation into words -
   „White is winning", „the position is about even" - and never print `+1.50`
   in a sentence.
4. **Name positions, do not write them.** Give every part a `"from"` field
   holding the label of the block it starts from, copied exactly - for example
   `"from": "14... Qc7"` - and leave `fen` out; the position is filled in from
   these blocks when your file is read. This overrides the contract's rule that
   every part carries a `fen`; every other rule of the contract still holds. To
   show a better move, start the part on the position before the mistake and
   play that move's line from its block.

{table}
"""


def facts_of(name):
    """`input/<name>_facts.json`, or a loud stop naming the command that makes it."""
    path = os.path.join(HERE, 'input', '%s_facts.json' % name)
    if not os.path.exists(path):
        sys.exit('no facts for %s: run `python make_facts.py %s` first' % (name, name))
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def facts_text(name):
    """The facts as the blocks a model reads, one per position."""
    facts = facts_of(name)
    blocks = []
    for row in facts['rows']:
        lines = ['%s | %s to move | %s' % (row['label'], row['to_move'], row['fen'])]
        if row.get('game_over'):
            lines.append('  game over: %s' % row['game_over'])
        elif row.get('candidates'):
            lines.append('  best moves: ' + '; '.join(
                '%s %s (%s)' % (c['move'], c['eval'], c['line'])
                for c in row['candidates']))
            if 'best_stands_out' in row:
                detail = row.get('why') or 'lead over the second: %s' % row.get('margin_pawns')
                lines.append('  best move stands out: %s (%s)'
                             % ('yes' if row['best_stands_out'] else 'no', detail))
        played = row.get('played')
        if played:
            rank = ('rank %d' % played['rank']) if played.get('rank') else 'not among the best moves'
            cost = played.get('cost_pawns')
            if isinstance(cost, (int, float)):
                # Clamped here as well as in make_facts.py, so a facts file
                # written before that fix reads the same as one written after.
                cost = max(0, cost)
            lines.append('  played: %s, evaluation after it %s, cost %s pawns, %s'
                         % (played['label'], played.get('eval'), cost, rank))
            if row.get('motifs_after_played'):
                lines.append('  on the board after it: ' + row['motifs_after_played'])
        blocks.append('\n'.join(lines))
    return facts, '\n\n'.join(blocks)


def position_rows(name):
    """(label, FEN) for every position of the game's main line.

    `start` first, then one row per move, labelled the way a PGN writes the move
    that led to it (`14... Qc7`), so the label a model copies is the notation it
    has just read.
    """
    import io
    import chess.pgn

    text, _ = game_text(name, 'plain')
    game = chess.pgn.read_game(io.StringIO(text))
    board = game.board()
    rows = [('start', board.fen())]
    for move in game.mainline_moves():
        label = ('%d. ' if board.turn else '%d... ') % board.fullmove_number
        label += board.san(move)
        board.push(move)
        rows.append((label, board.fen()))
    return rows


def normalise_label(label):
    """A label as it is compared: no spaces, one spelling of the ellipsis, and
    no check or assessment marks — `14...Qc7+` and `14... Qc7` are one row."""
    text = re.sub(r'\s+', '', str(label)).replace('…', '...')
    return re.sub(r'[+#!?]+$', '', text).lower()


def game_note(arm, name):
    """The note that goes under the game: B's, and for a position-table arm the
    table after it."""
    if arm == 'G':
        facts, table = facts_text(name)
        return FACTS_TEXT.format(depth=facts['depth'], multipv=facts['multipv'],
                                 margin=facts.get('margin_pawns', 0.5), table=table)
    note = ARMS[arm]['note'] or ARMS['B']['note']
    if arm in POSITION_TABLE_ARMS:
        table = '\n'.join('%s | %s' % row for row in position_rows(name))
        note += '\n\n' + POSITIONS_TEXT.format(table='```\n%s\n```' % table)
    return note


def apply_positions(run_dir, name, meta, arm='F'):
    """Fill each part's `fen` from the `from` label the model wrote.

    A label that names no row is left without a position rather than guessed
    at: the grader then refuses the part, which is the loud answer. What the
    model wrote is kept beside the filled file, and `meta.json` says how many
    parts were filled, which labels did not resolve, and whether the model wrote
    a FEN anyway against the instruction.
    """
    path = os.path.join(run_dir, 'tutorial.json')
    if not os.path.exists(path):
        return
    raw = open(path, encoding='utf-8').read()
    save_text(run_dir, 'tutorial_as_written.json', raw)
    try:
        data = json.loads(raw)
    except ValueError:
        meta['positions'] = {'error': 'tutorial.json is not JSON'}
        return

    rows_in_order = position_rows(name)
    table = {normalise_label(label): fen for label, fen in rows_in_order}
    by_board = {}
    for label, fen in rows_in_order:
        by_board.setdefault(' '.join(fen.split()[:2]), (label, fen))
    filled, unresolved, wrote_fen, labels = 0, [], 0, {}
    for index, part in enumerate(data.get('positionList') or [], 1):
        if part.get('fen'):
            wrote_fen += 1
        label = part.pop('from', None)
        if label is None:
            # A model that wrote the FEN itself instead of naming it. It counts
            # only when it is a row of the table, and then it gets that row's
            # label - a copy made correctly. Anything else is removed, so the
            # grader refuses the part: on 13.9.2026 `gpt-5.4-mini` wrote eight
            # FENs and no labels, three of them wrong, and with this branch
            # missing nothing was filled and no question was checked.
            written = part.get('fen')
            hit = by_board.get(' '.join(str(written).split()[:2])) if written else None
            if hit:
                labels[index] = hit[0]
                part['fen'] = hit[1]
                continue
            part.pop('fen', None)
            unresolved.append('part %d: no "from", and %s' % (
                index, 'the FEN it wrote is not a position of this game'
                if written else 'no FEN either'))
            continue
        fen = table.get(normalise_label(label))
        if fen is None:
            unresolved.append('part %d: %r is not a row' % (index, label))
            part.pop('fen', None)
            continue
        part['fen'] = fen
        labels[index] = label
        filled += 1

    meta['positions'] = {'filled_from_table': filled, 'unresolved': unresolved,
                         'fen_written_by_model': wrote_fen}

    # Arm G's rule 2, checked rather than trusted: a question only where the
    # best move stands out, and its answer that best move. A student marked wrong
    # for an equally good move is the fault this arm exists to end.
    if arm == 'G':
        rows = {normalise_label(r['label']): r for r in facts_of(name)['rows']}
        against = []
        for index, part in enumerate(data.get('positionList') or [], 1):
            if part.get('kind') != 'ask_move':
                continue
            if index not in labels:
                # Said, not skipped: an empty list must mean „every question
                # was checked and passed", never „none could be checked".
                against.append('part %d is a question on no position of the '
                               'table, so it could not be checked' % index)
                continue
            row = rows.get(normalise_label(labels[index]))
            if not row or not row.get('candidates'):
                continue
            best = row['candidates'][0]['move']
            answer = str(part.get('solutionSan') or '')
            if not row.get('best_stands_out'):
                against.append('part %d asks at %s, where the best move does not '
                               'stand out' % (index, row['label']))
            elif answer.rstrip('+#') != best.rstrip('+#'):
                against.append('part %d answers %s at %s; the best move is %s'
                               % (index, answer, row['label'], best))
        meta['positions']['questions_against_facts'] = against
    save_text(run_dir, 'tutorial.json',
              json.dumps(data, ensure_ascii=False, indent=2))


# --- The pieces of the prompt -------------------------------------------------

def format_contract():
    """The prompt block out of `docs/PGN-TUTORIAL-FORMAT.md`, with the three
    placeholder lines at its end filled in.

    Matched by the fence rather than by line numbers: the document is edited,
    and a slice by position is the same mistake as reading a function body by
    counting characters.
    """
    with open(FORMAT_DOC, encoding='utf-8') as fh:
        doc = fh.read()

    block = re.search(r'```text\n(.*?)\n```', doc, re.S)
    if not block:
        sys.exit('the prompt block could not be found in %s - has the fence '
                 'changed?' % os.path.relpath(FORMAT_DOC, REPO))
    text = block.group(1)

    for key, value in (('Topic', TOPIC), ('Level', LEVEL),
                       ('Language of the sentences', LANGUAGE)):
        text, hits = re.subn(r'^%s: .*$' % re.escape(key),
                             '%s: %s' % (key, value), text, flags=re.M)
        if hits != 1:
            sys.exit('the contract has %d lines beginning %r; expected one'
                     % (hits, key))
    return text


def game_text(name, which):
    path = os.path.join(INPUT_DIR, '%s_%s.pgn' % (name, which))
    if not os.path.exists(path):
        sys.exit('no such input: %s\nRun make_inputs.py first.'
                 % os.path.relpath(path, HERE))
    with open(path, encoding='utf-8') as fh:
        return fh.read().strip(), path


def build_prompt(arm, name, work_dir, calls, session):
    spec = ARMS[arm]
    note = game_note(arm, name)
    _, pgn_path = game_text(name, spec['input'])

    with open(BRIEF, encoding='utf-8') as fh:
        brief = fh.read()

    # The session names the budget file, and it is the run's own name rather
    # than the temporary directory's: the log has to be findable afterwards.
    tools = (TOOL_TEXT.format(analyze=os.path.join(HERE, 'analyze.py'),
                              session=session, calls=calls)
             if spec['engine'] else NO_TOOL_TEXT)

    # The game travels as the file already copied into the working directory,
    # never inlined. A 78-move reviewed game is 18 KB, which pushed the prompt
    # past the Windows command-line limit - and a channel that changes with the
    # length of the game is a variable nobody declared. One channel for every
    # arm and every game, so a difference between two answers is not this.
    prompt = (brief
              .replace('{OUTPUT_INSTRUCTION}', OUTPUT_TO_FILE.format(
                  path=os.path.join(work_dir, 'tutorial.json')))
              .replace('{CLOSING}', CLOSING)
              .replace('{GAME_NOTE}', note)
              .replace('{GAME_DELIVERY}', GAME_AS_FILE.format(
                  name=os.path.basename(pgn_path)))
              .replace('{TOOLS}', tools)
              .replace('{FORMAT_CONTRACT}', format_contract()))

    left = re.findall(r'\{[A-Z_]+\}', prompt)
    if left:
        sys.exit('the brief still has placeholders in it: %s' % ', '.join(left))

    # The prompt travels as one command-line argument, and Windows cuts a
    # command line off at 32767 characters - silently, in the middle of a
    # sentence, which would leave the model working from a brief with its end
    # missing and nothing anywhere saying so. Arm C's is already 23k.
    if len(prompt) > 30000:
        sys.exit('the prompt is %d characters, too close to the Windows '
                 'command-line limit to send as an argument. Shorten the brief '
                 'or the game before running this arm.' % len(prompt))
    return prompt, pgn_path


# --- The model ----------------------------------------------------------------

def find_agy():
    found = shutil.which('agy')
    if found:
        return found
    guess = os.path.expanduser(r'~\AppData\Local\agy\bin\agy.exe')
    if os.path.exists(guess):
        return guess
    sys.exit('agy not found. Install the Antigravity CLI or put it on PATH.')


def run(cfg):
    arm = cfg.arm.upper()
    if arm not in ARMS:
        sys.exit('the arms are A, B, C, F, G and H')

    stamp = time.strftime('%Y%m%d-%H%M%S')
    # Model and game in the name, and an existing folder refused: named by arm
    # and second alone, several models started together would share one folder,
    # and one model's answer would be graded as another's. `run_api.py` had the
    # same fault and the same fix.
    slug = re.sub(r'[^a-z0-9.]+', '-', cfg.model.lower())
    run_dir = os.path.join(OUT_DIR, '%s-%s-%s-%s' % (arm, slug, cfg.name, stamp))
    os.makedirs(run_dir, exist_ok=False)

    # The model works in an empty directory of its own, outside this folder,
    # holding nothing but the game. Everything is copied back into `run_dir`
    # afterwards. `tools/tutorial_translate/translate.py` does the same thing
    # for the same reason: an agent reads what is in front of it, and what was
    # in front of it here was the README describing the experiment and the
    # previous arm's answer.
    work_dir = tempfile.mkdtemp(prefix='arm%s-' % arm)

    calls = cfg.max_calls if ARMS[arm]['engine'] else 0
    session = os.path.basename(run_dir)
    if arm == 'H':
        # The skeleton's own short task rather than the brief; the model answers
        # with words, and the tutorial is assembled from them below.
        import skeleton
        prompt = skeleton.prompt(cfg.name)
        _, pgn_path = game_text(cfg.name, 'plain')
    else:
        prompt, pgn_path = build_prompt(arm, cfg.name, work_dir, calls, session)

    with open(os.path.join(run_dir, 'prompt.md'), 'w', encoding='utf-8') as fh:
        fh.write(prompt)
    shutil.copy(pgn_path, work_dir)

    meta = {
        'arm': arm, 'model': cfg.model, 'game': cfg.name,
        'input': ARMS[arm]['input'], 'engine_calls_allowed': calls,
        'started': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'prompt_characters': len(prompt),
    }

    if cfg.dry_run:
        meta['dry_run'] = True
        shutil.rmtree(work_dir, ignore_errors=True)
        save(run_dir, 'meta.json', meta)
        print('prompt written, model not called:\n  %s'
              % os.path.relpath(os.path.join(run_dir, 'prompt.md'), HERE))
        return

    env = dict(os.environ)
    # The session names the budget file, so one run's engine calls are one
    # file, and an arm that was given none still leaves its refusals there.
    env['ANALYZE_SESSION'] = session
    env['ANALYZE_MAX_CALLS'] = str(calls)

    # Deliberately no `--add-dir` and a working directory outside this folder:
    # see „What the model may see" in README.md. The first run of all three arms
    # was thrown away because the model read the README, learnt what the
    # experiment was comparing, and had the previous arm's answer sitting in a
    # sibling directory.
    # The CLI's own log, kept with the run. `gemini-3.1-pro-high` once exited 0
    # after two minutes with an empty reply and no stderr — a run that reports
    # success and did nothing, and with no log there was no way to say why.
    cmd = [find_agy(), '-p', prompt, '--model', cfg.model,
           '--print-timeout', cfg.timeout,
           '--log-file', os.path.join(run_dir, 'agy.log')]
    if cfg.yolo:
        cmd.append('--dangerously-skip-permissions')

    print('arm %s, %s, %d characters of prompt - running...'
          % (arm, cfg.model, len(prompt)))
    started = time.time()
    proc = subprocess.run(cmd, cwd=work_dir, capture_output=True,
                          encoding='utf-8', errors='replace', env=env)
    meta['seconds'] = round(time.time() - started, 1)
    meta['exit_code'] = proc.returncode
    # A CLI that failed may still leave a file behind, and that file is a draft
    # the model never finished, not its answer. `gpt-oss-120b-medium` was cut off
    # by a 503 („No capacity available") after eleven minutes, left a four-part
    # tutorial, and was graded DAMAGED as if it had chosen to write that. The
    # fault is recorded here so nobody grades the channel as the model.
    if proc.returncode != 0:
        first = next((line.strip() for line in (proc.stderr or '').splitlines()
                      if line.strip()), 'no stderr')
        meta['channel_error'] = first[:300]
        print('THE CLI FAILED (exit %d): %s\n  whatever was written is not an '
              'answer - rerun before grading' % (proc.returncode, first[:200]))

    save_text(run_dir, 'reply.txt', proc.stdout or '')
    if proc.stderr:
        save_text(run_dir, 'stderr.txt', proc.stderr)

    # The empty working directory is not the only one the model can reach: agy
    # gives every session `~/.gemini/antigravity-cli/scratch`, shared across
    # sessions and never cleared. On 13.9.2026 `gemini-3.1-pro-high` said it had
    # run a `validate_tutorial.py` from there — which held a finished game-one
    # tutorial from arm A of 12.9. The brief asks the model to declare what it
    # read outside its directory; this makes that declaration a field, so a run
    # that reached the shared scratch is flagged rather than trusted.
    reached = re.findall(r'[^\n]*(?:antigravity-cli|\.gemini[\\/]|scratch)[^\n]*',
                         proc.stdout or '', re.I)
    if reached:
        meta['outside_read_declared'] = [line.strip()[:200] for line in reached[:5]]
        print('THE MODEL REPORTS READING OUTSIDE ITS DIRECTORY:\n  %s'
              % reached[0].strip()[:200])

    for name in sorted(os.listdir(work_dir)):
        source = os.path.join(work_dir, name)
        if os.path.isfile(source):
            shutil.copy(source, run_dir)
    shutil.rmtree(work_dir, ignore_errors=True)

    if arm == 'H':
        answer = rescue_json(proc.stdout or '')
        meta['answer_was_json'] = bool(answer)
        if answer:
            import skeleton
            save_text(run_dir, 'answer.json', answer)
            skeleton.assemble(run_dir, cfg.name, meta, answer)
    wrote = os.path.exists(os.path.join(run_dir, 'tutorial.json'))
    meta['wrote_the_file'] = wrote
    if not wrote and arm != 'H':
        rescued = rescue_json(proc.stdout or '')
        meta['rescued_from_reply'] = bool(rescued)
        if rescued:
            save_text(run_dir, 'tutorial.json', rescued)
    if arm in POSITION_TABLE_ARMS:
        apply_positions(run_dir, cfg.name, meta, arm)

    budget = os.path.join(HERE, 'out', '_budget',
                          '%s.jsonl' % re.sub(r'\W+', '_', session))
    if os.path.exists(budget):
        shutil.copy(budget, os.path.join(run_dir, 'engine_calls.jsonl'))
        with open(budget, encoding='utf-8') as fh:
            meta['engine_calls_made'] = sum(1 for line in fh if line.strip())
    else:
        meta['engine_calls_made'] = 0

    save(run_dir, 'meta.json', meta)
    print('%s in %.0f s, exit %d, engine calls %d, file written: %s'
          % (os.path.relpath(run_dir, HERE), meta['seconds'], proc.returncode,
             meta['engine_calls_made'], meta.get('wrote_the_file')))
    print('Grade it:\n  cd %s && dart run tool/grade_tutorial.dart "%s"'
          % (os.path.join(REPO, 'chess_app'), run_dir))


def rescue_json(text):
    """The JSON object out of a reply that did not write the file.

    Kept as a *measurement* rather than a convenience: `meta.json` records that
    it was needed, because „did it follow the instruction about where to put
    the answer" is one of the things being compared.
    """
    fence = re.search(r'```(?:json)?\s*\n(\{.*?\})\s*\n```', text, re.S)
    if fence:
        return fence.group(1)
    start = text.find('{')
    end = text.rfind('}')
    if start >= 0 and end > start:
        candidate = text[start:end + 1]
        try:
            json.loads(candidate)
            return candidate
        except ValueError:
            return None
    return None


def save(run_dir, name, data):
    save_text(run_dir, name, json.dumps(data, ensure_ascii=False, indent=1))


def save_text(run_dir, name, text):
    with open(os.path.join(run_dir, name), 'w', encoding='utf-8') as fh:
        fh.write(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('arm', help='A, B or C')
    parser.add_argument('--name', default='pvladan_2026-09-12',
                        help='which pair of input files to use')
    parser.add_argument('--model', default='gemini-3.8-flash-high')
    parser.add_argument('--max-calls', type=int, default=40,
                        help='engine searches, arm C only')
    parser.add_argument('--timeout', default='20m')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--no-yolo', dest='yolo', action='store_false',
                        help='ask before each tool call instead of approving them')
    parser.set_defaults(yolo=True)
    run(parser.parse_args())


if __name__ == '__main__':
    main()
