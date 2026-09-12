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
         'what a child can take from it into their own games')
LEVEL = 'a club child of about ten to thirteen who knows how the pieces move'
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
                 ' * a clause beginning `Resolved -` says a motif that existed '
                 'a move ago has *stopped* being true. It is a state change, '
                 'not something to tell a child.\n'
                 ' * `Watch out -` marks a motif that has just appeared '
                 'against the side who moved.\n'
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
}

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
answer is merely one of several good moves marks a child wrong for playing the
best one, and nothing in the app can catch that.

**You have {calls} engine searches for this task.** `line --no-eval` and
`budget` are free. Spend them where the game is actually unclear, not evenly:
going three moves deeper into one critical position is worth more than a shallow
look at twenty. When they are gone you will be told so, and you must finish the
tutorial with what you know.

Say in your reply which positions you spent them on and why.
"""

NO_TOOL_TEXT = """## No engine

You have no engine and no tablebase for this task. Work from the position in
front of you, and where you are not certain of a line, write a shorter one you
are certain of.
"""


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
    note = spec['note'] or ARMS['B']['note']
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
              .replace('{OUT_FILE}', os.path.join(work_dir, 'tutorial.json'))
              .replace('{GAME_NOTE}', note)
              .replace('{GAME_FILE}', os.path.basename(pgn_path))
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
        sys.exit('the arms are A, B and C')

    stamp = time.strftime('%Y%m%d-%H%M%S')
    run_dir = os.path.join(OUT_DIR, '%s-%s' % (arm, stamp))
    os.makedirs(run_dir, exist_ok=True)

    # The model works in an empty directory of its own, outside this folder,
    # holding nothing but the game. Everything is copied back into `run_dir`
    # afterwards. `tools/tutorial_translate/translate.py` does the same thing
    # for the same reason: an agent reads what is in front of it, and what was
    # in front of it here was the README describing the experiment and the
    # previous arm's answer.
    work_dir = tempfile.mkdtemp(prefix='arm%s-' % arm)

    calls = cfg.max_calls if ARMS[arm]['engine'] else 0
    session = os.path.basename(run_dir)
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
    cmd = [find_agy(), '-p', prompt, '--model', cfg.model,
           '--print-timeout', cfg.timeout]
    if cfg.yolo:
        cmd.append('--dangerously-skip-permissions')

    print('arm %s, %s, %d characters of prompt - running...'
          % (arm, cfg.model, len(prompt)))
    started = time.time()
    proc = subprocess.run(cmd, cwd=work_dir, capture_output=True,
                          encoding='utf-8', errors='replace', env=env)
    meta['seconds'] = round(time.time() - started, 1)
    meta['exit_code'] = proc.returncode

    save_text(run_dir, 'reply.txt', proc.stdout or '')
    if proc.stderr:
        save_text(run_dir, 'stderr.txt', proc.stderr)

    for name in sorted(os.listdir(work_dir)):
        source = os.path.join(work_dir, name)
        if os.path.isfile(source):
            shutil.copy(source, run_dir)
    shutil.rmtree(work_dir, ignore_errors=True)

    wrote = os.path.exists(os.path.join(run_dir, 'tutorial.json'))
    meta['wrote_the_file'] = wrote
    if not wrote:
        rescued = rescue_json(proc.stdout or '')
        meta['rescued_from_reply'] = bool(rescued)
        if rescued:
            save_text(run_dir, 'tutorial.json', rescued)

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
