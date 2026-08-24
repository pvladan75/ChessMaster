import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';

/// The gate, the request, and what comes back.
///
/// The gate is the part worth a test of its own. Judging one move costs up to
/// four questions of somebody's Lichess allowance, and the server's own token
/// is a single allowance shared by every child in the app — so a user without a
/// token of their own must not reach the route at all, rather than reaching it
/// and being refused. The difference is invisible on screen and is exactly the
/// thing that would quietly empty the shared quota.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const verdictBody = {
    'fen': 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    'fenAfter':
        'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2',
    'uci': 'f1c4',
    'san': 'Bc4',
    'moverIsWhite': true,
    'minRating': 1600,
    'verdict': 'mistake',
    'masters': {'games': 2, 'total': 900},
    'band': {'games': 40, 'total': 800},
    'eval': {
      'beforeCp': 20,
      'afterCp': -400,
      'lossCp': 420,
      'mateBefore': null,
      'mateAfter': null,
      'depth': 40,
      'better': 'Nf3',
      'punishment': ['Qh4', 'Nf3', 'Qxe4+'],
    },
  };

  Future<void> signedIn({required String lichessToken}) async {
    SharedPreferences.setMockInitialValues({
      'lichess_api_token': lichessToken,
    });
    await AppSettingsService.instance.init();
    await SessionService.instance.signIn(
      UserSession(
          token: 'jwt', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
      rememberMe: false,
    );
  }

  test('without a personal token nothing is sent at all', () async {
    await signedIn(lichessToken: '');
    var called = false;
    final service = OpeningJudgeService.withClient(MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    }));

    final lookup = await service.judge('fen', 'Nf3');

    expect(lookup.isAvailable, isFalse);
    expect(lookup.reason, 'no-token');
    expect(called, isFalse, reason: 'bez svog tokena se ne šalje ništa');
  });

  test('the token travels in a header, never in the address', () async {
    await signedIn(lichessToken: 'lip_secret');
    late http.Request seen;
    final service = OpeningJudgeService.withClient(MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode(verdictBody), 200);
    }));

    await service.judge('start fen', 'Bc4', minRating: 1600);

    expect(seen.headers['X-Lichess-Token'], 'lip_secret');
    expect(seen.headers['Authorization'], 'Bearer jwt');
    // A URL is the one part of a request that everything it passes through
    // writes down.
    expect(seen.url.toString(), isNot(contains('lip_secret')));
    expect(seen.url.queryParameters['move'], 'Bc4');
    expect(seen.url.queryParameters['minRating'], '1600');
  });

  test('a verdict is read whole, and asked for only once', () async {
    await signedIn(lichessToken: 'lip_secret');
    var calls = 0;
    final service = OpeningJudgeService.withClient(MockClient((_) async {
      calls += 1;
      return http.Response(jsonEncode(verdictBody), 200);
    }));

    final lookup = await service.judge('start fen', 'Bc4', minRating: 1600);
    final j = lookup.judgement!;

    expect(j.verdict, OpeningVerdict.mistake);
    expect(j.san, 'Bc4');
    expect(j.lossCp, 420);
    expect(j.better, 'Nf3');
    expect(j.punishment, ['Qh4', 'Nf3', 'Qxe4+']);
    expect(j.bandGames, 40);

    await service.judge('start fen', 'Bc4', minRating: 1600);
    expect(calls, 1, reason: 'isti potez se ne plaća dvaput');
  });

  test('the server\'s reason survives the trip, and a failure is not cached',
      () async {
    await signedIn(lichessToken: 'lip_secret');
    var calls = 0;
    final service = OpeningJudgeService.withClient(MockClient((_) async {
      calls += 1;
      return http.Response(
          jsonEncode({'error': 'nema', 'reason': 'rate-limited'}), 503);
    }));

    final lookup = await service.judge('start fen', 'Bc4');

    expect(lookup.isAvailable, isFalse);
    expect(lookup.reason, 'rate-limited',
        reason: 'potrošena kvota i loš potez nisu ista poruka');

    await service.judge('start fen', 'Bc4');
    expect(calls, 2,
        reason: 'jedan loš minut ne sme da zatvori panel do kraja');
  });

  test('an unknown verdict is read as unknown, not as a mistake', () {
    final j = OpeningJudgement.fromJson(const {
      'verdict': 'unknown',
      'reason': 'no-eval',
      'san': 'Bc4',
      'masters': {'games': 0, 'total': 0},
      'band': {'games': 0, 'total': 0},
      'eval': null,
    });

    expect(j.verdict, OpeningVerdict.unknown);
    expect(j.lossCp, isNull);
    expect(j.punishment, isEmpty);
  });
}
