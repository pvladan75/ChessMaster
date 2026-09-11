"""Translate tutorial JSON files into another language through `agy`.

    python translate.py run   SRC OUT --language "Serbian (Latin script)"
    python translate.py merge SRC OUT --language "Serbian (Latin script)"

SRC is one tutorial file or a folder of them, in the shape of
`docs/PGN-TUTORIAL-FORMAT.md`. OUT receives one translated tutorial per source
file, a `_work/` folder with the strings, and `REPORT.txt`.

**The model never sees a move.** Every piece of prose is pulled out of the
tutorial into a flat list of `{id, text}` - the title, the description, each
part's title (unless it is a generated „Part 3"), instruction and answers, and
the words inside each `{ }` comment
of a part's `pgn` with its `[%cal]`/`[%csl]` commands taken out. Only that list
goes to the model, and the translations are written back into the same places.
The moves, the arrows, the positions and which answer is correct never leave
this script, so no translation can damage them - and after writing, the script
proves it: every part's `pgn` with its comments removed must be byte-identical
to the original's, and every field that is not prose must be equal.

That is also why nothing here parses a move. The app has exactly one PGN reader
(`LessonStepLine`), and a second one disagreeing with it is a fault this
project has already paid for. Finding a comment only needs its braces, which a
PGN comment cannot contain.

**What is checked on every translated string**, before anything is written:

  * every id comes back once, and none is invented;
  * the chess notation in it is the notation of the source, token for token -
    every move (`Nf3`, `Bxf7+`, `O-O`, `e8=Q#`), every square (`f7`) and every
    move number (`6.`, `6...`). A translation into Serbian that writes `Lc4`
    for `Bc4` fails here, and so does `Bxf7 +`;
  * a comment's translation carries no `{`, `}` or `[%` - any of those would
    end the comment early or turn words into moves;
  * in a Latin-script language, no Cyrillic letter.

A string that fails is sent back once with the reason. If it fails again the
tutorial is **not written**, and REPORT.txt names the id and the reason: edit
`_work/<name>.tr.json` by hand and run `merge`, which uses the strings already
there and never calls the model. `--force` writes it anyway.

Warnings are printed but do not block: a string returned unchanged, or one much
shorter or longer than its source, which is what a dropped sentence and an
added explanation look like.

Step `id`s are always dropped. A step id names a child's schedule row and
recorded answers, so a translated copy carrying the original's ids would show
one child's progress in the wrong tutorial. The app's import drops them too;
this is the second lock on the same door.

`run` skips a tutorial whose output already exists, so an interrupted batch is
resumed by running it again. `--redo` translates again from scratch.
"""

import argparse
import copy
import glob
import json
import os
import re
import shutil
import subprocess
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
PROMPT_FILE = os.path.join(HERE, 'prompt.md')

# The seven languages a tutorial may say it is written in — the app's
# `TutorialLanguage` and the server's `services/tutorialLanguage.js`. A code
# outside them is refused by the server with the whole save, so it is refused
# here before a single request is made.
TUTORIAL_LANGUAGES = ('en', 'sr-Latn', 'sr-Cyrl', 'de', 'es', 'it', 'fr')

# A part title the app generated — „Part 3", or „Deo 3" from before its English
# pivot. Not prose: the app shows it in its own words, so it is left out of the
# translation, and a „Teil 3" coming back would read to the app as a name the
# trainer chose. The same rule as `isGeneratedSectionTitle` in
# chess_app/lib/features/lessons/models/part_titles.dart.
GENERATED_PART_TITLE = re.compile(r'^(Part|Deo|Primer)\s+\d+$')

COMMENT = re.compile(r'\{([^}]*)\}')
COMMAND = re.compile(r'\[%[^\]]*\]')

# The notation a translation must keep, token for token.
SAN = re.compile(
    r'(?<!\w)(?:O-O-O|O-O|0-0-0|0-0'
    r'|[KQRBN][a-h]?[1-8]?x?[a-h][1-8](?:=[QRBN])?[+#]?'
    r'|[a-h]x[a-h][1-8](?:=[QRBN])?[+#]?'
    r'|[a-h][1-8](?:=[QRBN])?[+#]?)(?!\w)')
# A move number only when a move follows it, so that „1. **King position**" in
# a markdown list and „mate in 3." at the end of a sentence are not counted.
MOVE_NUMBER = re.compile(
    r'(?<![\w.])\d{1,3}\.(?:\.\.)?(?=\s*(?:O-O|0-0|[KQRBN]?[a-h]?x?[a-h][1-8]))')
