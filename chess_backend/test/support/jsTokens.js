// jsTokens.js
// A small JavaScript tokenizer for tests that read the server's own sources.
//
// Read by structure, never by slicing or plain text matching (CLAUDE.md,
// rule 4): a comment, a string or a regex literal all match a `contains`, and
// a comma inside a template's `${…}` is not a comma between two arguments.
// There is no JavaScript parser in `node_modules`, and one is not added for a
// test, so this does the least a reader of calls needs:
//
//   - comments are dropped;
//   - a string is one token, with its text;
//   - a template literal is one token, with its text outside `${…}` and the
//     tokens of every `${…}` kept apart in `inner`, so a comma inside one is
//     never taken for a comma between arguments;
//   - a regex literal is one token, told from a division by the token before
//     it;
//   - every bracket is matched, and a file whose brackets do not match — which
//     is what a regex taken for a division, or the other way round, leaves
//     behind — **throws**, naming the file and the line. A tokenizer that
//     guessed wrong must be loud, never quietly skip half a file.

/// Words after which a `/` begins a regex rather than a division.
const REGEX_AFTER_WORD = new Set([
  'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void',
  'throw', 'case', 'do', 'else', 'yield', 'await',
]);

const CLOSES = { ')': '(', ']': '[', '}': '{' };

function isIdentStart(ch) {
  return /[A-Za-z_$#]/.test(ch) || ch.charCodeAt(0) > 127;
}

function isIdentPart(ch) {
  return /[\w$]/.test(ch) || ch.charCodeAt(0) > 127;
}

function lineOf(src, at) {
  let line = 1;
  for (let i = 0; i < at && i < src.length; i += 1) if (src[i] === '\n') line += 1;
  return line;
}

/// The tokens of `src`. `name` is used only to say where a failure is.
///
/// Every token is `{ type, value, start, end }`; `type` is one of `ident`,
/// `number`, `punct`, `string`, `template` or `regex`. A string's `value` is
/// its text without the quotes, escapes left as written. A template's `value`
/// is its text outside `${…}` (each `${…}` shown as `${}`), and `inner` holds
/// one token list per `${…}`.
function tokenize(src, name = '<source>') {
  let i = 0;

  const fail = (message, at = i) => {
    throw new Error(`${name}:${lineOf(src, at)}: ${message}`);
  };

  const regexAllowed = (prev) => {
    if (!prev) return true;
    if (prev.type === 'ident') return REGEX_AFTER_WORD.has(prev.value);
    if (prev.type === 'punct') return ![')', ']', '}'].includes(prev.value);
    return false;
  };

  const readQuoted = (quote) => {
    const start = i;
    i += 1;
    let text = '';
    while (i < src.length && src[i] !== quote) {
      if (src[i] === '\\') {
        text += src.slice(i, i + 2);
        i += 2;
        continue;
      }
      if (src[i] === '\n') fail('a string runs past the end of its line', start);
      text += src[i];
      i += 1;
    }
    if (i >= src.length) fail('a string is never closed', start);
    i += 1;
    return { type: 'string', value: text, start, end: i };
  };

  const readRegex = () => {
    const start = i;
    i += 1;
    let inClass = false;
    while (i < src.length) {
      const ch = src[i];
      if (ch === '\n') fail('a regex runs past the end of its line', start);
      if (ch === '\\') { i += 2; continue; }
      if (inClass) {
        if (ch === ']') inClass = false;
      } else if (ch === '[') {
        inClass = true;
      } else if (ch === '/') {
        break;
      }
      i += 1;
    }
    if (i >= src.length) fail('a regex is never closed', start);
    i += 1;
    while (i < src.length && /[a-z]/.test(src[i])) i += 1;
    return { type: 'regex', value: src.slice(start, i), start, end: i };
  };

  // Reads tokens until the end of the source or, when `insideTemplate`, until
  // the `}` that closes the `${` it was called for.
  const readTokens = (insideTemplate) => {
    const tokens = [];
    const open = [];
    while (i < src.length) {
      const ch = src[i];
      const next = src[i + 1];

      if (/\s/.test(ch)) { i += 1; continue; }
      if (ch === '/' && next === '/') {
        while (i < src.length && src[i] !== '\n') i += 1;
        continue;
      }
      if (ch === '/' && next === '*') {
        const end = src.indexOf('*/', i + 2);
        if (end === -1) fail('a block comment is never closed');
        i = end + 2;
        continue;
      }
      if (ch === '#' && next === '!' && i === 0) {
        while (i < src.length && src[i] !== '\n') i += 1;
        continue;
      }

      const prev = tokens[tokens.length - 1];
      if (ch === '\'' || ch === '"') { tokens.push(readQuoted(ch)); continue; }
      if (ch === '`') { tokens.push(readTemplate()); continue; }
      if (ch === '/' && regexAllowed(prev)) { tokens.push(readRegex()); continue; }

      if (isIdentStart(ch)) {
        const start = i;
        i += 1;
        while (i < src.length && isIdentPart(src[i])) i += 1;
        tokens.push({ type: 'ident', value: src.slice(start, i), start, end: i });
        continue;
      }
      if (/[0-9]/.test(ch)) {
        const start = i;
        while (i < src.length && /[\w.]/.test(src[i])) i += 1;
        tokens.push({ type: 'number', value: src.slice(start, i), start, end: i });
        continue;
      }

      if (ch === '(' || ch === '[' || ch === '{') {
        open.push({ ch, at: i });
      } else if (ch in CLOSES) {
        if (open.length === 0) {
          if (insideTemplate && ch === '}') {
            i += 1;
            return tokens;
          }
          fail(`\`${ch}\` closes nothing`);
        }
        const top = open.pop();
        if (top.ch !== CLOSES[ch]) fail(`\`${ch}\` closes \`${top.ch}\` from line ${lineOf(src, top.at)}`);
      }
      tokens.push({ type: 'punct', value: ch, start: i, end: i + 1 });
      i += 1;
    }
    if (insideTemplate) fail('a template\'s `${` is never closed');
    if (open.length > 0) {
      const top = open[open.length - 1];
      fail(`\`${top.ch}\` is never closed`, top.at);
    }
    return tokens;
  };

  const readTemplate = () => {
    const start = i;
    i += 1;
    let text = '';
    const inner = [];
    while (i < src.length && src[i] !== '`') {
      if (src[i] === '\\') {
        text += src.slice(i, i + 2);
        i += 2;
        continue;
      }
      if (src[i] === '$' && src[i + 1] === '{') {
        i += 2;
        inner.push(readTokens(true));
        text += '${}';
        continue;
      }
      text += src[i];
      i += 1;
    }
    if (i >= src.length) fail('a template literal is never closed', start);
    i += 1;
    return { type: 'template', value: text, inner, start, end: i };
  };

  return readTokens(false);
}

module.exports = { tokenize, lineOf };
