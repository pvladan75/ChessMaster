import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/board_control_rules.dart';

void main() {
  test('the room host may navigate even though their account is not a trainer',
      () {
    // The reported bug, exactly: a trainer creates a room, so the server seats
    // them 'trener' while their account is still the 'korisnik' everyone
    // registers as. boardControl defaults to 'trainer_only'. Reading the
    // account role alone answered false here and disabled the whole navigation
    // bar for the very person running the lesson.
    expect(
      canDriveSharedBoard(
        seatRole: 'trener',
        accountRole: 'korisnik',
        boardControl: 'trainer_only',
      ),
      isTrue,
    );
  });

  test('an admin account seated as host is not locked out either', () {
    // The owner's account was promoted to 'admin', which is likewise not
    // 'trener' — the account role is simply the wrong thing to ask.
    expect(
      canDriveSharedBoard(
        seatRole: 'host',
        accountRole: 'admin',
        boardControl: 'host_only',
      ),
      isTrue,
    );
  });

  test('a student is held back while the board is restricted', () {
    expect(
      canDriveSharedBoard(
        seatRole: 'ucenik',
        accountRole: 'korisnik',
        boardControl: 'trainer_only',
      ),
      isFalse,
    );
    expect(
      canDriveSharedBoard(
        seatRole: 'ucenik',
        accountRole: 'korisnik',
        boardControl: 'host_only',
      ),
      isFalse,
    );
  });

  test('an unrestricted board opens up to every seat', () {
    expect(
      canDriveSharedBoard(
        seatRole: 'ucenik',
        accountRole: 'korisnik',
        boardControl: 'unrestricted',
      ),
      isTrue,
    );
  });

  test('an account-level trainer is trusted in any room', () {
    expect(
      canDriveSharedBoard(
        seatRole: 'ucenik',
        accountRole: 'trener',
        boardControl: 'trainer_only',
      ),
      isTrue,
    );
  });

  test('the local STUDIO board is never restricted', () {
    // It has no room to broadcast to, so board_control has nothing to protect.
    expect(
      canDriveSharedBoard(
        seatRole: null,
        accountRole: 'korisnik',
        boardControl: 'trainer_only',
        isStudio: true,
      ),
      isTrue,
    );
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