CYRILLIC = re.compile(r'[Ѐ-ӿ]')
COMMENT_KEY = re.compile(r'\.c\d+$')

# Items per request, counted in characters of source text. The whole prompt is
# one command-line argument, and Windows stops at 32 767 characters.
CHUNK_CHARS = 12000

SCHEMA = json.dumps({
    'type': 'object',
    'properties': {
        'items': {
            'type': 'array',
            'items': {
                'type': 'object',
                'properties': {'id': {'type': 'string'}, 'text': {'type': 'string'}},
                'required': ['id', 'text'],
            },
        },
    },
    'required': ['items'],
})


def notation(text):
    return sorted(SAN.findall(text) + MOVE_NUMBER.findall(text))


def prose_of(comment_body):
    return ' '.join(COMMAND.sub(' ', comment_body).split())


# --- Out of the tutorial, and back in -----------------------------------------

def extract(tutorial):
    """Every piece of prose in [tutorial], keyed by where it lives."""
    out = {}

    def put(key, value):
        if isinstance(value, str) and value.strip():
            out[key] = value

    put('title', tutorial.get('title'))
    put('description', tutorial.get('description'))
    for i, step in enumerate(tutorial.get('positionList') or [], 1):
        title = step.get('title')
        if not (isinstance(title, str)
                and GENERATED_PART_TITLE.match(title.strip())):
            put('p%d.title' % i, title)
        put('p%d.instruction' % i, step.get('instruction'))
        for k, choice in enumerate(step.get('choices') or [], 1):
            put('p%d.choice%d' % (i, k), choice.get('text'))
        for m, match in enumerate(COMMENT.finditer(step.get('pgn') or ''), 1):
            put('p%d.c%d' % (i, m), prose_of(match.group(1)))
    return out


def merge(tutorial, tr, tags=None, code=None):
    """[tutorial] with every string [tr] names replaced, and step ids dropped.

    [code] is the language the translation is in. Without one the field is
    **removed**, not kept: a source that said „en" and was translated into
    Serbian would otherwise still say „en", and be read aloud in English.
    """
    new = copy.deepcopy(tutorial)
    if code:
        new['language'] = code
    else:
        new.pop('language', None)
    if 'title' in tr:
        new['title'] = tr['title']
    if 'description' in tr:
        new['description'] = tr['description']
    if tags:
        new['tags'] = list(dict.fromkeys((new.get('tags') or []) + tags))
    for i, step in enumerate(new.get('positionList') or [], 1):
        step.pop('id', None)
        if 'p%d.title' % i in tr:
            step['title'] = tr['p%d.title' % i]
        if 'p%d.instruction' % i in tr:
            step['instruction'] = tr['p%d.instruction' % i]
        for k, choice in enumerate(step.get('choices') or [], 1):
            if 'p%d.choice%d' % (i, k) in tr:
                choice['text'] = tr['p%d.choice%d' % (i, k)]

        counter = [0]

        def rewrite(match, i=i, counter=counter):
            counter[0] += 1
            key = 'p%d.c%d' % (i, counter[0])
            if key not in tr:
                return match.group(0)
            commands = COMMAND.findall(match.group(1))
            # Commands stay on the side of the words they were on, so that a
            # comment whose text changed differs from its source in the text.
            if match.group(1).strip().startswith('[%'):
                return '{ %s }' % ' '.join(commands + [tr[key]])
            return '{ %s }' % ' '.join([tr[key]] + commands)

        if step.get('pgn'):
            step['pgn'] = COMMENT.sub(rewrite, step['pgn'])
    return new


def prove_untouched(src, new):
    """Raise if anything but prose differs. A failure here is a bug in this
    script, never in the translation, so it stops the run."""
    a, b = src.get('positionList') or [], new.get('positionList') or []
    assert len(a) == len(b), 'the number of parts changed'
    for i, (s, n) in enumerate(zip(a, b), 1):
        for field in ('fen', 'kind', 'solutionSan', 'acceptedSans', 'blackOrientation'):
            assert s.get(field) == n.get(field), 'part %d: %s changed' % (i, field)
        sc, nc = s.get('choices') or [], n.get('choices') or []
        assert [c.get('correct') for c in sc] == [c.get('correct') for c in nc], \
            'part %d: which answer is correct changed' % i
        strip = lambda p: COMMENT.sub('{}', p or '')
        assert strip(s.get('pgn')) == strip(n.get('pgn')), \
            'part %d: the pgn changed outside its comments' % i
        cmds = lambda p: [COMMAND.findall(c) for c in COMMENT.findall(p or '')]
        assert cmds(s.get('pgn')) == cmds(n.get('pgn')), \
            'part %d: an arrow or a coloured square changed' % i


