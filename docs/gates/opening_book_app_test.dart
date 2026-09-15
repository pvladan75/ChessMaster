// The gate for phase 4 of docs/PLAN-OTVARANJA-LOKALNO.md: the app after the
// opening book became a file on our own server.
//
// Copied to chess_app/test/opening_book_app_test.dart by the batch, and not
// edited there except by `dart format`.
//
// ## The contract, which the server froze at 1dd66c7
//
// GET /opening-explorer?fen=…&moves=12 answers, for a signed-in user,
//
//     { fen, white, draws, black, opening: null,
//       moves: [{ uci, san, white, draws, black }], unlisted, beyondBook }
//
// and refuses with { error, reason } — 400 for a FEN that is not a position,
// 503 with reason `not-configured`, `unreadable` or `inconsistent` when the
// server has no usable book. A `minRating` is not read by any route on the
// server. GET /opening-judge?fen&move and /opening-judge/replies?fen take
// nothing else either, and neither does POST /repertoire/spine beyond
// { color, rootFen, depth, minGames }.
//
// ## What the app must become
//
// 1. **ChessDB is gone** — `chessdb_service.dart`, the panel's ChessDB branch,
//    the screen's fallback to it, `openingDbSource` and the Settings switch.
// 2. **No personal Lichess token anywhere.** The explorer's direct path to
//    explorer.lichess.ovh is deleted, and so is the Settings field: once that
//    path is gone nothing in the app sends the token, and a field that does
//    nothing, holding a secret, is worse than no field. The stored value is
//    removed from SharedPreferences once, when the settings load.
// 3. **No rating anywhere the book is concerned.** The explorer panel's
//    dropdown, the repertoire list's "Opponent rating" menu,
//    `repertoireMinRating`, and every `minRating` parameter and wire key in the
//    repertoire, the judge, the explorer and the leak report. **Puzzle
//    assignments keep theirs** — a puzzle's rating is not the book's, and the
//    last test here says so.
// 4. **The explorer panel says what happened**, one sentence per state:
//      guest                     → „Sign in to see the opening book."
//      not-configured, unreadable,
//      inconsistent              → „The opening book is not available on this server."
//      any other refusal         → „The opening book could not be reached."
//      beyondBook                → „This position is deeper than the opening book goes."
//      no game reached it        → „No master game reached this position."
//    Its header is the opening name the screen already computes from the ECO
//    data (`displayOpeningName`), passed in as `openingName`, or „Opening book"
//    when there is none. A move's share is of the position's total, which the
//    server counts including the games in moves it does not list.
// 5. **Comments stop saying the book costs a Lichess request.** Nothing in the
//    repertoire does any more.
//
// The shapes this file compiles against:
//
//   OpeningExplorerService.withClient(http.Client)          // @visibleForTesting
//   OpeningExplorerService.lookup(String fen, {int movesLimit = 12})
//   OpeningExplorerResult.unlisted (int), .beyondBook (bool)
//   OpeningExplorerPanelWidget({required bool isLoading,
//       required OpeningExplorerResult? result, String? reason,
//       String? openingName, void Function(String uci)? onMoveSelected})
//   OpeningJudgeService.judge(String fen, String move)
//   OpeningJudgeService.replies(String fen)
//   RepertoireApiService.buildSpine({required String color,
//       required String rootFen, int depth = 8, int? minGames})

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';

import 'support/dart_source.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

const _guest = 'Sign in to see the opening book.';
const _noBook = 'The opening book is not available on this server.';
const _unreachable = 'The opening book could not be reached.';
const _deeper = 'This position is deeper than the opening book goes.';
const _nobody = 'No master game reached this position.';

/// A book answer for 1.e4: 1000 games reached it, the three moves listed hold
/// 900, and 100 are in moves played once that the server no longer lists.
Map<String, dynamic> _e4Answer({bool beyondBook = false, int total = 1000}) => {
  'fen': _afterE4,
  'white': total == 0 ? 0 : 400,
  'draws': total == 0 ? 0 : 300,
  'black': total == 0 ? 0 : 300,
  'opening': null,
  'moves': total == 0
      ? const []
      : const [
          {'uci': 'c7c5', 'san': 'c5', 'white': 100, 'draws': 50, 'black': 150},
          {
            'uci': 'e7e5',
            'san': 'e5',
            'white': 250,
            'draws': 200,
            'black': 150,
          },
          {'uci': 'e7e6', 'san': 'e6', 'white': 20, 'draws': 10, 'black': 30},
        ],
  'unlisted': total == 0 ? 0 : 100,
  'beyondBook': beyondBook,
};

