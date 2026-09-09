// renderAbort.js — a film nobody is waiting for stops being drawn.
//
// Measured on 9.9.2026: a client whose request hit the 300 s ceiling went away
// and the server drew for minutes more, wrote a 14 MB MP4 whose download URL
// had been in the response nobody received, and — the part that matters — held
// the one render slot for the whole of it, so every other trainer was queued
// behind a film that would never be collected, or turned away with a 429.
//
// `RENDER_QUEUE_MAX` bounds the *queue*; it says nothing about one render that
// outlives its own connection. That is what this file is for.
//
// **Why a signal rather than a flag.** Three things have to stop: the frame
// loop, the piper process synthesising the narration, and the ffmpeg joining
// the clips. Two of those are child processes, and `AbortSignal` is what the
// standard library already spells this with — one object passed down, one
// `abort` event, no polling.

/// Thrown when the client that asked for a render has gone.
///
/// A distinct type because it is **not** an error to report: there is nobody to
/// report it to. The route swallows it deliberately, and anything that catches
/// broadly must not turn it into a 500 for a socket that is already closed.
class RenderAborted extends Error {
  constructor(message = 'render aborted: the client is gone') {
    super(message);
    this.name = 'RenderAborted';
  }
}

/// The signal for one export request, fired when its client disconnects.
///
/// **`writableFinished` is the whole of the correctness here.** A response that
/// completed normally also emits `close`, so a listener that aborts on every
/// `close` would abort every successful render the instant it answered — which
/// is harmless today only because nothing is running by then, and would become
/// a silent cancellation the first time anything is. Asked of the response
/// rather than of the request, because `req`'s own `close` fires when the
/// request *body* has been read, which for a POST is long before the render.
function abortOnDisconnect(res) {
  const controller = new AbortController();
  const onClose = () => {
    if (!res.writableFinished) controller.abort();
  };
  res.on('close', onClose);
  return {
    signal: controller.signal,
    /// Stops listening. The response object outlives the handler, so a listener
    /// left on it is a listener that fires after everything it could have
    /// stopped is over.
    dispose() {
      res.off('close', onClose);
    },
  };
}

/// Stops here when the client has already gone.
///
/// Called at the top of the queued task as well as inside it: a render that
/// waited its turn behind two others is exactly the one whose client is most
/// likely to have given up, and starting to draw for it would hold the slot
/// for a full film.
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
      // ordinary race between a process exiting and a client leaving.
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

module.exports = { RenderAborted, abortOnDisconnect, throwIfAborted, killOnAbort };
