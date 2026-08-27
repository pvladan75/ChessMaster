import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import '../models/trainer_panel.dart';

/// Reads the trainer's panel, and tells the server when finished homework has
/// been looked at.
///
/// Both calls fail quietly. The panel sits above a working screen — the list of
/// people is what the tab is actually for — and a network hiccup must not put
/// an error banner over it or leave it spinning. An empty panel and a panel
/// that could not be fetched look the same on purpose: neither is worth
/// interrupting the trainer for.
class TrainerPanelApiService {
  TrainerPanelApiService({required this.authToken});

  final String authToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Future<TrainerPanel> fetch() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/trainer/panel'), headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return TrainerPanel.empty;

      return TrainerPanel.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      AppLogger.log('[Panel] Ne mogu da učitam panel: $e');
      return TrainerPanel.empty;
    }
  }

  /// Marks one finished assignment as looked at, which is what takes it off the
  /// badge. Best effort: the review screen opens either way, because refusing
  /// to show a trainer their student's work over a failed bookkeeping call
  /// would be the message taking down the thing it reports on.
  Future<void> markReviewed(int assignmentId) async {
    try {
      await http
          .post(
            Uri.parse('$backendUrl/assignments/$assignmentId/reviewed'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      AppLogger.log('[Panel] Pregled nije zabeležen: $e');
    }
  }
}
