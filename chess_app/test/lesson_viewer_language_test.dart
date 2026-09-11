// The tutorial screen reads a tutorial in its own language — phase 4 of
// docs/PLAN-JEZIK-GLASA.md.
//
// Driven through the screen a child actually uses, with the machines it runs
// on: Windows with only the Croatian voice, a machine with English and nothing
// else, and a Windows that lists Croatian without having it. The regression
// that matters most is the last group: a tutorial that has not said its
// language — every tutorial saved before this — must be read exactly as it was.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/speech_service.dart';

/// An engine that records which voice read what, completes each sentence at
/// once, and refuses the voices it is told to.
class _Engine implements TtsEngine {
  _Engine(this.installed, {this.refuses = const {}});

  final List<String> installed;
  final Set<String> refuses;
  final spoken = <({String voice, String text})>[];
  String? current;

  @override
  Future<List<String>> languages() async => installed;

  @override
  Future<void> setLanguage(String value) async {
    if (refuses.contains(value)) throw StateError('no voice installed: $value');
    current = value;
  }

  @override
  Future<void> setSpeechRate(double value) async {}

  @override
  Future<void> speak(String text) async =>
      spoken.add((voice: current ?? '?', text: text));

  @override
  Future<void> stop() async {}
}

/// A service that remembers which language the screen asked the reading speed
/// for.
class _AskedRate extends SpeechService {
  _AskedRate(super.engine) : super.forSubclass();

  final askedFor = <String?>[];

  @override
  double charsPerSecondFor(TutorialLanguage? language) {
    askedFor.add(language?.code);
    return super.charsPerSecondFor(language);
  }
}

const startFen = '8/8/8/3k4/8/8/3PK3/8 w - - 0 1';

/// Two moves, each with a sentence naming a move — so the words the voice
/// is handed show which vocabulary said them.
const pgn = '{ Beli počinje. } 1. Kd3 { Posle Kd3 beli drži opoziciju. } '
    'Ke5 { Crni odgovara sa Ke5. } *';

final session = UserSession(
  token: 't',
  id: 1,
  email: 'a@b.c',
  name: 'Student',
  role: 'ucenik',
);

AssignmentDetail tutorial({String? language}) => AssignmentDetail(
      assignment: Assignment(
        id: 1,
        title: 'Opozicija',
        kind: AssignmentKind.lesson,
        totalItems: 1,
      ),
      items: [AssignmentItem(puzzleId: null, position: 0)],
      steps: const [LessonStep(title: 'Opozicija', fen: startFen, pgn: pgn)],
      lessonLanguage: language,
    );

Future<SpeechService> _ready(_Engine engine) async {
  final service = SpeechService.forTesting(engine);
  await service.init(enabled: true, rate: 0.5, engine: engine);
  return service;
}

Future<void> open(
    WidgetTester tester, AssignmentDetail detail, SpeechService speech) async {
  await tester.pumpWidget(MaterialApp(
    home: LessonViewerScreen(session: session, detail: detail, speech: speech),
  ));
  await tester.pump();
}

