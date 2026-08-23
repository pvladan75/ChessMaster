// endgameCatalog.js — sorting material keys into something a trainer can pick.
//
// The mined collection carries 128 distinct endings and grows with every run,
// so the grouping is a rule rather than a table. A key is not a name: 'KRPPvKR'
// says white has a rook and two pawns and black has a rook, and both the family
// it belongs to and the Serbian sentence for it follow from that.
//
// Two things this got wrong on the first try, kept here because both are easy
// to walk back into:
//
// The key does not put the stronger side first. 'KPPvKR' is a rook against two
// pawns, with the rook second. Rules written as "white is the armed one" put a
// fifth of the collection in a leftovers bucket.
//
// And "protiv" takes the genitive, so the two sides are not spelled the same
// way: "top i pešak protiv topa i pešaka", not "protiv top i pešak".
//
// What the key cannot say is whether two bishops stand on the same colour, and
// opposite bishops are a different ending altogether. That is read from the
// position instead - see oppositeBishops below.

/// 'KRPPvKR' -> [{R:1,P:2}, {R:1}]. Kings are dropped; every ending has two.
function parseMaterial(key) {
  const text = String(key || '');
  const halves = text.split('v');
  if (halves.length !== 2) return null;
  const count = (side) => {
    const out = {};
    for (const ch of side) {
      if (ch === 'K') continue;
      if (!'QRBNP'.includes(ch)) return null;
      out[ch] = (out[ch] || 0) + 1;
    }
    return out;
  };
  const white = count(halves[0]);
  const black = count(halves[1]);
  if (white === null || black === null) return null;
  return [white, black];
}

const minors = (s) => (s.B || 0) + (s.N || 0);
const pieces = (s) => (s.Q || 0) + (s.R || 0) + minors(s);

const FAMILIES = [
  { id: 'rooks', name: 'Topovske završnice' },
  { id: 'rook_vs_minors', name: 'Top protiv lakih figura' },
  { id: 'queens', name: 'Damske završnice' },
  { id: 'queen_vs_rest', name: 'Dama protiv ostalog materijala' },
  { id: 'minors', name: 'Lake figure' },
  { id: 'pawns', name: 'Pešačke završnice' },
  { id: 'pawns_vs_pieces', name: 'Pešaci protiv figura' },
];

const FAMILY_NAMES = Object.fromEntries(FAMILIES.map((f) => [f.id, f.name]));

/// Which family an ending belongs to, or null when the key is not one.
///
/// A rook apiece stays a rook ending even with a bishop standing next to it:
/// R+B vs R is 360 positions of the collection and a trainer asking for rook
/// endings means it too.
function familyOf(key) {
  const parsed = parseMaterial(key);
  if (parsed === null) return null;
  const [a, b] = parsed;

  const armed = [a, b].filter((s) => pieces(s) > 0);
  if (armed.length === 0) return 'pawns';
  // One side has nothing but pawns. Which piece the other side holds is the
  // smaller question - the exercise is the same shape either way.
  if (armed.length === 1) return 'pawns_vs_pieces';

  if ((a.Q || 0) > 0 && (b.Q || 0) > 0) return 'queens';
  if ((a.Q || 0) > 0 || (b.Q || 0) > 0) return 'queen_vs_rest';
  if ((a.R || 0) > 0 && (b.R || 0) > 0) return 'rooks';
  if ((a.R || 0) > 0 || (b.R || 0) > 0) return 'rook_vs_minors';
  return 'minors';
}

// Nominative for the side that acts, genitive for the side after "protiv".
const ONE = { Q: 'dama', R: 'top', B: 'lovac', N: 'skakač', P: 'pešak' };
const ONE_GEN = { Q: 'dame', R: 'topa', B: 'lovca', N: 'skakača', P: 'pešaka' };
const MANY = { Q: 'dame', R: 'topa', B: 'lovca', N: 'skakača', P: 'pešaka' };
const HOW = {
  2: 'dva', 3: 'tri', 4: 'četiri', 5: 'pet', 6: 'šest', 7: 'sedam', 8: 'osam',
};
const ORDER = ['Q', 'R', 'B', 'N', 'P'];

function describeSide(set, genitive) {
  const parts = [];
  for (const piece of ORDER) {
    const n = set[piece] || 0;
    if (!n) continue;
    parts.push(n === 1
      ? (genitive ? ONE_GEN[piece] : ONE[piece])
      : `${HOW[n] || n} ${MANY[piece]}`);
  }
  if (parts.length === 0) return genitive ? 'golog kralja' : 'goli kralj';
  if (parts.length === 1) return parts[0];
  return `${parts.slice(0, -1).join(', ')} i ${parts[parts.length - 1]}`;
}

