import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Where a PGN comes into the room from: a file, or pasted text.
///
/// Both used to sit in the lessons drawer, the paste one as a single-line field
/// under the FEN field. A whole game does not read back in one line on a phone,
/// and that drawer already carries nine controls stacked vertically — so the
/// paste box moved in here, behind the button that was already the usual way in.
class PgnImportDialog extends StatefulWidget {
  /// Opens the platform file picker. The dialog closes first, so the picker
  /// does not come up behind it.
  final VoidCallback onPickFile;

  /// Called with the pasted text, which may hold several games — the caller
  /// splits it the same way it splits a file.
  final ValueChanged<String> onPasted;

  const PgnImportDialog({
    super.key,
    required this.onPickFile,
    required this.onPasted,
  });

  @override
  State<PgnImportDialog> createState() => _PgnImportDialogState();
}

class _PgnImportDialogState extends State<PgnImportDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Taken from the screen rather than fixed: a fixed 360 is wider than the
    // content box of a dialog on a 360 dp phone, and a release build clips it
    // without painting anything to say so.
    final width = MediaQuery.of(context).size.width * 0.9;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_open, color: colors.brand),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('Uvezi PGN', style: AppText.title)),
        ],
      ),
      content: SizedBox(
        width: width > 420 ? 420 : width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onPickFile();
                },
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Otvori PGN fajl'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: colors.canvas,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'ili nalepi tekst partije:',
                style: AppText.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                minLines: 5,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '[Event "..."]\n1. e4 e5 2. Nf3 ...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                ),
                style: AppText.body,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(context);
            widget.onPasted(text);
          },
          icon: const Icon(Icons.playlist_add, size: 16),
          label: const Text('Učitaj'),
        ),
      ],
    );
  }
}
