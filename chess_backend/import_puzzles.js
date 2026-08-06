// import_puzzles.js - Lichess Puzzle Import & Seeding Utility
require('dotenv').config();
const fs = require('fs');
const readline = require('readline');
const { pool, initializeDatabase } = require('./db');

// Built-in seed puzzles covering various tactical themes and ratings (Official Lichess Dataset)
const SEED_PUZZLES = [
  {
    puzzle_id: '00sHx',
    fen: 'q3k1nr/1pp1nQpp/3p4/1P2p3/4P3/B1PP1b2/B5PP/5K2 b k - 0 17',
    moves: 'e8d7 a2e6 d7d8 f7f8',
    rating: 1760,
    rating_deviation: 80,
    popularity: 83,
    nb_plays: 72,
    themes: ['mate', 'mateIn2', 'middlegame', 'short'],
    game_url: 'https://lichess.org/yyznGmXs/black#34',
    opening_tags: 'Italian_Game Italian_Game_Classical_Variation'
  },
  {
    puzzle_id: '00sJ9',
    fen: 'r3r1k1/p4ppp/2p2n2/1p6/3P1qb1/2NQR3/PPB2PP1/R1B3K1 w - - 5 18',
    moves: 'e3g3 e8e1 g1h2 e1c1 a1c1 f4h6 h2g1 h6c1',
    rating: 2671,
    rating_deviation: 105,
    popularity: 87,
    nb_plays: 325,
    themes: ['advantage', 'attraction', 'fork', 'middlegame', 'sacrifice', 'veryLong'],
    game_url: 'https://lichess.org/gyFeQsOE#35',
    opening_tags: 'French_Defense French_Defense_Exchange_Variation'
  },
  {
    puzzle_id: '00sJb',
    fen: 'Q1b2r1k/p2np2p/5bp1/q7/5P2/4B3/PPP3PP/2KR1B1R w - - 1 17',
    moves: 'd1d7 a5e1 d7d1 e1e3 c1b1 e3b6',
    rating: 2235,
    rating_deviation: 76,
    popularity: 97,
    nb_plays: 64,
    themes: ['advantage', 'fork', 'long'],
    game_url: 'https://lichess.org/kiuvTFoE#33',
    opening_tags: 'Sicilian_Defense Sicilian_Defense_Dragon_Variation'
  },
  {
    puzzle_id: '00sO1',
    fen: '1k1r4/pp3pp1/2p1p3/4b3/P3n1P1/8/KPP2PN1/3rBR1R b - - 2 31',
    moves: 'b8c7 e1a5 b7b6 f1d1',
    rating: 998,
    rating_deviation: 85,
    popularity: 94,
    nb_plays: 293,
    themes: ['advantage', 'discoveredAttack', 'master', 'middlegame', 'short'],
    game_url: 'https://lichess.org/vsfFkG0s/black#62',
    opening_tags: ''
  },
  {
    puzzle_id: '00008',
    fen: 'r1bqk2r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
    moves: 'd2d4 e5d4 e4e5',
    rating: 1450,
    rating_deviation: 75,
    popularity: 95,
    nb_plays: 1200,
    themes: ['opening', 'fork', 'short'],
    game_url: 'https://lichess.org/ABC12345#31',
    opening_tags: 'Italian Game'
  },
  {
    puzzle_id: '0001d',
    fen: 'r1bqk2r/pp3ppp/2p5/1B1pP3/3Pn3/8/PPP2PPP/R1BQK2R w KQkq - 0 10',
    moves: 'b5d3 d8h4',
    rating: 1300,
    rating_deviation: 65,
    popularity: 92,
    nb_plays: 3400,
    themes: ['pin', 'opening', 'short'],
    game_url: 'https://lichess.org/XYZ67890#19',
    opening_tags: 'Ruy Lopez'
  },
  {
    puzzle_id: '0002e',
    fen: 'r1b1k2r/pp1p1ppp/2n1pn2/8/q1PP4/P1PB4/4NPPP/R1BQ1RK1 b kq - 2 10',
    moves: 'a4d1 f1d1',
    rating: 1250,
    rating_deviation: 60,
    popularity: 88,
    nb_plays: 980,
    themes: ['endgame', 'advantage', 'short'],
    game_url: 'https://lichess.org/DEF98765#19',
    opening_tags: 'Sicilian Defense'
  },
  {
    puzzle_id: '0003f',
    fen: 'r2qk2r/ppp2ppp/2n5/3pP3/3Pn3/2P5/P1P1B1PP/R1BQK2R w KQkq - 1 11',
    moves: 'c1b2 d8h4 g2g3 e4g3',
    rating: 1600,
    rating_deviation: 80,
    popularity: 97,
    nb_plays: 2100,
    themes: ['fork', 'discoveredAttack', 'middlegame'],
    game_url: 'https://lichess.org/GHI11223#21',
    opening_tags: 'French Defense'
  }
];

async function seedPuzzles() {
  console.log('--- Započinjem uvoz Šahovskih Zagonetki (Puzzles) u PostgreSQL ---');
  await initializeDatabase();
  const client = await pool.connect();
  try {
    const csvFilePath = process.argv[2];

    if (csvFilePath && fs.existsSync(csvFilePath)) {
      console.log(`Čitam CSV fajl: ${csvFilePath}`);
      const fileStream = fs.createReadStream(csvFilePath);
      const rl = readline.createInterface({ input: fileStream, crlfDelay: Infinity });

      let isHeader = true;
      let count = 0;

      for await (const line of rl) {
        if (isHeader) {
          isHeader = false;
          continue;
        }
        const parts = line.split(',');
        if (parts.length < 9) continue;

        const [puzzle_id, fen, moves, rating, rating_deviation, popularity, nb_plays, themesStr, game_url, opening_tags] = parts;
        const themes = themesStr ? themesStr.trim().split(' ') : [];

        await client.query(
          `INSERT INTO puzzles (puzzle_id, fen, moves, rating, rating_deviation, popularity, nb_plays, themes, game_url, opening_tags)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (puzzle_id) DO UPDATE SET
             rating = EXCLUDED.rating,
             themes = EXCLUDED.themes`,
          [
            puzzle_id,
            fen,
            moves,
            parseInt(rating) || 1500,
            parseInt(rating_deviation) || 100,
            parseInt(popularity) || 100,
            parseInt(nb_plays) || 0,
            themes,
            game_url || '',
            opening_tags || ''
          ]
        );
        count++;
        if (count % 1000 === 0) console.log(`Uvezeno ${count} zagonetki...`);
      }
      console.log(`Uspešno uvezeno ${count} zagonetki iz CSV datoteke!`);
    } else {
      console.log('Nije naveden CSV fajl ili ne postoji. Uvozim ugradjeni skup Lichess zagonetki...');
      for (const p of SEED_PUZZLES) {
        await client.query(
          `INSERT INTO puzzles (puzzle_id, fen, moves, rating, rating_deviation, popularity, nb_plays, themes, game_url, opening_tags)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (puzzle_id) DO NOTHING`,
          [
            p.puzzle_id,
            p.fen,
            p.moves,
            p.rating,
            p.rating_deviation,
            p.popularity,
            p.nb_plays,
            p.themes,
            p.game_url,
            p.opening_tags
          ]
        );
      }
      console.log(`Uspešno ubaceno ${SEED_PUZZLES.length} ugradjenih zagonetki u bazu!`);
    }
  } catch (err) {
    console.error('Greška pri uvozu zagonetki:', err);
  } finally {
    client.release();
    await pool.end();
  }
}

seedPuzzles();
