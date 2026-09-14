/// The words of a tutorial made from a game, asked of the server — phase 4 of
/// `docs/PLAN-SKELET.md`.
///
/// `POST /lessons/from-game/words` takes the request `wordsRequestOf` builds
/// and answers with the model's words once they are the shape asked for. The
/// app then assembles both tutorials and judges the words against the facts.
///
/// **Every refusal is a reason and a sentence, never an exception.** A trainer
/// has pressed one button and waited for the engine; what they need back is
/// what happened and what they can do about it — upgrade, try again, wait for
/// the tutorial already being written — and a credit that was not spent must be
/// said to be unspent.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

/// Why no words came back, and what to tell the trainer.
class WordsRefusal {
  const WordsRefusal(this.reason, this.message);

  /// `signed-out`, `upgrade-required`, `quota-spent`, `bad-request`,
  /// `bad-answer`, `already-writing`, `not-configured`, `timeout`, `network`,
  /// or the provider's own reason from a 503.
  final String reason;
  final String message;

  bool get upgradeRequired => reason == 'upgrade-required';

  @override
  String toString() => '$reason: $message';
}

/// The words, or why there are none.
class WordsOutcome {
  const WordsOutcome.written(this.answerText,
      {this.attempts = 1, this.tokens = 0})
      : refusal = null;
  const WordsOutcome.refused(WordsRefusal this.refusal)
      : answerText = null,
        attempts = 0,
        tokens = 0;

  /// The model's answer as JSON text — what `assembleSkeleton` reads.
  final String? answerText;
  final WordsRefusal? refusal;
  final int attempts;
  final int tokens;
}

/// The server's JSON body, or an empty map when it sent none.
Map<String, dynamic> _body(http.Response res) {
  try {
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : const {};
  } catch (_) {
    return const {};
  }
}

Future<WordsOutcome> requestTutorialWords(
  Map<String, dynamic> request, {
  required String token,
  http.Client? client,
  String? baseUrl,
  Duration timeout = const Duration(seconds: 120),
}) async {
  if (token.isEmpty) {
    return const WordsOutcome.refused(
        WordsRefusal('signed-out', 'Sign in to make a tutorial from a game.'));
  }
  final http.Client c = client ?? http.Client();
  try {
    final res = await c
        .post(
          Uri.parse('${baseUrl ?? backendUrl}/lessons/from-game/words'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(request),
        )
        .timeout(timeout);
    final body = _body(res);
    final said = body['error'] as String?;

    switch (res.statusCode) {
      case 200:
        final answer = body['answer'];
        if (answer is! Map) {
          return const WordsOutcome.refused(WordsRefusal('bad-answer',
              'The server sent no words. Nothing was charged. Try again.'));
        }
        final tokens = body['tokens'];
        return WordsOutcome.written(
          jsonEncode(answer),
          attempts: (body['attempts'] as num?)?.toInt() ?? 1,
          tokens: tokens is Map ? (tokens['total'] as num?)?.toInt() ?? 0 : 0,
        );
      case 401:
        return const WordsOutcome.refused(WordsRefusal('signed-out',
            'Your sign-in has expired. Sign in again to make a tutorial.'));
      case 403:
        if (body['quotaExceeded'] == true) {
          return WordsOutcome.refused(WordsRefusal(
              'quota-spent',
              said ??
                  'You have made all the tutorials your plan includes this month.'));
        }
        return const WordsOutcome.refused(WordsRefusal('upgrade-required',
            'Making a tutorial from a game is part of a Premium account.'));
      case 400:
        return WordsOutcome.refused(WordsRefusal(
            'bad-request', said ?? 'The server could not read this game.'));
      case 422:
        return const WordsOutcome.refused(WordsRefusal(
            'bad-answer',
            'The words could not be written this time. It did not count '
                'against your allowance — try again.'));
      case 429:
        return WordsOutcome.refused(WordsRefusal(
            'already-writing',
            said ??
                'Another tutorial is still being written. Wait for it to finish.'));
      case 503:
        return WordsOutcome.refused(WordsRefusal(
            (body['reason'] as String?) ?? 'unavailable',
            said ?? 'Writing tutorials is not available right now.'));
      default:
        return WordsOutcome.refused(WordsRefusal('http-${res.statusCode}',
            said ?? 'The server answered ${res.statusCode}.'));
    }
  } on TimeoutException {
    return const WordsOutcome.refused(WordsRefusal('timeout',
        'The server did not answer in two minutes. Nothing was charged.'));
  } on SocketException catch (e) {
    AppLogger.log('[TutorialWords] ❌ Server nedostupan: $e');
    return const WordsOutcome.refused(
        WordsRefusal('network', 'The server could not be reached.'));
  } on http.ClientException catch (e) {
    AppLogger.log('[TutorialWords] ❌ Server nedostupan: $e');
    return const WordsOutcome.refused(
        WordsRefusal('network', 'The server could not be reached.'));
  } finally {
    if (client == null) c.close();
  }
}
