// The gate for P5a of `docs/PLAN-STUDIO-REDIZAJN.md` — the „Delovi tutorijala"
// panel.
//
// Written before the batch. It moves to
// `chess_app/test/tutorial_delovi_test.dart` in the merge commit.
//
// It drives the **real screen**, not the panel in isolation. The panel's whole
// job is that selecting a part moves the board, the tree and the fields with
// it; a test that pumped the panel alone could not tell that from a list that
// merely highlights a different row.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH 57
//
// **One new widget**, `lib/features/tutorial_studio/widgets/tutorial_sections_panel.dart`:
//
//   class TutorialSectionsPanel extends StatelessWidget {
//     const TutorialSectionsPanel({
//       super.key,
//       required this.draft,
//       required this.onSelect,   // void Function(int index)
//       required this.onAdd,      // void Function({required bool continueFromEnd})
//       required this.onMove,     // void Function(int from, int to)
//       required this.onClone,    // void Function(int index)
//       required this.onRemove,   // void Function(int index)
//     });
//     final TutorialDraft draft;
//     ...
//   }
//
// **Stateless, and it decides nothing.** It draws `draft.sections`, marks
// `draft.selected`, and reports. Every mutation goes through the screen, which
// already owns the draft, the board controller and the fields — the model's
// `addSection`, `removeSection`, `moveSection`, `cloneSection` and `selected`
// are frozen and do the work. A panel that mutates the draft itself has taken
// the screen's job and the screen will not know its fields are stale.
//
// It **replaces** the plain running list in `_authoringColumn` (the
// `if (written > 0) ... Text(...)` block and the bold current-part line). It is
// not added beside it.
//
// **Strings, frozen. They land in the panel file and in the screen, and
// nowhere else:**
//
//   'Delovi tutorijala'                 the panel's heading
//   '+ Dodaj deo'                       the button
//   'Gde počinje novi deo?'             the add dialog's title
//   'Nastavi odavde'                    -> continueFromEnd: true
//   'Nova pozicija'                     -> continueFromEnd: false
//   'Otkaži'                            -> adds nothing
//   'Pomeri gore' / 'Pomeri dole'       tooltips on the reorder buttons
//   'Kloniraj deo' / 'Obriši deo'       tooltips
//   'Brisanje dela'                     the confirmation's title
//   'Odustani' / 'Obriši'               on the confirmation
//   'Poslednji deo ne može biti obrisan.'   the refusal, through AppFeedback
//   'Nastavlja se na prethodni deo'     the join mark's tooltip
//
// **„Deo" replaces „Primer" in this screen, and only in this screen.** That is
// D7, and it lands here because the panel is the surface that names a part.
// The screen's generated titles become 'Deo 1', 'Deo 2', … The rest of D7 —
// anywhere else the word appears — is a separate vocabulary batch with a table,
// the way batch 51 was done. **Do not rename anything outside
// `lib/features/tutorial_studio/`.**
//
// **The join mark.** Two parts in a row where the second starts on the position
// the first's line ends at are joined on the child's screen — one board, no
// reset. The author cannot see that today and it is the thing they are most
// likely to break by reordering. The mark is drawn on the *second* of such a
// pair, and it carries the tooltip above.
//
// **Nothing reaches the server.** Decision 3 of `docs/PLAN-TUTORIJAL.md` still
// holds: one write, at the end. Adding, moving, cloning and deleting are all
// local until „Sačuvaj tutorijal".
//
// **Not this batch:** the split-view layout (P5b), the timeline (P6), drawing
// (P7). The model, `TutorialEntry`, the save routing and the studio's other
// gates are frozen.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const openingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

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

  ChessBoardWithOverlay board(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay).first);

  /// The move tree, whether or not it is the tab currently showing.
  ///
  /// `skipOffstage: false` was added ahead of P6a, which puts the tree behind
  /// a „Stablo" tab with „Tok" in front of it: `IndexedStack` keeps the hidden
  /// tab built — that is how the tree keeps its zoom across a switch — but
  /// offstage, and the default finder skips offstage widgets. Without this the
  /// helper throws „Bad state: No element" and takes a dozen assertions with
  /// it, none of which are about tabs.
  AnalysisMoveTreeWidget tree(WidgetTester tester) =>
      tester.widget<AnalysisMoveTreeWidget>(
          find.byType(AnalysisMoveTreeWidget, skipOffstage: false).first);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: const TutorialEntry.blank('Opozicija'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    board(tester).onMove(from, to, '');
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip).last);
    await tester.pumpAndSettle();
  }

  /// Adds a demonstration, answering the position question with
  /// [continueFromEnd].
  ///
  /// The words changed on 7.9.2026 and the two answers did not: „+ Dodaj deo"
  /// became „Novi prikaz", and „Gde počinje novi deo?" — a question about
  /// parts — became „Odakle počinje?", which is a question about a board. Every
  /// assertion below about *where* a new part starts is unchanged.
  Future<void> addPart(WidgetTester tester,
      {bool continueFromEnd = true}) async {
    await tester.tap(find.byKey(const Key('add-show')));
    await tester.pumpAndSettle();
    await tapText(tester, continueFromEnd ? 'Odavde' : 'Nova tabla');
  }

  /// Clicks a row of the panel by the name it is listed under.
  ///
  /// By the row and not by the text, because since 7.9.2026 a part is called by
  /// its first sentence — and that sentence is also in the field the trainer
  /// typed it into, so `find.text` matches two widgets. Same family as batch
  /// 55's finder that stopped being unique once a second place for the string
  /// existed.
  Future<void> tapRow(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(ListTile),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String value) async {
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.pumpAndSettle();
  }

  group('the panel is the table of contents', () {
    testWidgets('every part is listed, numbered, by its name', (tester) async {
      await open(tester);
      expect(find.text('Sadržaj tutorijala'), findsOneWidget);
      expect(find.text('Deo 1'), findsOneWidget);

      await play(tester, 'e2', 'e4');
      await addPart(tester);

      expect(find.text('Deo 1'), findsOneWidget);
      expect(find.text('Deo 2'), findsOneWidget);
      await close(tester);
    });

    testWidgets('choosing a part takes the board and the tree with it',
        (tester) async {
      // The whole point of the panel, and the assertion batch 55 taught: prove
      // the selection **followed**, not merely that the other part's work is
      // absent. A mutation that left the selection where it was would pass a
      // test that only checked for absence.
      await open(tester);
      await type(tester, 'example-sentence', 'Prvi deo govori ovo.');
      await play(tester, 'e2', 'e4');
      await addPart(tester, continueFromEnd: false);
      await play(tester, 'd2', 'd4');

      expect(tree(tester).rootNode.children.single.moveSan, 'd4');

      await tapRow(tester, 'Prvi deo govori ovo.');

      expect(tree(tester).rootNode.children.single.moveSan, 'e4',
          reason: 'the tree stayed on the part that was open before');
      expect(board(tester).controller.getFen().split(' ').first,
          openingFen.split(' ').first,
          reason: 'the board did not follow the part that was chosen');
      expect(find.widgetWithText(TextField, 'Prvi deo govori ovo.'),
          findsOneWidget,
          reason: 'the fields still show the other part — the trainer is '
              'typing into a part they are not looking at');
      await close(tester);
    });
  });

  group('adding a part', () {
    testWidgets('asks which board it begins on', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('add-show')));
      await tester.pumpAndSettle();
      expect(find.text('Odakle počinje?'), findsOneWidget);
      expect(find.text('Odavde'), findsOneWidget);
      expect(find.text('Nova tabla'), findsOneWidget);
      await close(tester);
    });

    testWidgets('„Odavde" starts where this part’s line ended', (tester) async {
      // What makes show → ask one board with no reset on the child's screen.
      await open(tester);
      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      final ended = board(tester).controller.getFen();

      await addPart(tester);

      expect(board(tester).controller.getFen().split(' ').take(2).join(' '),
          ended.split(' ').take(2).join(' '));
      expect(tree(tester).rootNode.children, isEmpty);
      await close(tester);
    });

    testWidgets('„Nova tabla" starts on a board of its own', (tester) async {
      await open(tester);
      await play(tester, 'e2', 'e4');
      await addPart(tester, continueFromEnd: false);

      expect(board(tester).controller.getFen().split(' ').first,
          openingFen.split(' ').first);
      await close(tester);
    });

    testWidgets('saying neither adds nothing', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('add-show')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Otkaži');

      expect(find.text('Deo 2'), findsNothing);
      await close(tester);
    });
  });

  group('rearranging', () {
    testWidgets('a part moves with its work, not just its name',
        (tester) async {
      await open(tester);
      await type(tester, 'example-sentence', 'Ovo je prvi.');
      await addPart(tester, continueFromEnd: false);
      await type(tester, 'example-sentence', 'Ovo je drugi.');

      await tapTooltip(tester, 'Pomeri gore');

      // The selection follows the part, and the part brought its sentence.
      expect(find.widgetWithText(TextField, 'Ovo je drugi.'), findsOneWidget,
          reason: 'the row moved but the work behind it did not');
      await tapRow(tester, 'Ovo je prvi.');
      expect(find.widgetWithText(TextField, 'Ovo je prvi.'), findsOneWidget);
      await close(tester);
    });

    testWidgets('the ends cannot be moved past', (tester) async {
      await open(tester);
      await addPart(tester);

      // Standing on the last part: down is dead, up is live.
      expect(
          tester
              .widget<IconButton>(find.ancestor(
                  of: find.byTooltip('Pomeri dole'),
                  matching: find.byType(IconButton)))
              .onPressed,
          isNull);
      await close(tester);
    });

    testWidgets('a clone is a copy, and it is the one you land on',
        (tester) async {
      await open(tester);
      await type(tester, 'example-sentence', 'Rečenica koja se kopira.');
      await tapTooltip(tester, 'Kloniraj deo');

      expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text('Rečenica koja se kopira.'),
          ),
          findsNWidgets(2),
          reason: 'the copy is listed beside the original, under the same '
              'name — both are called by the sentence they carry');
      expect(find.widgetWithText(TextField, 'Rečenica koja se kopira.'),
          findsOneWidget,
          reason: 'the copy did not carry the work, or the trainer was left '
              'standing on the original');
      await close(tester);
    });
  });

  group('removing a part', () {
    testWidgets('asks first, and saying no keeps it', (tester) async {
      await open(tester);
      await addPart(tester);

      await tapTooltip(tester, 'Obriši deo');
      expect(find.text('Brisanje dela'), findsOneWidget);
      await tapText(tester, 'Odustani');

      expect(find.text('Deo 2'), findsOneWidget);
      await close(tester);
    });

    testWidgets('saying yes drops it', (tester) async {
      await open(tester);
      await addPart(tester);

      await tapTooltip(tester, 'Obriši deo');
      await tapText(tester, 'Obriši');

      expect(find.text('Deo 2'), findsNothing);
      expect(find.text('Deo 1'), findsOneWidget);
      await close(tester);
    });

    testWidgets('the last part is refused, in a sentence', (tester) async {
      // `PUT` writes `position_list = NULL` for an empty list, so a tutorial
      // emptied here loses every step with nothing left to join on and
      // complain. The model refuses it; this is the screen saying so.
      await open(tester);
      await tapTooltip(tester, 'Obriši deo');
      await tester.pumpAndSettle();

      expect(find.text('Poslednji deo ne može biti obrisan.'), findsOneWidget);
      expect(find.text('Deo 1'), findsOneWidget);
      await close(tester);
    });
  });

  group('the join mark', () {
    testWidgets('marks a part that continues the one before it',
        (tester) async {
      await open(tester);
      await play(tester, 'e2', 'e4');
      await addPart(tester);

      expect(find.byTooltip('Nastavlja se na prethodni deo'), findsOneWidget,
          reason: 'the author cannot see which of their parts the child will '
              'experience as one board');
      await close(tester);
    });

    testWidgets('and is absent where the board is reloaded', (tester) async {
      await open(tester);
      await play(tester, 'e2', 'e4');
      await addPart(tester, continueFromEnd: false);

      expect(find.byTooltip('Nastavlja se na prethodni deo'), findsNothing);
      await close(tester);
    });
  });
}
