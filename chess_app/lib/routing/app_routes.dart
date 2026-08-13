/// Every navigable destination in the app, in one place.
///
/// Paths are the contract: they show up in deep links and in restored
/// navigation state, so treat a change here as a breaking change.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';

  /// Live lesson/game room. `:roomCode` is the join code; an optional `role`
  /// query parameter seeds the local role until the server confirms it.
  static const String room = '/room/:roomCode';

  /// Analysis board. Optional `fen` query parameter opens a specific position;
  /// without it the screen restores the user's autosaved draft.
  static const String analysis = '/analysis';

  /// Recorded lesson playback.
  static const String replay = '/replay/:recordingId';

  /// App settings pushed *over* the current screen. Distinct from the Settings
  /// tab inside the home shell: this variant keeps the analysis board or a live
  /// room mounted underneath, so closing it returns the user exactly where they
  /// were rather than tearing their work down.
  static const String preferences = '/preferences';

  // ── Builders, so callers never hand-assemble a path ──

  static String roomPath(String roomCode, {String? role}) {
    final query = role == null || role.isEmpty ? '' : '?role=$role';
    return '/room/${Uri.encodeComponent(roomCode)}$query';
  }

  static String analysisPath({String? fen}) {
    if (fen == null || fen.isEmpty) return analysis;
    return '$analysis?fen=${Uri.encodeComponent(fen)}';
  }

  static String replayPath(int recordingId) => '/replay/$recordingId';
}
