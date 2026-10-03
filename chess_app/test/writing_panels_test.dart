// The board panels of the screens where a tutorial is written — D1 and D2 of
// docs/PLAN-MOTOR-I-PANELI.md: Analysis's three rows and words, remembered
// per screen, Preparation starting with its engine and the studio with
// nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/widgets/analysis_panels.dart';
import 'package:chess_app/services/app_settings_service.dart';

Future<void> _fresh([Map<String, Object> stored = const {}]) async {
  SharedPreferences.setMockInitialValues(stored);
  await AppSettingsService.instance.init();
}

void main() {
  test('the rows and words are Analysis\'s', () {
    final analysis = {for (final (label, key) in analysisPanels) key: label};
    for (final (label, key) in writingPanels) {
      expect(analysis[key], label, reason: '„$label" says another thing here');
    }
    expect(writingPanels.map((p) => p.$2),
        ['engine_analysis', 'opening_explorer', 'syzygy']);
  });

  test('before any tick: Preparation its engine, the studio nothing', () async {
    await _fresh();
    expect(
        writingPanelShown(PanelScope.preparation, 'engine_analysis'), isTrue);
    expect(
        writingPanelShown(PanelScope.preparation, 'opening_explorer'), isFalse);
    expect(writingPanelShown(PanelScope.preparation, 'syzygy'), isFalse);
    for (final (_, key) in writingPanels) {
      expect(writingPanelShown(PanelScope.studio, key), isFalse, reason: key);
    }
  });

  test('a tick on one screen is that screen\'s alone, and is remembered',
      () async {
    await _fresh();
    await setWritingPanelShown(
        PanelScope.preparation, 'opening_explorer', true);
    expect(
        writingPanelShown(PanelScope.preparation, 'opening_explorer'), isTrue);
    // The first tick started from the defaults: the engine is still shown.
    expect(
        writingPanelShown(PanelScope.preparation, 'engine_analysis'), isTrue);
    expect(writingPanelShown(PanelScope.studio, 'opening_explorer'), isFalse,
        reason: 'a tick in Preparation reached the studio');
    expect(
        AppSettingsService.instance.isPanelVisible('opening_explorer'), isTrue);
    await AppSettingsService.instance
        .setPanelVisible('opening_explorer', false);
    expect(
        writingPanelShown(PanelScope.preparation, 'opening_explorer'), isTrue,
        reason: 'Analysis\'s choice reached Preparation');

    // Read back from what was stored, as the next start of the app reads it.
    final prefs = await SharedPreferences.getInstance();
    await _fresh({
      for (final k in prefs.getKeys())
        if (prefs.get(k) is List) k: prefs.getStringList(k)!,
    });
    expect(
        writingPanelShown(PanelScope.preparation, 'opening_explorer'), isTrue,
        reason: 'the tick was not remembered');
    expect(writingPanelShown(PanelScope.studio, 'opening_explorer'), isFalse);
  });

  test('unticking the engine in Preparation is remembered too', () async {
    await _fresh();
    await setWritingPanelShown(
        PanelScope.preparation, 'engine_analysis', false);
    expect(
        writingPanelShown(PanelScope.preparation, 'engine_analysis'), isFalse);
  });
}
