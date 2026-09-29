import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/features/archive/screens/opening_leak_report_screen.dart';
import 'package:chess_app/features/archive/screens/player_profile_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';

import '../../support/landscape.dart' show loadRoboto;

/// Opening leaks and the player's profile laid out for the width they are
/// given (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md` §9): the profile's sections
/// flow into columns, the leak positions into rows of cards, and a phone
/// keeps one of each per line.
class _Api extends Fake implements ArchiveApiService {
  @override
  Future<PlayerProfile> getPlayerProfile(String username) async {
    List<ProfileBucket> b(List<(String, int, double)> rows) => [
          for (final (k, g, s) in rows)
            ProfileBucket(key: k, games: g, score: s),
        ];
    return PlayerProfile(
      byColor: b([('b', 2066, .51), ('w', 2060, .51)]),
      bySpeed: b([('blitz', 4073, .51), ('bullet', 52, .51), ('rapid', 1, 1)]),
      byTermination: b([('Normal', 3446, .48), ('Time forfeit', 680, .66)]),
      byLength: b([('moves 20-40', 2196, .51), ('over 40 moves', 1234, .54)]),
      byPhase: b([('decided before endgame', 3237, .50)]),
      byYear: const [
        ProfileYearBucket(key: '2016', games: 494, score: .52, avgElo: 1922),
        ProfileYearBucket(key: '2020', games: 106, score: .60, avgElo: 1872),
      ],
      byOpening:
          b([('Sicilian Defense', 800, .49), ('French Defense', 300, .5)]),
    );
  }

  @override
  Future<LeakReport> getLeaks({
    required String subject,
    String? color,
    int? fromPly,
    int? toPly,
    int? minGames,
    double? maxScore,
    String? speed,
    int? limit,
    bool? judge,
    int? judgeLimit,
  }) async {
    return LeakReport(
      subject: subject,
      games: 400,
      gamesWithoutNodes: 0,
      judge: const LeakReportJudge(requested: false, judged: 0, nodes: 0),
      nodes: [
        for (var i = 0; i < 6; i++)
          LeakReportNode(
            fenKey: 'fen$i',
            fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
            ply: 7 + i,
            games: 50,
            score: 0.4,
            moves: [
              const LeakReportMove(
                  san: 'd4', games: 45, score: 0.38, share: 0.9),
              const LeakReportMove(
                  san: 'Nf3', games: 5, score: 0.5, share: 0.1),
            ],
          ),
      ],
    );
  }
}

void main() {
  setUpAll(loadRoboto);

  setUp(() {
    // Any file that exists counts as an engine on disk; nothing starts one
    // unless „Judge with the engine" is pressed, and no case presses it.
    SharedPreferences.setMockInitialValues(
        {'custom_engine_path': 'pubspec.yaml'});
    ArchiveApiService.setMock(_Api());
  });

  Future<void> open(WidgetTester tester, Size size, Widget screen) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto'),
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  const profile = PlayerProfileScreen(username: 'someone');
  const leaks = OpeningLeakReportScreen(subject: 'someone');

  Set<double> lefts(WidgetTester tester, Finder f) => {
        for (final e in f.evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dx.roundToDouble(),
      };

  final sections = find.byWidgetPredicate(
      (w) => w is Card && '${w.key}'.contains('profile-section-'));
  final positions = find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      '${(w.key as ValueKey).value}'.startsWith('fen'));

  for (final (size, columns) in const [
    (Size(1536, 792), 4),
    (Size(900, 700), 3),
    (Size(360, 640), 1),
  ]) {
    testWidgets('profile at ${size.width.toInt()}: $columns column(s)',
        (tester) async {
      await open(tester, size, profile);
      expect(lefts(tester, sections), hasLength(columns));
    });

    testWidgets('leaks at ${size.width.toInt()}: $columns position(s) a row',
        (tester) async {
      await open(tester, size, leaks);
      expect(lefts(tester, positions), hasLength(columns));
      // And ranked left to right: the second position is beside the first
      // wherever a row holds two.
      if (columns > 1) {
        expect(tester.getTopLeft(find.byKey(const ValueKey('fen1'))).dy,
            tester.getTopLeft(find.byKey(const ValueKey('fen0'))).dy);
      }
    });
  }

  for (final size in const [
    Size(360, 640),
    Size(900, 700),
    Size(1536, 792),
    Size(1920, 1080),
  ]) {
    testWidgets('nothing overflows at ${size.width.toInt()}', (tester) async {
      await open(tester, size, profile);
      expect(tester.takeException(), isNull);
      await open(tester, size, leaks);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'a profile line reads as a table row: label left, games and score '
      'right, and one game is one game', (tester) async {
    await open(tester, const Size(1536, 792), profile);
    final label = tester.getRect(find.text('rapid'));
    final games = tester.getRect(find.text('1 game'));
    final card = tester
        .getRect(find.byKey(const ValueKey('profile-section-By time control')));
    // The label's box fills its slot (it is Expanded), so the measure is
    // where it starts: the games stand well to the right of it.
    expect(games.left, greaterThan(label.left + 150));
    expect(card.right - games.right, lessThan(120));
    expect(find.text('1 games'), findsNothing);
  });

  testWidgets('„Judge with the engine" is as wide as its words, not the window',
      (tester) async {
    await open(tester, const Size(1536, 792), leaks);
    final button = find.byKey(const Key('engine-judge-start'));
    expect(button, findsOneWidget);
    expect(tester.getSize(button).width, lessThan(400));
  });
}
