import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/theme/app_colors.dart';
import '../services/assignment_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Composes the monthly report a trainer sends to a parent, then hands back the
/// link.
///
/// Two steps in one dialog: pick the period and write a note, then copy or open
/// the link. Keeping it in one place means the trainer never has to hunt for a
/// generated report afterwards.
class ParentReportDialog extends StatefulWidget {
  const ParentReportDialog({
    super.key,
    required this.api,
    required this.studentId,
    required this.studentName,
  });

  final AssignmentApiService api;
  final int studentId;
  final String studentName;

  @override
  State<ParentReportDialog> createState() => _ParentReportDialogState();
}

class _ParentReportDialogState extends State<ParentReportDialog> {
  final _note = TextEditingController();
  int _days = 30;
  bool _working = false;
  String? _error;
  String? _url;
  bool _hasData = true;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _working = true;
      _error = null;
    });

    final result = await widget.api.generateParentReport(
      studentId: widget.studentId,
      days: _days,
      note: _note.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _working = false;
      _url = result.url;
      _hasData = result.hasData;
      _error = result.error;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _url!));
    if (!mounted) return;
    AppFeedback.show(
      context,
      () => const SnackBar(content: Text('Link je kopiran.')),
    );
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(_url!);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        () => const SnackBar(content: Text('Ne mogu da otvorim link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // An AlertDialog leaves screenWidth - 128 for its child; a wider fixed box
    // overflows on a phone instead of shrinking.
    final width = (MediaQuery.of(context).size.width - 128).clamp(180.0, 420.0);

    return AlertDialog(
      title:
          Text(_url == null ? 'Izveštaj za roditelja' : 'Izveštaj je spreman'),
      content: SizedBox(
        width: width,
        child: SingleChildScrollView(
          child: _url == null ? _buildForm(context) : _buildResult(context),
        ),
      ),
      actions: _url == null
          ? [
              TextButton(
                onPressed: _working ? null : () => Navigator.pop(context),
                child: const Text('Otkaži'),
              ),
              ElevatedButton(
                onPressed: _working ? null : _generate,
                child: _working
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Napravi'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zatvori'),
              ),
              TextButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Otvori'),
              ),
              ElevatedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Kopiraj link'),
              ),
            ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Za ${widget.studentName}. Roditelj otvara link u pregledaču — '
          'nije mu potreban nalog.',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Period', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final option in const [7, 30, 90])
              ChoiceChip(
                label: Text('$option dana'),
                selected: _days == option,
                onSelected: (_) => setState(() => _days = option),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _note,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Poruka roditelju (opciono)',
            hintText:
                'Šta ide dobro, na čemu radite, šta biste tražili od kuće.',
            alignLabelWithHint: true,
          ),
        ),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: context.colors.danger, fontSize: 12.5)),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_hasData)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Napomena: u izabranom periodu učenik nije rešavao zadatke, pa '
              'izveštaj to i kaže umesto da prikaže nule.',
              style: TextStyle(fontSize: 12.5, color: context.colors.warning),
            ),
          ),
        Text(
          'Pošaljite ovaj link roditelju. Brojevi u njemu su zamrznuti — neće se '
          'menjati kad ga roditelj kasnije ponovo otvori.',
          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.surfaceRaised,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            _url!,
            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Link važi 60 dana i otvara ga svako ko ga dobije — šaljite ga samo '
          'roditelju.',
          style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
        ),
      ],
    );
  }
}
