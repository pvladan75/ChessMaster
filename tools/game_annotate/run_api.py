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
import urllib.parse
import urllib.request

import run_arm
import skeleton

HERE = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(run_arm.REPO, 'chess_backend', '.env')
# One provider is one row: where to post, which environment variable holds the
# key, and which of the two request shapes it speaks. Groq, DeepSeek, Azure
# OpenAI, OpenRouter and the rest are all the OpenAI chat shape, so a new vendor
# is a row here rather than a second script - and the grader, the engine check
# and the games below stay ignorant of all of it, which is what keeps a model
# comparison about the model.
PROVIDERS = {
    'gemini': {
        'url': ('https://generativelanguage.googleapis.com/v1beta/models/'
                '%s:generateContent'),
        'key_env': 'GEMINI_API_KEY',
        'shape': 'gemini',
    },
    'groq': {
        'url': 'https://api.groq.com/openai/v1/chat/completions',
        'key_env': 'GROQ_API_KEY',
        'shape': 'openai',
    },
    'deepseek': {
        'url': 'https://api.deepseek.com/chat/completions',
        'key_env': 'DEEPSEEK_API_KEY',
        'shape': 'openai',
    },
    # Azure speaks the same body and neither the same address nor the same
    # header: the deployment is in the URL with an `api-version`, and the key
    # goes in `api-key` rather than in `Authorization`. A row, because getting
    # either of those wrong is a 401 that reads like a bad key.
    'azure': {
        'url': None,                  # built from AZURE_OPENAI_ENDPOINT
        'key_env': 'AZURE_OPENAI_KEY',
        'shape': 'openai',
        'auth_header': 'api-key',
    },
    # Alibaba Cloud Model Studio. The address depends on the region the key
    # was made in and, for most regions, on a workspace id inside the host, so
    # it is read whole from DASHSCOPE_BASE_URL rather than written here - a key
    # is bound to its region, and a guessed host is a 401 that reads like a bad
    # key.
    'qwen': {
        'url': None,                  # built from DASHSCOPE_BASE_URL
        'key_env': 'DASHSCOPE_API_KEY',
        'shape': 'openai',
    },
    # Anything else that speaks the OpenAI chat API: pass --base-url.
    'openai-compatible': {
        'url': None,
        'key_env': 'LLM_API_KEY',
        'shape': 'openai',
    },
}

QWEN_DEFAULT_BASE_URL = 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1'

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


def from_env_file(name):
    """One setting out of `chess_backend/.env`, or None."""
    if not os.path.exists(ENV_FILE):
        return None
    for line in open(ENV_FILE, encoding='utf-8', errors='replace'):
        if line.startswith(name + '='):
            value = line.split('=', 1)[1].strip()
            if value and 'your_' not in value:
                return value
    return None


def api_key(provider):
    """The key for [provider], from the environment or from the backend's `.env`.

    Never printed, never written into a run's folder: this repository is public
    and a key in an artefact outlives the run that made it.
    """
    name = PROVIDERS[provider]['key_env']
    from_env = os.environ.get(name)
    if from_env and 'your_' not in from_env:
        return from_env
    found = from_env_file(name)
    if found:
        return found
    sys.exit('No %s in the environment or in chess_backend/.env.' % name)


def build(arm, name):
    spec = run_arm.ARMS[arm]
    pgn, pgn_path = run_arm.game_text(name, spec['input'])
    if arm == 'H':
        # Not the brief: the skeleton's own short task, with the moments and
        # their empty slots. The format contract is not in it, because the
        # model writes no JSON the app reads - only words the harness places.
        return skeleton.prompt(name), pgn_path

    with open(run_arm.BRIEF, encoding='utf-8') as fh:
        brief = fh.read()

    prompt = (brief
              .replace('{OUTPUT_INSTRUCTION}', OUTPUT_AS_ANSWER)
              .replace('{CLOSING}', CLOSING_API)
              .replace('{GAME_NOTE}', run_arm.game_note(arm, name))
              .replace('{GAME_DELIVERY}', GAME_INLINE.format(pgn=pgn))
              .replace('{TOOLS}', run_arm.NO_TOOL_TEXT)
              .replace('{FORMAT_CONTRACT}', run_arm.format_contract()))

    left = re.findall(r'\{[A-Z_]+\}', prompt)
    if left:
        sys.exit('the brief still has placeholders in it: %s' % ', '.join(left))
    return prompt, pgn_path


