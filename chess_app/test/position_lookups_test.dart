// The tablebase and the opening explorer for the position on a board, in one
// home — phase 2 of docs/PLAN-MOTOR-I-PANELI.md (D8).
//
// Analysis fetched both inline, on every position change, **whether their
// panels were shown or not**, each behind a request id of its own. Preparation
// and the tutorial studio need the same two look-ups; a second and a third
// copy of that code is what this file exists to prevent. So the rules are
// written here once, against the requests that actually leave the app (rule 7:
// fake the client, assert on the request):
//
//   * a hidden panel asks nothing;
//   * a shown panel asks once for a position, and again only for a new one;
//   * showing a panel asks for the position already on the board;
//   * an answer that arrives after the board has moved on is dropped;
//   * the tablebase is asked only with seven pieces or fewer, and for the
//     distance to mate (a person is reading it);
//   * a guest's explorer says why it is empty and asks nothing;
//   * nothing is told after `dispose`.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/position_lookups.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/services/session_service.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';
// Five pieces: the tablebase answers.
const _ending = '8/8/5k2/p7/P1K5/2N5/8/8 b - - 0 52';
const _ending2 = '8/8/4k3/p7/P1K5/2N5/8/8 w - - 1 53';

const _tablebaseAnswer = {
  'category': 'loss',
  'dtz': -4,
  'dtm': -21,
  'checkmate': false,
  'stalemate': false,
  'insufficient_material': false,
  'moves': [
    {
      'uci': 'f6e5',
      'san': 'Ke5',
      'category': 'win',
      'dtz': 3,
      'dtm': 20,
      'zeroing': false,
      'checkmate': false,
      'stalemate': false,
    },
  ],
};

Map<String, Object> _book(String san, String uci) => {
      'white': 10,
      'draws': 5,
      'black': 3,
      'moves': [
        {'uci': uci, 'san': san, 'white': 10, 'draws': 5, 'black': 3},
      ],
    };

/// Every request that leaves the app, and a server that answers each one —
/// at once, or when the case says so.
class _Net {
  final seen = <http.Request>[];
  final _held = <String, Completer<http.Response>>{};
  bool holdExplorer = false;

