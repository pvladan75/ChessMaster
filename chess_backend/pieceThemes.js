// High-quality Lichess Alpha style piece SVG vectors

const alphaPieceSvgs = {
  // White Pawn
  'P': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><path d="M 22.5,9 C 20.29,9 18.5,10.79 18.5,13 C 18.5,13.89 18.79,14.71 19.28,15.38 C 17.33,16.5 16,18.59 16,21 C 16,23.03 16.94,24.84 18.41,26.03 C 15.41,27.09 11,31.58 11,39.5 L 34,39.5 C 34,31.58 29.59,27.09 26.59,26.03 C 28.06,24.84 29,23.03 29,21 C 29,18.59 27.67,16.5 25.72,15.38 C 26.21,14.71 26.5,13.89 26.5,13 C 26.5,10.79 24.71,9 22.5,9 z" fill="#ffffff" stroke="#111111" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`,

  // White Knight
  'N': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#111" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 22,10 C 32.5,11 38.5,18 38,39 L 15,39 C 15,30 25,32.5 23,24 C 21.5,17.5 13,18 13,18 C 13,18 16.5,13 22,10 z" fill="#ffffff"/><circle cx="27" cy="16" r="1.8" fill="#111"/><path d="M 24,25 C 24,25 28,27 28,31" stroke="#111"/></g></svg>`,

  // White Bishop
  'B': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#111" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><g fill="#ffffff"><path d="M 9,36 C 12.39,35.03 19.11,36.46 22.5,34 C 25.89,36.46 32.61,35.03 36,36 C 36,36 37.65,36.54 39,38 C 38.32,38.97 37.35,39.5 36,39.5 L 9,39.5 C 7.65,39.5 6.68,38.97 6,38 C 7.35,36.54 9,36 9,36 z"/><path d="M 15,32 C 17.5,34.5 27.5,34.5 30,32 C 30.5,30.5 30,22 30,22 C 30.5,20.5 32,18 32,15.5 C 32,13 30,8.5 22.5,8.5 C 15,8.5 13,13 13,15.5 C 13,18 14.5,20.5 15,22 C 15,22 14.5,30.5 15,32 z"/><circle cx="22.5" cy="6" r="2.5"/></g><path d="M 17.5,26 L 27.5,26 M 22.5,21 L 22.5,31"/></g></svg>`,

  // White Rook
  'R': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#ffffff" fill-rule="evenodd" stroke="#111" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><path d="M 12,36 L 12,32 L 33,32 L 33,36 z"/><path d="M 11,14 L 11,9 L 15,9 L 15,11 L 20,11 L 20,9 L 25,9 L 25,11 L 30,11 L 30,9 L 34,9 L 34,14 z"/><path d="M 12,14 L 33,14 L 31,32 L 14,32 z"/></g></svg>`,

  // White Queen
  'Q': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#ffffff" fill-rule="evenodd" stroke="#111" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,26 C 17.5,24.5 30,24.5 36,26 L 38,14 L 31,25 L 22.5,11 L 14,25 L 7,14 z"/><path d="M 9,26 L 36,26 L 36,36 L 9,36 z"/><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><circle cx="6" cy="12" r="2.2"/><circle cx="14" cy="9" r="2.2"/><circle cx="22.5" cy="6" r="2.2"/><circle cx="31" cy="9" r="2.2"/><circle cx="39" cy="12" r="2.2"/></g></svg>`,

  // White King
  'K': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#111" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 22.5,11.63 L 22.5,6 M 20,8 L 25,8"/><g fill="#ffffff"><path d="M 22.5,25 C 22.5,25 27,17.5 27,14 C 27,11.5 25,9.5 22.5,9.5 C 20,9.5 18,11.5 18,14 C 18,17.5 22.5,25 22.5,25 z"/><path d="M 11.5,37 C 17,35.5 28,35.5 33.5,37 L 35.5,25 C 35.5,25 31,31 22.5,31 C 14,31 9.5,25 9.5,25 z"/><path d="M 11.5,37 L 33.5,37 L 33.5,40 L 11.5,40 z"/></g></g></svg>`,

  // Black Pawn
  'p': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><path d="M 22.5,9 C 20.29,9 18.5,10.79 18.5,13 C 18.5,13.89 18.79,14.71 19.28,15.38 C 17.33,16.5 16,18.59 16,21 C 16,23.03 16.94,24.84 18.41,26.03 C 15.41,27.09 11,31.58 11,39.5 L 34,39.5 C 34,31.58 29.59,27.09 26.59,26.03 C 28.06,24.84 29,23.03 29,21 C 29,18.59 27.67,16.5 25.72,15.38 C 26.21,14.71 26.5,13.89 26.5,13 C 26.5,10.79 24.71,9 22.5,9 z" fill="#2B2B2B" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`,

  // Black Knight
  'n': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 22,10 C 32.5,11 38.5,18 38,39 L 15,39 C 15,30 25,32.5 23,24 C 21.5,17.5 13,18 13,18 C 13,18 16.5,13 22,10 z" fill="#2B2B2B"/><circle cx="27" cy="16" r="1.8" fill="#ffffff"/><path d="M 24,25 C 24,25 28,27 28,31" stroke="#ffffff"/></g></svg>`,

  // Black Bishop
  'b': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><g fill="#2B2B2B"><path d="M 9,36 C 12.39,35.03 19.11,36.46 22.5,34 C 25.89,36.46 32.61,35.03 36,36 C 36,36 37.65,36.54 39,38 C 38.32,38.97 37.35,39.5 36,39.5 L 9,39.5 C 7.65,39.5 6.68,38.97 6,38 C 7.35,36.54 9,36 9,36 z"/><path d="M 15,32 C 17.5,34.5 27.5,34.5 30,32 C 30.5,30.5 30,22 30,22 C 30.5,20.5 32,18 32,15.5 C 32,13 30,8.5 22.5,8.5 C 15,8.5 13,13 13,15.5 C 13,18 14.5,20.5 15,22 C 15,22 14.5,30.5 15,32 z"/><circle cx="22.5" cy="6" r="2.5"/></g><path d="M 17.5,26 L 27.5,26 M 22.5,21 L 22.5,31"/></g></svg>`,

  // Black Rook
  'r': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#2B2B2B" fill-rule="evenodd" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><path d="M 12,36 L 12,32 L 33,32 L 33,36 z"/><path d="M 11,14 L 11,9 L 15,9 L 15,11 L 20,11 L 20,9 L 25,9 L 25,11 L 30,11 L 30,9 L 34,9 L 34,14 z"/><path d="M 12,14 L 33,14 L 31,32 L 14,32 z"/></g></svg>`,

  // Black Queen
  'q': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#2B2B2B" fill-rule="evenodd" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,26 C 17.5,24.5 30,24.5 36,26 L 38,14 L 31,25 L 22.5,11 L 14,25 L 7,14 z"/><path d="M 9,26 L 36,26 L 36,36 L 9,36 z"/><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><circle cx="6" cy="12" r="2.2"/><circle cx="14" cy="9" r="2.2"/><circle cx="22.5" cy="6" r="2.2"/><circle cx="31" cy="9" r="2.2"/><circle cx="39" cy="12" r="2.2"/></g></svg>`,

  // Black King
  'k': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M 22.5,11.63 L 22.5,6 M 20,8 L 25,8"/><g fill="#2B2B2B"><path d="M 22.5,25 C 22.5,25 27,17.5 27,14 C 27,11.5 25,9.5 22.5,9.5 C 20,9.5 18,11.5 18,14 C 18,17.5 22.5,25 22.5,25 z"/><path d="M 11.5,37 C 17,35.5 28,35.5 33.5,37 L 35.5,25 C 35.5,25 31,31 22.5,31 C 14,31 9.5,25 9.5,25 z"/><path d="M 11.5,37 L 33.5,37 L 33.5,40 L 11.5,40 z"/></g></g></svg>`
};

module.exports = {
  alphaPieceSvgs
};
