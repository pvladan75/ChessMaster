/// Who is allowed to drive the shared board in a lesson room.
///
/// Kept as a pure function, apart from the session screen's State, because the
/// same rule governs two actions that look unrelated on screen — moving a piece
/// and stepping through the move tree — and both broadcast the resulting
/// position to everyone in the room. When the rule lived inline it was written
/// out four times with three subtly different definitions, and the navigation
/// bar ended up with a fifth that consulted the wrong role entirely.
library;

/// The two states a room's board has (docs/PLAN-SESIJA.md, phase 3).
///
/// The column held six spellings of them: `host_only` (the database default,
/// which no screen could show or choose), `trainer_only`, `student_white` and
/// `student_black` — labels only, nothing on either end ever filtered a move by
/// colour, so „Student plays as White" let them move Black too — `student_both`
/// and `unrestricted`. What the code did with all six was one question, and it
/// is asked here and in `roomBoardEvents.js`, which answers it the same way.
const String boardLocked = 'trainer_only';
const String boardOpen = 'student_both';

/// Whether [boardControl], in any spelling the column has ever held, lets
/// students move. Only the two locked spellings lock.
bool boardIsOpen(String? boardControl) =>
    boardControl != 'host_only' && boardControl != 'trainer_only';

/// True when this seat **leads** the room: the person who started the session,
/// seated 'trener' by the server and by nobody else — or the local Preparation
/// board, which has nobody to share with.
///
/// One answer, in one place. The room screen used to hold four: a getter, two
/// locals that added the *account's* role, and one that left out the co-host
/// seat. There is no co-host any more, and `users.role` plays no part in
/// teaching: a trainer is a position in a relationship.
bool leadsRoom({required String? seatRole, bool isStudio = false}) =>
    isStudio || seatRole == 'trener';

/// True when a client holding [seatRole] in a room whose board is set to
/// [boardControl] may move pieces and navigate the move tree.
///
/// [seatRole] is the seat the **server** granted for this room. The account's
/// own role is not asked: it used to be, and an account registered 'trener'
/// could then drive the board of any room it sat in as a student.
bool canDriveSharedBoard({
  required String? seatRole,
  required String boardControl,
  bool isStudio = false,
}) =>
    leadsRoom(seatRole: seatRole, isStudio: isStudio) ||
    boardIsOpen(boardControl);

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
