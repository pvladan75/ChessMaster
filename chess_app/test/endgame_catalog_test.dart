import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_catalog.dart';

/// Shaped like what the route returns, with the real numbers from the
/// collection: rook endings come in thirteen shapes and this is the top of it.
EndgameCatalog catalog() => EndgameCatalog.fromJson({
      'families': [
        {
          'id': 'rooks',
          'name': 'Topovske završnice',
          'count': 2129,
          'endings': [
            {
              'material': 'KRPPvKR',
              'label': 'top i dva pešaka protiv topa',
              'count': 945,
              'bands': {'b2000': 300, 'b2200': 400, 'mined': 245},
              'opposite': 0,
            },
            {
              'material': 'KRPvKR',
              'label': 'top i pešak protiv topa',
              'count': 824,
              'bands': {'b2000': 500, 'b2400': 324},
              'opposite': 0,
            },
            {
              'material': 'KRBvKR',
              'label': 'top i lovac protiv topa',
              'count': 360,
              'bands': {'b2200': 360},
              'opposite': 0,
            },
          ],
        },
        {
          'id': 'minors',
          'name': 'Lake figure',
          'count': 86,
          'endings': [
            {
              'material': 'KBPvKB',
              'label': 'lovac i pešak protiv lovca',
              'count': 86,
              'bands': {'b2000': 40, 'b2200': 46},
              'opposite': 28,
            },
          ],
        },
      ],
      'bands': [
        {'id': 'mined', 'name': 'Bez rejtinga (izrudareno)'},
        {'id': 'b2000', 'name': '2000 - 2200'},
        {'id': 'b2200', 'name': '2200 - 2400'},
        {'id': 'b2400', 'name': '2400 i preko'},
      ],
      'oppositeBishops': 28,
    });

void main() {
  test('everything is selected to begin with', () {
    // A picker that starts empty asks the reader to do work before they can do
    // anything at all.
    final all = catalog().allMaterials;
    expect(all, hasLength(4));
    expect(all, contains('KRPvKR'));
    expect(all, contains('KBPvKB'));
  });

  test('the total over a selection is exact, not an estimate', () {
    final c = catalog();
    expect(c.countFor(materials: c.allMaterials), 945 + 824 + 360 + 86);
    expect(c.countFor(materials: {'KRPvKR', 'KRBvKR'}), 824 + 360);
    expect(c.countFor(materials: {}), 0);
  });

  test('a level narrows the same total, band by band', () {
    // This is the whole reason the counts arrive split: the picker can say what
    // a combination covers before it asks, instead of sending a query that
    // matches nothing and reporting that afterwards.
    final c = catalog();
    expect(
        c.countFor(materials: c.allMaterials, bandId: 'b2200'), 400 + 360 + 46);
    expect(c.countFor(materials: {'KRPvKR'}, bandId: 'b2200'), 0);
    expect(c.countFor(materials: {'KRPPvKR'}, bandId: 'mined'), 245);
  });

  test('an unknown band counts as nothing rather than as everything', () {
    final c = catalog();
    expect(c.countFor(materials: c.allMaterials, bandId: 'nema-ga'), 0);
  });

  test('opposite bishops are counted from their own column', () {
    // Reported per ending rather than per ending and band: 43 positions in the
    // whole collection do not deserve a second breakdown.
    final c = catalog();
    expect(c.countFor(materials: c.allMaterials, oppositeOnly: true), 28);
    expect(c.countFor(materials: {'KRPvKR'}, oppositeOnly: true), 0);
  });

  test('a full selection sends no filter at all', () {
    // The route reads a missing filter as "any", and listing 128 keys to say
    // the same thing would be a long way round.
    final c = catalog();
    expect(c.materialsParamFor(c.allMaterials), isNull);
    expect(c.materialsParamFor({'KRPvKR', 'KRBvKR'}), 'KRBvKR,KRPvKR');
  });

  test('an empty answer reads as empty rather than as broken', () {
    final empty = EndgameCatalog.fromJson({});
    expect(empty.isEmpty, isTrue);
    expect(empty.allMaterials, isEmpty);
    expect(empty.countFor(materials: {'KRPvKR'}), 0);
  });
}
