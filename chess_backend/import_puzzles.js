// import_puzzles.js - Lichess Puzzle Import & Seeding Utility
require('dotenv').config();
const fs = require('fs');
const readline = require('readline');
const { pool, initializeDatabase } = require('./db');

// Built-in seed puzzles covering various tactical themes and ratings
const SEED_PUZZLES = [
  {
    puzzle_id: '00008',
    fen: 'q3k1nr/1pp1nQpp/3p4/1P2p3/4P3/e1PP1b2/5PPP/5RK1 b k - 0 16',
    moves: 'e8f7 g1f1',
    rating: 1450,
    rating_deviation: 75,
    popularity: 95,
    nb_plays: 1200,
    themes: ['fork', 'middlegame', 'short'],
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
    moves: 'e2f3 d8h4 g2g3 e4g3',
    rating: 1600,
    rating_deviation: 80,
    popularity: 97,
    nb_plays: 2100,
    themes: ['fork', 'discoveredAttack', 'middlegame'],
    game_url: 'https://lichess.org/GHI11223#21',
    opening_tags: 'French Defense'
  },
  {
    puzzle_id: '0004g',
    fen: '3r2k1/p4ppp/1p6/8/8/1P6/P4PPP/3R2K1 w - - 0 25',
    moves: 'd1d8',
    rating: 1100,
    rating_deviation: 50,
    popularity: 99,
    nb_plays: 5000,
    themes: ['mate', 'mateIn1', 'endgame', 'backRankMate'],
    game_url: 'https://lichess.org/JKL44556#49',
    opening_tags: 'Queen Gambit Accepted'
  },
  {
    puzzle_id: '0005h',
    fen: '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',
    moves: 'd1d8',
    rating: 1050,
    rating_deviation: 45,
    popularity: 98,
    nb_plays: 6200,
    themes: ['mate', 'mateIn1', 'backRankMate'],
    game_url: 'https://lichess.org/MNO77889#1',
    opening_tags: 'King Pawn'
  },
  {
    puzzle_id: '0006i',
    fen: 'r1b2rk1/pp1p1ppp/2n1pn2/q7/2PP4/P1PB4/4NPPP/R1BQ1RK1 w - - 0 11',
    moves: 'c1g5 a5g5',
    rating: 1550,
    rating_deviation: 70,
    popularity: 94,
    nb_plays: 1800,
    themes: ['skewer', 'advantage', 'middlegame'],
    game_url: 'https://lichess.org/PQR99001#21',
    opening_tags: 'English Opening'
  },
  {
    puzzle_id: '0007j',
    fen: 'r4rk1/pp3ppp/2n1pn2/q7/2PP1b2/P2B1N2/4NPPP/R2Q1RK1 b - - 2 14',
    moves: 'f4h6 e2g3',
    rating: 1700,
    rating_deviation: 85,
    popularity: 91,
    nb_plays: 1400,
    themes: ['deflection', 'middlegame', 'advantage'],
    game_url: 'https://lichess.org/STU22334#27',
    opening_tags: 'Caro-Kann Defense'
  },
  {
    puzzle_id: '0008k',
    fen: '2r3k1/pp3p1p/4p1p1/8/8/1P6/P4PPP/3R2K1 b - - 0 22',
    moves: 'c8c1 d1c1',
    rating: 1350,
    rating_deviation: 60,
    popularity: 96,
    nb_plays: 2900,
    themes: ['pin', 'endgame', 'short'],
    game_url: 'https://lichess.org/VWX55667#43',
    opening_tags: 'Slav Defense'
  },
  {
    puzzle_id: '0009l',
    fen: 'r1bqk2r/pp2bppp/2n1pn2/2pp4/3P4/2N1PN2/PPP1BPPP/R1BQ1RK1 w kq - 0 7',
    moves: 'c3b5 a7a6 b5c3',
    rating: 1400,
    rating_deviation: 65,
    popularity: 90,
    nb_plays: 1100,
    themes: ['opening', 'quietMove'],
    game_url: 'https://lichess.org/YZA88990#13',
    opening_tags: 'Nimzo-Indian Defense'
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
