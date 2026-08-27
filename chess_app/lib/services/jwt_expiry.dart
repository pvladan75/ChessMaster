import 'dart:convert';

/// What a token says about its own lifetime.
///
/// The server is the only thing that can *prove* a token; this reads what the
/// token claims about when it stops being accepted. That is enough for the one
/// job it has — stopping the app from acting signed in while holding a slip
/// that is certainly dead — and it is deliberately useless for the opposite
/// job: a token this cannot read comes back as "no answer", never as expired.
///
/// The rule is the server's own, from `services/accountGuard.js`: **"I could
/// not tell" must not arrive as "you are out."** Getting that backwards here
/// would sign people out over a token shape this parser has not met.
///
/// Nothing is verified. The signature is not checked and must not be trusted;
/// `exp` is a claim, and a forged one only ever makes this *more* eager to send
/// somebody to the login screen, which the server would do anyway.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return null;
    final exp = payload['exp'];
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).round(),
      isUtc: true,
    );
  } catch (_) {
    // Not a JWT, not base64, not JSON, or an `exp` that is not a number. All of
    // them mean the same thing here: this token says nothing about when it dies.
    return null;
  }
}

/// Whether [token] is past its own expiry.
///
/// [leeway] counts a token that dies in the next few seconds as already dead,
/// because the alternative is a request that leaves the app and comes back
/// refused — the same end, one round trip later and one step further from the
/// place that could explain it.
bool isJwtExpired(
  String token, {
  DateTime? now,
  Duration leeway = const Duration(seconds: 30),
}) {
  if (token.isEmpty) return false; // a guest has nothing to expire
  final expiry = jwtExpiry(token);
  if (expiry == null) return false;
  return (now ?? DateTime.now().toUtc()).add(leeway).isAfter(expiry);
}
