// The reading of phase 2 of docs/PLAN-SKENER-SLIKE.md, off the main thread.
// Half a second a board is too long to spend on the thread that answers every
// other request, draws films and runs sessions; imageRead.mjs starts one of
// these per request and waits for its one message.
import { parentPort, workerData } from 'node:worker_threads';

import { calibrate, readBoard } from './reader.mjs';

const { calibration, boards } = workerData;
const calibrated = calibrate(calibration);
parentPort.postMessage({
  cells: boards.map((board) => readBoard(board, calibrated)),
  composed: calibrated.composed,
  unseen: calibrated.unseen,
});
