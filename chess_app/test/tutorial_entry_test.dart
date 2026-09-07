// The gate for P3b of `docs/PLAN-STUDIO-REDIZAJN.md` — D4, why the studio is
// being opened.
//
// Written before the work. It is the gate for complaint 1.1, which is the one
// the owner reported first: opening the studio to start something new came up
// carrying the last tutorial.
//
// The cause was never subtle. `_restoreDraft` loaded the one stored draft slot
// **unconditionally**, and a handover replaced only the working tree — so the
// title and every finished part came back whatever the trainer had asked for.
// The slot had no identity and the screen had no idea what it was opened for.
//
// ---------------------------------------------------------------------------
// WHAT CHANGES, AND WHICH FILE SAYS SO
//
// `test/tutorial_studio_test.dart` — the phase-4a gate — asserts the **old**
// behaviour in two tests: reopen the screen with no argument and the draft is
// silently back. That is the behaviour D4 removes, and the owner approved D4 on
// 6.9.2026. Those two tests are updated to answer the question the screen now
// asks; their assertions are otherwise unchanged, and the draft still comes
// back. It is declared here rather than left for a reader to notice.
//
// `test/tutorial_authoring_test.dart` opens through the Analysis door on every
// test, which is `TutorialEntry.fromAnalysis` and behaves exactly as before. It
// passes **unedited**, as §8 requires.
//
// ---------------------------------------------------------------------------
// WHY THE DOOR'S QUESTION IS NOT ASKED HERE
//
// D4 says a handover either joins the tutorial being written or starts a new
// one. That question is answered **at the door**, by the Analysis Studio,
// before it navigates — a question about where a line should go belongs beside
// the line, while the trainer can still see it. This screen is told the answer.
// Wiring the door is P4.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';

