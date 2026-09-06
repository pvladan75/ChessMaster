// The gate for P4 of `docs/PLAN-STUDIO-REDIZAJN.md` — the way in.
//
// Written before the batch, and kept here rather than in `test/` until it
// lands: it names a widget nobody has built, so it does not compile against
// today's tree, and a suite that does not compile says nothing about anything
// else. It moves to `chess_app/test/tutorial_ulaz_test.dart` in the merge
// commit, the way every gate before it was moved.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT FOR BATCH 56
//
// Written here, once, so the batch does not decide it and the reviewer does not
// have to guess what was meant. Everything below is what this file asserts.
//
// **One new widget owns the whole way in.**
//
//   lib/features/tutorial_studio/widgets/tutorial_library_card.dart
//
//   class TutorialLibraryCard extends StatelessWidget {
//     const TutorialLibraryCard({super.key, required this.session, this.api});
//     final UserSession session;
//     /// The seam a test reaches the library list through. Defaulted to a real
//     /// service against this session's token, so nothing but a test passes it.
//     final LessonApiService? api;
//   }
//
// It is one widget rather than two callbacks on `HomeBibliotekaTab` because
// both actions end in the same place — a `TutorialStudioScreen` with an
// entry — and because a card that draws itself only on Windows must decide
// that in one place. `HomeBibliotekaTab` gains one field, `tutorialCard`, and
// draws it where it is given; `home_screen.dart` passes
// `TutorialLibraryCard(session: ...)`. **`HomeBibliotekaTab` stays stateless
// and learns nothing about tutorials.**
//
// **Strings, frozen.** These are the only user-facing strings this batch adds,
// and they land in `tutorial_library_card.dart` and nowhere else:
//
//   'Interaktivni tutorijali'          the card's heading
//   'Napravite tutorijal koji dete prolazi samo — pozicija po poziciju, sa '
//   'komentarom, strelicama i pitanjima.'                 the card's sentence
//   'Novi tutorijal'                   the first button, and the name dialog's
//                                      title
//   'Otvori sačuvani tutorijal'        the second button, and the picker's title
//   'Naziv tutorijala'                 the name field's label
//   'Otkaži'                           on both dialogs
//   'Napravi'                          confirms the name dialog
//   'Nemate nijedan sačuvan tutorijal.'   the picker with nothing to show
//   'Ne mogu da učitam listu tutorijala.' the picker when the list call failed
//
// Nothing else. „Deo" is D7 and lands with the screen in P5, so this batch does
// not rename „Primer" anywhere.
//
// **Where it is drawn.** Behind `isTutorialStudioAvailable`, the one named
// predicate, read and never rewritten. A second `Platform.isWindows` anywhere
// in `lib/` is a finding, and the last test in this file is what says so.
//
// **What each action does.**
//
//   'Novi tutorijal'  ->  a dialog with one text field, then
//                         TutorialStudioScreen(entry: TutorialEntry.blank(name))
//                         An empty or blank name does not navigate: the tutorial
//                         has to have a name before the first save anyway, and
//                         finding that out twenty minutes later is the expensive
//                         way to learn it.
//
//   'Otvori sačuvani' ->  api.fetchAll(), keep the rows that are tutorials —
//                         `position_list` a non-empty List — then a dialog
//                         listing their titles. Picking one opens
//                         TutorialStudioScreen(entry: TutorialEntry.saved(row)),
//                         with the **whole row**, because
//                         `TutorialDraft.fromLesson` reads `id`, `title` and
//                         `position_list` off it.
//
// **The Analysis door asks where the line goes, and passes the answer.**
// „Kreiraj interaktivni tutorijal" already asks what to carry (the position, or
// the whole line). It now asks a second question — into the tutorial being
// written, or into a new one — and passes it as `intoOpenDraft`. That question
// belongs at the door, while the trainer can still see the line; the studio is
// told the answer and never asks it. Cancelling either question navigates
// nowhere.
//
// The question is a **top-level function in the same new file**, so it can be
// tested without building the Analysis Studio — 2446 lines with an engine, an
// explorer and a tablebase in it. A gate that has to boot all that to read one
// dialog is a gate nobody will keep:
//
//   /// true  — into the tutorial being written
//   /// false — into a new one
//   /// null  — the trainer said neither
//   Future<bool?> askTutorialDestination(BuildContext context);
//
// Its strings, also frozen and also in that file:
//
//   'Gde ide ova linija?'                      the title
//   'Nastavi tutorijal koji uređujem'          -> true
//   'Počni nov tutorijal'                      -> false
//   'Otkaži'                                   -> null (shared with the others)
//
// `analysis_studio_screen.dart` calls it after the „šta prenosimo" question it
// already asks, and passes the answer straight through as `intoOpenDraft`. That
// is the only edit that file gets.
//
// **Not this batch.** The studio's layout (P5), the timeline (P6), drawing
// (P7), retiring `LessonStepEditorPanel` (P8). Nothing under
// `lib/features/tutorial_studio/` changes except the new file — the model,
// the screen and the services are frozen and were merged before this brief was
// written.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';

