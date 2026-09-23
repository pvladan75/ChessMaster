// Settle and propose before saving — docs/PLAN-MATERIJAL.md, phase 2, on the
// font path (ScanReviewScreen). The picture path's cases are in
// image_scan_screen_test.dart, group „phase 2 — the engine before saving",
// because that file already knows how to walk a picture book to its boards.
//
// Until this phase the engine was asked whose move it is only after saving,
// on Saved Positions, and kept the number but not the move. Now the scanner
// asks before saving, over the boards whose side nobody set, and a person
// takes the side — and, if they choose, the move — or leaves it.
//
// The server is a MockClient that records every request; the engine is a
// FakeSideRunner through the screen's constructor seam. Every rule is read
// off what `POST /scans/confirm` was sent (rule 7).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/position_scanner/screens/scan_review_screen.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/position_scanner/widgets/side_suggestions.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/fake_side_runner.dart';

const _placement = '6k1/5ppp/8/8/8/8/5PPP/R5K1';

/// Four boards: two whose side the book did not give (p0, p1), one whose
/// side the book's solution settled (p2), and one more nobody set (p3), which
/// the case that needs it flips by hand before the run.
final _positions = [
  {'fen': '$_placement w - - 0 1', 'page': 5, 'label': '1'},
  {'fen': '$_placement w - - 0 1', 'page': 5, 'label': '2'},
  {
    'fen': '$_placement w - - 0 1',
    'page': 5,
    'label': '3',
    'sideSource': 'solution',
    'solutionSan': 'Ra8#',
    'solutionLegal': true,
  },
  {'fen': '$_placement w - - 0 1', 'page': 6, 'label': '4'},
];

/// What the engine says about each: a confident White mate, a likely Black
/// move (a book can ask for a defence, so it is not taken in bulk), and
/// answers for the two that must never be asked.
final _answers = {
  'p0': highProposal('w', 'Ra8#'),
  'p1': mediumProposal('b', 'Kf8'),
  'p2': highProposal('b', 'Kh8'),
  'p3': highProposal('b', 'Kh8'),
};

class _Server {
  final List<http.Request> sent = [];

  http.Client client() => MockClient((req) async {
        sent.add(req);
        final path = req.url.path;
        if (path.startsWith('/scans/calibrations/')) {
          return http.Response(
              jsonEncode({'error': 'none', 'code': 'no_calibration'}), 404);
        }
        if (path == '/scans/kind') {
          return http.Response(
              jsonEncode({'pageCount': 40, 'kind': 'font'}), 200);
        }
        if (path == '/scans') {
          return http.Response(
              jsonEncode({
                'documentName': 'Book.pdf',
                'pageCount': 40,
                'scannedFrom': 1,
                'scannedTo': 20,
                'font': 'Merida',
                'positions': _positions,
              }),
              200);
        }
        if (path == '/scans/confirm') {
          return http.Response(
              jsonEncode({'saved': 4, 'filled': 0, 'unchanged': 0}), 201);
        }
        return http.Response('unexpected ${req.method} $path', 500);
      });

  /// The boards the last save sent, by their printed label.
  Map<String, Map<String, dynamic>> confirmed() {
    final request = sent.lastWhere((r) => r.url.path == '/scans/confirm');
    final positions = ((jsonDecode(request.body) as Map)['positions'] as List)
        .cast<Map<String, dynamic>>();
    return {for (final p in positions) p['label'] as String: p};
  }
}

Future<void> _settle(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Picks a book, scans it, and leaves its four boards on screen.
Future<_Server> _scanned(WidgetTester tester, FakeSideRunner runner,
    {Size size = const Size(1280, 1400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server();
  final path = await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('scan_settle_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/Book.pdf');
    await file.writeAsString('%PDF-1.4 ${server.hashCode}');
    return file.path;
  });
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => ScanReviewScreen(
        session: UserSession(
            token: 'tok', id: 1, email: 'e', name: 'A', role: 'korisnik'),
        api: ScannerApiService(authToken: 'tok', client: server.client()),
        pickDocument: () async => (path: path!, name: 'Book.pdf'),
        proposalRunner: runner,
      ),
    ),
    GoRoute(
        path: '/scan/saved',
        builder: (_, __) => const Scaffold(body: Text('saved'))),
  ]);
  await tester.pumpWidget(MaterialApp.router(
    key: UniqueKey(),
    routerConfig: router,
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
  ));
  await tester.tap(find.text('Select PDF'));
  await _settle(tester, 20);
  await tester.tap(find.text('Scan'));
  await _settle(tester, 20);
  await _scrollTo(tester, find.byKey(const ValueKey('scan-card-p0')));
  expect(find.byKey(const ValueKey('scan-card-p0')), findsOneWidget,
      reason: 'the scan did not reach the screen');
  return server;
}

/// The screen is one scroll, and a board below the fold is not built until
/// it is scrolled to — as a person would.
Future<void> _scrollTo(WidgetTester tester, Finder target) =>
    tester.scrollUntilVisible(target, 120,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);

