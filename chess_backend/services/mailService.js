require('dotenv').config();
const logger = require('./logger');
const nodemailer = require('nodemailer');

const isProduction = process.env.NODE_ENV === 'production';

const SMTP_HOST = process.env.SMTP_HOST;
const SMTP_PORT = parseInt(process.env.SMTP_PORT || '587', 10);
const SMTP_USER = process.env.SMTP_USER;
const SMTP_PASSWORD = process.env.SMTP_PASSWORD;
const MAIL_FROM = process.env.MAIL_FROM || 'Chess Coach <no-reply@chesstrainers.app>';

const isConfigured = Boolean(SMTP_HOST && SMTP_USER && SMTP_PASSWORD);

let transporter = null;
if (isConfigured) {
  transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: SMTP_PORT,
    secure: SMTP_PORT === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASSWORD },
  });
  logger.info(`[MAIL] SMTP transport configured for ${SMTP_HOST}:${SMTP_PORT}`);
} else if (isProduction) {
  logger.error('[MAIL] SMTP is not configured. Verification emails cannot be delivered in production.');
} else {
  logger.warn('[MAIL] SMTP is not configured — verification codes will be printed to this log (development only).');
}

/// Delivers a verification code.
///
/// With SMTP configured the code is emailed and never logged. Without SMTP it is
/// logged in development so local testing still works, and rejected in production
/// so a user is never left waiting for an email that cannot arrive.
async function sendVerificationCode(email, code, name) {
  if (!isConfigured) {
    if (isProduction) {
      throw new Error('Email delivery is not configured on this server.');
    }
    logger.warn(`[MAIL][DEV ONLY] Verification code for ${email}: ${code}`);
    return { delivered: false, devFallback: true };
  }

  const greeting = name ? `Zdravo ${name},` : 'Zdravo,';
  await transporter.sendMail({
    from: MAIL_FROM,
    to: email,
    subject: 'Verifikacioni kod',
    text: `${greeting}\n\nVaš verifikacioni kod je: ${code}\n\nKod važi 15 minuta. Ako niste tražili registraciju, ignorišite ovu poruku.`,
    html:
      `<p>${greeting}</p>` +
      `<p>Vaš verifikacioni kod je:</p>` +
      `<p style="font-size:28px;font-weight:bold;letter-spacing:4px">${code}</p>` +
      `<p>Kod važi 15 minuta. Ako niste tražili registraciju, ignorišite ovu poruku.</p>`,
  });

  logger.info(`[MAIL] Verification code sent to ${email}`);
  return { delivered: true, devFallback: false };
}

/// A name into HTML. Names reach the mail body from a registration form, so
/// they are text rather than markup — the same rule the consent page follows.
function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

/// Asks a parent to answer, with the link that is the whole flow.
///
/// Deliberately says almost nothing: who is asking, about which child, and one
/// link. The detail belongs on the page, where there is room for it and where
/// opening it is a deliberate act that can be recorded — an email that carried
/// the whole text would be a consent form nobody can prove was read.
///
/// Without SMTP the link is logged in development, the same fallback the
/// verification code has, so the flow can be walked end to end on one machine.
/// In production it throws: a parent left waiting for a mail that cannot arrive
/// is a relationship stuck at `awaiting_parent` with nobody able to say why.
async function sendParentConsentRequest(email, { childName, trainerName, link }) {
  if (!link) {
    throw new Error('PUBLIC_BASE_URL is not configured, so no link can be sent.');
  }

  const child = childName || 'vaše dete';
  const trainer = trainerName || 'trener';
  // Both are whatever somebody typed into a registration form, and both are
  // about to be put inside HTML tags.
  const childHtml = escapeHtml(child);
  const trainerHtml = escapeHtml(trainer);
  const text = `Poštovani,

`
    + `${trainer} je zatražio/la dozvolu da uči ${child} u aplikaciji za `
    + `šahovsku obuku. Bez vaše potvrde ta veza ne počinje.

`
    + `Šta se traži i šta se čuva o detetu piše na stranici ispod. Tamo `
    + `saglasnost dajete ili odbijate — snimanje časova je posebna, opciona `
    + `stavka:

${link}

`
    + `Ako niste očekivali ovu poruku, ne morate ništa da uradite.`;

  if (!isConfigured) {
    if (isProduction) {
      throw new Error('Email delivery is not configured on this server.');
    }
    logger.warn(`[MAIL][DEV ONLY] Link za saglasnost (${email}): ${link}`);
    return { delivered: false, devFallback: true };
  }

  await transporter.sendMail({
    from: MAIL_FROM,
    to: email,
    subject: 'Saglasnost za učešće deteta u šahovskoj obuci',
    text,
    html:
      `<p>Poštovani,</p>`
      + `<p><strong>${trainerHtml}</strong> je zatražio/la dozvolu da uči `
      + `<strong>${childHtml}</strong> u aplikaciji za šahovsku obuku. Bez vaše `
      + `potvrde ta veza ne počinje.</p>`
      + `<p>Šta se traži i šta se čuva o detetu piše na stranici ispod. Tamo `
      + `saglasnost dajete ili odbijate — snimanje časova je posebna, opciona `
      + `stavka.</p>`
      + `<p><a href="${link}">Otvorite stranicu sa saglasnošću</a></p>`
      + `<p style="color:#666;font-size:13px">Ako niste očekivali ovu poruku, `
      + `ne morate ništa da uradite.</p>`,
  });

  logger.info(`[MAIL] Parent consent request sent to ${email}`);
  return { delivered: true, devFallback: false };
}

module.exports = {
  sendVerificationCode,
  sendParentConsentRequest,
  isConfigured,
};
