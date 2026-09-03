import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/widgets/action_banner.dart';
import 'package:chess_app/widgets/speakable_info.dart';

/// The two widgets phase 0 freezes, tested before the batches that spread them.
///
/// Three batches building three versions of "this expects an answer" and three
/// speaker buttons is the outcome this file exists to prevent — and the rules
/// below are the ones a batch would quietly drop: a control that does nothing
/// when speech is off, a bar that carries its meaning in colour alone, an
/// engine failure taking down the panel it was decorating.
class _Engine implements TtsEngine {
  _Engine({this.failOnSpeak = false});

  final bool failOnSpeak;
  final List<String> said = [];
  int stops = 0;

  @override
  Future<List<String>> languages() async => const ['sr-RS'];

  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> speak(String text) async {
    if (failOnSpeak) throw StateError('nema glasa');
    said.add(text);
  }

  @override
  Future<void> stop() async => stops += 1;
}

Future<(SpeechService, _Engine)> _speech({
  required bool enabled,
  bool failOnSpeak = false,
}) async {
  final engine = _Engine(failOnSpeak: failOnSpeak);
  final service = SpeechService.forTesting(engine);
  await service.init(enabled: enabled, rate: 0.5, engine: engine);
  return (service, engine);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ActionBanner', () {
    testWidgets('says its sentence and offers one thing to press',
        (tester) async {
      var pressed = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ActionBanner(
            text: 'Čeka 4 nepotvrđena poteza.',
            actionLabel: 'Pregledaj',
            onAction: () => pressed += 1,
          ),
        ),
      ));

      expect(find.text('Čeka 4 nepotvrđena poteza.'), findsOneWidget);
      await tester.tap(find.text('Pregledaj'));
      expect(pressed, 1);
    });

    testWidgets('a label with no callback is not a button', (tester) async {
      // A button that does nothing has shipped here before, in a menu that
      // offered two actions bound to a `?.call` that went nowhere.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ActionBanner(text: 'Nešto', actionLabel: 'Pritisni'),
        ),
      ));

      expect(find.text('Pritisni'), findsNothing);
    });

    testWidgets('every tone carries a mark, not only a colour', (tester) async {
      // The reader this is built for signs off on luminance and shape. A tone
      // told apart by hue alone is a tone they cannot read.
      for (final tone in ActionTone.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ActionBanner(text: 'x', tone: tone)),
        ));
        expect(find.byType(Icon), findsOneWidget, reason: '$tone has no mark');
      }

      final marks = <IconData>{};
      for (final tone in ActionTone.values) {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ActionBanner(text: 'x', tone: tone)),
        ));
        marks.add(tester.widget<Icon>(find.byType(Icon)).icon!);
      }
      expect(marks.length, ActionTone.values.length,
          reason: 'two tones share one mark, so the mark says nothing');
    });

    testWidgets('it fits a 360 dp phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ActionBanner(
            text: 'Ovo je duga rečenica koja traži odgovor od čitaoca.',
            actionLabel: 'Pregledaj nepotvrđene poteze',
            onAction: _noop,
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('SpeakableInfo', () {
    testWidgets('the speaker is never a no-op when speech is off',
        (tester) async {
      // `speak` returns silently when speech is off, so a control that only
      // called it would do nothing at all on the setting most readers start
      // with. Pressing it turns speech on and then says the sentence.
      final settings = AppSettingsService.instance;
      await settings.init();
      await settings.setSpeechEnabled(false);
      final (service, engine) = await _speech(enabled: false);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpeakableInfo(
            text: 'Odigrajte potez koji ste izabrali.',
            settings: settings,
            speech: service,
          ),
        ),
      ));

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(settings.speechEnabled, isTrue);
      expect(engine.said, contains('Odigrajte potez koji ste izabrali.'));
    });

    testWidgets('an engine that throws does not take the panel with it',
        (tester) async {
      final settings = AppSettingsService.instance;
      await settings.init();
      await settings.setSpeechEnabled(true);
      final (service, _) = await _speech(enabled: true, failOnSpeak: true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpeakableInfo(
            text: 'Nešto što treba reći',
            autoSpeak: true,
            settings: settings,
            speech: service,
          ),
        ),
      ));
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nešto što treba reći'), findsOneWidget);
    });

    testWidgets('nothing is said until it is asked for', (tester) async {
      // `autoSpeak` off is the default on purpose: a screen where every panel
      // announces itself is the noise this feature is trying not to be.
      final settings = AppSettingsService.instance;
      await settings.init();
      await settings.setSpeechEnabled(true);
      final (service, engine) = await _speech(enabled: true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpeakableInfo(
            text: 'Tiho',
            settings: settings,
            speech: service,
          ),
        ),
      ));
      await tester.pump();

      expect(engine.said, isEmpty);
    });
  });

  group('SpeechToggleButton', () {
    testWidgets('turns speech off where the talking happens', (tester) async {
      final settings = AppSettingsService.instance;
      await settings.init();
      await settings.setSpeechEnabled(true);
      final (service, engine) = await _speech(enabled: true);
      // Something has to be being said for stopping to mean anything: the
      // service deliberately never calls `stop` on an engine that has not
      // spoken, because on Windows that is the one call that must not be made.
      await service.speak('duga rečenica koja se upravo izgovara');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [SpeechToggleButton(settings: settings, speech: service)],
          ),
        ),
      ));

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(settings.speechEnabled, isFalse);
      // And it goes quiet now, rather than finishing the sentence somebody has
      // just asked it to stop saying.
      expect(engine.stops, greaterThan(0));
    });
  });
}

void _noop() {}
