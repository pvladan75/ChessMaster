// `LibraryEntry.fromPreparation` — phase 8 of `docs/PLAN-PRIPREMA.md`. Only a
// Preparation recording can become a tutorial (`GET /library/positions`,
// `positionLibrary.js`), and the Library's door reads this field to decide
// whether to draw it (`library_screen.dart`, `_actionsFor`).

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/library/models/library_entry.dart';

LibraryEntry _recordingOf(Map<String, dynamic> extra) => LibraryEntry.fromJson({
      'kind': 'recording',
      'id': '31',
      'title': 'Italijanska',
      'fen': '',
      ...extra,
    });

void main() {
  test('fromPreparation true', () {
    expect(_recordingOf({'fromPreparation': true}).fromPreparation, isTrue);
  });

  test('fromPreparation false', () {
    expect(_recordingOf({'fromPreparation': false}).fromPreparation, isFalse);
  });

  test('fromPreparation absent reads as false', () {
    expect(_recordingOf({}).fromPreparation, isFalse);
  });
}
