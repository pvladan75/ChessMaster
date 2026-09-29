import 'package:chess_app/services/password_store.dart';

/// A [PasswordStore] in memory, standing in for Windows Credential Manager.
///
/// It compares addresses without case, as the real one does, and it can be
/// told to refuse — a store that throws is a case the app must survive
/// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md` §4.1: the sign-in never waits on
/// the password being kept).
class FakePasswordStore implements PasswordStore {
  final Map<String, String> kept = {};

  bool refuseWrite = false;
  bool refuseRead = false;
  bool refuseDelete = false;

  /// Every write, in order, as `address -> password`.
  final List<MapEntry<String, String>> writes = [];

  static String _key(String address) => address.trim().toLowerCase();

  @override
  String get name => 'Windows Credential Manager';

  @override
  String? read(String address) {
    if (refuseRead) throw StateError('the store would not read');
    return kept[_key(address)];
  }

  @override
  void write(String address, String password) {
    if (refuseWrite) throw StateError('the store would not write');
    writes.add(MapEntry(address, password));
    kept[_key(address)] = password;
  }

  @override
  void delete(String address) {
    if (refuseDelete) throw StateError('the store would not delete');
    kept.remove(_key(address));
  }
}
