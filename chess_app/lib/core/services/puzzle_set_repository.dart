// puzzle_set_repository.dart — the one place that answers „which puzzle sets
// does this account have".
//
// Added 21.9.2026. Until then the answer came from
// `LocalPuzzleSetStorageService` alone, which reads `SharedPreferences`, so
// the owner's sets were on the machine that had run „Review entire game" and
// nowhere else. On Windows he saw them; on the phone, under the same account,
// the shelf was empty. Reported as a display fault and it was a storage one.
//
// The device store keeps its name and its job — it is the **cache** now, and
// the thing that answers when the server cannot be reached. This class owns
// the rule about which of the two wins, so no screen has to (rule 12).
//
// The rule, said once:
//
//  * The server is the account's list. What it returns is what the reader has.
//  * A server that **cannot be reached** is not an empty account. `list()`
//    answers null there rather than `[]`, and the device's own sets are shown
//    instead — a reader offline still gets what they made here.
//  * Sets a device made before the server knew about them are **lifted** on
//    the first reachable load, by id. The write is an upsert, so this runs on
//    every device and every start without ever making a second copy.

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/core/services/puzzle_set_api_service.dart';
import 'package:chess_app/services/app_logger.dart';

class PuzzleSetRepository {
  PuzzleSetRepository({
    required PuzzleSetApiService api,
    LocalPuzzleSetStorageService? local,
  })  : _api = api,
        _local = local ?? LocalPuzzleSetStorageService.instance;

  final PuzzleSetApiService _api;
  final LocalPuzzleSetStorageService _local;

  /// What this account has, newest first.
  Future<List<SavedPuzzleSet>> load() async {
    final remote = await _api.list();
    final onDevice = await _local.loadSets();

    // Offline, or a server that refused. The device's own sets are the
    // honest answer — better than an empty shelf that says the work is gone.
    if (remote == null) return onDevice;

    final known = remote.map((s) => s.id).toSet();
    final lifted = <SavedPuzzleSet>[];
    for (final set in onDevice) {
      if (known.contains(set.id)) continue;
      if (set.puzzles.isEmpty) continue; // the server refuses these anyway
      if (await _api.save(set)) {
        lifted.add(set);
      } else {
        // Kept on the device and tried again next time rather than dropped.
        AppLogger.log('[PuzzleSets] Could not lift "${set.title}" yet.');
      }
    }

    final all = [...remote, ...lifted]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _local.replaceAll(all);
    return all;
  }

  /// Saves a new set to the account, and to this device so it survives a
  /// server that is not there.
  ///
  /// Written to the device **first**: the extraction that produced it cost an
  /// engine pass over a whole game, and losing that to a refused request
  /// would be the worst outcome of the three.
  Future<SavedPuzzleSet> save({
    required String title,
    required List<LocalPuzzle> puzzles,
  }) async {
    final set = await _local.saveSet(title: title, puzzles: puzzles);
    await _api.save(set);
    return set;
  }

  /// Removes a set from the account and from this device, and says whether
  /// it did.
  ///
  /// **The device copy goes only once the account has let go of it.** Until
  /// 21.9.2026 it went whatever the server answered, so a refused delete read
  /// as done and the set was back on the next reachable load — a step that
  /// reports success and fails one load later. A refusal now leaves both
  /// copies as they were and answers false, and the caller says so.
  Future<bool> delete(String id) async {
    if (!await _api.delete(id)) return false;
    await _local.deleteSet(id);
    return true;
  }
}
