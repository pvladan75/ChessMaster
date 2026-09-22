// Every slider in lib/ is AppSlider, and no RangeSlider is left.
//
// Flutter 3.47's Slider and RangeSlider keep an OverlayPortal open, and when
// either arrives with a new route its semantics node reaches Windows before
// the node it belongs under. Windows refuses the update, its accessibility
// tree stays broken, and a few updates later the app dies in the engine
// (22.9.2026; lib/widgets/app_slider.dart has the whole story). Nothing about
// a Slider looks wrong in review, so the rule is held here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/dart_source.dart';

final _flutterSlider =
    RegExp(r'(?<![A-Za-z0-9_$.])(Range)?Slider\s*(<[^>]*>)?\s*\(');
final _qualified = RegExp(r'\.\s*(Range)?Slider\s*(<[^>]*>)?\s*\(');

List<String> _offenders(Map<String, String> sources) => [
      for (final e in sources.entries)
        for (final m in [
          ..._flutterSlider.allMatches(codeOf(e.value)),
          ..._qualified.allMatches(codeOf(e.value)),
        ])
          '${e.key}: ${m.group(0)}',
    ];

void main() {
  final sources = <String, String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    sources[f.path.replaceAll(r'\', '/')] = f.readAsStringSync();
  }

  test('the walk read the app and found the sliders', () {
    expect(sources.length, greaterThan(100));
    final users = sources.values.where((s) => codeOf(s).contains('AppSlider('));
    expect(users.length, greaterThan(5),
        reason: 'if nothing uses AppSlider this guard guards nothing');
  });

  test('the check sees a Flutter slider in code, and not in prose', () {
    expect(
      _offenders({
        'a.dart': 'Widget f() => Slider(value: 1, onChanged: null);',
        'b.dart': 'x = RangeSlider(values: v, onChanged: null);',
        'c.dart': 'x = material.Slider(value: 1, onChanged: null);',
      }).length,
      3,
    );
    expect(
      _offenders({
        'd.dart': "// a Slider( in a comment\nfinal s = 'Slider(';",
        'e.dart':
            'x = AppSlider(value: 1, onChanged: null); _BoardSizeSlider();',
        'f.dart': 'final x = CupertinoSlider(value: 1, onChanged: null);',
      }),
      isEmpty,
    );
  });

  test('no file in lib/ builds a Material Slider or RangeSlider', () {
    expect(_offenders(sources), isEmpty,
        reason: 'use AppSlider (lib/widgets/app_slider.dart), or '
            'RatingRangeStepper for a range');
  });
}
