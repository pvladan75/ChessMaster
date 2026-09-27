// The gate for phase 6 of `docs/PLAN-PRIPREMA.md`, third half — the editor:
// several sentences on one position, written in the Tutorial Studio (desktop
// and phone) and in Preparation's comment box.
//
// Drafted by the lead on 27.9.2026, after the owner accepted the five
// recommendations of the sketch („Slažem se sa svih pet preporuka" — D16;
// `docs/skice/taktovi.html`). It moves to `chess_app/test/sentence_editor_test.dart`
// when the phase is briefed. It stands on the contract of
// `node_beats_test.dart` (`NodeBeat`, `beats`, `addBeat`, `removeBeatAt`) and
// of `tutorial_beats_film_test.dart` (`beatsOf(…, currentAt:)`,
// `TutorialBeat.at` / `of`), and reads what it saved back through
// `readStepTree` — **what is stored is the judge, not what is drawn**.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT
//
// Words the trainer reads: a **sentence**. Code: a **beat**. They are the same
// thing (D4).
//
// **One home for „a new sentence"** (D16 B): the model's
//
//     NodeBeat addBeat({int? after, bool keepMarks = false})
//
// with `keepMarks` copying the arrows and squares of the beat it follows —
// its own lists, never shared. Both screens call it; neither copies marks by
// hand.
//
// **Which sentence is open** belongs to where the author stands:
//
//   TutorialSection.cursorAt   int, beside `cursorNode`; kept in the draft's
//                              JSON as „cursorAt", absent when 0, so an undo
//                              comes back to the sentence it left
//   TutorialDraftController
//     int get cursorAt                  clamped to the cursor's beats
//     NodeBeat get openBeat             the cursor's beat [cursorAt]
//     void selectBeat(AnalysisNode node, int at)
//     void addSentence()                after the open one, keepMarks, opens
//                                       it; one undo step
//     bool removeSentence(AnalysisNode node, int at)
//                                       false for a position's only one; the
//                                       one before it opens (or the new
//                                       first); one undo step
//     void setComment(AnalysisNode node, String text,
//         {int at = 0, bool typing = false})
//   `jumpTo(node)` opens the node's first sentence. The move strip walks
//   moves, as today; sentences are walked by their cards, ‹ › and „·2".
//
// **The board draws the open sentence's marks, and a mark drawn goes to it**
// — on every screen here. Nothing reads `node.arrows` / `node.squares` for the
// board any more, because that is the first sentence.
//
// **`TutorialFlowPanel`** stays a renderer:
//
//   currentAt           int, default 0
//   onSelect            void Function(AnalysisNode node, int at)
//   onCommentChanged    void Function(AnalysisNode node, int at, String text)
//   onAddSentence       VoidCallback?        — drawn on the open card only
//   onRemoveSentence    void Function(AnalysisNode node, int at)?
//
// **Keys** — every key the suite already uses stays where it is:
//
//   Key('beat-<index>')             a position's first card, as today
//   Key('beat-<index>.<at>')        its later ones (at ≥ 1)
//   Key('example-sentence')         the open card's field, as today
//   Key('beat-comment-<index>')     another first card's field, as today
//   Key('beat-comment-<index>.<at>') another later card's field
//   Key('beat-current')             the ring, on the open card only
//   Key('beat-delete-<index>')      „Delete this move", on the first card
//   Key('add-sentence')             „Add a sentence here", open card only
//   Key('remove-sentence-<index>.<at>')  ✕, tooltip „Remove this sentence",
//                                   on every card of a position with more
//                                   than one sentence — the first as `.0`
//
//   phone:  Key('phone-add-sentence'), Key('phone-remove-sentence'),
//           Key('phone-sentence-prev'), Key('phone-sentence-next') — the last
//           three only where the position has more than one sentence; the
//           two arrows are `IconButton`s, null `onPressed` at either end
//   Preparation: Key('prep-add-sentence'), Key('prep-remove-sentence'),
//           Key('prep-sentence-prev'), Key('prep-sentence-next'), the same
//           way; nothing is added on the starting position, whose comment is
//           switched off there as today
//
// **Copy**:
//
//   'Add a sentence here'                     the button, in words (D16 A)
//   'Remove this sentence'                    the ✕'s tooltip; the phone's
//                                             button reads it in words
//   '<n> of <m>'                              on each card of a position with
//                                             more than one, e.g. „2 of 2"
//   '·<n>'                                    the phone row's chip for a
//                                             later sentence, e.g. „·2"
//   'Comment on <move> · sentence <n> of <m>' the phone's Line tab, where
//                                             there is more than one
//   'Comment for <move> · sentence <n> of <m>' Preparation's, likewise
//   'Sentence removed.' + action 'Undo'       Preparation only — it has no
//                                             undo of its own (D16 C, the
//                                             lead's reading)
//
// Where a position has one sentence, every one of those screens reads as
// today, word for word.
//
// **„then plays" and the branch chips stand under a position's last
// sentence** — where the film moves on — and „Delete this move" on its
// first, because the move belongs to the position.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/preparation/screens/preparation_screen.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

