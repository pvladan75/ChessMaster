import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_slider.dart';

/// How strongly the engine plays *against* the reader, and how long it may
/// think — chosen on the one screen where it plays, the exercise screen.
///
/// Both lived in Settings until 17.9.2026, although only that screen reads
/// them. Still remembered by [AppSettingsService]; a change is read at the
/// engine's next move, so it takes effect in the game on the board. When a
/// trainer can one day set a position to be played against the engine, the
/// strength will come with the assignment and this sheet will not be offered
/// there — the student does not choose the opponent the trainer chose.
Future<void> showEngineOpponentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const EngineOpponentSheet(),
  );
}

/// The button that opens the sheet; sized and coloured for the row it sits in.
class EngineOpponentButton extends StatelessWidget {
  const EngineOpponentButton({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.smart_toy_outlined, size: size, color: color),
      tooltip: 'Engine opponent',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: () => showEngineOpponentSheet(context),
    );
  }
}

class EngineOpponentSheet extends StatelessWidget {
  const EngineOpponentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Engine opponent',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              const Text('Strength',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<String>(
                key: const Key('engine-opponent-level'),
                segments: [
                  for (final entry
                      in AppSettingsService.kEnginePlayLevelNames.entries)
                    ButtonSegment<String>(
                      value: entry.key,
                      label: Text(entry.value),
                    ),
                ],
                selected: {settings.enginePlayLevel},
                showSelectedIcon: false,
                onSelectionChanged: (picked) {
                  if (picked.isEmpty) return;
                  settings.setEnginePlayLevel(picked.first);
                },
              ),
              const SizedBox(height: 6),
              Text(
                'The engine moves as soon as it reaches its level depth — '
                'Easy ${AppSettingsService.kEnginePlayDepths['lako']}, '
                'Medium ${AppSettingsService.kEnginePlayDepths['srednje']}, '
                'Hard ${AppSettingsService.kEnginePlayDepths['tesko']} '
                'moves ahead.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(
                    child: Text('Maximum think time',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    '${settings.defaultEngineMoveTimeSeconds} s',
                    style:
                        AppText.bodyBold.copyWith(color: context.colors.accent),
                  ),
                ],
              ),
              AppSlider(
                key: const Key('engine-opponent-time'),
                value: settings.defaultEngineMoveTimeSeconds
                    .toDouble()
                    .clamp(1.0, 60.0),
                min: 1,
                max: 60,
                divisions: 59,
                label: '${settings.defaultEngineMoveTimeSeconds} s',
                onChanged: (val) =>
                    settings.setEngineMoveTimeSeconds(val.round()),
              ),
              Text(
                'The engine moves at its level depth or when this time is up, '
                'whichever comes first. A change applies from its next move.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