  late final MockClient client = MockClient((request) async {
    seen.add(request);
    if (request.url.path.endsWith('/opening-explorer')) {
      final fen = request.url.queryParameters['fen']!;
      final body =
          jsonEncode(fen == _start ? _book('e4', 'e2e4') : _book('e5', 'e7e5'));
      if (holdExplorer) {
        final c = Completer<http.Response>();
        _held[fen] = c;
        return c.future;
      }
      return http.Response(body, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response(jsonEncode(_tablebaseAnswer), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });

  void release(String fen) {
    _held.remove(fen)!.complete(http.Response(
        jsonEncode(fen == _start ? _book('e4', 'e2e4') : _book('e5', 'e7e5')),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
  }

  int get explorerAsked =>
      seen.where((r) => r.url.path.endsWith('/opening-explorer')).length;
  int get tablebaseAsked => seen.length - explorerAsked;
}

Future<void> _signIn({bool guest = false}) async {
  SharedPreferences.setMockInitialValues(guest
      ? {}
      : {
          'remember_me': true,
          'user_token': 'tok',
          'user_id': 1,
          'user_email': 'e',
          'user_name': 'N',
          'user_role': 'korisnik',
        });
  await SessionService.instance.init();
}

PositionLookups _lookups(_Net net) => PositionLookups(
      tablebase: SyzygyTablebaseService.forTesting(
          client: net.client,
          token: 'tok',
          // No pacing in a unit test: the gap is the service's own rule,
          // tested in syzygy_tablebase_pacing_test.
          sleep: (_) async {}),
      explorer: OpeningExplorerService.withClient(net.client),
    );

/// Lets the fake server's answers land.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUp(() => _signIn());

  test('a hidden panel asks nothing', () async {
    final net = _Net();
    final lookups = _lookups(net);
    lookups.lookUp(_start);
    lookups.lookUp(_ending);
    await _settle();
    expect(net.seen, isEmpty,
        reason: 'asked ${net.seen.map((r) => r.url.path).toList()} '
            'with both panels hidden');
    expect(lookups.explorer, isNull);
    expect(lookups.tablebase, isNull);
    lookups.dispose();
  });

  test('a shown explorer asks once for a position, again for a new one',
      () async {
    final net = _Net();
    final lookups = _lookups(net)..show(explorer: true);
    var told = 0;
    lookups.addListener(() => told++);
    lookups.lookUp(_start);
    await _settle();
    expect(net.explorerAsked, 1);
    expect(net.seen.single.url.queryParameters['fen'], _start);
    expect(lookups.explorer?.moves.single.san, 'e4');
    expect(lookups.explorerLoading, isFalse);
    expect(told, greaterThan(0), reason: 'the screen was never told');

    lookups.lookUp(_afterE4);
    await _settle();
    expect(net.explorerAsked, 2);
    expect(lookups.explorer?.moves.single.san, 'e5');
    expect(net.tablebaseAsked, 0, reason: 'the hidden tablebase was asked');
    lookups.dispose();
  });

  test('showing a panel asks for the position already on the board', () async {
    final net = _Net();
    final lookups = _lookups(net);
    lookups.lookUp(_afterE4);
    await _settle();
    expect(net.seen, isEmpty);
    lookups.show(explorer: true);
    await _settle();
    expect(net.explorerAsked, 1,
        reason: 'a panel shown over a board waited for the next move');
    expect(net.seen.single.url.queryParameters['fen'], _afterE4);
    lookups.dispose();
  });

  test('an answer for a board that has moved on is dropped', () async {
    final net = _Net()..holdExplorer = true;
    final lookups = _lookups(net)..show(explorer: true);
    lookups.lookUp(_start);
    lookups.lookUp(_afterE4);
    await _settle();
    expect(lookups.explorerLoading, isTrue);
    net.release(_afterE4);
    await _settle();
    expect(lookups.explorer?.moves.single.san, 'e5');
    net.release(_start); // the older answer, late
    await _settle();
    expect(lookups.explorer?.moves.single.san, 'e5',
        reason: 'a late answer for the old position replaced the new one');
    expect(lookups.explorerLoading, isFalse);
    lookups.dispose();
  });

  test('the tablebase is asked with seven pieces or fewer, for mate distance',
      () async {
    final net = _Net();
    final lookups = _lookups(net)..show(tablebase: true);
    lookups.lookUp(_start);
    await _settle();
    expect(net.seen, isEmpty, reason: 'asked the tablebase with 32 pieces');
    expect(lookups.tablebaseEligible, isFalse);

    lookups.lookUp(_ending);
    await _settle();
    expect(lookups.tablebaseEligible, isTrue);
    expect(net.tablebaseAsked, 1);
    final asked = net.seen.single.url;
    expect(asked.path, endsWith('/api/tablebase'));
    expect(asked.queryParameters['fen'], _ending);
    expect(asked.queryParameters['mate'], '1',
        reason: 'a person reads this panel: the distance to mate is asked');
    expect(lookups.tablebase?.moves.single.san, 'Ke5');

    lookups.lookUp(_ending2);
    await _settle();
    expect(net.tablebaseAsked, 2);
    expect(net.explorerAsked, 0, reason: 'the hidden explorer was asked');
    lookups.dispose();
  });

  test('hiding a panel again clears what it showed and asks no more', () async {
    final net = _Net();
    final lookups = _lookups(net)..show(explorer: true);
    lookups.lookUp(_start);
    await _settle();
    expect(lookups.explorer, isNotNull);
    lookups.show(explorer: false);
    expect(lookups.explorer, isNull);
    lookups.lookUp(_afterE4);
    await _settle();
    expect(net.explorerAsked, 1);
    lookups.dispose();
  });

  test('a guest\'s explorer says why and asks nothing', () async {
    await _signIn(guest: true);
    final net = _Net();
    final lookups = _lookups(net)..show(explorer: true);
    lookups.lookUp(_start);
    await _settle();
    expect(net.explorerAsked, 0);
    expect(lookups.explorer, isNull);
    expect(lookups.explorerReason, 'guest');
    lookups.dispose();
  });

  test('nothing is told after dispose', () async {
    final net = _Net()..holdExplorer = true;
    final lookups = _lookups(net)..show(explorer: true);
    var told = 0;
    lookups.addListener(() => told++);
    lookups.lookUp(_start);
    await _settle();
    final before = told;
    lookups.dispose();
    net.release(_start);
    await _settle(); // a notify after dispose throws in a ChangeNotifier
    expect(told, before);
  });
}
