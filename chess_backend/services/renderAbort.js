// renderAbort.js — a film nobody wants any more stops being drawn.
//
// Measured on 9.9.2026: a client whose request hit the 300 s ceiling went away
// and the server drew for minutes more, wrote a 14 MB MP4 whose download URL
// had been in the response nobody received, and — the part that matters — held
// the one render slot for the whole of it, so every other trainer was queued
// behind a film that would never be collected, or turned away with a 429.
//
// **Who fires the signal changed with item 5 of part two of
// docs/PLAN-SNIMANJE.md.** It used to be the client hanging up
// (`abortOnDisconnect`, deleted with that item). A tutorial's film is drawn
// after its request has been answered now, so the socket closes with the 202,
// and „the client is gone" would stop every render at birth. The trainer's own
// „Cancel render" fires it (`services/renderJobs.js`); everything below — the
// frame loop's check, the piper kill, the ffmpeg kill — is as it was.
//
// **Why a signal rather than a flag.** Three things have to stop: the frame
// loop, the piper process synthesising the narration, and the ffmpeg joining
// the clips. Two of those are child processes, and `AbortSignal` is what the
// standard library already spells this with — one object passed down, one
// `abort` event, no polling.

/// Thrown when the film being drawn is no longer wanted.
///
/// A distinct type because it is **not** an error to report: the trainer asked
/// for it. The route records it as a cancelled job, and anything that catches
/// broadly must not turn it into a failed film.
class RenderAborted extends Error {
  constructor(message = 'render aborted: nobody wants this film any more') {
    super(message);
    this.name = 'RenderAborted';
  }
}

/// Stops here when the render has already been cancelled.
///
/// Called at the top of the queued task as well as inside it: a film cancelled
/// while it waited its turn must not start drawing, because starting would hold
/// the slot for a whole film.
function throwIfAborted(signal) {
  if (signal && signal.aborted) throw new RenderAborted();
}

/// Kills [proc] when [signal] fires.
///
/// `SIGKILL` rather than `SIGTERM`: piper is a Python process that ignores a
/// polite ask while it is inside the model, and ffmpeg asked politely finishes
/// writing the file it was told to write — which is the file this exists to
/// prevent.
///
/// Returns the function that stops listening; it is also called when the
/// process exits on its own, because a signal that outlives a render must not
/// hold a reference to its dead children.
function killOnAbort(proc, signal) {
  if (!signal) return () => {};

  const kill = () => {
    try {
      proc.kill('SIGKILL');
    } catch {
      // Already gone. Nothing to stop, and nothing to report: this is the
      // ordinary race between a process exiting and a render being cancelled.
    }
  };

  if (signal.aborted) {
    kill();
    return () => {};
  }

  signal.addEventListener('abort', kill, { once: true });
  const off = () => signal.removeEventListener('abort', kill);
  proc.once('close', off);
  return off;
}

module.exports = { RenderAborted, throwIfAborted, killOnAbort };
