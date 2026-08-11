require('dotenv').config();
const logger = require('./logger');
const nodemailer = require('nodemailer');

const isProduction = process.env.NODE_ENV === 'production';

const SMTP_HOST = process.env.SMTP_HOST;
const SMTP_PORT = parseInt(process.env.SMTP_PORT || '587', 10);
const SMTP_USER = process.env.SMTP_USER;
const SMTP_PASSWORD = process.env.SMTP_PASSWORD;
const MAIL_FROM = process.env.MAIL_FROM || 'Chess Master <no-reply@chessmaster.app>';

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
    subject: 'Chess Master — verifikacioni kod',
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

module.exports = {
  sendVerificationCode,
  isConfigured,
};
