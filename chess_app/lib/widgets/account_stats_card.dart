import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';

/// What the account is and what it has used up.
///
/// It used to sit on the first tab, under the buttons for starting a lesson,
/// which is where it was written and not where it belongs: a saved-position
/// count and a plan name are facts about the account, and the account is what
/// settings are for. Somebody opening the app to practise was being shown their
/// monthly session quota first.
///
/// It fetches for itself rather than being handed numbers. The screen it lives
/// on now is opened over whatever the reader was doing, so there is nobody
/// above it holding this.
class AccountStatsCard extends StatefulWidget {
  const AccountStatsCard({super.key, required this.session});

  final UserSession session;

  @override
  State<AccountStatsCard> createState() => _AccountStatsCardState();
}

class _AccountStatsCardState extends State<AccountStatsCard> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/users/me/stats'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _stats = jsonDecode(response.body));
      }
    } catch (e) {
      AppLogger.log('[Nalog] Statistika nije stigla: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// `-1` is the server's way of saying there is no ceiling.
  String _limit(dynamic used, dynamic max, int fallback) {
    final ceiling = max == -1 ? '∞' : '${max ?? fallback}';
    return '${used ?? 0} / $ceiling';
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final premium = stats?['account_type'] == 'premium';
    final limits = stats?['limits'] as Map<String, dynamic>?;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart, color: Colors.tealAccent),
                const SizedBox(width: 8),
                const Text('Statistika naloga',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Chip(
                    label: Text(
                      premium ? 'PREMIUM' : 'FREE',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    backgroundColor: premium
                        ? Colors.amber.withValues(alpha: 0.3)
                        : Colors.teal.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bookmark, color: Colors.teal),
              title: const Text('Sačuvane lekcije / pozicije',
                  style: TextStyle(fontSize: 13)),
              trailing: Text(
                _limit(stats?['savedLessonsCount'], limits?['maxSavedLessons'],
                    20),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.video_camera_front,
                  color: Colors.blueAccent),
              title: const Text('Kreirano sesija u tekućem mesecu',
                  style: TextStyle(fontSize: 13)),
              trailing: Text(
                _limit(stats?['monthlySessionsCount'],
                    limits?['maxMonthlySessions'], 5),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