/// Lets the walk run: each sentence completes at once, and a move with nothing
/// written waits 1400 ms.
Future<void> walk(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

void main() {
  testWidgets(
      'a Serbian tutorial on Windows is read by the Croatian voice, '
      'in Serbian words', (tester) async {
    final engine = _Engine(['en-US', 'hr-HR']);
    final speech = await _ready(engine);
    await open(tester, tutorial(language: 'sr-Latn'), speech);

    await tester.tap(find.byTooltip('Play tutorial'));
    await walk(tester);

    expect(engine.spoken, isNotEmpty);
    expect(engine.spoken.map((s) => s.voice).toSet(), {'hr-HR'},
        reason: 'every sentence of the tutorial, and none in English');
    expect(engine.spoken.map((s) => s.text),
        contains('Posle kralj de tri beli drži opoziciju.'),
        reason: 'the move said with the Serbian vocabulary');
  });

  testWidgets(
      'a Serbian tutorial on an English machine has no play button, '
      'and says why', (tester) async {
    final engine = _Engine(['en-US', 'de-DE']);
    final speech = await _ready(engine);
    await open(tester, tutorial(language: 'sr-Latn'), speech);

    expect(find.byTooltip('Play tutorial'), findsNothing);
    final reason = find.byKey(const Key('tutorial-no-voice'));
    expect(reason, findsOneWidget,
        reason: 'a button that silently vanished would read as a bug');

    await tester.tap(reason);
    await tester.pump();
    expect(find.textContaining('Serbian (Latin)'), findsOneWidget);
    expect(find.textContaining('Croatian voice'), findsOneWidget,
        reason: 'the one install that answers it on Windows');
    expect(engine.spoken, isEmpty);
  });

  testWidgets('a voice that fails on the first sentence stops the walk',
      (tester) async {
    // Windows listed Croatian and had none. Before the check after each
    // sentence, `speak` returned at once and the walk played every move of the
    // tutorial with no wait and no voice.
    final engine = _Engine(['en-US', 'hr-HR'], refuses: {'hr-HR'});
    final speech = await _ready(engine);
    await open(tester, tutorial(language: 'sr-Latn'), speech);

    await tester.tap(find.byTooltip('Play tutorial'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Asked at once: the reason arrives as a SnackBar, which is gone again
    // after a few seconds.
    expect(find.textContaining('no voice for it'), findsOneWidget,
        reason: 'the reader is told why it stopped');

    await walk(tester);
    expect(engine.spoken, isEmpty, reason: 'and nothing in English instead');
    expect(find.byKey(const Key('tutorial-no-voice')), findsOneWidget,
        reason: 'the button now says what the machine turned out to be');
    // The walk did not race ahead: the child is still on the tutorial's
    // opening position, where the sentence that failed was.
    expect(find.text('Posle Kd3 beli drži opoziciju.'), findsNothing);
  });

  testWidgets('the question at the end is read in the tutorial\'s voice too',
      (tester) async {
    // The walk speaks in two places — the sentence on a move, and the question
    // of a part that asks — and both are the trainer's words.
    final engine = _Engine(['en-US', 'hr-HR']);
    final speech = await _ready(engine);
    const question = 'Kuda ide beli kralj?';
    await open(
      tester,
      AssignmentDetail(
        assignment: Assignment(
          id: 1,
          title: 'Opozicija',
          kind: AssignmentKind.lesson,
          totalItems: 2,
        ),
        items: [
          AssignmentItem(puzzleId: null, position: 0),
          AssignmentItem(puzzleId: null, position: 1),
        ],
        steps: const [
          LessonStep(title: 'Opozicija', fen: startFen, pgn: pgn),
          LessonStep(
            title: 'Pitanje',
            fen: '8/8/8/4k3/8/3K4/3P4/8 w - - 2 2',
            kind: LessonStepKind.askMove,
            instruction: question,
          ),
        ],
        lessonLanguage: 'sr-Latn',
      ),
      speech,
    );

    await tester.tap(find.byTooltip('Play tutorial'));
    await walk(tester);

    final asked = engine.spoken.where((s) => s.text == question);
    expect(asked, hasLength(1), reason: 'the walk reached the question');
    expect(asked.single.voice, 'hr-HR');
  });

  testWidgets('the words are written at the speed of the tutorial\'s voice',
      (tester) async {
    // The writing that follows the voice has to ask about the voice that is
    // reading. Asking the Settings voice would time Serbian letters by an
    // English voice's measurements.
    final engine = _Engine(['en-US', 'hr-HR']);
    final speech = _AskedRate(engine);
    await speech.init(enabled: true, rate: 0.5, engine: engine);
    await open(tester, tutorial(language: 'sr-Latn'), speech);

    await tester.tap(find.byTooltip('Play tutorial'));
    await walk(tester);

    expect(speech.askedFor, isNotEmpty);
    expect(speech.askedFor.toSet(), {'sr-Latn'});
  });

  group('a tutorial that has not said its language', () {
    testWidgets('is read by the Settings voice, as before', (tester) async {
      final engine = _Engine(['en-US', 'hr-HR']);
      final speech = await _ready(engine);
      await open(tester, tutorial(), speech);

      await tester.tap(find.byTooltip('Play tutorial'));
      await walk(tester);

      expect(engine.spoken.map((s) => s.voice).toSet(), {'en-US'});
      expect(engine.spoken.map((s) => s.text),
          contains('Posle king d three beli drži opoziciju.'));
    });

    testWidgets('and on a machine with no voice for the app draws nothing',
        (tester) async {
      // Unchanged: the old answer for the old question.
      final engine = _Engine(['de-DE']);
      final speech = await _ready(engine);
      await open(tester, tutorial(), speech);

      expect(find.byTooltip('Play tutorial'), findsNothing);
      expect(find.byKey(const Key('tutorial-no-voice')), findsNothing);
    });
  });

  test('the student\'s screen is told the language by the server', () {
    final detail = AssignmentDetail.fromJson({
      'id': 5,
      'title': 'Opozicija',
      'kind': 'lesson',
      'items': const [],
      'steps': const [],
      'lessonLanguage': 'sr-Cyrl',
    });
    expect(detail.lessonLanguage, 'sr-Cyrl');
    expect(
        AssignmentDetail.fromJson({'id': 5, 'title': 'x', 'kind': 'lesson'})
            .lessonLanguage,
        isNull);
  });
}
