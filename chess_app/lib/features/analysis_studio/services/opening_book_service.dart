import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/services/app_logger.dart';

class OpeningBookEntry {
  final String eco;
  final String name;
  final String pgn;

  OpeningBookEntry({required this.eco, required this.name, required this.pgn});

  /// The opening this line belongs to: everything before the colon in the ECO
  /// name. "Sicilian Defense: Najdorf Variation, English Attack" is a line of
  /// the **Sicilian Defense**, and that is the level somebody browses at — a
  /// flat list of 3800 names is a list nobody reads.
  String get family {
    final at = name.indexOf(':');
    return at < 0 ? name.trim() : name.substring(0, at).trim();
  }

  /// What distinguishes this line inside its opening — the rest of the name.
  ///
  /// The opening's own main line has nothing after the colon, and it is named
  /// rather than left blank: an empty row in a list of variations reads as a
  /// bug, and "the opening itself" is a real choice somebody makes.
  String get variation {
    final at = name.indexOf(':');
    final rest = at < 0 ? '' : name.substring(at + 1).trim();
    return rest.isEmpty ? 'Osnovna linija' : rest;
  }
}

class _ParseResult {
  final List<OpeningBookEntry> entries;
  final Map<String, OpeningBookEntry> fenIndex;

  _ParseResult(this.entries, this.fenIndex);
}

_ParseResult _parseEcoOpeningsInBackground(String rawJson) {
  final list = jsonDecode(rawJson) as List;
  final entries = list
      .whereType<Map<String, dynamic>>()
      .map((e) => OpeningBookEntry(
            eco: e['eco'] as String? ?? '',
            name: e['name'] as String? ?? '',
            pgn: e['pgn'] as String? ?? '',
          ))
      .toList();

  final Map<String, OpeningBookEntry> fenIndex = {};
  for (final entry in entries) {
    try {
      final game = chess.Chess();
      if (!game.load_pgn(entry.pgn)) continue;
      final fenParts = game.fen.trim().split(' ');
      final normalized = fenParts.take(4).join(' ');
      fenIndex[normalized] = entry;
    } catch (_) {
      // Skip malformed lines
    }
  }

  return _ParseResult(entries, fenIndex);
}

/// Local, offline ECO opening/variation database (lichess-org/chess-openings,
/// ~3800 named lines) bundled as an asset. Used to name any reachable
/// position without needing the token-gated Lichess Opening Explorer.
class OpeningBookService {
  OpeningBookService._();
  static final OpeningBookService instance = OpeningBookService._();

  List<OpeningBookEntry> _entries = [];
  final Map<String, OpeningBookEntry> _fenIndex = {};
  bool _loaded = false;
  Future<void>? _loadingFuture;

  bool get isLoaded => _loaded;

  static String normalizeFen(String fen) {
    final parts = fen.trim().split(' ');
    return parts.take(4).join(' ');
  }

  Future<void> ensureLoaded() {
    return _loadingFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/eco_openings.json');
      final result = await compute(_parseEcoOpeningsInBackground, raw);
      _entries = result.entries;
      _fenIndex.addAll(result.fenIndex);
      _loaded = true;
      AppLogger.log(
          '[OpeningBook] 📚 Loaded ${_entries.length} openings (${_fenIndex.length} indexed positions)');
    } catch (e) {
      AppLogger.log('[OpeningBook] ❌ Failed to load ECO dataset: $e');
      _loaded = false;
    }
  }

  /// Returns the named opening/variation whose line ends exactly at [fen], if any.
  OpeningBookEntry? lookupByFen(String fen) {
    if (!_loaded) return null;
    return _fenIndex[normalizeFen(fen)];
  }

  /// Every opening in the book, by name, alphabetically.
  ///
  /// This is what makes the picker usable by somebody who cannot spell the
  /// thing they want: the search field answers "what is it called", and this
  /// answers "what is there". A repertoire starts by choosing an opening, and
  /// asking a trainer to type a name they are trying to look up is the same
  /// mistake as asking a child to play out seven moves to say "Smith-Morra".
  List<String> families() {
    if (!_loaded) return const [];
    final names = <String>{for (final entry in _entries) entry.family};
    final list = names.toList()..sort();
    return list;
  }

  /// The lines of one opening, shortest first.
  ///
  /// Shortest first because the shortest line *is* the opening — the main line
  /// somebody means when they name it — and the long ones are the branches off
  /// it. Alphabetical would open the list on whatever begins with A.
  List<OpeningBookEntry> variationsOf(String family) {
    if (!_loaded) return const [];
    final lines = _entries.where((e) => e.family == family).toList()
      ..sort((a, b) {
        final lenDiff = a.pgn.length.compareTo(b.pgn.length);
        if (lenDiff != 0) return lenDiff;
        return a.name.compareTo(b.name);
      });
    return lines;
  }

  /// Case-insensitive substring search over opening/variation names.
  List<OpeningBookEntry> search(String query, {int limit = 30}) {
    if (!_loaded) return [];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final matches =
        _entries.where((e) => e.name.toLowerCase().contains(q)).toList()
          ..sort((a, b) {
            final lenDiff = a.pgn.length.compareTo(b.pgn.length);
            if (lenDiff != 0) return lenDiff;
            return a.name.compareTo(b.name);
          });

    return matches.take(limit).toList();
  }
}