Future<void> _tap(WidgetTester tester, Key key) async {
  await _scrollTo(tester, find.byKey(key));
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

Future<void> _suggest(WidgetTester tester) async {
  await _tap(tester, const ValueKey('suggest-sides'));
  await _settle(tester, 4);
}

Future<void> _save(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save (4)');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await _settle(tester, 12);
}

/// The side of a sent FEN.
String _side(Map<String, dynamic> p) => (p['fen'] as String).split(' ')[1];

void main() {
  testWidgets(
      'only boards whose side nobody set are asked: not one the book settled, '
      'not one flipped by hand', (tester) async {
    final runner = FakeSideRunner(_answers);
    final server = await _scanned(tester, runner);
    // Flipped by hand before the run: a person set it.
    await _scrollTo(tester, find.byKey(const ValueKey('scan-card-p3')));
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('scan-card-p3')),
        matching: find.text('White to move')));
    await tester.pump();

    await _suggest(tester);
    expect(runner.askedIds, ['p0', 'p1']);
    expect(find.byKey(const ValueKey('proposal-p0')), findsOneWidget);
    expect(find.byKey(const ValueKey('proposal-p3')), findsNothing);

    // And a side set by hand is settled, as on the picture path — until this
    // phase a font board flipped by hand was still saved marked for review.
    await _save(tester);
    final sent = server.confirmed();
    expect(_side(sent['4']!), 'b');
    expect(sent['4']!['needsReview'], false);
  });

  testWidgets('„Set side" sets the side and clears the mark; no answer is sent',
      (tester) async {
    final server = await _scanned(tester, FakeSideRunner(_answers));
    await _suggest(tester);
    await _tap(tester, const ValueKey('proposal-set-side-p1'));
    expect(find.byKey(const ValueKey('proposal-p1')), findsNothing,
        reason: 'an accepted proposal stays on the board');
    await _save(tester);

    final p1 = server.confirmed()['2']!;
    expect(_side(p1), 'b');
    expect(p1['needsReview'], false);
    expect(p1.containsKey('solutionSan'), isFalse,
        reason: 'the side alone was taken, not the move');
    // p0 was not touched: still in doubt.
    expect(server.confirmed()['1']!['needsReview'], true);
  });

  testWidgets('„Set side and answer" sends the move as the engine\'s',
      (tester) async {
    final server = await _scanned(tester, FakeSideRunner(_answers));
    await _suggest(tester);
    await _tap(tester, const ValueKey('proposal-set-answer-p1'));
    await _save(tester);

    final p1 = server.confirmed()['2']!;
    expect(_side(p1), 'b');
    expect(p1['solutionSan'], 'Kf8');
    expect(p1['solutionSource'], 'engine');
    expect(p1['needsReview'], false);
    // The book's own move is sent without a source: it is the book's.
    expect(server.confirmed()['3']!['solutionSan'], 'Ra8#');
    expect(server.confirmed()['3']!.containsKey('solutionSource'), isFalse);
  });

  testWidgets('„Accept all confident" takes the high proposals only',
      (tester) async {
    final server = await _scanned(tester, FakeSideRunner(_answers));
    await _suggest(tester);
    // p0 and p3 are confident (p3 is flipped only in the first case).
    expect(find.text('Accept all confident (2)'), findsOneWidget);
    await _tap(tester, const ValueKey('suggest-sides-accept-confident'));
    await _save(tester);

    final sent = server.confirmed();
    expect(_side(sent['1']!), 'w');
    expect(sent['1']!['solutionSan'], 'Ra8#');
    expect(sent['1']!['solutionSource'], 'engine');
    expect(sent['1']!['needsReview'], false);
    expect(_side(sent['4']!), 'b');
    expect(sent['4']!['solutionSan'], 'Kh8');
    // The likely one is left for a person to look at.
    expect(_side(sent['2']!), 'w');
    expect(sent['2']!.containsKey('solutionSan'), isFalse);
    expect(sent['2']!['needsReview'], true);
  });

  testWidgets('Stop keeps what landed and asks nothing more', (tester) async {
    final runner = FakeSideRunner(_answers, pauseAfter: 1);
    await _scanned(tester, runner);
    await _suggest(tester);
    expect(find.text('1 of 3'), findsOneWidget);

    await _tap(tester, const ValueKey('suggest-sides-stop'));
    runner.resume.complete();
    await _settle(tester, 4);

    expect(runner.cancelled, isTrue);
    expect(find.byKey(const ValueKey('proposal-p0')), findsOneWidget,
        reason: 'what landed before Stop is gone');
    expect(find.byKey(const ValueKey('proposal-p1')), findsNothing);
    expect(find.byKey(const ValueKey('proposal-p3')), findsNothing);
    expect(runner.askedIds, ['p0', 'p1', 'p3'],
        reason: 'the run was offered all three; Stop is what cut it short');
    expect(find.byKey(const ValueKey('suggest-sides-progress')), findsNothing);
  });

  testWidgets('a network engine is refused in words, and nothing is asked',
      (tester) async {
    final runner = FakeSideRunner(_answers, usable: false);
    await _scanned(tester, runner);
    await _suggest(tester);
    expect(runner.runs, isEmpty);
    expect(find.text(SideSuggestions.noLocalEngineMessage), findsOneWidget);
  });

  testWidgets('a proposal under a board fits a 360 x 640 phone',
      (tester) async {
    await _scanned(tester, FakeSideRunner(_answers),
        size: const Size(360, 640));
    await _suggest(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('proposal-p1')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
        find.byKey(const ValueKey('proposal-set-answer-p1')), findsOneWidget);
    // One board to a row: until this phase the grid split 360 dp into two
    // cells of 158 around a 150 px board, and on master its height was 0.
    expect(tester.getSize(find.byKey(const ValueKey('scan-card-p1'))).width,
        greaterThan(300));
  });
}
