// recordingTranscripts.js — a recording's transcript in the database, and the
// one question every route about it asks first: is this the host's own
// recording from Preparation? Phase 7 of docs/PLAN-PRIPREMA.md.
//
// **Only the host, only a recording made in Preparation.** A room recording
// had other people in it; a student a recording is shared with reads the film
// and the sound, not what a vendor heard. Anybody else reads not found — never
// a refusal that would say the recording exists.

/// The host's own recording, with what transcribing it needs — or null.
async function hostRecording(pool, recordingId, hostId) {
  const id = Number(recordingId);
  if (!Number.isInteger(id)) return null;
  const result = await pool.query(
    `SELECT id, source, audio_file, duration_ms
       FROM session_recordings
      WHERE id = $1 AND host_id = $2`,
    [id, hostId],
  );
  return result.rows[0] || null;
}

/// Whether [row] can be heard: made in Preparation, with a private sound and
/// a known length.
function transcribable(row) {
  return Boolean(row && row.source === 'preparation' && row.audio_file
    && Number.isInteger(row.duration_ms) && row.duration_ms > 0);
}

/// The transcript as the app reads it, or null.
function wireOf(row) {
  if (!row) return null;
  return {
    language: row.language,
    vendor: row.vendor,
    model: row.model,
    durationMs: row.duration_ms,
    sentences: row.sentences,
    updatedAt: row.updated_at,
  };
}

async function readTranscript(pool, recordingId) {
  const result = await pool.query(
    'SELECT * FROM recording_transcripts WHERE recording_id = $1',
    [recordingId],
  );
  return result.rows[0] || null;
}

/// Keeps a transcript just heard, replacing any the recording had — its
/// corrections with it; the app asks before it hears a recording again.
async function saveTranscript(pool, { recordingId, language, vendor, model, durationMs, sentences, words }) {
  const result = await pool.query(
    `INSERT INTO recording_transcripts
       (recording_id, language, vendor, model, duration_ms, sentences, words)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (recording_id) DO UPDATE
       SET language = EXCLUDED.language, vendor = EXCLUDED.vendor,
           model = EXCLUDED.model, duration_ms = EXCLUDED.duration_ms,
           sentences = EXCLUDED.sentences, words = EXCLUDED.words,
           created_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
     RETURNING *`,
    [recordingId, language, vendor, model, durationMs, JSON.stringify(sentences), JSON.stringify(words)],
  );
  return result.rows[0];
}

/// A correction: the sentences only. The words as heard stay as they were.
async function saveSentences(pool, recordingId, sentences) {
  const result = await pool.query(
    `UPDATE recording_transcripts
        SET sentences = $2, updated_at = CURRENT_TIMESTAMP
      WHERE recording_id = $1
      RETURNING *`,
    [recordingId, JSON.stringify(sentences)],
  );
  return result.rows[0] || null;
}

module.exports = { hostRecording, readTranscript, saveSentences, saveTranscript, transcribable, wireOf };
