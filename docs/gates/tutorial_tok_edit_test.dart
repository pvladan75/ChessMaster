// The gate for P6b of `docs/PLAN-STUDIO-REDIZAJN.md` — the „Tok" timeline
// becomes the place the tutorial is written, and the fields leave the column.
//
// Written before the batch. It moves to
// `chess_app/test/tutorial_tok_edit_test.dart` in the merge commit.
//
// P6a drew the line. This batch makes it editable and takes the standalone
// fields out of the authoring pane, which is the shape §5 of the plan has had
// from the start: the sentence belongs beside the move it is about, and the
// question belongs where the line runs out.
//
// **It asserts on what gets saved.** P6a could be judged on geometry; this one
// cannot. A panel that draws a sentence in the right box and writes it onto the
// wrong node looks perfect and destroys a trainer's work — so most of what
// follows drives the screen and then reads the single `POST` body, the way
// `tutorial_authoring_test.dart` does and for the same reason.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH 60
//
// **The keys do not move away; they move house.** Twenty-three references across
// five test files drive this screen by key, one of them the frozen gate that
// asserts on the `POST` body. Every one of them keeps working:
//
//   Key('example-sentence')       the comment field **of the current beat's
//                                 card**. It follows the author from card to
//                                 card, so there is always exactly one.
//   Key('beat-comment-<index>')   the comment field of every other card
//   Key('example-kind')           in the question card, under the last beat
//   Key('example-instruction')    same
//   Key('example-choice-<n>')     same
//   Key('example-choice-delete-<n>')  same
//   Key('question-card')          the question card itself, drawn under the
//                                 last beat and nowhere else
//
// A batch that renames any of those has rewritten five test files rather than
// built a feature, and the diff will say so.
//
// **`TutorialFlowPanel` gains two things and stays a renderer:**
//
//   const TutorialFlowPanel({
//     super.key,
//     required this.root,
//     required this.current,
//     required this.onSelect,
//     required this.onCommentChanged,  // void Function(AnalysisNode, String)
//     required this.question,          // Widget — rendered under the last beat
//   });
//
// The `question` slot is a **widget the screen builds and hands in**. The kind,
// the task, the offered answers and the recorded move are per *part*, and they
// live in the screen's own state (`_currentKind`, `_choiceControllers`,
// `_fieldsEpoch`) — moving them into the panel would give the panel a model,
// which is the one thing it must not have.
//
// **A card's field belongs to that card's node.** Typing into the third card
// writes the third node's comment, whichever node the author happens to be
// standing on. That is the whole point of editing in place, and it is also the
// one way this batch can silently destroy work: a card whose controller was
// built for one node and is still on screen for another writes the first
// node's text onto the second. Key each card's state by `beat.node.id` and let
// Flutter tear the state down when the node changes.
//
// **The line re-projects under the fields.** Pressing a fork chip changes which
// nodes the cards are for — the fields must follow, not keep the text of the
// line that was left. Same trap as `_fieldsEpoch`, one layer out.
//
// **Nothing new is said.** No new user-facing string: every sentence on this
// screen already exists, and the fields keep the labels they have („Komentar za
// trenutni potez" moves with its field). The only new literals are the two keys
// above.
//
// **Not this batch:** arrows and squares (P7), the four refusals and retiring
// the old step editor (P8). `beatsOf`, `AnalysisNode`, the model, the save
// routing, `TutorialSectionsPanel` and the P5b layout are all frozen.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_flow_panel.dart';
import 'package:chess_app/models/user_session.dart';

class _RecordingApi extends LessonApiService {
  _RecordingApi._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> saves;

