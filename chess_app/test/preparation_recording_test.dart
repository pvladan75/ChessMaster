// The gate for phase 3 of `docs/PLAN-PRIPREMA.md` — recording on
// Preparation's own screen, and squares in the timeline.
//
// **Since phase 4 this is the only recording there is.** The room's own
// (`lesson_recording_ui_test.dart`, eight cases) went with the room's
// recording, each of them held here under the name beside it:
//
//   Preparation offers „Start recording",   „offers „Record" at …"; the room's
//     a room does not                       half is `room_not_recorded_test`
//                                           and `preparation_doors_test`
//   a refusal is said before the            the same name
//     microphone opens
//   a lesson goes to the server with the    „is the board's events, each
//     board stamped on the audio's clock    stamped on the audio's clock"
//   a failed upload keeps the take and      the same name
//     offers to try again
//   discard sends nothing and keeps         the same name
//     nothing
//   back does not leave while a lesson      „back does not leave while a take
//     is recording                          runs"
//   the strip fits at 360×640, 760×360      there is no strip (D11): „the
//                                           board is the size it was, recording
//                                           or not, at …" and the two phone
//                                           cases of „the bar"
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT
//
// **The screen gains three seams**, every one optional, named as the room's
// are:
//
//   lessonRecordingApi   LessonRecordingApi            may I record, and the upload
//   pcmSourceFactory     PcmSource Function()          the microphone
//   lessonTakeDir        Future<Directory> Function()  where the take is kept
//
// **The bar**, at every width:
//
//   Key('prep-record')              „Record" — a word where the bar is the
//                                   wide one, an icon with that tooltip where
//                                   it is not. Not drawn while a take runs.
//
// and while a take runs (D11 — said in the bar, never in a strip under it):
//
//   Key('prep-recording')           the clock („0:01"), and „N s left" in the
//                                   take's last minute
//   Key('lesson-recording-pause')   „Pause" / „Resume"
//   Key('lesson-recording-stop')    „Stop and save"
//   Key('lesson-recording-discard') „Discard"
//
//   „Library" and „Board" stay, because a position loaded in mid-recording is
//   part of the recording. „Save as…" and ⋮ give way on the wide bar. On the
//   narrow bar ⋮ stays and holds what puts something on the board and nothing
//   that keeps.
//
//   A tutorial is still walked: from the bar where the bar is the wide one
//   (840 and wider), and from ⋮ where it is the narrow one —
//   Key('prep-part-prev'), Key('prep-part-next') — because 360 px do not
//   hold the stepper and a take together. With no take running it is walked
//   from the bar at every width, as in phase 2.
//
// **The board is the size it was**: before „Record", while the take runs,
// while it is paused, and after.
//
// **The dialogs are the room's, as they are**: Key('lesson-title-field'),
// Key('lesson-save'), Key('lesson-upload-retry'), and every sentence:
//
//   'Save the recording'   'Title'   'Discard'   'Save'
//   'The recording was not saved'   'Try again'
//   'Recording saved. It is under Recordings.'
//   'Recording stopped at the limit of one recording. It is kept.'
//   'Stop or discard the recording first.'
//   'The app may not use the microphone. Allow it in the system settings.'
//
// **The timeline.** Three kinds, stamped by the audio's own clock
// (`LessonTake.mark`), and **every event carries the marks of the board it
// leaves behind** — `arrows` as `{from, to, color}`, `squares` as
// `{square, color}`, each key written only when its list is not empty, except
// on `arrow_drawn`, which always writes both:
//
//   init          the board when „Record" was pressed, and every board put on
//                 the screen afterwards (the Library, „Board", a tutorial's
//                 part): `fen`, `pgn`, and the marks of that position
//   move          a move played — `fen`, `from`, `to` — and a step to a move
//                 already in the tree — `fen` alone; both with the marks the
//                 move they land on already holds
//   arrow_drawn   every change of the marks on the board in front of the
//                 trainer: `arrows` and `squares`, whole, both always
//
// The first tap of an arrow changes nothing and writes nothing.
//
// **The invariant all of it serves**: at every moment of the recording, what
// the player replays (`replayFrameAt`) is what the trainer saw — the same
// position, arrows and squares.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/preparation/screens/preparation_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/landscape.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
const _lucena = '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1';

const _refusal =
    'Recording requires entering your birth year — only adults may record their voice.';

const _desktop = Size(1536, 792);
const _narrowDesktop = Size(900, 700);
const _phone = Size(360, 640);
const _phoneOnItsSide = Size(800, 360);

/// A part whose first move holds an arrow and a square of its own.
const _partOnePgn = '1. e4 { Takes the centre. [%cal Ge2e4] [%csl Rd5] } '
    '1... e5 2. Nf3';
const _partTwoPgn = '1. Rc4 { The bridge. } 1... Ra1 2. Rd4+';

final _record = find.byKey(const Key('prep-record'));
final _recording = find.byKey(const Key('prep-recording'));
final _pause = find.byKey(const Key('lesson-recording-pause'));
final _stop = find.byKey(const Key('lesson-recording-stop'));
final _discard = find.byKey(const Key('lesson-recording-discard'));

class _Mic implements PcmSource {
  _Mic({this.permitted = true});

  final bool permitted;

  /// One for every take: a stream is listened to once in its life, and the
  /// real microphone hands over a new one each time it is started. The first
  /// draft of this gate kept a single controller, so a second take on the
  /// same microphone threw — the worker of phase 3 found it and said so.
  var controller = StreamController<Uint8List>();
  bool started = false;
  int starts = 0;

