import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

void main() {
  _guardTheDeletePath();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RepertoireApiService unconfirmed', () {
    test('unconfirmedPositions decodes walk correctly', () async {
      final mock = MockClient((request) async {
        return http.Response(
            jsonEncode({
              "root": {
                "fen":
                    "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                "path": []
              },
              "positions": [
                {
                  "fen":
                      "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
                  "fenKey": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR",
                  "path": ["e4"],
                  "ply": "1",
                  "moves": [
                    {"uci": "e7e5", "san": "e5", "role": "primary"}
                  ]
                }
              ],
              "total": "37",
              "truncated": false
            }),
            200);
      });

      final api = RepertoireApiService.withClient(mock);
      final walk = await api.unconfirmedPositions(
          color: 'w',
          rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

      expect(walk, isNotNull);
      expect(walk!.total, 37);
      expect(walk.positions.length, 1);
      expect(walk.positions[0].ply, 1);
      expect(walk.positions[0].moves[0].uci, 'e7e5');
    });

    test('unconfirmedCounts decodes counts correctly', () async {
      final mock = MockClient((request) async {
        return http.Response(
            jsonEncode({
              "w": {"positions": "12", "moves": "19"},
              "b": {"positions": 0, "moves": 0}
            }),
            200);
      });

      final api = RepertoireApiService.withClient(mock);
      final counts = await api.unconfirmedCounts();

      expect(counts, isNotNull);
      expect(counts!.w.positions, 12);
      expect(counts.w.moves, 19);
      expect(counts.b.positions, 0);
      expect(counts.b.moves, 0);
    });

    test('playAlternative decodes result correctly', () async {
      final mock = MockClient((request) async {
        return http.Response(
            jsonEncode({
              "played": {
                "uci": "e2e4",
                "san": "e4",
                "role": "primary",
                "source": "chosen"
              },
              "rejected": "d2d4",
              "orphans": "6",
              "removed": "9",
              "decisions": "3",
              "drafts": "9"
            }),
            200);
      });

      final api = RepertoireApiService.withClient(mock);
      final res = await api.playAlternative(
        color: 'w',
        fen: 'start',
        uci: 'e2e4',
        san: 'e4',
        rejectedUci: 'd2d4',
      );

      expect(res.error, isNull);
      expect(res.result, isNotNull);
      expect(res.result!.played.uci, 'e2e4');
      expect(res.result!.rejected, 'd2d4');
      expect(res.result!.decisions, 3);
    });
  });
}

/// The delete path, guarded at the source.
///
/// `playAlternative` sweeps what the rejected draft was the only way to.
/// Drafts go without asking; the student's own decisions are counted and left
/// standing unless `includeDecisions: true` is sent. So that flag is the one
/// parameter in this feature that destroys work, and the rule is that it may
/// only ever be sent *after* the reader has been shown the number and said
/// yes.
///
/// Driving that through the UI means opening the banner, opening the wizard,
/// choosing "play alternative", waiting for the sheet to pop, and landing the
/// screen on the right node — a chain long enough that the test would break
/// for a dozen reasons having nothing to do with the rule. So it is read out
/// of the source instead, and the body is found by **matching braces, never by
/// slicing**: a guard in this project once read a fixed 1600 characters, ran
/// past the end of its function into the next one, and still matched after the
/// check it guarded had been deleted.
void _guardTheDeletePath() {
  test('includeDecisions: true is only sent inside a confirmation branch', () {
    final src = File(
      'lib/features/repertoire/screens/repertoire_build_screen.dart',
    ).readAsStringSync();

    // Every branch of the shape `if (<answer> == true ...) { ... }`, with its
    // body found by matching braces. There are two delete paths on this screen
    // and both are gated this way: replacing a draft, and changing a decided
    // move. Pinning the count instead would fail the day a third is added
    // correctly, which is the kind of gate that gets switched off.
    final safe = <List<int>>[];
    for (final m
        in RegExp(r'if \([A-Za-z_][A-Za-z0-9_]* == true').allMatches(src)) {
      var i = src.indexOf('{', m.end);
      if (i == -1) continue;
      var depth = 0;
      for (; i < src.length; i++) {
        if (src[i] == '{') depth++;
        if (src[i] == '}') {
          depth--;
          if (depth == 0) break;
        }
      }
      safe.add([m.start, i]);
    }
    expect(safe, isNotEmpty,
        reason: 'no confirmation branch found at all — nothing gates a sweep');

    final forced = 'includeDecisions: true'.allMatches(src).toList();
    expect(forced, isNotEmpty,
        reason: 'the forcing call is gone; this guard is now pointed at '
            'nothing and should be re-aimed or deleted');

    for (final f in forced) {
      final inside = safe.any((r) => f.start > r[0] && f.start < r[1]);
      expect(inside, isTrue,
          reason: 'a sweep at offset ${f.start} is not inside any '
              '"== true" branch — work would be deleted without the reader '
              'ever being shown the number');
    }
  });
}
