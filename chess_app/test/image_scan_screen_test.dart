// The screens of the image path — phases 3c and 3d of
// docs/PLAN-SKENER-SLIKE.md.
//
// A book whose diagrams are pictures: the door from the font path, the three
// boards the trainer sets up beside their pictures, and every board read shown
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
import 'package:chess_app/theme/app_colors.dart';

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
    {'page': 41, 'index': 1, 'fen': '8/3nk3/8/3Q1K2/8/8/8/8', 'ignore': []},
    {
      'page': 42,
      'index': 1,
      'fen': '5nk1/R5p1/p3p2p/2B1P2P/r4P2/1p4K1/6P1/8',
      'ignore': []
    },
  ],
};

/// A fake server. [calibration] answers the GET; [find] and [read] answer
/// POST /scans/images without and with a calibration field; every request is
/// kept in [sent].
class _Server {
  _Server(
      {this.calibration,
      Map<String, dynamic>? find,
      Map<String, dynamic>? read,
      this.readStatus = 200})
      : find = find ?? _defaultFind,
        read = read ?? _defaultRead;

  final Map<String, dynamic>? calibration;
  final Map<String, dynamic> find;
  final Map<String, dynamic> read;
  final int readStatus;
  final List<http.Request> sent = [];

  static final _defaultFind = {
    'needsCalibration': true,
    'scannedFrom': 40,
    'scannedTo': 44,
    'boards': [
      _found(40, 1),
      _found(41, 1),
      _found(42, 1),
      _found(43, 1),
      _found(44, 1)
    ],
    'suggested': [
      {'page': 42, 'index': 1},
      {'page': 40, 'index': 1},
      {'page': 44, 'index': 1},
    ],
  };

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
        if (path == '/scans/images') {
          final withCalibration = req.body.contains('name="calibration"');
          if (!withCalibration) return http.Response(jsonEncode(find), 200);
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
          '${r.method} ${r.url.path}${r.url.path == '/scans/images' ? (r.body.contains('name="calibration"') ? ' +calibration' : ' -calibration') : ''}'
      ];
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
    bool overAnotherScreen = false}) async {
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
      fromPage: 40,
      toPage: 44,
      pickPosition:
          pick ?? (context, picture, initial) async => '8/8/8/8/8/8/8/K6k');
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
      expect(find.textContaining('set up three'), findsNothing);
      expect(find.textContaining('set up this book before'), findsOneWidget);
    });

    testWidgets('a new book is told what setting up means', (tester) async {
      await door(tester, calibrated: false);
      expect(find.textContaining('set up three'), findsOneWidget);
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
    testWidgets('a remembered calibration goes straight to reading',
        (tester) async {
      final server = _Server(calibration: _calibrated);
      await _pump(tester, server);
      expect(server.trail, [
        'GET /scans/calibrations/${server.sent.first.url.pathSegments.last}',
        'POST /scans/images +calibration',
      ]);
      final field =
          RegExp(r'name="calibration"\r\n\r\n(.*?)\r\n--', dotAll: true)
              .firstMatch(server.sent[1].body)!;
      expect((jsonDecode(field.group(1)!) as List).length, 3);
      expect(find.byKey(const ValueKey('image-scan-boards')), findsOneWidget);
      expect(find.byKey(const ValueKey('calibration-boards')), findsNothing);
    });

    testWidgets(
        '"Read" waits for all three boards, then reads and remembers them',
        (tester) async {
      final server = _Server();
      final picked = <String>[];
      await _pump(tester, server, pick: (context, picture, initial) async {
        const placements = [
          '5nk1/R5p1/8/8/8/8/8/6K1',
          '7k/8/8/8/8/8/8/1KQ5',
          '8/3nk3/8/3Q1K2/8/8/8/8'
        ];
        final p = placements[picked.length];
        picked.add(p);
        return p;
      });
      expect(server.trail.skip(1), ['POST /scans/images -calibration']);
      expect(find.byKey(const ValueKey('calibration-boards')), findsOneWidget);

      FilledButton read() =>
          tester.widget(find.byKey(const ValueKey('calibration-read')));
      expect(read().onPressed, isNull);
      for (final ref in ['42-1', '40-1', '44-1']) {
        expect(read().onPressed, isNull,
            reason: 'enabled before $ref was set up');
        await tester
            .ensureVisible(find.byKey(ValueKey('calibrate-setup-$ref')));
        await tester.tap(find.byKey(ValueKey('calibrate-setup-$ref')));
        await _settle(tester, 2);
      }
      expect(read().onPressed, isNotNull);
      expect(find.text('Read 2 boards'), findsOneWidget);

      await tester
          .ensureVisible(find.byKey(const ValueKey('calibration-read')));
      await tester.tap(find.byKey(const ValueKey('calibration-read')));
      await _settle(tester);
      expect(server.trail.skip(2), [
        'POST /scans/images +calibration',
        'PUT /scans/calibrations/${server.sent.first.url.pathSegments.last}',
      ]);
      final sentBoards =
          (jsonDecode(server.sent.last.body) as Map)['boards'] as List;
      expect(sentBoards.map((b) => '${b['page']}:${b['fen']}'), [
        '42:${picked[0]}',
        '40:${picked[1]}',
        '44:${picked[2]}',
      ]);
    });

    // The owner's live pass of 22.9.2026: "Generate and Set Position" threw
    // him back to the scanner, the board unset. The editor closes itself
    // after `onPositionSet`, and the scanner's callback closed it too — so the
    // second close took the calibration screen with it. The cases above stand
    // a fake in for the editor and could not see it; this one runs the real
    // one, through the scanner's own `pickPositionWithEditor`.
    testWidgets('the real editor hands its board back and leaves the screen',
        (tester) async {
      final server = _Server();
      await _pump(tester, server,
          overAnotherScreen: true,
          pick: (context, picture, initial) =>
              pickPositionWithEditor(context, picture, '4k3/8/8/8/8/8/8/4K3'));
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-setup-42-1')));
      await tester.tap(find.byKey(const ValueKey('calibrate-setup-42-1')));
      await _settle(tester, 4);
      expect(find.text('Generate and Set Position'), findsOneWidget);
      await tester.tap(find.text('Generate and Set Position'));
      await _settle(tester, 4);

      expect(find.text('Generate and Set Position'), findsNothing,
          reason: 'the editor stayed open');
      expect(find.text('the screen underneath'), findsNothing,
          reason: 'the calibration screen was closed with the editor');
      expect(find.byKey(const ValueKey('calibration-boards')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('calibrate-setup-42-1')), findsOneWidget);
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
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibrate-setup-42-1')));
      await tester.tap(find.byKey(const ValueKey('calibrate-setup-42-1')));
      await _settle(tester, 4);

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

    testWidgets(
        'a reading that fails remembers nothing, and offers the way out',
        (tester) async {
      final server = _Server(readStatus: 422);
      await _pump(tester, server);
      for (final ref in ['42-1', '40-1', '44-1']) {
        await tester
            .ensureVisible(find.byKey(ValueKey('calibrate-setup-$ref')));
        await tester.tap(find.byKey(ValueKey('calibrate-setup-$ref')));
        await _settle(tester, 2);
      }
      await tester
          .ensureVisible(find.byKey(const ValueKey('calibration-read')));
      await tester.tap(find.byKey(const ValueKey('calibration-read')));
      await _settle(tester);
      expect(server.trail.where((t) => t.startsWith('PUT')), isEmpty,
          reason: 'a calibration that did not read was remembered');
      expect(find.byKey(const ValueKey('image-scan-failure')), findsOneWidget);
      expect(find.byKey(const ValueKey('image-scan-failed-recalibrate')),
          findsOneWidget);
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
}
