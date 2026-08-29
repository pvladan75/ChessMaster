import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

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
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: context.colors.accent),
                const SizedBox(width: AppSpacing.sm),
                // Expanded rather than a fixed Text plus a Spacer: the
                // title, the gap and the plan chip together overflowed this row
                // by 26 pixels at 360 dp.
                Expanded(
                  child: Text('Statistika naloga', style: AppText.title),
                ),
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
                      style: AppText.micro.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary),
                    ),
                    backgroundColor: premium
                        ? context.colors.warning.withValues(alpha: 0.3)
                        : context.colors.accent.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bookmark, color: context.colors.accent),
              title:
                  Text('Sačuvane lekcije / pozicije', style: AppText.bodyLarge),
              trailing: Text(
                _limit(stats?['savedLessonsCount'], limits?['maxSavedLessons'],
                    20),
                style: AppText.bodyLargeBold,
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading:
                  Icon(Icons.video_camera_front, color: context.colors.info),
              title: Text('Kreirano sesija u tekućem mesecu',
                  style: AppText.bodyLarge),
              trailing: Text(
                _limit(stats?['monthlySessionsCount'],
                    limits?['maxMonthlySessions'], 5),
                style: AppText.bodyLargeBold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
