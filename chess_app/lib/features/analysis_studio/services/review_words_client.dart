/// The words of a whole-game review, asked of the server —
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 3.
///
/// `POST /review-words` takes the request `reviewWordsRequest` builds and
/// answers with the model's slots once they are the shape asked for; the app
/// then judges them (`judgeReviewWords`). The tutorial's client
/// (`words_client.dart`) is the shape copied: **every refusal is a reason and
/// a sentence, never an exception**, and a credit that was not spent is said
/// to be unspent. The review's engine work is never lost to a refusal — the
/// runner lands it whatever this answers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;
import 'package:chess_app/services/app_logger.dart';

/// The slots the server kept (`m1.played` → text), or why there are none.
class ReviewWordsOutcome {
  const ReviewWordsOutcome.written(Map<String, String> this.slots)
      : refusal = null;
  const ReviewWordsOutcome.refused(WordsRefusal this.refusal) : slots = null;

  final Map<String, String>? slots;
  final WordsRefusal? refusal;
}

Map<String, dynamic> _body(http.Response res) {
  try {
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : const {};
  } catch (_) {
    return const {};
  }
}

Future<ReviewWordsOutcome> requestReviewWords(
  Map<String, dynamic> request, {
  required String token,
  http.Client? client,
  String? baseUrl,
  Duration timeout = const Duration(seconds: 120),
}) async {
  if (token.isEmpty) {
    return const ReviewWordsOutcome.refused(
        WordsRefusal('signed-out', 'Sign in to have comments written.'));
  }
  final http.Client c = client ?? http.Client();
  try {
    final res = await c
        .post(
          Uri.parse('${baseUrl ?? backendUrl}/review-words'),
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
        final slots = body['slots'];
        if (slots is! Map) {
          return const ReviewWordsOutcome.refused(WordsRefusal('bad-answer',
              'The server sent no comments. Nothing was charged.'));
        }
        return ReviewWordsOutcome.written({
          for (final e in slots.entries)
            if (e.value is String) e.key.toString(): e.value as String,
        });
      case 401:
        return const ReviewWordsOutcome.refused(WordsRefusal(
            'signed-out', 'Your sign-in has expired. Sign in again.'));
      case 403:
        if (body['quotaExceeded'] == true) {
          return ReviewWordsOutcome.refused(WordsRefusal(
              'quota-spent',
              said ??
                  'You have used all the AI comments your plan includes this month.'));
        }
        return const ReviewWordsOutcome.refused(WordsRefusal('upgrade-required',
            'AI comments for a review are part of a Premium account.'));
      case 400:
        return ReviewWordsOutcome.refused(WordsRefusal(
            'bad-request', said ?? 'The server could not read this review.'));
      case 422:
        return const ReviewWordsOutcome.refused(WordsRefusal(
            'bad-answer',
            'The model did not answer in the shape asked for. It did not '
                'count against your allowance.'));
      case 429:
        return ReviewWordsOutcome.refused(WordsRefusal('already-writing',
            said ?? 'Comments for another review are still being written.'));
      case 503:
        return ReviewWordsOutcome.refused(WordsRefusal(
            (body['reason'] as String?) ?? 'unavailable',
            said ?? 'Writing comments is not available right now.'));
      default:
        return ReviewWordsOutcome.refused(WordsRefusal('http-${res.statusCode}',
            said ?? 'The server answered ${res.statusCode}.'));
    }
  } on TimeoutException {
    return const ReviewWordsOutcome.refused(WordsRefusal('timeout',
        'The server did not answer in two minutes. Nothing was charged.'));
  } on SocketException catch (e) {
    AppLogger.log('[ReviewWords] ❌ Server nedostupan: $e');
    return const ReviewWordsOutcome.refused(
        WordsRefusal('network', 'The server could not be reached.'));
  } on http.ClientException catch (e) {
    AppLogger.log('[ReviewWords] ❌ Server nedostupan: $e');
    return const ReviewWordsOutcome.refused(
        WordsRefusal('network', 'The server could not be reached.'));
  } finally {
    if (client == null) c.close();
  }
}
