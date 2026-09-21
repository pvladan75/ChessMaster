import 'package:flutter/material.dart';

import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';
import 'package:chess_app/features/trainer_panel/widgets/trainer_panel_view.dart';
import 'package:chess_app/features/training/widgets/resume_strip.dart';
import 'package:chess_app/services/server_status_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

/// The "Početna" tab: welcome header, session shortcuts, account stats and
/// the recordings list. Purely presentational — [HomeScreen] owns fetching
/// and mutating everything shown here.
class HomeDashboardTab extends StatelessWidget {
  final String userName;
  final TextEditingController codeController;
  final List<dynamic> recordings;
  final bool isLoadingRecordings;

  /// The trainer's day — today's sessions, homework to review — drawn only
  /// when it has rows. Phase 5 of docs/PLAN-REORGANIZACIJA.md moved it here
  /// from the People tab: it is about now, not about who.
  final TrainerPanel panel;
  final void Function(String roomCode) onEnterLesson;
  final void Function(PanelAssignment assignment) onOpenPanelAssignment;
  final void Function(int id, String name) onOpenStudent;

  /// Whether anybody teaches this user. The student's blocks — what was set
  /// for them, what is due for review — are drawn for a student, and for
  /// anyone with something due; a player with neither sees neither.
  final bool hasTrainer;
  final VoidCallback onOpenAssignments;
  final VoidCallback onOpenReviews;

  /// Positions waiting to be reviewed; drives the badge.
  final int dueReviewCount;
  final ValueChanged<String> onJoinRoom;
  final VoidCallback onRefreshRecordings;
  final ValueChanged<int> onOpenReplay;

