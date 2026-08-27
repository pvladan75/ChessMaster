import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/oauth_pkce.dart';

/// The desktop Google sign-in, minus the browser and the socket.
///
/// `google_sign_in` does not support Windows at all, so that build signs in
/// through the installed-app flow instead: the system browser, a loopback
/// redirect, and PKCE. None of that can be tested end to end here — it needs a
/// real Google client and a real browser window — but every part of it that is
/// string work can be, and those are the parts that fail silently. A wrong
/// challenge, a missing state check: both come back as "prijava nije uspela"
/// with nothing to go on.
void main() {
  group('PKCE', () {
    test('the challenge matches the worked example in RFC 7636', () {
      // Appendix B. If this fails, Google answers `invalid_grant` and nothing
      // in the app can tell you why.
      expect(
        pkceChallengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('the challenge carries no padding and no unsafe characters', () {
      final challenge = pkceChallengeFor('a' * 43);

      expect(challenge, isNot(contains('=')));
      expect(challenge, isNot(contains('+')));
      expect(challenge, isNot(contains('/')));
    });

    test('a verifier uses only the characters the spec allows', () {
      // It is compared byte for byte at the other end, so anything a browser or
      // a proxy might re-encode on the way is a bug waiting for a different
      // machine.
      final pair = createPkcePair();

      expect(pair.verifier.length, 64);
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(pair.verifier), isTrue);
      expect(pair.challenge, pkceChallengeFor(pair.verifier));
    });

    test('two verifiers in a row are not the same', () {
      expect(createPkcePair().verifier, isNot(createPkcePair().verifier));
    });

    test('a seeded generator is reproducible, which is how this is testable',
        () {
      expect(
        randomVerifier(length: 16, random: Random(7)),
        randomVerifier(length: 16, random: Random(7)),
      );
    });
  });

  group('the URL the browser is sent to', () {
    final url = googleAuthUrl(
      clientId: 'client-123',
      redirectUri: 'http://localhost:5511',
      challenge: 'CHALLENGE',
      state: 'STATE',
    );

    test('asks Google for a code, with the digest rather than the secret', () {
      expect(url.host, 'accounts.google.com');
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['code_challenge'], 'CHALLENGE');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['redirect_uri'], 'http://localhost:5511');
    });

    test('asks for no more than who this is', () {
      // A scope asked for once is a scope shown on the consent screen to every
      // parent who ever signs a child in.
      expect(url.queryParameters['scope'], 'openid email profile');
    });

    test('makes Google ask which account, rather than reusing the last one',
        () {
      // On a shared computer the last account is somebody else's child.
      expect(url.queryParameters['prompt'], 'select_account');
    });

    test('the address hint is offered only when there is one', () {
      expect(url.queryParameters.containsKey('login_hint'), isFalse);
      final hinted = googleAuthUrl(
        clientId: 'c',
        redirectUri: 'r',
        challenge: 'c',
        state: 's',
        loginHint: 'trener@example.com',
      );
      expect(hinted.queryParameters['login_hint'], 'trener@example.com');
    });
  });

  group('what comes back', () {
    Uri redirect(Map<String, String> params) =>
        Uri.http('localhost:5511', '/', params);

    test('a matching answer yields the code', () {
      expect(
        authCodeFromRedirect(
          redirect({'code': 'abc', 'state': 'STATE'}),
          expectedState: 'STATE',
        ),
        'abc',
      );
    });

    test('an answer from a different attempt is refused', () {
      // Without this check any page in any browser on this machine could hit
      // the loopback port with a code of its own and have the app redeem it —
      // signing the user into an account they do not own.
      expect(
        () => authCodeFromRedirect(
          redirect({'code': 'abc', 'state': 'OTHER'}),
          expectedState: 'STATE',
        ),
        throwsA(isA<OAuthRedirectException>()),
      );
      expect(
        () => authCodeFromRedirect(
          redirect({'code': 'abc'}),
          expectedState: 'STATE',
        ),
        throwsA(isA<OAuthRedirectException>()),
      );
    });

    test('a refusal is reported as a refusal, not as a failure', () {
      expect(
        () => authCodeFromRedirect(
          redirect({'error': 'access_denied', 'state': 'STATE'}),
          expectedState: 'STATE',
        ),
        throwsA(isA<OAuthRedirectException>()
            .having((e) => e.message, 'message', contains('otkazana'))),
      );
    });

    test('an answer with no code at all is not silently accepted', () {
      expect(
        () => authCodeFromRedirect(
          redirect({'state': 'STATE'}),
          expectedState: 'STATE',
        ),
        throwsA(isA<OAuthRedirectException>()),
      );
    });
  });

  test('the page left in the browser fetches nothing', () {
    // It is served from a socket that is closed a moment later, so anything it
    // tried to load would fail in front of the user.
    expect(oauthDonePage, isNot(contains('http')));
    expect(oauthDonePage, contains('Prijava je gotova'));
  });
}
