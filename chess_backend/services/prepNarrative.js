// prepNarrative.js — the sentence over the report, and what it is not allowed to say.
//
// The leak report is a table: positions, counts, scores, the move that keeps
// being played. A sentence over it — "na 1.e4 skoro uvek bira Sicilijanku, ali
// u njoj gubi više nego što dobija" — is worth having, and it is the one thing
// here a model writes better than a template.
//
// Two rules shape everything below, and both are about what leaves this server.
//
// **The numbers are checked, not requested.** `narrativeGuard` refuses any
// output carrying a numeral the input did not contain. See that file for why a
// prompt cannot do this job; the short version is that the model does not lie,
// it rounds, and "oko 40%" reads exactly like the 41.3% beside it.
//
// **The name never goes.** The subject is replaced by the word „protivnik"
// before the prompt is built. It adds nothing to the prose — the model is
// describing a playing style, not a person — and this feature exists to profile
// a named individual who never opened the app, quite possibly a child. Sending
// that name and their playing record to a third party is the part of this that
// cannot be taken back, and it is not needed for the sentence to be good.

const { checkNarrative } = require('./narrativeGuard');
const logger = require('./logger');

/// How many of the report's positions the sentence is allowed to see.
///
/// Small on purpose. A sentence about four positions is a sentence; a sentence
/// about forty is a list, and the report is already a better list than prose
/// will ever be.
const DEFAULT_POSITIONS = 4;

/// The facts, stripped to what a sentence can honestly use.
///
/// This object is both what the model is shown **and** what the guard checks
/// against, and it must stay one object for that reason: two derivations of
/// "the numbers" would eventually disagree, and the disagreement would show up
/// as the guard refusing sentences that were true.
function factsFrom(report, { positions = DEFAULT_POSITIONS } = {}) {
  const nodes = (report?.nodes || []).slice(0, positions).map((node) => ({
    ply: node.ply,
    games: node.games,
    score: node.score,
    moves: (node.moves || []).slice(0, 2).map((move) => ({
      san: move.san,
      games: move.games,
      score: move.score,
      share: move.share,
    })),
    // A verdict is a word, not a number, and it is the one piece of judgement
    // here that was computed rather than written. Passed through so the
    // sentence can use it instead of inventing an opinion.
    verdict: node.judgement?.verdict ?? null,
    better: node.judgement?.eval?.better ?? null,
  }));

  return {
    // Deliberately not `report.subject`. See the header.
    games: report?.games ?? 0,
    color: report?.color ?? null,
    positions: nodes,
  };
}

function buildPrompt(facts) {
  return `Ti si šahovski trener. Na osnovu izmerenih podataka o protivniku napiši
kratak opis njegovog otvaranja — najviše tri rečenice, na srpskom.

PODACI (JSON). Ovo je sve što znaš:
${JSON.stringify(facts, null, 2)}

Značenje polja: "games" je broj partija, "score" je prolaznost od 0 do 1,
"share" je udeo tog poteza u toj poziciji, "ply" je polupotez, "verdict" je
presuda o potezu ("theory", "playable", "mistake"), "better" je bolji potez.

PRAVILA:
- Piši o „protivniku". Ime ne znaš i ne izmišljaj ga.
- Svaki broj koji napišeš mora doslovno postojati u podacima gore. Prolaznost
  smeš izraziti kao procenat (0.413 → 41.3%), ali ne smeš zaokruživati,
  sabirati, prosečiti niti izvoditi bilo koji novi broj.
- Ako nisi siguran u broj, izostavi ga. Rečenica bez broja je u redu.
- Bez uvoda i bez zaključka. Samo opis.`;
}

/// A second attempt, told exactly which numerals were refused.
///
/// One retry and not more. The model usually fixes it when shown the offending
/// token, and a loop that keeps asking until something passes is a loop that
/// eventually launders a wrong number into an accepted one.
function buildRetryPrompt(facts, invented) {
  return `${buildPrompt(facts)}

PRETHODNI POKUŠAJ JE ODBIJEN. Sadržao je brojeve kojih nema u podacima: ${invented.join(', ')}.
Napiši ponovo, bez tih brojeva.`;
}

function createPrepNarrative({ generate, positions = DEFAULT_POSITIONS, retry = true } = {}) {
  if (typeof generate !== 'function') {
    throw new TypeError('createPrepNarrative requires a generate function');
  }

  /// The sentence, or the named reason there is none.
  ///
  /// Never throws for a bad answer and never returns a partial one. The report
  /// is the product; this is decoration, and decoration that fails must not
  /// take the report down with it — the same rule as every message in this
  /// codebase.
  async function narrate(report, { positions: howMany = positions } = {}) {
    const facts = factsFrom(report, { positions: howMany });

    if (facts.positions.length === 0) {
      // Nothing was flagged, so there is nothing to describe. Saying so is a
      // better answer than a sentence about an empty table.
      return { narrative: null, reason: 'no-findings' };
    }

    let answer;
    try {
      answer = await generate(buildPrompt(facts));
    } catch (err) {
      logger.error(`[PRIPREMA] Opis protivnika nije generisan: ${err.message}`);
      return { narrative: null, reason: 'model-unavailable' };
    }

    let verdict = checkNarrative(answer, facts);
    if (!verdict.ok && verdict.reason === 'invented-numbers' && retry) {
      logger.info(
        { invented: verdict.invented },
        'Prep narrative refused, asking once more',
      );
      try {
        answer = await generate(buildRetryPrompt(facts, verdict.invented));
        verdict = checkNarrative(answer, facts);
      } catch (err) {
        return { narrative: null, reason: 'model-unavailable' };
      }
    }

    if (!verdict.ok) {
      // Fails closed. There is no version of this where the invented figure
      // reaches the player with a warning beside it.
      logger.warn(
        { reason: verdict.reason, invented: verdict.invented || [] },
        'Prep narrative dropped',
      );
      return {
        narrative: null,
        reason: verdict.reason,
        invented: verdict.invented || [],
      };
    }

    return { narrative: verdict.narrative, reason: null, basedOn: facts.positions.length };
  }

  return { narrate, factsFrom, buildPrompt };
}

module.exports = {
  createPrepNarrative,
  factsFrom,
  buildPrompt,
  DEFAULT_POSITIONS,
};
