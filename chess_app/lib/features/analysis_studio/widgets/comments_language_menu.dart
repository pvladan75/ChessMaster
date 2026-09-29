import 'package:flutter/material.dart';

import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// „Comments in" and its menu of the seven tutorial languages — the one
/// setting for the language the AI writes in (`docs/PLAN-JEZIK-STUDIJE.md`,
/// L1 and G2), drawn by „Study this position" and „Make a tutorial from this
/// game". The caller holds the value and stores it
/// (`AppSettingsService.setStudyLanguage`); with no [onChanged] the menu is
/// drawn off.
///
/// The menu takes what the label leaves, and a name too long for it is cut
/// rather than pushed past the dialog: a menu is as wide as its widest item,
/// and „Serbian (Cyrillic)" in a large font is wider than the 232 px a 360 dp
/// phone leaves inside a dialog.
class CommentsLanguageMenu extends StatelessWidget {
  const CommentsLanguageMenu({
    super.key,
    required this.menuKey,
    required this.value,
    required this.onChanged,
  });

  static const String label = 'Comments in';

  /// The menu's own key, for the tests of each dialog that draws it.
  final Key menuKey;
  final TutorialLanguage value;
  final ValueChanged<TutorialLanguage>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final on = onChanged != null;
    return Row(
      children: [
        Text(
          label,
          style: AppText.body
              .copyWith(color: on ? colors.textPrimary : colors.textMuted),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: DropdownButton<TutorialLanguage>(
            key: menuKey,
            isExpanded: true,
            // The label's size, in the font the text around it is drawn in:
            // a menu does not inherit it.
            style: DefaultTextStyle.of(context)
                .style
                .merge(AppText.body)
                .copyWith(color: colors.textPrimary),
            value: value,
            onChanged: on
                ? (chosen) {
                    if (chosen != null) onChanged!(chosen);
                  }
                : null,
            items: [
              for (final language in TutorialLanguage.all)
                DropdownMenuItem(
                  value: language,
                  child: Text(
                    language.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
