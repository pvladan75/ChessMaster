/// Writes `assets/speech/manifest.json` from the Dart vocabulary —
/// `docs/PLAN-GOVOR-IZ-KLIPOVA.md`, D7.
///
///     dart run tool/speech_manifest.dart
///
/// Then `node tools/speech_clips/render.js` (from the repository root) renders
/// the clips the manifest asks for, and `test/speech_clips_test.dart` holds
/// both to this file.
library;

import 'dart:io';

import 'package:chess_app/core/speech/vocabulary.dart';

void main() {
  final file = File('assets/speech/manifest.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(SpeechVocabulary.manifestText());
  stdout.writeln('${file.path}: ${SpeechVocabulary.tokens.length} tokens');
}
