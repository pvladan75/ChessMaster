// The app's side of the image path — phase 3b of docs/PLAN-SKENER-SLIKE.md.
//
// A book whose diagrams are pictures is read against a calibration (the
// positions of a few of its own boards), remembered on the account by the
// SHA-256 of the file. Every case fakes the client and reads **the request**
// (rule 7): a fake that answered a question nobody asked could not see the
// question go missing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/position_scanner/models/image_scan.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';

const _hash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

// A 1 x 1 PNG, which is all a preview has to be here.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Future<String> _book() async {
  final dir = await Directory.systemTemp.createTemp('scan_image_api_');
  final file = File('${dir.path}/book.pdf');
  await file.writeAsString('%PDF-1.4 not really a book');
  addTearDown(() => dir.delete(recursive: true));
  return file.path;
}

void main() {
  group('scanImages', () {
    test(
        'without a calibration: the pages and the file, and no calibration field',
        () async {
      late http.Request sent;
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async {
          sent = req;
          return http.Response(
            jsonEncode({
              'needsCalibration': true,
              'scannedFrom': 40,
              'scannedTo': 42,
              'boards': [
                {'page': 40, 'index': 1, 'source': 'image', 'preview': _png},
                {'page': 41, 'index': 2, 'source': 'image', 'preview': _png},
              ],
              'pageCount': 120,
            }),
            200,
          );
        }),
      );
      final outcome = await api.scanImages(
          filePath: await _book(),
          fileName: 'book.pdf',
          fromPage: 40,
          toPage: 42);

      expect(sent.method, 'POST');
      expect(sent.url.path, '/scans/images');
      expect(sent.headers['Authorization'], 'Bearer tok');
      expect(sent.body, contains('name="fromPage"\r\n\r\n40'));
      expect(sent.body, contains('name="toPage"\r\n\r\n42'));
      expect(sent.body, contains('name="document"; filename="book.pdf"'));
      expect(sent.body, isNot(contains('name="calibration"')));

      expect(outcome.ok, isTrue);
      final result = outcome.result!;
      expect(result.needsCalibration, isTrue);
      expect(result.boards.map((b) => b.ref),
          [const BoardRef(40, 1), const BoardRef(41, 2)]);
      // Phase 3e: the trainer chooses the boards; the answer carries the
      // book's length for browsing it, and no suggestions any more.
      expect(result.pageCount, 120);
      expect(result.boards.first.preview.sublist(1, 4), utf8.encode('PNG'));
    });

    test(
        'with a calibration: the boards travel as JSON, and the positions come back',
        () async {
      late http.Request sent;
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async {
          sent = req;
          return http.Response(
            jsonEncode({
              'needsCalibration': false,
              'scannedFrom': 40,
              'scannedTo': 42,
              'positions': [
                {
                  'page': 42,
                  'index': 1,
                  'source': 'image',
                  'placement': '8/5k2/8/3Q4/8/2n5/5B2/6K1',
                  'uncertain': ['c3'],
                  'legal': true,
                  'preview': _png,
                },
              ],
              'composed': ['R/light'],
              'unseen': ['q'],
            }),
            200,
          );
        }),
      );
      final outcome = await api.scanImages(
        filePath: await _book(),
        fileName: 'book.pdf',
        fromPage: 40,
        toPage: 42,
        calibration: const [
          CalibrationBoard(
              ref: BoardRef(40, 1), placement: '7k/8/8/3q4/8/8/8/1KQ5'),
          CalibrationBoard(
              ref: BoardRef(41, 2),
              placement: '8/8/8/8/8/8/8/K6k',
              ignore: ['e4']),
        ],
      );

      final field =
          RegExp(r'name="calibration"\r\n\r\n(.*?)\r\n--', dotAll: true)
              .firstMatch(sent.body);
      expect(field, isNotNull, reason: 'no calibration field in the request');
      expect(jsonDecode(field!.group(1)!), [
        {'page': 40, 'index': 1, 'fen': '7k/8/8/3q4/8/8/8/1KQ5'},
        {
          'page': 41,
          'index': 2,
          'fen': '8/8/8/8/8/8/8/K6k',
          'ignore': ['e4']
        },
      ]);

      final board = outcome.result!.positions.single;
      expect(board.ref, const BoardRef(42, 1));
      expect(board.uncertain, ['c3']);
      expect(board.accepted, isTrue);
      expect(outcome.result!.composed, ['R/light']);
      expect(outcome.result!.unseen, ['q']);
    });

    test('a refusal keeps its code and the numbers the server named', () async {
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'error':
                  'Those pages hold 74 diagrams; at most 60 are read at a time.',
              'code': 'too_many_boards',
              'details': {'boards': 74, 'max': 60},
            }),
            422)),
      );
      final outcome = await api.scanImages(
          filePath: await _book(),
          fileName: 'book.pdf',
          fromPage: 1,
          toPage: 40);
      expect(outcome.ok, isFalse);
      expect(outcome.code, 'too_many_boards');
      expect(outcome.error, contains('74'));
      expect(outcome.details, {'boards': 74, 'max': 60});
    });
  });

  group('the door from the font path', () {
    test('a refusal for no text carries how many diagrams are pictures',
        () async {
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async => http.Response(
            jsonEncode({
              'error': 'no text on those pages',
              'code': 'no_text',
              'details': {'imageDiagrams': 38},
            }),
            422)),
      );
      final outcome = await api.scan(
          filePath: await _book(),
          fileName: 'book.pdf',
          fromPage: 40,
          toPage: 60);
      expect(outcome.code, 'no_text');
      expect(outcome.imageDiagrams, 38);
    });

    test('a refusal that counted nothing opens no door', () async {
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async => http.Response(
            jsonEncode({'error': 'unknown font', 'code': 'unknown_font'}),
            422)),
      );
      final outcome = await api.scan(
          filePath: await _book(),
          fileName: 'book.pdf',
          fromPage: 1,
          toPage: 2);
      expect(outcome.imageDiagrams, 0);
    });
  });

  group('the calibration on the account', () {
    test('it is asked for by the book\'s hash', () async {
      late http.Request sent;
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async {
          sent = req;
          return http.Response(
              jsonEncode({
                'bookName': 'Silman',
                'boards': [
                  {
                    'page': 44,
                    'index': 1,
                    'fen': '7k/8/8/3q4/8/8/8/1KQ5',
                    'ignore': []
                  },
                ],
              }),
              200);
        }),
      );
      final load = await api.loadCalibration(_hash);
      expect(sent.method, 'GET');
      expect(sent.url.path, '/scans/calibrations/$_hash');
      expect(sent.headers['Authorization'], 'Bearer tok');
      expect(load.found, isTrue);
      expect(load.boards.single.ref, const BoardRef(44, 1));
      expect(load.boards.single.placement, '7k/8/8/3q4/8/8/8/1KQ5');
    });

    test('"this book has none" is missing, not an error', () async {
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async => http.Response(
            jsonEncode({'error': 'none', 'code': 'no_calibration'}), 404)),
      );
      final load = await api.loadCalibration(_hash);
      expect(load.missing, isTrue);
      expect(load.error, isNull);
    });

    test('a 404 that is not "no calibration" is an error, never "none"',
        () async {
      // A server without the route answers 404 too. Reading that as "this
      // book has no calibration" would send the trainer to set up three
      // boards that could never be remembered.
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient(
            (req) async => http.Response('<html>Not Found</html>', 404)),
      );
      final load = await api.loadCalibration(_hash);
      expect(load.missing, isFalse);
      expect(load.error, isNotNull);
    });

    test('it is saved with the book\'s name and the boards', () async {
      late http.Request sent;
      final api = ScannerApiService(
        authToken: 'tok',
        client: MockClient((req) async {
          sent = req;
          return http.Response(jsonEncode({'saved': 1}), 200);
        }),
      );
      final error = await api.saveCalibration(
        bookHash: _hash,
        bookName: 'Silman',
        boards: const [
          CalibrationBoard(
              ref: BoardRef(44, 1), placement: '7k/8/8/3q4/8/8/8/1KQ5'),
        ],
      );
      expect(error, isNull);
      expect(sent.method, 'PUT');
      expect(sent.url.path, '/scans/calibrations/$_hash');
      expect(jsonDecode(sent.body), {
        'bookName': 'Silman',
        'boards': [
          {'page': 44, 'index': 1, 'fen': '7k/8/8/3q4/8/8/8/1KQ5'},
        ],
      });
    });
  });

  test('a book is known by the SHA-256 of its file', () async {
    final dir = await Directory.systemTemp.createTemp('book_hash_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/abc.pdf');
    await file.writeAsString('abc');
    expect(await bookHashOf(file.path),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  group('a board read from a picture, saved', () {
    ReadBoard board() => ReadBoard(
          ref: const BoardRef(42, 1),
          placement: '8/5k2/8/3Q4/8/2n5/5B2/6K1',
          uncertain: const [],
          legal: true,
          preview: base64Decode(_png),
        );

    test('is flagged for review while nobody has said whose move it is', () {
      final json = board().toScannedPosition().toConfirmJson();
      expect(json['fen'], '8/5k2/8/3Q4/8/2n5/5B2/6K1 w - - 0 1');
      expect(json['page'], 42);
      expect(json['needsReview'], isTrue);
    });

    test('is not flagged once the trainer has set the side', () {
      final b = board()..flipSide();
      final json = b.toScannedPosition().toConfirmJson();
      expect(json['fen'], '8/5k2/8/3Q4/8/2n5/5B2/6K1 b - - 0 1');
      expect(json['needsReview'], isFalse);
    });

    test('a board that is not a position starts unselected', () {
      final b = ReadBoard(
        ref: const BoardRef(1, 1),
        placement: '8/8/8/8/8/8/8/8',
        uncertain: const [],
        legal: false,
        preview: base64Decode(_png),
      );
      expect(b.accepted, isFalse);
    });
  });
}
