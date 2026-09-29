import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/password_store.dart';

/// What became of the password a sign-in offered to keep.
enum PasswordKeeping {
  /// Nothing to keep: no password was offered (Google), „Remember me" was not
  /// ticked, or this platform keeps none.
  notOffered,

  /// Kept in the platform's store.
  kept,

  /// The store refused it. The sign-in went through regardless, and the
  /// screen says the password was not saved.
  failed,
}

/// The addresses this device has signed in with under „Remember me", and —
/// where the platform has a safe place for one — each one's password
/// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, §4.1).
///
/// One home for both, because they are read together: the sign-in form fills
/// an address and its password as a pair, and a password must never be sent
/// with an address it was not kept for.
///
/// The addresses, most recent first, live in `SharedPreferences` — an address
/// is not a secret, and the form has offered the last one since 27.8.2026.
/// The passwords live only in [PasswordStore], never beside the addresses.
///
/// Two spellings of one address are one entry (compared without case), as
/// they are in the Windows store underneath; the list shows the spelling
/// used last.
class SavedSignIns extends ChangeNotifier {
  SavedSignIns._();
  static final SavedSignIns instance = SavedSignIns._();

  static const _addressesKey = 'remembered_emails';

  /// Where the single remembered address was kept before this list existed.
  /// Read once, moved into the list, and removed.
  static const _legacyKey = 'last_email';

  PasswordStore? _store = PasswordStore.forPlatform();
  List<String> _addresses = const [];

  /// Puts a fake store in place of the platform's; null means a platform
  /// that keeps no passwords, which is also what every test run gets unless
  /// it asks (`PasswordStore.forPlatform`).
  @visibleForTesting
  void debugUseStore(PasswordStore? store) => _store = store;

  /// Whether this platform keeps passwords at all.
  bool get keepsPasswords => _store != null;

  /// Where they are kept, for the sentence under „Remember me".
  String? get storeName => _store?.name;

  /// The remembered addresses, most recent first.
  List<String> get addresses => List.unmodifiable(_addresses);

  /// The address the form opens with.
  String? get last => _addresses.isEmpty ? null : _addresses.first;

  static String _key(String address) => address.trim().toLowerCase();

  bool isRemembered(String address) {
    final key = _key(address);
    return key.isNotEmpty && _addresses.any((a) => _key(a) == key);
  }

  /// Reads the list. Called by `SessionService.init`, before the first frame.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_addressesKey) ?? <String>[];
    final legacy = prefs.getString(_legacyKey);
    if (legacy != null) {
      if (legacy.trim().isNotEmpty &&
          !list.any((a) => _key(a) == _key(legacy))) {
        list.insert(0, legacy.trim());
      }
      await prefs.setStringList(_addressesKey, list);
      await prefs.remove(_legacyKey);
    }
    _addresses = list;
    notifyListeners();
  }

  /// The password kept for [address], or null.
  ///
  /// Only for an address on the list: an address the person has typed but
  /// never signed in with under „Remember me" has nothing kept, whatever the
  /// store might hold. A store that cannot be read answers null and says so
  /// in the log — the cost is that the person types their password, which is
  /// what they would do without this feature.
  String? passwordFor(String address) {
    final store = _store;
    if (store == null || !isRemembered(address)) return null;
    try {
      return store.read(address);
    } catch (e) {
      AppLogger.log('[SavedSignIns] could not read a kept password: $e');
      return null;
    }
  }

  bool hasPassword(String address) => passwordFor(address) != null;

  /// Puts [address] first on the list and, when [password] is given and the
  /// platform has a store, keeps it.
  ///
  /// Called only after the server has accepted the sign-in, so a wrong
  /// password is never kept. A null [password] (a Google sign-in) leaves any
  /// kept one where it is.
  Future<PasswordKeeping> remember(String address, {String? password}) async {
    final clean = address.trim();
    if (clean.isEmpty) return PasswordKeeping.notOffered;
    _addresses = [
      clean,
      ..._addresses.where((a) => _key(a) != _key(clean)),
    ];
    await _saveList();

    var keeping = PasswordKeeping.notOffered;
    final store = _store;
    if (store != null && password != null && password.isNotEmpty) {
      try {
        store.write(clean, password);
        keeping = PasswordKeeping.kept;
      } catch (e) {
        AppLogger.log('[SavedSignIns] could not keep a password: $e');
        keeping = PasswordKeeping.failed;
      }
    }
    notifyListeners();
    return keeping;
  }

  /// Forgets [address] and its password: „Remember me" left unticked, × in
  /// the form's list, „Forget" in Settings, or an account that is gone.
  ///
  /// False when the store would not let go of the password. The address is
  /// off the list either way, but a „Forget" that left the password behind
  /// must not be reported as done — the caller says it was not.
  Future<bool> forget(String address) async {
    _addresses = _addresses.where((a) => _key(a) != _key(address)).toList();
    await _saveList();
    final gone = _deletePassword(address);
    notifyListeners();
    return gone;
  }

  /// Forgets only the password, keeping the address: the server refused the
  /// kept one, so it is wrong, but the address the person uses is not.
  /// False as for [forget].
  bool forgetPassword(String address) {
    final gone = _deletePassword(address);
    notifyListeners();
    return gone;
  }

  bool _deletePassword(String address) {
    try {
      _store?.delete(address);
      return true;
    } catch (e) {
      AppLogger.log('[SavedSignIns] could not forget a kept password: $e');
      return false;
    }
  }

  Future<void> _saveList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_addressesKey, _addresses);
  }
}
