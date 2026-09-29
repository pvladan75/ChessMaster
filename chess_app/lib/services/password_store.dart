import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:chess_app/services/windows_credential_store.dart';

/// A place the operating system keeps a password safe for one person, if the
/// platform has one the app can write to.
///
/// Windows has one the app can reach — Credential Manager — and no password
/// autofill for desktop programs, so a password kept for „Remember me" goes
/// there (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D3). Android has its own
/// password manager, which the sign-in form already speaks to through its
/// autofill hints, so the app keeps nothing there (D4) and this is null.
///
/// Never `SharedPreferences`: on Windows that is a plain file in the user's
/// profile, readable by anything running as them, and most accounts in this
/// app belong to minors.
abstract interface class PasswordStore {
  /// Where the password goes, in the words the person will find it under —
  /// the sentence under „Remember me" names it.
  String get name;

  /// The password kept for [address], or null when there is none.
  ///
  /// Throws when the store could not be read. „Could not read" is not „there
  /// is none", and the caller decides what to do with the difference.
  String? read(String address);

  /// Keeps [password] for [address], replacing any kept before. Throws when
  /// it could not.
  void write(String address, String password);

  /// Forgets the password kept for [address]. Forgetting one that is not
  /// there is not an error.
  void delete(String address);

  /// The store this platform has, or null where the app keeps no passwords.
  static PasswordStore? forPlatform() {
    if (kIsWeb || !Platform.isWindows) return null;
    // A widget test on the workstation is a Windows process too, and a
    // sign-in it drives must never land in the owner's real Credential
    // Manager. The one test that means to reach it builds the store itself.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    return const WindowsCredentialStore();
  }
}
