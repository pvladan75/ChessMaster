import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/board_control_rules.dart';

void main() {
  test('the room host may navigate even though their account is not a trainer', () {
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
}
