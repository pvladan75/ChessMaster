const test = require('node:test');
const assert = require('node:assert/strict');

const {
  parseMaterial, familyOf, labelOf, oppositeBishops, buildCatalog,
} = require('../services/endgameCatalog');

test('a key is read as two sides of material, without the kings', () => {
  assert.deepEqual(parseMaterial('KRPPvKR'), [{ R: 1, P: 2 }, { R: 1 }]);
  assert.deepEqual(parseMaterial('KPvK'), [{ P: 1 }, {}]);
  assert.equal(parseMaterial('nonsense'), null);
  assert.equal(parseMaterial(''), null);
});

test('the armed side is not always the first one', () => {
  // The mistake that put a fifth of the collection in a leftovers bucket:
  // KPPvKR is a rook against two pawns, with the rook written second.
  assert.equal(familyOf('KPPvKR'), 'pawns_vs_pieces');
  assert.equal(familyOf('KRvKPP'), 'pawns_vs_pieces');
  assert.equal(familyOf('KNPPvKR'), 'rook_vs_minors');
});

test('a rook apiece is a rook ending, whatever stands beside it', () => {
  // R+B against R is 360 positions of the collection, and a trainer asking for
  // rook endings means those too.
  assert.equal(familyOf('KRPvKR'), 'rooks');
  assert.equal(familyOf('KRPPvKR'), 'rooks');
  assert.equal(familyOf('KRPvKRP'), 'rooks');
  assert.equal(familyOf('KRBvKR'), 'rooks');
});

test('every family the collection actually holds is reachable', () => {
  assert.equal(familyOf('KPPvKPP'), 'pawns');
  assert.equal(familyOf('KQPvKQ'), 'queens');
  assert.equal(familyOf('KRPvKQ'), 'queen_vs_rest');
  assert.equal(familyOf('KRPvKBP'), 'rook_vs_minors');
  assert.equal(familyOf('KBPvKB'), 'minors');
  assert.equal(familyOf('KQvKP'), 'pawns_vs_pieces');
});

test('nothing lands outside a family, and nonsense lands nowhere', () => {
  const everything = [
    'KRPPvKR', 'KRPvKR', 'KRPvKRP', 'KRBvKR', 'KRPvKBP', 'KRPvKNP', 'KRvKN',
    'KQPvKQ', 'KQPPvKQ', 'KQPvKQP', 'KRPvKQ', 'KNPPvKN', 'KBPvKB', 'KPPvKP',
    'KPPvKPP', 'KPvK', 'KPPvKR', 'KNPvKPP', 'KQvKP', 'KRvKP',
  ];
  for (const key of everything) {
    assert.notEqual(familyOf(key), null, key);
  }
  assert.equal(familyOf('KRPvKR extra'), null);
});

test('the sentence puts the second side in the genitive', () => {
  // "protiv top" is what the first draft said, and it is wrong Serbian.
  assert.equal(labelOf('KRPvKR'), 'top i pešak protiv topa');
  assert.equal(labelOf('KRPPvKR'), 'top i dva pešaka protiv topa');
  assert.equal(labelOf('KRPvKRP'), 'top i pešak protiv topa i pešaka');
  assert.equal(labelOf('KQPvKQ'), 'dama i pešak protiv dame');
  assert.equal(labelOf('KBPvKN'), 'lovac i pešak protiv skakača');
  assert.equal(labelOf('KPvK'), 'pešak protiv golog kralja');
  assert.equal(labelOf('KRBPvKRN'), 'top, lovac i pešak protiv topa i skakača');
});

test('a key that cannot be read is shown as it came', () => {
  assert.equal(labelOf('sta-je-ovo'), 'sta-je-ovo');
});

test('bishops on different colours are told from bishops on the same', () => {
  // The one thing the key cannot carry, and the difference between an ending
  // where the extra pawn usually wins and one where it usually does not.
  assert.equal(oppositeBishops('8/8/4k3/8/2B5/8/5b2/4K3 w - - 0 1'), true);
  assert.equal(oppositeBishops('8/8/4k3/8/2B5/8/4b3/4K3 w - - 0 1'), false);
});

test('positions where the question does not arise say so', () => {
  // Null rather than false: "these bishops are on the same colour" and "there
  // are no two bishops" are different answers, and a filter needs both.
  assert.equal(oppositeBishops('8/8/4k3/8/2B5/8/8/4K3 w - - 0 1'), null);
  assert.equal(oppositeBishops('4k3/8/8/8/8/8/4P3/4K3 w - - 0 1'), null);
  assert.equal(oppositeBishops(''), null);
});

test('the catalog groups, counts and orders by weight', () => {
  const catalog = buildCatalog([
    { material: 'KRPvKR', n: 824 },
    { material: 'KRPPvKR', n: 945 },
    { material: 'KPPvKP', n: 146 },
    { material: 'KRBvKR', n: 360 },
  ]);

  assert.equal(catalog[0].id, 'rooks');
  assert.equal(catalog[0].count, 824 + 945 + 360);
  // Biggest ending first inside the family, so the list opens on what there is
  // most of rather than on whatever the database returned first.
  assert.equal(catalog[0].endings[0].material, 'KRPPvKR');
  assert.equal(catalog[0].endings[0].label, 'top i dva pešaka protiv topa');
  assert.equal(catalog[1].id, 'pawns');
  assert.equal(catalog[1].count, 146);
});

test('a key the catalog cannot read is left out rather than bucketed', () => {
  const catalog = buildCatalog([
    { material: 'KRPvKR', n: 5 },
    { material: '???', n: 99 },
  ]);
  assert.equal(catalog.length, 1);
  assert.equal(catalog[0].count, 5);
});

test('an ending arriving as several bands is added up once', () => {
  // The route groups by material and band, so the same ending comes back in
  // pieces. Adding them into one entry - and keeping the split - is what lets
  // the picker total any combination of endings and levels without asking the
  // server again.
  const catalog = buildCatalog([
    { material: 'KRPvKR', band: 'b2000', n: 300 },
    { material: 'KRPvKR', band: 'b2200', n: 400 },
    { material: 'KRPvKR', band: 'mined', n: 124 },
  ]);

  assert.equal(catalog.length, 1);
  const ending = catalog[0].endings[0];
  assert.equal(ending.count, 824);
  assert.deepEqual(ending.bands, { b2000: 300, b2200: 400, mined: 124 });
  assert.equal(catalog[0].count, 824);
});

test('bands are optional, and their absence is not a zero', () => {
  const catalog = buildCatalog([{ material: 'KRPvKR', n: 5 }]);
  assert.deepEqual(catalog[0].endings[0].bands, {});
});
