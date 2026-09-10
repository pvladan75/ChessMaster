// The recording screen — phases 1 and 2 of `docs/PLAN-SNIMANJE.md`, driven
// through its own controls with a fake microphone, a fake player and a real
// directory.
//
// What it must never do:
//
//   * put a beat anywhere but where the audio is when Space is pressed;
//   * let a held key, or a clicked control, turn Space into anything but „next";
//   * keep half a take, or let the trainer leave in the middle of one unasked;
//   * show a take whose markers and audio disagree as if nothing were wrong.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_narration_screen.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_player.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _pgn = '{ White takes the centre. } 1. e4 { Black answers. } e5 '
    '{ The knight comes out. } 2. Nf3';

/// 80 ms of audio.
Uint8List chunkOf({int peak = 8000}) {
  final data = ByteData(2560);
  for (var i = 0; i < 2560; i += 2) {
    data.setInt16(i, (i ~/ 2).isEven ? peak : -peak, Endian.little);
  }
  return data.buffer.asUint8List();
}

class FakeSource implements PcmSource {
  final controller = StreamController<Uint8List>();
  final calls = <String>[];

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> start() async => controller.stream;

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async {}
}

class FakePlayer implements NarrationPlayer {
  final positionsController = StreamController<Duration>.broadcast();
  final completedController = StreamController<void>.broadcast();
  String? playing;

  @override
  Stream<Duration> get positions => positionsController.stream;

  @override
  Stream<void> get completed => completedController.stream;

  @override
  Future<void> play(String path) async => playing = path;

  @override
  Future<void> stop() async => playing = null;

  @override
  Future<void> dispose() async {}
}

TutorialDraft draftOf({String pgn = _pgn}) {
  final read = readStepTree(fen: _start, pgn: pgn);
  return TutorialDraft(
    lessonId: 31,
    title: 'Centre',
    sections: [
      TutorialSection(
          root: read.root, title: 'Part', kind: LessonStepKind.show),
    ],
  );
}

class Rig {
  Rig(this.dir, {this.stopAtMs = narrationStopAtMs})
      : store = NarrationTakeStore(() async => dir);
  final Directory dir;
  final int stopAtMs;
  final NarrationTakeStore store;
  final source = FakeSource();
  final player = FakePlayer();

  Widget screen() => TutorialNarrationScreen(
        lessonId: 31,
        title: 'Centre',
        draft: draftOf(),
        sourceFactory: () => source,
        store: store,
        player: player,
        stopAtMs: stopAtMs,
      );

  List<FileSystemEntity> filesLeft() {
    final lesson = Directory('${dir.path}${Platform.pathSeparator}lesson_31');
    return lesson.existsSync() ? lesson.listSync() : const [];
  }
}

Future<Rig> open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final dir = Directory.systemTemp.createTempSync('narration_screen_');
  addTearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {
      // A file the test left open on Windows; the temp directory is the OS's.
    }
  });

  final rig = Rig(dir);
  await tester.pumpWidget(MaterialApp(home: rig.screen()));
  await tester.pumpAndSettle();
  return rig;
}

Future<void> deliver(WidgetTester tester, Rig rig, int chunks,
    {int peak = 8000}) async {
  for (var i = 0; i < chunks; i++) {
    rig.source.controller.add(chunkOf(peak: peak));
    await tester.pump();
  }
}

Future<void> startRecording(WidgetTester tester, Rig rig) async {
  await tester.tap(find.byKey(const Key('narration-record')));
  await tester.pumpAndSettle();
}

String beatLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('narration-beat'))).data!;

