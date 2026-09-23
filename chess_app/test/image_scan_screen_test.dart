// The screens of the image path — phases 3c and 3d of
// docs/PLAN-SKENER-SLIKE.md.
//
// A book whose diagrams are pictures: the door from the font path, the boards
// the trainer finds in the book and sets up beside their pictures, guided by
// the table of what the scanner has not seen (phase 3e), and every board read shown
// beside its picture with its uncertain squares marked by shape (the owner is
// colourblind; a mark told only by colour is no mark for him). The server is a
// MockClient that records every request; the board editor is replaced by a
// picker that answers a placement, except in the case that measures the
// editor itself.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/position_scanner/screens/image_scan_screen.dart';
import 'package:chess_app/features/position_scanner/screens/scan_review_screen.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/position_scanner/services/side_proposal_runner.dart';
import 'package:chess_app/features/position_scanner/widgets/side_suggestions.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/fake_side_runner.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Map<String, dynamic> _found(int page, int index) =>
    {'page': page, 'index': index, 'source': 'image', 'preview': _png};

Map<String, dynamic> _read(int page, int index, String placement,
        {List<String> uncertain = const [], bool legal = true}) =>
    {
      'page': page,
      'index': index,
      'source': 'image',
      'placement': placement,
      'uncertain': uncertain,
      'legal': legal,
      'preview': _png,
    };

const _calibrated = {
  'bookName': 'Silman.pdf',
  'boards': [
    {'page': 40, 'index': 1, 'fen': '7k/8/8/3q4/8/8/8/1KQ5', 'ignore': []},
    {'page': 41, 'index': 1, 'fen': '8/3nk3/8/3Q1K2/8/2N5/8/5b2', 'ignore': []},
    {
      'page': 42,
      'index': 1,
      'fen': '5nk1/R5p1/p3p2p/2B1P2P/r4P2/1p4K1/6P1/8',
      'ignore': []
    },
  ],
};

/// The pages of the fake book that hold a picture diagram, one each. Page 22
/// and page 95 lie outside the pages read (40–44): the missing pieces are
/// usually elsewhere in the book.
const _bookPages = [22, 40, 41, 42, 43, 44, 95];

/// A fake server. [calibration] answers the GET; POST /scans/images without
/// a calibration field answers the book's boards on the pages asked for, and
/// [read] answers it with one; every request is kept in [sent].
class _Server {
  _Server(
      {this.calibration,
      this.shared,
      Map<String, dynamic>? read,
      this.readStatus = 200})
      : read = read ?? _defaultRead;

  final Map<String, dynamic>? calibration;

  /// The book as other users set it up (phase 3g); null when nobody has.
  final Map<String, dynamic>? shared;
  final Map<String, dynamic> read;
  final int readStatus;
  final List<http.Request> sent = [];

  static String? _field(http.Request req, String name) =>
      RegExp('name="$name"\r\n\r\n(.*?)\r\n--', dotAll: true)
          .firstMatch(req.body)
          ?.group(1);

  static http.Response _browse(http.Request req) {
    final from = int.parse(_field(req, 'fromPage')!);
    final to = int.parse(_field(req, 'toPage')!);
    final pages = [
      for (final p in _bookPages)
        if (p >= from && p <= to) p
    ];
    if (pages.isEmpty) {
      return http.Response(
          jsonEncode({'error': 'none', 'code': 'no_image_diagrams'}), 422);
    }
    return http.Response(
        jsonEncode({
          'needsCalibration': true,
          'pageCount': 120,
          'scannedFrom': from,
          'scannedTo': to,
          'boards': [for (final p in pages) _found(p, 1)],
        }),
        200);
  }

  static final _defaultRead = {
    'needsCalibration': false,
    'scannedFrom': 40,
    'scannedTo': 44,
    'positions': [
      _read(43, 1, '8/5k2/8/3Q4/8/2n5/5B2/6K1', uncertain: ['c3']),
      _read(44, 1, '8/8/8/8/8/8/8/8', legal: false),
    ],
    'calibration': [
      {..._read(40, 1, '7k/8/8/3q4/8/8/8/1KQ5'), 'calibration': true},
    ],
    'composed': <String>[],
  };

  http.Client client() => MockClient((req) async {
        sent.add(req);
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
          if (req.method == 'GET') {
            return calibration == null
                ? http.Response(
                    jsonEncode({'error': 'none', 'code': 'no_calibration'}),
                    404)
                : http.Response(jsonEncode(calibration), 200);
          }
          if (req.method == 'PUT') {
            return http.Response(jsonEncode({'saved': 3}), 200);
          }
          return http.Response('', 204);
        }
        if (path == '/scans/images/browse') return _browse(req);
        if (path == '/scans/images') {
          final withCalibration = req.body.contains('name="calibration"');
          // Browsing has its own route; a reading without a calibration
          // would be the old way of browsing, counted as a scan.
          if (!withCalibration) {
            return http.Response('browse through /scans/images/browse', 500);
          }
          return readStatus == 200
              ? http.Response(jsonEncode(read), 200)
              : http.Response(
                  jsonEncode({
                    'error': 'the board is not there',
                    'code': 'calibration_board_missing'
                  }),
                  readStatus);
        }
        if (path == '/scans/confirm') {
          return http.Response(jsonEncode({'saved': 1}), 201);
        }
        return http.Response('unexpected ${req.method} $path', 500);
      });

  List<String> get trail => [
        for (final r in sent)
          '${r.method} ${r.url.path}${r.url.path == '/scans/images/browse' ? ' pages ${_field(r, 'fromPage')}-${_field(r, 'toPage')}' : r.url.path == '/scans/images' ? (r.body.contains('name="calibration"') ? ' +calibration' : ' -calibration') : ''}'
      ];

  /// The calibration a reading sent, as `page:fen`.
  List<String> calibrationSent() {
    final req = sent.lastWhere((r) =>
        r.url.path == '/scans/images' && r.body.contains('name="calibration"'));
    return [
      for (final b in jsonDecode(_field(req, 'calibration')!) as List)
        '${b['page']}:${b['fen']}'
    ];
  }
}

// Every piece but the black queen; a black queen on d8, a dark square; and a
// board that shows nothing the first does not.
const _allButQueen = 'rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
const _blackQueen = '3qk3/8/8/8/8/8/8/4K3';
const _kingsOnly = '4k3/8/8/8/8/8/8/4K3';