def ask(provider, model, prompt, timeout, thinking=None, base_url=None,
        max_tokens=16384, extra=None, stream=False):
    spec = PROVIDERS[provider]
    if spec['shape'] == 'openai':
        return ask_openai(provider, model, prompt, timeout, base_url, max_tokens,
                          extra, stream)
    # The Gemini shape needs no adjustment, so it answers with an empty list.

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
        (spec['url'] % model) + '?key=' + api_key(provider),
        data=body,
        headers={'Content-Type': 'application/json'},
    )
    answer, fault = send(request, timeout)
    return answer, fault, []


def azure_url(model):
    """`https://<resource>.openai.azure.com/openai/v1/chat/completions`

    The v1 path, which is what Azure documents for the GPT-5 and GPT-6
    reasoning models: no `api-version`, and the **deployment** name travels as
    the body's `model`. Setting `AZURE_OPENAI_API_VERSION` asks for the older
    dated path instead, `…/deployments/<deployment>/chat/completions`.
    """
    endpoint = (os.environ.get('AZURE_OPENAI_ENDPOINT')
                or from_env_file('AZURE_OPENAI_ENDPOINT'))
    if not endpoint:
        sys.exit('Set AZURE_OPENAI_ENDPOINT (https://<resource>.openai.azure.com) '
                 'in the environment or in chess_backend/.env.')
    # The portal's „Target URI" is the whole request address, path and
    # `api-version` included, and it is the obvious thing to copy. Only the
    # scheme and host are the resource, so that is all that is kept.
    parts = urllib.parse.urlsplit(endpoint.strip())
    if not parts.scheme or not parts.netloc:
        sys.exit('AZURE_OPENAI_ENDPOINT is not an address: expected '
                 'https://<resource>.openai.azure.com')
    endpoint = '%s://%s' % (parts.scheme, parts.netloc)
    version = (os.environ.get('AZURE_OPENAI_API_VERSION')
               or from_env_file('AZURE_OPENAI_API_VERSION'))
    if not version:
        return '%s/openai/v1/chat/completions' % endpoint
    return ('%s/openai/deployments/%s/chat/completions?api-version=%s'
            % (endpoint, model, version))


def qwen_url():
    """The chat address under DASHSCOPE_BASE_URL, the compatible-mode base the
    console shows for the key's region.

    Absent, it is the international address from Qwen Cloud's own model page
    (13.9.2026). A key made in another region answers that with a 401, which is
    the signal to set the variable rather than to doubt the key.
    """
    base = (os.environ.get('DASHSCOPE_BASE_URL')
            or from_env_file('DASHSCOPE_BASE_URL')
            or QWEN_DEFAULT_BASE_URL)
    base = base.strip().rstrip('/')
    if base.endswith('/chat/completions'):
        return base
    return base + '/chat/completions'


