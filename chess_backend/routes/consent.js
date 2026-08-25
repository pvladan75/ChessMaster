// consent.js — the one page in this project that is not for the app.
//
// A parent opens it from a link in an email, on whatever device is at hand,
// without an account and without installing anything. That is the whole reason
// the flow was built this way rather than as a code typed into the app: only a
// page the parent actually opened can honestly fill `parent_consent_at`,
// `parent_consent_ip` and `parent_consent_version`.
//
// Three rules hold here that do not hold anywhere else in this codebase:
//
//   * **No authentication, so the token is the entire lock.** Every other route
//     asks who is calling. This one cannot — the parent has no account — so the
//     link is 32 random bytes, single-use, and expires. Nothing on the page is
//     reachable without it.
//   * **Everything is inlined.** No stylesheet, no script, no font: this is
//     opened in an unknown mail client on an unknown network, and a page that
//     needs a second request is a page that sometimes arrives blank.
//   * **Every name is escaped.** The page prints a child's name and a trainer's
//     name straight from the database, and a name is whatever somebody typed
//     into a registration form.

const express = require('express');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const {
  findRequest,
  recordAnswer,
  textVersion,
} = require('../services/parentConsentService');

/// Text into HTML. Not a general sanitiser — the inputs here are names and
/// dates, and what they must never do is close a tag or open an attribute.
function esc(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function page(title, body) {
  return `<!DOCTYPE html>
<html lang="sr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${esc(title)}</title>
<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0; padding: 24px 16px;
    font: 16px/1.55 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    background: #f5f5f7; color: #1c1c1e;
  }
  main { max-width: 640px; margin: 0 auto; background: #fff;
         border-radius: 14px; padding: 24px; box-sizing: border-box;
         box-shadow: 0 1px 3px rgba(0,0,0,.12); }
  h1 { font-size: 1.35rem; margin: 0 0 4px; }
  h2 { font-size: 1.05rem; margin: 24px 0 8px; }
  p, li { margin: 8px 0; }
  .lead { color: #48484a; }
  .card { background: #f2f2f7; border-radius: 10px; padding: 12px 16px;
          margin: 16px 0; }
  .card div { margin: 4px 0; }
  label.check { display: flex; gap: 10px; align-items: flex-start;
                margin: 14px 0; }
  label.check input { margin-top: 4px; width: 18px; height: 18px; flex: none; }
  .actions { display: flex; flex-wrap: wrap; gap: 12px; margin-top: 24px; }
  button { font: inherit; padding: 12px 20px; border-radius: 10px;
           border: 0; cursor: pointer; }
  button.yes { background: #0a7d32; color: #fff; }
  button.no { background: transparent; color: #48484a;
              border: 1px solid #c7c7cc; }
  footer { max-width: 640px; margin: 16px auto 0; color: #6c6c70;
           font-size: .82rem; }
  @media (prefers-color-scheme: dark) {
    body { background: #000; color: #f2f2f7; }
    main { background: #1c1c1e; box-shadow: none; }
    .lead { color: #aeaeb2; }
    .card { background: #2c2c2e; }
    button.no { color: #aeaeb2; border-color: #48484a; }
    footer { color: #8e8e93; }
  }
</style>
</head>
<body>
<main>
${body}
</main>
<footer>Ova stranica je otvorena iz linka poslatog na vašu adresu. Ako niste
tražili ovu poruku, ne morate ništa da uradite.</footer>
</body>
</html>`;
}

function notice(title, message) {
  return page(title, `<h1>${esc(title)}</h1><p class="lead">${esc(message)}</p>`);
}

/// Why there is no form, said in the sentence that belongs to each case.
///
/// Kept apart rather than collapsed into "link nije ispravan": a parent whose
/// link expired has to know to ask for a new one, and a parent who already
/// answered has to be told that their answer was recorded — showing them the
/// form again would read as the first attempt having failed.
const REFUSALS = {
  'not-found': [
    'Link nije prepoznat',
    'Moguće je da je nepotpuno kopiran iz poruke, ili da je saglasnost u '
    + 'međuvremenu poništena. Zamolite trenera da pošalje novu poruku.',
  ],
  expired: [
    'Link je istekao',
    'Iz bezbednosnih razloga link važi ograničeno. Zamolite trenera da pošalje '
    + 'novu poruku i saglasnost ćete dati na istoj ovakvoj stranici.',
  ],
  answered: [
    'Već ste odgovorili',
    'Vaš odgovor je zabeležen i ne treba ga ponavljati. Ako želite da ga '
    + 'promenite ili povučete, javite se treneru ili nam pišite.',
  ],
};

router.get('/consent/:token', async (req, res) => {
  try {
    const { request, reason } = await findRequest(pool, req.params.token);
    if (reason !== null) {
      const [title, message] = REFUSALS[reason] ?? REFUSALS['not-found'];
      // 200 rather than 404: this is a page for a person, not an answer to a
      // program, and a mail client that hides non-200 responses would show a
      // parent nothing at all.
      return res.status(200).type('html').send(notice(title, message));
    }

    const child = esc(request.student_name || 'dete');
    const trainer = esc(request.trainer_name || 'trener');

    return res.type('html').send(page('Saglasnost roditelja', `
<h1>Saglasnost roditelja</h1>
<p class="lead">Trener je zatražio dozvolu da uči vaše dete u aplikaciji za
šahovsku obuku. Bez vaše potvrde ta veza ne počinje.</p>

<div class="card">
  <div><strong>Dete:</strong> ${child}</div>
  <div><strong>Trener:</strong> ${trainer}</div>
  <div><strong>Vaša adresa:</strong> ${esc(request.parent_email)}</div>
</div>

<h2>Na šta dajete saglasnost</h2>
<p>Prve dve stavke su neophodne da bi dete moglo da pohađa časove. Treća je
opciona — možete je odbiti, a da dete i dalje pohađa časove.</p>
<ol>
  <li><strong>Nalog.</strong> Da dete ima nalog u aplikaciji i da se u njemu
      čuvaju: email adresa, ime, odigrani potezi, rezultati zagonetki i
      zadataka, i rejting po šahovskim temama.</li>
  <li><strong>Uvid trenera.</strong> Da navedeni trener vidi napredak deteta —
      rezultate zadataka, tačnost i teme na kojima dete greši — i da mu na
      osnovu toga zadaje vežbe.</li>
  <li><strong>Snimanje časova (opciono).</strong> Da se časovi na kojima
      učestvuje dete mogu snimati, uključujući zvučni zapis glasa deteta, i da
      trener taj snimak čuva i koristi za pregled časa sa vama i sa detetom.
      Snimak nije javan i vidljiv je samo treneru i učesnicima tog časa.</li>
</ol>

<h2>Šta se ne radi</h2>
<ul>
  <li>Podaci deteta se <strong>ne prodaju</strong> i ne ustupaju oglašivačima.</li>
  <li>Detetu se <strong>ne prikazuju reklame</strong>.</li>
  <li>Snimci se <strong>ne objavljuju</strong> niti dele van kruga učesnika časa.</li>
  <li>Servisu veštačke inteligencije <strong>ne šalje se nijedan lični podatak
      deteta</strong> — samo šahovske pozicije.</li>
</ul>

<h2>Vaša prava</h2>
<p>U svakom trenutku možete tražiti uvid u podatke koji se čuvaju o vašem
detetu, ispravku netačnih podataka, brisanje pojedinačnog snimka ili svih
snimaka, brisanje celog naloga, i <strong>povlačenje ove saglasnosti</strong> —
u celini ili samo za snimanje. Povlačenje ne utiče na zakonitost obrade
obavljene do tog trenutka.</p>

<form method="POST" action="/consent/${esc(req.params.token)}">
  <label class="check">
    <input type="checkbox" name="recording" value="da">
    <span>Saglasan/na sam i sa <strong>snimanjem časova</strong> (stavka 3).
      Ovo polje možete ostaviti prazno.</span>
  </label>
  <div class="actions">
    <button class="yes" type="submit" name="odgovor" value="da">
      Dajem saglasnost
    </button>
    <button class="no" type="submit" name="odgovor" value="ne">
      Ne dajem saglasnost
    </button>
  </div>
</form>
<p class="lead" style="margin-top:20px;font-size:.85rem">
  Verzija teksta: ${esc(request.text_version || textVersion())}
</p>
`));
  } catch (err) {
    logger.error('[SAGLASNOST] Stranica nije mogla da se prikaže:', err);
    return res.status(500).type('html').send(notice(
      'Trenutno ne možemo da prikažemo stranicu',
      'Pokušajte ponovo za nekoliko minuta, sa istim linkom.',
    ));
  }
});

router.post('/consent/:token', async (req, res) => {
  const granted = req.body?.odgovor === 'da';
  // Recording is agreed to only when the box was ticked **and** consent was
  // given at all. A refusal that carried a ticked box through would record a
  // parent as agreeing to a recording they refused outright.
  const allowsRecording = granted && req.body?.recording === 'da';

  try {
    const result = await recordAnswer(pool, {
      token: req.params.token,
      // `trust proxy` is set, so this is the parent's address rather than
      // nginx's. It is written into the record because a consent record has to
      // say where the answer came from, and nowhere else.
      ip: req.ip,
      granted,
      allowsRecording,
    });

    if (!result.ok) {
      const [title, message] = REFUSALS[result.reason] ?? REFUSALS['not-found'];
      return res.status(200).type('html').send(notice(title, message));
    }

    logger.info(
      `[SAGLASNOST] Roditelj je odgovorio na vezu ${result.relationshipId}: `
      + `${granted ? 'saglasan' : 'nije saglasan'}`
      + `${granted ? `, snimanje: ${allowsRecording ? 'da' : 'ne'}` : ''}`,
    );

    if (!granted) {
      return res.type('html').send(notice(
        'Saglasnost nije data',
        'Zabeležili smo vaš odgovor. Veza sa trenerom ne počinje, a dete i '
        + 'dalje može samostalno da vežba u aplikaciji.',
      ));
    }

    return res.type('html').send(page('Saglasnost je zabeležena', `
<h1>Hvala — saglasnost je zabeležena</h1>
<p class="lead">Veza između deteta i trenera je od sada aktivna.</p>
<div class="card">
  <div><strong>Dete:</strong> ${esc(result.studentName)}</div>
  <div><strong>Trener:</strong> ${esc(result.trainerName)}</div>
  <div><strong>Snimanje časova:</strong>
    ${allowsRecording ? 'dozvoljeno' : '<strong>nije dozvoljeno</strong>'}</div>
</div>
<p>Ovu stranicu možete zatvoriti. Saglasnost možete povući u svakom trenutku —
javite se treneru ili nam pišite.</p>
`));
  } catch (err) {
    logger.error('[SAGLASNOST] Odgovor nije mogao da se upiše:', err);
    return res.status(500).type('html').send(notice(
      'Odgovor nije sačuvan',
      'Ništa nije zabeleženo. Otvorite isti link ponovo za nekoliko minuta i '
      + 'odgovorite još jednom.',
    ));
  }
});

module.exports = router;