# --- What a translated string must satisfy ------------------------------------

def judge(src, tr, language):
    """(faults, warnings), each a {id: reason}."""
    faults, warnings = {}, {}
    latin = 'latin' in language.lower()
    for key, text in src.items():
        if key not in tr:
            faults[key] = 'missing from the translation'
            continue
        out = tr[key]
        if not isinstance(out, str) or not out.strip():
            faults[key] = 'translated to nothing'
            continue
        want, got = Counter(notation(text)), Counter(notation(out))
        if want != got:
            faults[key] = 'notation differs - lost %s, gained %s' % (
                ' '.join(sorted((want - got).elements())) or 'nothing',
                ' '.join(sorted((got - want).elements())) or 'nothing')
            continue
        if COMMENT_KEY.search(key) and ('{' in out or '}' in out or '[%' in out):
            faults[key] = 'a comment must not contain {, } or [%'
            continue
        if latin and CYRILLIC.search(out):
            faults[key] = 'Cyrillic letters in a Latin-script translation'
            continue
        if out.strip() == text.strip() and re.search(r'[A-Za-z]{4,}', text):
            warnings[key] = 'returned unchanged'
        elif len(text) >= 40 and not 0.5 <= len(out) / len(text) <= 2.2:
            warnings[key] = 'length %d against %d in the source' % (len(out), len(text))
    for key in tr:
        if key not in src:
            faults[key] = 'not in the source - invented by the model'
    return faults, warnings


# --- The model ----------------------------------------------------------------

def find_agy():
    found = shutil.which('agy')
    if found:
        return found
    guess = os.path.expanduser(r'~\AppData\Local\agy\bin\agy.exe')
    if os.path.exists(guess):
        return guess
    sys.exit('agy not found. Install the Antigravity CLI or put it on PATH.')


def chunks(items):
    batch, size = {}, 0
    for key, text in items.items():
        if batch and size + len(text) > CHUNK_CHARS:
            yield batch
            batch, size = {}, 0
        batch[key] = text
        size += len(text)
    if batch:
        yield batch


def ask(items, language, model, workdir, note=None):
    """Translations of [items] from agy, as {id: text}."""
    with open(PROMPT_FILE, encoding='utf-8') as fh:
        template = fh.read()
    result = {}
    for part in chunks(items):
        prompt = template.replace('{language}', language)
        if note:
            prompt += '\n\n## A correction\n\n' + note
        prompt += '\n\n## Items\n\n' + json.dumps(
            [{'id': k, 'text': v} for k, v in part.items()], ensure_ascii=False, indent=1)
        cmd = [find_agy(), '-p', prompt, '--output-format', 'json',
               '--json-schema', SCHEMA, '--model', model, '--print-timeout', '10m']
        # An empty folder as the working directory, so the agent has nothing
        # in its workspace to read instead of the items it was handed.
        p = subprocess.run(cmd, cwd=workdir, capture_output=True, encoding='utf-8',
                           errors='replace', timeout=12 * 60)
        try:
            answer = json.loads(p.stdout)
        except ValueError:
            raise RuntimeError('agy did not answer in JSON (exit %d): %s' % (
                p.returncode, (p.stdout or p.stderr).strip()[:400]))
        if answer.get('status') != 'SUCCESS':
            raise RuntimeError('agy: %s' % (answer.get('error') or answer.get('status')))
        got = (answer.get('structured_output') or {}).get('items')
        if not isinstance(got, list):
            raise RuntimeError('agy answered without the items it was asked for')
        for entry in got:
            key, text = entry.get('id'), entry.get('text')
            if key in result:
                raise RuntimeError('the model returned %s twice' % key)
            result[key] = text
    return result


# --- The batch ----------------------------------------------------------------

def sources(src):
    if os.path.isdir(src):
        return sorted(glob.glob(os.path.join(src, '*.json')))
    return [src]


def save_json(path, data):
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write('\n')


