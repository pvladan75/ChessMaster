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
    return {
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
    for game in RUNS:
        folder = run_dir(game)
        answer = read(os.path.join(folder, 'answer.json'))
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
    print('%d fixtures, %d KB -> %s' % (len(RUNS), total // 1024, os.path.relpath(DEST, REPO)))


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
