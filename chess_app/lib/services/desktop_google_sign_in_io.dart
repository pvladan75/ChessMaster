import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'oauth_pkce.dart';

/// Signs in with Google on Windows and Linux, where the plugin cannot.
///
/// The installed-app flow from RFC 8252: open the user's own browser, listen on
/// a loopback port for the redirect, and redeem the code with PKCE. The browser
/// is the point — the password is typed into Google's page in the user's own
/// browser, with their own saved sessions, and this app never sees it.
///
/// macOS is deliberately **not** here even though it is a desktop: the plugin
/// supports it properly, and two ways in mean two things to keep working.
class DesktopGoogleSignIn {
  const DesktopGoogleSignIn();

  /// Platforms that need this path at all.
  static bool get isSupported => Platform.isWindows || Platform.isLinux;

  /// Whether this build was given a desktop OAuth client to use.
  ///
  /// It comes from `--dart-define`, not from the source: the repository is
  /// public. A build without it hides the button rather than offering one that
  /// cannot work — which is the state the Windows build was in.
  static bool get isConfigured => googleDesktopClientId.isNotEmpty;

  /// How long the user has to finish in the browser before the local server is
  /// taken down. Generous: this includes finding the window, picking an
  /// account, and possibly typing a password from a manager.
  static const Duration _timeout = Duration(minutes: 5);

  /// Returns a Google ID token, or throws with a message meant for a person.
  ///
  /// Only the token comes back. Identity is read from it on the server, which
  /// verifies the signature and the audience — an email address sent alongside
  /// would be a second, unverified answer to the same question, and that is the
  /// bug `/auth/google` was fixed for once already.
  Future<String> obtainIdToken({String? loginHint}) async {
    if (!isConfigured) {
      throw const OAuthRedirectException(
        'Google prijava nije podešena za ovu verziju aplikacije.',
      );
    }

    // Port 0: the operating system picks a free one. A fixed port is a port
    // that is sometimes taken, and the failure would look like Google's.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://localhost:${server.port}';

    final pkce = createPkcePair();
    final state = randomVerifier(length: 32);

    try {
      final authUrl = googleAuthUrl(
        clientId: googleDesktopClientId,
        redirectUri: redirectUri,
        challenge: pkce.challenge,
        state: state,
        loginHint: loginHint,
      );

      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw const OAuthRedirectException(
          'Ne mogu da otvorim pretraživač za Google prijavu.',
        );
      }

      final code = await _awaitRedirect(server, expectedState: state);
      return await _redeem(code,
          redirectUri: redirectUri, verifier: pkce.verifier);
    } finally {
      // Always, including when the user closed the browser and nothing ever
      // arrived: a listening socket left behind outlives the attempt and the
      // next one would bind a different port while this one still answers.
      await server.close(force: true);
    }
  }

  /// Waits for the browser to come back, and answers it with a page.
  ///
  /// The page is written before the code is redeemed, not after: redeeming
  /// takes a round trip to Google, and a browser left hanging on a blank tab
  /// for that long looks like the sign-in failed.
  Future<String> _awaitRedirect(
    HttpServer server, {
    required String expectedState,
  }) async {
    final completer = Completer<String>();

    final subscription = server.listen((request) async {
      // Browsers ask for this on their own, and answering the favicon request
      // as though it were the redirect would fail the state check.
      if (request.uri.path == '/favicon.ico') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(oauthDonePage);
      await request.response.close();

      if (completer.isCompleted) return;
      try {
        completer.complete(
          authCodeFromRedirect(request.uri, expectedState: expectedState),
        );
      } on OAuthRedirectException catch (e) {
        completer.completeError(e);
      }
    }, onError: (Object e) {
      if (!completer.isCompleted) {
        completer.completeError(
          OAuthRedirectException('Greška lokalnog servera za prijavu: $e'),
        );
      }
    });

    try {
      return await completer.future.timeout(
        _timeout,
        onTimeout: () => throw const OAuthRedirectException(
          'Prijava preko Google-a je istekla. Pokušajte ponovo.',
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  /// Trades the code for tokens.
  ///
  /// `client_secret` is sent when the build has one, because Google's desktop
  /// clients still expect it. It is not a secret in any real sense — it ships
  /// inside every copy of the app, which is exactly why PKCE is what actually
  /// protects this exchange, and why it must not be committed to a public
  /// repository either.
  Future<String> _redeem(
    String code, {
    required String redirectUri,
    required String verifier,
  }) async {
    final response = await http.post(
      Uri.https('oauth2.googleapis.com', '/token'),
      body: {
        'code': code,
        'client_id': googleDesktopClientId,
        if (googleDesktopClientSecret.isNotEmpty)
          'client_secret': googleDesktopClientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      },
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      // The body carries Google's own reason — a wrong client type, a redirect
      // URI that is not registered — and logging it is the difference between
      // fixing the console setup in a minute and guessing for an hour. It is
      // not shown to the user, who can do nothing with it.
      AppLogger.log('[Google/desktop] Razmena kôda nije uspela: '
          '${response.statusCode} ${response.body}');
      throw const OAuthRedirectException(
        'Google nije prihvatio prijavu sa ovog uređaja.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final idToken = data['id_token']?.toString() ?? '';
    if (idToken.isEmpty) {
      throw const OAuthRedirectException(
        'Google nije vratio identitet (id_token).',
      );
    }
    return idToken;
  }
}
