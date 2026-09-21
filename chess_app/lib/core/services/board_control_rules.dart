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

/// True when this account **teaches** in the room — the rule behind the
/// room's teaching actions („Make exercise", and what a tutorial row offers),
/// as against the board tools and keeping one's own copy, which follow
/// [canDriveSharedBoard] and belong to anyone who may move on the board.
///
/// **Not the seat.** The server seats whoever opened the room as 'trener' and
/// everyone who joins as 'ucenik', so in a room a student opened the student
/// sits as the trainer — which is how both people ended up with the whole
/// panel (TODO-provera 201.10, reported 20.9.2026). Decided with the owner on
/// 21.9.2026, by relationship:
///
///  * you are the accepted trainer of at least one other person in the room
///    ([memberIds] against [myStudentIds]) — a trainer is a position in a
///    relationship, not a property of a person, so in a circle A → B → C → A
///    all three teach, and someone's student is still their own student's
///    trainer; or
///  * you opened the room and are somebody's trainer at all, so a trainer
///    preparing before the student arrives keeps them.
///
/// Rights stay pairwise everywhere else in this codebase; nothing here grants
/// anything, it only decides what the panel offers, and every such action
/// writes to the actor's own library.
bool mayTeachInRoom({
  required bool isStudio,
  required int myId,
  required Set<int> myStudentIds,
  required Iterable<int> memberIds,
  required bool openedRoom,
}) {
  if (isStudio) return true;
  final students = myStudentIds.where((id) => id != myId).toSet();
  if (openedRoom && students.isNotEmpty) return true;
  return memberIds.any((id) => id != myId && students.contains(id));
}
