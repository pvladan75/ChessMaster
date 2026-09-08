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

function generateFallbackExplanation({ fen, evals }) {
  // Parse side to move from FEN ('w' or 'b')
  const fenParts = (fen || '').split(' ');
  const sideToMove = fenParts[1] === 'b' ? 'Black to move' : 'White to move';

  const bestMove = evals?.bestMove || (evals?.continuation ? evals.continuation.split(' ')[0] : null) || (evals?.pv ? evals.pv.split(' ')[0] : null);
  const cp = evals?.cp !== undefined ? evals.cp : (evals?.evaluation !== undefined ? Math.round(evals.evaluation * 100) : 0);

  let summary = `${sideToMove}. Position offers tactical opportunities with engine evaluation ${cp > 0 ? '+' : ''}${(cp / 100).toFixed(2)}.`;

  let keyMotif = 'Tactical Initiative & Mobility';
  if (cp > 300) {
    keyMotif = 'Decisive Advantage';
  } else if (cp < -300) {
    keyMotif = 'Defensive Counterplay';
  }

  const movesList = evals?.continuation
    ? evals.continuation.split(' ').slice(0, 4)
    : (bestMove ? [bestMove] : []);

  const moveAdvice = bestMove
    ? `Pressure opponent with ${bestMove}.`
    : 'Analyze undefended pieces and activate key pieces.';

  let plan = `1. ${sideToMove}: ${moveAdvice}\n2. Control key open files and diagonals.\n3. Continue calculated engine line.`;

  return {
    summary,
    keyMotif,
    plan,
    recommendedMoves: movesList
  };
}

async function explainPosition({ fen, evals }) {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY' || apiKey.trim() === '') {
    console.log('Gemini API Key missing/placeholder. Returning fallback structured coach explanation.');
    return generateFallbackExplanation({ fen, evals });
  }

  try {
    const ai = new GoogleGenAI({ apiKey });
    const prompt = `
You are a world-class chess grandmaster and AI Chess Coach.
Your task is to explain the current chess position to the student in a clear, motivating, and pedagogical way based on the FEN code and engine evaluation analysis (Stockfish).

FEN position: "${fen}"
Evaluation data (Stockfish): ${JSON.stringify(evals || {})}
Language of explanation: English

Return EXCLUSIVELY a valid JSON object with the following structure (without markdown tags like \`\`\`json):
{
  "summary": "A brief pedagogical conclusion about the position in 1-2 sentences.",
  "keyMotif": "Main tactical or positional motif (e.g. 'Fork', 'Pinning the queen', 'Back-rank weakness').",
  "plan": "Detailed step-by-step game plan explanation and reason why the suggested moves are best.",
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
    return generateFallbackExplanation({ fen, evals });
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
    return { comment: `Evaluation moves from ${fmt(evalBefore)} to ${fmt(evalAfter)}.` };
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
      `=== Findings for PLAYED move ("${moveSan}") ===\nTactical: ${JSON.stringify(tacticalFindings || [])}\nPositional: ${JSON.stringify(positionalFindings || [])}`,
    ];

    if (previousMove) {
      sections.push(
        `=== Findings for move THAT LED to this position (previous move, "${previousMove.moveSan}") ===\nTactical: ${JSON.stringify(previousMove.tacticalFindings || [])}\nPositional: ${JSON.stringify(previousMove.positionalFindings || [])}`
      );
    }

    let hasAlternative = false;
    if (engineAlternative) {
      hasAlternative = true;
      sections.push(
        `=== Engine recommendation INSTEAD OF played move (NOT played): "${engineAlternative.moveSan}", evaluation: ${engineAlternative.eval ?? 'unknown'} ===\nTactical: ${JSON.stringify(engineAlternative.tacticalFindings || [])}\nPositional: ${JSON.stringify(engineAlternative.positionalFindings || [])}`
      );
    } else if (nextMoveEval) {
      sections.push(
        `=== Evaluation after actual played next move ("${nextMoveEval.moveSan}") ===\n${nextMoveEval.eval}`
      );
    }

    if (Array.isArray(siblingAlternatives) && siblingAlternatives.length > 0) {
      hasAlternative = true;
      for (const alt of siblingAlternatives) {
        sections.push(
          `=== Alternative branch from tree (NOT played): "${alt.moveSan}" ===\nTactical: ${JSON.stringify(alt.tacticalFindings || [])}\nPositional: ${JSON.stringify(alt.positionalFindings || [])}`
        );
      }
    }

    const instruction = hasAlternative
      ? 'Write a 1 to 4 sentence commentary comparing the played move with the specified alternatives that were NOT played, explaining why the played move is better, worse, or comparable — relying on the provided findings and evaluations, do not list them mechanically, write natural prose as for a game reader.'
      : 'Write a 1 to 3 sentence commentary explaining WHY this move is good, bad, or questionable, relying on the provided findings and evaluation swing — do not list findings mechanically, write natural prose as for a game reader.';

    const prompt = `
You are a chess grandmaster and commentator writing concise, insightful move annotations for a game, in the style used in annotated PGN files.

Played move: "${moveSan}"
Evaluation before move: ${evalBefore ?? 'unknown'}
Evaluation after move: ${evalAfter ?? 'unknown'}

${sections.join('\n\n')}

Language: English

${instruction}

Whenever mentioning any move in the text (played or alternative), use the exact SAN notation given above (e.g. "Be7", "Nf3", "Qxd5") — with standard English piece letters (K, Q, R, B, N).

Return EXCLUSIVELY a valid JSON object (without markdown tags like \`\`\`json):
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
