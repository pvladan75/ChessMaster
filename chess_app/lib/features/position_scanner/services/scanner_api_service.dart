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

  /// `unknown_font` and `range_too_large` are worth telling apart in the UI:
  /// one is asking for less, the other is a book we cannot read at all yet.
  final String? code;

  bool get ok => result != null;
}

class SaveOutcome {
  const SaveOutcome({this.saved = 0, this.rejected = 0, this.error});

  final int saved;
  final int rejected;
  final String? error;

  bool get ok => error == null;
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
