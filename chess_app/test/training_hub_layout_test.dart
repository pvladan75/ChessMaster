// `docs/PLAN-POCETNI-TABOVI.md`, phase 4 — the Practise tab gives each phase
// of the game its own column where three fit, and stops at three.
//
// The column count is read from where the three phase labels and their cards
// are painted, never from the code's own arithmetic. The widths are chosen one
// in each band of `AdaptiveCardGrid.columnsFor` for the box the cards get (the
// tab's own padding taken off): 360 gives one, 700 two, 1000 and 1400 three.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';

/// The hub inside a box exactly [width] wide, in a window of [window] — the
/// two differ in one case, which is how reading the window gets caught.
Future<void> _pump(WidgetTester tester, double width,
    {Size window = const Size(1920, 3000)}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    // Inside a vertical scroll view, as `TrainingHubScreen` holds it: the hub
    // is given unbounded height there, so its `Center` never centres it
    // vertically — a bare box of the window's height would.
    home: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: CategorySelectionHubWidget(
              onSelectMatePuzzle: (_) {},
              onSelectBasicMate: (_) {},
              onSelectWinningPosition: () {},
              onSelectTactics: () {},
              onSelectEndgameWin: () {},
              onSelectEndgameDraw: () {},
              onSelectBlunderGames: () {},
              onSelectRepertoire: () {},
              onSelectMyGames: () {},
              onSelectMistakesDrill: () {},
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

const _opening = 'OPENING';
const _tactics = 'TACTICS';
const _endgame = 'ENDGAME AND TECHNIQUE';

/// Each phase's label and the titles of the cards under it, in today's order.
const _phases = {
  _opening: ['Opening repertoire', 'My games', 'My mistakes'],
  _tactics: ['Tactics tailored to you', 'Puzzles: Mate in 1, 2 or 3 moves'],
  _endgame: [
    'Endgames from master games',
    'Practice basic checkmates',
    'Find the winning path',
  ],
};

Rect _at(WidgetTester tester, String text) => tester.getRect(find.text(text));

/// The card a title sits in.
Rect _card(WidgetTester tester, String title) => tester.getRect(
    find.ancestor(of: find.text(title), matching: find.byType(Card)).first);

/// How many distinct columns the three phase labels are painted in.
int _columns(WidgetTester tester) => [_opening, _tactics, _endgame]
    .map((l) => _at(tester, l).left.round())
    .toSet()
    .length;

/// Every card of [phase] sits in its label's column, under it, in order.
void _expectPhaseStacked(WidgetTester tester, String phase) {
  final label = _at(tester, phase);
  var above = label.bottom;
  for (final title in _phases[phase]!) {
    final card = _card(tester, title);
    expect(card.top, greaterThanOrEqualTo(above),
        reason: '„$title" is not under what comes before it in $phase');
    expect((card.left - label.left).abs(), lessThan(8),
        reason: '„$title" is not in the $phase column');
    above = card.bottom;
  }
}

void main() {
  testWidgets('one column on a phone, in today\'s order', (tester) async {
    await _pump(tester, 360, window: const Size(360, 3000));
    expect(_columns(tester), 1);
    expect(_at(tester, _tactics).top,
        greaterThan(_card(tester, 'My mistakes').bottom));
    expect(_at(tester, _endgame).top,
        greaterThan(_card(tester, 'Puzzles: Mate in 1, 2 or 3 moves').bottom));
    for (final p in _phases.keys) {
      _expectPhaseStacked(tester, p);
    }
  });

  testWidgets('two columns: opening and tactics, then the endgame beside them',
      (tester) async {
    await _pump(tester, 700);
    expect(_columns(tester), 2);
    final o = _at(tester, _opening);
    final t = _at(tester, _tactics);
    final e = _at(tester, _endgame);
    expect(t.left, o.left, reason: 'tactics left the opening column');
    expect(t.top, greaterThan(_card(tester, 'My mistakes').bottom));
    expect(e.top, o.top, reason: 'the endgame column does not start level');
    expect(e.left, greaterThan(o.right));
    for (final p in _phases.keys) {
      _expectPhaseStacked(tester, p);
    }
  });

  for (final width in [1000.0, 1400.0]) {
    testWidgets('three columns at $width: one per phase', (tester) async {
      await _pump(tester, width);
      expect(_columns(tester), 3);
      final o = _at(tester, _opening);
      final t = _at(tester, _tactics);
      final e = _at(tester, _endgame);
      expect(t.top, o.top);
      expect(e.top, o.top);
      expect(t.left, greaterThan(o.left));
      expect(e.left, greaterThan(t.left));
      for (final p in _phases.keys) {
        _expectPhaseStacked(tester, p);
      }
    });
  }

  testWidgets('never more than three card widths, however wide',
      (tester) async {
    await _pump(tester, 1920);
    expect(_columns(tester), 3);
    for (final titles in _phases.values) {
      for (final title in titles) {
        expect(_card(tester, title).width,
            lessThanOrEqualTo(AdaptiveCardGrid.maxTileWidth),
            reason: '„$title" stretched past one card');
      }
    }
  });

  testWidgets('decided from the box the hub is given, not the window',
      (tester) async {
    // A 1920 window with the hub in a 400 box. The hub before this plan read
    // `Breakpoints.isWide` — the window — and split 400 px into two columns.
    await _pump(tester, 400);
    expect(_columns(tester), 1,
        reason: 'the hub read the window and put two columns in 400 px');
  });

  testWidgets('the phases are the first thing on the tab', (tester) async {
    // The „Chess trainer and drills" card sat above them until 21.9.2026 and
    // was removed on the owner's word. Measured by position rather than by
    // looking for its words, so a header of any wording fails here.
    for (final w in [360.0, 1400.0]) {
      await _pump(tester, w, window: Size(w, 3000));
      expect(_at(tester, _opening).top, lessThan(40),
          reason: 'something sits above the phases at $w');
    }
  });

  testWidgets('nothing overflows at 360, 700, 1000 and 1920', (tester) async {
    for (final w in [360.0, 700.0, 1000.0, 1920.0]) {
      await _pump(tester, w, window: Size(w, 3000));
      expect(tester.takeException(), isNull, reason: 'at $w');
    }
  });
}
