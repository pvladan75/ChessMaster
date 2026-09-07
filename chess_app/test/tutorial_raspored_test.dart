// The gate for P5b of `docs/PLAN-STUDIO-REDIZAJN.md` — the split layout of the
// tutorial studio.
//
// Written before the batch. It moves to
// `chess_app/test/tutorial_raspored_test.dart` in the merge commit.
//
// It drives the **real screen** and **measures** it. Nothing here asks which
// widget was used: a `Row` that overflows also contains a `SizedBox(width:
// 460)`, and „it uses `Expanded`" is not proof the board got the width. Every
// assertion below is a number taken off the laid-out tree.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH 58
//
// **At or above `Breakpoints.wide` (840) the screen is:**
//
//   Padding(all: AppSpacing.md)
//     Row
//       ├ Expanded                      Key('board-pane')
//       │    the board, centred, then MoveNavigationControls
//       ├ SizedBox(width: AppSpacing.md)
//       └ SizedBox(width: 460)          Key('authoring-pane')
//            ├ „Naziv tutorijala"                    fixed, above the split
//            ├ Expanded(flex: 2)        Key('sections-half')
//            │    TutorialSectionsPanel, scrolling inside itself
//            ├ Divider
//            └ Expanded(flex: 3)        Key('editor-half')
//                 the fields for the open part, „Linija ovog dela", the tree,
//                 scrolling inside itself
//
// and „Sačuvaj tutorijal" **moves into the AppBar**, beside „Unos pozicije",
// leaving both layouts — the narrow one included, so the action keeps one home.
//
// **Four keys, and they are the only new literals this batch may add.** They
// are how a layout is measured from the outside; without them this file would
// have to guess at widget types and would pass over the wrong tree. No new
// *user-facing* string, and no existing one edited — every sentence on this
// screen is already written and approved.
//
// **The arithmetic**, so nobody has to rediscover it. The padding is
// `AppSpacing.md` (12) on each side and the gap between the panes is another
// 12, so the board pane is `width - 24 - 460 - 12`: 1104 at a 1600 px window,
// 344 at 840. The board itself is that width, limited by the height the way it
// already is (`clamp(280, maxHeight - 120)`), and **centred** in the pane —
// past about 1250 px the board stops growing and the slack must fall on both
// sides.
//
// **Below 840 nothing changes**: board on top, one scrolled column under it,
// exactly as today. This screen is Windows-only and a narrow window here is a
// resized one, not a phone; §5.4 of the plan says it must not be *broken*, not
// that it must be good. What it must never do is overflow — in a release build
// that is silent, and three of those have already been paid for here.
//
// **Why the save is in the AppBar, and this was measured rather than argued.**
// The bottom half is shorter than the column it replaces, and
// `tutorial_authoring_test.dart` — the frozen gate that asserts on the `POST`
// body — taps „Sačuvaj tutorijal" six times. Pinning the button under the
// scrolling half was tried first, on a throwaway build of this whole layout,
// and it put the button exactly where `AppFeedback` draws its message: the
// SnackBar covered the control it was complaining about, and one of those six
// taps failed on it. In the AppBar the suite is green with **no edit to any
// existing test**, which is the state this batch is expected to reach — the
// plan's own §5 sketch had it there all along.
//
// So: if a tap in an existing test lands off-screen, that is news. Say so in
// the report rather than scrolling around it.
//
// **Not this batch:** the `[Tok]`/`[Stablo]` tab bar and the timeline (P6),
// arrow drawing (P7), a draggable divider, a remembered ratio, the tutorial's
// name in the AppBar. The model, the entry type, the save routing and
// `TutorialSectionsPanel`'s API are frozen — that panel's list becomes a
// scrolling one, which is the only change permitted in that file.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
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

  /// A saved tutorial of [count] parts, for the panel that has to scroll.
  ///
  /// Both fixtures here are **data**, and that is deliberate. The first version
  /// of this file made the lower half tall by pressing „Dodaj odgovor" four
  /// times, and the taps started missing as soon as the layout under test
  /// worked: the controls a split pushes below a fold are exactly the controls
  /// such a helper reaches for, so the gate failed for a reason that had
  /// nothing to do with what it asserts — and only when run in file order,
  /// which is the worst way to find out.
  Map<String, dynamic> lessonOf(int count) => {
        'id': 12,
        'title': 'Dugačak tutorijal',
        'position_list': [
          for (var i = 0; i < count; i++)
            {'fen': openingFen, 'pgn': '1. e4', 'title': 'Deo ${i + 1}'},
        ],
      };

  /// One part carrying more than its half can show: six offered answers is a
  /// question a trainer really writes, and it needs no tap to arrive.
  Map<String, dynamic> tallLesson() => {
        'id': 13,
        'title': 'Pitanje sa mnogo odgovora',
        'position_list': [
          {
            'fen': openingFen,
            'title': 'Deo 1',
            'kind': 'ask_choice',
            'instruction': 'Šta beli postiže ovim potezom?',
            'choices': [
              for (var i = 0; i < 6; i++)
                {'text': 'Ponuđeni odgovor broj ${i + 1}', 'correct': i == 0},
            ],
          },
        ],
      };

  Future<void> openAt(
    WidgetTester tester,
    Size size, {
    TutorialEntry? entry,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: TutorialStudioScreen(
          session: session,
          entry: entry ?? const TutorialEntry.blank('Opozicija'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  /// Tears the tree down without waiting out the draft's 600 ms debounce — see
  /// the same helper in `test/tutorial_studio_test.dart`.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder pane(String key) => find.byKey(Key(key));

  /// The scroll of the outermost scrollable inside [key].
  ///
  /// Read as a position rather than driven as a gesture: a drag has to land
  /// somewhere, and every candidate inside these panes is a text field, a
  /// dropdown or a move tree that may claim the pointer. The property is that
  /// the two halves have **their own** scrolls, and a position says that
  /// without a pointer being involved at all.
  ScrollPosition scrollIn(WidgetTester tester, String key) => tester
      .state<ScrollableState>(
        find.descendant(of: pane(key), matching: find.byType(Scrollable)).first,
      )
      .position;

  /// The board's own square, which is what the trainer looks at.
  Size boardSize(WidgetTester tester) =>
      tester.getSize(find.byType(ChessBoardWithOverlay).first);

  group('the board gets the window, the fields keep their width', () {
    testWidgets('the authoring pane is 460 and the board pane has the rest', (
      tester,
    ) async {
      await openAt(tester, const Size(1600, 1000));

      final authoring = tester.getRect(pane('authoring-pane'));
      final board = tester.getRect(pane('board-pane'));

      expect(
        authoring.width,
        460,
        reason: 'the column that holds text is fixed — §5.1 of the plan',
      );
      expect(
        board.width,
        greaterThan(1000),
        reason: 'the board pane did not take what was left of the row',
      );
      expect(
        board.right,
        lessThanOrEqualTo(authoring.left),
        reason: 'the two panes overlap, which is what a clipped Row looks '
            'like from the outside',
      );
      expect(
        authoring.right,
        closeTo(1600 - 12, 1),
        reason: 'the authoring pane is not flush against the right edge',
      );

      await close(tester);
    });

    testWidgets('a wider window grows the board and never the fields', (
      tester,
    ) async {
      // The sharp one. Today's layout gives the board 45% and the rest to an
      // `Expanded`, so *both* grow with the window; after this batch exactly
      // one does. 400 px of window must arrive as 400 px of board pane.
      await openAt(tester, const Size(1400, 1000));
      final narrowAuthoring = tester.getSize(pane('authoring-pane')).width;
      final narrowBoard = tester.getSize(pane('board-pane')).width;

      await resize(tester, const Size(1800, 1000));
      final wideAuthoring = tester.getSize(pane('authoring-pane')).width;
      final wideBoard = tester.getSize(pane('board-pane')).width;

      expect(
        wideAuthoring,
        narrowAuthoring,
        reason: 'the fields grew with the window; they are fixed',
      );
      expect(
        wideBoard - narrowBoard,
        closeTo(400, 1),
        reason: 'the 400 px the window gained did not all go to the board',
      );

      await close(tester);
    });

    testWidgets('the board is centred in the space it is given', (
      tester,
    ) async {
      // Past about 1250 px the board is limited by the height, so there is
      // slack in the pane. It belongs on both sides: a board pinned left with
      // 300 px of nothing beside it is the version of this that looks like a
      // bug.
      await openAt(tester, const Size(1600, 1000));

      final paneRect = tester.getRect(pane('board-pane'));
      // `BoardWithCoordinates`, not the board inside it: the rank and file
      // labels sit on two of the four sides, so the playing surface is off
      // centre inside its own widget by design. Measuring the inner board
      // would demand an asymmetry that would be a bug if anyone built it.
      final boardRect = tester.getRect(find.byType(BoardWithCoordinates).first);

      expect(
        paneRect.width - boardRect.width,
        greaterThan(100),
        reason: 'this window is meant to leave slack; nothing is proved '
            'about centring without it',
      );
      expect(
        boardRect.left - paneRect.left,
        closeTo(paneRect.right - boardRect.right, 1),
        reason: 'the board sits off to one side of its pane',
      );

      await close(tester);
    });
  });

  group('two panels, two scrolls', () {
    testWidgets('reading down the line leaves the list of parts where it is', (
      tester,
    ) async {
      await openAt(
        tester,
        const Size(1400, 900),
        entry: TutorialEntry.saved(tallLesson()),
      );

      // The row is called by what the part says, since 7.9.2026 — and the
      // same sentence is in the field the trainer typed it into, so the finder
      // has to name the row rather than the string.
      final row = find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Šta beli postiže ovim potezom?'),
      );
      final partBefore = tester.getRect(row);
      final nameBefore = tester.getRect(
        find.byKey(const Key('tutorial-title')),
      );

      final editor = scrollIn(tester, 'editor-half');
      expect(
        editor.maxScrollExtent,
        greaterThan(0),
        reason: 'the lower half is not a scroll of its own — with the column '
            'still scrolling as one, this is the whole batch',
      );
      editor.jumpTo(editor.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(row),
        partBefore,
        reason: 'reading down the line carried the list of parts away, '
            'which is the thing this layout exists to stop',
      );
      expect(
        tester.getRect(find.byKey(const Key('tutorial-title'))),
        nameBefore,
        reason: "the tutorial's name is above the split and does not scroll",
      );

      await close(tester);
    });

    testWidgets('the list of parts scrolls inside itself', (tester) async {
      await openAt(
        tester,
        const Size(1400, 900),
        entry: TutorialEntry.saved(lessonOf(14)),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'fourteen parts overflowed the panel instead of scrolling',
      );

      final sections = scrollIn(tester, 'sections-half');
      final editorBefore = scrollIn(tester, 'editor-half').pixels;
      final sentenceBefore = tester.getRect(
        find.byKey(const Key('example-sentence')),
      );

      expect(
        sections.maxScrollExtent,
        greaterThan(0),
        reason: 'the panel does not scroll inside its own half',
      );
      sections.jumpTo(sections.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(scrollIn(tester, 'editor-half').pixels, editorBefore);
      expect(
        tester.getRect(find.byKey(const Key('example-sentence'))),
        sentenceBefore,
        reason: 'moving the list of parts moved the fields with it — one '
            'scroll wrapped around both halves satisfies a screenshot and '
            'not this',
      );

      await close(tester);
    });

    testWidgets('the one write has one home and is always on screen', (
      tester,
    ) async {
      await openAt(
        tester,
        const Size(1400, 900),
        entry: TutorialEntry.saved(tallLesson()),
      );

      expect(
        find.text('Sačuvaj tutorijal'),
        findsOneWidget,
        reason: 'two saves on one screen are two answers to „did it save?"',
      );

      final save = tester.getRect(find.text('Sačuvaj tutorijal'));
      final authoring = tester.getRect(pane('authoring-pane'));
      expect(
        save.bottom,
        lessThanOrEqualTo(authoring.top),
        reason: 'the save sits above both panels. Under them is where '
            'AppFeedback draws its message, and a refusal that covers the '
            'button it is refusing was measured, not imagined',
      );

      final editor = scrollIn(tester, 'editor-half');
      editor.jumpTo(editor.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(
        find.text('Sačuvaj tutorijal').hitTestable(),
        findsOneWidget,
        reason: 'the one write scrolled away with the half beneath it',
      );

      await close(tester);
    });
  });

  group('where the shape changes, and below it', () {
    testWidgets('at 840 the panes stand side by side', (tester) async {
      await openAt(tester, const Size(840, 800));
      expect(
        tester.takeException(),
        isNull,
        reason: 'the narrowest wide window overflows',
      );

      expect(tester.getSize(pane('authoring-pane')).width, 460);
      expect(
        boardSize(tester).width,
        lessThan(420),
        reason: 'at 840 the board has 344 px of pane to live in; a board '
            'wider than that is a Row hanging over the edge',
      );

      await close(tester);
    });

    testWidgets('at 839 the board has the whole window', (tester) async {
      await openAt(tester, const Size(839, 800));
      expect(tester.takeException(), isNull);

      expect(
        boardSize(tester).width,
        greaterThan(700),
        reason: 'below the breakpoint the board is the width of the window, '
            'with the authoring column under it — unchanged from today',
      );

      await close(tester);
    });

    testWidgets('a small window lays out without an overflow', (tester) async {
      // 700 is a Windows window somebody has dragged narrow, which is the only
      // way below the breakpoint is reached on the platform this screen runs
      // on. It is here because a release build paints no stripes: a Row wider
      // than the window is simply clipped, and the controls past the edge are
      // unreachable.
      //
      // Not 360: the studio already overflows by 47 px at a phone width, on
      // `master`, before this batch — a horizontal flex somewhere under the
      // narrow branch. That is a real defect and it is **not this batch's**, so
      // demanding it here would be a gate asking for work nobody briefed.
      await openAt(tester, const Size(700, 800));
      expect(tester.takeException(), isNull);
      expect(find.text('Sadržaj tutorijala'), findsOneWidget);
      await close(tester);
    });
  });
}
