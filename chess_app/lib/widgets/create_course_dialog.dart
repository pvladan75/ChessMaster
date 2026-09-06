import 'package:flutter/material.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/widgets/position_picker_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class CreateCourseDialog extends StatefulWidget {
  final UserSession userSession;
  final VoidCallback onCourseCreated;

  /// When set, the dialog opens pre-filled for editing this existing saved
  /// lesson (must be a course — i.e. have a position_list) instead of
  /// starting a blank one.
  final Map<String, dynamic>? existingLesson;

  const CreateCourseDialog({
    super.key,
    required this.userSession,
    required this.onCourseCreated,
    this.existingLesson,
  });

  @override
  State<CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<CreateCourseDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final List<Map<String, dynamic>> selectedPositions = [];

  late final LessonApiService _api =
      LessonApiService(authToken: widget.userSession.token);
  bool isSaving = false;
  bool isAddingFromLibrary = false;

  bool get isEditing => widget.existingLesson != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingLesson;
    if (existing != null) {
      titleController.text = existing['title'] ?? '';
      descController.text = existing['description'] ?? '';
      final items = (existing['position_list'] as List?) ?? const [];
      selectedPositions.addAll(
        items.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
    }
  }

  void _showError(String message) {
    AppFeedback.show(
      context,
      () => SnackBar(
          content: Text(message), backgroundColor: context.colors.danger),
    );
  }

  void _showSuccess(String message) {
    AppFeedback.show(
      context,
      () => SnackBar(
          content: Text(message), backgroundColor: context.colors.success),
    );
  }

  /// Adds positions from the one library, whatever shelf they sit on.
  ///
  /// There used to be two ways in here — a checkbox list of saved boards and a
  /// button for saved analyses — and no way at all to reach a position scanned
  /// out of a book. That was a hole in the chain: a trainer could scan a
  /// diagram, confirm it, set it as homework, and still not put it in a lesson.
  Future<void> _addFromLibrary() async {
    setState(() => isAddingFromLibrary = true);
    final picked = await showDialog<List<LibraryEntry>>(
      context: context,
      builder: (ctx) => PositionPickerDialog(
        service: PositionLibraryService(authToken: widget.userSession.token),
      ),
    );
    if (!mounted) return;

    if (picked == null || picked.isEmpty) {
      setState(() => isAddingFromLibrary = false);
      return;
    }

    final steps = <Map<String, dynamic>>[];
    for (final entry in picked) {
      steps.add(await _stepFrom(entry));
    }
    if (!mounted) return;

    setState(() {
      isAddingFromLibrary = false;
      selectedPositions.addAll(steps);
    });
  }

  /// Turns one library entry into a lesson step.
  ///
  /// Two things must survive the crossing. The **task** moves from the position
  /// onto the step, or the student gets a board with no question on it — the
  /// oldest complaint about this feature, fixed once already. The **solution**
  /// travels too, unused: a lesson is read rather than solved, but the same
  /// step may later be set as homework, and a move dropped here is gone.
  Future<Map<String, dynamic>> _stepFrom(LibraryEntry entry) async {
    final step = <String, dynamic>{
      'title': entry.title,
      'fen': entry.fen,
      if (entry.instruction != null) 'instruction': entry.instruction,
      if (entry.solutionSan != null) 'solutionSan': entry.solutionSan,
    };

    if (entry.kind != LibraryKind.analysis) {
      if (entry.pgn != null) step['pgn'] = entry.pgn;
      return step;
    }

    // The tree is the heavy half and is not in the listing, so it is fetched
    // only for the entries actually taken.
    final id = int.tryParse(entry.id);
    final tree = id == null
        ? null
        : await AnalysisPersistenceService.instance.loadAnalysis(
            id: id,
            userToken: widget.userSession.token,
          );
    if (tree == null) {
      // The board is still worth keeping: the starting position is right, only
      // the variations are missing, and saying so beats dropping the step.
      _showError(
          'Varijante za „${entry.title}" nisu učitane — dodata je samo pozicija.');
      return step;
    }
    step['fen'] = tree.fen;
    step['pgn'] = PgnExporterService.exportToPgn(tree);
    return step;
  }

  Future<void> _submit({required bool asNew}) async {
    final title = titleController.text.trim();
    final desc = descController.text.trim();
    if (title.isEmpty) {
      _showError('Unesite naziv tutorijala.');
      return;
    }
    if (selectedPositions.isEmpty) {
      _showError('Dodajte bar jedan korak.');
      return;
    }

    setState(() => isSaving = true);
    final updateInPlace = isEditing && !asNew;
    // `selectedPositions` holds each stored step whole, so `id`, `kind`,
    // `solutionSan` and `choices` travel back untouched. That is what keeps the
    // server's 409 from firing on an edit made here, and it is why this dialog
    // can go on ordering steps it does not know how to author.
    final error = updateInPlace
        ? await _api.update(
            id: widget.existingLesson!['id'] as int,
            title: title,
            description: desc,
            tags: const ['lekcija_kurs'],
            positionList: selectedPositions,
          )
        : await _api.save(
            title: title,
            description: desc,
            tags: const ['lekcija_kurs'],
            positionList: selectedPositions,
          );

    if (!mounted) return;
    setState(() => isSaving = false);

    if (error != null) {
      // The server's own sentence. `buildLessonStep` refuses a step with a
      // reason a trainer can act on, and „Neuspešna izmena lekcije." — which is
      // what stood here — threw away the only part that helps.
      _showError(error);
      return;
    }

    _showSuccess(updateInPlace
        ? 'Tutorijal je izmenjen (${selectedPositions.length} koraka)!'
        : 'Tutorijal sa ${selectedPositions.length} koraka je sačuvan!');
    widget.onCourseCreated();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.collections_bookmark, color: colors.brand),
          const SizedBox(width: AppSpacing.sm),
          Text(
              isEditing
                  ? 'Izmeni tutorijal'
                  : 'Kreiraj tutorijal (više koraka)',
              style: AppText.title),
        ],
      ),
      // The width must be tight: AlertDialog wraps its children in an
      // IntrinsicWidth, and a loose maxWidth would let that intrinsic pass
      // descend into the lazy lists below, which cannot report intrinsics.
      content: SizedBox(
        width: 380,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Naziv tutorijala',
                    hintText: 'Npr. Završnice sa skakačem - Kompletna modul',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Opis tutorijala (opciono)',
                    hintText: 'Kratak opis zadataka...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: isAddingFromLibrary
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.collections_bookmark_outlined,
                            size: 16),
                    // One way in, over all three shelves. The two lists that
                    // used to be here could not see the scanner's positions,
                    // so a diagram out of a book could never enter a lesson.
                    label: const Text('Dodaj iz biblioteke'),
                    onPressed: isAddingFromLibrary ? null : _addFromLibrary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (selectedPositions.isNotEmpty) ...[
                  const Text(
                    'Redosled koraka (prevuci da promeniš):',
                    style: AppText.bodyBold,
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      itemCount: selectedPositions.length,
                      // onReorderItem (unlike the deprecated onReorder) already
                      // adjusts newIndex for the removed item at oldIndex.
                      onReorderItem: (oldIndex, newIndex) {
                        setState(() {
                          final item = selectedPositions.removeAt(oldIndex);
                          selectedPositions.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final item = selectedPositions[index];
                        // Steps written before the library existed carry the
                        // whole saved-lesson row, so the id is not a reliable
                        // mark of origin. Variations are: a step with a PGN
                        // came from a tree, one without is a single board.
                        final hasVariations =
                            item['pgn']?.toString().isNotEmpty == true;
                        return Card(
                          key: ValueKey(identityHashCode(item)),
                          margin: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxs),
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              hasVariations
                                  ? Icons.biotech
                                  : Icons.push_pin_outlined,
                              color: hasVariations
                                  ? colors.accent
                                  : colors.textMuted,
                              size: 18,
                            ),
                            title: Text(
                              '${index + 1}. ${item['title'] ?? ''}',
                              style: AppText.bodyBold,
                            ),
                            subtitle: Text(
                              item['instruction']?.toString().isNotEmpty == true
                                  ? item['instruction'].toString()
                                  : 'bez zadatka — učenik neće znati šta se traži',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: item['instruction'] == null
                                    ? colors.warning
                                    : colors.textMuted,
                                fontStyle: item['instruction'] == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18, color: context.colors.danger),
                                  tooltip: 'Ukloni',
                                  onPressed: () => setState(
                                      () => selectedPositions.removeAt(index)),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(Icons.drag_handle,
                                      size: 18, color: colors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
        if (isEditing)
          OutlinedButton(
            onPressed: isSaving ? null : () => _submit(asNew: true),
            child: const Text('Sačuvaj kao novu'),
          ),
        ElevatedButton(
          onPressed: isSaving ? null : () => _submit(asNew: !isEditing),
          child: isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEditing ? 'Sačuvaj izmene' : 'Sačuvaj tutorijal'),
        ),
      ],
    );
  }
}