  @override
  Future<bool> hasPermission() async => permitted;
  @override
  Future<Stream<Uint8List>> start() async {
    started = true;
    if (starts++ > 0) controller = StreamController<Uint8List>();
    return controller.stream;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}

  /// [ms] of audio at 32 bytes a millisecond, loud enough to count as live.
  void speak(int ms) {
    final bytes = Uint8List(ms * 32);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      data.setInt16(i, 8000, Endian.little);
    }
    controller.add(bytes);
  }
}

class _Server {
  _Server({this.allowed = true, this.maxMs = 60000, List<int>? uploadStatuses})
      : uploadStatuses = uploadStatuses ?? [201];

  final bool allowed;
  final int maxMs;
  final List<int> uploadStatuses;
  final uploads = <http.Request>[];
  int limitsAsked = 0;

  late final client = MockClient((req) async {
    final path = req.url.path;
    http.Response json(Object body, [int status = 200]) =>
        http.Response.bytes(utf8.encode(jsonEncode(body)), status,
            headers: {'content-type': 'application/json; charset=utf-8'});

    if (path.endsWith('/library/positions')) {
      return json({
        'items': [
          {
            'kind': 'tutorial',
            'id': '14',
            'title': 'Rook endings',
            'fen': _start,
            'partsCount': 2,
            'fromTrainer': false,
          },
          {
            'kind': 'position',
            'id': '12',
            'title': 'Lucena',
            'fen': _lucena,
            'fromTrainer': false,
          },
        ],
      });
    }
    if (path.endsWith('/lessons/labels')) return json(<String>[]);
    if (req.method == 'GET' && path.endsWith('/lessons/14')) {
      return json({
        'id': 14,
        'title': 'Rook endings',
        'position_list': [
          {
            'id': 'step0001',
            'title': 'The centre',
            'fen': _start,
            'pgn': _partOnePgn,
          },
          {
            'id': 'step0002',
            'title': 'The bridge',
            'fen': _lucena,
            'pgn': _partTwoPgn,
          },
        ],
      });
    }
    if (path == '/recordings/lesson-limits') {
      limitsAsked++;
      return json({
        'allowed': allowed,
        'reason': allowed ? null : _refusal,
        'maxMs': maxMs,
      });
    }
    if (path == '/recordings/lesson' && req.method == 'POST') {
      uploads.add(req);
      final status = uploadStatuses.length > 1
          ? uploadStatuses.removeAt(0)
          : uploadStatuses.first;
      return status == 201
          ? json({
              'recording': {'id': 88, 'title': 'x'}
            }, 201)
          : json({'error': 'The server is out of space.'}, status);
    }
    return json({'error': 'not in this fixture: ${req.method} $path'}, 404);
  });
}

/// A field of a multipart body, read as text.
String _field(http.Request req, String name) {
  final body = latin1.decode(req.bodyBytes);
  final start = body.indexOf('name="$name"');
  expect(start, isNot(-1), reason: 'no field $name in the upload');
  final from = body.indexOf('\r\n\r\n', start) + 4;
  final to = body.indexOf('\r\n--', from);
  return utf8.decode(latin1.encode(body.substring(from, to)));
}

List<Map<String, dynamic>> _eventsOf(http.Request req) => [
      for (final e in jsonDecode(_field(req, 'events')) as List)
        Map<String, dynamic>.from(e as Map),
    ];

Widget _screen(_Server server, _Mic mic, Directory dir, {String? fen}) =>
    PreparationScreen(
      key: UniqueKey(),
      userSession: UserSession(
          token: 'tok',
          id: 7,
          email: 'a@b.c',
          name: 'Trainer',
          role: 'korisnik'),
      initialFen: fen,
      positionLibrary:
          PositionLibraryService(authToken: 'tok', client: server.client),
      lessonApi: LessonApiService(authToken: 'tok', client: server.client),
      scannerApi: ScannerApiService(authToken: 'tok', client: server.client),
      exerciseApi: ExerciseApiService(authToken: 'tok', client: server.client),
      onOpenInAnalysis: (_) {},
      lessonRecordingApi:
          LessonRecordingApi(authToken: 'tok', client: server.client),
      pcmSourceFactory: () => mic,
      lessonTakeDir: () async => dir,
    );

