/// The words of a position study, asked of the server —
/// `docs/PLAN-STUDIJA-POZICIJE.md`, §3.
///
/// `POST /study-words` takes the request `studyWordsRequest` builds and
/// answers with the model's slots once they are the shape asked for; the app
/// then judges them (`judgeStudyWords`). `POST /study-words/comment` is the
/// same request with one item — one move, or one position — counted where a
/// single AI comment always was.
///
/// The review's client (`review_words_client.dart`) is the shape copied:
/// **every refusal is a reason and a sentence, never an exception**, and a
/// credit that was not spent is said to be unspent. The engine's work is never
/// lost to a refusal — the study's lines are written whatever this answers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;
import 'package:chess_app/services/app_logger.dart';

/// The slots the server kept (`m1.move` → text), or why there are none.
class StudyWordsOutcome {
  const StudyWordsOutcome.written(Map<String, String> this.slots)
      : refusal = null;
  const StudyWordsOutcome.refused(WordsRefusal this.refusal) : slots = null;

  final Map<String, String>? slots;
  final WordsRefusal? refusal;
}

/// How long the app waits for the words. The server asks the model twice at
/// the most, 100 s an attempt, under a proxy that waits 300; `deepseek-v4-pro`
/// took up to 62 s for one study in phase 0, so a second attempt is past the
/// two minutes this waited while the fast model wrote.
const Duration kStudyWordsTimeout = Duration(seconds: 230);

/// How the app asks for words — the seam a test or a headless tool replaces.
typedef StudyWordsAsker = Future<StudyWordsOutcome> Function(
  Map<String, dynamic> request, {
  required bool comment,
});

Map<String, dynamic> _body(http.Response res) {
  try {
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : const {};
  } catch (_) {
    return const {};
  }
}

/// Asks the server for the words of [request]: a whole study, or with
/// [comment] one move or one position.
Future<StudyWordsOutcome> requestStudyWords(
  Map<String, dynamic> request, {
  required String token,
  bool comment = false,
  http.Client? client,
  String? baseUrl,
  Duration timeout = kStudyWordsTimeout,
}) async {
  if (token.isEmpty) {
    return const StudyWordsOutcome.refused(
        WordsRefusal('signed-out', 'Sign in to have comments written.'));
  }
  final http.Client c = client ?? http.Client();
  final path = comment ? '/study-words/comment' : '/study-words';
  try {
    final res = await c
        .post(
          Uri.parse('${baseUrl ?? backendUrl}$path'),
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
          return const StudyWordsOutcome.refused(WordsRefusal('bad-answer',
              'The server sent no comments. Nothing was charged.'));
        }
        return StudyWordsOutcome.written({
          for (final e in slots.entries)
            if (e.value is String) e.key.toString(): e.value as String,
        });
      case 401:
        return const StudyWordsOutcome.refused(WordsRefusal(
            'signed-out', 'Your sign-in has expired. Sign in again.'));
      case 403:
        if (body['quotaExceeded'] == true) {
          return StudyWordsOutcome.refused(WordsRefusal(
              'quota-spent',
              said ??
                  'You have used all the AI comments your plan includes this month.'));
        }
        return const StudyWordsOutcome.refused(WordsRefusal('upgrade-required',
            'AI comments for a position study are part of a Premium account.'));
      case 400:
        return StudyWordsOutcome.refused(WordsRefusal(
            'bad-request', said ?? 'The server could not read this position.'));
      case 422:
        return const StudyWordsOutcome.refused(WordsRefusal(
            'bad-answer',
            'The model did not answer in the shape asked for. It did not '
                'count against your allowance.'));
      case 429:
        return StudyWordsOutcome.refused(WordsRefusal(
            (body['reason'] as String?) ?? 'too-many',
            said ?? 'Comments for another position are still being written.'));
      case 503:
        return StudyWordsOutcome.refused(WordsRefusal(
            (body['reason'] as String?) ?? 'unavailable',
            said ?? 'Writing comments is not available right now.'));
      default:
        return StudyWordsOutcome.refused(WordsRefusal('http-${res.statusCode}',
            said ?? 'The server answered ${res.statusCode}.'));
    }
  } on TimeoutException {
    return const StudyWordsOutcome.refused(WordsRefusal('timeout',
        'The server did not answer in four minutes. Nothing was charged.'));
  } on SocketException catch (e) {
    AppLogger.log('[StudyWords] ❌ Server nedostupan: $e');
    return const StudyWordsOutcome.refused(
        WordsRefusal('network', 'The server could not be reached.'));
  } on http.ClientException catch (e) {
    AppLogger.log('[StudyWords] ❌ Server nedostupan: $e');
    return const StudyWordsOutcome.refused(
        WordsRefusal('network', 'The server could not be reached.'));
  } finally {
    if (client == null) c.close();
  }
}