  const HomeDashboardTab({
    super.key,
    required this.userName,
    required this.codeController,
    required this.recordings,
    required this.isLoadingRecordings,
    required this.panel,
    required this.onEnterLesson,
    required this.onOpenPanelAssignment,
    required this.onOpenStudent,
    required this.hasTrainer,
    required this.onOpenAssignments,
    required this.onOpenReviews,
    this.dueReviewCount = 0,
    required this.onJoinRoom,
    required this.onRefreshRecordings,
    required this.onOpenReplay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Sections stack, their contents flow — `docs/PLAN-POCETNI-TABOVI.md`
    // §3. No cap and no reading of the window: the shortcuts, the panel's
    // rows and the recordings each take their column count from the width
    // they are handed, so a phone keeps one card per line and today's order,
    // and no line of prose is ever wider than one card.
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Header Card
          Card(
            shape: AppRadii.cardShape,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                children: [
                  // Solid, with the initial in the canvas colour. It was a
                  // brand tint at 22% alpha carrying brand-coloured text —
                  // one token as both background and foreground, which
                  // measures 3.69:1 where 4.5 is the bar. The tint could
                  // have been lowered instead, and the arithmetic says
                  // 10% would just clear it: a circle so faint that it is
                  // no longer a coloured circle. Passing a contrast gate
                  // by making a thing invisible is not passing it.
                  //
                  // 6.56:1 this way, and the difference is in lightness
                  // rather than in hue, which is the only kind the reader
                  // of this app can be relied on to see.
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.brand,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'K',
                      style: AppText.display.copyWith(color: colors.canvas),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $userName!',
                          style: AppText.headline
                              .copyWith(color: colors.textPrimary),
                        ),
                        // The greeting proves the phone remembers you and
                        // nothing else. Said alone, with the backend off, it
                        // reads as "connected" — so when it is not, that is
                        // stated right underneath rather than left to be
                        // discovered when something fails to save.
                        const _ConnectionNotice(),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Get ready for a chess session, solve puzzles, or analyze positions.',
                          style: AppText.body
                              .copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // What is left open, and what needs a trainer today. Both
          // draw nothing when they have nothing.
          const ResumeStrip(),
          TrainerPanelView(
            panel: panel,
            onEnterLesson: onEnterLesson,
            onOpenAssignment: onOpenPanelAssignment,
            onOpenStudent: onOpenStudent,
          ),
          // What was set for me, what is due, and a room to join: peers,
          // in one flow. The student's two are drawn for someone who has
          // a trainer, and for anyone with a review due — never as two
          // empty cards.
          AdaptiveCardRows(
            key: const Key('home-shortcut-flow'),
            children: [
              if (hasTrainer || dueReviewCount > 0) ...[
                // Homework. Sits directly under the session shortcuts because for
                // a student it is the reason to open the app between lessons.
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.roundedLg,
                    side: BorderSide(color: colors.info, width: 1.5),
                  ),
                  child: InkWell(
                    onTap: onOpenAssignments,
                    borderRadius: AppRadii.roundedLg,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Icon(Icons.assignment_turned_in,
                              size: 32, color: colors.info),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set for me',
                                  style: AppText.title
                                      .copyWith(color: colors.info),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Drills and tutorials your trainer set you, and your progress.',
                                  style: AppText.caption
                                      .copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),

                // Spaced repetition. Shown even at zero so the student learns the
                // feature exists before anything is due; the badge is what pulls
                // them back on the days it is not.
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.roundedLg,
                    side: BorderSide(
                      color: dueReviewCount > 0
                          ? colors.warning
                          : colors.borderStrong,
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: onOpenReviews,
                    borderRadius: AppRadii.roundedLg,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Badge(
                            isLabelVisible: dueReviewCount > 0,
                            label: Text('$dueReviewCount'),
                            child: Icon(
                              Icons.repeat,
                              size: 32,
                              color: dueReviewCount > 0
                                  ? colors.warning
                                  : colors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Due for review',
                                  style: AppText.title.copyWith(
                                    color: dueReviewCount > 0
                                        ? colors.warning
                                        : colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  dueReviewCount > 0
                                      ? (dueReviewCount == 1
                                          ? '1 position is waiting for review.'
                                          : '$dueReviewCount positions are waiting for review.')
                                      : 'Positions from tutorials return for review when their time comes.',
                                  style: AppText.caption
                                      .copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: colors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Join Room Card
              Card(
                shape: AppRadii.cardShape,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Join a session',
                          style: AppText.title
                              .copyWith(color: colors.textPrimary)),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: codeController,
                              decoration: const InputDecoration(
                                labelText: 'Enter room code (e.g. 123456)',
                                prefixIcon: Icon(Icons.vpn_key),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Join'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: 14,
                              ),
                            ),
                            onPressed: () {
                              final code = codeController.text.trim();
                              if (code.isNotEmpty) onJoinRoom(code);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          // The material card.
          //
          // Not 'Snimljeni časovi' any more: a lesson has not been recorded
          // since 26.8.2026, and what a recording is now is material an
          // adult made alone in a room. A label that still said 'čas' named
          // a thing this app can no longer produce.
          Card(
            shape: AppRadii.cardShape,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.video_library, color: colors.brand),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Recordings',
                            style: AppText.title
                                .copyWith(color: colors.textPrimary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: onRefreshRecordings,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (isLoadingRecordings)
                    const Center(child: CircularProgressIndicator())
                  else if (recordings.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Center(
                        child: Text(
                          'No recordings yet.',
                          style: AppText.body.copyWith(color: colors.textMuted),
                        ),
                      ),
                    )
                  else
                    // Each recording a card, flowing into as many
                    // columns as the card has room for.
                    AdaptiveCardRows(
                      key: const Key('home-recordings-flow'),
                      children: [
                        for (final rec in recordings)
                          _RecordingCard(
                            recording: rec,
                            onPlay: () => onOpenReplay(rec['id'] as int),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One recording: what it is on the left, „Play" on the right — the same
/// dense row as the Trainer panel's, laid out in columns by the flow above.
class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.recording, required this.onPlay});

  final dynamic recording;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = recording['title'] ?? 'Recording';
    final dateStr = DateTime.parse(recording['created_at'])
        .toLocal()
        .toString()
        .substring(0, 16);
    final durationSec = recording['duration'] ?? 0;
    final durationMin = (durationSec / 60).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: AppRadii.roundedMd,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        leading: CircleAvatar(
          backgroundColor: colors.brand.withValues(alpha: 0.22),
          child: Icon(Icons.play_arrow, color: colors.brand),
        ),
        title: Text(
          title,
          style: AppText.bodyLargeBold.copyWith(color: colors.textPrimary),
        ),
        subtitle: Text(
          '$dateStr • $durationMin min',
          style: AppText.caption.copyWith(color: colors.textSecondary),
        ),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.movie, size: 14),
          label: Text('Play', style: AppText.caption),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 36),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          onPressed: onPlay,
        ),
      ),
    );
  }
}

/// Says so when being signed in currently buys nothing.
class _ConnectionNotice extends StatelessWidget {
  const _ConnectionNotice();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ServerStatusService.instance,
      builder: (context, _) {
        final service = ServerStatusService.instance;
        if (!service.hasProblem) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                service.status == ServerStatus.expired
                    ? Icons.lock_clock
                    : Icons.cloud_off,
                size: 14,
                color: context.colors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  service.message,
                  style: AppText.caption.copyWith(
                    color: context.colors.warning,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
