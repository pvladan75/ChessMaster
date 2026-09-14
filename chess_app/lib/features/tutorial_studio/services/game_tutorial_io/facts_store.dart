/// The engine's answers for a game, kept on the device — phase 2 of
/// `docs/PLAN-SKELET.md`, rule 4.
///
/// A build of a game is one to eight minutes of every core the machine has.
/// Keeping the answers means an interrupted build resumes where it stopped,
/// and a second tutorial of the same game — the other mode, another try at the
/// words — costs no engine time at all.
///
/// **What an answer belongs to is the key**: the game (its starting position
/// and its moves), the depth and the engine. The engine is named by the size and
/// the modification time of its binary, because phase 0 showed the answers are a
/// function of exactly the binary: the same file gave byte-identical facts, and a
/// different build of Stockfish would not.
///
/// **It is a cache and is treated as one.** A file that cannot be read — torn
/// by a crash, written by another version — is an empty store, not an error:
/// the price of ignoring it is one more build, and the price of trusting it is
/// a tutorial made of somebody else's answers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

const int _storeVersion = 1;

/// The name an engine binary's answers are kept under.
Future<String> engineIdentity(String path) async {
  final stat = await File(path).stat();
  if (stat.type == FileSystemEntityType.notFound) {
    throw FileSystemException('The engine is not there', path);
  }
  return '${stat.size}-${stat.modified.toUtc().millisecondsSinceEpoch}';
}

/// The key of one game at one depth by one engine.
String factsKey({
  required String startFen,
  required List<String> uciMoves,
  required int depth,
  required String engine,
}) =>
    sha1
        .convert(utf8.encode('$startFen|${uciMoves.join(' ')}|$depth|$engine'))
        .toString();

/// The store under the app's support directory.
GameFactsStore deviceFactsStore() => GameFactsStore(() async {
      final support = await getApplicationSupportDirectory();
      return Directory('${support.path}${Platform.pathSeparator}game_facts');
    });

class GameFactsStore {
  GameFactsStore(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> _file(String key) async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$key.json');
  }

  /// The answers kept under [key], by position; empty when there are none or
  /// the file cannot be trusted.
  Future<Map<String, List<Map<String, dynamic>>>> load(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return {};
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map ||
          data['version'] != _storeVersion ||
          data['key'] != key ||
          data['answers'] is! Map) {
        return {};
      }
      return {
        for (final entry in (data['answers'] as Map).entries)
          entry.key as String: [
            for (final c in entry.value as List)
              Map<String, dynamic>.from(c as Map)
          ]
      };
    } catch (_) {
      return {};
    }
  }

  /// Keeps answers under [key] as they arrive, starting from [initial].
  GameFactsRecorder recorder(String key,
          {Map<String, List<Map<String, dynamic>>> initial = const {}}) =>
      GameFactsRecorder._(this, key, {...initial});
}

/// Writes a build's answers as they come, one write at a time.
class GameFactsRecorder {
  GameFactsRecorder._(this._store, this._key, this._answers);

  final GameFactsStore _store;
  final String _key;
  final Map<String, List<Map<String, dynamic>>> _answers;

  Future<void> _chain = Future.value();
  bool _queued = false;

  /// Records one answer and schedules a write. Answers that arrive while a
  /// write is running are carried by the next one, so eight workers finishing
  /// together cost two writes, not eight.
  void add(String fen, List<Map<String, dynamic>> candidates) {
    _answers[fen] = candidates;
    if (_queued) return;
    _queued = true;
    _chain = _chain.then((_) {
      _queued = false;
      return _write();
    });
  }

  /// Waits until everything recorded so far is on disk.
  Future<void> flush() => _chain;

  Future<void> _write() async {
    final file = await _store._file(_key);
    await file.parent.create(recursive: true);
    // Written beside the file and renamed onto it: a crash in the middle
    // leaves the previous version whole, never half of this one.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode({
      'version': _storeVersion,
      'key': _key,
      'answers': _answers,
    }));
    await temporary.rename(file.path);
  }
}