/// A picker that answers [placements] in turn.
PositionPicker _answers(List<String> placements) {
  var next = 0;
  return (context, picture, initial) async => placements[next++];
}

/// Finds board 1 of [page] in the book browser and sets it up.
Future<void> _addBoard(WidgetTester tester, int page) async {
  await tester.ensureVisible(find.byKey(const ValueKey('calibration-find')));
  await tester.tap(find.byKey(const ValueKey('calibration-find')));
  await _settle(tester);
  final browsed = find.byKey(ValueKey('browse-$page-1'));
  if (browsed.evaluate().isEmpty) {
    await tester.enterText(find.byKey(const ValueKey('browse-jump')), '$page');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await _settle(tester);
  }
  expect(browsed, findsOneWidget, reason: 'board 1 of page $page not browsed');
  await tester.tap(browsed);
  await _settle(tester);
}

/// „Done — choose pages": enabled once the calibration may be read with.
FilledButton _readButton(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('calibration-done')));

/// Finishes the calibration and reads the pages offered (phase 3f: the pages
/// are chosen after the calibration).
Future<void> _doneAndRead(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('calibration-done')));
  await tester.tap(find.byKey(const ValueKey('calibration-done')));
  await _settle(tester, 2);
  await tester.tap(find.byKey(const ValueKey('pages-read')));
  await _settle(tester);
}

Future<String> _book() async {
  final dir = await Directory.systemTemp.createTemp('image_scan_screen_');
  final file = File('${dir.path}/Silman.pdf');
  await file.writeAsString('%PDF-1.4 a drawn book');
  addTearDown(() => dir.delete(recursive: true));
  return file.path;
}

/// Lets real I/O (the file's hash, the upload) finish, then draws.
Future<void> _settle(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

Future<void> _pump(WidgetTester tester, _Server server,
    {PositionPicker? pick,
    Size size = const Size(1280, 900),
    bool overAnotherScreen = false,
    bool readPages = true,
    bool withPages = true,
    SideProposalRunner? runner}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final path = await tester.runAsync(_book);
  // A new key per pump: pumping the same widget type again reuses its State,
  // and the second screen of a case would keep the first one's answer.
  final screen = ImageScanScreen(
      api: ScannerApiService(authToken: 'tok', client: server.client()),
      filePath: path!,
      fileName: 'Silman.pdf',
      fromPage: withPages ? 40 : null,
      toPage: withPages ? 44 : null,
      pickPosition:
          pick ?? (context, picture, initial) async => '8/8/8/8/8/8/8/K6k',
      proposalRunner: runner);
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    // As in the app, where the scanner is pushed over the screen that
    // opened it: a close too many then shows that screen, not nothing.
    initialRoute: overAnotherScreen ? '/scan' : '/',
    routes: {
      '/': (_) => overAnotherScreen
          ? const Scaffold(body: Text('the screen underneath'))
          : screen,
      '/scan': (_) => screen,
    },
  ));
  await _settle(tester);
  // A complete calibration opens on the choice of pages; the cases about the
  // boards read go on to read the pages offered.
  final read = find.byKey(const ValueKey('pages-read'));
  if (readPages && read.evaluate().isNotEmpty) {
    await tester.tap(read);
    await _settle(tester);
  }
}

