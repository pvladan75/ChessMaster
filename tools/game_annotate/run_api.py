"""The same task, sent straight to the Gemini API instead of through `agy`.

    python run_api.py B --model gemini-2.5-flash-lite
    python run_api.py A --model gemini-2.5-flash --name french_2026-06-19
    python run_api.py B --model gemini-2.5-flash-lite --dry-run

Written on 13.9.2026 to answer one question: the cheap models are not in the
Antigravity CLI's list, and the price of running this over a hundred games
differs by a factor of twenty between the top of that list and the bottom. Only
the API can be asked whether the cheap end can do the work at all.

**It reports what a run actually cost**, out of the response's own
`usageMetadata` — prompt tokens, answer tokens, and the answer's thinking
tokens where the model has them. A price table is somebody else's arithmetic
over somebody else's assumptions about length; this is the length.

**Arms A and B only.** Arm C is a model with a tool in its hand, which is an
agent loop and not one request; `run_arm.py` is where that lives.

**The channel is not the same as `run_arm.py`'s, and that is stated rather than
hidden.** There is no working directory here, so the game is inlined in the
prompt and the answer comes back as the response body instead of as a file the
model wrote. Both differences are visible in the prompt this script saves.
Compare an API run against another API run; comparing one against a CLI run
measures the channel as well as the model.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

import run_arm

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(run_arm.REPO, 'chess_backend', '.env')
ENDPOINT = ('https://generativelanguage.googleapis.com/v1beta/models/'
            '%s:generateContent')

OUTPUT_AS_ANSWER = """Return the tutorial as a single JSON object, and return
nothing else at all: no prose before or after it, no code fence, no explanation.
Your whole answer is that object."""

GAME_INLINE = """It is the game below.

