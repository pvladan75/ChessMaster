import 'dart:async';

import 'package:flutter/foundation.dart';

/// Whether the engine is answering, as one sentence for the screen — or null.
///
/// An engine that answers nothing is not an error anywhere in this app: every
/// wait on it times out, logs a line and „proceeds anyway", so the user sees a
/// board with no evaluation and no reason (owner's report of 20.9.2026). This
/// is the reason. `StockfishService` feeds it; `EngineNotice` shows it. It
/// holds no engine and no widgets, so a test drives it directly.
class EngineSilence extends ValueNotifier<String?> {
  EngineSilence() : super(null);

  /// The one the service and the app share.
  static final EngineSilence instance = EngineSilence();

  static const String notAnswering =
      'The engine is not answering. Close the app completely and open it again.';
  static const String stopped =
      'The engine has stopped. Leave this screen and open it again.';

  Timer? _waiting;
  int _heard = 0;

  /// Taken when a question is sent, handed back to [unansweredSince].
  int get mark => _heard;

  /// A command was sent that the engine must answer ([within]) — `uci`.
  void expectAnswer(Duration within) {
    _waiting?.cancel();
    _waiting = Timer(within, () => value = notAnswering);
  }

  /// A line from the engine. **The banner is not an answer**: it is printed
  /// before the engine reads its first command, and an engine stuck behind
  /// another reader of the process's stdin prints it and nothing else.
  void heard(String line) {
    if (line.startsWith('Stockfish ')) return;
    _heard++;
    _waiting?.cancel();
    _waiting = null;
    value = null;
  }

  /// A wait on the engine ran out — `isready` with no `readyok` — **and the
  /// engine said nothing at all since [mark] was taken.** The service can run
  /// two drains at once, and the second takes over the first one's waiter: the
  /// first then times out on an engine that answered. A timeout beside a
  /// talking engine is the service's bookkeeping, not the engine's silence.
  void unansweredSince(int mark) {
    if (_heard != mark) return;
    value = notAnswering;
  }

  /// The engine refused a write: it has exited.
  void exited() => value = stopped;

  /// The engine was shut down on purpose; nothing is owed.
  void clear() {
    _waiting?.cancel();
    _waiting = null;
    value = null;
  }
}