final _android = TargetPlatformVariant.only(TargetPlatform.android);

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _first = 'The bishop goes straight for that knight.';
const _second = 'Because the knight on c6 is what defends e5.';

/// Positions on the line, by the index the Flow panel keys them with: 0 the
/// start, 1 e4, 2 e5, 3 Nf3, 4 Nc6, **5 Bb5 with two sentences**, 6 a6.
const _pgn = '1. e4 e5 2. Nf3 Nc6 3. Bb5 { $_first [%cal Gb5c6] } '
    '{ $_second [%cal Oc6e5] [%csl Re5] } 3... a6 *';

final _session = UserSession(
    token: 't', id: 7, email: 'a@b.c', name: 'Trainer', role: 'korisnik');

class _Api extends LessonApiService {
  _Api._(this.saves, http.Client client)
      : super(authToken: 'tok', client: client);

  final List<Map<String, dynamic>> saves;

  /// Every request that carried a `positionList`, whichever verb it used — a
  /// saved tutorial is a `PUT` (see `tutorial_tok_edit_test.dart`).
  factory _Api() {
    final saves = <Map<String, dynamic>>[];
    return _Api._(
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

  /// The one saved part, read back through the reader every screen uses.
  AnalysisNode savedRoot() {
    expect(saves, hasLength(1), reason: 'one save is one write');
    final part = Map<String, dynamic>.from(
        (saves.single['positionList'] as List).single as Map);
    final read =
        readStepTree(fen: part['fen'].toString(), pgn: part['pgn'].toString());
    expect(read.rejectedMoves, 0);
    return read.root;
  }
}

Map<String, dynamic> _lesson() => {
      'id': 31,
      'title': 'Ruy Lopez',
      'position_list': [
        {'fen': _start, 'title': 'Part 1', 'pgn': _pgn},
      ],
    };

/// The node [plies] moves down the main line.
AnalysisNode _at(AnalysisNode root, int plies) {
  var node = root;
  for (var i = 0; i < plies; i++) {
    expect(node.children, isNotEmpty, reason: 'the line ends before $plies');
    node = node.children.first;
  }
  return node;
}

List<String> _comments(AnalysisNode node) =>
    [for (final b in node.beats) b.comment];

ChessBoardWithOverlay _board(WidgetTester tester) {
  final board = find.byType(ChessBoardWithOverlay);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  return tester.widget<ChessBoardWithOverlay>(board);
}

List<String> _arrowsOnBoard(WidgetTester tester) =>
    [for (final a in _board(tester).arrows) '$a'];
List<String> _squaresOnBoard(WidgetTester tester) =>
    [for (final s in _board(tester).squares) '$s'];

Finder _in(String key, Finder what) =>
    find.descendant(of: find.byKey(Key(key)), matching: what);

Future<void> _tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  expect(f, findsOneWidget, reason: 'nothing is keyed $key');
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final f = find.byKey(Key(key));
  expect(f, findsOneWidget, reason: 'nothing is keyed $key');
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, Finder field) {
  expect(field, findsOneWidget, reason: 'no such field');
  return tester.widget<TextField>(field).controller!.text;
}

// ---------------------------------------------------------------------------
// The Tutorial Studio

Future<_Api> _openStudio(WidgetTester tester,
    {Size size = const Size(1600, 1200), bool phone = false}) async {
  SharedPreferences.setMockInitialValues({});
  await TutorialDraftService.instance.clear();
  // A phone case runs under `_android` (below): the platform is a variant,
  // not an override — an override reset in a teardown is checked before the
  // teardown runs.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
  final api = _Api();
  await tester.pumpWidget(MaterialApp(
    home: TutorialStudioScreen(
      key: UniqueKey(),
      session: _session,
      entry: TutorialEntry.saved(_lesson()),
      lessonApi: api,
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

Future<void> _saveStudio(WidgetTester tester, {bool phone = false}) async {
  if (phone) {
    await _tapKey(tester, 'phone-save');
  } else {
    await tester.tap(find.text('Save tutorial'));
    await tester.pumpAndSettle();
  }
}

// ---------------------------------------------------------------------------
// Preparation

Future<void> _openPreparation(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1536, 792);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  final tree = readStepTree(fen: _start, pgn: _pgn);
  expect(tree.rejectedMoves, 0);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: PreparationScreen(
      key: UniqueKey(),
      userSession: _session,
      initialTree: tree.root,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
}

/// Steps [plies] moves forward from wherever Preparation opened — the start.
Future<void> _forward(WidgetTester tester, int plies) async {
  for (var i = 0; i < plies; i++) {
    expect(find.byTooltip('Next move'), findsOneWidget,
        reason: 'no control says „Next move"');
    await tester.tap(find.byTooltip('Next move'));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

AnalysisNode _preparationTree(WidgetTester tester) {
  final tree = find.byType(AnalysisMoveTreeWidget, skipOffstage: false);
  expect(tree, findsOneWidget, reason: 'there is no move tree on the screen');
  return tester.widget<AnalysisMoveTreeWidget>(tree).rootNode;
}

String _prepComment(WidgetTester tester) =>
    _fieldText(tester, find.byKey(const Key('prep-comment')));

void main() {
  group('the model\'s one home for a new sentence', () {
    test('keepMarks copies the marks of the sentence it follows', () {
      final node = AnalysisNode(fen: _start, comment: 'one');
      node.arrows.add(ChessArrow(colorCode: 'G', from: 'e2', to: 'e4'));
      node.squares.add(SquareMark(colorCode: 'R', square: 'd5'));
      node.addBeat().comment = 'three';

      final two = node.addBeat(after: 0, keepMarks: true);
      expect(_comments(node), ['one', '', 'three']);
      expect(
          ['${two.arrows.single}', '${two.squares.single}'], ['Ge2e4', 'Rd5']);
      two.arrows.clear();
      expect(node.beats.first.arrows, hasLength(1),
          reason: 'the new sentence drew on the old one\'s list');

      expect(node.addBeat().arrows, isEmpty,
          reason: 'without keepMarks a sentence starts clean, as the model '
              'gate says');
    });
  });

  group('the Tutorial Studio', () {
    testWidgets('draws a card for each sentence, the later one under the first',
        (tester) async {
      await _openStudio(tester);
      expect(find.byKey(const Key('beat-5')), findsOneWidget);
      expect(find.byKey(const Key('beat-5.1')), findsOneWidget);
      expect(find.byKey(const Key('beat-5.2')), findsNothing);
      expect(tester.getRect(find.byKey(const Key('beat-5.1'))).left,
          greaterThan(tester.getRect(find.byKey(const Key('beat-5'))).left),
          reason: 'a later sentence hangs under its position\'s first card');
      expect(_in('beat-5', find.text('1 of 2')), findsOneWidget);
      expect(_in('beat-5.1', find.text('2 of 2')), findsOneWidget);
      expect(_in('beat-4', find.textContaining(RegExp(r'^\d+ of \d+$'))),
          findsNothing,
          reason: 'a position with one sentence reads as today');
      expect(_fieldText(tester, find.byKey(const Key('beat-comment-5.1'))),
          _second);
    });

    testWidgets('marks the open sentence on one card, and draws its marks',
        (tester) async {
      await _openStudio(tester);
      await _tapKey(tester, 'beat-5.1');
      expect(find.byKey(const Key('beat-current')), findsOneWidget);
      expect(_in('beat-5.1', find.byKey(const Key('beat-current'))),
          findsOneWidget);
      expect(
          _fieldText(tester,
              _in('beat-5.1', find.byKey(const Key('example-sentence')))),
          _second);
      expect(_arrowsOnBoard(tester), ['Oc6e5']);
      expect(_squaresOnBoard(tester), ['Re5']);

      await _tapKey(tester, 'beat-5');
      expect(
          _in('beat-5', find.byKey(const Key('beat-current'))), findsOneWidget);
      expect(_arrowsOnBoard(tester), ['Gb5c6'],
          reason: 'the board showed another sentence\'s marks');
      expect(_squaresOnBoard(tester), isEmpty);
    });

    testWidgets(
        '„then plays" under the last sentence, „Delete this move" on '
        'the first', (tester) async {
      await _openStudio(tester);
      expect(
          _in('beat-5.1', find.textContaining('then plays')), findsOneWidget);
      expect(_in('beat-5', find.textContaining('then plays')), findsNothing);
      expect(_in('beat-5', find.byKey(const Key('beat-delete-5'))),
          findsOneWidget);
      expect(_in('beat-5.1', find.byKey(const Key('beat-delete-5'))),
          findsNothing);
    });

    testWidgets('„Add a sentence here" is on the open card only, in words',
        (tester) async {
      await _openStudio(tester);
      await _tapKey(tester, 'beat-3');
      expect(find.byKey(const Key('add-sentence')), findsOneWidget);
      expect(
          _in('beat-3', find.byKey(const Key('add-sentence'))), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('add-sentence')),
              matching: find.text('Add a sentence here')),
          findsOneWidget,
          reason: 'D16 A: a button with words, not an icon');

      await _tapKey(tester, 'beat-5.1');
      expect(_in('beat-5.1', find.byKey(const Key('add-sentence'))),
          findsOneWidget,
          reason: 'it follows the open card');
      expect(
          _in('beat-3', find.byKey(const Key('add-sentence'))), findsNothing);
    });

    testWidgets('a new sentence opens after the open one, with its marks',
        (tester) async {
      final api = await _openStudio(tester);
      await _tapKey(tester, 'beat-5');
      await _tapKey(tester, 'add-sentence');

      expect(_in('beat-5.1', find.byKey(const Key('beat-current'))),
          findsOneWidget,
          reason: 'the new sentence is the open one');
      expect(_fieldText(tester, find.byKey(const Key('example-sentence'))),
          isEmpty);
      expect(_fieldText(tester, find.byKey(const Key('beat-comment-5.2'))),
          _second,
          reason: 'the old second sentence moved one place down');
      expect(_arrowsOnBoard(tester), ['Gb5c6'],
          reason: 'D16 B: it starts with the marks of the one before it');

      await _type(tester, 'example-sentence', 'It pins nothing yet.');
      await _saveStudio(tester);

      final bb5 = _at(api.savedRoot(), 5);
      expect(_comments(bb5), [_first, 'It pins nothing yet.', _second]);
      expect([for (final b in bb5.beats) b.arrows.join(',')],
          ['Gb5c6', 'Gb5c6', 'Oc6e5']);
    });

    testWidgets('a position with one sentence takes a second', (tester) async {
      final api = await _openStudio(tester);
      await _tapKey(tester, 'beat-3');
      await _tapKey(tester, 'add-sentence');
      expect(find.byKey(const Key('beat-3.1')), findsOneWidget);
      expect(
          _in('beat-3.1', find.textContaining('then plays')), findsOneWidget);
      expect(_in('beat-3', find.textContaining('then plays')), findsNothing);

      await _type(tester, 'example-sentence', 'And now e5 needs a guard.');
      await _saveStudio(tester);
      // Nf3 had no words and no marks, so its first sentence is empty, and an
      // empty sentence is not written (`node_beats_test.dart`). The first
      // draft of this gate expected `['', …]` back — a tree the writer cannot
      // represent; the worker of phase 6 said so rather than special-case it.
      expect(_comments(_at(api.savedRoot(), 3)), ['And now e5 needs a guard.']);
    });

    testWidgets('a mark drawn goes to the open sentence', (tester) async {
      final api = await _openStudio(tester);
      await _tapKey(tester, 'beat-5.1');
      await _tapKey(tester, 'annotate-square');
      _board(tester).onSquareTapForDrawing('d4');
      await tester.pumpAndSettle();
      expect(_squaresOnBoard(tester).map((s) => s.substring(1)),
          containsAll(['e5', 'd4']));

      await _saveStudio(tester);
      final bb5 = _at(api.savedRoot(), 5);
      expect(bb5.beats.first.squares, isEmpty,
          reason: 'the square landed on the first sentence');
      expect([for (final s in bb5.beats[1].squares) s.square],
          containsAll(['e5', 'd4']));
    });

    testWidgets('typing into a later card writes that sentence',
        (tester) async {
      // The author stands on another move: a card that writes the open
      // sentence, or the position's first, looks right and is not.
      final api = await _openStudio(tester);
      await _tapKey(tester, 'beat-6');
      await _type(tester, 'beat-comment-5.1', 'The knight is the defender.');
      await _saveStudio(tester);
      expect(_comments(_at(api.savedRoot(), 5)),
          [_first, 'The knight is the defender.'],
          reason: 'an edit of a second sentence must reach the save — the '
              'signature that could not see it wrote the stored text back');
    });

    testWidgets(
        '✕ stands on every sentence of a position that has two, and '
        'nowhere else', (tester) async {
      await _openStudio(tester);
      expect(_in('beat-5', find.byKey(const Key('remove-sentence-5.0'))),
          findsOneWidget);
      expect(_in('beat-5.1', find.byKey(const Key('remove-sentence-5.1'))),
          findsOneWidget);
      expect(find.byKey(const Key('remove-sentence-4.0')), findsNothing);
      expect(find.byTooltip('Remove this sentence'), findsNWidgets(2));
    });

    testWidgets('removing the first sentence leaves the second, and the move',
        (tester) async {
      final api = await _openStudio(tester);
      await _tapKey(tester, 'remove-sentence-5.0');

      expect(find.byKey(const Key('beat-5.1')), findsNothing);
      // The card left standing is the second sentence's — not the first's
      // field kept alive under a new owner.
      final left = _in('beat-5', find.byType(TextField));
      expect(_fieldText(tester, left), _second);
      expect(find.byTooltip('Remove this sentence'), findsNothing);
      expect(_in('beat-5', find.textContaining(RegExp(r'^\d+ of \d+$'))),
          findsNothing);

      await _saveStudio(tester);
      final root = api.savedRoot();
      final bb5 = _at(root, 5);
      expect(bb5.moveSan, 'Bb5', reason: 'the move went with the sentence');
      expect(_comments(bb5), [_second]);
      expect(
          ['${bb5.arrows.single}', '${bb5.squares.single}'], ['Oc6e5', 'Re5']);
      expect(_at(root, 6).moveSan, 'a6');
    });

    testWidgets('removing an earlier sentence keeps the open one open',
        (tester) async {
      // Added on grading: the controller opened „the one before" whichever
      // sentence was removed, so removing sentence 1 while standing on
      // sentence 3 opened sentence 1's successor, not sentence 3.
      await _openStudio(tester);
      await _tapKey(tester, 'beat-5');
      await _tapKey(tester, 'add-sentence'); // [first, new (Gb5c6), second]
      await _tapKey(tester, 'beat-5.2');
      expect(_arrowsOnBoard(tester), ['Oc6e5']);

      await _tapKey(tester, 'remove-sentence-5.0');
      expect(_in('beat-5.1', find.byKey(const Key('beat-current'))),
          findsOneWidget,
          reason: 'the open sentence moved up one place and stayed open');
      expect(_fieldText(tester, find.byKey(const Key('example-sentence'))),
          _second);
      expect(_arrowsOnBoard(tester), ['Oc6e5']);
    });

    testWidgets('Undo brings a removed sentence back', (tester) async {
      final api = await _openStudio(tester);
      await _tapKey(tester, 'remove-sentence-5.1');
      expect(find.byKey(const Key('beat-5.1')), findsNothing);
      await _tapKey(tester, 'tutorial-undo');
      expect(find.byKey(const Key('beat-5.1')), findsOneWidget);

      await _saveStudio(tester);
      expect(_comments(_at(api.savedRoot(), 5)), [_first, _second]);
    });

    testWidgets('Undo of an added sentence opens the one that was open',
        (tester) async {
      await _openStudio(tester);
      await _tapKey(tester, 'beat-5.1');
      await _tapKey(tester, 'add-sentence');
      expect(find.byKey(const Key('beat-5.2')), findsOneWidget);
      await _tapKey(tester, 'tutorial-undo');
      expect(find.byKey(const Key('beat-5.2')), findsNothing);
      expect(_in('beat-5.1', find.byKey(const Key('beat-current'))),
          findsOneWidget,
          reason: 'the open sentence is part of what an undo restores');
      expect(_arrowsOnBoard(tester), ['Oc6e5']);
    });
  });

  group('the phone', () {
    const phone = Size(360, 640);

    // The row is a lazy horizontal list: a chip past its edge is not built,
    // so a helper that only looks finds the first three and stops. Both of
    // these scroll the row itself.
    Finder rowScrollable() => find.descendant(
        of: find.byKey(const Key('phone-move-list')),
        matching: find.byType(Scrollable));

    Future<List<String>> row(WidgetTester tester) async {
      final seen = <int, String>{};
      await tester.drag(rowScrollable(), const Offset(2000, 0));
      await tester.pumpAndSettle();
      for (var sweep = 0; sweep < 20; sweep++) {
        for (final e in find
            .descendant(
                of: find.byKey(const Key('phone-move-list')),
                matching: find.byWidgetPredicate((w) =>
                    w.key is ValueKey<String> &&
                    (w.key as ValueKey<String>)
                        .value
                        .startsWith('phone-move-')))
            .evaluate()) {
          final key = (e.widget.key as ValueKey<String>).value;
          final i = int.tryParse(key.substring('phone-move-'.length));
          if (i == null) continue;
          final text = find.descendant(
              of: find.byKey(Key(key)), matching: find.byType(Text));
          seen[i] = tester.widget<Text>(text.first).data ?? '';
        }
        await tester.drag(rowScrollable(), const Offset(-120, 0));
        await tester.pumpAndSettle();
      }
      final count = seen.length;
      expect(seen.keys.toSet(), {for (var i = 0; i < count; i++) i},
          reason: 'the sweep missed a chip');
      return [for (var i = 0; i < count; i++) seen[i]!];
    }

    Future<void> tapChip(WidgetTester tester, int i) async {
      await tester.scrollUntilVisible(find.byKey(Key('phone-move-$i')), 80,
          scrollable: rowScrollable());
      await tester.pumpAndSettle();
      await _tapKey(tester, 'phone-move-$i');
    }

    testWidgets('the row of moves has a narrow chip for a later sentence',
        (tester) async {
      await _openStudio(tester, size: phone, phone: true);
      expect(await row(tester), [
        'Start', '1. e4', '1... e5', '2. Nf3', '2... Nc6', //
        '3. Bb5', '·2', '3... a6',
      ]);
      await tapChip(tester, 6);
      expect(tester.getSize(find.byKey(const Key('phone-move-6'))).width,
          lessThan(tester.getSize(find.byKey(const Key('phone-move-5'))).width),
          reason: 'D16 D: a narrow chip');
    }, variant: _android);

    testWidgets('the chip opens the sentence, and ‹ › walk them',
        (tester) async {
      await _openStudio(tester, size: phone, phone: true);
      await tapChip(tester, 6);
      expect(find.text('Comment on 3. Bb5 · sentence 2 of 2'), findsOneWidget);
      expect(
          _fieldText(tester, find.byKey(const Key('phone-comment'))), _second);
      expect(_arrowsOnBoard(tester), ['Oc6e5']);
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('phone-sentence-next')))
              .onPressed,
          isNull,
          reason: 'the last sentence has none after it');

      await _tapKey(tester, 'phone-sentence-prev');
      expect(find.text('Comment on 3. Bb5 · sentence 1 of 2'), findsOneWidget);
      expect(
          _fieldText(tester, find.byKey(const Key('phone-comment'))), _first);
      expect(_arrowsOnBoard(tester), ['Gb5c6']);
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('phone-sentence-prev')))
              .onPressed,
          isNull);
      expect(find.byKey(const Key('phone-remove-sentence')), findsOneWidget);
    }, variant: _android);

    testWidgets('a position with one sentence reads as today, and takes one',
        (tester) async {
      final api = await _openStudio(tester, size: phone, phone: true);
      await tapChip(tester, 7);
      expect(find.text('Comment on 3... a6'), findsOneWidget);
      for (final key in [
        'phone-sentence-prev',
        'phone-sentence-next',
        'phone-remove-sentence',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(
          find.descendant(
              of: find.byKey(const Key('phone-add-sentence')),
              matching: find.text('Add a sentence here')),
          findsOneWidget);

      await _tapKey(tester, 'phone-add-sentence');
      expect(find.text('Comment on 3... a6 · sentence 2 of 2'), findsOneWidget);
      expect(
          _fieldText(tester, find.byKey(const Key('phone-comment'))), isEmpty);
      expect((await row(tester)).last, '·2');

      await _type(tester, 'phone-comment', 'Black asks at once.');
      await _saveStudio(tester, phone: true);
      // The empty first sentence is not written; see „a position with one
      // sentence takes a second".
      expect(_comments(_at(api.savedRoot(), 6)), ['Black asks at once.']);
    }, variant: _android);

    testWidgets('„Remove this sentence" in words, and the one before opens',
        (tester) async {
      final api = await _openStudio(tester, size: phone, phone: true);
      await tapChip(tester, 6);
      expect(
          find.descendant(
              of: find.byKey(const Key('phone-remove-sentence')),
              matching: find.text('Remove this sentence')),
          findsOneWidget);
      await _tapKey(tester, 'phone-remove-sentence');
      expect(find.text('Comment on 3. Bb5'), findsOneWidget);
      expect(
          _fieldText(tester, find.byKey(const Key('phone-comment'))), _first);
      expect(await row(tester), isNot(contains('·2')));

      await _saveStudio(tester, phone: true);
      expect(_comments(_at(api.savedRoot(), 5)), [_first]);
    }, variant: _android);
  });

  group('Preparation\'s comment box', () {
    testWidgets('reads as today where a position has one sentence',
        (tester) async {
      await _openPreparation(tester);
      await _forward(tester, 1);
      expect(find.text('Comment for 1. e4'), findsOneWidget);
      for (final key in [
        'prep-sentence-prev',
        'prep-sentence-next',
        'prep-remove-sentence',
      ]) {
        expect(find.byKey(Key(key)), findsNothing, reason: key);
      }
      expect(
          find.descendant(
              of: find.byKey(const Key('prep-add-sentence')),
              matching: find.text('Add a sentence here')),
          findsOneWidget);
    });

    testWidgets('adds nothing on the starting position', (tester) async {
      await _openPreparation(tester);
      expect(find.text('Comment (select a move)'), findsOneWidget);
      expect(find.byKey(const Key('prep-add-sentence')), findsNothing);
    });

    testWidgets('follows the open sentence, and ‹ › walk them (D16 E)',
        (tester) async {
      await _openPreparation(tester);
      await _forward(tester, 5);
      expect(find.text('Comment for 3. Bb5 · sentence 1 of 2'), findsOneWidget,
          reason: 'a step onto a position opens its first sentence');
      expect(_prepComment(tester), _first);
      expect(_arrowsOnBoard(tester), ['Gb5c6']);

      await tester.tap(find.byKey(const Key('prep-sentence-next')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Comment for 3. Bb5 · sentence 2 of 2'), findsOneWidget);
      expect(_prepComment(tester), _second,
          reason: 'the field kept the first sentence\'s text');
      expect(_arrowsOnBoard(tester), ['Oc6e5']);
      expect(_squaresOnBoard(tester), ['Re5']);
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('prep-sentence-next')))
              .onPressed,
          isNull);

      await tester.enterText(
          find.byKey(const Key('prep-comment')), 'The knight is the guard.');
      await tester.pump(const Duration(milliseconds: 50));
      expect(_comments(_at(_preparationTree(tester), 5)),
          [_first, 'The knight is the guard.']);
    });

    testWidgets('a new sentence keeps the marks, and a mark drawn goes to it',
        (tester) async {
      await _openPreparation(tester);
      await _forward(tester, 5);
      await tester.tap(find.byKey(const Key('prep-add-sentence')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Comment for 3. Bb5 · sentence 2 of 3'), findsOneWidget);
      expect(_prepComment(tester), isEmpty);
      expect(_arrowsOnBoard(tester), ['Gb5c6']);

      await tester.tap(find.byKey(const Key('annotate-square')));
      await tester.pump(const Duration(milliseconds: 50));
      _board(tester).onSquareTapForDrawing('d4');
      await tester.pump(const Duration(milliseconds: 50));

      final bb5 = _at(_preparationTree(tester), 5);
      expect(bb5.beats, hasLength(3));
      expect(bb5.beats.first.squares, isEmpty);
      expect([for (final s in bb5.beats[1].squares) s.square], ['d4']);
      expect(bb5.beats[2].comment, _second);
    });

    testWidgets(
        'a removed sentence is said, with Undo — there is no other '
        'undo here', (tester) async {
      await _openPreparation(tester);
      await _forward(tester, 5);
      await tester.tap(find.byKey(const Key('prep-remove-sentence')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Comment for 3. Bb5'), findsOneWidget);
      expect(_comments(_at(_preparationTree(tester), 5)), [_second]);
      expect(find.text('Sentence removed.'), findsOneWidget);

      // Let the message finish sliding in: 50 ms in, its action stood below
      // the window's edge and the tap missed (found by the worker of phase 6).
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_comments(_at(_preparationTree(tester), 5)), [_first, _second]);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
