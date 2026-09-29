/// A tutorial made from a game, translated whole before it opens —
/// `docs/PLAN-JEZIK-STUDIJE.md`, §8.
///
/// `POST /lessons/from-game/translate` takes the tutorial the trainer picked,
/// unsaved, and answers it with every sentence in the language asked for —
/// the model's and the ones the app wrote itself — its moves, arrows and
/// squares proved untouched. It spends no unit: the tutorial was the unit,
/// spent on its words.
///
/// The words client's shape (`words_client.dart`): **every refusal is a reason
/// and a sentence, never an exception**.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart'
    show WordsRefusal;
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/services/app_logger.dart';

/// How long the app waits: the server asks at most twice, 100 s a request,
/// under a proxy that waits 300. Phase 5 measured 17 to 59 s for one.
const Duration kTutorialTranslateTimeout = Duration(seconds: 230);

/// [tutorial] in [language], or why not.
typedef TutorialTranslation = ({
  ImportedTutorial? tutorial,
  WordsRefusal? refusal,
});

/// How a translation is asked for — the seam a test replaces.
typedef TutorialTranslator = Future<TutorialTranslation> Function(
    ImportedTutorial tutorial, String language);

Map<String, dynamic> _body(http.Response res) {
  try {
    final data = jsonDecode(res.body);
    return data is Map<String, dynamic> ? data : const {};
  } catch (_) {
    return const {};
  }
}

/// Asks the server for [tutorial] in [language].
Future<TutorialTranslation> translateGameTutorial(
  ImportedTutorial tutorial,
  String language, {
  required String token,
  http.Client? client,
  String? baseUrl,
  Duration timeout = kTutorialTranslateTimeout,
}) async {
  TutorialTranslation refused(String reason, String message) =>
      (tutorial: null, refusal: WordsRefusal(reason, message));
  if (token.isEmpty) {
    return refused('signed-out', 'Sign in to have the tutorial translated.');
  }
  final http.Client c = client ?? http.Client();
  try {
    final res = await c
        .post(
          Uri.parse('${baseUrl ?? backendUrl}/lessons/from-game/translate'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'language': language,
            'tutorial': {
              'title': tutorial.title,
              'description': tutorial.description,
              'steps': tutorial.positionList,
            },
          }),
        )
        .timeout(timeout);
    final body = _body(res);
    final said = body['error'] as String?;
    switch (res.statusCode) {
      case 200:
        final t = body['tutorial'];
        final steps = t is Map ? t['steps'] : null;
        if (t is! Map ||
            steps is! List ||
            steps.length != tutorial.positionList.length ||
            t['language'] != language) {
          return refused('bad-answer', 'The server sent no translation.');
        }
        return (
          tutorial: ImportedTutorial(
            title: (t['title'] as String?) ?? tutorial.title,
            description: t['description'] as String?,
            tags: tutorial.tags,
            positionList: [
              for (final s in steps) Map<String, dynamic>.from(s as Map),
            ],
            problems: tutorial.problems,
            language: language,
            fileName: tutorial.fileName,
          ),
          refusal: null,
        );
      case 401:
        return refused(
            'signed-out', 'Your sign-in has expired. Sign in again.');
      case 403:
        return refused('upgrade-required',
            'Translating a tutorial from a game is part of a Premium account.');
      case 400:
        return refused(
            'bad-request', said ?? 'The server could not read the tutorial.');
      case 422:
        return refused(
            'bad-translation',
            'The translation did not keep the moves as they were, twice, so '
                'it was not used.');
      case 429:
        return refused((body['reason'] as String?) ?? 'too-many',
            said ?? 'Another tutorial is being translated.');
      case 503:
        return refused((body['reason'] as String?) ?? 'unavailable',
            said ?? 'Translating is not available right now.');
      default:
        return refused('http-${res.statusCode}',
            said ?? 'The server answered ${res.statusCode}.');
    }
  } on TimeoutException {
    return refused('timeout', 'The server did not answer in four minutes.');
  } on SocketException catch (e) {
    AppLogger.log('[TutorialTranslate] ❌ Server nedostupan: $e');
    return refused('network', 'The server could not be reached.');
  } on http.ClientException catch (e) {
    AppLogger.log('[TutorialTranslate] ❌ Server nedostupan: $e');
    return refused('network', 'The server could not be reached.');
  } finally {
    if (client == null) c.close();
  }
}
