import 'package:flutter/material.dart';

import 'package:chess_app/core/user_manual.dart';
import 'package:chess_app/screens/home_screen.dart' show kTabNames;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

/// One line of the list: the keys, what they do, and nothing implied.
class AppShortcut {
  const AppShortcut(this.keys, this.what);

  /// Drawn one after another, so `['Ctrl', ',']` reads as a chord.
  final List<String> keys;

  final String what;
}

/// A group of shortcuts and, in [where], the honest answer to "where does this
/// work". A list that lets the reader assume a key works everywhere, when it
/// works on one screen, is worse than no list at all: they press it, nothing
/// happens, and they stop trusting the rest of the page.
class ShortcutGroup {
  const ShortcutGroup(this.title, this.where, this.shortcuts);

  final String title;
  final String where;
  final List<AppShortcut> shortcuts;
}

/// Every shortcut the application answers, in one place.
///
/// This is the list, not a copy of it: a key added to a screen and not added
/// here is a key nobody will find. Ctrl+, is why this page exists at all — it
/// was built, it passed its test, and the person it was built for could not
/// find it or use it. A shortcut nobody knows about does not exist.
final kShortcutGroups = <ShortcutGroup>[
  ShortcutGroup(
    'Everywhere in app',
    'Works on every screen.',
    [
      AppShortcut(['Esc'], 'Closes whatever is open over current work.'),
      AppShortcut(['Ctrl', ','], 'Opens Settings.'),
      AppShortcut(['F1'], 'Opens this shortcut list.'),
      AppShortcut(['Ctrl', 'C'], 'Copies FEN of the board on screen.'),
    ],
  ),
  ShortcutGroup(
    'Tabs',
    'On the home screen, where the four tabs are. While an exercise or room '
        'is open above it, keys belong to what is on top.',
    // The tabs' own names, read from where the tabs are named: this list
    // said Training, Sessions, Library and People for eleven days after the
    // reorganisation of 18.9.2026 renamed and reordered all four.
    [
      for (var i = 0; i < kTabNames.length; i++)
        AppShortcut(['Ctrl', '${i + 1}'], '${kTabNames[i]}.'),
    ],
  ),
  ShortcutGroup(
    'Move navigation',
    'Everywhere with a move strip below the board: analysis, room, tutorial, '
        'reviews, exercises, and game review. While focus is in a text '
        'field, arrow keys belong to the field.',
    [
      AppShortcut(['←'], 'Move backward.'),
      AppShortcut(['→'], 'Move forward.'),
      AppShortcut(['↑'], 'To the start of the line.'),
      AppShortcut(['↓'], 'To the end of the line.'),
      AppShortcut(['Home'], 'To the start of the line, same as ↑.'),
      AppShortcut(['End'], 'To the end of the line, same as ↓.'),
    ],
  ),
  ShortcutGroup(
    'Endgame trainer',
    'On the endgames screen. Each letter presses the button currently '
        'on screen, and does nothing when that button is not present.',
    [
      AppShortcut(['N'], 'Next position.'),
      AppShortcut(['R'], 'Restart, same as the restart button.'),
      AppShortcut(['H'], 'Hint.'),
      AppShortcut(['T'], 'Tablebase lookup, while playing out the position.'),
      AppShortcut(['U'], 'Undo move, after an error while playing out.'),
    ],
  ),
  ShortcutGroup(
    'Recording playback',
    'On the recorded session screen. While focus is on a button, space '
        'belongs to that button.',
    [
      AppShortcut(['Space'], 'Play or pause recording.'),
    ],
  ),
  ShortcutGroup(
    'Recording narration',
    'On the Record narration screen, while your voice is being recorded.',
    [
      AppShortcut(['Space'], 'Next beat.'),
    ],
  ),
  ShortcutGroup(
    'Tutorial Studio',
    'While a tutorial is being edited — also with the cursor in a text field, '
        'where Ctrl+Z takes back the last change to the tutorial, a whole '
        'sentence or a move, rather than one letter.',
    [
      AppShortcut(['Ctrl', 'Z'], 'Undo the last change.'),
      AppShortcut(['Ctrl', 'Y'], 'Redo it.'),
      AppShortcut(['Ctrl', 'Shift', 'Z'], 'Redo, same as Ctrl+Y.'),
    ],
  ),
  ShortcutGroup(
    'Move tree',
    'In Analysis, only after clicking inside the tree itself — while focus is not in it, '
        'arrow keys belong to the move strip below the board.',
    [
      AppShortcut(['↑'], 'To the move this variation branches from.'),
      AppShortcut(['↓'], 'To the first move.'),
      AppShortcut(['←'], 'To the previous variation of the same move.'),
      AppShortcut(['→'], 'To the next variation of the same move.'),
      AppShortcut(['+'], 'Zoom in tree.'),
      AppShortcut(['−'], 'Zoom out tree.'),
    ],
  ),
  ShortcutGroup(
    'Mouse',
    'On every board in rooms and exercises.',
    [
      AppShortcut(['Right click'], 'Copies board FEN.'),
    ],
  ),
];

/// The keyboard shortcuts, written down.
///
/// A page and not a dialog because it is reached from two places that must not
/// know about each other — the F1 key and a row in Settings — and a route is
/// what both can name.
class ShortcutsScreen extends StatelessWidget {
  const ShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard Shortcuts'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'No shortcut is the only way to do something — everything here also '
            'has its own button. On mobile devices without a keyboard, only right '
            'click works with a mouse.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
          // F1 is where somebody lost in the app presses first, so the manual
          // is one tap from here (docs/PLAN-PRIRUCNIK.md).
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('shortcuts-user-manual'),
              onPressed: () => openUserManual(context),
              icon: const Icon(Icons.menu_book),
              label: const Text('User manual'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // The groups flow into columns — as many as the width holds, one on
          // a phone, in this order (docs/PLAN-PRIJAVA-I-PODESAVANJA.md, §8;
          // the rule Settings uses). Each card carries its own gap below,
          // because the columns add none.
          AdaptiveCardColumns(
            children: [
              for (final group in kShortcutGroups)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _GroupCard(group: group),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final ShortcutGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: AppText.bodyBold),
            const SizedBox(height: AppSpacing.xs),
            Text(
              group.where,
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            const Divider(height: 20),
            for (final shortcut in group.shortcuts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                // The keys, then the sentence in whatever the card has left.
                // It was a Wrap whose sentence was sized from the *window*
                // (width - 140), which held on a phone and was wrong in a
                // column; the sentence now wraps inside its own card.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final key in shortcut.keys) ...[
                      _KeyCap(label: key),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(child: Text(shortcut.what, style: AppText.body)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.borderStrong),
      ),
      child: Text(
        label,
        style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
      ),
    );
  }
}
