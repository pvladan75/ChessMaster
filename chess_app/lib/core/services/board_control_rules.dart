/// Who is allowed to drive the shared board in a lesson room.
///
/// Kept as a pure function, apart from the session screen's State, because the
/// same rule governs two actions that look unrelated on screen — moving a piece
/// and stepping through the move tree — and both broadcast the resulting
/// position to everyone in the room. When the rule lived inline it was written
/// out four times with three subtly different definitions, and the navigation
/// bar ended up with a fifth that consulted the wrong role entirely.
library;

/// True when a client holding [seatRole] in a room whose board is set to
/// [boardControl] may move pieces and navigate the move tree.
///
/// [seatRole] is the seat the **server** granted for this room, which is what
/// decides this — not the account's global role. A trainer who creates a room
/// is seated 'trener' there while their account is still registered
/// 'korisnik', so testing the account role alone locks the room's own host out
/// of their board. [accountRole] is still honoured, since an account-level
/// trainer is trusted in any room they are in.
///
/// [isStudio] marks the local analysis board, which has no room to share with
/// and so is never restricted.
bool canDriveSharedBoard({
  required String? seatRole,
  required String? accountRole,
  required String boardControl,
  bool isStudio = false,
}) {
  if (isStudio) return true;
  if (seatRole == 'host' || seatRole == 'trener') return true;
  if (accountRole == 'trener') return true;
  // Anything other than the two restricted modes is open to every seat.
  return boardControl != 'host_only' && boardControl != 'trainer_only';
}
