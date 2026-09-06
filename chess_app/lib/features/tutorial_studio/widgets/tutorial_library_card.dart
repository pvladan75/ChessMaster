import 'package:flutter/material.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Asks whether an analysis line joins the open tutorial draft or starts a new one.
///
/// - `true`  — into the tutorial being written (`intoOpenDraft: true`)
/// - `false` — into a new one (`intoOpenDraft: false`)
/// - `null`  — the trainer cancelled
Future<bool?> askTutorialDestination(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Gde ide ova linija?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Otkaži'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Počni nov tutorijal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Nastavi tutorijal koji uređujem'),
        ),
      ],
    ),
  );
}

/// The front door to the Tutorial Studio on the Library tab.
///
/// Draws itself only when [isTutorialStudioAvailable] is true.
class TutorialLibraryCard extends StatelessWidget {
  const TutorialLibraryCard({
    super.key,
    required this.session,
    this.api,
  });

  final UserSession session;

  /// The seam a test reaches the library list through. Defaulted to a real
  /// service against this session's token, so nothing but a test passes it.
  final LessonApiService? api;

  @override
  Widget build(BuildContext context) {
    if (!isTutorialStudioAvailable) return const SizedBox.shrink();

    // The gap below belongs to the card rather than to the tab. The tab cannot
    // tell a card that draws nothing from a card that is not there, so spacing
    // it from the outside left 24 px of dead air at the top of the Library tab
    // on every phone — where this card is deliberately absent.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        shape: AppRadii.cardShape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    color: context.colors.accent,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Interaktivni tutorijali',
                    style: AppText.headline
                        .copyWith(color: context.colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Napravite tutorijal koji dete prolazi samo — pozicija po poziciju, sa '
                'komentarom, strelicama i pitanjima.',
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Novi tutorijal'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: AppSpacing.buttonPadding,
                ),
                onPressed: () => _onNewTutorial(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Otvori sačuvani tutorijal'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: AppSpacing.buttonPadding,
                ),
                onPressed: () => _onOpenSavedTutorial(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onNewTutorial(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _NewTutorialNameDialog(),
    );

    // Trimmed and refused inside the dialog, so anything that arrives here is a
    // name. A tutorial has to have one before the first save — the studio
    // refuses an unnamed one — and finding that out after twenty minutes of
    // writing is the expensive way to learn it.
    if (name == null || !context.mounted) return;

    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.blank(name),
      ),
    ));
  }

  Future<void> _onOpenSavedTutorial(BuildContext context) async {
    final service = api ?? LessonApiService(authToken: session.token);
    final rawRows = await service.fetchAll();
    if (!context.mounted) return;

    // `lastFetchFailed` is the whole answer. The `identical(rawRows, const [])`
    // that stood beside it happened to be harmless — `jsonDecode` builds a new
    // list, so a genuinely empty library is never the canonical `const []` —
    // but it read as though it were doing the work, and it would start
    // misfiring the day `fetchAll` returned a plain `[]` on failure. A second
    // condition that cannot be right when the first is wrong is not a
    // safeguard.
    if (service.lastFetchFailed) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Otvori sačuvani tutorijal'),
          content: const Text('Ne mogu da učitam listu tutorijala.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Otkaži'),
            ),
          ],
        ),
      );
      return;
    }

    final tutorials = <Map<String, dynamic>>[];
    for (final item in rawRows) {
      if (item is Map<String, dynamic>) {
        final posList = item['position_list'];
        if (posList is List && posList.isNotEmpty) {
          tutorials.add(item);
        }
      } else if (item is Map) {
        final posList = item['position_list'];
        if (posList is List && posList.isNotEmpty) {
          tutorials.add(Map<String, dynamic>.from(item));
        }
      }
    }

    if (tutorials.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Otvori sačuvani tutorijal'),
          content: const Text('Nemate nijedan sačuvan tutorijal.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Otkaži'),
            ),
          ],
        ),
      );
      return;
    }

    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Otvori sačuvani tutorijal'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: tutorials.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final row = tutorials[index];
                final title = row['title']?.toString() ?? '';
                return ListTile(
                  title: Text(title),
                  onTap: () => Navigator.of(ctx).pop(row),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Otkaži'),
          ),
        ],
      ),
    );

    if (picked != null && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TutorialStudioScreen(
          session: session,
          entry: TutorialEntry.saved(picked),
        ),
      ));
    }
  }
}

/// „Novi tutorijal" — one field, and the controller's whole life inside it.
///
/// Stateful for one reason, and it is not style. A controller created beside
/// `showDialog` and disposed when that future completes is disposed **too
/// early**: the future finishes on `pop`, while the route is still animating
/// out and the `TextField` still rebuilding, and the rebuild asserts on a
/// controller that is already gone. Leaving it undisposed instead leaks a
/// listener. A `State` is the only place that knows when the field is actually
/// finished with.
class _NewTutorialNameDialog extends StatefulWidget {
  const _NewTutorialNameDialog();

  @override
  State<_NewTutorialNameDialog> createState() => _NewTutorialNameDialogState();
}

class _NewTutorialNameDialogState extends State<_NewTutorialNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Answers with the name, or with nothing at all when it is blank. Three
  /// spaces is a blank name.
  void _submit() {
    final trimmed = _controller.text.trim();
    Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novi tutorijal'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Naziv tutorijala'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Otkaži'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Napravi')),
      ],
    );
  }
}
