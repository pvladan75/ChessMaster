import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class PlayerProfileScreen extends StatefulWidget {
  final String username;

  const PlayerProfileScreen({super.key, required this.username});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  PlayerProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prof =
          await ArchiveApiService.instance.getPlayerProfile(widget.username);
      if (!mounted) return;
      setState(() {
        _profile = prof;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Error: $e');
      setState(() => _loading = false);
    }
  }

  String _formatScore(double? score) {
    if (score == null) return 'N/A';
    return '${(score * 100).round()}%';
  }

  String _translateClockKey(String key) {
    switch (key) {
      case 'under-30s':
        return 'Under 30s';
      case '30-60s':
        return '30-60s';
      case '60-120s':
        return '60-120s';
      case 'over-120s':
        return 'Over 120s';
      default:
        return key;
    }
  }

  String _translateColor(String key) {
    if (key == 'w') return 'White';
    if (key == 'b') return 'Black';
    return key;
  }

  static String _games(int n) => n == 1 ? '1 game' : '$n games';

  /// One line of a section: what it counts on the left, then how many games
  /// and the score on the right, so a column of them reads as a table.
  Widget _row(String label, int games, double? score, {String? extra}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: AppText.bodyBold
                    .copyWith(color: context.colors.textSecondary)),
          ),
          if (extra != null) ...[
            Text(extra,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
            const SizedBox(width: AppSpacing.md),
          ],
          Text(_games(games),
              style: AppText.body.copyWith(color: context.colors.textMuted)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            constraints: const BoxConstraints(minWidth: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: context.colors.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              _formatScore(score),
              style:
                  AppText.bodyBold.copyWith(color: context.colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// A section as a card: its title, a rule, its lines.
  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        key: ValueKey('profile-section-$title'),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppText.title
                      .copyWith(color: context.colors.textPrimary)),
              const Divider(height: 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildBucketList(String title, List<ProfileBucket> buckets,
      {String Function(String)? keyTranslator}) {
    if (buckets.isEmpty) return null;
    return _section(title, [
      for (final b in buckets)
        _row(keyTranslator != null ? keyTranslator(b.key) : b.key, b.games,
            b.score),
    ]);
  }

  Widget? _buildYearList(String title, List<ProfileYearBucket> buckets) {
    if (buckets.isEmpty) return null;
    return _section(title, [
      for (final b in buckets)
        _row(b.key, b.games, b.score,
            extra: b.avgElo != null ? 'Elo: ${b.avgElo}' : null),
    ]);
  }

  Widget? _buildClockSection(ClockProfile? clock) {
    if (clock == null || clock.sampled == 0) return null;
    final muted = AppText.body.copyWith(color: context.colors.textMuted);
    return _section('Time management', [
      Text('Games analyzed: ${clock.sampled}', style: muted),
      Text('Losses on time: ${clock.lostOnTime}', style: muted),
      if (clock.hurriedShare != null)
        Text('Rushed moves (<3s): ${_formatScore(clock.hurriedShare)}',
            style: muted),
      const SizedBox(height: AppSpacing.md),
      Text('Score by time at move 20:',
          style:
              AppText.bodyBold.copyWith(color: context.colors.textSecondary)),
      const SizedBox(height: AppSpacing.sm),
      for (final b in clock.atMove20)
        _row(_translateClockKey(b.key), b.games, b.score),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text('Profile: ${widget.username}'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(
                  child: Text('No data',
                      style: AppText.body
                          .copyWith(color: context.colors.textMuted)))
              // The sections flow into columns, one on a phone, in this
              // order (docs/PLAN-PRIJAVA-I-PODESAVANJA.md, §9): a row of
              // three short facts no longer stands alone at the left edge of
              // a 1920 px window.
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    AdaptiveCardColumns(
                      children: [
                        for (final section in [
                          _buildBucketList('By color', _profile!.byColor,
                              keyTranslator: _translateColor),
                          _buildBucketList(
                              'By time control', _profile!.bySpeed),
                          _buildBucketList(
                              'By outcome', _profile!.byTermination),
                          _buildBucketList(
                              'By game length', _profile!.byLength),
                          _buildBucketList('By game phase', _profile!.byPhase),
                          _buildYearList('By year', _profile!.byYear),
                          _buildBucketList('Openings', _profile!.byOpening),
                          _buildClockSection(_profile!.clock),
                        ])
                          if (section != null) section,
                      ],
                    ),
                  ],
                ),
    );
  }
}
