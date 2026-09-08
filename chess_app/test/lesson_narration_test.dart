import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/speech_text.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// The shape a lesson step is meant to have: one board, a line walked a
/// sentence at a time, and the question about the position it arrives at asked
/// on that same board without anything being reloaded.
///
/// Two rules are pinned here, and both are about *timing* rather than about
/// what is on screen:
///
///  * a move is played once the sentence in front of it has been read out, not
///    on a clock — a board that moves under a voice still speaking leaves the
///    listener hearing about a position that is no longer there;
///  * the step that asks is reached without a reset — same board, same
///    orientation, and all that changes is whose turn it is to act.

/// A synthesiser that reports completion when the test says so.
class FakeTts implements TtsEngine {
  FakeTts({this.instant = false});

  /// Complete each utterance as soon as it starts, for the tests about the
  /// route rather than about the waiting.
  final bool instant;

  final List<String> spoken = [];
  Completer<void>? _pending;

  /// Ends the utterance, the way an engine reporting completion would.
  void finish() {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<List<String>> languages() async => ['en-US'];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> speak(String text) {
    spoken.add(text);
    if (instant) return Future<void>.value();
    final completer = Completer<void>();
    _pending = completer;
    return completer.future;
  }

  @override
  Future<void> stop() async => finish();
}

/// A machine that has a synthesiser and no voice for Serbian — the ordinary
/// state of a Windows install until somebody goes hunting for one.
class VoicelessTts implements TtsEngine {
  // A machine that has voices, but none for the language the app is written
  // in. It said `['en-US']` while the app was Serbian and says `['de-DE']` now
  // — the fixture is "no voice we can use", not "no voice at all", and which
  // tag expresses that changes with the app's own language.
  @override
  Future<List<String>> languages() async => ['de-DE'];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  const startFen = '8/8/8/3k4/8/8/3PK3/8 w - - 0 1';
  const afterKd3 = '8/8/8/3k4/8/3K4/3P4/8 b - - 1 1';
  const afterKc4 = '8/8/8/4k3/8/3K4/3P4/8 w - - 2 2';
  const afterKd6 = '8/8/3k4/8/2K5/8/3P4/8 w - - 4 3';

  // The lesson exactly as the trainer writes it in the studio.
  const kd3Note =
      'Ovde potezom Kd3 beli dovodi crnog u opoziciju primoravajući ga da u '
      'sledećem potezu dozvoli pristup belom kralju nekom od polja e4, d4 ili '
      'c4.';
  const ke5Note = 'Pretpostavimo da crni kralj odigra na e5.';
  const kc4Note = 'Sada beli kralj ide napred sa Kc4.';
  const kd4Note =
      'Posle sekvence poteza beli opet dovodi crnog kralja u opoziciju.';

  const oppositionPgn = '1. Kd3 {$kd3Note [%csl Ge4,Gd4,Gc4]} '
      'Ke5 {$ke5Note} 2. Kc4 {$kc4Note} Kd6 3. Kd4 {$kd4Note}';

  const question = 'Kako beli sada ponovo zauzima opoziciju?';

  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Učenik',
    role: 'ucenik',
  );

  Future<SpeechService> readyService(FakeTts engine) async {
    final service = SpeechService.forTesting(engine);
    await service.init(enabled: true, rate: 0.5, engine: engine);
    expect(service.state, SpeechState.ready);
    return service;
  }

  Future<SpeechService> voicelessService() async {
    final service = SpeechService.forTesting(VoicelessTts());
    await service.init(enabled: true, rate: 0.5, engine: VoicelessTts());
    expect(service.state, SpeechState.noVoice);
    return service;
  }

