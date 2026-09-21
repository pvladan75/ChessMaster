/// What a guest was trying to do when a login-gated action redirected them
/// to [LoginRegisterScreen] — carried through go_router's `extra` so the app
/// can resume it after a successful login instead of just dropping the user
/// on Home. See home_screen.dart's `_checkAuthRequired` (where these are
/// created) and its `initState` (where they're resumed).
enum PendingSessionAction {
  createRoom,
  joinInviteRoom,
}

class PendingSessionIntent {
  final PendingSessionAction action;

  /// The room code for [PendingSessionAction.joinInviteRoom].
  final String? roomCode;

  /// The seat role for [PendingSessionAction.joinInviteRoom].
  final String? role;

  const PendingSessionIntent._(this.action, {this.roomCode, this.role});

  const PendingSessionIntent.createRoom()
      : this._(PendingSessionAction.createRoom);

  const PendingSessionIntent.joinInviteRoom(String code, {String? role})
      : this._(PendingSessionAction.joinInviteRoom, roomCode: code, role: role);
}