```
{pgn}
```"""

CLOSING_API = """Check your own work against the rules in the contract before
you answer, and then answer with the JSON object alone. There is nowhere in this
channel to put remarks, so anything that is not the object will be read as part
of it and break the file."""


def api_key():
    """The key, from the environment or from the backend's `.env`.

    Never printed, never written into a run's folder: this repository is public
    and a key in an artefact outlives the run that made it.
    """
    from_env = os.environ.get('GEMINI_API_KEY')
    if from_env and 'your_gemini' not in from_env:
        return from_env
    if os.path.exists(ENV_FILE):
        for line in open(ENV_FILE, encoding='utf-8', errors='replace'):
            if line.startswith('GEMINI_API_KEY='):
                value = line.split('=', 1)[1].strip()
                if value and 'your_gemini' not in value:
                    return value
    sys.exit('No GEMINI_API_KEY in the environment or in chess_backend/.env.')


def build(arm, name):
    spec = run_arm.ARMS[arm]
    pgn, pgn_path = run_arm.game_text(name, spec['input'])

    with open(run_arm.BRIEF, encoding='utf-8') as fh:
        brief = fh.read()

    prompt = (brief
              .replace('{OUTPUT_INSTRUCTION}', OUTPUT_AS_ANSWER)
              .replace('{CLOSING}', CLOSING_API)
              .replace('{GAME_NOTE}', spec['note'] or run_arm.ARMS['B']['note'])
              .replace('{GAME_DELIVERY}', GAME_INLINE.format(pgn=pgn))
              .replace('{TOOLS}', run_arm.NO_TOOL_TEXT)
              .replace('{FORMAT_CONTRACT}', run_arm.format_contract()))

    left = re.findall(r'\{[A-Z_]+\}', prompt)
    if left:
        sys.exit('the brief still has placeholders in it: %s' % ', '.join(left))
    return prompt, pgn_path


def ask(model, prompt, timeout, thinking=None):
    body = json.dumps({
        'contents': [{'parts': [{'text': prompt}]}],
        'generationConfig': {
            # The answer is the artefact, so it is asked for as JSON rather
            # than fished out of prose afterwards. A model that cannot hold to
            # it fails here loudly instead of producing a file that almost
            # parses.
            'responseMimeType': 'application/json',
            'maxOutputTokens': 16384,
            'temperature': 1.0,
            # Absent means the model's own default, which for the Lite models
            # is no thinking at all - they answered this brief in four seconds
            # with zero thinking tokens. A budget is what makes „can it do this"
            # a question about the model rather than about a default.
            **({'thinkingConfig': {'thinkingBudget': thinking}}
               if thinking is not None else {}),
        },
    }).encode('utf-8')

    request = urllib.request.Request(
        (ENDPOINT % model) + '?key=' + api_key(),
        data=body,
        headers={'Content-Type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as answer:
            return json.load(answer), None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', 'replace')[:600]
        # The key is in the URL, so the URL never goes into the message.
        return None, 'HTTP %d: %s' % (exc.code, detail)
    except Exception as exc:                       # noqa: BLE001 - reported
        return None, '%s: %s' % (type(exc).__name__, exc)


def text_of(answer):
    for candidate in answer.get('candidates', []):
        parts = (candidate.get('content') or {}).get('parts') or []
        joined = ''.join(p.get('text', '') for p in parts)
        if joined.strip():
            return joined, candidate.get('finishReason')
        return '', candidate.get('finishReason')
    return '', None


def run(cfg):
    arm = cfg.arm.upper()
    if arm == 'C':
        sys.exit('Arm C needs a tool loop, which this channel has not. '
                 'Use run_arm.py for it.')
    if arm not in run_arm.ARMS:
        sys.exit('the arms are A and B here')

    prompt, pgn_path = build(arm, cfg.name)
    stamp = time.strftime('%Y%m%d-%H%M%S')
    slug = re.sub(r'[^a-z0-9.]+', '-', cfg.model.lower())
    if cfg.thinking is not None:
        slug += '-think%d' % cfg.thinking
    run_dir = os.path.join(run_arm.OUT_DIR, '%s-api-%s-%s' % (arm, slug, stamp))
    os.makedirs(run_dir, exist_ok=True)

    with open(os.path.join(run_dir, 'prompt.md'), 'w', encoding='utf-8') as fh:
        fh.write(prompt)

    meta = {
        'arm': arm, 'model': cfg.model, 'game': cfg.name,
        'channel': 'gemini-api', 'input': run_arm.ARMS[arm]['input'],
        'started': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'prompt_characters': len(prompt),
        'thinking_budget': cfg.thinking,
    }

    if cfg.dry_run:
        meta['dry_run'] = True
        run_arm.save(run_dir, 'meta.json', meta)
        print('prompt written, model not called:\n  %s'
              % os.path.relpath(os.path.join(run_dir, 'prompt.md'), HERE))
        return

    print('arm %s, %s, %d characters of prompt - asking...'
          % (arm, cfg.model, len(prompt)))
    started = time.time()
    answer, fault = ask(cfg.model, prompt, cfg.timeout, cfg.thinking)
    meta['seconds'] = round(time.time() - started, 1)

    if fault:
        meta['error'] = fault
        run_arm.save(run_dir, 'meta.json', meta)
        print('failed: %s' % fault)
        sys.exit(1)

    body, finish = text_of(answer)
    meta['finish_reason'] = finish
    usage = answer.get('usageMetadata') or {}
    meta['tokens'] = {
        'prompt': usage.get('promptTokenCount'),
        'answer': usage.get('candidatesTokenCount'),
        'thoughts': usage.get('thoughtsTokenCount'),
        'total': usage.get('totalTokenCount'),
    }

    run_arm.save_text(run_dir, 'reply.txt', body)
    rescued = body if body.strip().startswith('{') else run_arm.rescue_json(body)
    meta['answer_was_json'] = bool(rescued) and body.strip().startswith('{')
    if rescued:
        run_arm.save_text(run_dir, 'tutorial.json', rescued)
    meta['wrote_the_file'] = bool(rescued)

    run_arm.save(run_dir, 'meta.json', meta)
    print('%s in %.0f s, finish %s, tokens %s in / %s out%s'
          % (os.path.relpath(run_dir, HERE), meta['seconds'], finish,
             meta['tokens']['prompt'], meta['tokens']['answer'],
             '' if meta['wrote_the_file'] else ', NO JSON IN THE ANSWER'))
    print('Grade it:\n  cd %s && dart run tool/grade_tutorial.dart "%s"'
          % (os.path.join(run_arm.REPO, 'chess_app'), run_dir))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('arm', help='A or B')
    parser.add_argument('--name', default='pvladan_2026-09-12')
    parser.add_argument('--model', default='gemini-2.5-flash-lite')
    parser.add_argument('--thinking', type=int, default=None,
                        help='thinking budget in tokens; -1 asks the '
                             'model to decide, 0 turns it off, absent '
                             'leaves the model default')
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--dry-run', action='store_true')
    run(parser.parse_args())


if __name__ == '__main__':
    main()