const String openingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 'tok',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  /// Puts a draft in the slot, the way leaving the screen would have.
  Future<void> storeDraft({int? lessonId, required String title}) async {
    final draft = TutorialDraft(
      lessonId: lessonId,
      title: title,
      sections: [
        TutorialSection.fromStep({
          'fen': openingFen,
          'pgn': '1. e4 { Zapamti ovo. }',
          'title': 'Nedovršen deo',
        }),
      ],
    );
    await TutorialDraftService.instance.flush(draft);
  }

  Future<void> open(WidgetTester tester, TutorialEntry entry) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: TutorialStudioScreen(session: session, entry: entry)),
    );
    await tester.pumpAndSettle();
  }

  group('a new tutorial does not inherit the last one', () {
    testWidgets('an unfinished draft is offered by name, not adopted',
        (tester) async {
      await storeDraft(title: 'Opozicija');
      await open(tester, const TutorialEntry.blank('Skakač i pešak'));

      expect(find.textContaining('Opozicija'), findsWidgets,
          reason: 'the trainer was not told which tutorial is waiting — '
              'a draft that comes back unannounced is what made this feel '
              'haunted');
      expect(find.text('Odustajem'), findsOneWidget,
          reason: 'the question has no way out, so a trainer who did not mean '
              'to be asked has to answer it with somebodys work');
      expect(find.text('Nov'), findsOneWidget);
      expect(find.text('Nastavi'), findsOneWidget);
    });

    testWidgets('declining leaves a clean screen with the new name',
        (tester) async {
      await storeDraft(title: 'Opozicija');
      await open(tester, const TutorialEntry.blank('Skakač i pešak'));

      await tester.tap(find.text('Nov'));
      await tester.pumpAndSettle();

      expect(find.text('Skakač i pešak'), findsOneWidget,
          reason: 'the new tutorial did not get the name it was opened with');
      expect(find.text('Nedovršen deo'), findsNothing,
          reason: 'the declined draft is still on screen');

      // And it does not come back tomorrow: a draft the trainer has just
      // thrown away must not be waiting the next time they start something.
      expect(await TutorialDraftService.instance.load(), isNull);
    });

    testWidgets('accepting brings the unfinished tutorial back',
        (tester) async {
      await storeDraft(title: 'Opozicija');
      await open(tester, const TutorialEntry.blank('Skakač i pešak'));

      await tester.tap(find.text('Nastavi'));
      await tester.pumpAndSettle();

      expect(find.text('Opozicija'), findsWidgets);
      expect(find.text('Nedovršen deo'), findsOneWidget);
    });

    testWidgets('backing out leaves the unfinished tutorial where it was',
        (tester) async {
      // The answer that was missing. „Odbaci" and „Nastavi" made a trainer who
      // opened this screen by accident choose between somebody's work and
      // starting over — and dismissing the dialog was read as „discard".
      await storeDraft(title: 'Opozicija');
      await open(tester, const TutorialEntry.blank('Skakač i pešak'));

      await tester.tap(find.text('Odustajem'));
      await tester.pumpAndSettle();

      final kept = await TutorialDraftService.instance.load();
      expect(kept, isNotNull,
          reason: 'backing out of the question deleted the tutorial it was '
              'asking about');
      expect(kept!.title, 'Opozicija');
      expect(kept.sections.single.title, 'Nedovršen deo');
    });

    testWidgets('and the blank screen it was asked from is not written either',
        (tester) async {
      // The trap under the trap: this screen flushes its draft on the way out,
      // and the draft it holds at that moment is the blank one it opened with.
      // Backing out has to suppress that write, or the slot ends up holding
      // „Skakač i pešak" with nothing in it — which is the stored tutorial
      // gone by another route.
      await storeDraft(title: 'Opozicija');
      await open(tester, const TutorialEntry.blank('Skakač i pešak'));

      await tester.tap(find.text('Odustajem'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 700));

      final kept = await TutorialDraftService.instance.load();
      expect(kept?.title, 'Opozicija',
          reason: 'the blank screen wrote itself over the stored draft as it '
              'closed');
    });

    testWidgets('with nothing stored there is no question at all',
        (tester) async {
      await open(tester, const TutorialEntry.blank('Skakač i pešak'));

      expect(find.text('Nastavi'), findsNothing);
      expect(find.text('Nov'), findsNothing);
      expect(find.text('Skakač i pešak'), findsOneWidget);
    });
  });

  group('opening a saved tutorial opens that tutorial', () {
    Map<String, dynamic> lesson(int id, String title) => {
          'id': id,
          'title': title,
          'position_list': [
            {
              'id': 'step0001',
              'fen': openingFen,
              'title': 'Uvod',
              'kind': 'show',
            },
          ],
        };

    testWidgets('its parts are on screen', (tester) async {
      await open(tester, TutorialEntry.saved(lesson(12, 'Opozicija')));

      expect(find.text('Opozicija'), findsWidgets);
      expect(find.text('Uvod'), findsOneWidget);
    });

    testWidgets('a draft of a different tutorial is left alone',
        (tester) async {
      // The heart of D4. One slot held one draft with no identity, so opening
      // any tutorial came up carrying whatever was last written.
      await storeDraft(lessonId: 99, title: 'Neki drugi');
      await open(tester, TutorialEntry.saved(lesson(12, 'Opozicija')));

      expect(find.text('Nedovršen deo'), findsNothing,
          reason: 'another tutorial’s unsaved work was opened as this one');
      expect(find.text('Uvod'), findsOneWidget);
      expect(find.text('Nastavi'), findsNothing,
          reason: 'a draft of a different tutorial is not this trainer’s '
              'business right now, so it is not a question either');
    });

    testWidgets('a draft of this tutorial is picked up where it was left',
        (tester) async {
      await storeDraft(lessonId: 12, title: 'Opozicija');
      await open(tester, TutorialEntry.saved(lesson(12, 'Opozicija')));

      expect(find.text('Nedovršen deo'), findsOneWidget,
          reason: 'the trainer’s unsaved edits to this very tutorial were '
              'thrown away');
    });
  });

  group('the door from the Analysis Studio', () {
    testWidgets('carries on with the tutorial being written', (tester) async {
      await storeDraft(title: 'Opozicija');
      await open(
        tester,
        TutorialEntry.fromAnalysis(TutorialHandover.position(openingFen)),
      );

      expect(find.text('Opozicija'), findsWidgets,
          reason: 'the flow the door exists for: work the next part out in the '
              'Studio, hand it over, carry on with the same tutorial');
    });

    testWidgets('or starts a new one when the door said so', (tester) async {
      await storeDraft(title: 'Opozicija');
      await open(
        tester,
        TutorialEntry.fromAnalysis(
          TutorialHandover.position(openingFen),
          intoOpenDraft: false,
        ),
      );

      expect(find.text('Nedovršen deo'), findsNothing);
      expect(find.text('Nastavi'), findsNothing,
          reason: 'the question was already answered at the door');
    });
  });
}
