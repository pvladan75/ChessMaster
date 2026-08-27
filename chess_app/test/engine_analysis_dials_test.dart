import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/engine_analysis_dials.dart';

/// **Two questions that used to be one number.**
///
/// Until 27.8.2026 Settings held a single "engine depth" that was both how
/// strongly the engine played against you and how deeply every board in the app
/// analysed. Turning the opponent down to help a beginner also made every
/// evaluation shallower, and there was no way to ask one position for five
/// lines without changing how the engine played everywhere.
///
/// Now: a level (Lako/Srednje/Teško) for the opponent, and dials on each board
/// for what that board shows.
void main() {
  group('the dials on a board', () {
    testWidgets('offer depths up to 50', (tester) async {
      // The old ceiling was 28, and it was a leftover from when this number
      // also decided how long the opponent thought before moving.
      expect(EngineAnalysisDials.depths.last, 50);
      expect(EngineAnalysisDials.lineCounts, [1, 2, 3, 4, 5]);
    });

    testWidgets('a depth that is not on the list still opens', (tester) async {
      // Cost a test run to find: `values.contains(v) ? values : [...]..sort()`
      // binds the cascade to the whole conditional, so it sorted the *const*
      // list and threw UnsupportedError while building — every screen with an
      // engine panel went white.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineAnalysisDials(
            depth: 27,
            lines: 2,
            onDepthChanged: (_) {},
            onLinesChanged: (_) {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('27'), findsOneWidget);
    });

    testWidgets('picking a depth reports it', (tester) async {
      int? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineAnalysisDials(
            depth: 20,
            lines: 2,
            onDepthChanged: (value) => picked = value,
            onLinesChanged: (_) {},
          ),
        ),
      ));

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('42').last);
      await tester.pumpAndSettle();

      expect(picked, 42);
    });

    testWidgets('while a search runs, the dials do not take a new one',
        (tester) async {
      var picked = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EngineAnalysisDials(
            depth: 20,
            lines: 2,
            enabled: false,
            onDepthChanged: (_) => picked++,
            onLinesChanged: (_) => picked++,
          ),
        ),
      ));

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(picked, 0, reason: 'onemogućen padajući meni se ne otvara');
    });
  });

  group('the engine plays at a level, and analyses at a depth', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('three levels, and each one is a depth', () {
      expect(AppSettingsService.kEnginePlayDepths,
          {'lako': 18, 'srednje': 24, 'tesko': 30});
      expect(AppSettingsService.kEnginePlayLevelNames.keys,
          AppSettingsService.kEnginePlayDepths.keys);
    });

    test('an old hand-set depth becomes the nearest level, once', () async {
      // Somebody who had set 29 was asking for a strong opponent; they should
      // not be dropped to the default because the setting changed shape.
      SharedPreferences.setMockInitialValues({'app_engine_depth': 29});

      await AppSettingsService.instance.init();

      expect(AppSettingsService.instance.enginePlayLevel, 'tesko');
      expect(AppSettingsService.instance.enginePlayDepth, 30);
      // And the number they chose is kept where it still means something: how
      // deep their boards analyse.
      expect(AppSettingsService.instance.analysisDepth, 29);
    });

    test('nearest means nearest, not rounded up', () async {
      // 26 sits between Srednje (24) and Teško (30) and is closer to Srednje.
      SharedPreferences.setMockInitialValues({'app_engine_depth': 26});

      await AppSettingsService.instance.init();

      expect(AppSettingsService.instance.enginePlayLevel, 'srednje');
    });

    test('the level is remembered and the depth follows it', () async {
      await AppSettingsService.instance.init();
      await AppSettingsService.instance.setEnginePlayLevel('lako');

      expect(AppSettingsService.instance.enginePlayDepth, 18);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_engine_play_level'), 'lako');
    });

    test('a level nobody offers is refused rather than stored', () async {
      await AppSettingsService.instance.init();
      final before = AppSettingsService.instance.enginePlayLevel;

      await AppSettingsService.instance.setEnginePlayLevel('nemoguce');

      expect(AppSettingsService.instance.enginePlayLevel, before);
    });

    test('the analysis dials are remembered for the next board', () async {
      await AppSettingsService.instance.init();

      await AppSettingsService.instance.setAnalysisDepth(42);
      await AppSettingsService.instance.setAnalysisLines(5);

      expect(AppSettingsService.instance.analysisDepth, 42);
      expect(AppSettingsService.instance.analysisLines, 5);
      // Changing what a board shows must not touch how the engine plays.
      expect(
          AppSettingsService.instance.enginePlayDepth,
          AppSettingsService
              .kEnginePlayDepths[AppSettingsService.instance.enginePlayLevel]);
    });

    test('the dials are held to what the dropdowns can offer', () async {
      await AppSettingsService.instance.init();

      await AppSettingsService.instance.setAnalysisDepth(500);
      await AppSettingsService.instance.setAnalysisLines(9);

      expect(AppSettingsService.instance.analysisDepth, 50);
      expect(AppSettingsService.instance.analysisLines, 5);
    });
  });
}