Directory _takeDir() {
  final dir = Directory.systemTemp.createTempSync('prep-rec-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

void _prepare(WidgetTester tester, _Server server, Size size) {
  SharedPreferences.setMockInitialValues({});
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(server.client));
  addTearDown(AnalysisPersistenceService.resetInstance);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}

Future<(_Mic, Directory)> _open(
  WidgetTester tester,
  _Server server, {
  Size size = _desktop,
  String? fen,
  _Mic? mic,
}) async {
  _prepare(tester, server, size);
  final microphone = mic ?? _Mic();
  final dir = _takeDir();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: _screen(server, microphone, dir, fen: fen),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return (microphone, dir);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

/// [ms] of talking, and the screen given time to hear it.
Future<void> _speak(WidgetTester tester, _Mic mic, int ms) async {
  mic.speak(ms);
  await _settle(tester);
}

List<File> _takes(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.wav'))
    .toList();

ChessBoardWithOverlay _board(WidgetTester tester) {
  final board = find.byType(ChessBoardWithOverlay);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  return tester.widget<ChessBoardWithOverlay>(board);
}

AnalysisMoveTreeWidget _tree(WidgetTester tester) {
  final tree = find.byType(AnalysisMoveTreeWidget, skipOffstage: false);
  expect(tree, findsOneWidget, reason: 'there is no move tree on the screen');
  return tester.widget<AnalysisMoveTreeWidget>(tree);
}

Size _boardSize(WidgetTester tester) {
  final board = find.byType(BoardWithCoordinates);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  return tester.getSize(board);
}

Future<void> _press(WidgetTester tester, Key key) async {
  expect(find.byKey(key), findsOneWidget, reason: 'nothing is keyed $key');
  await tester.tap(find.byKey(key));
  await _settle(tester);
}

Future<void> _tooltip(WidgetTester tester, String message) async {
  expect(find.byTooltip(message), findsOneWidget,
      reason: 'no control says „$message"');
  await tester.tap(find.byTooltip(message));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  _board(tester).onMove(from, to, '');
  await tester.pump(const Duration(milliseconds: 50));
}

/// A tap on [square] while a marking tool is chosen.
Future<void> _mark(WidgetTester tester, String square) async {
  expect(_board(tester).isDrawingMode, isTrue,
      reason: 'no marking tool is chosen, so a tap would be a move');
  _board(tester).onSquareTapForDrawing(square);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _startRecording(WidgetTester tester) async {
  await _press(tester, const Key('prep-record'));
}

Future<void> _saveAs(WidgetTester tester, String title) async {
  await _press(tester, const Key('lesson-recording-stop'));
  await tester.enterText(find.byKey(const Key('lesson-title-field')), title);
  await _press(tester, const Key('lesson-save'));
  await _settle(tester);
}

/// Opens the drawer and taps the row called [title].
Future<void> _putOnBoard(WidgetTester tester, String title) async {
  await _press(tester, const Key('prep-library'));
  final drawer = find.byKey(const Key('prep-library-drawer'));
  expect(drawer, findsOneWidget, reason: 'the Library\'s drawer did not open');
  final row = find.descendant(of: drawer, matching: find.text(title));
  expect(row, findsOneWidget, reason: '„$title" is not in the drawer');
  await tester.ensureVisible(row);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(row);
  await _settle(tester);
}

/// What the trainer has in front of them, at [ms] of the audio.
class _Seen {
  _Seen(this.ms, this.what, WidgetTester tester)
      : fen = _tree(tester).activeNode.fen,
        arrows = [
          for (final a in _board(tester).arrows)
            '${a.colorCode}${a.from}${a.to}',
        ],
        squares = [
          for (final s in _board(tester).squares) '${s.colorCode}${s.square}',
        ];

  final int ms;
  final String what;
  final String fen;
  final List<String> arrows;
  final List<String> squares;
}

/// The lesson every timeline case records: a move, an arrow, a square, a step
/// back and forward again, a clear, a position from the Library, a tutorial
/// and its second part — half a second of talking between any two, so every
/// event has a millisecond of its own.
Future<List<_Seen>> _lesson(WidgetTester tester, _Mic mic) async {
  final seen = <_Seen>[];
  var ms = 0;
  Future<void> then(String what, Future<void> Function() act,
      {int after = 500}) async {
    await _speak(tester, mic, after);
    ms += after;
    await act();
    seen.add(_Seen(ms, what, tester));
  }

  await _startRecording(tester);
  seen.add(_Seen(0, 'Record', tester));

  await then('a move', () => _play(tester, 'e2', 'e4'), after: 1000);
  await then('an arrow', () async {
    await _press(tester, const Key('annotate-arrow'));
    await _mark(tester, 'g1');
    await _mark(tester, 'f3');
  });
  await then('a square', () async {
    await _press(tester, const Key('annotate-square'));
    await _mark(tester, 'd5');
  });
  await then('a step back', () => _tooltip(tester, 'Previous move'));
  await then('a step forward', () => _tooltip(tester, 'Next move'));
  await then('a clear', () => _press(tester, const Key('annotate-clear')));
  await then('a position', () => _putOnBoard(tester, 'Lucena'));
  await then('a tutorial', () => _putOnBoard(tester, 'Rook endings'));
  await then('its first move', () => _tooltip(tester, 'Next move'));
  await then(
      'its second part', () => _press(tester, const Key('prep-part-next')));
  await _speak(tester, mic, 500);
  return seen;
}

void main() {
  setUpAll(loadRoboto);

  final windows = TargetPlatformVariant.only(TargetPlatform.windows);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  final everyWindow = <(Size, TargetPlatformVariant)>[
    (_desktop, windows),
    (const Size(1200, 800), windows),
    (_narrowDesktop, windows),
    (_phone, android),
    (_phoneOnItsSide, android),
  ];

  group('the bar', () {
    for (final (size, platform) in everyWindow) {
      testWidgets('offers „Record" at ${sizeLabel(size)}', (tester) async {
        await _open(tester, _Server(), size: size);
        expect(_record, findsOneWidget, reason: 'nothing is keyed prep-record');
        expectOnScreen(tester, size, _record);
        final rect = tester.getRect(_record);
        expect(rect.width >= 40 && rect.height >= 40, isTrue,
            reason: '„Record" is ${rect.size}, too small to press');
        expect(_recording, findsNothing);
        expect(_stop, findsNothing);
        expect(tester.takeException(), isNull);
      }, variant: platform);

      testWidgets(
          'the board is the size it was, recording or not, at '
          '${sizeLabel(size)}', (tester) async {
        final (mic, _) = await _open(tester, _Server(), size: size);
        final before = _boardSize(tester);
        expect(before.width, closeTo(before.height, 0.01));

        await _startRecording(tester);
        await _speak(tester, mic, 1000);
        expect(tester.takeException(), isNull,
            reason: 'the bar does not hold a recording at ${sizeLabel(size)}');
        expect(_boardSize(tester), before,
            reason: 'pressing „Record" resized the board');
        expect(_recording, findsOneWidget,
            reason: 'the bar does not say a take is running');
        for (final control in [_recording, _pause, _stop, _discard]) {
          expectOnScreen(tester, size, control);
        }
        for (final button in [_pause, _stop, _discard]) {
          final rect = tester.getRect(button);
          expect(rect.width >= 40 && rect.height >= 40, isTrue,
              reason: '$button is ${rect.size}, too small to press');
        }
        // „Fits" is not „can be read": the clock is drawn whole.
        final clock =
            find.descendant(of: _recording, matching: find.text('0:01'));
        expect(clock, findsOneWidget,
            reason: 'the bar does not say how long the take is');
        expect(tester.renderObject<RenderParagraph>(clock).didExceedMaxLines,
            isFalse,
            reason: 'the clock is cut at ${sizeLabel(size)}');

        await _press(tester, const Key('lesson-recording-pause'));
        expect(_boardSize(tester), before, reason: 'pausing resized the board');
        expect(tester.takeException(), isNull);

        await _press(tester, const Key('lesson-recording-discard'));
        expect(_recording, findsNothing);
        expect(_record, findsOneWidget);
        expect(_boardSize(tester), before,
            reason: 'the board did not come back the size it was');
        expect(tester.takeException(), isNull);
      }, variant: platform);
    }

    testWidgets(
        'keeps „Library" and „Board" while recording, and says the time',
        (tester) async {
      final (mic, _) = await _open(tester, _Server());
      await _startRecording(tester);
      await _speak(tester, mic, 1000);

      expect(_record, findsNothing, reason: 'a second take cannot be started');
      for (final key in const [Key('prep-library'), Key('prep-board-menu')]) {
        expect(find.byKey(key), findsOneWidget,
            reason: '$key left the bar, and a position loaded in '
                'mid-recording is part of the recording');
        expectOnScreen(tester, _desktop, find.byKey(key));
      }
      expect(find.byKey(const Key('prep-save-menu')), findsNothing);
      expect(find.byKey(const Key('prep-more')), findsNothing);
      // A cap of a minute: the take stops itself at 59 s, and one has passed.
      expect(find.descendant(of: _recording, matching: find.text('58 s left')),
          findsOneWidget);
      expect(find.byKey(const Key('lesson-recording-strip')), findsNothing,
          reason: 'the room\'s strip under the bar is not carried over (D11)');
      expect(find.byTooltip('Stop and save'), findsOneWidget);
      expect(find.byTooltip('Discard'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);

      await _press(tester, const Key('lesson-recording-pause'));
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsNothing);
    }, variant: windows);

    testWidgets('with an hour to go it does not count the seconds',
        (tester) async {
      final (mic, _) = await _open(tester, _Server(maxMs: 3600000));
      await _startRecording(tester);
      await _speak(tester, mic, 1000);
      expect(find.textContaining('s left'), findsNothing);
    }, variant: windows);

    testWidgets(
        'on a phone ⋮ holds what puts something on the board, and nothing '
        'that keeps', (tester) async {
      final (mic, _) = await _open(tester, _Server(), size: _phone);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      await _press(tester, const Key('prep-more'));
      for (final key in const [
        Key('prep-board-setup'),
        Key('prep-board-fen'),
        Key('prep-board-pgn'),
        Key('prep-board-start'),
      ]) {
        expect(find.byKey(key), findsOneWidget,
            reason: 'nothing is keyed $key');
      }
      for (final key in const [
        Key('prep-save-position'),
        Key('prep-save-exercise'),
        Key('prep-save-analysis'),
        Key('prep-save-pgn'),
        Key('prep-open-analysis'),
      ]) {
        expect(find.byKey(key), findsNothing,
            reason: '$key is offered while a take runs');
      }
      expect(tester.takeException(), isNull);
    }, variant: android);

    testWidgets(
        'a tutorial is walked from the bar while recording, at 900 wide',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server, size: _narrowDesktop);
      await _putOnBoard(tester, 'Rook endings');
      await _startRecording(tester);
      await _speak(tester, mic, 1000);
      expect(tester.takeException(), isNull,
          reason: 'the bar does not hold a tutorial and a recording together');
      for (final control in [
        _recording,
        _pause,
        _stop,
        _discard,
        find.byKey(const Key('prep-part-prev')),
        find.byKey(const Key('prep-part-next')),
        find.byKey(const Key('prep-library')),
        find.byKey(const Key('prep-board-menu')),
      ]) {
        expectOnScreen(tester, _narrowDesktop, control);
      }
      await _press(tester, const Key('prep-part-next'));
      expect(_tree(tester).activeNode.fen, _lucena);

      await _saveAs(tester, 'Rook endings, spoken');
      final events = _eventsOf(server.uploads.single);
      expect([for (final e in events) e['eventType']], ['init', 'init']);
      expect([for (final e in events) e['timestampMs']], [0, 1000]);
      expect(events.last['data']['fen'], _lucena);
    }, variant: windows);

    testWidgets(
        'on a phone held on its side the bar holds a take, and ⋮ what goes '
        'on the board', (tester) async {
      // Added on grading: the bar is the narrow one under 840 wide, whichever
      // way the phone is held, and the worker built it so. The contract at
      // the head of this file says „the narrow bar" since.
      final server = _Server();
      final (mic, _) = await _open(tester, server, size: _phoneOnItsSide);
      await _startRecording(tester);
      await _speak(tester, mic, 1000);
      expect(tester.takeException(), isNull);
      for (final control in [_recording, _pause, _stop, _discard]) {
        expectOnScreen(tester, _phoneOnItsSide, control);
      }
      await _press(tester, const Key('prep-more'));
      expect(find.byKey(const Key('prep-board-start')), findsOneWidget);
      expect(find.byKey(const Key('prep-save-position')), findsNothing);
      expect(find.byKey(const Key('prep-part-next')), findsNothing,
          reason: 'there is no tutorial on the board to walk');
      expect(tester.takeException(), isNull);
    }, variant: android);

    testWidgets('on a phone a tutorial is walked from ⋮ while recording',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server, size: _phone);
      await tester.tap(find.widgetWithText(Tab, 'Library'));
      await _settle(tester);
      final row = find.text('Rook endings');
      expect(row, findsOneWidget, reason: 'the tutorial is not on the tab');
      await tester.ensureVisible(row);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(row);
      await _settle(tester);
      expect(find.byKey(const Key('prep-part-next')), findsOneWidget,
          reason: 'until a take runs the tutorial is walked from the bar');

      await _startRecording(tester);
      await _speak(tester, mic, 1000);
      expect(tester.takeException(), isNull);
      for (final control in [_recording, _pause, _stop, _discard]) {
        expectOnScreen(tester, _phone, control);
      }

      await _press(tester, const Key('prep-more'));
      expect(find.byKey(const Key('prep-part-prev')), findsOneWidget);
      await _press(tester, const Key('prep-part-next'));
      expect(_board(tester).controller.getFen().split(' ').first,
          _lucena.split(' ').first);

      await _saveAs(tester, 'Rook endings, spoken');
      final events = _eventsOf(server.uploads.single);
      expect([for (final e in events) e['eventType']], ['init', 'init']);
      expect(events.last['data']['fen'], _lucena);
    }, variant: android);
  });

  group('the take', () {
    testWidgets('a refusal is said before the microphone opens',
        (tester) async {
      final server = _Server(allowed: false);
      final (mic, dir) = await _open(tester, server);
      await _startRecording(tester);
      expect(server.limitsAsked, 1);
      expect(find.text(_refusal), findsOneWidget);
      expect(_recording, findsNothing);
      expect(_record, findsOneWidget);
      expect(mic.started, isFalse);
      expect(_takes(dir), isEmpty);
    }, variant: windows);

    testWidgets('two taps on „Record" start one take', (tester) async {
      // Added on grading. The server is asked before the take exists, so a
      // second tap that arrives while it is being asked finds no take to be
      // refused by — the double tap on „Start" of 22.9.2026, word for word.
      final server = _Server();
      final dir = _takeDir();
      var microphones = 0;
      final mic = _Mic();
      _prepare(tester, server, _desktop);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: PreparationScreen(
          key: UniqueKey(),
          userSession: UserSession(
              token: 'tok', id: 7, email: 'a@b.c', name: 'T', role: 'korisnik'),
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: server.client),
          lessonApi: LessonApiService(authToken: 'tok', client: server.client),
          scannerApi:
              ScannerApiService(authToken: 'tok', client: server.client),
          exerciseApi:
              ExerciseApiService(authToken: 'tok', client: server.client),
          onOpenInAnalysis: (_) {},
          lessonRecordingApi:
              LessonRecordingApi(authToken: 'tok', client: server.client),
          pcmSourceFactory: () {
            microphones++;
            return mic;
          },
          lessonTakeDir: () async => dir,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(_record);
      await tester.tap(_record, warnIfMissed: false);
      await _settle(tester);
      await _speak(tester, mic, 500);

      expect(server.limitsAsked, 1, reason: 'the server was asked twice');
      expect(microphones, 1, reason: 'two microphones were opened');
      expect(_takes(dir), hasLength(1), reason: 'two takes were started');
      expect(_recording, findsOneWidget);
    }, variant: windows);

    testWidgets('a microphone the app may not use is said, and nothing is kept',
        (tester) async {
      final server = _Server();
      final (mic, dir) =
          await _open(tester, server, mic: _Mic(permitted: false));
      await _startRecording(tester);
      await _settle(tester);
      expect(
          find.text('The app may not use the microphone. '
              'Allow it in the system settings.'),
          findsOneWidget);
      expect(mic.started, isFalse);
      expect(_recording, findsNothing);
      expect(_record, findsOneWidget);
      expect(_takes(dir), isEmpty);
    }, variant: windows);

    testWidgets('a failed upload keeps the take and offers to try again',
        (tester) async {
      final server = _Server(uploadStatuses: [507, 201]);
      final (mic, dir) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 800);
      await _saveAs(tester, 'Rook endings');

      expect(find.text('The recording was not saved'), findsOneWidget);
      expect(find.text('The server is out of space.'), findsOneWidget);
      expect(_takes(dir), hasLength(1), reason: 'the only copy of a voice');
      await _press(tester, const Key('lesson-upload-retry'));
      await _settle(tester);
      expect(server.uploads, hasLength(2));
      expect(_takes(dir), isEmpty);
      expect(find.text('Recording saved. It is under Recordings.'),
          findsOneWidget);
    }, variant: windows);

    testWidgets('a saved take leaves the bar as it was', (tester) async {
      final server = _Server();
      final (mic, dir) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 1500);
      await _saveAs(tester, 'Lucena, the bridge');

      final req = server.uploads.single;
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(_field(req, 'title'), 'Lucena, the bridge');
      expect(_field(req, 'durationMs'), '1500');
      expect(latin1.decode(req.bodyBytes), contains('name="audio"'));
      expect(find.text('Recording saved. It is under Recordings.'),
          findsOneWidget);
      expect(_takes(dir), isEmpty,
          reason: 'the take leaves the device once the server has it');
      expect(_recording, findsNothing);
      for (final key in const [
        Key('prep-record'),
        Key('prep-library'),
        Key('prep-board-menu'),
        Key('prep-save-menu'),
        Key('prep-more'),
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key did not return');
      }
    }, variant: windows);

    testWidgets('discard sends nothing and keeps nothing', (tester) async {
      final server = _Server();
      final (mic, dir) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      expect(_takes(dir), hasLength(1));
      await _press(tester, const Key('lesson-recording-discard'));
      expect(_recording, findsNothing);
      expect(server.uploads, isEmpty);
      expect(_takes(dir), isEmpty);
    }, variant: windows);

    testWidgets('„Discard" where the title is asked drops the take',
        (tester) async {
      final server = _Server();
      final (mic, dir) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      await _press(tester, const Key('lesson-recording-stop'));
      expect(find.text('Save the recording'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await _settle(tester);
      expect(server.uploads, isEmpty);
      expect(_takes(dir), isEmpty);
      expect(_record, findsOneWidget);
    }, variant: windows);

    testWidgets('a take without a title is not sent', (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      await _press(tester, const Key('lesson-recording-stop'));
      await _press(tester, const Key('lesson-save'));
      expect(find.text('Save the recording'), findsOneWidget,
          reason: 'the dialog closed on a take nobody named');
      expect(server.uploads, isEmpty);
    }, variant: windows);

    testWidgets('the cap stops the take, says so and keeps it', (tester) async {
      final server = _Server();
      final (mic, dir) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 59000);
      await _settle(tester);
      expect(
          find.text(
              'Recording stopped at the limit of one recording. It is kept.'),
          findsOneWidget);
      expect(find.text('Save the recording'), findsOneWidget);
      expect(_takes(dir), hasLength(1));
    }, variant: windows);

    testWidgets('back does not leave while a take runs', (tester) async {
      // Preparation is a pushed route in the app, so it is one here: with the
      // screen as the only route, back is the system's and not the screen's
      // to refuse.
      final server = _Server();
      _prepare(tester, server, _desktop);
      final mic = _Mic();
      final dir = _takeDir();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: const Scaffold(body: Text('HOME')),
      ));
      unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => _screen(server, mic, dir),
      )));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _startRecording(tester);
      await _speak(tester, mic, 300);

      await navigator.currentState!.maybePop();
      await _settle(tester);
      expect(_recording, findsOneWidget, reason: 'still in Preparation');
      expect(find.text('HOME'), findsNothing);
      expect(find.text('Stop or discard the recording first.'), findsOneWidget);

      await _press(tester, const Key('lesson-recording-discard'));
      await navigator.currentState!.maybePop();
      await _settle(tester);
      await _settle(tester);
      expect(find.text('HOME'), findsOneWidget,
          reason: 'with the take gone, back leaves as always');
    }, variant: windows, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('the timeline', () {
    testWidgets('is the board\'s events, each stamped on the audio\'s clock',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _lesson(tester, mic);
      await _saveAs(tester, 'A lesson');

      final req = server.uploads.single;
      expect(_field(req, 'durationMs'), '6000');
      final events = _eventsOf(req);
      expect([
        for (final e in events) e['eventType']
      ], [
        'init', // Record
        'move', // e4
        'arrow_drawn', // g1–f3; its first tap wrote nothing
        'arrow_drawn', // d5
        'move', // a step back
        'move', // a step forward
        'arrow_drawn', // a clear
        'init', // Lucena
        'init', // the tutorial's first part
        'move', // its first move
        'init', // its second part
      ]);
      expect([for (final e in events) e['timestampMs']],
          [0, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 5500]);
      Map<String, dynamic> data(int i) =>
          Map<String, dynamic>.from(events[i]['data'] as Map);

      expect(data(0)['fen'], _start);
      expect(data(0)['pgn'], isA<String>());
      expect(data(0).containsKey('arrows'), isFalse,
          reason: 'a bare board names no marks');

      expect(data(1), {'fen': _afterE4, 'from': 'e2', 'to': 'e4'});

      expect(data(2), {
        'arrows': [
          {'from': 'g1', 'to': 'f3', 'color': 'G'},
        ],
        'squares': <Object>[],
      });
      expect(data(3), {
        'arrows': [
          {'from': 'g1', 'to': 'f3', 'color': 'G'},
        ],
        'squares': [
          {'square': 'd5', 'color': 'G'},
        ],
      });

      // A step to a move already in the tree: the position alone, and the
      // marks that move holds.
      expect(data(4), {'fen': _start});
      expect(data(5), {
        'fen': _afterE4,
        'arrows': [
          {'from': 'g1', 'to': 'f3', 'color': 'G'},
        ],
        'squares': [
          {'square': 'd5', 'color': 'G'},
        ],
      });

      expect(data(6), {'arrows': <Object>[], 'squares': <Object>[]});

      expect(data(7)['fen'], _lucena);
      expect(data(7)['pgn'], isA<String>());

      expect(data(8)['fen'], _start);
      expect(data(8)['pgn'], contains('e4'),
          reason: 'a part is put on the board with its line');

      expect(data(9)['fen'], _afterE4);
      expect(data(9)['arrows'], [
        {'from': 'e2', 'to': 'e4', 'color': 'G'},
      ]);
      expect(data(9)['squares'], [
        {'square': 'd5', 'color': 'R'},
      ]);

      expect(data(10)['fen'], _lucena);
    }, variant: windows);

    testWidgets('replays as what the trainer saw, at every step',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      final seen = await _lesson(tester, mic);
      await _saveAs(tester, 'A lesson');

      // As the server stores it and the player reads it back.
      final events = [
        for (final e in _eventsOf(server.uploads.single))
          TimelineEvent.fromJson(e),
      ];
      expect(seen, hasLength(11));
      expect(seen.where((s) => s.arrows.isNotEmpty && s.squares.isNotEmpty),
          isNotEmpty,
          reason: 'the lesson never had an arrow and a square together');
      for (final moment in seen) {
        // Up to the millisecond before the next thing the trainer did.
        for (final ms in [moment.ms, moment.ms + 499]) {
          final frame = replayFrameAt(events, ms);
          expect(frame.fen, moment.fen,
              reason: 'the position after ${moment.what}, at $ms ms');
          expect([
            for (final a in frame.arrows)
              '${a['colorCode']}${a['from']}${a['to']}',
          ], moment.arrows,
              reason: 'the arrows after ${moment.what}, at $ms ms');
          expect([
            for (final s in frame.squares) '${s['colorCode']}${s['square']}',
          ], moment.squares,
              reason: 'the squares after ${moment.what}, at $ms ms');
        }
      }
    }, variant: windows);

    testWidgets('opens on the board as it stood, marks and all',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server, fen: _lucena);
      // Drawn before „Record": not an event, and not lost either.
      await _press(tester, const Key('annotate-square'));
      await _mark(tester, 'c4');
      await _startRecording(tester);
      await _speak(tester, mic, 700);
      await _saveAs(tester, 'Lucena');

      final events = _eventsOf(server.uploads.single);
      expect(events, hasLength(1));
      expect(events.single['eventType'], 'init');
      expect(events.single['timestampMs'], 0);
      expect(events.single['data']['fen'], _lucena);
      expect(events.single['data']['squares'], [
        {'square': 'c4', 'color': 'G'},
      ]);
    }, variant: windows);

    testWidgets('a move made before the first sample is stamped at 0',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _startRecording(tester);
      // The microphone has not delivered anything yet.
      await _play(tester, 'e2', 'e4');
      await _speak(tester, mic, 900);
      await _saveAs(tester, 'Early');

      final events = _eventsOf(server.uploads.single);
      expect([for (final e in events) e['eventType']], ['init', 'move']);
      expect([for (final e in events) e['timestampMs']], [0, 0]);
      expect(events.last['data']['fen'], _afterE4);
    }, variant: windows);

    testWidgets('a move made while paused lands on the seam', (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 1000);
      await _press(tester, const Key('lesson-recording-pause'));
      await _play(tester, 'e2', 'e4');
      await _press(tester, const Key('lesson-recording-pause'));
      await _speak(tester, mic, 500);
      await _saveAs(tester, 'Paused');

      final req = server.uploads.single;
      expect(_field(req, 'durationMs'), '1500');
      final events = _eventsOf(req);
      expect([for (final e in events) e['eventType']], ['init', 'move']);
      expect([for (final e in events) e['timestampMs']], [0, 1000]);
    }, variant: windows);

    testWidgets('nothing is written while nothing is recorded', (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _play(tester, 'e2', 'e4');
      await _press(tester, const Key('annotate-arrow'));
      await _mark(tester, 'g1');
      await _mark(tester, 'f3');
      await _startRecording(tester);
      await _speak(tester, mic, 400);
      await _press(tester, const Key('lesson-recording-discard'));

      // A second take starts clean: what the first heard is not in it.
      await _startRecording(tester);
      await _speak(tester, mic, 600);
      await _saveAs(tester, 'Second');
      final req = server.uploads.single;
      expect(_field(req, 'durationMs'), '600',
          reason: 'the second take counted the first one\'s audio');
      final events = _eventsOf(req);
      expect(events, hasLength(1));
      expect(events.single['data']['fen'], _afterE4);
      expect(events.single['data']['arrows'], [
        {'from': 'g1', 'to': 'f3', 'color': 'G'},
      ]);
    }, variant: windows);

    // Added on grading, 27.9.2026: three ways onto the board the first draft
    // of this gate did not walk.

    testWidgets('„Undo" is a change of marks like any other', (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-square'));
      await _mark(tester, 'd5');
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-undo'));
      expect(_board(tester).squares, isEmpty);
      await _speak(tester, mic, 500);
      await _saveAs(tester, 'Undone');

      final events = _eventsOf(server.uploads.single);
      expect([for (final e in events) e['eventType']],
          ['init', 'arrow_drawn', 'arrow_drawn']);
      expect([for (final e in events) e['timestampMs']], [0, 500, 1000]);
      expect(
          events.last['data'], {'arrows': <Object>[], 'squares': <Object>[]});
    }, variant: windows);

    testWidgets('a move played again brings the marks it already holds',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _play(tester, 'e2', 'e4');
      await _press(tester, const Key('annotate-square'));
      await _mark(tester, 'd5');
      await _tooltip(tester, 'Previous move');
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      // Not a step: the same move, played on the board a second time.
      await _play(tester, 'e2', 'e4');
      expect(_tree(tester).rootNode.children, hasLength(1));
      expect(_board(tester).squares, hasLength(1));
      await _speak(tester, mic, 500);
      await _saveAs(tester, 'Again');

      final events = _eventsOf(server.uploads.single);
      expect([for (final e in events) e['eventType']], ['init', 'move']);
      expect(events.last['data'], {
        'fen': _afterE4,
        'from': 'e2',
        'to': 'e4',
        'squares': [
          {'square': 'd5', 'color': 'G'},
        ],
      });
    }, variant: windows);

    testWidgets('a deleted variation that takes the cursor with it is a step',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _play(tester, 'e2', 'e4');
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      final tree = _tree(tester);
      expect(tree.onDeleteNode, isNotNull);
      tree.onDeleteNode!(tree.activeNode);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_tree(tester).activeNode.fen, _start);
      await _speak(tester, mic, 500);
      await _saveAs(tester, 'Deleted');

      final events = _eventsOf(server.uploads.single);
      expect([for (final e in events) e['eventType']], ['init', 'move']);
      expect([for (final e in events) e['timestampMs']], [0, 500]);
      expect(events.first['data']['fen'], _afterE4);
      expect(events.last['data'], {'fen': _start});
    }, variant: windows);
    testWidgets(
        'a sentence removed, and brought back, is a change of the '
        'marks', (tester) async {
      // Added on grading: removing the open sentence opens the one before it,
      // and „Undo" opens it again — both change what is drawn, and neither
      // was stamped.
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      await _play(tester, 'e2', 'e4');
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-arrow'));
      await _mark(tester, 'g1');
      await _mark(tester, 'f3');
      await _speak(tester, mic, 500);
      await _press(tester, const Key('prep-add-sentence'));
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-clear'));
      await _speak(tester, mic, 500);
      // The open (second) sentence goes: the first, with its arrow, opens.
      await _press(tester, const Key('prep-remove-sentence'));
      await _speak(tester, mic, 500);
      // „Undo" brings the bare second sentence back, open.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await _settle(tester);
      await _speak(tester, mic, 500);
      await _saveAs(tester, 'Removed and back');

      final events = _eventsOf(server.uploads.single);
      expect([
        for (final e in events) e['eventType']
      ], [
        'init', // Record
        'move', // e4
        'arrow_drawn', // g1–f3
        'arrow_drawn', // the second sentence cleared
        'arrow_drawn', // the second removed: the first's arrow is back
        'arrow_drawn', // Undo: the bare second sentence is open again
      ]);
      Map<String, dynamic> data(int i) =>
          Map<String, dynamic>.from(events[i]['data'] as Map);
      expect(data(4)['arrows'], [
        {'from': 'g1', 'to': 'f3', 'color': 'G'},
      ]);
      expect(data(5), {'arrows': <Object>[], 'squares': <Object>[]});
    });

    testWidgets('another sentence opened is a change of the marks',
        (tester) async {
      final server = _Server();
      final (mic, _) = await _open(tester, server);
      await _startRecording(tester);
      await _speak(tester, mic, 500);
      await _play(tester, 'e2', 'e4');
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-arrow'));
      await _mark(tester, 'g1');
      await _mark(tester, 'f3');
      await _speak(tester, mic, 500);
      // A second sentence: it keeps the arrow, so the board does not change.
      await _press(tester, const Key('prep-add-sentence'));
      await _speak(tester, mic, 500);
      await _press(tester, const Key('annotate-clear'));
      await _speak(tester, mic, 500);
      // Back to the first sentence: its arrow is on the board again.
      await _press(tester, const Key('prep-sentence-prev'));
      await _speak(tester, mic, 500);
      await _saveAs(tester, 'Two sentences');

      final events = _eventsOf(server.uploads.single);
      expect([
        for (final e in events) e['eventType']
      ], [
        'init', // Record
        'move', // e4
        'arrow_drawn', // g1–f3
        'arrow_drawn', // the second sentence cleared
        'arrow_drawn', // the first sentence opened again
      ]);
      expect([
        for (final e in events) e['timestampMs']
      ], [
        0,
        500,
        1000,
        2000,
        2500
      ], reason: 'adding a sentence that keeps the marks wrote nothing');
      Map<String, dynamic> data(int i) =>
          Map<String, dynamic>.from(events[i]['data'] as Map);
      expect(data(3), {'arrows': <Object>[], 'squares': <Object>[]});
      expect(data(4), {
        'arrows': [
          {'from': 'g1', 'to': 'f3', 'color': 'G'},
        ],
        'squares': <Object>[],
      });
    });
  });
}
