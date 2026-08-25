import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Dialogs used by [AnalysisStudioScreen] that are pure UI: they read whatever
/// they need from their parameters and report the result back through a
/// callback rather than touching the screen's state directly. Keeping them
/// here (instead of as private methods on the State) is what keeps the
/// screen file from re-growing every time a toolbar dialog changes.

void showCommentDialog(
    BuildContext context, String initialComment, ValueChanged<String> onSaved) {
  final controller = TextEditingController(text: initialComment);
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Text('Dodaj / Izmeni Komentar',
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        maxLines: 4,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Unesite zabelešku ili analitički komentar...',
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.black45,
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Otkaži'),
          onPressed: () => Navigator.pop(ctx),
        ),
        ElevatedButton(
          child: const Text('Sačuvaj'),
          onPressed: () {
            onSaved(controller.text.trim());
            Navigator.pop(ctx);
          },
        ),
      ],
    ),
  );
}

/// Comment editor: a free-text field plus two checklists of candidate
/// findings — tactical ([TacticalMotifDetector]) and positional
/// ([PositionalEvaluatorService]) — the user toggles individually instead of
/// keeping or discarding the whole comment as one block.
///
/// [initialComment] is a ' | '-joined string (see how comments get built
/// throughout the analysis feature); whichever of its parts still match a
/// currently-available candidate come back pre-checked here, and anything
/// left over (the user's own note, or a clause whose exact wording no
/// longer matches — e.g. after an app update) lands in the free-text field
/// instead of being silently dropped.
void showManualCommentDialog(
  BuildContext context,
  String initialComment,
  List<String> tacticalCandidates,
  List<String> positionalCandidates,
  ValueChanged<String> onSaved,
) {
  final existingParts = initialComment
      .split(' | ')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final selectedTactical = <String>{
    ...tacticalCandidates.where(existingParts.contains)
  };
  final selectedPositional = <String>{
    ...positionalCandidates.where(existingParts.contains)
  };
  final leftoverText = existingParts
      .where((p) =>
          !selectedTactical.contains(p) && !selectedPositional.contains(p))
      .join(' | ');
  final freeTextController = TextEditingController(text: leftoverText);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        Widget buildChecklist(
            String title, List<String> candidates, Set<String> selected,
            {required String emptyHint}) {
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 4),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      emptyHint,
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  )
                else
                  ...candidates.map((line) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        visualDensity: VisualDensity.compact,
                        title: Text(line,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        value: selected.contains(line),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(line);
                            } else {
                              selected.remove(line);
                            }
                          });
                        },
                      )),
              ],
            ),
          );
        }

        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Dodaj / Izmeni Komentar',
              style: TextStyle(color: Colors.white)),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: freeTextController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Sopstveni komentar (opciono)...',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Plain Row, not IntrinsicHeight — IntrinsicHeight forces
                  // every CheckboxListTile in both columns to the height of
                  // the *tallest* column's own intrinsic-height computation,
                  // which undercounts wrapped multi-line finding text (a
                  // known Flutter/Material ListTile quirk) and produced a
                  // few-pixel RenderFlex overflow whenever a long finding
                  // was present. Each column just sizing to its own natural
                  // height (letting the outer SingleChildScrollView absorb
                  // any excess) has no such mismatch.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildChecklist(
                        'Taktički motivi',
                        tacticalCandidates,
                        selectedTactical,
                        emptyHint: 'Nema taktičkih nalaza za ovaj potez.',
                      ),
                      const SizedBox(width: 16),
                      buildChecklist(
                        'Pozicioni faktori',
                        positionalCandidates,
                        selectedPositional,
                        emptyHint: 'Nema pozicionih nalaza za ovaj potez.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Otkaži'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: const Text('Sačuvaj'),
              onPressed: () {
                // Preserve each checklist's own order rather than click order.
                final chosen = [
                  ...tacticalCandidates.where(selectedTactical.contains),
                  ...positionalCandidates.where(selectedPositional.contains),
                ];
                final parts = <String>[
                  if (freeTextController.text.trim().isNotEmpty)
                    freeTextController.text.trim(),
                  ...chosen,
                ];
                onSaved(parts.join(' | '));
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    ),
  );
}

