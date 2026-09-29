import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import 'package:chess_app/services/password_store.dart';

/// Windows Credential Manager, where „Remember me" keeps a password on
/// Windows (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D3).
///
/// Why here and not somewhere of the app's own: Windows encrypts the entry
/// for the signed-in Windows user (DPAPI), and the person can see it and
/// remove it themselves in *Control Panel → Credential Manager → Windows
/// Credentials*, under the name [prefix] + address. Nothing the app writes
/// is hidden from the person it belongs to.
///
/// What it does not protect against, said plainly because it is the price of
/// the feature: any program running as the same Windows user can read the
/// entry, as it can a browser's saved passwords.
///
/// One generic credential per address, persisted for this computer and this
/// Windows user only (`CRED_PERSIST_LOCAL_MACHINE` — never roaming with a
/// domain profile). Windows compares target names without regard to case,
/// so the address is lower-cased in the name: two spellings of one address
/// are one entry, deliberately rather than by accident.
class WindowsCredentialStore implements PasswordStore {
  const WindowsCredentialStore({this.prefix = 'Mislisha/'});

  /// What every entry's name starts with. Only the test that makes a real
  /// round trip passes another, so it can never touch the owner's entries.
  final String prefix;

  /// `CRED_MAX_CREDENTIAL_BLOB_SIZE`: 5 × 512 bytes.
  static const _maxBlobBytes = 2560;

  @override
  String get name => 'Windows Credential Manager';

  String _target(String address) => '$prefix${address.trim().toLowerCase()}';

  /// Asks for the last error once, and throws the answer away, before every
  /// store call.
  ///
  /// `package:win32` looks each function up the first time it is called, and
  /// looking one up is itself a Windows call that sets the last error to 0.
  /// So the first `GetLastError` after a failed `CredRead` answered „the
  /// operation completed successfully", and a password that was never kept
  /// read as an error instead of as none — found by
  /// `windows_credential_store_test` on its first run, 29.9.2026, and only
  /// in its first case, because by the second the lookup had been done.
  /// Resolved before the store call, nothing runs between the failure and
  /// the question.
  static void _resolveLastError() => GetLastError();

  @override
  String? read(String address) {
    _resolveLastError();
    return using((arena) {
      final target = _target(address).toNativeUtf16(allocator: arena);
      final found = arena<Pointer<CREDENTIAL>>();
      if (CredRead(target, CRED_TYPE_GENERIC, 0, found) == FALSE) {
        final error = GetLastError();
        if (error == ERROR_NOT_FOUND) return null;
        throw WindowsException(HRESULT_FROM_WIN32(error));
      }
      try {
        final credential = found.value.ref;
        // Written by [write] as UTF-16, which is also what Windows' own
        // dialogs write for a generic credential.
        final units = credential.CredentialBlobSize ~/ 2;
        return String.fromCharCodes(
            credential.CredentialBlob.cast<Uint16>().asTypedList(units));
      } finally {
        CredFree(found.value);
      }
    });
  }

  @override
  void write(String address, String password) {
    final units = password.codeUnits;
    if (units.length * 2 > _maxBlobBytes) {
      throw ArgumentError('A password this long cannot be kept here.');
    }
    _resolveLastError();
    using((arena) {
      final blob = arena<Uint16>(units.isEmpty ? 1 : units.length);
      final view = blob.asTypedList(units.length)..setAll(0, units);
      try {
        final credential = arena<CREDENTIAL>();
        credential.ref
          ..Flags = 0
          ..Type = CRED_TYPE_GENERIC
          ..TargetName = _target(address).toNativeUtf16(allocator: arena)
          ..Comment = 'Mislisha — Remember me'.toNativeUtf16(allocator: arena)
          ..CredentialBlobSize = units.length * 2
          ..CredentialBlob = blob.cast<Uint8>()
          ..Persist = CRED_PERSIST_LOCAL_MACHINE
          ..AttributeCount = 0
          ..Attributes = nullptr
          ..TargetAlias = nullptr
          ..UserName = address.trim().toNativeUtf16(allocator: arena);
        if (CredWrite(credential, 0) == FALSE) {
          throw WindowsException(HRESULT_FROM_WIN32(GetLastError()));
        }
      } finally {
        // The arena frees without clearing; a password should not outlive
        // the call in memory the process hands back.
        view.fillRange(0, view.length, 0);
      }
    });
  }

  @override
  void delete(String address) {
    _resolveLastError();
    using((arena) {
      final target = _target(address).toNativeUtf16(allocator: arena);
      if (CredDelete(target, CRED_TYPE_GENERIC, 0) == FALSE) {
        final error = GetLastError();
        if (error == ERROR_NOT_FOUND) return;
        throw WindowsException(HRESULT_FROM_WIN32(error));
      }
    });
  }
}
