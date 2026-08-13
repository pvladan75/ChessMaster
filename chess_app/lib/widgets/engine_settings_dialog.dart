import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/engine_download_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// True on platforms where a local custom UCI engine (.exe) can be configured.
/// The underlying StockfishService only looks at `custom_engine_path` on
/// Windows, so there is no point offering this UI elsewhere.
bool get isCustomEngineSupported => !kIsWeb && Platform.isWindows;

/// Shared "local engine" settings dialog: lets the user pick a UCI-compatible
/// .exe manually, download an official Stockfish build automatically, or
/// reset back to the built-in engine. Used from the in-game analysis panel,
/// Analysis Studio, AI Studio, and the main Settings screen so the local
/// engine can be configured from anywhere, not just mid-session.
Future<void> showEngineSettingsDialog(
  BuildContext context, {
  required StockfishService stockfishService,
  bool isEngineEnabled = false,
}) async {
  if (!isCustomEngineSupported) return;

  final prefs = await SharedPreferences.getInstance();
  if (!context.mounted) return;

  String currentPath = prefs.getString('custom_engine_path') ?? '';
  bool isBusy = false;
  String statusMessage = '';
  double? progress;
  String? errorMessage;

  Future<void> applyChange() async {
    stockfishService.shutdown();
    await AppSettingsService.instance.refreshCustomEnginePath();
    if (isEngineEnabled) {
      await stockfishService.initEngine();
      stockfishService.reactivateTopSubscriber();
    }
  }

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final hasCustom = currentPath.isNotEmpty;

          Future<void> pickManually() async {
            try {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['exe'],
              );
              if (result != null && result.files.single.path != null) {
                final path = result.files.single.path!;
                await prefs.setString('custom_engine_path', path);
                setDialogState(() {
                  isBusy = true;
                  statusMessage = 'Pokretanje engine-a...';
                  progress = null;
                  errorMessage = null;
                });
                await applyChange();
                setDialogState(() {
                  currentPath = path;
                  isBusy = false;
                });
              }
            } catch (e) {
              setDialogState(() {
                isBusy = false;
                errorMessage = 'Greška pri izboru fajla: $e';
              });
            }
          }

          Future<void> downloadAuto() async {
            setDialogState(() {
              isBusy = true;
              statusMessage = 'Priprema preuzimanja...';
              progress = null;
              errorMessage = null;
            });
            try {
              final path = await EngineDownloadService.instance.downloadAndInstall(
                onProgress: (status, p) {
                  setDialogState(() {
                    statusMessage = status;
                    progress = p;
                  });
                },
              );
              setDialogState(() {
                statusMessage = 'Podešavanje engine-a...';
                progress = null;
              });
              await applyChange();
              setDialogState(() {
                currentPath = path;
                isBusy = false;
              });
            } catch (e) {
              setDialogState(() {
                isBusy = false;
                errorMessage = 'Preuzimanje nije uspelo: $e';
              });
            }
          }

          Future<void> reset() async {
            setDialogState(() {
              isBusy = true;
              statusMessage = 'Resetovanje...';
              errorMessage = null;
            });
            await EngineDownloadService.instance.clearCustomEngine();
            await applyChange();
            setDialogState(() {
              currentPath = '';
              isBusy = false;
            });
          }

          return AlertDialog(
            title: const Text('Podešavanja Šahovskog Engine-a'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trenutni engine:', style: AppText.bodyLargeBold),
                  const SizedBox(height: 4),
                  Text(
                    hasCustom
                        ? 'Sopstveni lokalni engine:\n$currentPath'
                        : 'Podrazumevani (Online / FFI paket)',
                    style: AppText.body.copyWith(
                      color: hasCustom ? context.colors.accent : context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isBusy) ...[
                    Text(statusMessage, style: AppText.body),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                  ] else ...[
                    Text(
                      'Preuzmite zvanični Stockfish engine sa interneta i automatski ga podesite, ili izaberite bilo koji UCI kompatibilan .exe sa svog računara.',
                      style: AppText.caption.copyWith(color: context.colors.textMuted),
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: AppText.caption.copyWith(color: context.colors.danger),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (hasCustom && !isBusy)
                TextButton.icon(
                  onPressed: reset,
                  icon: Icon(Icons.delete, color: context.colors.danger, size: 16),
                  label: Text('Resetuj', style: TextStyle(color: context.colors.danger)),
                ),
              if (!isBusy) ...[
                TextButton.icon(
                  onPressed: pickManually,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Izaberi .exe'),
                ),
                ElevatedButton.icon(
                  onPressed: downloadAuto,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Preuzmi automatski'),
                ),
              ],
              TextButton(
                onPressed: isBusy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Zatvori'),
              ),
            ],
          );
        },
      );
    },
  );
}
