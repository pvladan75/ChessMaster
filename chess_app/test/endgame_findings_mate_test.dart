// The trainer's `Tablebase findings`, read for the distance to mate.
//
// Reported 1.10.2026: the list stood two captures with DTZ 30 above the
// fastest mate, every row said only „DTZ", and the reader could not tell
// which move was best. The server now hands the tablebase's own order and
// its `dtm`; the screen keeps the order and says „mate in N" / „mated in N",
// and DTZ only where no source knew the distance — saying then that DTZ is
// not a distance to mate.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';

import 'support/landscape.dart';

Map<String, dynamic> _move(String san, String outcome,
        {int? dtz, int? dtm, bool zeroing = false, bool holds = true}) =>
    {
      'san': san,
      'uci': 'a1a2',
      'outcome': outcome,
      'holds': holds,
      'zeroing': zeroing,
      'dtz': dtz,
      'dtm': dtm,
    };

/// Lucena, the winner's list as Lichess orders it: two mates in 21 first, a
/// capture with a far larger DTZ further down, a drawing and a losing move.
final _known = <String, dynamic>{
  'goal': 'win',
  'outcome': 'win',
  'holding': 3,
  'total': 5,
  'pawnless': false,
  'deadDraw': false,
  'dtz': 15,
  'dtm': 41,
  'moves': [
    _move('Rd1+', 'win', dtz: -14, dtm: -40),
    _move('Rc4', 'win', dtz: -14, dtm: -40),
    _move('Rxa2', 'win', dtz: -30, dtm: -44, zeroing: true),
    _move('Ra1', 'draw', dtz: 0, dtm: 0, holds: false),
    _move('Rc2', 'loss', dtz: 1, dtm: 39, holds: false),
  ],
};

/// The same with one winning move whose distance no source knew.
final _partly = <String, dynamic>{
  ..._known,
  'moves': [
    ...(_known['moves'] as List).take(2),
    _move('Rxa2', 'win', dtz: -30, zeroing: true),
    ...(_known['moves'] as List).skip(3),
  ],
};

class _Api extends EndgameApiService {
  _Api(this.readout) : super(authToken: '');

  final Map<String, dynamic> readout;

  @override
  Future<EndgameFetchResult> fetchNext({
    EndgameMode? mode,
    String? excludeId,
    String? material,
    String? band,
    bool oppositeOnly = false,
    bool includeOnline = false,
  }) async =>
      EndgameFetchResult(
        EndgameFetchOutcome.ok,
        EndgamePuzzle.fromJson({
          'puzzle_id': 'eg_mate',
          'fen': '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1',
          'type': 'RookAndPawnVsRook',
          'mode': 'win',
          'winning_moves': ['c1d1'],
          'solution': ['c1d1'],
          'piece_count': 5,
          'pawn_count': 1,
          'source': 'syzygy',
        }),
      );

  @override
  Future<TablebaseReadout?> fetchReadout({
    required String fen,
    required EndgameMode goal,
  }) async =>
      TablebaseReadout.fromJson(readout);
}

Future<void> _openFindings(WidgetTester tester, Map<String, dynamic> readout,
    {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: EndgameTrainerScreen(
      session: UserSession(
          token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
      api: _Api(readout),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Play to the end'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Play to the end'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Tablebase findings'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tablebase findings'));
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  setUpAll(loadRoboto);

  testWidgets('the rows keep the served order, best first, with mate in N',
      (tester) async {
    await _openFindings(tester, _known, size: const Size(1400, 1000));

    expect(find.text('Hide findings'), findsOneWidget,
        reason: 'the findings are open beside the board');
    // Order: what the server sent, never sorted again by zeroing or DTZ.
    expect(_top(tester, 'Rd1+'), lessThan(_top(tester, 'Rc4')));
    expect(_top(tester, 'Rc4'), lessThan(_top(tester, 'Rxa2 *')));
    expect(_top(tester, 'Rxa2 *'), lessThan(_top(tester, 'Rc2')));

    expect(find.text('mate in 21'), findsNWidgets(2));
    expect(find.text('mate in 23'), findsOneWidget);
    expect(find.text('mated in 20'), findsOneWidget);
    expect(find.textContaining('win, mate in 21'), findsOneWidget,
        reason: "the position's own line names the mate too");
    expect(find.textContaining('DTZ'), findsNothing,
        reason: 'every decided move has its distance to mate');
  });

  testWidgets('a move with no distance to mate shows DTZ, and says what it is',
      (tester) async {
    await _openFindings(tester, _partly, size: const Size(1400, 1000));

    expect(find.text('DTZ -30'), findsOneWidget);
    expect(find.text('mate in 21'), findsNWidgets(2));
    expect(find.textContaining('not to mate'), findsOneWidget);
  });

  testWidgets('on a phone the window fits with the longer labels',
      (tester) async {
    await _openFindings(tester, _partly, size: const Size(360, 640));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('mated in 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