def ask_openai(provider, model, prompt, timeout, base_url=None,
               max_tokens=16384, extra=None, stream=False):
    """The OpenAI chat shape: Groq, DeepSeek, Azure OpenAI, OpenRouter.

    `response_format` is asked for but not relied on - a reasoning model that
    ignores it still gets its object fished out by `rescue_json`, and whether it
    had to be is recorded in `meta.json` rather than smoothed over.
    """
    url = base_url or PROVIDERS[provider]['url']
    if provider == 'azure':
        url = base_url or azure_url(model)
    if provider == 'qwen':
        url = base_url or qwen_url()
    if not url:
        sys.exit('--base-url is required for the openai-compatible provider.')

    payload = {
        'model': model,
        'messages': [{'role': 'user', 'content': prompt}],
        'response_format': {'type': 'json_object'},
        # A reasoning model counts its thinking against this ceiling, so 16k —
        # enough for Gemini, whose thoughts are billed but budgeted apart — cut
        # both DeepSeek models off mid-thought with no answer written at all.
        'max_tokens': max_tokens,
        'temperature': 1.0,
    }

    # Vendor-specific switches (DeepSeek's `thinking` and `reasoning_effort`)
    # go in as given; `run` records them in `meta.json`.
    payload.update(extra or {})
    if stream:
        payload['stream'] = True
        payload['stream_options'] = {'include_usage': True}

    header = PROVIDERS[provider].get('auth_header')
    headers = {'Content-Type': 'application/json'}
    if header:
        headers[header] = api_key(provider)
    else:
        headers['Authorization'] = 'Bearer ' + api_key(provider)

    # Two refusals are worth surviving rather than reporting, because both are
    # about the request's shape and not about the work: a reasoning model that
    # cannot be asked for JSON (DeepSeek's reasoner is one), and a newer model
    # that wants `max_completion_tokens` where the older ones want `max_tokens`.
    # Each retry is recorded, so „it needed one" stays visible.
    adjustments = []
    while True:
        request = urllib.request.Request(
            url, data=json.dumps(payload).encode('utf-8'), headers=headers)
        answer, fault = (send_stream(request, timeout) if stream
                         else send(request, timeout))
        if not fault or not fault.startswith('HTTP 400'):
            return answer, fault, adjustments

        lowered = fault.lower()
        if 'response_format' in lowered and 'response_format' in payload:
            payload.pop('response_format')
            adjustments.append('no response_format')
            continue
        if 'max_tokens' in lowered and 'max_tokens' in payload:
            payload['max_completion_tokens'] = payload.pop('max_tokens')
            adjustments.append('max_completion_tokens')
            continue
        if 'temperature' in lowered and 'temperature' in payload:
            payload.pop('temperature')
            adjustments.append('no temperature')
            continue
        return answer, fault, adjustments


def send(request, timeout):
    try:
        with urllib.request.urlopen(request, timeout=timeout) as answer:
            return json.load(answer), None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', 'replace')[:600]
        # The key travels in the URL or a header, so neither goes into the
        # message: a failing run is exactly the thing somebody pastes into a
        # chat window.
        return None, 'HTTP %d: %s' % (exc.code, detail)
    except Exception as exc:                       # noqa: BLE001 - reported
        return None, '%s: %s' % (type(exc).__name__, exc)


def send_stream(request, timeout):
    """The same request as a stream, folded back into the non-streamed shape.

    Written on 13.9.2026, when two Qwen runs sat for thirteen minutes with no
    way to tell a model thinking from a connection nobody was answering. A
    stream says which every thirty seconds, and a read timeout then measures
    silence rather than the length of the whole answer. What arrived before a
    fault is reported with it and not kept: half a tutorial is not a result.
    """
    content, reasoning, usage, finish = [], [], None, None
    started = last = time.time()
    done = False
    try:
        with urllib.request.urlopen(request, timeout=timeout) as answer:
            for raw in answer:
                line = raw.decode('utf-8', 'replace').strip()
                if not line.startswith('data:'):
                    continue
                data = line[5:].strip()
                if data == '[DONE]':
                    done = True
                    break
                chunk = json.loads(data)
                if chunk.get('usage'):
                    usage = chunk['usage']
                for choice in chunk.get('choices') or []:
                    delta = choice.get('delta') or {}
                    if delta.get('content'):
                        content.append(delta['content'])
                    if delta.get('reasoning_content'):
                        reasoning.append(delta['reasoning_content'])
                    if choice.get('finish_reason'):
                        finish = choice['finish_reason']
                if time.time() - last >= 30:
                    last = time.time()
                    print('  ... %d characters of thinking, %d of answer'
                          % (sum(map(len, reasoning)), sum(map(len, content))),
                          flush=True)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode('utf-8', 'replace')[:600]
        return None, 'HTTP %d: %s' % (exc.code, detail)
    except Exception as exc:                       # noqa: BLE001 - reported
        return None, '%s: %s (after %d characters of thinking, %d of answer)' % (
            type(exc).__name__, exc, sum(map(len, reasoning)),
            sum(map(len, content)))
    # A stream the server simply closes is not an answer. The first version
    # read it as one: qwen3.8-max was cut off at 899 s mid-thought and the run
    # was recorded as finished, with no finish reason, no tokens and no file.
    if not done and finish is None:
        return None, ('the stream was closed after %.0f s with no finish reason '
                      '(%d characters of thinking, %d of answer)' % (
                          time.time() - started, sum(map(len, reasoning)),
                          sum(map(len, content))))
    return {
        'choices': [{
            'message': {'content': ''.join(content),
                        'reasoning_content': ''.join(reasoning)},
            'finish_reason': finish,
        }],
        'usage': usage or {},
    }, None


