import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/models/player_profile.dart';
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
      AppFeedback.error(context, 'Greška: $e');
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
        return 'Ispod 30s';
      case '30-60s':
        return '30-60s';
      case '60-120s':
        return '60-120s';
      case 'over-120s':
        return 'Preko 120s';
      default:
        return key;
    }
  }

  String _translateColor(String key) {
    if (key == 'w') return 'Beli';
    if (key == 'b') return 'Crni';
    return key;
  }

  Widget _buildBucketList(String title, List<ProfileBucket> buckets,
      {String Function(String)? keyTranslator}) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppText.title.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        ...buckets.map((b) {
          final label = keyTranslator != null ? keyTranslator(b.key) : b.key;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(label,
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textSecondary)),
                Text('${b.games} partija',
                    style:
                        AppText.body.copyWith(color: context.colors.textMuted)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    _formatScore(b.score),
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildYearList(String title, List<ProfileYearBucket> buckets) {
    if (buckets.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppText.title.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        ...buckets.map((b) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(b.key,
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textSecondary)),
                Text('${b.games} partija',
                    style:
                        AppText.body.copyWith(color: context.colors.textMuted)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    _formatScore(b.score),
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ),
                if (b.avgElo != null)
                  Text('Elo: ${b.avgElo}',
                      style: AppText.caption
                          .copyWith(color: context.colors.textMuted)),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildClockSection(ClockProfile? clock) {
    if (clock == null || clock.sampled == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upravljanje vremenom',
            style: AppText.title.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.sm),
        Text('Analizirano partija: ${clock.sampled}',
            style: AppText.body.copyWith(color: context.colors.textMuted)),
        Text('Porazi na vreme: ${clock.lostOnTime}',
            style: AppText.body.copyWith(color: context.colors.textMuted)),
        if (clock.hurriedShare != null)
          Text('Brzopleti potezi (<3s): ${_formatScore(clock.hurriedShare)}',
              style: AppText.body.copyWith(color: context.colors.textMuted)),
        const SizedBox(height: AppSpacing.md),
        Text('Skor na osnovu vremena u 20. potezu:',
            style:
                AppText.bodyBold.copyWith(color: context.colors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        ...clock.atMove20.map((b) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                Text(_translateClockKey(b.key),
                    style: AppText.body
                        .copyWith(color: context.colors.textSecondary)),
                Text('${b.games} partija',
                    style:
                        AppText.body.copyWith(color: context.colors.textMuted)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    _formatScore(b.score),
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text('Profil: ${widget.username}'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(
                  child: Text('Nema podataka',
                      style: AppText.body
                          .copyWith(color: context.colors.textMuted)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBucketList('Po boji', _profile!.byColor,
                          keyTranslator: _translateColor),
                      _buildBucketList('Po tempu igre', _profile!.bySpeed),
                      _buildBucketList('Po ishodu', _profile!.byTermination),
                      _buildBucketList('Po dužini partije', _profile!.byLength),
                      _buildBucketList('Po fazi igre', _profile!.byPhase),
                      _buildYearList('Po godinama', _profile!.byYear),
                      _buildBucketList('Otvaranja', _profile!.byOpening),
                      _buildClockSection(_profile!.clock),
                    ],
                  ),
                ),
    );
  }
}