Future<void> _signIn({String lichessToken = 'lip_still_stored'}) async {
  SharedPreferences.setMockInitialValues({'lichess_api_token': lichessToken});
  await AppSettingsService.instance.init();
  await SessionService.instance.signIn(
    UserSession(
      token: 'jwt',
      id: 1,
      email: 'a@b',
      name: 'Test',
      role: 'korisnik',
    ),
    rememberMe: false,
  );
}

String _read(String path) => File(path).readAsStringSync();

/// Every Dart file under [dir], relative to chess_app.
List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// The text of the call to [callee] in [code], by matching parentheses — never
/// by slicing a number of characters, which runs into the next call.
String _callTo(String code, String callee) {
  final at = code.indexOf('$callee(');
  if (at < 0) return '';
  var depth = 0;
  for (var i = at + callee.length; i < code.length; i++) {
    if (code[i] == '(') depth++;
    if (code[i] == ')') {
      depth--;
      if (depth == 0) return code.substring(at, i + 1);
    }
  }
  return code.substring(at);
}

Future<void> _pumpPanel(
  WidgetTester tester,
  OpeningExplorerPanelWidget panel, {
  Size size = const Size(500, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: panel)),
    ),
  );
  // One frame: the loading state draws a spinner, which never settles.
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the explorer service', () {
    test('asks our server for a position and nothing else', () async {
      await _signIn();
      final seen = <http.Request>[];
      final service = OpeningExplorerService.withClient(
        MockClient((req) async {
          seen.add(req);
          return http.Response(jsonEncode(_e4Answer()), 200);
        }),
      );

      final lookup = await service.lookup(_afterE4);

      expect(lookup.isAvailable, isTrue);
      expect(seen, hasLength(1));
      final req = seen.single;
      expect(req.url.toString(), startsWith('$backendUrl/opening-explorer?'));
      expect(
        req.url.queryParameters.keys.toSet(),
        {'fen', 'moves'},
        reason: 'no rating is sent: there is one book',
      );
      expect(req.url.queryParameters['fen'], _afterE4);
      expect(req.headers['Authorization'], 'Bearer jwt');
      // A token still sitting in the settings of a device that had one must
      // not ride along, and must not send the app to Lichess on its own.
      expect(
        req.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-lichess-token')),
      );
      expect(req.url.toString(), isNot(contains('lip_still_stored')));
    });

    test(
      'reads what the server counted, including the games it does not list',
      () async {
        await _signIn();
        final service = OpeningExplorerService.withClient(
          MockClient((_) async => http.Response(jsonEncode(_e4Answer()), 200)),
        );

        final result = (await service.lookup(_afterE4)).result!;

        expect(result.total, 1000);
        expect(result.unlisted, 100);
        expect(result.beyondBook, isFalse);
        expect(result.moves.map((m) => m.san), [
          'e5',
          'c5',
          'e6',
        ], reason: 'most played first');

        final deep = OpeningExplorerService.withClient(
          MockClient(
            (_) async => http.Response(
              jsonEncode(_e4Answer(beyondBook: true, total: 0)),
              200,
            ),
          ),
        );
        expect((await deep.lookup(_start)).result!.beyondBook, isTrue);
      },
    );

    test('a guest asks nothing', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsService.instance.init();
      await SessionService.instance.signOut();
      var called = false;
      final service = OpeningExplorerService.withClient(
        MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      final lookup = await service.lookup(_afterE4);

      expect(lookup.isAvailable, isFalse);
      expect(lookup.reason, 'guest');
      expect(called, isFalse);
    });

    test(
      "the server's reason survives, and a refusal is not remembered",
      () async {
        await _signIn();
        var calls = 0;
        final service = OpeningExplorerService.withClient(
          MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({'error': 'x', 'reason': 'not-configured'}),
              503,
            );
          }),
        );

        final first = await service.lookup(_afterE4);
        await service.lookup(_afterE4);

        expect(first.reason, 'not-configured');
        expect(calls, 2, reason: 'one bad minute must not close the panel');
      },
    );
  });

  group('the explorer panel', () {
    OpeningExplorerResult e4({bool beyondBook = false, int total = 1000}) =>
        OpeningExplorerResult.fromJson(
          _afterE4,
          _e4Answer(beyondBook: beyondBook, total: total),
        );

    testWidgets('names the position, counts it, and shares are of the whole', (
      tester,
    ) async {
      String? tapped;
      await _pumpPanel(
        tester,
        OpeningExplorerPanelWidget(
          isLoading: false,
          result: e4(),
          openingName: "B00 · King's Pawn Game",
          onMoveSelected: (uci) => tapped = uci,
        ),
      );

      expect(find.text("B00 · King's Pawn Game"), findsOneWidget);
      expect(find.text('1000 games'), findsOneWidget);
      // 600 of the 1000 that reached the position, not of the 900 listed.
      expect(find.text('e5 (60%)'), findsOneWidget);
      expect(find.text('c5 (30%)'), findsOneWidget);

      await tester.tap(find.text('e5 (60%)'));
      await tester.pump();
      expect(tapped, 'e7e5');
    });

    testWidgets('without a name it is the opening book', (tester) async {
      await _pumpPanel(
        tester,
        OpeningExplorerPanelWidget(isLoading: false, result: e4()),
      );
      expect(find.text('Opening book'), findsOneWidget);
    });

    testWidgets('offers no rating to choose', (tester) async {
      await _pumpPanel(
        tester,
        OpeningExplorerPanelWidget(isLoading: false, result: e4()),
      );
      expect(find.byWidgetPredicate((w) => w is DropdownButton), findsNothing);
      expect(find.byWidgetPredicate((w) => w is PopupMenuButton), findsNothing);
    });

    testWidgets('a guest is told to sign in, and shown no moves', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        const OpeningExplorerPanelWidget(
          isLoading: false,
          result: null,
          reason: 'guest',
        ),
      );
      expect(find.text(_guest), findsOneWidget);
      expect(
        find.text(_nobody),
        findsNothing,
        reason: 'a guest was not told nobody played this; they were not asked',
      );
    });

    testWidgets(
      "a server without the book says so, whichever way it lacks it",
      (tester) async {
        for (final reason in ['not-configured', 'unreadable', 'inconsistent']) {
          await _pumpPanel(
            tester,
            OpeningExplorerPanelWidget(
              isLoading: false,
              result: null,
              reason: reason,
            ),
          );
          expect(find.text(_noBook), findsOneWidget, reason: reason);
          expect(find.text(_nobody), findsNothing, reason: reason);
        }
      },
    );

    testWidgets('any other refusal is a book that could not be reached', (
      tester,
    ) async {
      for (final reason in ['network', 'http-500', 'rate-limited']) {
        await _pumpPanel(
          tester,
          OpeningExplorerPanelWidget(
            isLoading: false,
            result: null,
            reason: reason,
          ),
        );
        expect(find.text(_unreachable), findsOneWidget, reason: reason);
        expect(find.text(_noBook), findsNothing, reason: reason);
      }
    });

    testWidgets('past the depth of the book is not a position nobody played', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        OpeningExplorerPanelWidget(
          isLoading: false,
          result: e4(beyondBook: true, total: 0),
        ),
      );
      expect(find.text(_deeper), findsOneWidget);
      expect(find.text(_nobody), findsNothing);
    });

    testWidgets('a position no master game reached says exactly that', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        OpeningExplorerPanelWidget(isLoading: false, result: e4(total: 0)),
      );
      expect(find.text(_nobody), findsOneWidget);
      expect(find.text(_deeper), findsNothing);
    });

    testWidgets('while loading it says nothing it does not know yet', (
      tester,
    ) async {
      // Over the previous position's answer, which is what a screen holds
      // while the next one is on its way: an empty book and one past its depth
      // would each say something, and neither is about this position yet.
      for (final stale in [e4(total: 0), e4(beyondBook: true, total: 0)]) {
        await _pumpPanel(
          tester,
          OpeningExplorerPanelWidget(isLoading: true, result: stale),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        for (final sentence in [
          _guest,
          _noBook,
          _unreachable,
          _deeper,
          _nobody,
        ]) {
          expect(find.text(sentence), findsNothing, reason: sentence);
        }
      }
    });

    testWidgets('every state fits a 360 dp phone', (tester) async {
      final states = <OpeningExplorerPanelWidget>[
        OpeningExplorerPanelWidget(
          isLoading: false,
          result: e4(),
          openingName:
              'C89 · Ruy Lopez: Marshall Attack, Modern Main Line, Spassky Variation',
          onMoveSelected: (_) {},
        ),
        const OpeningExplorerPanelWidget(
          isLoading: false,
          result: null,
          reason: 'guest',
        ),
        const OpeningExplorerPanelWidget(
          isLoading: false,
          result: null,
          reason: 'not-configured',
        ),
        const OpeningExplorerPanelWidget(
          isLoading: false,
          result: null,
          reason: 'network',
        ),
        OpeningExplorerPanelWidget(
          isLoading: true,
          result: e4(beyondBook: true, total: 0),
        ),
      ];
      for (final panel in states) {
        await _pumpPanel(tester, panel, size: const Size(360, 640));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('no rating on the wire', () {
    test(
      'the judge asks about a position and a move, and nothing else',
      () async {
        await _signIn();
        final seen = <http.Request>[];
        final service = OpeningJudgeService.withClient(
          MockClient((req) async {
            seen.add(req);
            return http.Response(
              jsonEncode(
                req.url.path.endsWith('/replies')
                    ? {'total': 0, 'replies': [], 'all': []}
                    : {
                        'verdict': 'theory',
                        'masters': {'games': 10, 'total': 20},
                      },
              ),
              200,
            );
          }),
        );

        await service.judge(_start, 'e4');
        await service.replies(_afterE4);

        expect(seen.map((r) => r.url.queryParameters.keys.toSet()).toList(), [
          {'fen', 'move'},
          {'fen'},
        ]);
      },
    );

    test('a spine sends its colour, root, depth and floor', () async {
      await _signIn();
      late http.Request sent;
      final api = RepertoireApiService(
        client: MockClient((req) async {
          sent = req;
          return http.Response(
            jsonEncode({
              'written': 0,
              'path': [],
              'stopped': {'reason': 'depth'},
            }),
            200,
          );
        }),
      );

      await api.buildSpine(
        color: 'w',
        rootFen: _start,
        depth: 4,
        minGames: 100,
      );

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body.keys.toSet(), {'color', 'rootFen', 'depth', 'minGames'});
      expect(
        sent.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('x-lichess-token')),
      );
    });
  });

  group('what is gone', () {
    test('ChessDB: the service, and every reader of it', () {
      expect(
        File(
          'lib/features/analysis_studio/services/chessdb_service.dart',
        ).existsSync(),
        isFalse,
      );
      for (final file in [..._dartFiles('lib'), ..._dartFiles('test')]) {
        final code = codeOf(file.readAsStringSync());
        expect(code, isNot(contains('chessdb_service')), reason: file.path);
        expect(code, isNot(contains('ChessDb')), reason: file.path);
        expect(code, isNot(contains('openingDbSource')), reason: file.path);
      }
      for (final file in _dartFiles('lib')) {
        for (final literal in literalsIn(file.readAsStringSync())) {
          expect(
            literal.toLowerCase(),
            isNot(contains('chessdb')),
            reason: '${file.path}: "$literal"',
          );
        }
      }
    });

    test('the personal Lichess token: no field, no setting, no request', () {
      for (final file in _dartFiles('lib')) {
        final src = file.readAsStringSync();
        final code = codeOf(src);
        for (final name in [
          'lichessApiToken',
          'setLichessApiToken',
          'createTokenUrl',
        ]) {
          expect(code, isNot(contains(name)), reason: '${file.path}: $name');
        }
        for (final literal in literalsIn(src)) {
          expect(
            literal,
            isNot(contains('explorer.lichess.ovh')),
            reason: file.path,
          );
          expect(
            literal,
            isNot(contains('X-Lichess-Token')),
            reason: file.path,
          );
          expect(
            literal,
            isNot(contains('oauth/token/create')),
            reason: file.path,
          );
        }
      }
    });

    test(
      'a token a device already stored is removed when settings load',
      () async {
        SharedPreferences.setMockInitialValues({
          'lichess_api_token': 'lip_old',
        });
        await AppSettingsService.instance.init();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('lichess_api_token'), isNull);
      },
    );

    test('the book takes no rating anywhere', () {
      final scoped = [
        ..._dartFiles('lib/features/repertoire'),
        ..._dartFiles('lib/features/analysis_studio'),
        File('lib/features/archive/services/archive_api_service.dart'),
        File('lib/features/archive/screens/opening_leak_report_screen.dart'),
        File('lib/services/app_settings_service.dart'),
        File('lib/screens/settings_screen.dart'),
      ];
      for (final file in scoped) {
        final src = file.readAsStringSync();
        expect(codeOf(src), isNot(contains('minRating')), reason: file.path);
        expect(codeOf(src), isNot(contains('MinRating')), reason: file.path);
        expect(
          literalsIn(src),
          isNot(contains('minRating')),
          reason: file.path,
        );
      }
      for (final file in _dartFiles('lib')) {
        final code = codeOf(file.readAsStringSync());
        for (final name in [
          'repertoireMinRating',
          'kRepertoireRatingBands',
          'kOpeningExplorerRatingOptions',
          'ratingOptionLabel',
        ]) {
          expect(code, isNot(contains(name)), reason: '${file.path}: $name');
        }
        expect(
          literalsIn(file.readAsStringSync()),
          isNot(contains('Opponent rating')),
          reason: file.path,
        );
      }
    });

    test('the analysis screen hands the panel its name and its reason', () {
      final code = codeOf(
        _read(
          'lib/features/analysis_studio/screens/analysis_studio_screen.dart',
        ),
      );
      final call = _callTo(code, 'OpeningExplorerPanelWidget');
      expect(call, isNotEmpty, reason: 'the panel is still drawn');
      expect(call, contains('openingName:'));
      expect(call, contains('reason:'));
      expect(call, isNot(contains('minRating')));
    });

    test('nothing in the repertoire says the book costs a Lichess request', () {
      final stale = RegExp(
        r'lichess (request|requests|allowance|quota)|the lichess one|'
        r'token (that )?serves every|shared (server )?token|'
        r"(reader|student|user)'s own (lichess )?(allowance|token)",
        caseSensitive: false,
      );
      final scoped = [
        ..._dartFiles('lib/features/repertoire'),
        ..._dartFiles(
          'lib/features/analysis_studio',
        ).where((f) => f.path.contains('opening_')),
        File('lib/screens/settings_screen.dart'),
      ];
      for (final file in scoped) {
        final src = file.readAsStringSync();
        for (final text in [...commentsOf(src), ...literalsIn(src)]) {
          expect(
            stale.hasMatch(text),
            isFalse,
            reason: '${file.path}: "${text.trim()}"',
          );
        }
      }
    });

    test('puzzle assignments keep their own rating', () {
      // Not the book's: a puzzle's rating is how hard the puzzle is. A sweep
      // that took this too would have broken homework in silence.
      expect(
        codeOf(
          _read(
            'lib/features/assignments/services/assignment_api_service.dart',
          ),
        ),
        contains('minRating'),
      );
      expect(
        codeOf(
          _read(
            'lib/features/assignments/widgets/create_assignment_dialog.dart',
          ),
        ),
        contains('minRating'),
      );
    });
  });

  group('the source reader this gate stands on', () {
    // A gate that reads source is only as good as its reader. These are the
    // cases that made the three earlier gates in this repository wrong.
    const sample = r'''
// minRating was removed here
/// Talks about ChessDb in a doc comment.
final uri = {'fen': fen, 'moves': '$moves'};
final label = 'Played by ${stats.minRating} players';
final pattern = r'\b(?:O-O' r'|0-0)';
final sentence = 'Sign in to see '
    'the opening book.';
''';

    test('comments are not code', () {
      final code = codeOf(sample);
      expect(code, isNot(contains('removed here')));
      expect(code, isNot(contains('ChessDb')));
      expect(commentsOf(sample).join(), contains('ChessDb'));
    });

    test('an interpolation is code, a literal is not', () {
      final code = codeOf(sample);
      expect(code, contains('stats.minRating'));
      expect(code, isNot(contains("'fen'")));
      expect(code, isNot(contains('Played by')));
    });

    test('adjacent literals are one sentence, raw ones included', () {
      final literals = literalsIn(sample);
      expect(literals, contains('Sign in to see the opening book.'));
      expect(literals, contains(r'\b(?:O-O|0-0)'));
    });
  });
}