  /// Every request that carried a `positionList`, whichever verb it used.
  ///
  /// A tutorial opened from the server already has an id, so the save is a
  /// `PUT` to that lesson and not a `POST` to `/lessons/save` — P3a's whole
  /// point is that one button works twice. The first version of this file
  /// listened for the `POST` only and read „nothing was saved" over a save
  /// that had happened.
  factory _RecordingApi() {
    final saves = <Map<String, dynamic>>[];
    return _RecordingApi._(
      saves,
      MockClient((req) async {
        if (req.body.isNotEmpty) {
          final body = jsonDecode(req.body);
          if (body is Map && body.containsKey('positionList')) {
            saves.add(Map<String, dynamic>.from(body));
          }
        }
        return http.Response(jsonEncode({'id': 77}), 201);
      }),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  final session = UserSession(
    token: 't',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  Map<String, dynamic> lessonOf(String pgn, String kind) => {
        'id': 31,
        'title': 'Otvaranje',
        'position_list': [
          {
            'fen': startFen,
            'title': 'Deo 1',
            'pgn': pgn,
            'kind': kind,
            if (kind == 'ask_choice') 'instruction': 'Šta beli postiže?',
          },
        ],
      };

  Future<_RecordingApi> open(WidgetTester tester,
      {String pgn = '1. e4 e5 2. Nf3', String kind = 'show'}) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final api = _RecordingApi();
    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(lessonOf(pgn, kind)),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();
    return api;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> typeIn(WidgetTester tester, String key, String text) async {
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pumpAndSettle();
  }

  /// The one thing that leaves this screen. Everything below that matters is
  /// read out of it rather than off the widgets that produced it.
  Future<List<Map<String, dynamic>>> save(
      WidgetTester tester, _RecordingApi api) async {
    await tester.tap(find.text('Sačuvaj tutorijal'));
    await tester.pumpAndSettle();
    expect(api.saves, hasLength(1), reason: 'one tutorial is one write');
    return (api.saves.single['positionList'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  group('the sentence is written where it is read', () {
    testWidgets('typing into a card writes that card\'s node', (tester) async {
      // The one that matters, and the reason this file asserts on the request.
      // The author is standing on the last move and edits the *second* card.
      // A panel that draws the text in the right box and writes it onto the
      // node the author happens to be standing on looks perfect on screen and
      // quietly moves a trainer's sentence onto the wrong move.
      final api = await open(tester);

      await typeIn(tester, 'beat-comment-1', 'Beli zauzima centar.');

      final list = await save(tester, api);
      final pgn = list.single['pgn'].toString();

      expect(pgn, contains('Beli zauzima centar.'));
      expect(pgn.indexOf('Beli zauzima centar.'), lessThan(pgn.indexOf('e5')),
          reason: 'the sentence was stored against a later move than the card '
              'it was typed into');

      await close(tester);
    });

    testWidgets('the current beat keeps the key the rest of the suite uses',
        (tester) async {
      final api = await open(tester);

      expect(find.byKey(const Key('example-sentence')), findsOneWidget,
          reason: 'twenty-three references in five files drive this screen by '
              'that key, one of them the gate that asserts on the POST body');

      await typeIn(tester, 'example-sentence', 'Ovde stojim.');
      final list = await save(tester, api);

      expect(list.single['pgn'].toString(), contains('Ovde stojim.'));

      await close(tester);
    });

    testWidgets('the key follows the author from card to card', (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key('beat-1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('example-sentence')), findsOneWidget,
          reason: 'two fields with that key is two answers to „where does a '
              'sentence typed now go"');
      expect(
          find.descendant(
              of: find.byKey(const Key('beat-1')),
              matching: find.byKey(const Key('example-sentence'))),
          findsOneWidget,
          reason: 'the field did not follow the author onto the card they '
              'chose');

      await close(tester);
    });

    testWidgets('a card shows the sentence its node already carries',
        (tester) async {
      await open(tester, pgn: '1. e4 {Beli zauzima centar.} e5');

      expect(
          find.descendant(
              of: find.byKey(const Key('beat-1')),
              matching: find.widgetWithText(
                  TextField, 'Beli zauzima centar.')),
          findsOneWidget,
          reason: 'the comment travelled in the pgn and belongs in the field '
              'of the move it was written about');

      await close(tester);
    });

    testWidgets('re-projecting takes the fields with it', (tester) async {
      // The `_fieldsEpoch` trap, one layer out: the cards are rebuilt for other
      // nodes, and a controller built for the line that was left would put the
      // old sentence in front of the author — who would then type over it.
      await open(tester,
          pgn: '1. e4 e5 {Klasičan odgovor.} (1... c5 {Sicilijanka.} 2. Nf3) '
              '2. Nc3');

      expect(find.widgetWithText(TextField, 'Klasičan odgovor.'),
          findsOneWidget);

      await tester.tap(find.text('1... c5').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Sicilijanka.'), findsOneWidget,
          reason: 'the fields did not follow the branch that was chosen');
      expect(find.widgetWithText(TextField, 'Klasičan odgovor.'), findsNothing,
          reason: 'the sentence of the line that was left is still in a field, '
              'waiting to be typed over onto a node it does not belong to');

      await close(tester);
    });
  });

  group('the question is asked where the line runs out', () {
    testWidgets('the question card is under the last beat, and only there',
        (tester) async {
      await open(tester);

      expect(find.byKey(const Key('question-card')), findsOneWidget);
      expect(find.byKey(const Key('example-kind')), findsOneWidget);

      final lastCard = tester.getRect(find.byKey(const Key('beat-3')));
      final question = tester.getRect(find.byKey(const Key('question-card')));
      expect(question.top, greaterThanOrEqualTo(lastCard.top),
          reason: 'the question is asked when the line has run out, so it '
              'belongs under the beat where that happens');

      await close(tester);
    });

    testWidgets('the question still reaches the server', (tester) async {
      final api = await open(tester, pgn: '1. e4');

      await tester.tap(find.byKey(const Key('example-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Traži odgovor iz liste').last);
      await tester.pumpAndSettle();
      await typeIn(tester, 'example-instruction', 'Šta beli postiže?');
      await tester.tap(find.text('Dodaj odgovor'));
      await tester.pumpAndSettle();
      await typeIn(tester, 'example-choice-0', 'Zauzima centar.');
      await tester.tap(find.byType(Radio<int>).first);
      await tester.pumpAndSettle();

      final list = await save(tester, api);

      expect(list.single['kind'], 'ask_choice');
      expect(list.single['instruction'], 'Šta beli postiže?');
      expect(list.single['choices'], [
        {'text': 'Zauzima centar.', 'correct': true},
      ]);

      await close(tester);
    });
  });

  group('the fields have left the column', () {
    testWidgets('every field the author types in is inside the timeline',
        (tester) async {
      // A question step, because „Zadatak za učenika" is drawn only when the
      // part asks something — demanding it on a `show` part would be demanding
      // a field that is correctly absent.
      await open(tester, kind: 'ask_choice');

      for (final key in const [
        'example-sentence',
        'example-kind',
        'example-instruction',
      ]) {
        expect(
            find.descendant(
                of: find.byType(TutorialFlowPanel),
                matching: find.byKey(Key(key))),
            findsOneWidget,
            reason: '$key is still drawn beside the timeline instead of in '
                'it — the column was supposed to lose its fields');
      }

      await close(tester);
    });

    testWidgets('the pane above the tabs is the parts panel and nothing else',
        (tester) async {
      await open(tester);

      final tabs = tester.getRect(find.byKey(const Key('tok-tab')));
      final sentence = tester.getRect(find.byKey(const Key('example-sentence')));
      expect(sentence.top, greaterThan(tabs.top),
          reason: 'a field left above the tabs is a second place to write the '
              'same sentence');

      await close(tester);
    });
  });
}
