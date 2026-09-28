// The doors of the position study — docs/PLAN-STUDIJA-POZICIJE.md, D1 and D5:
// „Study this position" where Auto Analysis stood, „Generate AI comment" and
// the repertoire's „AI on position" on the study's own path, and nothing left
// in the app that asks the routes Gemini answered.
//
// The screen is drawn for what a reader can reach (rule 10), and read by
// structure (`support/dart_source.dart`) for what must not come back: a
// comment that names a retired label is writing about code, not code.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/widgets/position_study_dialog.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/dart_source.dart';

const _owner2 =
    'rn2kbnr/pp2pppp/2p5/3PN3/4b3/1P4P1/1P1PPP1P/RNB1KB1R w KQkq - 1 8';

Future<void> _open(WidgetTester tester, Size size, {String token = 't'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: AnalysisStudioScreen(
      userSession: UserSession(
          token: token, id: 1, email: 'a@b.c', name: 'N', role: 'korisnik'),
      initialFen: _owner2,
    ),
  ));
  await tester.pumpAndSettle();
}

Map<String, String> _sourcesOfLib() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll('\\', '/'): file.readAsStringSync(),
    };

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  testWidgets(
      'in a window the bar has „Study this position", and it opens '
      'the study', (tester) async {
    await _open(tester, const Size(1280, 900));
    expect(find.byTooltip('Auto Analysis ⚡'), findsNothing);
    final door = find.byTooltip(PositionStudyDialog.title);
    expect(door, findsOneWidget);

    await tester.tap(door);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final dialog =
        tester.widget<PositionStudyDialog>(find.byType(PositionStudyDialog));
    expect(dialog.startNode.fen, _owner2,
        reason: 'the study is of the position the board stands on');
    expect(dialog.ask, isNotNull, reason: 'signed in: the words can be asked');
    expect(dialog.tablebase, isNotNull);
    expect(dialog.onOpenAsTutorial, isNotNull);
    expect(dialog.onHold, isNotNull);
    expect(dialog.onRelease, isNotNull);
  });

  testWidgets('on a phone it is behind „More tools", by its name',
      (tester) async {
    await _open(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('More tools'));
    await tester.pumpAndSettle();
    expect(find.text('Auto Analysis ⚡'), findsNothing);
    final row = find.text(PositionStudyDialog.title);
    expect(row, findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PositionStudyDialog), findsOneWidget);
    final box = tester.getRect(find.byType(Dialog));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(360));
    expect(tester.getRect(find.byKey(const ValueKey('study-start'))).bottom,
        lessThanOrEqualTo(640));
  });

  testWidgets('a guest is offered the study without its words', (tester) async {
    await _open(tester, const Size(1280, 900), token: '');
    await tester.tap(find.byTooltip(PositionStudyDialog.title));
    await tester.pumpAndSettle();
    final dialog =
        tester.widget<PositionStudyDialog>(find.byType(PositionStudyDialog));
    expect(dialog.ask, isNull);
    expect(dialog.noWordsReason, 'Sign in to have comments written.');
    expect(find.text('Sign in to have comments written.'), findsOneWidget);
  });

  test('Auto Analysis is gone from lib/, by its labels and by its dialog', () {
    final sources = _sourcesOfLib();
    final literals = {
      for (final src in sources.values) ...literalsIn(src),
    };
    for (final gone in [
      'Auto Analysis ⚡',
      'Automatic Position Analysis',
      'Start Automatic Analysis ⚡',
    ]) {
      expect(literals.where((s) => s.contains(gone)), isEmpty,
          reason: '„$gone" survives');
    }
    expect(
      sources.keys.where((p) => p.endsWith('auto_analysis_dialog.dart')),
      isEmpty,
    );
    for (final entry in sources.entries) {
      expect(codeOf(entry.value), isNot(contains('AutoAnalysisDialog')),
          reason: entry.key);
    }
  });

  test('nothing in lib/ asks the routes Gemini answered', () {
    final sources = _sourcesOfLib();
    expect(sources.length, greaterThan(200), reason: 'lib/ was walked');
    for (final entry in sources.entries) {
      for (final literal in literalsIn(entry.value)) {
        expect(literal, isNot(contains('/ai/explain-position')),
            reason: entry.key);
        expect(literal, isNot(contains('/ai/generate-move-comment')),
            reason: entry.key);
      }
      final code = codeOf(entry.value);
      expect(code, isNot(contains('generateMoveComment(')), reason: entry.key);
      expect(code, isNot(contains('.explainPosition(')), reason: entry.key);
    }
  });

  test('„Generate AI comment" and „AI on position" go the study\'s way', () {
    final screen = codeOf(
        File('lib/features/analysis_studio/screens/analysis_studio_screen.dart')
            .readAsStringSync());
    final at = screen.indexOf('Future<void> _generateAiComment()');
    expect(at, greaterThan(0));
    final body = _bodyAt(screen, at);
    expect(body, contains('commentOnMove('));
    expect(body, contains('_stockfishService.hold('));
    expect(body, contains('_stockfishService.release('));
    expect(
        body.indexOf('release('), lessThan(body.indexOf('showCommentDialog(')),
        reason: 'the engine is handed back before anything is shown');

    final ask = codeOf(
        File('lib/features/repertoire/widgets/repertoire_position_ask.dart')
            .readAsStringSync());
    final asking = _bodyAt(ask, ask.indexOf('askAboutPosition({'));
    expect(asking, contains('commentOnPosition('));
    expect(asking, contains('engine.release(holder)'));
  });

  test('the manual names the door the app has', () {
    final page =
        File('../site/mislisha/manual/analysis.html').readAsStringSync();
    expect(
        page, contains('<span class="ui">${PositionStudyDialog.title}</span>'));
    expect(page,
        contains('<span class="ui">${PositionStudyDialog.withWords}</span>'));
    expect(
        page,
        contains(
            '<span class="ui">${PositionStudyDialog.openAsTutorial}</span>'));
    expect(page, isNot(contains('Automatic Position Analysis')));
    expect(page, isNot(contains('Auto Analysis')));
  });
}

/// The body of the function whose signature starts at [at], by its braces.
String _bodyAt(String code, int at) {
  expect(at, greaterThanOrEqualTo(0), reason: 'the function is there');
  // Past the parameter list: the body's brace is the first one after the
  // parenthesis that closes it.
  var depth = 0;
  var i = code.indexOf('(', at);
  for (; i < code.length; i++) {
    if (code[i] == '(') depth++;
    if (code[i] == ')' && --depth == 0) break;
  }
  final open = code.indexOf('{', i);
  depth = 0;
  for (var j = open; j < code.length; j++) {
    if (code[j] == '{') depth++;
    if (code[j] == '}' && --depth == 0) return code.substring(open, j + 1);
  }
  fail('the body does not close');
}
