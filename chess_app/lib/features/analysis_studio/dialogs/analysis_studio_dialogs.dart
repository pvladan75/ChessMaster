import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
// `debugSavePgnFile` and `pgnFileNameFor` are re-exported so that every test and
// caller that has ever reached them through this file still does: the seam is
// one variable wherever it is imported from.
export 'package:chess_app/features/analysis_studio/services/pgn_file_saver.dart'
    show debugSavePgnFile, pgnFileNameFor, savePgnFile;
import 'package:chess_app/features/analysis_studio/services/pgn_file_saver.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/core/services/finding_sentences.dart';
import 'package:chess_app/theme/app_typography.dart';
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
      title: const Text('Add / Edit Comment'),
      content: TextField(
        controller: controller,
        maxLines: 4,
        style: TextStyle(color: ctx.colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Enter a note or analytical comment...',
          hintStyle: TextStyle(color: ctx.colors.textMuted),
          filled: true,
          fillColor: ctx.colors.canvas,
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(ctx),
        ),
        ElevatedButton(
          child: const Text('Save'),
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
/// [initialComment] is sentences joined by a space ([joinSentences]);
/// whichever candidate sentences it still holds come back pre-checked here,
/// and anything left over (the user's own note, or a comment in a wording
/// that is no longer written — e.g. after an app update) lands in the
/// free-text field instead of being silently dropped.
void showManualCommentDialog(
  BuildContext context,
  String initialComment,
  List<String> tacticalCandidates,
  List<String> positionalCandidates,
  ValueChanged<String> onSaved,
) {
  final split = splitCommentForChecklist(
      initialComment, tacticalCandidates, positionalCandidates);
  final selectedTactical = {...split.tactical};
  final selectedPositional = {...split.positional};
  final freeTextController = TextEditingController(text: split.leftover);

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
                    style: AppText.bodyLargeBold
                        .copyWith(color: ctx.colors.accent)),
                const SizedBox(height: AppSpacing.xs),
                if (candidates.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Text(
                      emptyHint,
                      style: AppText.body.copyWith(
                          color: ctx.colors.textMuted,
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
                            style: AppText.body
                                .copyWith(color: ctx.colors.textPrimary)),
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
          title: const Text('Add / Edit Comment'),
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
                    style: TextStyle(color: ctx.colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Custom comment (optional)...',
                      hintStyle: TextStyle(color: ctx.colors.textMuted),
                      filled: true,
                      fillColor: ctx.colors.canvas,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
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
                        'Tactical motifs',
                        tacticalCandidates,
                        selectedTactical,
                        emptyHint: 'No tactical findings for this move.',
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      buildChecklist(
                        'Positional factors',
                        positionalCandidates,
                        selectedPositional,
                        emptyHint: 'No positional findings for this move.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                // Preserve each checklist's own order rather than click order.
                final chosen = [
                  ...tacticalCandidates.where(selectedTactical.contains),
                  ...positionalCandidates.where(selectedPositional.contains),
                ];
                onSaved(joinSentences([freeTextController.text, ...chosen]));
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
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
            spacing: 8,
            children: nags.map((n) {
              return ActionChip(
                label: Text(n == 'clear' ? 'Remove NAG' : n,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor:
                    n == 'clear' ? ctx.colors.danger : ctx.colors.accent,
                labelStyle: TextStyle(color: ctx.colors.canvas),
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
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, color: ctx.colors.warning),
              const SizedBox(width: AppSpacing.sm),
              Text('Engine Logs 📜',
                  style: AppText.title.copyWith(color: ctx.colors.textPrimary)),
            ],
          ),
          IconButton(
            icon:
                Icon(Icons.delete_outline, color: ctx.colors.danger, size: 20),
            tooltip: 'Clear logs',
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
              return Center(
                child: Text('No logs recorded.',
                    style: AppText.body.copyWith(color: ctx.colors.textMuted)),
              );
            }
            return Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: ctx.colors.canvas,
                borderRadius: AppRadii.roundedSm,
                border: Border.all(color: ctx.colors.surfaceRaised),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: SelectableText(
                  logs.join('\n'),
                  style: AppText.caption.copyWith(
                    fontFamily: 'monospace',
                    color: ctx.colors.success,
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
          label: const Text('Copy Logs'),
          style: ElevatedButton.styleFrom(
              backgroundColor: ctx.colors.accent,
              foregroundColor: ctx.colors.canvas),
          onPressed: () async {
            await Clipboard.setData(
                ClipboardData(text: AppLogger.formattedLogs));
            if (ctx.mounted) {
              AppFeedback.show(
                ctx,
                () => SnackBar(
                    content: Text('✅ Logs copied to clipboard!',
                        style: TextStyle(color: ctx.colors.canvas)),
                    backgroundColor: ctx.colors.accent),
              );
            }
          },
        ),
        TextButton(
          child: const Text('Close'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

Future<void> exportPgnDialog(
    BuildContext context, AnalysisNode rootNode) async {
  final pgnText = PgnExporterService.exportToPgn(rootNode);

  // Not awaited, and that is the fix rather than the shortcut. The clipboard is
  // a platform channel: awaiting it in front of `showDialog` means the dialog
  // opens only once the channel answers — never, in a widget test, and late on
  // a machine where the channel is slow. CLAUDE.md already records this shape
  // from the export sheet, where awaiting `path_provider` stopped twelve tests
  // from seeing the dialog at all.
  //
  // The failure is logged rather than raised: a copy that did not happen must
  // not take down the dialog that was showing the text, which is the other
  // rule this repository keeps paying for.
  unawaited(PgnExporterService.copyToClipboard(pgnText)
      .catchError((Object e) => AppLogger.log('[PGN] not copied: $e')));

  if (!context.mounted) return;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_download, color: ctx.colors.info),
          const SizedBox(width: AppSpacing.sm),
          // Flexible, so the words wrap on a narrow phone instead of being
          // clipped: an icon beside a Text that cannot shrink is the shape
          // this repository has already found unreachable three times, and a
          // release build draws no stripes over it — it just cuts the end off.
          Flexible(
            child: Text('Exported PGN Text',
                style: AppText.title.copyWith(color: ctx.colors.textPrimary)),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: SelectableText(
            pgnText,
            style: AppText.body.copyWith(
                color: ctx.colors.textPrimary, fontFamily: 'monospace'),
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Close'),
          onPressed: () => Navigator.pop(ctx),
        ),
        TextButton.icon(
          key: const Key('export-pgn-save-file'),
          icon: const Icon(Icons.save_alt, size: 16),
          label: const Text('Save as .pgn'),
          onPressed: () async {
            final save = debugSavePgnFile ?? savePgnFile;
            String? path;
            try {
              path = await save(
                fileName: pgnFileNameFor(DateTime.now()),
                pgn: pgnText,
              );
            } catch (e) {
              AppLogger.log('[PGN] not saved: $e');
              if (context.mounted) {
                AppFeedback.error(context, 'The file could not be saved.');
              }
              return;
            }
            // Null is the trainer closing the picker, and somebody who
            // cancelled a save does not need to be told they cancelled it.
            if (path == null) return;

            // The dialog goes first and the message second: a SnackBar under
            // an open dialog is dimmed by its own barrier, and this
            // repository has already shipped a refusal that covered the
            // button it was refusing.
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) AppFeedback.success(context, 'Saved: $path');
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          // „Copied to Clipboard!" until 12.9.2026, when a third action joined
          // the row: twenty characters and an icon do not fit one line of a
          // 360 dp dialog, and a button label is the one thing in a row that
          // cannot wrap. The sentence was doing the work of a message anyway —
          // the copy happens when the dialog opens, and this button closes it.
          label: const Text('Copied'),
          style: ElevatedButton.styleFrom(
              backgroundColor: ctx.colors.accent,
              foregroundColor: ctx.colors.canvas),
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
      title: const Text('Load analysis?'),
      content: Text(
        'The current analysis tree (unsaved) will be replaced with "$title".',
        style: AppText.body.copyWith(color: ctx.colors.textMuted),
      ),
      actions: [
        TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false)),
        ElevatedButton(
            child: const Text('Load'),
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
        'Analysis ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
  );
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save analysis'),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: ctx.colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Analysis title',
          hintStyle: TextStyle(color: ctx.colors.textMuted),
          filled: true,
          fillColor: ctx.colors.canvas,
        ),
      ),
      actions: [
        TextButton(
            child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
        ElevatedButton(
          child: const Text('Save'),
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
      content: Text(
        result != null
            ? '✅ Analysis "${result.title}" saved.'
            : '⚠️ Save failed. Check your connection.',
        style: TextStyle(color: context.colors.canvas),
      ),
      backgroundColor:
          result != null ? context.colors.accent : context.colors.danger,
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
      () => SnackBar(
        content: Text('Saving analysis requires a signed-in account.',
            style: TextStyle(color: context.colors.canvas)),
        backgroundColor: context.colors.warning,
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
          title: Row(
            children: [
              Icon(Icons.cloud_outlined, color: ctx.colors.info),
              const SizedBox(width: AppSpacing.sm),
              Text('Saved analyses',
                  style: AppText.title.copyWith(color: ctx.colors.textPrimary)),
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
                    label: const Text('Save current analysis'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ctx.colors.accent,
                        foregroundColor: ctx.colors.canvas),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await promptSaveAnalysisDialog(context,
                          rootNode: rootNode, userSession: userSession);
                    },
                  ),
                ),
                Divider(height: 24, color: ctx.colors.border),
                Expanded(
                  child: FutureBuilder<List<SavedAnalysisSummary>>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return Center(
                          child: Text('No saved analyses.',
                              style: AppText.body
                                  .copyWith(color: ctx.colors.textMuted)),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: ctx.colors.border),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.title,
                                style: AppText.bodyLarge
                                    .copyWith(color: ctx.colors.textPrimary)),
                            subtitle: Text(
                              '${item.createdAt.day.toString().padLeft(2, '0')}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.year}. ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                              style: AppText.caption
                                  .copyWith(color: ctx.colors.textMuted),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: ctx.colors.danger, size: 20),
                              tooltip: 'Delete',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (confirmCtx) => AlertDialog(
                                    title: const Text('Delete analysis?'),
                                    content: Text(
                                        '"${item.title}" will be permanently deleted.',
                                        style: AppText.body.copyWith(
                                            color: ctx.colors.textMuted)),
                                    actions: [
                                      TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () =>
                                              Navigator.pop(confirmCtx, false)),
                                      TextButton(
                                        child: Text('Delete',
                                            style: TextStyle(
                                                color: ctx.colors.danger)),
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
                child: const Text('Close'),
                onPressed: () => Navigator.pop(ctx)),
          ],
        );
      },
    ),
  );
}
