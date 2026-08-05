// geminiService.js - AI Chess Coach powered by Google Gemini SDK (@google/genai)
require('dotenv').config();
const { GoogleGenAI } = require('@google/genai');

function generateFallbackExplanation({ fen, evals, userLanguage = 'sr' }) {
  const isSr = userLanguage === 'sr';
  const bestMove = evals?.bestMove || (evals?.continuation ? evals.continuation.split(' ')[0] : 'e2e4');
  const cp = evals?.cp !== undefined ? evals.cp : (evals?.evaluation !== undefined ? Math.round(evals.evaluation * 100) : 0);

  let summary = isSr
    ? `Pozicija pruža značajnu taktičku šansu sa ocenom ${cp > 0 ? '+' : ''}${(cp / 100).toFixed(2)}.`
    : `The position offers strong tactical opportunities with evaluation ${cp > 0 ? '+' : ''}${(cp / 100).toFixed(2)}.`;

  let keyMotif = isSr ? 'Taktička inicijativa i napad' : 'Tactical Initiative & Attack';
  if (cp > 300) {
    keyMotif = isSr ? 'Dobijena pozicija (Velika materijalna/taktička prednost)' : 'Decisive Advantage';
  } else if (cp < -300) {
    keyMotif = isSr ? 'Odbrambeni resursi i kontraigra' : 'Defensive Resources & Counterplay';
  }

  const movesList = evals?.continuation
    ? evals.continuation.split(' ').slice(0, 4)
    : [bestMove];

  let plan = isSr
    ? `1. Pritisnite protivničku poziciju ključnim potezom ${bestMove}.\n2. Kontrolišite centar i iskoristite nepokrivene figure.\n3. Nastavite sa linijom: ${movesList.join(' -> ')}.`
    : `1. Pressure the opponent's position with key move ${bestMove}.\n2. Control central squares and exploit unguarded pieces.\n3. Continue line: ${movesList.join(' -> ')}.`;

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

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
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

module.exports = {
  explainPosition,
  generateFallbackExplanation
};
