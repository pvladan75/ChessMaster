import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';

import '../models/image_scan.dart';
import '../models/scanned_position.dart';

/// Outcome of a scan, with the server's own words when it refused.
class ScanOutcome {
  const ScanOutcome({this.result, this.error, this.code, this.details});

  final ScanResult? result;
  final String? error;

  /// What the server added to a refusal. `imageDiagrams` is the one read here:
  /// on `no_text` and `no_diagram_text` it counts the diagrams on those pages
  /// that are pictures, and more than none opens the image path.
  final Map<String, dynamic>? details;

  /// Diagrams on the scanned pages that are pictures, when the server counted.
  int get imageDiagrams => (details?['imageDiagrams'] as num?)?.toInt() ?? 0;

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
      return 'This book was scanned as an image, and no chess diagram was '
          'found in the pictures on those pages. Try other pages.';
    case 'no_diagram_text':
      return 'No diagram was found on those pages — neither in a chess font '
          'nor as a picture. Diagrams drawn with lines cannot be read yet.';
    case 'unknown_font':
      return 'The diagrams in this book use a font we cannot read yet.';
    default:
      return outcome.error ?? 'Scan failed.';
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
    if (saved > 0) parts.add('$saved new');
    if (filled > 0) parts.add('$filled updated');
    if (unchanged > 0) parts.add('$unchanged already existed');
    if (conflicts > 0) parts.add('$conflicts conflicts');
    if (rejected > 0) parts.add('$rejected rejected');
    return parts.isEmpty ? 'nothing changed' : parts.join(', ');
  }
}

/// The answer of `POST /scans/images`, with the server's words and code when
/// it refused — `too_many_boards` names the count and the ceiling itself.
class ImageScanOutcome {
  const ImageScanOutcome({this.result, this.error, this.code, this.details});

  final ImageScanResult? result;
  final String? error;
  final String? code;
  final Map<String, dynamic>? details;

  bool get ok => result != null;
}

/// A remembered calibration, read back. "The book has none" and "the server
/// could not be asked" are different answers: the first leads to calibrating,
/// the second to trying again, and neither may pose as the other.
class CalibrationLoad {
  const CalibrationLoad.found(this.boards, {this.absent = const []})
      : missing = false,
        error = null;
  const CalibrationLoad.missing()
      : boards = const [],
        absent = const [],
        missing = true,
        error = null;
  const CalibrationLoad.failed(this.error)
      : boards = const [],
        absent = const [],
        missing = false;

  final List<CalibrationBoard> boards;

  /// Pieces the trainer said the book never draws (phase 3e).
  final List<String> absent;
  final bool missing;
  final String? error;

  bool get found => error == null && !missing;
}

/// The SHA-256 of a book's file, as lowercase hex — how the account knows a
/// book again without the server ever keeping a page of it.
Future<String> bookHashOf(String filePath) async =>
    (await sha256.bind(File(filePath).openRead()).first).toString();

