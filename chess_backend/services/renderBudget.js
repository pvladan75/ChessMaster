// renderBudget.js — whether a film is short enough to draw in one go, answered
// before anything is drawn. Item 4 of part two of docs/PLAN-SNIMANJE.md.
//
// It was written while the render happened inside the POST, and that request
// had a ceiling: nginx closes a proxied request after 300 s. A film that needed
// longer used to be drawn anyway until the connection went and the abort
// stopped it — a trainer watching a bar for five minutes and getting nothing.
// The arithmetic was there the whole time: the number of frames is known before
// the first one is drawn.
//
// **Since item 5 a tutorial's film is drawn after its request**, so its ceiling
// is not the connection's any more and was raised to 600 s by the owner on
// 10.9.2026. It is still a ceiling, for the reason the owner gave for the
// hybrid: „ne bih dozvolio da jedan veliki render koči nekoliko manjih duže
// vreme." One slot draws one film at a time, and until a long film is drawn in
// chunks that other films can go between, the longest film is the longest
// anybody else waits behind it. When chunking lands, „too long" stops being a
// refusal and becomes the choice of a lane, made by this same arithmetic.
//
// The connection's own number is still here, because one export is still drawn
// inside its request — the recorded lesson's — and the queue has to know when
// that client stops waiting.

/// How long a request may take before nginx closes it, in seconds.
///
/// Default 300: `proxy_read_timeout` in deploy/app-setup.sh — change the two
/// together. Read only for an export still drawn inside its request
/// (`routes/recordings.js`), to tell the queue when its client stops waiting.
function requestSeconds() {
  const n = Number(process.env.RENDER_REQUEST_SECONDS);
  return Number.isFinite(n) && n > 0 ? n : 300;
}

/// The longest one film may take to draw, in seconds.
///
/// Default 600 — the owner's decision of 10.9.2026, once the tutorial film had
/// left the request: about thirty minutes of captioned film at 720p on the
/// default rate. Not nginx's number, since nothing waits on a connection for
/// it; it is the longest one film holds the one render slot, which is what
/// every other trainer waits behind. Raising it lets longer films through and
/// makes shorter ones wait longer behind them.
///
/// **The longest recorded narration follows from it** (`narrationUpload.js`),
/// so the two cannot be set to disagree.
function maxDrawSeconds() {
  const n = Number(process.env.RENDER_MAX_DRAW_SECONDS);
  return Number.isFinite(n) && n > 0 ? n : 600;
}

/// Frames drawn per second of wall clock, at [resolution], on this machine.
///
/// **Configured, not constant, and measured where the drawing happens.** On the
/// development machine a captioned 720p film was drawn at 15.6 to 18.7 frames a
/// second, and the same two-minute film took anywhere from 15.4 to 30.2 s over
/// eight runs — a factor of two on identical input. So the default is the slow
/// end with a margin, and 1080p is half of it: a still costs 2.1 times as much
/// there (1.2 s against 2.5 s for the same film). The droplet's own numbers are
/// unknown until somebody measures them there. Too high admits a film that holds
/// the slot longer than the ceiling says; too low refuses films that would have
/// fitted.
///
/// 480p, which only the recorded-lesson export offers, is judged at the 720p
/// rate: it draws faster than that, never slower.
function drawRate(resolution) {
  const hd = resolution === '1080p';
  const n = Number(hd ? process.env.RENDER_DRAW_FPS_1080P : process.env.RENDER_DRAW_FPS_720P);
  if (Number.isFinite(n) && n > 0) return n;
  return hd ? 6 : 12;
}

/// Seconds of wall clock to draw a film [seconds] long at [fps] frames of film
/// a second — `videoRenderer.framesPerSecondOf`, so the frames counted here are
/// the frames the renderer will draw. Rounded up: a promise is never shorter
/// than the work.
function drawSeconds({ seconds, fps, resolution }) {
  return Math.ceil((seconds * fps) / drawRate(resolution));
}

/// The longest film, in seconds, that can be drawn in one go at [fps] and
/// [resolution]. Rounded down, for the same reason.
function longestFilmSeconds({ fps, resolution }) {
  return Math.floor((maxDrawSeconds() * drawRate(resolution)) / fps);
}

function aboutMinutes(seconds) {
  const minutes = Math.ceil(seconds / 60);
  return minutes <= 1 ? 'about a minute' : `about ${minutes} minutes`;
}

const PARTS = ['', 'one', 'two', 'three', 'four', 'five'];

/// The refusal for a film too long to draw in one go, and the ways out.
///
/// **It says what to do.** A refusal with no door is a bug report from the
/// trainer's side. Splitting is always a door — into as many tutorials as the
/// arithmetic says, not „two" when two would still be too long — and [doors]
/// are the others the caller has *checked* would fit. None is offered
/// unchecked: „export it at 720p" on a film that is too long at 720p too is a
/// second refusal waiting to happen.
function tooLongSentence({ drawSeconds: needed, fps, resolution, doors = [], narrated = false }) {
  const fits = Math.floor(longestFilmSeconds({ fps, resolution }) / 60);
  const parts = Math.max(2, Math.ceil(needed / maxDrawSeconds()));
  const ways = [`split the tutorial into ${PARTS[parts] || parts} shorter ones`, ...doors];
  const last = ways.pop();
  const list = ways.length ? `${ways.join(', ')}, or ${last}` : last;
  const lead = narrated ? 'With narration, this video' : 'This video';
  return `${lead} would take ${aboutMinutes(needed)} to render, and the server can render `
    + `about ${fits} minutes of video in one go. ${list[0].toUpperCase()}${list.slice(1)}.`;
}

/// The refusal for a film that would fit on its own but not behind the ones
/// already here — and when there will be room. Not „the server is busy", which
/// is `RenderQueueFull`'s sentence: this server has a place in the queue, just
/// not enough time in front of this film before the connection closes. Only an
/// export still drawn inside its request can be told this.
function retrySentence(waitMs) {
  const when = waitMs <= 60_000 ? 'in a minute or two' : `in ${aboutMinutes(waitMs / 1000)}`;
  return 'The server has other videos to render before this one and could not finish it '
    + `before the connection closes. Try again ${when}.`;
}

/// Thrown at a film's turn when it turns out too long to draw in one go: a
/// synthesised voice made it longer than the length it was accepted on, and
/// that length is known only once the voice has spoken.
class RenderTooLong extends Error {
  constructor({ drawSeconds: needed, fps, narrated = false }) {
    super(`render needs ${needed}s, more than one film may take`);
    this.name = 'RenderTooLong';
    this.drawSeconds = needed;
    this.fps = fps;
    this.narrated = narrated;
  }
}

module.exports = {
  requestSeconds,
  maxDrawSeconds,
  drawRate,
  drawSeconds,
  longestFilmSeconds,
  tooLongSentence,
  retrySentence,
  RenderTooLong,
};
