// geminiService.js - AI Chess Coach powered by Google Gemini SDK (@google/genai)
require('dotenv').config();
const { GoogleGenAI } = require('@google/genai');

/// Google's own 503 message says "usually temporary... try again later" —
/// a couple of quick retries clear most of these without falling all the
/// way back to the mechanical finding-join. Only retries transient
/// capacity errors (503/UNAVAILABLE); anything else (bad key, malformed
/// request) fails immediately since a retry wouldn't help.
async function generateContentWithRetry(ai, params, { retries = 2, baseDelayMs = 800 } = {}) {
  for (let attempt = 0; ; attempt++) {
    try {
      return await ai.models.generateContent(params);
    } catch (err) {
      const isTransient = err && (err.status === 'UNAVAILABLE' || (err.error && err.error.code === 503) || /503|UNAVAILABLE|high demand/i.test(err.message || ''));
      if (!isTransient || attempt >= retries) throw err;
      const delay = baseDelayMs * (attempt + 1);
      console.log(`Gemini transient error (attempt ${attempt + 1}/${retries + 1}), retrying in ${delay}ms:`, err.message || err);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
}

function generateFallbackExplanation({ fen, evals, userLanguage = 'sr' }) {
  const isSr = userLanguage === 'sr';

  // Parse side to move from FEN ('w' or 'b')
  const fenParts = (fen || '').split(' ');
  const sideToMove = fenParts[1] === 'b' ? (isSr ? 'Crni na potezu' : 'Black to move') : (isSr ? 'Beli na potezu' : 'White to move');

  const bestMove = evals?.bestMove || (evals?.continuation ? evals.continuation.split(' ')[0] : null) || (evals?.pv ? evals.pv.split(' ')[0] : null);
  const cp = evals?.cp !== undefined ? evals.cp : (evals?.evaluation !== undefined ? Math.round(evals.evaluation * 100) : 0);

  let summary = isSr
    ? `${sideToMove}. Pozicija pruža taktičke resurse sa procenom motora ${cp > 0 ? '+' : ''}${(cp / 100).toFixed(2)}.`
    : `${sideToMove}. Position offers tactical opportunities with engine evaluation ${cp > 0 ? '+' : ''}${(cp / 100).toFixed(2)}.`;

  let keyMotif = isSr ? 'Taktička inicijativa i mobilnost' : 'Tactical Initiative & Mobility';
  if (cp > 300) {
    keyMotif = isSr ? 'Značajna prednost (Zobijena pozicija)' : 'Decisive Advantage';
  } else if (cp < -300) {
    keyMotif = isSr ? 'Odbrambeni resursi i kontraigra' : 'Defensive Counterplay';
  }

  const movesList = evals?.continuation
    ? evals.continuation.split(' ').slice(0, 4)
    : (bestMove ? [bestMove] : []);

  const moveAdvice = bestMove
    ? (isSr ? `Pritisnite protivnika potezom ${bestMove}.` : `Pressure opponent with ${bestMove}.`)
    : (isSr ? 'Analizirajte nezaštićene figure i aktivirajte najjače figure.' : 'Analyze undefended pieces and activate key pieces.');

  let plan = isSr
    ? `1. ${sideToMove}: ${moveAdvice}\n2. Kontrolišite ključne dijagonale i linije.\n3. Nastavite sa preporučenom linijom motora.`
    : `1. ${sideToMove}: ${moveAdvice}\n2. Control key open files and diagonals.\n3. Continue calculated engine line.`;

  return {
    summary,
    keyMotif,
    plan,
    recommendedMoves: movesList
  };
}

async function explainPosition({ fen, evals, userLanguage = 'sr' }) {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY' || apiKey.trim() === '') {
    console.log('Gemini API Key missing/placeholder. Returning fallback structured coach explanation.');
    return generateFallbackExplanation({ fen, evals, userLanguage });
  }

  try {
    const ai = new GoogleGenAI({ apiKey });
    const prompt = `
Vi ste vrhunski šahovski velemajstor i AI Šahovski Trener (Chess Coach).
Vaš zadatak je da učeniku na jasan, motivišući i pedagoški način objasnite trenutnu šahovsku poziciju na osnovu FEN koda i analize motorne evaluacije (Stockfish).

FEN pozicija: "${fen}"
Evaluacijski podaci (Stockfish): ${JSON.stringify(evals || {})}
Jezik objašnjenja: ${userLanguage === 'sr' ? 'srpski (šahovska terminologija)' : 'english'}

Vratite ISKLJUČIVO ispravan JSON objekat sa sledećom strukturom (bez markdown oznaka poput \`\`\`json):
{
  "summary": "Kratak pedagoški zaključak o poziciji u 1-2 rečenice.",
  "keyMotif": "Glavni taktički ili pozicioni motiv (npr. 'Dvostruki udar (Viljuška)', 'Vezivanje kraljice', 'Slabost zadnjeg reda').",
  "plan": "Detaljno objašnjenje plana igre korak-po-korak i razlog zašto su predloženi potezi najbolji.",
  "recommendedMoves": ["e2e4", "e7e5"]
}
`;

    const response = await generateContentWithRetry(ai, {
      // 'gemini-2.5-flash' pinned directly 404s for this API key ("no
      // longer available to new users") even though the AI Studio usage
      // dashboard shows history for it — that history is 404s too, not
      // successful calls. The rolling alias is what actually works today;
      // it just means whichever flash model Google currently points it at
      // (variable — has resolved to both 2.5 and 3.7 Flash so far), with
      // whatever quota/capacity that model happens to have.
      model: 'gemini-flash-latest',
      contents: prompt,
    });

    const text = response.text;
    const cleanJson = text.replace(/```json/g, '').replace(/```/g, '').trim();
    return JSON.parse(cleanJson);
  } catch (err) {
    console.error('Gemini API Exception, using structured fallback:', err.message || err);
    return generateFallbackExplanation({ fen, evals, userLanguage });
  }
}

function generateFallbackMoveComment({ evalBefore, evalAfter, tacticalFindings, positionalFindings }) {
  // Same mechanical join the app already did before this feature existed —
  // a Gemini outage should never leave the user with nothing.
  const parts = [...(tacticalFindings || []), ...(positionalFindings || [])]
    .map((f) => f && f.description)
    .filter((d) => typeof d === 'string' && d.trim() !== '');

  if (parts.length > 0) {
    return { comment: parts.join(' | ') };
  }

  // A "quiet" move with no detected tactical/positional findings has
  // nothing to join — describe the eval swing instead of returning nothing.
  if (typeof evalBefore === 'number' && typeof evalAfter === 'number') {
    const fmt = (v) => (v > 0 ? `+${v.toFixed(2)}` : v.toFixed(2));
    return { comment: `Evaluacija ide sa ${fmt(evalBefore)} na ${fmt(evalAfter)}.` };
  }

  return { comment: '' };
}

async function generateMoveComment({
  moveSan,
  evalBefore,
  evalAfter,
  tacticalFindings,
  positionalFindings,
  // Comparative context, all optional — see the labeled === sections below.
  previousMove,        // { moveSan, tacticalFindings, positionalFindings } | null/undefined
  engineAlternative,    // { moveSan, eval, tacticalFindings, positionalFindings } | null/undefined
  nextMoveEval,         // { moveSan, eval } | null/undefined — cheap fallback, only useful when engineAlternative is absent
  siblingAlternatives,  // [{ moveSan, tacticalFindings, positionalFindings }, ...] | undefined
  userLanguage = 'sr',
}) {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY' || apiKey.trim() === '') {
    console.log('Gemini API Key missing/placeholder. Returning fallback move comment.');
    return generateFallbackMoveComment({ evalBefore, evalAfter, tacticalFindings, positionalFindings });
  }

  try {
    const ai = new GoogleGenAI({ apiKey });

    // Each block is labeled with its role (played vs. not-played) so the
    // model never conflates "what happened" with "what could have" — built
    // as a list of sections rather than one fixed template since most of
    // these are optional (a quiet, unbranched move has none of them).
    const sections = [
      `=== Nalazi ODIGRANOG poteza ("${moveSan}") ===\nTaktički: ${JSON.stringify(tacticalFindings || [])}\nPozicioni: ${JSON.stringify(positionalFindings || [])}`,
    ];

    if (previousMove) {
      sections.push(
        `=== Nalazi poteza KOJI JE DOVEO do ove pozicije (prethodni potez, "${previousMove.moveSan}") ===\nTaktički: ${JSON.stringify(previousMove.tacticalFindings || [])}\nPozicioni: ${JSON.stringify(previousMove.positionalFindings || [])}`
      );
    }

    let hasAlternative = false;
    if (engineAlternative) {
      hasAlternative = true;
      sections.push(
        `=== Engine-ova preporuka UMESTO odigranog poteza (NIJE odigrano): "${engineAlternative.moveSan}", evaluacija: ${engineAlternative.eval ?? 'nepoznato'} ===\nTaktički: ${JSON.stringify(engineAlternative.tacticalFindings || [])}\nPozicioni: ${JSON.stringify(engineAlternative.positionalFindings || [])}`
      );
    } else if (nextMoveEval) {
      sections.push(
        `=== Evaluacija posle stvarno odigranog sledećeg poteza ("${nextMoveEval.moveSan}") ===\n${nextMoveEval.eval}`
      );
    }

    if (Array.isArray(siblingAlternatives) && siblingAlternatives.length > 0) {
      hasAlternative = true;
      for (const alt of siblingAlternatives) {
        sections.push(
          `=== Alternativna varijanta iz stabla (NIJE odigrano): "${alt.moveSan}" ===\nTaktički: ${JSON.stringify(alt.tacticalFindings || [])}\nPozicioni: ${JSON.stringify(alt.positionalFindings || [])}`
        );
      }
    }

    const instruction = hasAlternative
      ? 'Napišite komentar od 1 do 4 rečenice koji upoređuje odigrani potez sa navedenim alternativama koje NISU odigrane, objašnjavajući zašto je odigrani potez bolji, gori ili uporediv — oslanjajući se na date nalaze i evaluacije, ne nabrajajte ih mehanički, napišite prirodan tekst kao za čitaoca partije.'
      : 'Napišite komentar od 1 do 3 rečenice koji objašnjava ZAŠTO je ovaj potez dobar, loš ili sporan, oslanjajući se na date nalaze i promenu evaluacije — ne nabrajajte nalaze mehanički, napišite prirodan tekst kao za čitaoca partije.';

    const prompt = `
Vi ste šahovski velemajstor i komentator koji piše kratke, pronicljive komentare uz poteze u partiji, u stilu koji se koristi u analiziranim PGN fajlovima.

Odigran potez: "${moveSan}"
Evaluacija pre poteza: ${evalBefore ?? 'nepoznato'}
Evaluacija posle poteza: ${evalAfter ?? 'nepoznato'}

${sections.join('\n\n')}

Jezik: ${userLanguage === 'sr' ? 'srpski (šahovska terminologija)' : 'english'}

${instruction}

Kad god pominjete bilo koji potez u tekstu (odigrani ili alternativni), koristite tačno onu SAN notaciju koja vam je data iznad (npr. "Be7", "Nf3", "Qxd5") — sa standardnim engleskim slovima za figure (K, Q, R, B, N). Ne prevodite slova figura na srpski (nikako "Le7", "Sf3", "Td1" i slično), čak ni kad je ostatak teksta na srpskom.

Vratite ISKLJUČIVO ispravan JSON objekat (bez markdown oznaka poput \`\`\`json):
{
  "comment": "..."
}
`;

    const response = await generateContentWithRetry(ai, {
      // 'gemini-2.5-flash' pinned directly 404s for this API key ("no
      // longer available to new users") even though the AI Studio usage
      // dashboard shows history for it — that history is 404s too, not
      // successful calls. The rolling alias is what actually works today;
      // it just means whichever flash model Google currently points it at
      // (variable — has resolved to both 2.5 and 3.7 Flash so far), with
      // whatever quota/capacity that model happens to have.
      model: 'gemini-flash-latest',
      contents: prompt,
    });

    const text = response.text;
    const cleanJson = text.replace(/```json/g, '').replace(/```/g, '').trim();
    return JSON.parse(cleanJson);
  } catch (err) {
    console.error('Gemini API Exception, using fallback move comment:', err.message || err);
    return generateFallbackMoveComment({ evalBefore, evalAfter, tacticalFindings, positionalFindings });
  }
}

module.exports = {
  // Exported so the preparation narrative can reuse the transient-503 retry and
  // the model alias, rather than growing a second opinion about either.
  generateContentWithRetry,
  explainPosition,
  generateFallbackExplanation,
  generateMoveComment,
  generateFallbackMoveComment
};
