import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chess_app/services/app_logger.dart';

enum ChessPlatform { lichess, chessCom }

/// Thrown for anything the caller should show to the user as a message,
/// as opposed to a bug — a typo'd username or an empty history are the
/// common case, not exceptional.
class ChessImportException implements Exception {
  final String message;
  ChessImportException(this.message);
  @override
  String toString() => message;
}

/// Fetches a player's recent games from Lichess or Chess.com as a raw PGN
/// blob, ready for [MoveTree.splitGames] the same way a pasted multi-game
/// PGN file already is — no separate parsing path needed.
class ChessPlatformImportService {
  ChessPlatformImportService._();
  static final ChessPlatformImportService instance =
      ChessPlatformImportService._();

  static const _timeout = Duration(seconds: 15);

  // Lichess silently serves a fake 404 page to requests carrying no
  // recognisable User-Agent (curl's default included) rather than answering
  // them — a bot-filter on this endpoint specifically, discovered by testing
  // against the live API. Chess.com does not require this, but sending it
  // anyway matches both platforms' published API etiquette.
  static const _userAgent = 'ChessCoach/1.0';

  Future<String> fetchRecentGames(ChessPlatform platform, String username,
      {int max = 20}) {
    final name = username.trim();
    if (name.isEmpty) {
      throw ChessImportException('Unesite korisničko ime.');
    }
    switch (platform) {
      case ChessPlatform.lichess:
        return _fetchLichess(name, max);
      case ChessPlatform.chessCom:
        return _fetchChessCom(name, max);
    }
  }

  /// One call returns PGN text directly — games are separated by a blank
  /// line, the same shape [MoveTree.splitGames] already expects.
  Future<String> _fetchLichess(String username, int max) async {
    final uri = Uri.parse(
      'https://lichess.org/api/games/user/$username'
      '?max=$max&pgnInJson=false&opening=true&clocks=false&evals=false',
    );
    http.Response res;
    try {
      res = await http.get(
        uri,
        headers: const {
          'Accept': 'application/x-chess-pgn',
          'User-Agent': _userAgent,
        },
      ).timeout(_timeout);
    } catch (e) {
      AppLogger.log('[ChessPlatformImport] Lichess fetch failed: $e');
      throw ChessImportException(
          'Nema veze sa Lichess-om. Proverite internet konekciju.');
    }

    if (res.statusCode == 404) {
      throw ChessImportException(
          'Korisnik "$username" ne postoji na Lichess-u.');
    }
    if (res.statusCode == 429) {
      throw ChessImportException(
          'Lichess trenutno ograničava zahteve. Pokušajte ponovo za koji trenutak.');
    }
    if (res.statusCode != 200) {
      throw ChessImportException(
          'Lichess je vratio grešku (${res.statusCode}).');
    }
    final pgn = res.body.trim();
    if (pgn.isEmpty) {
      throw ChessImportException(
          '"$username" nema odigranih partija na Lichess-u.');
    }
    return pgn;
  }

  /// Chess.com has no "last N games" endpoint: the archive list gives one URL
  /// per calendar month, so this walks backward from the most recent month
  /// collecting games — usually the newest archive alone already has enough.
  Future<String> _fetchChessCom(String username, int max) async {
    final lower = username.toLowerCase();
    final archivesUri =
        Uri.parse('https://api.chess.com/pub/player/$lower/games/archives');

    http.Response archivesRes;
    try {
      archivesRes = await http.get(archivesUri,
          headers: const {'User-Agent': _userAgent}).timeout(_timeout);
    } catch (e) {
      AppLogger.log(
          '[ChessPlatformImport] Chess.com archives fetch failed: $e');
      throw ChessImportException(
          'Nema veze sa Chess.com-om. Proverite internet konekciju.');
    }

    if (archivesRes.statusCode == 404) {
      throw ChessImportException(
          'Korisnik "$username" ne postoji na Chess.com-u.');
    }
    if (archivesRes.statusCode != 200) {
      throw ChessImportException(
          'Chess.com je vratio grešku (${archivesRes.statusCode}).');
    }

    List<dynamic> archiveUrls;
    try {
      archiveUrls = (jsonDecode(archivesRes.body)
          as Map<String, dynamic>)['archives'] as List<dynamic>;
    } catch (e) {
      throw ChessImportException('Neočekivan odgovor sa Chess.com-a.');
    }

    if (archiveUrls.isEmpty) {
      throw ChessImportException(
          '"$username" nema odigranih partija na Chess.com-u.');
    }

    final pgns = <String>[];
    // Most recent month first, stop once there is enough.
    for (var i = archiveUrls.length - 1; i >= 0 && pgns.length < max; i--) {
      final monthUri = Uri.parse(archiveUrls[i] as String);
      http.Response monthRes;
      try {
        monthRes = await http.get(monthUri,
            headers: const {'User-Agent': _userAgent}).timeout(_timeout);
      } catch (e) {
        AppLogger.log('[ChessPlatformImport] Chess.com month fetch failed: $e');
        continue; // one bad month should not fail the whole import
      }
      if (monthRes.statusCode != 200) continue;

      List<dynamic> games;
      try {
        games = (jsonDecode(monthRes.body) as Map<String, dynamic>)['games']
            as List<dynamic>;
      } catch (e) {
        continue;
      }

      // Newest games are at the end of each month's list.
      for (var g = games.length - 1; g >= 0 && pgns.length < max; g--) {
        final pgn = (games[g] as Map<String, dynamic>)['pgn'] as String?;
        if (pgn != null && pgn.trim().isNotEmpty) {
          pgns.add(pgn.trim());
        }
      }
    }

    if (pgns.isEmpty) {
      throw ChessImportException('Nije nađena nijedna partija za "$username".');
    }
    return pgns.join('\n\n');
  }
}
