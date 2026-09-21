import 'package:flutter/material.dart';

import 'package:chess_app/features/groups/screens/groups_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

/// The "Prijatelji" tab: add-by-email form plus the current friends list.
class HomeFriendsTab extends StatelessWidget {
  final TextEditingController studentEmailController;
  final bool isLoadingStudents;

  /// People I teach. The tab used to draw only these, so someone who had a
  /// trainer but no students was told they had nobody at all.
  final List<dynamic> students;

  /// People who teach me — the same relationships read from the other end.
  final List<dynamic> trainers;

  /// Requests waiting for *this* user to answer, in either direction — a
  /// trainer who enrolled them, or a student asking them to coach.

  final VoidCallback onAddStudent;
  final ValueChanged<int> onDeleteStudent;

  /// Which side the sender is claiming for the request they are about to send.
  /// Sending one is not "adding a student": it says who teaches whom, and the
  /// other person answers that exact claim.
  final bool iAmTrainerInRequest;
  final ValueChanged<bool> onRoleChanged;

  /// Pull to refresh. The other side answers on their own device, so this
  /// screen can be out of date without anything having gone wrong.
  final Future<void> Function() onRefresh;

  /// Opens the student's progress report. Receives the raw row so the caller
  /// keeps the id and the display name together.
  final void Function(Map<String, dynamic> student) onOpenProgress;

  /// Opens the place where a missing parent address is filled in. Handed in
  /// rather than opened here so the tab stays a tab: the dialog belongs to the
  /// screen that owns the session.
  final VoidCallback onFixParentEmail;

  /// Inside the Teach tab, under its own scroll: no pull-to-refresh and no
  /// padding of its own. On its own it scrolls and refreshes as before.
  final bool embedded;

  const HomeFriendsTab({
    super.key,
    required this.studentEmailController,
    required this.isLoadingStudents,
    required this.students,
    required this.trainers,
    required this.onAddStudent,
    required this.onDeleteStudent,
    required this.iAmTrainerInRequest,
    required this.onRoleChanged,
    required this.onRefresh,
    required this.onOpenProgress,
    required this.onFixParentEmail,
    this.embedded = false,
  });

  /// Everyone, in whatever state the relationship is.
  List<dynamic> get myStudents => students;
  List<dynamic> get myTrainers => trainers;