void showNagSelector(BuildContext context, ValueChanged<String?> onSelected) {
  final nags = ['!!', '!', '?', '??', '!?', '!□', 'clear'];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.grey.shade900,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 8,
            children: nags.map((n) {
              return ActionChip(
                label: Text(n == 'clear' ? 'Ukloni NAG' : n,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor:
                    n == 'clear' ? Colors.red.shade900 : Colors.teal.shade900,
                labelStyle: const TextStyle(color: Colors.white),
                onPressed: () {
                  onSelected(n == 'clear' ? null : n);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      );
    },
  );
}

void showLogsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Logovi Engine-a 📜',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 20),
            tooltip: 'Očisti logove',
            onPressed: () {
              AppLogger.clear();
              (ctx as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: ValueListenableBuilder<int>(
          valueListenable: AppLogger.logUpdateNotifier,
          builder: (context, _, __) {
            final logs = AppLogger.logs;
            if (logs.isEmpty) {
              return const Center(
                child: Text('Nema zabeleženih logova.',
                    style: TextStyle(color: Colors.grey)),
              );
            }
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  logs.join('\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Kopiraj Logove'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, foregroundColor: Colors.white),
          onPressed: () async {
            await Clipboard.setData(
                ClipboardData(text: AppLogger.formattedLogs));
            if (ctx.mounted) {
              AppFeedback.show(
                ctx,
                () => const SnackBar(
                    content: Text('✅ Logovi kopirani u klipbord!'),
                    backgroundColor: Colors.teal),
              );
            }
          },
        ),
        TextButton(
          child: const Text('Zatvori'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

Future<void> exportPgnDialog(
    BuildContext context, AnalysisNode rootNode) async {
  final pgnText = PgnExporterService.exportToPgn(rootNode);
  await PgnExporterService.copyToClipboard(pgnText);

  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title: const Row(
        children: [
          Icon(Icons.file_download, color: Colors.lightBlueAccent),
          SizedBox(width: 8),
          Text('Izvezeni PGN Tekst',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: SelectableText(
            pgnText,
            style: const TextStyle(
                color: Colors.white, fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Zatvori'),
          onPressed: () => Navigator.pop(ctx),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Kopirano u Klipbord!'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

/// "Replace the current unsaved tree with this saved one?" guard shown before
/// loading a saved analysis over whatever is currently on the board.
Future<bool> confirmReplaceAnalysisDialog(
    BuildContext context, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title:
          const Text('Učitaj analizu?', style: TextStyle(color: Colors.white)),
      content: Text(
        'Trenutno stablo analize (nesačuvano) će biti zamenjeno sa "$title".',
        style: const TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
            child: const Text('Otkaži'),
            onPressed: () => Navigator.pop(ctx, false)),
        ElevatedButton(
            child: const Text('Učitaj'),
            onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return confirmed == true;
}

/// Prompts for a title and persists [rootNode] server-side. Self-contained —
/// saving never touches the screen's live tree, so it needs no callback back
/// into the caller beyond the snackbar it shows itself.
Future<void> promptSaveAnalysisDialog(
  BuildContext context, {
  required AnalysisNode rootNode,
  required UserSession userSession,
}) async {
  final controller = TextEditingController(
    text:
        'Analiza ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}.',
  );
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey.shade900,
      title:
          const Text('Sačuvaj analizu', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Naziv analize',
          hintStyle: TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.black45,
        ),
      ),
      actions: [
        TextButton(
            child: const Text('Otkaži'), onPressed: () => Navigator.pop(ctx)),
        ElevatedButton(
          child: const Text('Sačuvaj'),
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
        ),
      ],
    ),
  );

  if (title == null || title.isEmpty) return;

  final result = await AnalysisPersistenceService.instance.saveAnalysis(
    title: title,
    rootNode: rootNode,
    userToken: userSession.token,
  );

  if (!context.mounted) return;
  AppFeedback.show(
    context,
    () => SnackBar(
      content: Text(result != null
          ? '✅ Analiza "${result.title}" sačuvana.'
          : '⚠️ Čuvanje nije uspelo. Proverite konekciju.'),
      backgroundColor: result != null ? Colors.teal : Colors.red,
    ),
  );
}

/// Entry point for the cloud icon: lets the user save the current tree or
/// browse/load/delete previously saved ones. Requires a logged-in account
/// since the data lives server-side, scoped to the user.
///
/// [onLoad] is invoked with the summary the user tapped; it owns applying the
/// loaded tree to the live screen (that mutation stays on the State, since it
/// also has to reset the engine and the board controller).
void showSavedAnalysesDialog(
  BuildContext context, {
  required UserSession userSession,
  required AnalysisNode rootNode,
  required ValueChanged<SavedAnalysisSummary> onLoad,
}) {
  if (userSession.isGuest) {
    AppFeedback.show(
      context,
      () => const SnackBar(
        content: Text('Čuvanje analize zahteva prijavljen nalog.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        Future<List<SavedAnalysisSummary>>? future = AnalysisPersistenceService
            .instance
            .listSavedAnalyses(userToken: userSession.token);

        void refresh() {
          setDialogState(() {
            future = AnalysisPersistenceService.instance
                .listSavedAnalyses(userToken: userSession.token);
          });
        }

        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Row(
            children: [
              Icon(Icons.cloud_outlined, color: Colors.lightBlueAccent),
              SizedBox(width: 8),
              Text('Sačuvane analize',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Sačuvaj trenutnu analizu'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await promptSaveAnalysisDialog(context,
                          rootNode: rootNode, userSession: userSession);
                    },
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: FutureBuilder<List<SavedAnalysisSummary>>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return const Center(
                          child: Text('Nema sačuvanih analiza.',
                              style: TextStyle(color: Colors.grey)),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Colors.white12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.title,
                                style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              '${item.createdAt.day.toString().padLeft(2, '0')}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.year}. ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 20),
                              tooltip: 'Obriši',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (confirmCtx) => AlertDialog(
                                    backgroundColor: Colors.grey.shade900,
                                    title: const Text('Obriši analizu?',
                                        style: TextStyle(color: Colors.white)),
                                    content: Text(
                                        '"${item.title}" će biti trajno obrisana.',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                    actions: [
                                      TextButton(
                                          child: const Text('Otkaži'),
                                          onPressed: () =>
                                              Navigator.pop(confirmCtx, false)),
                                      TextButton(
                                        child: const Text('Obriši',
                                            style: TextStyle(
                                                color: Colors.redAccent)),
                                        onPressed: () =>
                                            Navigator.pop(confirmCtx, true),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  final ok = await AnalysisPersistenceService
                                      .instance
                                      .deleteAnalysis(
                                          id: item.id,
                                          userToken: userSession.token);
                                  if (ok) refresh();
                                }
                              },
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              onLoad(item);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                child: const Text('Zatvori'),
                onPressed: () => Navigator.pop(ctx)),
          ],
        );
      },
    ),
  );
}