void main() {
  group('the door', () {
    test('opens only on a refusal for no text that counted pictures', () {
      ScanOutcome refusal(String code, [Map<String, dynamic>? details]) =>
          ScanOutcome(error: 'no', code: code, details: details);
      expect(imageDoorFor(refusal('no_text', {'imageDiagrams': 38})), 38);
      expect(imageDoorFor(refusal('no_diagram_text', {'imageDiagrams': 4})), 4);
      expect(imageDoorFor(refusal('no_text')), 0);
      expect(imageDoorFor(refusal('unknown_font', {'imageDiagrams': 9})), 0);
      expect(imageDoorFor(refusal('range_too_large', {'imageDiagrams': 9})), 0);
    });

    testWidgets('says what it found and opens the image path', (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(
            body: ImageDiagramsDoor(
                count: 38, calibrated: false, onOpen: () => opened++)),
      ));
      expect(
          find.text('The diagrams in this book are pictures'), findsOneWidget);
      expect(find.textContaining('38'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('image-diagrams-open')));
      expect(opened, 1);
    });
  });

  // The owner, 23.9.2026: „mislim da me pita svaki put kada skeniram istu
  // knjigu da uradim kalibraciju". The calibration was remembered all along —
  // on the account, by the file's content — but the door said „set up three
  // of them by hand" every time. It now asks first, and says which.
  group('the door knows a book it has seen', () {
    Future<void> door(WidgetTester tester, {required bool calibrated}) =>
        tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
          home: Scaffold(
              body: ImageDiagramsDoor(
                  count: 12, calibrated: calibrated, onOpen: () {})),
        ));

    testWidgets('a calibrated book is not asked for three boards again',
        (tester) async {
      await door(tester, calibrated: true);
      expect(find.textContaining('set up a few'), findsNothing);
      expect(find.textContaining('set up this book before'), findsOneWidget);
    });

    testWidgets('a new book is told what setting up means', (tester) async {
      await door(tester, calibrated: false);
      expect(find.textContaining('set up a few'), findsOneWidget);
      expect(find.textContaining('set up this book before'), findsNothing);
    });

    test('the check goes by content: a renamed copy is the same book',
        () async {
      final dir = await Directory.systemTemp.createTemp('book_calibrated_');
      addTearDown(() => dir.delete(recursive: true));
      final original = File('${dir.path}/Silman.pdf');
      await original.writeAsString('%PDF-1.4 a drawn book');
      final renamed = await original.copy('${dir.path}/renamed copy.pdf');
      final other = File('${dir.path}/Other.pdf');
      await other.writeAsString('%PDF-1.4 another book');
      final known = await bookHashOf(original.path);

      final asked = <String>[];
      final api = ScannerApiService(
          authToken: 'tok',
          client: MockClient((req) async {
            asked.add(req.url.path);
            return req.url.pathSegments.last == known
                ? http.Response(jsonEncode(_calibrated), 200)
                : http.Response(
                    jsonEncode({'error': 'none', 'code': 'no_calibration'}),
                    404);
          }));

      expect(await bookIsCalibrated(api, renamed.path), isTrue);
      expect(await bookIsCalibrated(api, other.path), isFalse);
      expect(asked, [
        '/scans/calibrations/$known',
        '/scans/calibrations/${await bookHashOf(other.path)}'
      ]);
    });

    test('a server that cannot be asked is not a calibrated book', () async {
      final dir = await Directory.systemTemp.createTemp('book_calibrated_');
      addTearDown(() => dir.delete(recursive: true));
      final book = File('${dir.path}/b.pdf');
      await book.writeAsString('%PDF-1.4');
      final api = ScannerApiService(
          authToken: 'tok',
          client: MockClient((req) async => http.Response('oops', 500)));
      expect(await bookIsCalibrated(api, book.path), isFalse);
    });
  });

  group('3c — calibrating', () {
    // The owner, 23.9.2026: the calibration first, then the pages. A complete
    // calibration is skipped, and the trainer chooses the pages — it used to
    // go straight to reading the pages given before it.
    testWidgets(
        'a complete calibration is skipped: the pages are chosen, then read',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server, readPages: false, withPages: false);
      expect(
          server.trail,
          [
            'GET /scans/calibrations/${server.sent.first.url.pathSegments.last}',
          ],
          reason: 'read before any page was chosen');
      expect(find.text('Choose the pages to read'), findsOneWidget);
      expect(find.byKey(const ValueKey('calibration-boards')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('pages-from')), '50');
      await tester.enterText(find.byKey(const ValueKey('pages-to')), '61');
      await tester.tap(find.byKey(const ValueKey('pages-read')));
      await _settle(tester);
      final read = server.sent.last;
      expect(server.trail.last, 'POST /scans/images +calibration');
      expect(read.body, contains('name="fromPage"\r\n\r\n50'));
      expect(read.body, contains('name="toPage"\r\n\r\n61'));
      final field =
          RegExp(r'name="calibration"\r\n\r\n(.*?)\r\n--', dotAll: true)
              .firstMatch(read.body)!;
      expect((jsonDecode(field.group(1)!) as List).length, 3);
      expect(find.byKey(const ValueKey('image-scan-boards')), findsOneWidget);
    });

    testWidgets('pages that cannot be read are said, and nothing is sent',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server, readPages: false);
      final asked = server.sent.length;
      for (final (from, to, words) in const [
        ('60', '50', 'before the first'),
        ('1', '41', 'At most 40 pages'),
        ('', '10', 'Give the first'),
      ]) {
        await tester.enterText(find.byKey(const ValueKey('pages-from')), from);
        await tester.enterText(find.byKey(const ValueKey('pages-to')), to);
        await tester.tap(find.byKey(const ValueKey('pages-read')));
        await _settle(tester, 2);
        expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('pages-problem')))
                .data,
            contains(words),
            reason: '$from–$to');
      }
      expect(server.sent.length, asked, reason: 'a request went out');
      // Forty exactly is allowed.
      await tester.enterText(find.byKey(const ValueKey('pages-from')), '1');
      await tester.enterText(find.byKey(const ValueKey('pages-to')), '40');
      await tester.tap(find.byKey(const ValueKey('pages-read')));
      await _settle(tester);
      expect(server.trail.last, 'POST /scans/images +calibration');
    });

    testWidgets(
        'the pages offer to update the calibration, and other pages come back to them',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server);
      // From the boards read, to other pages of the same book.
      await tester.tap(find.byKey(const ValueKey('image-scan-other-pages')));
      await _settle(tester, 2);
      expect(find.text('Choose the pages to read'), findsOneWidget);
      // And from the pages, to the calibration with its boards.
      await tester.tap(find.byKey(const ValueKey('pages-update-calibration')));
      await _settle(tester, 6);
      for (final page in [40, 41, 42]) {
        expect(find.byKey(ValueKey('calibrate-$page-1')), findsOneWidget);
      }
      expect(server.sent.where((r) => r.method == 'DELETE'), isEmpty);
    });

    // Phase 3e (the owner, 23.9.2026): the three busiest boards of the pages
    // being read were usually neighbours showing the same pieces, while the
    // missing ones were elsewhere. The trainer now finds the boards himself,
    // anywhere in the book, and a table says what is still missing. The
    // cases of the three fixed boards are replaced by these.
    testWidgets('a new book opens on an empty table and uploads nothing yet',
        (tester) async {
      final server = _Server();
      await _pump(tester, server);
      // Phase 3g added a question — whether another user set the book up —
      // but still no upload before the trainer asks to browse.
      expect(server.trail.where((t) => t.startsWith('POST')), isEmpty,
          reason: 'the book was sent before the trainer asked to browse it');
      expect(
          find.byKey(const ValueKey('calibration-coverage')), findsOneWidget);
      expect(_readButton(tester).onPressed, isNull);
      // Every piece is missing on an empty table: twelve „No … in this book"
      // buttons would say nothing.
      expect(find.byKey(const ValueKey('calibration-absent-q')), findsNothing);
      // Nothing is shown yet: every piece is marked as not shown.
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('coverage-q-dark')),
              matching: find.byIcon(Icons.radio_button_unchecked)),
          findsOneWidget);
    });

    testWidgets(
        'the browser opens near the pages being read and asks for one window',
        (tester) async {
      final server = _Server();
      await _pump(tester, server);
      await tester.tap(find.byKey(const ValueKey('calibration-find')));
      await _settle(tester);
      expect(server.trail.last, 'POST /scans/images/browse pages 21-40');
      expect(find.text('Pages 21–40 of 120'), findsOneWidget);
      expect(find.byKey(const ValueKey('browse-22-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('browse-40-1')), findsOneWidget);
      // Turning on, and back: back is not uploaded again.
      await tester.tap(find.byKey(const ValueKey('browse-next')));
      await _settle(tester);
      expect(server.trail.last, 'POST /scans/images/browse pages 41-60');
      expect(find.byKey(const ValueKey('browse-42-1')), findsOneWidget);
      final asked = server.sent.length;
      await tester.tap(find.byKey(const ValueKey('browse-previous')));
      await _settle(tester);
      expect(server.sent.length, asked,
          reason: 'a window seen was fetched again');
      // A page with no pictures is an empty window, not an error.
      await tester.enterText(find.byKey(const ValueKey('browse-jump')), '70');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await _settle(tester);
      expect(server.trail.last, 'POST /scans/images/browse pages 61-80');
      expect(find.text('No diagram pictures on these pages.'), findsOneWidget);
    });

    testWidgets(
        'reading waits until every piece is shown, and reads with boards from anywhere',
        (tester) async {
      final server = _Server();
      await _pump(tester, server,
          pick: _answers([_allButQueen, _kingsOnly, _blackQueen]));

      await _addBoard(tester, 42);
      expect(find.byKey(const ValueKey('calibrate-42-1')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('coverage-R-dark')),
              matching: find.byIcon(Icons.check)),
          findsOneWidget);
      expect(_readButton(tester).onPressed, isNull,
          reason: 'read with the black queen never shown');
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('calibration-status')))
              .data,
          contains('a black queen, on any square'));

      // A board that shows nothing new says so.
      await _addBoard(tester, 41);
      expect(
          find.text('Shows nothing the other boards do not.'), findsOneWidget);
      expect(_readButton(tester).onPressed, isNull);

      // The black queen, from page 95 — far outside the pages read.
      await _addBoard(tester, 95);
      expect(_readButton(tester).onPressed, isNotNull,
          reason: 'every piece is shown, and reading still waits');
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('coverage-q-light')),
              matching: find.text('≈')),
          findsOneWidget,
          reason: 'the queen on a light square is guessed');

      await _doneAndRead(tester);
      expect(server.calibrationSent(), [
        '42:$_allButQueen',
        '41:$_kingsOnly',
        '95:$_blackQueen',
      ]);
      final put = server.sent.lastWhere((r) => r.method == 'PUT');
      expect(
          ((jsonDecode(put.body) as Map)['boards'] as List)
              .map((b) => '${b['page']}'),
          ['42', '41', '95']);
    });

    // Phase 3g (the owner, 23.9.2026): a calibration is no private thing. A
    // book another user set up opens with their boards, each to be checked
    // here against its picture before it counts or is remembered.
    testWidgets(
        'another user\'s boards are offered, and count only once checked',
        (tester) async {
      final server = _Server(shared: {
        'boards': [
          {
            'page': 42,
            'index': 1,
            'fen': _allButQueen,
            'ignore': [],
            'votes': 2
          },
          {
            'page': 95,
            'index': 1,
            'fen': _blackQueen,
            'ignore': [],
            'votes': 1
          },
        ],
        'absent': <String>[],
        'contributors': 2,
      });
      await _pump(tester, server);
      await _settle(tester, 6);
      expect(
          find.byKey(const ValueKey('calibrate-shared-42-1')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('calibrate-shared-95-1')), findsOneWidget);
      expect(find.textContaining('Set up by another user'), findsNWidgets(2));
      // Not counted yet: the grid still has nothing, and nothing is kept.
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('coverage-R-dark')),
              matching: find.byIcon(Icons.radio_button_unchecked)),
          findsOneWidget);
      expect(server.sent.where((r) => r.method == 'PUT'), isEmpty);
      expect(_readButton(tester).onPressed, isNull);

      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-confirm-42-1')));
      await tester.tap(find.byKey(const ValueKey('calibrate-confirm-42-1')));
      await _settle(tester, 4);
      Map put() =>
          jsonDecode(server.sent.lastWhere((r) => r.method == 'PUT').body)
              as Map;
      expect((put()['boards'] as List).map((b) => '${b['page']}'), ['42'],
          reason: 'an unchecked board was remembered');
      // Everything the checked board lacks said absent: only the unchecked
      // board can keep the calibration from being done now.
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibration-absent-q')));
      await tester.tap(find.byKey(const ValueKey('calibration-absent-q')));
      await _settle(tester, 4);
      expect(_readButton(tester).onPressed, isNull,
          reason: 'done with a board still unchecked');

      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-confirm-95-1')));
      await tester.tap(find.byKey(const ValueKey('calibrate-confirm-95-1')));
      await _settle(tester, 4);
      expect(
          (put()['boards'] as List).map((b) => '${b['page']}'), ['42', '95']);
      expect(_readButton(tester).onPressed, isNotNull);
    });

    testWidgets('another user\'s board set up again here is checked by it',
        (tester) async {
      final server = _Server(shared: {
        'boards': [
          {'page': 42, 'index': 1, 'fen': _kingsOnly, 'ignore': [], 'votes': 1},
        ],
        'absent': <String>[],
        'contributors': 1,
      });
      await _pump(tester, server, pick: _answers([_allButQueen]));
      await _settle(tester, 6);
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-setup-42-1')));
      await tester.tap(find.byKey(const ValueKey('calibrate-setup-42-1')));
      await _settle(tester, 4);
      expect(find.byKey(const ValueKey('calibrate-shared-42-1')), findsNothing);
      final put = server.sent.lastWhere((r) => r.method == 'PUT');
      expect(
          ((jsonDecode(put.body) as Map)['boards'] as List)
              .map((b) => '${b['page']}:${b['fen']}'),
          ['42:$_allButQueen'],
          reason: 'what was set up here is kept, not what was offered');
    });

    testWidgets(
        'a calibration of ones own is offered only the boards that add to it',
        (tester) async {
      final server = _Server(
        calibration: {
          'bookName': 'Silman.pdf',
          'boards': [
            {'page': 42, 'index': 1, 'fen': _allButQueen, 'ignore': []},
          ],
          'absent': <String>[],
        },
        shared: {
          'boards': [
            {
              'page': 41,
              'index': 1,
              'fen': _kingsOnly,
              'ignore': [],
              'votes': 3
            },
            {
              'page': 95,
              'index': 1,
              'fen': _blackQueen,
              'ignore': [],
              'votes': 1
            },
          ],
          'absent': <String>[],
          'contributors': 3,
        },
      );
      await _pump(tester, server);
      await _settle(tester, 6);
      expect(find.byKey(const ValueKey('calibrate-42-1')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('calibrate-shared-95-1')), findsOneWidget,
          reason: 'the black queen this calibration lacks was not offered');
      expect(find.byKey(const ValueKey('calibrate-41-1')), findsNothing,
          reason: 'a board that adds nothing was offered');
    });

    testWidgets('a board removed leaves the calibration and the table',
        (tester) async {
      final server = _Server();
      await _pump(tester, server, pick: _answers([_allButQueen, _blackQueen]));
      await _addBoard(tester, 42);
      await _addBoard(tester, 95);
      expect(_readButton(tester).onPressed, isNotNull);
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-remove-95-1')));
      await tester.tap(find.byKey(const ValueKey('calibrate-remove-95-1')));
      await tester.pump();
      expect(find.byKey(const ValueKey('calibrate-95-1')), findsNothing);
      expect(_readButton(tester).onPressed, isNull,
          reason: 'the black queen left with its board');
    });

    testWidgets('a piece the book never draws can be left out, by name',
        (tester) async {
      final server = _Server();
      await _pump(tester, server, pick: _answers([_allButQueen]));
      await _addBoard(tester, 42);
      expect(_readButton(tester).onPressed, isNull);
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibration-absent-q')));
      expect(find.text('No black queen in this book'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('calibration-absent-q')));
      await tester.pump();
      expect(_readButton(tester).onPressed, isNotNull);
    });

    // The owner, 23.9.2026: a book of rook endings has no queens, bishops or
    // knights at all — six pieces missing, not one. The buttons first
    // appeared only for four or fewer, so such a book could never be read.
    testWidgets('a rook-endings book can say six pieces are not in it',
        (tester) async {
      final server = _Server();
      await _pump(tester, server, pick: _answers(['4k3/r6p/8/8/8/8/P6R/4K3']));
      await _addBoard(tester, 42);
      expect(_readButton(tester).onPressed, isNull);
      for (final p in ['N', 'B', 'Q', 'n', 'b', 'q']) {
        final chip = find.byKey(ValueKey('calibration-absent-$p'));
        expect(chip, findsOneWidget, reason: 'no way to say there is no $p');
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pump();
      }
      expect(_readButton(tester).onPressed, isNotNull,
          reason: 'kings, rooks and pawns shown, the rest said absent');
      await _doneAndRead(tester);
      expect(server.calibrationSent(), ['42:4k3/r6p/8/8/8/8/P6R/4K3']);
    });

    testWidgets('a board already in the calibration cannot be chosen again',
        (tester) async {
      final server = _Server();
      await _pump(tester, server, pick: _answers([_allButQueen, _blackQueen]));
      await _addBoard(tester, 42);
      await tester.tap(find.byKey(const ValueKey('calibration-find')));
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('browse-jump')), '42');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('browse-42-1')));
      await _settle(tester);
      expect(find.text('Choose a board'), findsOneWidget,
          reason: 'the browser closed on a board already chosen');
    });

    // The owner's live pass of 22.9.2026: "Generate and Set Position" threw
    // him back to the scanner, the board unset. The editor closes itself
    // after `onPositionSet`, and the scanner's callback closed it too — so the
    // second close took the calibration screen with it. This case runs the
    // real editor, through the scanner's own `pickPositionWithEditor`.
    testWidgets('the real editor hands its board back and leaves the screen',
        (tester) async {
      final server = _Server();
      await _pump(tester, server,
          overAnotherScreen: true,
          pick: (context, picture, initial) =>
              pickPositionWithEditor(context, picture, '4k3/8/8/8/8/8/8/4K3'));
      await _addBoard(tester, 42);
      expect(find.text('Generate and Set Position'), findsOneWidget);
      await tester.tap(find.text('Generate and Set Position'));
      await _settle(tester, 4);

      expect(find.text('Generate and Set Position'), findsNothing,
          reason: 'the editor stayed open');
      expect(find.text('the screen underneath'), findsNothing,
          reason: 'the calibration screen was closed with the editor');
      expect(find.byKey(const ValueKey('calibration-boards')), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget,
          reason: 'the board set up in the editor did not arrive');
    });

    // The owner, 23.9.2026, looking at the editor over a book's picture: „kako
    // da znam ko je na potezu?" He does not need to — the scanner keeps only
    // where the pieces stand — so the editor does not ask. And a board that is
    // a position only with Black to move is still a board: the rook on e1
    // gives check to the king on e8, which with White to move would be
    // refused, with no side to change it by.
    testWidgets('the editor asks only for the pieces, and takes either side',
        (tester) async {
      final server = _Server();
      await _pump(tester, server,
          overAnotherScreen: true,
          pick: (context, picture, initial) => pickPositionWithEditor(
              context, picture, '4k3/8/8/8/8/8/8/4R1K1'));
      await _addBoard(tester, 42);

      expect(find.text('To move:'), findsNothing,
          reason: 'the editor asks who is to move, which the scanner drops');
      expect(find.textContaining('O-O'), findsNothing,
          reason: 'castling is asked for and then dropped');
      expect(
          find.textContaining('Only where the pieces stand'), findsOneWidget);
      expect(find.byKey(const ValueKey('builder-illegal')), findsNothing,
          reason: 'a position legal with Black to move was refused');

      await tester.tap(find.text('Generate and Set Position'));
      await _settle(tester, 4);
      expect(find.text('Edit'), findsOneWidget,
          reason: 'the board did not arrive');
    });

    // The owner, 23.9.2026: a calibration set up and not yet read was lost
    // when the reading was refused — it was remembered only after a reading
    // came back. It is now remembered as it is set up, and a reading that
    // fails goes back to its table, not to an empty one. (Until then this
    // case asserted the opposite: that nothing was remembered.)
    testWidgets(
        'a reading that fails keeps the boards, and goes back to their table',
        (tester) async {
      final server = _Server(readStatus: 422);
      await _pump(tester, server, pick: _answers([_allButQueen, _blackQueen]));
      await _addBoard(tester, 42);
      await _addBoard(tester, 95);
      await _doneAndRead(tester);
      expect(find.byKey(const ValueKey('image-scan-failure')), findsOneWidget);
      final put = server.sent.lastWhere((r) => r.method == 'PUT');
      expect(
          ((jsonDecode(put.body) as Map)['boards'] as List)
              .map((b) => '${b['page']}'),
          ['42', '95'],
          reason: 'the boards set up were not remembered before reading');
      await tester
          .tap(find.byKey(const ValueKey('image-scan-failed-recalibrate')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('calibrate-42-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('calibrate-95-1')), findsOneWidget);
      expect(server.sent.where((r) => r.method == 'DELETE'), isEmpty);
    });

    testWidgets(
        'every board set up is remembered at once, with the pieces said absent',
        (tester) async {
      final server = _Server();
      await _pump(tester, server, pick: _answers([_allButQueen]));
      await _addBoard(tester, 42);
      Map put() =>
          jsonDecode(server.sent.lastWhere((r) => r.method == 'PUT').body)
              as Map;
      expect((put()['boards'] as List).map((b) => '${b['page']}:${b['fen']}'),
          ['42:$_allButQueen']);
      expect(put()['absent'], isEmpty);
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibration-absent-q')));
      await tester.tap(find.byKey(const ValueKey('calibration-absent-q')));
      await _settle(tester, 4);
      expect(put()['absent'], ['q']);
      // Removing the last board forgets the book's calibration.
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-remove-42-1')));
      await tester.tap(find.byKey(const ValueKey('calibrate-remove-42-1')));
      await _settle(tester, 4);
      expect(server.sent.last.method, 'DELETE');
    });

    testWidgets(
        'a calibration left half-way comes back to its table, not to a reading',
        (tester) async {
      final server = _Server(calibration: {
        'bookName': 'Silman.pdf',
        'boards': [
          {'page': 42, 'index': 1, 'fen': _allButQueen, 'ignore': []},
        ],
        'absent': <String>[],
      });
      await _pump(tester, server);
      expect(server.trail.where((t) => t.contains('+calibration')), isEmpty,
          reason: 'read with the black queen never shown');
      expect(find.byKey(const ValueKey('calibrate-42-1')), findsOneWidget);
      expect(_readButton(tester).onPressed, isNull);
    });

    testWidgets(
        'a rook-endings book remembered with its absent pieces is read straight away',
        (tester) async {
      final server = _Server(calibration: {
        'bookName': 'Rooks.pdf',
        'boards': [
          {
            'page': 42,
            'index': 1,
            'fen': '4k3/r6p/8/8/8/8/P6R/4K3',
            'ignore': []
          },
        ],
        'absent': ['N', 'B', 'Q', 'n', 'b', 'q'],
      });
      await _pump(tester, server);
      expect(server.trail.last, 'POST /scans/images +calibration');
      expect(find.byKey(const ValueKey('image-scan-boards')), findsOneWidget);
    });

    testWidgets(
        'improving a remembered calibration brings its boards back, pictures and all',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server);
      await tester.tap(find.byKey(const ValueKey('image-scan-recalibrate')));
      await _settle(tester, 6);
      for (final page in [40, 41, 42]) {
        expect(find.byKey(ValueKey('calibrate-$page-1')), findsOneWidget);
        // Its picture arrived: the button that needs it is enabled.
        final setUp = tester.widget<FilledButton>(
            find.byKey(ValueKey('calibrate-setup-$page-1')));
        expect(setUp.onPressed, isNotNull, reason: 'no picture for page $page');
      }
      // Page 40 came with the reading; 41 and 42 were fetched, once.
      expect(server.trail.where((t) => t.contains('pages')).toList(),
          ['POST /scans/images/browse pages 41-60']);
      expect(server.sent.where((r) => r.method == 'DELETE'), isEmpty,
          reason: 'improving must not forget the calibration it improves');
    });

    testWidgets(
        'at 360 dp the table and the cards fit, and pictures are square',
        (tester) async {
      final server = _Server();
      await _pump(tester, server,
          size: const Size(360, 740),
          pick: _answers([_allButQueen, _kingsOnly]));
      await _addBoard(tester, 42);
      await _addBoard(tester, 41);
      expect(tester.takeException(), isNull);
      final table =
          tester.getRect(find.byKey(const ValueKey('calibration-coverage')));
      expect(table.right, lessThanOrEqualTo(360));
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-picture-41-1')));
      final picture =
          tester.getRect(find.byKey(const ValueKey('calibrate-picture-41-1')));
      expect(picture.width, picture.height);
      expect(picture.width, greaterThan(100));
      final adds = find.byKey(const ValueKey('calibrate-adds-41-1'));
      expect(tester.getRect(adds).right, lessThanOrEqualTo(360));
    });

    for (final size in const [Size(360, 740), Size(1280, 800)]) {
      testWidgets(
          'the editor shows the book\'s picture beside the board at ${size.width.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
          home: Scaffold(
            body: AnalysisBoardSetupDialog(
              initialFen: '8/8/8/8/8/8/8/8 w - - 0 1',
              referencePicture: Uint8List.fromList(base64Decode(_png)),
              onPositionSet: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final picture = tester
            .getRect(find.byKey(const ValueKey('setup-reference-picture')));
        final a8 = tester.getRect(find.byKey(const ValueKey('square-0-0')));
        final h1 = tester.getRect(find.byKey(const ValueKey('square-7-7')));
        final board = a8.expandToInclude(h1);
        final screen = Offset.zero & size;
        expect(picture.width, picture.height,
            reason: 'the picture is not square');
        expect(picture.width, greaterThanOrEqualTo(60),
            reason: 'too small to copy from');
        expect(
            screen.contains(picture.topLeft) &&
                screen.contains(picture.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: 'the picture is off the screen: $picture');
        expect(picture.overlaps(board), isFalse,
            reason: 'the picture covers the board');
        if (size.width >= 1000) {
          expect(picture.left, greaterThanOrEqualTo(board.right),
              reason: 'not beside the board');
        } else {
          expect(picture.bottom, lessThanOrEqualTo(board.top),
              reason: 'not above the board');
        }
      });
    }
  });

  group('3d — confirming', () {
    testWidgets(
        'an uncertain square is outlined and marked on the square itself',
        (tester) async {
      await _pump(tester, _Server(calibration: _calibrated));
      final mark = find.byKey(const ValueKey('uncertain-43-1-c3'));
      expect(mark, findsOneWidget);
      expect(
          find.descendant(of: mark, matching: find.text('?')), findsOneWidget);
      final board =
          tester.getRect(find.byKey(const ValueKey('read-board-43-1')));
      final cell = board.width / 8;
      final at = tester.getRect(mark);
      expect(at.left, closeTo(board.left + 2 * cell, 0.5)); // file c
      expect(at.top, closeTo(board.top + 5 * cell, 0.5)); // rank 3
      expect(at.width, closeTo(cell, 0.5));
      // Nowhere else on that board.
      expect(
          find.byWidgetPredicate((w) =>
              w.key is ValueKey &&
              '${(w.key as ValueKey).value}'.startsWith('uncertain-43-1-')),
          findsOneWidget);
    });

    testWidgets(
        'a board that is not a position has no tick box until it is fixed',
        (tester) async {
      await _pump(tester, _Server(calibration: _calibrated),
          pick: (context, picture, initial) async => '8/8/8/8/8/8/8/K6k');
      expect(find.byKey(const ValueKey('read-accept-44-1')), findsNothing);
      expect(find.byKey(const ValueKey('read-accept-43-1')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('read-board-44-1')));
      await tester.tap(find.byKey(const ValueKey('read-board-44-1')));
      await _settle(tester, 2);
      expect(find.byKey(const ValueKey('read-accept-44-1')), findsOneWidget);
    });

    testWidgets(
        'saving sends the accepted positions, flagged where the side was never set',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server);
      // Set Black to move on page 43; leave the calibration board on page 40 alone.
      await tester.ensureVisible(find.text('White to move').at(1));
      await tester.tap(find.text('White to move').at(1));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('image-scan-save')));
      await _settle(tester);
      final confirm =
          server.sent.lastWhere((r) => r.url.path == '/scans/confirm');
      final positions =
          ((jsonDecode(confirm.body) as Map)['positions'] as List).cast<Map>();
      expect(
          positions.map((p) => '${p['page']} ${p['fen']} ${p['needsReview']}'),
          [
            '40 7k/8/8/3q4/8/8/8/1KQ5 w - - 0 1 true',
            '43 8/5k2/8/3Q4/8/2n5/5B2/6K1 b - - 0 1 false',
          ],
          reason: 'page 44 is not a position and must not be sent');
    });

    // The owner, 23.9.2026: „zar ne mogu pozicije koje sam ispravio da služe
    // kao kalibracija?" A board set up by hand that shows what the reader had
    // to guess joins the book's calibration when it is saved.
    testWidgets('a board set up by hand joins the calibration on save',
        (tester) async {
      final read = Map<String, dynamic>.from(_Server._defaultRead)
        ..['composed'] = ['R/dark'];
      final server = _Server(calibration: _calibrated, read: read);
      await _pump(tester, server,
          // A white rook on a1, a dark square: the class that was guessed.
          pick: (context, picture, initial) async => '4k3/8/8/8/8/8/8/R3K3');
      await tester.ensureVisible(find.byKey(const ValueKey('read-board-43-1')));
      await tester.tap(find.byKey(const ValueKey('read-board-43-1')));
      await _settle(tester, 2);
      await tester.tap(find.byKey(const ValueKey('image-scan-save')));
      await _settle(tester);

      final puts = server.sent.where((r) => r.method == 'PUT').toList();
      expect(puts, hasLength(1), reason: 'the calibration was not updated');
      final boards =
          ((jsonDecode(puts.single.body) as Map)['boards'] as List).cast<Map>();
      expect(
          boards.map((b) => '${b['page']}:${b['fen']}'),
          [
            '40:7k/8/8/3q4/8/8/8/1KQ5',
            '41:8/3nk3/8/3Q1K2/8/2N5/8/5b2',
            '42:5nk1/R5p1/p3p2p/2B1P2P/r4P2/1p4K1/6P1/8',
            '43:4k3/8/8/8/8/8/8/R3K3',
          ],
          reason: 'the three it had, then the board set up by hand');
      expect(find.textContaining('calibration now includes page 43'),
          findsOneWidget);
    });

    // The owner, 23.9.2026: the counters „23 to check" and „13 not a
    // position" looked like filters and did nothing, and saving only what he
    // had confirmed meant unticking the rest one by one.
    group('filters and selecting in bulk', () {
      Set<String> shown(WidgetTester tester) => {
            for (final e in tester.widgetList(find.byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('read-board-'))))
              (e.key as ValueKey<String>).value.replaceFirst('read-board-', '')
          };

      Future<void> show(WidgetTester tester, String which) async {
        await tester
            .ensureVisible(find.byKey(ValueKey('image-scan-show-$which')));
        await tester.tap(find.byKey(ValueKey('image-scan-show-$which')));
        await tester.pump();
      }

      Future<List<String>> saved(WidgetTester tester, _Server server) async {
        await tester.tap(find.byKey(const ValueKey('image-scan-save')));
        await _settle(tester);
        final confirm =
            server.sent.lastWhere((r) => r.url.path == '/scans/confirm');
        return [
          for (final p
              in ((jsonDecode(confirm.body) as Map)['positions'] as List)
                  .cast<Map>())
            '${p['page']}'
        ];
      }

      testWidgets('each filter shows its own boards, and only those',
          (tester) async {
        await _pump(tester, _Server(calibration: _calibrated),
            pick: (context, picture, initial) async => '4k3/8/8/8/8/8/8/R3K3');
        expect(shown(tester), {'40-1', '43-1', '44-1'});
        await show(tester, 'to-check');
        expect(shown(tester), {'43-1'});
        await show(tester, 'not-position');
        expect(shown(tester), {'44-1'});
        await show(tester, 'set-up');
        expect(shown(tester), isEmpty);

        await show(tester, 'all');
        await tester
            .ensureVisible(find.byKey(const ValueKey('read-board-43-1')));
        await tester.tap(find.byKey(const ValueKey('read-board-43-1')));
        await _settle(tester, 2);
        await show(tester, 'set-up');
        expect(shown(tester), {'43-1'});
      });

      testWidgets('„Only the ones I set up" saves exactly those',
          (tester) async {
        final server = _Server(calibration: _calibrated);
        await _pump(tester, server,
            pick: (context, picture, initial) async => '4k3/8/8/8/8/8/8/R3K3');
        await tester
            .ensureVisible(find.byKey(const ValueKey('read-board-43-1')));
        await tester.tap(find.byKey(const ValueKey('read-board-43-1')));
        await _settle(tester, 2);
        await tester
            .tap(find.byKey(const ValueKey('image-scan-select-set-up')));
        await tester.pump();
        expect(await saved(tester, server), ['43']);
      });

      testWidgets('„Unselect shown" touches only what the filter shows',
          (tester) async {
        final server = _Server(calibration: _calibrated);
        await _pump(tester, server);
        await show(tester, 'to-check');
        await tester
            .tap(find.byKey(const ValueKey('image-scan-unselect-shown')));
        await tester.pump();
        await show(tester, 'all');
        expect(await saved(tester, server), ['40'],
            reason: 'page 43 was shown and unselected; 40 was not shown');
      });
    });

    testWidgets('a board only ticked does not touch the calibration',
        (tester) async {
      final read = Map<String, dynamic>.from(_Server._defaultRead)
        ..['composed'] = ['R/dark'];
      final server = _Server(calibration: _calibrated, read: read);
      await _pump(tester, server);
      await tester.tap(find.byKey(const ValueKey('image-scan-save')));
      await _settle(tester);
      expect(server.sent.where((r) => r.method == 'PUT'), isEmpty);
    });

    testWidgets(
        'the note about a guessed piece appears only when a class was composed',
        (tester) async {
      await _pump(tester, _Server(calibration: _calibrated));
      expect(find.byKey(const ValueKey('image-scan-composed')), findsNothing);
      final read = Map<String, dynamic>.from(_Server._defaultRead)
        ..['composed'] = ['R/light'];
      await _pump(tester, _Server(calibration: _calibrated, read: read));
      expect(find.byKey(const ValueKey('image-scan-composed')), findsOneWidget);
      expect(
          find.textContaining('white rook on a light square'), findsOneWidget);
    });

    testWidgets('a piece never shown at all is named above the boards',
        (tester) async {
      await _pump(tester, _Server(calibration: _calibrated));
      expect(find.byKey(const ValueKey('image-scan-unseen')), findsNothing);
      final read = Map<String, dynamic>.from(_Server._defaultRead)
        ..['unseen'] = ['q', 'N'];
      await _pump(tester, _Server(calibration: _calibrated, read: read));
      expect(find.byKey(const ValueKey('image-scan-unseen')), findsOneWidget);
      expect(find.textContaining('a black queen, a white knight at all'),
          findsOneWidget);
    });

    testWidgets('the note about a guessed piece fits a 360 dp phone',
        (tester) async {
      // Found by mutation: with the note always shown, the 360 case below
      // overflowed — the note had only ever been drawn at 1280.
      final read = Map<String, dynamic>.from(_Server._defaultRead)
        ..['composed'] = ['R/light', 'k/dark'];
      await _pump(tester, _Server(calibration: _calibrated, read: read),
          size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      final note =
          tester.getRect(find.byKey(const ValueKey('image-scan-composed')));
      expect(note.right, lessThanOrEqualTo(360));
    });

    testWidgets(
        'at 360 dp nothing overflows and the picture and the board are square and equal',
        (tester) async {
      await _pump(tester, _Server(calibration: _calibrated),
          size: const Size(360, 740));
      expect(tester.takeException(), isNull);
      // Scrolled into view first: the list builds only what is on screen, so
      // a board below the fold is not there to measure (found by mutation —
      // a note above the boards pushed this one down and the case failed for
      // the wrong reason).
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('read-picture-43-1')), 200,
          scrollable: find
              .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable))
              .first);
      final picture =
          tester.getRect(find.byKey(const ValueKey('read-picture-43-1')));
      final board =
          tester.getRect(find.byKey(const ValueKey('read-board-43-1')));
      expect(picture.width, picture.height);
      expect(board.width, board.height);
      expect(board.width, picture.width);
      expect(picture.right, lessThanOrEqualTo(board.left));
      expect(board.right, lessThanOrEqualTo(360));
    });
  });

  // docs/PLAN-MATERIJAL.md, phase 2: the engine is asked before saving here
  // too. A picture book prints no solution, so this is where its answers come
  // from. The font path's cases are in scan_settle_test.dart. Boards read:
  // 40-1 (a calibration board), 43-1, and 44-1, which is not a position.
  group('phase 2 — the engine before saving', () {
    Map<String, Map> sentByPage(_Server server) {
      final confirm =
          server.sent.lastWhere((r) => r.url.path == '/scans/confirm');
      return {
        for (final p in ((jsonDecode(confirm.body) as Map)['positions'] as List)
            .cast<Map>())
          '${p['page']}': p,
      };
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }

    final answers = {
      '40-1': highProposal('w', 'Qc8+'),
      '43-1': mediumProposal('b', 'Nd1'),
      '44-1': highProposal('w', 'Kb1'),
    };

    testWidgets(
        'asks about positions whose side nobody set — not one flipped by '
        'hand, not one that is not a position', (tester) async {
      final runner = FakeSideRunner(answers);
      await _pump(tester, _Server(calibration: _calibrated), runner: runner);
      await tester.ensureVisible(find.text('White to move').at(1));
      await tester.tap(find.text('White to move').at(1)); // 43-1
      await tester.pump();
      await tapKey(tester, 'suggest-sides');
      await _settle(tester, 4);
      expect(runner.askedIds, ['40-1']);
      expect(find.byKey(const ValueKey('proposal-40-1')), findsOneWidget);
    });

    testWidgets(
        '„Set side and answer" saves the side and the move of the engine',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server, runner: FakeSideRunner(answers));
      await tapKey(tester, 'suggest-sides');
      await _settle(tester, 4);
      await tapKey(tester, 'proposal-set-answer-43-1');
      await tester.tap(find.byKey(const ValueKey('image-scan-save')));
      await _settle(tester);

      final p43 = sentByPage(server)['43']!;
      expect((p43['fen'] as String).split(' ')[1], 'b');
      expect(p43['solutionSan'], 'Nd1');
      expect(p43['solutionSource'], 'engine');
      expect(p43['needsReview'], false);
      // 40-1 was left alone: no answer, still in doubt.
      expect(sentByPage(server)['40']!.containsKey('solutionSan'), isFalse);
      expect(sentByPage(server)['40']!['needsReview'], true);
    });

    testWidgets('„Set side" takes the side and not the move', (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server, runner: FakeSideRunner(answers));
      await tapKey(tester, 'suggest-sides');
      await _settle(tester, 4);
      await tapKey(tester, 'proposal-set-side-43-1');
      await tester.tap(find.byKey(const ValueKey('image-scan-save')));
      await _settle(tester);

      final p43 = sentByPage(server)['43']!;
      expect((p43['fen'] as String).split(' ')[1], 'b');
      expect(p43.containsKey('solutionSan'), isFalse);
      expect(p43['needsReview'], false);
    });

    testWidgets('„Accept all confident" takes the high proposals only',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server, runner: FakeSideRunner(answers));
      await tapKey(tester, 'suggest-sides');
      await _settle(tester, 4);
      expect(find.text('Accept all confident (1)'), findsOneWidget);
      await tapKey(tester, 'suggest-sides-accept-confident');
      await tester.tap(find.byKey(const ValueKey('image-scan-save')));
      await _settle(tester);

      final sent = sentByPage(server);
      expect(sent['40']!['solutionSan'], 'Qc8+');
      expect(sent['40']!['needsReview'], false);
      expect(sent['43']!.containsKey('solutionSan'), isFalse);
      expect(sent['43']!['needsReview'], true);
    });

    testWidgets('a network engine is refused in words, and nothing is asked',
        (tester) async {
      final runner = FakeSideRunner(answers, usable: false);
      await _pump(tester, _Server(calibration: _calibrated), runner: runner);
      await tapKey(tester, 'suggest-sides');
      await _settle(tester, 4);
      expect(runner.runs, isEmpty);
      expect(find.text(SideSuggestions.noLocalEngineMessage), findsOneWidget);
    });
  });
}
