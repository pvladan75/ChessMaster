// One calibration from every user's calibration of the same book — phase
// 3g of docs/PLAN-SKENER-SLIKE.md.
import test from 'node:test';
import assert from 'node:assert/strict';

import { mergeCalibrations, classesOf, SHARED_MAX } from './sharedCalibration.mjs';

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
const KINGS = '4k3/8/8/8/8/8/8/4K3';
const ROOKS = '4k3/r6p/8/8/8/8/P6R/4K3';
const board = (page, fen, extra = {}) => ({ page, index: 1, fen, ...extra });

test('a8 is light: the classes of a board are read as the reader reads them', () => {
  assert.deepEqual([...classesOf('R7/8/8/8/8/8/8/7r')].sort(), ['R/light', 'r/light']);
  assert.deepEqual([...classesOf('8/8/8/8/8/8/8/R7')], ['R/dark']);
});

test('the same board from two users is one board with two votes', () => {
  const merged = mergeCalibrations([
    { boards: [board(12, START)] },
    { boards: [board(12, START + ' w - - 0 1')] },
  ]);
  assert.deepEqual(merged.boards, [{ page: 12, index: 1, fen: START, ignore: [], votes: 2 }]);
  assert.equal(merged.contributors, 2);
});

test('set up two ways, the majority wins; a tie leaves the board out', () => {
  const wrong = START.replace('RNBQKBNR', 'RNBQKBN1');
  const majority = mergeCalibrations([
    { boards: [board(12, START)] }, { boards: [board(12, START)] }, { boards: [board(12, wrong)] },
  ]);
  assert.deepEqual(majority.boards.map((b) => [b.fen, b.votes]), [[START, 2]]);
  const tie = mergeCalibrations([{ boards: [board(12, START)] }, { boards: [board(12, wrong)] }]);
  assert.deepEqual(tie.boards, []);
});

test('boards are chosen for what they add, and one that adds nothing is left out', () => {
  const merged = mergeCalibrations([
    { boards: [board(5, KINGS), board(40, START), board(41, KINGS.replace('4K3', '3K4'))] },
  ]);
  // The opening position shows most; the kings on page 5 add nothing to it.
  assert.equal(merged.boards[0].page, 40);
  assert.ok(!merged.boards.some((b) => b.page === 5), JSON.stringify(merged.boards));
  // d1 is light: the king there is a class the opening position lacks.
  assert.ok(merged.boards.some((b) => b.page === 41));
});

test('among boards that add as much, the one more users agree on comes first', () => {
  // The same position on two different boards of the book: page 7 set up by
  // one user, page 9 by two.
  const same = '4k3/8/8/8/8/8/8/R3K3';
  const merged = mergeCalibrations([
    { boards: [board(7, same)] },
    { boards: [board(9, same)] },
    { boards: [board(9, same)] },
  ]);
  assert.equal(merged.boards[0].page, 9);
  assert.equal(merged.boards[0].votes, 2);
});

test('never more than the most a calibration holds', () => {
  // Twelve boards, each with one piece on its own square colour: each adds.
  const lone = [];
  for (const p of 'PNBRQpnbrq') lone.push(`4k3/8/8/8/8/8/8/${p}3K3`, `4k3/8/8/8/8/8/8/1${p}2K3`);
  const merged = mergeCalibrations([{ boards: lone.map((fen, k) => board(k + 1, fen)) }]);
  assert.equal(merged.boards.length, SHARED_MAX);
});

test('a piece stays absent only when no board anybody set up shows it', () => {
  const merged = mergeCalibrations([
    { boards: [board(1, ROOKS)], absent: ['Q', 'q', 'N'] },
    { boards: [board(2, '4k3/8/8/8/8/8/8/N3K3')], absent: [] },
  ]);
  assert.deepEqual(merged.absent, ['Q', 'q'], 'a white knight on a board beats a „there is none"');
});

test('ignored squares travel with the board they were marked on', () => {
  const merged = mergeCalibrations([
    { boards: [board(3, ROOKS, { ignore: ['e4'] })] },
    { boards: [board(3, ROOKS, { ignore: ['d5'] })] },
  ]);
  assert.deepEqual(merged.boards[0].ignore, ['d5', 'e4']);
});