  /// One person, from whichever end. `iTeachThem` decides only what the row
  /// offers: homework and progress belong to the teaching side, and breaking
  /// the relationship belongs to both — consent that cannot be withdrawn from
  /// one side is not consent.
  List<Widget> _rows(BuildContext context, List<dynamic> rows,
      {required bool iTeachThem}) {
    final colors = context.colors;

    return rows.map((r) {
      // Three states, not two. `awaiting_parent` is a relationship both people
      // agreed to that still does not exist, because a parent has not answered
      // — and a row that drew it as "Vaš učenik" would say a trainer may teach
      // a child they may not.
      final status = r['status'];
      final awaitingParent = status == 'awaiting_parent';
      final isPending = status == 'pending';
      final notYet = isPending || awaitingParent;
      // The child's own side of a wait on their parent is the one row here
      // that has something to do, so it stays enabled: `ListTile` drops
      // `onTap` entirely when it is not, which would have made the tap target
      // look right and do nothing.
      final actionable = awaitingParent && !iTeachThem;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: !notYet || actionable,
        leading: CircleAvatar(
          backgroundColor: notYet ? colors.surfaceRaised : null,
          child: Icon(awaitingParent
              ? Icons.family_restroom
              : (isPending
                  ? Icons.hourglass_empty
                  : (iTeachThem ? Icons.person : Icons.school))),
        ),
        title: Text(
          r['name'] ?? 'User',
          style: AppText.bodyLargeBold.copyWith(color: colors.textPrimary),
        ),
        subtitle: Text(
          awaitingParent
              ? (iTeachThem
                  ? 'Awaiting parental consent'
                  : 'Awaiting parental consent — tap here')
              : (isPending
                  ? (r['i_asked'] == true
                      ? 'Awaiting confirmation'
                      : 'Respond in notifications')
                  : (iTeachThem ? 'Your student' : 'Your trainer')),
          style: AppText.caption.copyWith(color: colors.textSecondary),
        ),
        onTap: awaitingParent
            ? (iTeachThem ? null : () => onFixParentEmail())
            : ((isPending || !iTeachThem)
                ? null
                : () => onOpenProgress(Map<String, dynamic>.from(r))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iTeachThem)
              Tooltip(
                message: awaitingParent
                    ? 'Available once parent confirms'
                    : (isPending
                        ? 'Available once student accepts'
                        : 'Progress and assignments'),
                child: TextButton.icon(
                  icon: const Icon(Icons.insights, size: 18),
                  label: const Text('Progress'),
                  onPressed: notYet
                      ? null
                      : () => onOpenProgress(Map<String, dynamic>.from(r)),
                ),
              ),
            IconButton(
              icon: Icon(Icons.delete, color: colors.danger, size: 20),
              tooltip: iTeachThem
                  ? 'End relationship'
                  : 'End relationship with trainer',
              onPressed: () => onDeleteStudent(r['id']),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) return _body(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final colors = context.colors;

    final form = Column(
      key: const Key('people-request-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text('I am a trainer'),
              selected: iAmTrainerInRequest,
              onSelected: (_) => onRoleChanged(true),
            ),
            ChoiceChip(
              label: const Text('I am a student'),
              selected: !iAmTrainerInRequest,
              onSelected: (_) => onRoleChanged(false),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          iAmTrainerInRequest
              ? 'You teach, the other person is a student.'
              : 'The other person teaches, you are a student.',
          style: AppText.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: studentEmailController,
                decoration: InputDecoration(
                  labelText: iAmTrainerInRequest
                      ? "Student's email"
                      : "Trainer's email",
                  hintText: 'osoba@example.com',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: onAddStudent,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 14,
                ),
              ),
              child: const Text('Send a request'),
            ),
          ],
        ),
      ],
    );

    final lists = Column(
      key: const Key('people-lists'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoadingStudents)
          const Center(child: CircularProgressIndicator())
        else if (myStudents.isEmpty && myTrainers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'You have neither students nor trainers yet.',
                style: AppText.body.copyWith(color: colors.textMuted),
              ),
            ),
          )
        else ...[
          if (myStudents.isNotEmpty) ...[
            Text(
              'My students',
              style: AppText.bodyLargeBold.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            AdaptiveCardRows(
                children: _rows(context, myStudents, iTeachThem: true)),
          ],
          if (myStudents.isNotEmpty && myTrainers.isNotEmpty)
            const SizedBox(height: AppSpacing.lg),
          if (myTrainers.isNotEmpty) ...[
            Text(
              'My trainers',
              style: AppText.bodyLargeBold.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            AdaptiveCardRows(
                children: _rows(context, myTrainers, iTeachThem: false)),
          ],
        ],
      ],
    );

    return SingleChildScrollView(
      physics: embedded
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: embedded ? EdgeInsets.zero : AppSpacing.screenPadding,
      child: Card(
        shape: AppRadii.cardShape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: colors.brand, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Students and trainers',
                      style:
                          AppText.headline.copyWith(color: colors.textPrimary),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: Icon(Icons.groups, color: colors.brand),
                    label: const Text('Groups'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupsScreen(students: students),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // `docs/PLAN-POCETNI-TABOVI.md`, decision 3: where two card
              // columns fit, the request form takes one of them and the
              // people take the rest, their rows flowing in turn. The email
              // field is then one card wide rather than the whole window, and
              // the width goes to showing more people. Below that, the form
              // sits above the list exactly as before.
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = AdaptiveCardGrid.columnsFor(width);
                if (columns < 2) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      form,
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(),
                      const SizedBox(height: AppSpacing.sm),
                      lists,
                    ],
                  );
                }
                final cell =
                    (width - AdaptiveCardGrid.spacing * (columns - 1)) /
                        columns;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: cell, child: form),
                    const SizedBox(width: AdaptiveCardGrid.spacing),
                    Expanded(child: lists),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