def text_of(answer):
    """The answer's text and why it stopped, from either shape."""
    if 'choices' in answer:
        choice = (answer.get('choices') or [{}])[0]
        message = choice.get('message') or {}
        return message.get('content') or '', choice.get('finish_reason')

    for candidate in answer.get('candidates', []):
        parts = (candidate.get('content') or {}).get('parts') or []
        joined = ''.join(p.get('text', '') for p in parts)
        if joined.strip():
            return joined, candidate.get('finishReason')
        return '', candidate.get('finishReason')
    return '', None


def reasoning_of(answer):
    """The OpenAI shape's `reasoning_content`, where a provider sends one."""
    choice = (answer.get('choices') or [{}])[0]
    return (choice.get('message') or {}).get('reasoning_content') or ''


def tokens_of(answer):
    """What the call cost, in whichever shape the provider reports it.

    The thinking count is kept apart from the answer count on purpose: this
    experiment's own finding is that the cheap configurations are cheap because
    they think not at all, and one total hides exactly that.
    """
    if 'usage' in answer:                               # the OpenAI shape
        usage = answer['usage'] or {}
        details = usage.get('completion_tokens_details') or {}
        return {
            'prompt': usage.get('prompt_tokens'),
            'answer': usage.get('completion_tokens'),
            'thoughts': details.get('reasoning_tokens'),
            'total': usage.get('total_tokens'),
        }
    usage = answer.get('usageMetadata') or {}
    return {
        'prompt': usage.get('promptTokenCount'),
        'answer': usage.get('candidatesTokenCount'),
        'thoughts': usage.get('thoughtsTokenCount'),
        'total': usage.get('totalTokenCount'),
    }


