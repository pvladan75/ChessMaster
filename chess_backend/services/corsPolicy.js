// corsPolicy.js — which browser origins this server answers, and why one of
// them is itself.
//
// The allowlist was written when this backend served a JSON API and nothing
// else. Native Android and Windows clients send no `Origin` header at all, so
// any request that carried one came from a browser that was, by definition,
// somebody else's page. Refusing every unlisted origin was exactly right.
//
// Then the parent's consent page arrived — one HTML page, served by this very
// server, with a form that posts back to it. That request carries
// `Origin: <this server>`, which was not on the list, so it was refused.
//
// **The half that made it invisible:** a browser sends no `Origin` on ordinary
// top-level navigation, and does send one on a form POST. So the page opened
// perfectly and only the button failed — and the button is the whole point of
// the page. A parent would have seen a consent form that refuses to record
// consent, with `{"error":"Origin not allowed"}` where the answer should be.
//
// The rule that was missing: **a request from this server's own origin is not a
// cross-origin request.** The allowlist exists to keep *other* origins out, and
// same-origin is the case it was never meant to judge.

/// What the CORS gate should do with one request.
///
/// Four answers rather than a boolean, because the caller does different things
/// with them and lumping them together is how the same-origin case disappeared
/// in the first place:
///
///   * `no-origin` — a native client, curl, or a same-origin navigation. Passes,
///     and gets no CORS headers because it needs none.
///   * `allowed` — a listed browser origin. Passes *and* gets the headers, which
///     is the only case that actually needs them.
///   * `same-origin` — our own page talking to us. Passes; headers are pointless
///     here and their absence is not a refusal.
///   * `blocked` — a browser origin that is neither listed nor ours.
///
/// `host` is the request's `Host` header rather than anything configured: it is
/// what the browser actually asked for, so it stays right behind a proxy, on a
/// LAN address, and after the domain changes.
function corsVerdict(origin, host, allowlist = []) {
  if (!origin) return 'no-origin';
  if (allowlist.includes(origin)) return 'allowed';
  if (isSameOrigin(origin, host)) return 'same-origin';
  return 'blocked';
}

/// Whether the origin naming itself is the host being asked.
///
/// Compared on `host` (name plus port) rather than on the whole string, because
/// the two are written differently — an origin carries the scheme and the Host
/// header does not. A malformed origin is not same-origin: `new URL` throwing is
/// an answer, and the answer is no.
function isSameOrigin(origin, host) {
  if (!origin || !host) return false;
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}

/// The `ALLOWED_ORIGINS` line, as a list. Empty means no browser origin is
/// listed — which is the shipped state, and fine, because the app is native and
/// the only browser page this server has is its own.
function parseAllowedOrigins(raw) {
  return String(raw ?? '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
}

module.exports = { corsVerdict, isSameOrigin, parseAllowedOrigins };
