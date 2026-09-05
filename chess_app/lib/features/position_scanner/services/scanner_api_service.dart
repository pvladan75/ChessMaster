import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

import '../models/scanned_position.dart';

/// Outcome of a scan, with the server's own words when it refused.
class ScanOutcome {
  const ScanOutcome({this.result, this.error, this.code});

  final ScanResult? result;
  final String? error;

  /// Worth telling apart in the UI, because each asks the trainer for
  /// something different: `range_too_large` asks for fewer pages,
  /// `file_too_large` for a smaller file, and the three unreadable codes
  /// (`no_text`, `no_diagram_text`, `unknown_font`) for a different book —
  /// all but the last, which asks for a glyph map and nothing from the trainer.
  final String? code;

  bool get ok => result != null;
}

/// The sentence a trainer reads when a scan refuses.
///
/// Three unreadable books used to share one message — "the diagrams use a font
/// we cannot read yet" — and it was true of none of the three tried on
/// 5.9.2026: two were image scans with no text at all, and one had an OCR text
/// layer with picture diagrams. Naming the wrong cause is worse than naming
/// none, because it sends the reader looking for a font that is not there.
///
/// Anything else keeps the server's own words: it knows numbers this screen
/// does not, such as the size ceiling a book just went over.
String scanFailureMessage(ScanOutcome outcome) {
  switch (outcome.code) {
    case 'no_text':
      return 'Ova knjiga je skenirana kao slika — u njoj nema teksta. '
          'Skener čita samo knjige u kojima su dijagrami složeni šahovskim fontom.';
    case 'no_diagram_text':
      return 'Na tim stranama ima teksta, ali su dijagrami slike ili crteži. '
          'Skener čita samo dijagrame složene šahovskim fontom.';
    case 'unknown_font':
      return 'Dijagrami u ovoj knjizi koriste font koji još ne umemo da čitamo.';
    default:
      return outcome.error ?? 'Skeniranje nije uspelo.';
  }
}

/// What a confirmation actually did.
///
/// Re-scanning an overlapping page range is normal, so "saved" alone would be a
/// lie: some positions are new, some only fill a gap in a row that already
/// exists, and some were already complete. Saying which is the difference
/// between a trainer trusting the count and wondering where things went.
class SaveOutcome {
  const SaveOutcome({
    this.saved = 0,
    this.filled = 0,
    this.unchanged = 0,
    this.conflicts = 0,
    this.rejected = 0,
    this.error,
  });

  final int saved;
  final int filled;
  final int unchanged;

  /// Positions where the book's solution will not play in the position already
  /// stored — the two disagree about something real, usually whose move it is.
  final int conflicts;
  final int rejected;
  final String? error;

  bool get ok => error == null;

  /// One line a person can read, naming only what actually happened.
  String get summary {
    final parts = <String>[];
    if (saved > 0) parts.add('novih $saved');
    if (filled > 0) parts.add('dopunjeno $filled');
    if (unchanged > 0) parts.add('već postojalo $unchanged');
    if (conflicts > 0) parts.add('neslaganja $conflicts');
    if (rejected > 0) parts.add('odbijeno $rejected');
    return parts.isEmpty ? 'ništa nije promenjeno' : parts.join(', ');
  }
}

class ScannerApiService {
  ScannerApiService({required this.authToken});

  final String authToken;

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  String _errorFrom(String body, String fallback) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['error']?.toString() ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  String? _codeFrom(String body) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['code']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Sends one document and gets candidates back.
  ///
  /// The file is uploaded per scan and never stored server-side, so re-scanning
  /// a different page range means sending it again. That is the deliberate
  /// trade: the server keeps no copy of anyone's book.
  Future<ScanOutcome> scan({
    required String filePath,
    required String fileName,
    required int fromPage,
    required int toPage,
    int? solutionsFrom,
    int? solutionsTo,
  }) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$backendUrl/scans'));
      if (authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.fields['fromPage'] = '$fromPage';
      request.fields['toPage'] = '$toPage';
      if (solutionsFrom != null) {
        request.fields['solutionsFrom'] = '$solutionsFrom';
      }
      if (solutionsTo != null) {
        request.fields['solutionsTo'] = '$solutionsTo';
      }
      request.files.add(await http.MultipartFile.fromPath('document', filePath,
          filename: fileName));

      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return ScanOutcome(
          result: ScanResult.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>),
        );
      }
      return ScanOutcome(
        error: _errorFrom(
            response.body, 'Skeniranje nije uspelo (${response.statusCode}).'),
        code: _codeFrom(response.body),
      );
    } catch (e) {
      AppLogger.log('Scan failed: $e', name: 'PositionScanner');
      return const ScanOutcome(error: 'Nije moguće doći do servera.');
    }
  }

  Future<SaveOutcome> confirm({
    required String sourceTitle,
    required List<ScannedPosition> positions,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/scans/confirm'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'sourceTitle': sourceTitle,
              'positions': positions.map((p) => p.toConfirmJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return SaveOutcome(
          saved: (body['saved'] as num?)?.toInt() ?? 0,
          filled: (body['filled'] as num?)?.toInt() ?? 0,
          unchanged: (body['unchanged'] as num?)?.toInt() ?? 0,
          conflicts: (body['conflicts'] as List?)?.length ?? 0,
          rejected: (body['rejected'] as List?)?.length ?? 0,
        );
      }
      return SaveOutcome(
          error: _errorFrom(
              response.body, 'Čuvanje nije uspelo (${response.statusCode}).'));
    } catch (e) {
      AppLogger.log('Confirm failed: $e', name: 'PositionScanner');
      return const SaveOutcome(error: 'Nije moguće doći do servera.');
    }
  }

  /// Everything this trainer has kept. Returns null when the server could not
  /// be reached — an empty list means "none saved", and the two must not look
  /// the same on screen.
  Future<List<SavedPosition>?> listSaved() async {
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/scans/puzzles'), headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      return (jsonDecode(response.body) as List)
          .map((e) => SavedPosition.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.log('List saved failed: $e', name: 'PositionScanner');
      return null;
    }
  }

  /// Settles whose move it is, and returns the rewritten FEN.
  ///
  /// The server does the rewriting: the en passant square belongs to the other
  /// side's last move and has to go with the change, and the result is checked
  /// before it is stored. Returns null if the server refused — which it will if
  /// that side cannot be the one to move in this position.
  Future<String?> setSideToMove(String puzzleId, String side) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$backendUrl/scans/puzzles/$puzzleId'),
            headers: _jsonHeaders,
            body: jsonEncode({'sideToMove': side}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      return (jsonDecode(response.body) as Map<String, dynamic>)['fen']
          ?.toString();
    } catch (e) {
      AppLogger.log('Set side failed: $e', name: 'PositionScanner');
      return null;
    }
  }

  /// Saves the task text a trainer wrote for one position.
  ///
  /// Sent on its own, never alongside a side change: they are different edits
  /// and the server tells them apart by which field arrives.
  Future<bool> setInstruction(String puzzleId, String instruction) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$backendUrl/scans/puzzles/$puzzleId'),
            headers: _jsonHeaders,
            body: jsonEncode({'instruction': instruction}),
          )
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.log('Set instruction failed: $e', name: 'PositionScanner');
      return false;
    }
  }

  Future<bool> deleteSaved(String puzzleId) async {
    try {
      final response = await http
          .delete(Uri.parse('$backendUrl/scans/puzzles/$puzzleId'),
              headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.log('Delete saved failed: $e', name: 'PositionScanner');
      return false;
    }
  }
}