  AssignmentDetail lesson(List<LessonStep> steps) => AssignmentDetail(
        assignment: Assignment(
          id: 1,
          title: 'Opozicija',
          kind: AssignmentKind.lesson,
          totalItems: steps.length,
        ),
        items: [
          for (var i = 0; i < steps.length; i++)
            AssignmentItem(puzzleId: null, position: i),
        ],
        steps: steps,
      );

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  /// Runs the walk to its end.
  ///
  /// Not `pumpAndSettle`: that returns the moment no frame is scheduled, and a
  /// move waiting out a pause schedules none — so it would report the lesson
  /// finished while it had not started moving.
  Future<void> walkThrough(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> open(
    WidgetTester tester,
    AssignmentDetail detail,
    SpeechService speech,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: LessonViewerScreen(
        session: session,
        detail: detail,
        speech: speech,
      ),
    ));
    await tester.pump();
  }

  group('the line is walked at the speed of the voice', () {
    testWidgets('a move waits for the sentence in front of it to end',
        (tester) async {
      final tts = FakeTts();
      final speech = await readyService(tts);

      await open(
        tester,
        lesson(const [
          LessonStep(title: 'Opozicija', fen: startFen, pgn: oppositionPgn),
        ]),
        speech,
      );

      await tester.tap(find.byTooltip('Play tutorial'));
      await tester.pump();

      // Nothing is written about the position the line starts from, so the
      // first move comes after a pause rather than after a sentence.
      expect(find.text('Move 0 of 5'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump();

      expect(find.text('Move 1 of 5'), findsOneWidget);
      // The service says notation as words — „Kd3" is heard as „kralj d tri" —
      // so the comparison is against what a listener would hear.
      expect(tts.spoken.last, speakable(kd3Note),
          reason: 'the sentence about Kd3 is read with Kd3 on the board');

      // The squares that sentence is about are on the board while it is being
      // said — that is the whole reason the two travel together.
      expect(
        board(tester).squares.map((s) => s.toString()).toList(),
        ['Ge4', 'Gd4', 'Gc4'],
      );

      // And the board does not move on while the voice is still going, however
      // long that takes.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Move 1 of 5'), findsOneWidget,
          reason: 'Ke5 must not be played under the sentence about Kd3');
      expect(tts.spoken.length, 1);

      tts.finish();
      await tester.pump();
      await tester.pump();

      expect(find.text('Move 2 of 5'), findsOneWidget);
      expect(tts.spoken.last, speakable(ke5Note));
      expect(board(tester).squares, isEmpty,
          reason: 'the marks belong to the move they were drawn on');

      tts.finish();
      await tester.pump();
      await tester.pump();

      expect(find.text('Move 3 of 5'), findsOneWidget);
      expect(tts.spoken.last, speakable(kc4Note));

      // Stopping is the reader taking over, and it holds.
      await tester.tap(find.byTooltip('Stop reading'));
      await tester.pump();

      final spokenSoFar = tts.spoken.length;
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Move 3 of 5'), findsOneWidget);
      expect(tts.spoken.length, spokenSoFar,
          reason: 'a stopped walk stays stopped');
    });

    testWidgets('taking the strip ends the walk', (tester) async {
      final tts = FakeTts();
      final speech = await readyService(tts);

      await open(
        tester,
        lesson(const [
          LessonStep(title: 'Opozicija', fen: startFen, pgn: oppositionPgn),
        ]),
        speech,
      );

      await tester.tap(find.byTooltip('Play tutorial'));
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pump();
      expect(find.text('Move 1 of 5'), findsOneWidget);

      // The child decides to go back and look again.
      await tester.tap(find.byTooltip('Prethodni potez'));
      await tester.pump();

      expect(find.text('Move 0 of 5'), findsOneWidget);
      expect(find.byTooltip('Play tutorial'), findsOneWidget,
          reason: 'the walk stopped, so the button offers to start it again');

      final spokenSoFar = tts.spoken.length;
      await tester.pump(const Duration(seconds: 5));
      expect(tts.spoken.length, spokenSoFar);
    });

    testWidgets('a machine with no voice is not offered the button',
        (tester) async {
      // Not a no-op control: where nothing can be read out, the child walks the
      // line with the strip and reads it, and no button promises otherwise.
      final speech = await voicelessService();

      await open(
        tester,
        lesson(const [
          LessonStep(title: 'Opozicija', fen: startFen, pgn: oppositionPgn),
        ]),
        speech,
      );

      expect(find.byTooltip('Play tutorial'), findsNothing);
      expect(find.byTooltip('Sledeći potez'), findsOneWidget,
          reason: 'the line is still there to be walked by hand');
    });
  });

  group('showing turns into asking on the same board', () {
    /// A demonstration that walks to 2...Kd6, and the question about that exact
    /// position.
    AssignmentDetail demoThenQuestion() => lesson(const [
          LessonStep(
            title: 'Opozicija',
            fen: startFen,
            pgn: '1. Kd3 {$kd3Note} Ke5 {$ke5Note} 2. Kc4 {$kc4Note} Kd6',
          ),
          LessonStep(
            title: 'Sada ti',
            fen: afterKd6,
            instruction: question,
            kind: LessonStepKind.askMove,
          ),
        ]);

    testWidgets('the walk carries on through the join and asks the question',
        (tester) async {
      final tts = FakeTts(instant: true);
      final speech = await readyService(tts);

      await open(tester, demoThenQuestion(), speech);

      expect(find.text('1/2'), findsOneWidget);

      await tester.tap(find.byTooltip('Play tutorial'));
      await walkThrough(tester);

      // Nobody pressed „Sledeći korak": the line ran out on a position the next
      // step stands on, so the lesson went on by itself.
      expect(find.text('2/2'), findsOneWidget);
      expect(tts.spoken.last, speakable(question));
      expect(
        tts.spoken,
        containsAllInOrder(
            [speakable(kd3Note), speakable(ke5Note), speakable(kc4Note)]),
      );

      // The same board, now the child's to play on.
      expect(board(tester).isAllowedToMove, isTrue);
      expect(find.text(question), findsOneWidget);
    });

    testWidgets('the board is not turned around at the join', (tester) async {
      // The visible half of "no reset". The question stands on a position with
      // black to move, so recomputing the orientation from the step — which is
      // what every step used to do — would spin the board round under the child
      // at the moment they are asked to answer.
      final tts = FakeTts(instant: true);
      final speech = await readyService(tts);

      await open(
        tester,
        lesson(const [
          LessonStep(
              title: 'Opozicija', fen: startFen, pgn: '1. Kd3 {$kd3Note}'),
          LessonStep(
            title: 'Sada ti',
            fen: afterKd3,
            instruction: 'Kuda crni kralj?',
            kind: LessonStepKind.askMove,
          ),
        ]),
        speech,
      );

      expect(board(tester).boardOrientation, PlayerColor.white);

      await tester.tap(find.byTooltip('Play tutorial'));
      await walkThrough(tester);

      expect(find.text('2/2'), findsOneWidget);
      expect(board(tester).boardOrientation, PlayerColor.white,
          reason: 'the child is looking at the board they just watched');
    });

    testWidgets('and on into a part that opens somewhere else', (tester) async {
      // **This used to stop here**, on the rule that a join is a continuation
      // while a new diagram is a page-turn the child should turn themselves.
      // The trainer met that rule on 7.9.2026 and read it as a bug: they
      // pressed the play button, watched the first part, and reported that the
      // second one „uopšte se ne prikazuje" — „mislio sam da pušta ceo
      // tutorijal kroz sve delove". A ▶ on a tutorial promises the tutorial,
      // and the child this walk exists for is the one listening rather than
      // pressing. What still stops it is a fork, a question, and the end.
      final tts = FakeTts(instant: true);
      final speech = await readyService(tts);

      await open(
        tester,
        lesson(const [
          LessonStep(
              title: 'Opozicija', fen: startFen, pgn: '1. Kd3 {$kd3Note}'),
          LessonStep(
            title: 'Druga pozicija',
            fen: afterKc4,
            instruction: 'Nešto sasvim drugo.',
            kind: LessonStepKind.askMove,
          ),
        ]),
        speech,
      );

      await tester.tap(find.byTooltip('Play tutorial'));
      await walkThrough(tester);

      expect(find.text('2/2'), findsOneWidget);
      expect(tts.spoken, contains(speakable('Nešto sasvim drugo.')),
          reason: 'the part was crossed into and its question read out');
    });

    testWidgets('two demonstrations in a row are one walk', (tester) async {
      // The trainer's own case: two „prikaži" parts, the second starting from
      // a board of its own. Pressing play has to reach the second one — the
      // whole report was that it did not.
      final tts = FakeTts(instant: true);
      final speech = await readyService(tts);

      await open(
        tester,
        lesson(const [
          LessonStep(
              title: 'Prvi deo', fen: startFen, pgn: '1. Kd3 {$kd3Note}'),
          LessonStep(
              title: 'Drugi deo', fen: afterKc4, pgn: '1... Kd6 {$kc4Note}'),
        ]),
        speech,
      );

      await tester.tap(find.byTooltip('Play tutorial'));
      await walkThrough(tester);

      expect(find.text('2/2'), findsOneWidget);
      expect(
          tts.spoken,
          containsAllInOrder([
            speakable(kd3Note),
            speakable(kc4Note),
          ]));
    });

    testWidgets('and the new diagram is not put up under the sentence',
        (tester) async {
      // Crossing to a part that opens elsewhere puts the pieces back, and a
      // board that rearranges itself while a sentence is still being spoken
      // leaves the listener hearing about a position that is no longer there.
      // So the walk waits a beat first — long enough that the step has not
      // changed a frame after the line ran out.
      final tts = FakeTts(instant: true);
      final speech = await readyService(tts);

      // The opening sentence is written on the root on purpose: with an
      // instant voice every sentence resolves in a microtask, so a part whose
      // first beat is *silent* would spend its first 1400 ms in the ordinary
      // wait for a wordless move — and this test would pass whether the beat
      // before the crossing existed or not. A check that cannot fail is not a
      // check.
      await open(
        tester,
        lesson(const [
          LessonStep(
            title: 'Prvi deo',
            fen: startFen,
            pgn: '{Uvod.} 1. Kd3 {$kd3Note}',
          ),
          LessonStep(
              title: 'Drugi deo', fen: afterKc4, pgn: '1... Kd6 {$kc4Note}'),
        ]),
        speech,
      );

      await tester.tap(find.byTooltip('Play tutorial'));
      // Both sentences are read out in microtasks, and then the walk waits
      // before it puts up a board the listener has not been told about.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1/2'), findsOneWidget);
      expect(tts.spoken, contains(speakable(kd3Note)),
          reason: 'the wait being tested is the one after the line ran out, '
              'not the ordinary wait on a move with nothing written about it');

      await walkThrough(tester);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('pressing the step button by hand does not jump either',
        (tester) async {
      // The same rule with the sound off, which is how most of these lessons
      // will actually be read.
      final speech = await voicelessService();

      await open(tester, demoThenQuestion(), speech);

      await tester.tap(find.byTooltip('Idi na kraj'));
      await tester.pump();
      expect(find.text('Move 4 of 4'), findsOneWidget);

      final before = board(tester).boardOrientation;

      await tester.tap(find.text('Next part'));
      await tester.pump();

      expect(find.text('2/2'), findsOneWidget);
      expect(board(tester).boardOrientation, before);
      expect(board(tester).isAllowedToMove, isTrue);
      expect(find.text(question), findsOneWidget);
    });
  });
}
