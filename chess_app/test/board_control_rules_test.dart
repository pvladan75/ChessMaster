import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/board_control_rules.dart';

void main() {
  // Phase 3 of docs/PLAN-SESIJA.md rewrote these on 21.9.2026, openly. The
  // account's role is no longer a parameter — it used to be, and two of the
  // cases that stood here held the opposite of today's rule: „an account-level
  // trainer is trusted in any room" and „an admin account seated as host". There
  // is no co-host seat any more, and `users.role` plays no part in teaching.

  test('whoever started the session drives a locked board', () {
    // The original report, which still holds: the server seats the creator
    // 'trener' while their account is the 'korisnik' everyone registers as, and
    // a new room is locked.
    for (final locked in ['trainer_only', 'host_only']) {
      expect(canDriveSharedBoard(seatRole: 'trener', boardControl: locked),
          isTrue);
    }
  });

  test('a student is held back while the board is locked, in both spellings',
      () {
    // `host_only` is what a fresh room arrives as: the database default.
    for (final locked in ['trainer_only', 'host_only']) {
      expect(canDriveSharedBoard(seatRole: 'ucenik', boardControl: locked),
          isFalse);
    }
  });

  test('every other spelling the column has held is an open board', () {
    // `student_white` and `student_black` never filtered a move by colour on
    // either end, so they were open boards with a misleading label.
    for (final open in [
      'student_both',
      'student_white',
      'student_black',
      'unrestricted',
    ]) {
      expect(boardIsOpen(open), isTrue, reason: open);
      expect(
          canDriveSharedBoard(seatRole: 'ucenik', boardControl: open), isTrue,
          reason: open);
    }
    expect(boardIsOpen(boardLocked), isFalse);
    expect(boardIsOpen(boardOpen), isTrue);
  });

  test('the co-host seat leads nothing', () {
    // Removed with promotion. A client that still claims it is a student.
    expect(leadsRoom(seatRole: 'host'), isFalse);
    expect(canDriveSharedBoard(seatRole: 'host', boardControl: 'trainer_only'),
        isFalse);
  });

  test('a guest, and a seat not yet granted, lead nothing', () {
    expect(leadsRoom(seatRole: 'gost'), isFalse);
    expect(leadsRoom(seatRole: null), isFalse);
    expect(leadsRoom(seatRole: 'korisnik'), isFalse);
  });

  test('the local Preparation board is led by whoever is at it', () {
    // It has no room to broadcast to, so there is nothing to protect.
    expect(leadsRoom(seatRole: null, isStudio: true), isTrue);
    expect(
        canDriveSharedBoard(
            seatRole: null, boardControl: 'trainer_only', isStudio: true),
        isTrue);
  });

  // ── who teaches in a room — item 5 of the owner's review of 21.9.2026 ──────
  //
  // Reported on TODO-provera 201.10: „ako učenik napravi sesiju i pozove
  // trenera, obojica imaju panel". The seat cannot answer it: the server
  // seats whoever *opened* the room as 'trener' and everyone who joins as
  // 'ucenik', so in a room a student opened, the student sits as the trainer.
  // Decided with the owner: teaching actions go by **relationship** — you are
  // the accepted trainer of someone in the room — or you opened the room and
  // are somebody's trainer, so a trainer preparing before the student arrives
  // keeps them. Every case below is one the owner asked about.
  group('mayTeachInRoom', () {
    // A trains B, C trains B; each list is „my accepted students".
    bool teaches(int me, Set<int> myStudents, List<int> inRoom,
            {bool opened = false}) =>
        mayTeachInRoom(
          isStudio: false,
          myId: me,
          myStudentIds: myStudents,
          memberIds: inRoom,
          openedRoom: opened,
        );

    test('the reported room: a student opened it and invited the trainer', () {
      // B (student, no students of their own) opened; A trains B.
      expect(teaches(2, {}, [1, 2], opened: true), isFalse,
          reason: 'the student who opened the room is not its trainer');
      expect(teaches(1, {2}, [1, 2]), isTrue,
          reason: 'the trainer who joined lost the tools');
    });

    test('A and C both train B, and are nothing to each other', () {
      const room = [1, 2, 3];
      expect(teaches(1, {2}, room), isTrue);
      expect(teaches(3, {2}, room), isTrue);
      expect(teaches(2, {}, room), isFalse);
    });

    test('the same, and A also trains C', () {
      const room = [1, 2, 3];
      expect(teaches(1, {2, 3}, room), isTrue);
      expect(teaches(3, {2}, room), isTrue,
          reason: 'C is A\'s student and B\'s trainer; the position counts');
      expect(teaches(2, {}, room), isFalse);
    });

    test('a circle A → B → C → A: everybody trains somebody present', () {
      const room = [1, 2, 3];
      expect(teaches(1, {2}, room), isTrue);
      expect(teaches(2, {3}, room), isTrue);
      expect(teaches(3, {1}, room), isTrue);
    });

    test('a trainer who opened the room keeps the tools before anyone comes',
        () {
      expect(teaches(1, {2}, [1], opened: true), isTrue);
    });

    test('a trainer whose students are elsewhere, in a room they did not open',
        () {
      // C trains B, but B is not here, and A — C's trainer — opened the room.
      expect(teaches(3, {2}, [1, 3]), isFalse);
    });

    test('I am not my own student', () {
      // A roster lists me too; a stray edge to myself must not count — not
      // among the people present, and not as „somebody's trainer" in a room I
      // opened. The server refuses a relationship with oneself, so this is a
      // guard, not a case the data has; the second line is the one that bites
      // (without it the self-filter survived its mutation).
      expect(teaches(1, {1}, [1]), isFalse);
      expect(teaches(1, {1}, [1], opened: true), isFalse);
    });

    test('the local Preparation board has no room to be anybody in', () {
      expect(
        mayTeachInRoom(
          isStudio: true,
          myId: 1,
          myStudentIds: const {},
          memberIds: const [],
          openedRoom: false,
        ),
        isTrue,
      );
    });
  });
}