/// Whether this account already has a calibration for the book at
/// [filePath] — by the file's content, so a renamed copy is the same book.
/// False when there is none **and** when the server could not be asked: the
/// door then says what setting up means, which is never untrue.
Future<bool> bookIsCalibrated(ScannerApiService api, String filePath) async {
  try {
    final load = await api.loadCalibration(await bookHashOf(filePath));
    return load.error == null && !load.missing && load.boards.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class ScannerApiService {
  ScannerApiService({required this.authToken, http.Client? client})
      : _client = client;

  final String authToken;

  /// Null means one client shared by the process. Every request goes through
  /// here or through [_send] — a seam that some calls went round would let a
  /// test believe it saw every request (phase 3d: the save went past it).
  final http.Client? _client;

  /// The package's own client, for when none was injected — one per process,
  /// as `http.get` and friends use one per call.
  static final http.Client _shared = http.Client();

  Future<http.StreamedResponse> _send(http.BaseRequest request) =>
      (_client ?? _shared).send(request);

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

  Map<String, dynamic>? _detailsFrom(String body) {
    try {
      final details = (jsonDecode(body) as Map<String, dynamic>)['details'];
      return details is Map<String, dynamic> ? details : null;
    } catch (_) {
      return null;
    }
  }

  /// A book whose diagrams are pictures. Without [calibration] the answer is
  /// the boards found and a preview of each; with it, every other board read
  /// against those. The file is sent again each time — the server keeps none.
  Future<ImageScanOutcome> scanImages({
    required String filePath,
    required String fileName,
    required int fromPage,
    required int toPage,
    List<CalibrationBoard> calibration = const [],
  }) =>
      _images('/scans/images',
          filePath: filePath,
          fileName: fileName,
          fromPage: fromPage,
          toPage: toPage,
          calibration: calibration);

  /// The boards and previews of a page range, to choose calibration boards
  /// from. Its own route and limiter on the server: turning pages is not
  /// scanning, and counted as scanning it used up the account's scans
  /// (the owner, 23.9.2026).
  Future<ImageScanOutcome> browseImages({
    required String filePath,
    required String fileName,
    required int fromPage,
    required int toPage,
  }) =>
      _images('/scans/images/browse',
          filePath: filePath,
          fileName: fileName,
          fromPage: fromPage,
          toPage: toPage);

  Future<ImageScanOutcome> _images(
    String path, {
    required String filePath,
    required String fileName,
    required int fromPage,
    required int toPage,
    List<CalibrationBoard> calibration = const [],
  }) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$backendUrl$path'));
      if (authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.fields['fromPage'] = '$fromPage';
      request.fields['toPage'] = '$toPage';
      if (calibration.isNotEmpty) {
        request.fields['calibration'] =
            jsonEncode(calibration.map((c) => c.toJson()).toList());
      }
      request.files.add(await http.MultipartFile.fromPath('document', filePath,
          filename: fileName));

      // Reading runs about half a second a board, 60 at most, on the server.
      final streamed = await _send(request).timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        return ImageScanOutcome(
          result: ImageScanResult.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>),
        );
      }
      return ImageScanOutcome(
        error: _errorFrom(response.body,
            'Reading the pictures failed (${response.statusCode}).'),
        code: _codeFrom(response.body),
        details: _detailsFrom(response.body),
      );
    } catch (e) {
      AppLogger.log('Image scan failed: $e', name: 'PositionScanner');
      return const ImageScanOutcome(error: 'Could not reach the server.');
    }
  }

  Uri _calibrationUri(String bookHash) =>
      Uri.parse('$backendUrl/scans/calibrations/$bookHash');

  /// The calibration this account remembered for a book, if any.
  Future<CalibrationLoad> loadCalibration(String bookHash) async {
    try {
      final uri = _calibrationUri(bookHash);
      final response = await (_client ?? _shared)
          .get(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final boards = (json['boards'] as List? ?? const [])
            .map((e) => CalibrationBoard.fromJson(e as Map<String, dynamic>))
            .toList();
        final absent = (json['absent'] as List? ?? const [])
            .map((e) => e.toString())
            .toList();
        return CalibrationLoad.found(boards, absent: absent);
      }
      if (response.statusCode == 404 &&
          _codeFrom(response.body) == 'no_calibration') {
        return const CalibrationLoad.missing();
      }
      return CalibrationLoad.failed(_errorFrom(response.body,
          'Reading the calibration failed (${response.statusCode}).'));
    } catch (e) {
      AppLogger.log('Load calibration failed: $e', name: 'PositionScanner');
      return const CalibrationLoad.failed('Could not reach the server.');
    }
  }

  /// Remembers a book's calibration on the account. Null when saved, the
  /// server's words otherwise. [absent] null leaves the pieces the book was
  /// said not to draw as they are; a list, even empty, replaces them.
  Future<String?> saveCalibration({
    required String bookHash,
    required String bookName,
    required List<CalibrationBoard> boards,
    List<String>? absent,
  }) async {
    try {
      final uri = _calibrationUri(bookHash);
      final body = jsonEncode({
        'bookName': bookName,
        'boards': boards.map((b) => b.toJson()).toList(),
        if (absent != null) 'absent': absent,
      });
      final response = await (_client ?? _shared)
          .put(uri, headers: _jsonHeaders, body: body)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return null;
      return _errorFrom(response.body,
          'Saving the calibration failed (${response.statusCode}).');
    } catch (e) {
      AppLogger.log('Save calibration failed: $e', name: 'PositionScanner');
      return 'Could not reach the server.';
    }
  }

  /// Forgets a book's calibration, to set it up again. True when it is gone,
  /// including when there was none.
  Future<bool> deleteCalibration(String bookHash) async {
    try {
      final uri = _calibrationUri(bookHash);
      final response = await (_client ?? _shared)
          .delete(uri, headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      return response.statusCode == 204 || response.statusCode == 404;
    } catch (e) {
      AppLogger.log('Delete calibration failed: $e', name: 'PositionScanner');
      return false;
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

      final streamed = await _send(request).timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return ScanOutcome(
          result: ScanResult.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>),
        );
      }
      return ScanOutcome(
        error:
            _errorFrom(response.body, 'Scan failed (${response.statusCode}).'),
        code: _codeFrom(response.body),
        details: _detailsFrom(response.body),
      );
    } catch (e) {
      AppLogger.log('Scan failed: $e', name: 'PositionScanner');
      return const ScanOutcome(error: 'Could not reach the server.');
    }
  }

  Future<SaveOutcome> confirm({
    required String sourceTitle,
    required List<ScannedPosition> positions,
  }) async {
    try {
      final response = await (_client ?? _shared)
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
              response.body, 'Save failed (${response.statusCode}).'));
    } catch (e) {
      AppLogger.log('Confirm failed: $e', name: 'PositionScanner');
      return const SaveOutcome(error: 'Could not reach the server.');
    }
  }

  /// Everything this trainer has kept. Returns null when the server could not
  /// be reached — an empty list means "none saved", and the two must not look
  /// the same on screen.
  Future<List<SavedPosition>?> listSaved() async {
    try {
      final response = await (_client ?? _shared)
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
      final response = await (_client ?? _shared)
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
      final response = await (_client ?? _shared)
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

  /// Deletes one of the account's own positions or exercises. Null when it
  /// is gone; otherwise the sentence to show — the server's own when it has
  /// one, which is how a trainer learns *which* unfinished homework still
  /// holds the position (409, services/positionDeletion.js).
  Future<String?> deletePosition(String puzzleId) async {
    try {
      final response = await (_client ?? _shared)
          .delete(Uri.parse('$backendUrl/scans/puzzles/$puzzleId'),
              headers: _jsonHeaders)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return null;
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) {
          return body['error'] as String;
        }
      } catch (_) {
        // Not JSON; the sentence below says enough.
      }
      return 'The position could not be deleted.';
    } catch (e) {
      AppLogger.log('Delete position failed: $e', name: 'PositionScanner');
      return 'The position could not be deleted — the server did not respond.';
    }
  }
}