def run(cfg):
    arm = cfg.arm.upper()
    if arm == 'C':
        sys.exit('Arm C needs a tool loop, which this channel has not. '
                 'Use run_arm.py for it.')
    if arm not in run_arm.ARMS:
        sys.exit('the arms are A, B, F, G and H here')

    prompt, pgn_path = build(arm, cfg.name)
    stamp = time.strftime('%Y%m%d-%H%M%S')
    slug = re.sub(r'[^a-z0-9.]+', '-', cfg.model.lower())
    if cfg.thinking is not None:
        slug += '-think%d' % cfg.thinking
    if cfg.thinking_mode == 'disabled':
        slug += '-nothink'
    if cfg.reasoning_effort:
        slug += '-effort-' + cfg.reasoning_effort
    # The game is in the name, and an existing folder is refused rather than
    # reused: two games on one model started in the same second used to share a
    # folder, and one run's answer would have been graded as the other's.
    run_dir = os.path.join(run_arm.OUT_DIR,
                           '%s-api-%s-%s-%s' % (arm, slug, cfg.name, stamp))
    os.makedirs(run_dir, exist_ok=False)

    with open(os.path.join(run_dir, 'prompt.md'), 'w', encoding='utf-8') as fh:
        fh.write(prompt)

    meta = {
        'arm': arm, 'model': cfg.model, 'game': cfg.name,
        'channel': cfg.provider, 'input': run_arm.ARMS[arm]['input'],
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
          % (arm, cfg.model, len(prompt)), flush=True)
    if cfg.stream:
        meta['stream'] = True
    started = time.time()
    meta['max_tokens'] = cfg.max_tokens
    extra = {}
    if cfg.thinking_mode:
        # One switch, two spellings: DeepSeek nests it, Qwen takes a boolean.
        if cfg.provider == 'qwen':
            extra['enable_thinking'] = cfg.thinking_mode == 'enabled'
        else:
            extra['thinking'] = {'type': cfg.thinking_mode}
    if cfg.provider == 'qwen' and cfg.thinking is not None:
        extra['thinking_budget'] = cfg.thinking
    if cfg.reasoning_effort:
        extra['reasoning_effort'] = cfg.reasoning_effort
    if extra:
        meta['request_extra'] = extra
    answer, fault, adjustments = ask(cfg.provider, cfg.model, prompt,
                                     cfg.timeout, cfg.thinking, cfg.base_url,
                                     cfg.max_tokens, extra, cfg.stream)
    if adjustments:
        meta['request_adjusted'] = adjustments
    meta['seconds'] = round(time.time() - started, 1)

    if fault:
        meta['error'] = fault
        run_arm.save(run_dir, 'meta.json', meta)
        print('failed: %s' % fault)
        sys.exit(1)

    body, finish = text_of(answer)
    meta['finish_reason'] = finish
    meta['tokens'] = tokens_of(answer)

    run_arm.save_text(run_dir, 'reply.txt', body)
    # DeepSeek returns its thinking beside the answer. Kept, because a run that
    # spends its whole ceiling thinking and answers nothing can only be
    # diagnosed from what it was thinking about.
    reasoning = reasoning_of(answer)
    if reasoning:
        run_arm.save_text(run_dir, 'reasoning.txt', reasoning)
    rescued = body if body.strip().startswith('{') else run_arm.rescue_json(body)
    meta['answer_was_json'] = bool(rescued) and body.strip().startswith('{')
    if rescued and arm == 'H':
        # The answer is words, not a tutorial: kept as it came, and the
        # tutorial is assembled from the skeleton around it.
        run_arm.save_text(run_dir, 'answer.json', rescued)
        skeleton.assemble(run_dir, cfg.name, meta, rescued)
        rescued = rescued if os.path.exists(os.path.join(run_dir, 'tutorial.json')) else None
    elif rescued:
        run_arm.save_text(run_dir, 'tutorial.json', rescued)
        if arm in run_arm.POSITION_TABLE_ARMS:
            run_arm.apply_positions(run_dir, cfg.name, meta, arm)
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
    parser.add_argument('--provider', default='gemini', choices=sorted(PROVIDERS))
    parser.add_argument('--base-url', help='for --provider openai-compatible')
    parser.add_argument('--model', default='gemini-2.5-flash-lite')
    parser.add_argument('--thinking', type=int, default=None,
                        help='thinking budget in tokens; -1 asks the '
                             'model to decide, 0 turns it off, absent '
                             'leaves the model default')
    parser.add_argument('--thinking-mode', choices=['enabled', 'disabled'],
                        help="DeepSeek's `thinking.type`; absent leaves the "
                             'model default, which is enabled')
    # The union of both vendors' values; each model accepts a subset and says
    # so with a 400. DeepSeek: low, high, max. Azure: none (not GPT-6),
    # minimal (original GPT-5 only), low, medium, high, xhigh.
    parser.add_argument('--reasoning-effort',
                        choices=['none', 'minimal', 'low', 'medium', 'high',
                                 'xhigh', 'max'],
                        help='`reasoning_effort`; absent leaves the model default')
    parser.add_argument('--max-tokens', type=int, default=16384,
                        help='output ceiling for the OpenAI shape; a '
                             'reasoning model spends its thinking out of it')
    parser.add_argument('--stream', action='store_true',
                        help='OpenAI shape only: stream the answer and print '
                             'progress every 30 s; the timeout then measures '
                             'silence, not the whole answer')
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--dry-run', action='store_true')
    run(parser.parse_args())


if __name__ == '__main__':
    main()
