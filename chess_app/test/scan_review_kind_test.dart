// The book's kind decides the order — phase 3f of docs/PLAN-SKENER-SLIKE.md.
//
// The owner, 23.9.2026: the trainer need not know whether a PDF's diagrams are
// set in a chess font or are pictures, and for a picture book the calibration
// comes before the choice of pages. So the scanner asks what kind of book it
// is the moment it is chosen. The server is a MockClient that records every
// request; the file picker is replaced by one that answers a file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/position_scanner/screens/scan_review_screen.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

/// Every piece on some board: a calibration that is complete.
const _complete = {
  'bookName': 'Book.pdf',
  'boards': [
    {
      'page': 12,
      'index': 1,
      'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
      'ignore': []
    },
  ],
  'absent': [],
};

class _Server {
  _Server({this.calibration, this.shared, this.kind, this.kindStatus = 200});

  /// The book as other users set it up; null when nobody has.
  final Map<String, dynamic>? shared;

  final Map<String, dynamic>? calibration;
  final String? kind;
  final int kindStatus;
  final List<String> trail = [];

  http.Client client() => MockClient((req) async {
        trail.add(
            '${req.method} ${req.url.path.endsWith('/shared') ? '/scans/calibrations/shared' : req.url.path.startsWith('/scans/calibrations/') ? '/scans/calibrations' : req.url.path}');
        final path = req.url.path;
        if (path.startsWith('/scans/calibrations/') &&
            path.endsWith('/shared')) {
          return shared == null
              ? http.Response(
                  jsonEncode(
                      {'error': 'none', 'code': 'no_shared_calibration'}),
                  404)
              : http.Response(jsonEncode(shared), 200);
        }
        if (path.startsWith('/scans/calibrations/')) {
          return calibration == null
              ? http.Response(
                  jsonEncode({'error': 'none', 'code': 'no_calibration'}), 404)
              : http.Response(jsonEncode(calibration), 200);
        }
        if (path == '/scans/kind') {
          return kindStatus == 200
              ? http.Response(jsonEncode({'pageCount': 300, 'kind': kind}), 200)
              : http.Response(jsonEncode({'error': 'down'}), kindStatus);
        }
        if (path == '/scans/images/browse') {
          return http.Response(
              jsonEncode({
                'needsCalibration': true,
                'pageCount': 300,
                'scannedFrom': 1,
                'scannedTo': 20,
                'boards': [
                  {'page': 12, 'index': 1, 'source': 'image', 'preview': _png}
                ],
              }),
              200);
        }
        return http.Response('unexpected ${req.method} $path', 500);
      });
}

Future<void> _settle(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

Future<void> _choose(WidgetTester tester, _Server server,
    {Size size = const Size(1280, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final path = await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('scan_review_kind_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/Book.pdf');
    await file.writeAsString('%PDF-1.4 ${server.hashCode}');
    return file.path;
  });
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: ScanReviewScreen(
      session: UserSession(
          token: 'tok',
          id: 1,
          email: 'a@example.test',
          name: 'A',
          role: 'korisnik',
          accountType: 'free'),
      api: ScannerApiService(authToken: 'tok', client: server.client()),
      pickDocument: () async => (path: path!, name: 'Book.pdf'),
    ),
  ));
  await tester.tap(find.text('Select PDF'));
  await _settle(tester, 30);
}

void main() {
  testWidgets(
      'a picture book goes to its calibration at once, before any page is asked',
      (tester) async {
    final server = _Server(kind: 'pictures');
    await _choose(tester, server);
    // Asked in this order — its own calibration, other users', then the
    // book itself; the calibration screen then reads its own.
    expect(server.trail.take(3), [
      'GET /scans/calibrations',
      'GET /scans/calibrations/shared',
      'POST /scans/kind'
    ]);
    expect(find.text('Teach the scanner this book'), findsOneWidget);
    // Back on the scanner: no page range for a picture book, and the way back.
    await tester.pageBack();
    await _settle(tester, 4);
    expect(find.byKey(const ValueKey('scan-range')), findsNothing);
    expect(find.byKey(const ValueKey('scan-picture-book')), findsOneWidget);
    expect(server.trail.where((t) => t == 'POST /scans'), isEmpty,
        reason: 'a picture book was scanned as a font book');
  });

  testWidgets(
      'a book already calibrated is not looked at again, and opens on its pages',
      (tester) async {
    final server = _Server(calibration: _complete, kind: 'font');
    await _choose(tester, server);
    expect(server.trail.where((t) => t == 'POST /scans/kind'), isEmpty);
    expect(find.text('Choose the pages to read'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('pages-update-calibration')), findsOneWidget);
  });

  testWidgets(
      'a book another user set up is known to be pictures without sending it',
      (tester) async {
    final server = _Server(shared: {
      'boards': _complete['boards'],
      'absent': [],
      'contributors': 1,
    }, kind: 'font');
    await _choose(tester, server);
    expect(server.trail.where((t) => t == 'POST /scans/kind'), isEmpty);
    expect(find.text('Teach the scanner this book'), findsOneWidget);
  });

  testWidgets('a font book is scanned by a page range, as before',
      (tester) async {
    final server = _Server(kind: 'font');
    await _choose(tester, server);
    expect(find.byKey(const ValueKey('scan-range')), findsOneWidget);
    expect(find.text('Teach the scanner this book'), findsNothing);
    expect(find.byKey(const ValueKey('scan-picture-book')), findsNothing);
  });

  testWidgets(
      'a book the server could not look at is scanned by a page range too',
      (tester) async {
    final server = _Server(kindStatus: 500);
    await _choose(tester, server);
    expect(find.byKey(const ValueKey('scan-range')), findsOneWidget);
    expect(find.text('Teach the scanner this book'), findsNothing);
  });

  testWidgets('at 360 dp the picture-book card fits', (tester) async {
    final server = _Server(kind: 'pictures');
    await _choose(tester, server, size: const Size(360, 740));
    await tester.pageBack();
    await _settle(tester, 4);
    expect(tester.takeException(), isNull);
    final card =
        tester.getRect(find.byKey(const ValueKey('scan-picture-book')));
    expect(card.right, lessThanOrEqualTo(360));
  });
}
