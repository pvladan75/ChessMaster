import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Where the reader left off, at the top of the first screen they see.
///
/// The tab under it is the same for everybody - here is what there is to
/// practise - and that is why it leads. This is the half that is theirs: a
/// lesson still running, a position they were pulling apart. Nothing invented
/// and nothing suggested; only things that were actually left open.
///
/// It shows nothing at all when there is nothing, rather than a card explaining
/// that there is nothing. An empty state that has to be read is worse than a
/// space that is not there.
class ResumeStrip extends StatefulWidget {
  const ResumeStrip({super.key});

  @override
  State<ResumeStrip> createState() => _ResumeStripState();
}

class _ResumeStripState extends State<ResumeStrip> {
  bool _hasDraft = false;

  @override
  void initState() {
    super.initState();
    _checkDraft();
    // The room outlives this screen, so its comings and goings are watched
    // rather than read once.
    GameSessionService.instance.addListener(_onSession);
  }

  @override
  void dispose() {
    GameSessionService.instance.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  Future<void> _checkDraft() async {
    final draft = await AnalysisDraftService.instance.load();
    if (!mounted) return;
    setState(() => _hasDraft = draft != null);
  }

  @override
  Widget build(BuildContext context) {
    final session = GameSessionService.instance;
    final colors = context.colors;
    final items = <Widget>[
      if (session.hasActiveSession)
        _ResumeChip(
          icon: Icons.videocam_outlined,
          label: 'Nastavi čas ${session.roomCode}',
          colour: colors.accent,
          onTap: () => context.push(
            AppRoutes.roomPath(session.roomCode!, role: session.role),
          ),
        ),
      if (_hasDraft)
        _ResumeChip(
          icon: Icons.biotech_outlined,
          label: 'Nastavi analizu',
          colour: colors.brand,
          onTap: () => context.push(AppRoutes.analysis),
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nastavi',
            style: AppText.captionBold.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Wrap: two of these with a room code in one of them outgrow a phone,
          // and a release build clips instead of warning.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: items,
          ),
        ],
      ),
    );
  }
}

class _ResumeChip extends StatelessWidget {
  const _ResumeChip({
    required this.icon,
    required this.label,
    required this.colour,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ActionChip(
      avatar: Icon(icon, size: 20, color: colour),
      label: Text(
        label,
        style: AppText.bodyBold.copyWith(color: colors.textPrimary),
      ),
      onPressed: onTap,
      backgroundColor: colour.withValues(alpha: 0.16),
      side: BorderSide(color: colour.withValues(alpha: 0.35)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
    );
  }
}