const String openingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A library with two tutorials and one plain saved position.
///
/// The plain position is the point: `GET /lessons` answers with everything the
/// trainer has saved, and a row with no `position_list` is a diagram, not a
/// tutorial. Offering it here would open the studio on something that has no
/// parts.
LessonApiService libraryApi({bool fail = false, bool empty = false}) =>
    LessonApiService(
      authToken: 'tok',
      client: MockClient((req) async {
        if (fail) return http.Response('nope', 500);
        return http.Response(
          jsonEncode(empty
              ? []
              : [
                  {
                    'id': 12,
                    'title': 'Opozicija',
                    'position_list': [
                      {
                        'id': 'step0001',
                        'fen': openingFen,
                        'title': 'Uvod',
                        'kind': 'show',
                      },
                    ],
                  },
                  {
                    'id': 13,
                    'title': 'Samo pozicija',
                    'fen': openingFen,
                    'position_list': null,
                  },
                  {
                    'id': 14,
                    'title': 'Vezani top',
                    'position_list': [
                      {
                        'id': 'step0002',
                        'fen': openingFen,
                        'title': 'Prvi deo',
                        'kind': 'show',
                      },
                    ],
                  },
                ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

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
    debugTutorialStudioAvailable = true;
  });

  tearDown(() => debugTutorialStudioAvailable = null);

  Future<void> pump(WidgetTester tester, {LessonApiService? api}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TutorialLibraryCard(session: session, api: api),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The entry the studio was opened with, or null when nothing was opened.
  ///
  /// Asserting on **what the screen was constructed with** rather than on what
  /// it then draws: the whole of P3b is that the entry decides what the screen
  /// does, so the entry is the thing this batch has to get right.
  TutorialEntry? openedWith(WidgetTester tester) {
    final found = find.byType(TutorialStudioScreen);
    if (found.evaluate().isEmpty) return null;
    return tester.widget<TutorialStudioScreen>(found).entry;
  }

  group('where the door is drawn', () {
    testWidgets('on Windows, the card is there', (tester) async {
      await pump(tester);
      expect(find.text('Interaktivni tutorijali'), findsOneWidget);
      expect(find.text('Novi tutorijal'), findsOneWidget);
      expect(find.text('Otvori sačuvani tutorijal'), findsOneWidget);
    });

    testWidgets('everywhere else, it is not', (tester) async {
      // Decision 5 of docs/PLAN-TUTORIJAL.md: the studio is a desktop screen
      // and Android is 360–410 dp. The card must not be a door to a screen that
      // is not there.
      debugTutorialStudioAvailable = false;
      await pump(tester);
      expect(find.text('Interaktivni tutorijali'), findsNothing);
      expect(find.text('Novi tutorijal'), findsNothing);
    });
  });

  group('a new tutorial', () {
    testWidgets('is named before it is opened', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Novi tutorijal'));
      await tester.pumpAndSettle();

      expect(find.text('Naziv tutorijala'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Skakač i pešak');
      await tester.tap(find.text('Napravi'));
      await tester.pumpAndSettle();

      final entry = openedWith(tester);
      expect(entry, isA<TutorialEntryBlank>(),
          reason: 'a new tutorial must not be opened as anything else — '
              'a `saved` or a `fromAnalysis` entry would adopt the last '
              'draft, which is the complaint this phase exists for');
      expect((entry! as TutorialEntryBlank).title, 'Skakač i pešak');
    });

    testWidgets('a blank name opens nothing', (tester) async {
      // It has to have a name before the first save anyway, and finding that
      // out twenty minutes later is the expensive way to learn it.
      await pump(tester);
      await tester.tap(find.text('Novi tutorijal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Napravi'));
      await tester.pumpAndSettle();

      expect(openedWith(tester), isNull);
    });

    testWidgets('cancelling opens nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Novi tutorijal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Otkaži'));
      await tester.pumpAndSettle();

      expect(openedWith(tester), isNull);
    });
  });

  group('a saved tutorial', () {
    testWidgets('the list offers tutorials and not plain positions',
        (tester) async {
      await pump(tester, api: libraryApi());
      await tester.tap(find.text('Otvori sačuvani tutorijal'));
      await tester.pumpAndSettle();

      expect(find.text('Opozicija'), findsOneWidget);
      expect(find.text('Vezani top'), findsOneWidget);
      expect(find.text('Samo pozicija'), findsNothing,
          reason: 'a row with no position_list is a diagram, and opening the '
              'studio on it opens a tutorial with no parts');
    });

    testWidgets('picking one opens that tutorial, whole', (tester) async {
      await pump(tester, api: libraryApi());
      await tester.tap(find.text('Otvori sačuvani tutorijal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vezani top'));
      await tester.pumpAndSettle();

      final entry = openedWith(tester);
      expect(entry, isA<TutorialEntrySaved>());
      final lesson = (entry! as TutorialEntrySaved).lesson;
      expect(lesson['id'], 14,
          reason: 'without the id the draft cannot know which tutorial it is, '
              'and the next save makes a second one');
      expect(lesson['title'], 'Vezani top');
      expect((lesson['position_list'] as List).single['id'], 'step0002',
          reason: 'the steps must travel with their ids — a step id is what a '
              'child’s schedule and their recorded answers are named by');
    });

    testWidgets('an empty library says so', (tester) async {
      await pump(tester, api: libraryApi(empty: true));
      await tester.tap(find.text('Otvori sačuvani tutorijal'));
      await tester.pumpAndSettle();

      expect(find.text('Nemate nijedan sačuvan tutorijal.'), findsOneWidget,
          reason: 'an empty box tells the trainer nothing about whether it '
              'failed or there is nothing there');
      expect(openedWith(tester), isNull);
    });

    testWidgets('a failed list says that instead', (tester) async {
      // `fetchAll` answers with an empty list on any failure — it feeds a list
      // that is drawn either way. So „nothing saved" and „could not reach the
      // server" arrive here identically unless this card asks.
      await pump(tester, api: libraryApi(fail: true));
      await tester.tap(find.text('Otvori sačuvani tutorijal'));
      await tester.pumpAndSettle();

      expect(find.text('Ne mogu da učitam listu tutorijala.'), findsOneWidget);
      expect(openedWith(tester), isNull);
    });
  });

  group('the door asks where the line goes', () {
    /// A button that asks, and remembers the answer. The question is a
    /// function, so this is all the scaffolding it needs — no engine, no
    /// explorer, no tablebase.
    Future<Object?> ask(WidgetTester tester, String tapWhat) async {
      Object? answer = 'not asked';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                answer = await askTutorialDestination(context);
              },
              child: const Text('pitaj'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('pitaj'));
      await tester.pumpAndSettle();
      expect(find.text('Gde ide ova linija?'), findsOneWidget);
      await tester.tap(find.text(tapWhat));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('carrying on with the open tutorial answers true',
        (tester) async {
      expect(await ask(tester, 'Nastavi tutorijal koji uređujem'), isTrue);
    });

    testWidgets('starting a new one answers false', (tester) async {
      expect(await ask(tester, 'Počni nov tutorijal'), isFalse);
    });

    testWidgets('saying neither answers null, and nothing is opened',
        (tester) async {
      // Being asked and saying nothing is not the same as choosing the first
      // answer — the rule the branch sheet on the move strip already keeps.
      expect(await ask(tester, 'Otkaži'), isNull);
    });

    test('the Studio passes the answer through rather than deciding it', () {
      final src = File('lib/features/analysis_studio/screens/'
              'analysis_studio_screen.dart')
          .readAsStringSync();
      expect(src.contains('askTutorialDestination'), isTrue,
          reason: 'the door stopped asking');
      expect(src.contains('intoOpenDraft:'), isTrue,
          reason: 'the answer was asked for and then thrown away, which is '
              'worse than not asking');
    });
  });

  group('what the card must not become', () {
    test('the tutorial studio has exactly one availability predicate', () {
      // **This test asserted something false when it was written, and batch 56
      // reported it rather than working around it.** It had exempted
      // `engine_settings_dialog.dart` at a path that does not exist — it lives
      // in `lib/widgets/`, not under `analysis_studio/` — and it had assumed the
      // predicate was the only place in `lib/` that asks about Windows at all.
      // Four other files ask, legitimately and for unrelated reasons: the
      // desktop sign-in, the engine download, the native Stockfish binding and
      // the room screen. A gate is worth nothing if what it claims is untrue,
      // and a gate naming a file that is not there cannot be noticed by
      // failing.
      //
      // The rule that is actually worth keeping is narrower. „Which screens
      // stop making sense on a phone" must stay a one-line change, so the
      // *tutorial studio's* availability has exactly one home. Everything else
      // asking the platform a different question is not this rule's business.
      //
      // So: the list is frozen, and a **sixth** file is the finding. The same
      // idiom this project already uses for the analyzer — compare the list,
      // not the count. Adding a genuine new desktop capability means adding a
      // line here, deliberately, which is the point.
      const known = {
        'lib/features/tutorial_studio/tutorial_studio_availability.dart',
        'lib/screens/chess_game_screen.dart',
        'lib/services/desktop_google_sign_in_io.dart',
        'lib/services/engine_download_service.dart',
        'lib/services/stockfish_service_native.dart',
        'lib/widgets/engine_settings_dialog.dart',
      };

      final asking = <String>{};
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (!file.readAsStringSync().contains('Platform.isWindows')) continue;
        asking.add(file.path.replaceAll(r'\', '/'));
      }

      expect(asking.difference(known), isEmpty,
          reason: 'a new file decides a platform question for itself — if it '
              'is about whether the tutorial studio exists, read '
              'isTutorialStudioAvailable instead; if it is about something '
              'else, add it to the list above and say why');
      expect(known.difference(asking), isEmpty,
          reason: 'this list names a file that no longer asks — a gate naming '
              'a file that is not there cannot be noticed by failing, which is '
              'exactly how this test shipped wrong');
    });

    test('the card owns its own strings and its own dialogs', () {
      final card = File('lib/features/tutorial_studio/widgets/'
              'tutorial_library_card.dart')
          .readAsStringSync();
      expect(card.contains('isTutorialStudioAvailable'), isTrue);
      expect(card.contains('TutorialEntry.blank'), isTrue);
      expect(card.contains('TutorialEntry.saved'), isTrue);

      // The tab stays a tab: it draws what it is given and knows nothing about
      // tutorials, entries or platforms.
      final tab =
          File('lib/widgets/home/biblioteka_tab.dart').readAsStringSync();
      expect(tab.contains('TutorialEntry'), isFalse,
          reason: 'the library tab has started deciding what a tutorial is');
      expect(tab.contains('isTutorialStudioAvailable'), isFalse,
          reason: 'the platform question belongs in the card, in one place');
    });
  });
}
