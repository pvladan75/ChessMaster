import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The parts of an OAuth 2.0 authorisation-code flow that are pure string
/// work: the PKCE pair, the URL the browser is sent to, and reading the answer
/// that comes back.
///
/// Kept apart from the socket and the browser so it can be tested at all — the
/// flow around it opens a local server and a real browser window, and neither
/// belongs in a test. It is also platform-neutral on purpose: `dart:io` lives
/// in the file that uses this one, so the web build never sees it.
///
/// PKCE (RFC 7636) is what makes this safe without a confidential secret. The
/// browser hands the authorisation code back over plain loopback HTTP, where
/// any other program on the machine could in principle catch it; the code is
/// worthless without the verifier, which never leaves this process.
class PkcePair {
  /// The secret this process keeps and sends only when redeeming the code.
  final String verifier;

  /// Its SHA-256 digest, which is what travels in the browser URL.
  final String challenge;

  const PkcePair({required this.verifier, required this.challenge});
}

/// Characters the spec allows in a verifier, and no others: it is compared
/// byte for byte at the other end, so anything that could be re-encoded on the
/// way is a bug waiting for a different browser.
const String _unreserved =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

/// A random string of [length] unreserved characters.
///
/// [random] is injectable so a test can pin the output; the default is
/// [Random.secure], and nothing here may fall back to the unseeded one — the
/// value is the only thing standing between an intercepted code and a session.
String randomVerifier({int length = 64, Random? random}) {
  final rng = random ?? Random.secure();
  return List.generate(
    length,
    (_) => _unreserved[rng.nextInt(_unreserved.length)],
  ).join();
}

/// base64url without padding, which is the only encoding the spec accepts.
String _b64Url(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// The challenge for a given verifier: base64url(SHA-256(verifier)), unpadded.
///
/// Its own function so it can be checked against the worked example in RFC 7636
/// Appendix B. Every part of this is a place to go wrong quietly — padding left
/// on, standard base64 instead of the URL alphabet, hashing the UTF-16 string
/// instead of its ASCII bytes — and each mistake fails the same way: Google
/// answers `invalid_grant` and the app says the sign-in did not work.
String pkceChallengeFor(String verifier) =>
    _b64Url(sha256.convert(ascii.encode(verifier)).bytes);

PkcePair createPkcePair({Random? random}) {
  final verifier = randomVerifier(random: random);
  return PkcePair(verifier: verifier, challenge: pkceChallengeFor(verifier));
}

/// Where the browser is sent to ask the user.
///
/// `openid email profile` and nothing else: the app needs to know who this is
/// and what to call them, and a scope asked for once is a scope the consent
/// screen shows to every parent who ever signs a child in.
Uri googleAuthUrl({
  required String clientId,
  required String redirectUri,
  required String challenge,
  required String state,
  String? loginHint,
}) {
  return Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': 'openid email profile',
    'code_challenge': challenge,
    'code_challenge_method': 'S256',
    'state': state,
    // Otherwise Google silently reuses whoever signed in last, which on a
    // shared computer is somebody else's child.
    'prompt': 'select_account',
    if (loginHint != null && loginHint.isNotEmpty) 'login_hint': loginHint,
  });
}

/// Raised when the browser comes back with something other than a usable code.
class OAuthRedirectException implements Exception {
  final String message;
  const OAuthRedirectException(this.message);

  @override
  String toString() => message;
}

/// The authorisation code out of the URL the browser was redirected to.
///
/// Throws rather than returning null, and says which of the three things went
/// wrong: the user declined, the answer belongs to a different attempt, or
/// there is no code in it at all. A silent null here would show up much later
/// as "Google prijava nije uspela" with nothing to go on.
///
/// The state check is not decoration. Without it, any page in any browser on
/// this machine could hit the loopback port with a code of its own choosing and
/// have this process redeem it — signing the user into an account they do not
/// own.
String authCodeFromRedirect(Uri requested, {required String expectedState}) {
  final params = requested.queryParameters;

  final error = params['error'];
  if (error != null && error.isNotEmpty) {
    if (error == 'access_denied') {
      throw const OAuthRedirectException('Prijava preko Google-a je otkazana.');
    }
    throw OAuthRedirectException('Google je odbio prijavu ($error).');
  }

  final state = params['state'];
  if (state == null || state != expectedState) {
    throw const OAuthRedirectException(
        'Odgovor ne pripada ovoj prijavi. Pokušajte ponovo.');
  }

  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw const OAuthRedirectException('Google nije vratio kôd za prijavu.');
  }
  return code;
}

/// The page the browser is left on. Plain, self-contained, and in the language
/// of whoever is reading it — they came from a Serbian app.
const String oauthDonePage = '<!doctype html>'
    '<html lang="sr"><head><meta charset="utf-8">'
    '<title>Prijava je gotova</title></head>'
    '<body style="font-family:system-ui,sans-serif;text-align:center;'
    'padding:48px 24px">'
    '<h2>Prijava je gotova.</h2>'
    '<p>Možete da zatvorite ovu karticu i vratite se u aplikaciju.</p>'
    '</body></html>';
