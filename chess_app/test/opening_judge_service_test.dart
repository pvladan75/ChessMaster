import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';

/// The request, and what comes back.
///
/// Until 15.9.2026 this file was mostly about a gate: judging carried the
/// reader's own Lichess token, and a reader without one reached nothing. The
/// book is on the server now and the evaluation anonymous
/// (`docs/PLAN-OTVARANJA-LOKALNO.md`), so the only condition left is being
/// signed in — and the test that matters is that no token rides along.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const verdictBody = {
    'fen': 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
    'fenAfter':
        'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR b KQkq - 1 2',
    'uci': 'f1c4',
    'san': 'Bc4',
    'moverIsWhite': true,
    'verdict': 'mistake',
    'masters': {'games': 2, 'total': 900, 'beyondBook': true},
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

  test('a reader with no Lichess token is judged like anybody else', () async {
    await signedIn(lichessToken: '');
    late http.Request seen;
    final service = OpeningJudgeService.withClient(MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode(verdictBody), 200);
    }));

    final lookup = await service.judge('start fen', 'Bc4');

    expect(lookup.isAvailable, isTrue);
    expect(seen.headers['Authorization'], 'Bearer jwt');
    expect(seen.url.queryParameters['move'], 'Bc4');
  });

  test('a token saved in Settings does not ride along', () async {
    // It is still kept, for importing one's own games from lichess.org. Sent
    // here it would be a secret travelling to a route that reads nothing.
    await signedIn(lichessToken: 'lip_secret');
    final seen = <http.Request>[];
    final service = OpeningJudgeService.withClient(MockClient((req) async {
      seen.add(req);
      return http.Response(
          jsonEncode(req.url.path.endsWith('/replies')
              ? {'total': 0, 'replies': [], 'all': []}
              : verdictBody),
          200);
    }));

    await service.judge('start fen', 'Bc4');
    await service.replies('start fen');

    expect(seen, hasLength(2));
    for (final req in seen) {
      expect(req.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-lichess-token')));
      expect(req.url.toString(), isNot(contains('lip_secret')));
    }
  });

  test('a guest asks nothing', () async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    await SessionService.instance.signOut();
    var called = false;
    final service = OpeningJudgeService.withClient(MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    }));

    expect((await service.judge('fen', 'Nf3')).reason, 'guest');
    expect((await service.replies('fen')).reason, 'guest');
    expect(called, isFalse);
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
    expect(j.mastersBeyondBook, isTrue);

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
      'eval': null,
    });

    expect(j.verdict, OpeningVerdict.unknown);
    expect(j.lossCp, isNull);
    expect(j.punishment, isEmpty);
  });
}