/// 'KRPPvKR' -> 'top i dva pešaka protiv topa'.
function labelOf(key) {
  const parsed = parseMaterial(key);
  if (parsed === null) return String(key || '');
  return `${describeSide(parsed[0], false)} protiv ${describeSide(parsed[1], true)}`;
}

/// Whether the two bishops stand on squares of different colours.
///
/// Not in the key and not derivable from it: 'KBPvKBP' covers both the ending
/// where a extra pawn usually wins and the one where it usually does not. Null
/// where the question does not arise - which is most of the collection - so a
/// filter can tell "no" from "not applicable".
function oppositeBishops(fen) {
  const board = String(fen || '').split(' ')[0];
  if (!board) return null;
  const squares = { white: [], black: [] };
  let file = 0;
  let rank = 7;
  for (const ch of board) {
    if (ch === '/') {
      rank -= 1;
      file = 0;
      continue;
    }
    if (ch >= '1' && ch <= '8') {
      file += Number(ch);
      continue;
    }
    if (ch === 'B') squares.white.push((file + rank) % 2);
    if (ch === 'b') squares.black.push((file + rank) % 2);
    file += 1;
  }
  if (squares.white.length !== 1 || squares.black.length !== 1) return null;
  return squares.white[0] !== squares.black[0];
}

/// The rating bands the picker offers.
///
/// Only positions taken from real mistakes carry a rating - the mined ones were
/// found by measurement, not by anyone failing - so 'mined' is a band of its
/// own rather than a gap. A trainer picking a level is picking the level
/// somebody actually got it wrong at, and that is worth keeping separate from
/// "we do not know".
const ELO_BANDS = [
  { id: 'mined', name: 'Bez rejtinga (izrudareno)', min: null, max: null },
  { id: 'u1800', name: 'Do 1800', min: 0, max: 1799 },
  { id: 'b1800', name: '1800 - 2000', min: 1800, max: 1999 },
  { id: 'b2000', name: '2000 - 2200', min: 2000, max: 2199 },
  { id: 'b2200', name: '2200 - 2400', min: 2200, max: 2399 },
  { id: 'b2400', name: '2400 i preko', min: 2400, max: 9999 },
];

/// The SQL that puts a row in one of them. Kept next to the bands so the two
/// cannot drift: a band whose bounds live in one file and whose CASE lives in
/// another is a bug waiting for the first edit.
const ELO_BAND_SQL = `CASE
  WHEN blunder_elo IS NULL THEN 'mined'
  WHEN blunder_elo < 1800 THEN 'u1800'
  WHEN blunder_elo < 2000 THEN 'b1800'
  WHEN blunder_elo < 2200 THEN 'b2000'
  WHEN blunder_elo < 2400 THEN 'b2200'
  ELSE 'b2400'
END`;

/// Groups counted material keys into families, biggest family first and the
/// biggest ending inside each.
///
/// Rows may carry a `band`, in which case each ending also reports how its
/// positions split across the bands - which is what lets the picker show a
/// total for any combination of endings and levels without asking again.
function buildCatalog(rows) {
  const byFamily = new Map();
  const endings = new Map();
  for (const row of rows) {
    const family = familyOf(row.material);
    if (family === null) continue;
    const count = Number(row.n) || 0;

    if (!byFamily.has(family)) byFamily.set(family, { total: 0, keys: [] });
    const bucket = byFamily.get(family);
    bucket.total += count;

    // One ending can arrive as several rows, one per band.
    let ending = endings.get(row.material);
    if (!ending) {
      ending = {
        material: row.material,
        label: labelOf(row.material),
        count: 0,
        bands: {},
        opposite: 0,
      };
      endings.set(row.material, ending);
      bucket.keys.push(ending);
    }
    ending.count += count;
    ending.opposite += Number(row.opposite) || 0;
    if (row.band) ending.bands[row.band] = (ending.bands[row.band] || 0) + count;
  }

  return [...byFamily.entries()]
    .map(([id, bucket]) => ({
      id,
      name: FAMILY_NAMES[id] || id,
      count: bucket.total,
      endings: bucket.keys.sort((x, y) => y.count - x.count),
    }))
    .sort((x, y) => y.count - x.count);
}

module.exports = {
  ELO_BANDS,
  ELO_BAND_SQL,
  parseMaterial,
  familyOf,
  labelOf,
  oppositeBishops,
  buildCatalog,
  FAMILIES,
};