def one(path, args, offline, report):
    name = os.path.basename(path)
    stem = name[:-5] if name.lower().endswith('.json') else name
    target = os.path.join(args.out, name)
    work = os.path.join(args.out, '_work')
    src_path = os.path.join(work, stem + '.src.json')
    tr_path = os.path.join(work, stem + '.tr.json')

    if os.path.exists(target) and not args.redo and not offline:
        report.append('SKIPPED  %s - already translated (--redo to do it again)' % name)
        return True

    with open(path, encoding='utf-8') as fh:
        tutorial = json.load(fh)
    src = extract(tutorial)
    save_json(src_path, src)

    tr = {}
    if os.path.exists(tr_path) and not args.redo:
        with open(tr_path, encoding='utf-8') as fh:
            tr = json.load(fh)
    elif offline:
        report.append('FAILED   %s - no %s to merge; run `run` first' % (name, os.path.basename(tr_path)))
        return False

    try:
        if not offline:
            missing = {k: v for k, v in src.items() if k not in tr}
            if missing:
                print('  %s: %d strings to translate' % (name, len(missing)), flush=True)
                tr.update(ask(missing, args.language, args.model, work))
                save_json(tr_path, tr)
            faults, _ = judge(src, tr, args.language)
            # Once more, and only for what was rejected, with the reasons.
            retry = {k: src[k] for k in faults if k in src}
            if retry:
                print('  %s: %d rejected, asking again' % (name, len(retry)), flush=True)
                note = ('Your earlier translation of the items below was rejected. '
                        'Translate them again and follow every rule above.\n\n' +
                        '\n'.join('- %s: %s' % (k, faults[k]) for k in retry))
                tr.update(ask(retry, args.language, args.model, work, note))
                for key in [k for k in tr if k not in src]:
                    del tr[key]
                save_json(tr_path, tr)
    except (RuntimeError, subprocess.TimeoutExpired) as e:
        report.append('FAILED   %s - %s' % (name, e))
        return False

    faults, warnings = judge(src, tr, args.language)
    lines = ['           %s: %s' % (k, v) for k, v in sorted(faults.items())]
    lines += ['           (warning) %s: %s' % (k, v) for k, v in sorted(warnings.items())]
    if faults and not args.force:
        report.append('REFUSED  %s - %d strings failed; edit _work/%s.tr.json and run merge'
                      % (name, len(faults), stem))
        report.extend(lines)
        return False

    translated = merge(tutorial, {k: v for k, v in tr.items() if k in src and k not in faults},
                       tags=args.tag, code=args.code)
    prove_untouched(tutorial, translated)
    save_json(target, translated)
    report.append('%s %s - %d strings%s' % (
        'FORCED  ' if faults else 'OK      ', name, len(src),
        ', %d warnings' % len(warnings) if warnings else ''))
    report.extend(lines)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('command', choices=['run', 'merge'])
    parser.add_argument('src', help='a tutorial .json, or a folder of them')
    parser.add_argument('out', help='the folder the translations are written to')
    parser.add_argument('--language', required=True,
                        help='the target language, in words: "Serbian (Latin script)"')
    parser.add_argument('--code', choices=TUTORIAL_LANGUAGES,
                        help='the language code written into every translated tutorial, '
                             'so the app reads it with a voice for it (docs/PLAN-JEZIK-GLASA.md). '
                             'Without it the field is removed: a translation must not keep '
                             'the code of the language it was translated from')
    parser.add_argument('--model', default='gemini-3.8-flash-high')
    parser.add_argument('--tag', action='append',
                        help='a label to add to every translated tutorial (repeatable)')
    parser.add_argument('--redo', action='store_true',
                        help='translate again, ignoring earlier output and strings')
    parser.add_argument('--force', action='store_true',
                        help='write a tutorial even when some strings failed; those keep the source text')
    args = parser.parse_args()

    os.makedirs(os.path.join(args.out, '_work'), exist_ok=True)
    report = ['Translation into %s, model %s' % (args.language, args.model)]
    if args.code:
        report.append('Every tutorial is marked "language": "%s".' % args.code)
    else:
        report.append('No --code: the translated tutorials say no language, and the '
                      'app reads them with the voice chosen in Settings.')
    report.append('')
    ok = 0
    files = sources(args.src)
    for path in files:
        if one(path, args, args.command == 'merge', report):
            ok += 1
    report += ['', '%d of %d written or already there.' % (ok, len(files))]
    text = '\n'.join(report) + '\n'
    with open(os.path.join(args.out, 'REPORT.txt'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    print(text)
    return 0 if ok == len(files) else 1


if __name__ == '__main__':
    sys.exit(main())