String statusOf(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('narration-status'))).data!;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    await TutorialDraftService.instance.clear();
  });

  testWidgets('Space puts the next beat on screen where the audio is',
      (tester) async {
    final rig = await open(tester);
    expect(beatLabel(tester), 'Beat 1 of 4 · Part 1');

    await startRecording(tester, rig);
    await deliver(tester, rig, 5); // 400 ms
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(beatLabel(tester), 'Beat 2 of 4 · Part 1');
    expect(find.text('Black answers.'), findsOneWidget);

    await deliver(tester, rig, 2);
    await tester.tap(find.byKey(const Key('narration-stop')));
    await tester.pumpAndSettle();

    final kept = (await rig.store.load(31)).stored!;
    expect(kept.take.markersMs, [0, 400]);
    expect(kept.take.durationMs, 560);
    expect(find.textContaining('2 of 4 beats'), findsOneWidget);
    expect(find.textContaining('It stops at beat 2 of 4'), findsOneWidget,
        reason: 'a take that does not reach the last beat says so');
  });

  testWidgets('a key held down is one beat, however long it is held',
      (tester) async {
    final rig = await open(tester);
    await startRecording(tester, rig);
    await deliver(tester, rig, 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    // The clock moves while the key is still down, so only the binding's own
    // refusal of repeats can stop the next beat here.
    await deliver(tester, rig, 2);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await deliver(tester, rig, 2);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(beatLabel(tester), 'Beat 2 of 4 · Part 1');
  });

  testWidgets('after clicking a control, Space still means the next beat',
      (tester) async {
    final rig = await open(tester);
    await startRecording(tester, rig);
    await deliver(tester, rig, 3);

    await tester.tap(find.byKey(const Key('narration-pause')));
    await tester.pumpAndSettle();
    expect(statusOf(tester), startsWith('Paused'));

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(beatLabel(tester), 'Beat 2 of 4 · Part 1',
        reason: 'a beat advanced in a pause lands on the seam');
    expect(statusOf(tester), startsWith('Paused'),
        reason: 'Space pressed the Resume button instead of advancing');
    expect(rig.source.calls, isNot(contains('resume')));
  });

  testWidgets('a take started from the keyboard still hears Space',
      (tester) async {
    final rig = await open(tester);

    // Focus on the Record button itself, where Tab leaves it. Starting the take
    // removes that button, and a removed button's focus can fall to the route —
    // above the binding that hears Space.
    Focus.of(tester.element(find.text('Record'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('narration-status')), findsOneWidget,
        reason: 'Enter on the focused Record button starts a take');

    await deliver(tester, rig, 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(beatLabel(tester), 'Beat 2 of 4 · Part 1');
  });

  testWidgets('a muted microphone is said while recording, not after',
      (tester) async {
    final rig = await open(tester);
    await startRecording(tester, rig);

    await deliver(tester, rig, 30, peak: 1); // 2.4 s of digital silence
    expect(find.byKey(const Key('narration-silent')), findsNothing,
        reason: 'under three seconds is not yet worth a warning');

    await deliver(tester, rig, 10, peak: 1); // 3.2 s
    expect(find.byKey(const Key('narration-silent')), findsOneWidget);

    await deliver(tester, rig, 1); // the microphone comes back
    expect(find.byKey(const Key('narration-silent')), findsNothing);
  });

  testWidgets('a kept take is there when the screen is opened again',
      (tester) async {
    final rig = await open(tester);
    await startRecording(tester, rig);
    await deliver(tester, rig, 4);
    await tester.tap(find.byKey(const Key('narration-stop')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: rig.screen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 of 4 beats'), findsOneWidget);
    expect(find.byKey(const Key('narration-listen')), findsOneWidget);
    expect(find.text('Record again'), findsOneWidget);
  });

  group('a take already on the device', () {
    Future<StoredNarration> keepTake(Rig rig,
        {List<int> markers = const [0, 400, 600, 700],
        int eventCount = 4}) async {
      final path = await rig.store.newRecordingPath(31);
      final sink = WavFileSink(path);
      for (var i = 0; i < 10; i++) {
        sink.add(chunkOf());
      }
      await sink.finish();
      return rig.store.keep(
        31,
        NarrationTake(
          markersMs: markers,
          durationMs: 800,
          eventCount: eventCount,
          peakDbfs: -12,
          recordedAt: DateTime(2026, 9, 10, 14, 2),
        ),
        path,
      );
    }

    testWidgets('listening moves the board with the audio', (tester) async {
      final rig = await open(tester);
      final stored = await keepTake(rig);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: rig.screen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('narration-listen')));
      await tester.pumpAndSettle();
      expect(rig.player.playing, stored.audioPath);

      rig.player.positionsController.add(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(beatLabel(tester), 'Beat 2 of 4 · Part 1');

      rig.player.positionsController.add(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(beatLabel(tester), 'Beat 3 of 4 · Part 1');

      rig.player.completedController.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('narration-listen')), findsOneWidget);
    });

    testWidgets('a take recorded against other beats says so', (tester) async {
      final rig = await open(tester);
      await keepTake(rig, markers: [0, 400, 600], eventCount: 3);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: rig.screen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('the tutorial had 3 beats'), findsOneWidget);
    });

    testWidgets('a take whose audio disagrees is reported gone, not absent',
        (tester) async {
      final rig = await open(tester);
      final stored = await keepTake(rig);
      // Different audio under the same markers.
      final other = WavFileSink(stored.audioPath)..add(chunkOf());
      await other.finish();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: rig.screen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('narration-unreadable')), findsOneWidget);
      expect(find.byKey(const Key('narration-listen')), findsNothing);
    });
  });

  testWidgets('Discard keeps nothing', (tester) async {
    final rig = await open(tester);
    await startRecording(tester, rig);
    await deliver(tester, rig, 4);

    await tester.tap(find.byKey(const Key('narration-discard')));
    await tester.pumpAndSettle();

    expect(rig.filesLeft(), isEmpty);
    expect((await rig.store.load(31)).stored, isNull);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('leaving in the middle of a take asks, and then keeps nothing',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('narration_leave_');
    final rig = Rig(dir);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => rig.screen())),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await startRecording(tester, rig);
    await deliver(tester, rig, 4);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this recording?'), findsOneWidget);
    expect(find.byType(TutorialNarrationScreen), findsOneWidget,
        reason: 'nothing is left until the trainer says so');

    await tester.tap(find.byKey(const Key('narration-leave')));
    await tester.pumpAndSettle();

    expect(find.byType(TutorialNarrationScreen), findsNothing);
    expect(rig.filesLeft(), isEmpty);
  });

  testWidgets('a take stops itself before the cap, and is kept whole',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final dir = Directory.systemTemp.createTempSync('narration_cap_');
    // The real cap is fifteen minutes; the rule is the same at 800 ms.
    final rig = Rig(dir, stopAtMs: 800);
    await tester.pumpWidget(MaterialApp(home: rig.screen()));
    await tester.pumpAndSettle();

    await startRecording(tester, rig);
    await deliver(tester, rig, 9); // 720 ms
    expect(find.byKey(const Key('narration-status')), findsOneWidget);

    await deliver(tester, rig, 1); // 800 ms
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('narration-status')), findsNothing,
        reason: 'the take is still running past the cap');
    final kept = (await rig.store.load(31)).stored!;
    expect(kept.take.durationMs, 800);
    expect(find.textContaining('is the most one recording may be'),
        findsOneWidget);
  });

  test('the last minute is counted down, and nothing before it', () {
    expect(narrationRemainingText(0, narrationStopAtMs), '');
    expect(narrationRemainingText(narrationStopAtMs - 60001, narrationStopAtMs),
        '');
    expect(narrationRemainingText(narrationStopAtMs - 60000, narrationStopAtMs),
        ' · 60 s left');
    expect(narrationRemainingText(narrationStopAtMs - 41500, narrationStopAtMs),
        ' · 42 s left');
    expect(narrationRemainingText(narrationStopAtMs, narrationStopAtMs),
        ' · 0 s left');
    expect(narrationStopAtMs, lessThan(narrationMaxMs),
        reason: 'a take stopped at the cap can end a chunk past it');
  });

  testWidgets('a screen torn down in the middle of a take keeps nothing',
      (tester) async {
    final rig = await open(tester);
    await startRecording(tester, rig);
    await deliver(tester, rig, 4);
    expect(rig.filesLeft(), isNotEmpty, reason: 'the take is being written');

    // Not the back button — the route simply goes, as a closed window does.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(rig.filesLeft(), isEmpty,
        reason: 'half a recording must not outlive the screen that made it');
  });

  testWidgets('a take is stamped with the beats it was recorded against',
      (tester) async {
    // Phase 5. Without this the take on disk says only how many beats there
    // were, and a rewritten sentence leaves that number exactly where it was.
    final rig = await open(tester);
    await startRecording(tester, rig);
    await deliver(tester, rig, 4);
    await tester.tap(find.byKey(const Key('narration-stop')));
    await tester.pumpAndSettle();

    final kept = (await rig.store.load(31)).stored!;
    expect(kept.take.signature, filmSignatureOf(filmBeatsOf(draftOf())));
  });

  testWidgets('an edited tutorial says so over the take it no longer follows',
      (tester) async {
    final rig = await open(tester);
    await startRecording(tester, rig);
    // All four beats, so nothing but the signature can be wrong with it.
    for (var beat = 0; beat < 3; beat++) {
      await deliver(tester, rig, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
    }
    await deliver(tester, rig, 2);
    await tester.tap(find.byKey(const Key('narration-stop')));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 of 4 beats'), findsOneWidget);
    expect(find.textContaining('has been edited'), findsNothing,
        reason: 'the take was just made against these very beats');

    // The screen closed and opened again on an edited tutorial: the same four
    // beats, one of them about something else, which is exactly what no count
    // can see. Closed first because the take is read on the way in — and
    // because `_stops` is fixed when the screen is built, as it is in the app,
    // where this screen is always pushed fresh.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(MaterialApp(
      home: TutorialNarrationScreen(
        lessonId: 31,
        title: 'Centre',
        draft:
            draftOf(pgn: _pgn.replaceFirst('Black answers.', 'Black is fine.')),
        sourceFactory: () => rig.source,
        store: rig.store,
        player: rig.player,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('4 of 4 beats'), findsOneWidget,
        reason: 'the count is unchanged, which is the point');
    expect(find.textContaining('has been edited since this was recorded'),
        findsOneWidget);
  });

  group('the door in the studio', () {
    final session = UserSession(
      token: 'tok',
      id: 7,
      email: 'a@b.c',
      name: 'Trener',
      role: 'trener',
    );
    final api = LessonApiService(
      authToken: 'tok',
      client: MockClient((_) async => http.Response('{}', 404)),
    );

    Future<void> openStudio(WidgetTester tester, TutorialEntry entry,
        {NarrationTakeStore? store}) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: TutorialStudioScreen(
            session: session,
            entry: entry,
            lessonApi: api,
            narrationStore: store),
      ));
      await tester.pumpAndSettle();
    }

    /// The saved tutorial the banner tests are written against: four beats,
    /// lesson 41.
    TutorialEntry savedEntry({String pgn = _pgn}) => TutorialEntry.saved({
          'id': 41,
          'title': 'Centre',
          'position_list': [
            {
              'id': 's1',
              'fen': _start,
              'title': 'Part',
              'kind': 'show',
              'pgn': pgn,
            },
          ],
        });

    /// Puts a finished take of [draft]'s beats in [store], for lesson 41.
    Future<void> keepTakeOf(NarrationTakeStore store,
        {required TutorialDraft draft, int peak = 8000}) async {
      final path = await store.newRecordingPath(41);
      final sink = WavFileSink(path);
      for (var i = 0; i < 10; i++) {
        sink.add(chunkOf(peak: peak));
      }
      await sink.finish();
      final beats = filmBeatsOf(draft);
      await store.keep(
        41,
        NarrationTake(
          markersMs: [for (var i = 0; i < beats.length; i++) i * 100],
          durationMs: 800,
          eventCount: beats.length,
          peakDbfs: peak == 0 ? -96 : -12,
          recordedAt: DateTime(2026, 9, 10),
          signature: filmSignatureOf(beats),
        ),
        path,
      );
    }

    /// A store of its own, in a real directory that goes with the test.
    NarrationTakeStore storeIn(WidgetTester tester) {
      final dir = Directory.systemTemp.createTempSync('studio_banner_');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {
          // A handle Windows still holds; the temp directory is the OS's.
        }
      });
      return NarrationTakeStore(() async => dir);
    }

    /// A store already holding a finished take of [draft].
    Future<NarrationTakeStore> takeOf(WidgetTester tester,
        {required TutorialDraft draft}) async {
      final store = storeIn(tester);
      await keepTakeOf(store, draft: draft);
      return store;
    }

    testWidgets('an unsaved tutorial is told to save first', (tester) async {
      await openStudio(tester, const TutorialEntry.blank('Nov'));
      await tester.tap(find.byKey(const Key('record-narration')));
      await tester.pumpAndSettle();

      expect(find.text('Save the tutorial first, then record it.'),
          findsOneWidget);
      expect(find.byType(TutorialNarrationScreen), findsNothing);
    });

    testWidgets('a take that still follows the tutorial says nothing',
        (tester) async {
      // The banner is a warning, and one that is up whenever a recording exists
      // is a warning nobody reads.
      final store = await takeOf(tester, draft: draftOf());
      await openStudio(tester, savedEntry(), store: store);

      expect(find.byKey(const Key('narration-stale-banner')), findsNothing);
    });

    testWidgets('an edited tutorial says so where it was edited',
        (tester) async {
      // Phase 5's whole point: the screen that caused it is the screen that can
      // undo it. At the export this could only ever be a refusal.
      final store = await takeOf(tester, draft: draftOf());
      await openStudio(
        tester,
        savedEntry(pgn: _pgn.replaceFirst('Black answers.', 'Black is fine.')),
        store: store,
      );

      expect(find.byKey(const Key('narration-stale-banner')), findsOneWidget);
      expect(find.textContaining('has been edited'), findsOneWidget);
      expect(find.byKey(const Key('narration-stale-record')), findsOneWidget);
      expect(find.byKey(const Key('narration-stale-export')), findsOneWidget);
    });

    testWidgets('a beat added is named as a count, and the door still opens',
        (tester) async {
      final store = await takeOf(tester, draft: draftOf());
      await openStudio(tester, savedEntry(pgn: '$_pgn { And on. } Nc6'),
          store: store);

      expect(
          find.textContaining('had 4 beats, and it has 5 now'), findsOneWidget);
      await tester.tap(find.byKey(const Key('narration-stale-record')));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialNarrationScreen), findsOneWidget);
    });

    testWidgets('with no take on this device there is no banner',
        (tester) async {
      final dir = Directory.systemTemp.createTempSync('studio_banner_none_');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {
          // As above.
        }
      });
      await openStudio(tester, savedEntry(),
          store: NarrationTakeStore(() async => dir));

      expect(find.byKey(const Key('narration-stale-banner')), findsNothing);
    });

    testWidgets(
        'a silent take is for the recording screen to say, not this one',
        (tester) async {
      // The banner is about what editing did, and it is drawn beside the
      // controls that did it. A microphone that was muted is neither this
      // screen's doing nor something it can put right, and a warning here for
      // it would be a warning the trainer cannot act on where they are.
      final store = storeIn(tester);
      await keepTakeOf(store, draft: draftOf(), peak: 0);
      await openStudio(tester, savedEntry(), store: store);

      expect(find.byKey(const Key('narration-stale-banner')), findsNothing);
    });

    testWidgets('recording again answers the banner', (tester) async {
      // The take is read on the way in, and a screen that never reads it again
      // leaves the trainer looking at a warning they have just dealt with —
      // which teaches them to ignore the next one.
      final store = await takeOf(tester, draft: draftOf());
      final edited = _pgn.replaceFirst('Black answers.', 'Black is fine.');
      await openStudio(tester, savedEntry(pgn: edited), store: store);
      expect(find.byKey(const Key('narration-stale-banner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('narration-stale-record')));
      await tester.pumpAndSettle();
      expect(find.byType(TutorialNarrationScreen), findsOneWidget);

      // What the recording screen would leave behind, without a microphone in
      // the test: a take of the beats as they are now.
      await keepTakeOf(store, draft: draftOf(pgn: edited));
      Navigator.of(tester.element(find.byType(TutorialNarrationScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('narration-stale-banner')), findsNothing);
    });

    testWidgets('a saved tutorial opens the recording screen', (tester) async {
      await openStudio(
        tester,
        const TutorialEntry.saved({
          'id': 41,
          'title': 'Centre',
          'position_list': [
            {
              'id': 's1',
              'fen': _start,
              'title': 'Part',
              'kind': 'show',
              'pgn': _pgn
            },
          ],
        }),
      );
      await tester.tap(find.byKey(const Key('record-narration')));
      await tester.pumpAndSettle();

      final screen = tester.widget<TutorialNarrationScreen>(
          find.byType(TutorialNarrationScreen));
      expect(screen.lessonId, 41);
      expect(screen.draft.sections, hasLength(1));
    });
  });
}
