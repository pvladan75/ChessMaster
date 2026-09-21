import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Progress callback: [status] is a short human-readable message, [progress]
/// is 0.0-1.0 for the download step or null for steps without a known size
/// (extraction, verification).
typedef EngineDownloadProgress = void Function(String status, double? progress);

/// Downloads and installs an official Stockfish build for the local machine.
///
/// Only Windows is supported today because that's the only platform the app's
/// "custom local engine" feature (see StockfishService) understands. The
/// build is Stockfish's universal one, which chooses its own CPU code, so it
/// works without asking the user anything about their hardware.
class EngineDownloadService {
  EngineDownloadService._();
  static final EngineDownloadService instance = EngineDownloadService._();

  // Since Stockfish 19 there is one Windows build, which picks the best code
  // for the CPU it runs on; the avx2 / sse41-popcnt / plain tiers this list
  // used to try in turn are no longer published.
  //
  // The release is pinned, not `latest`. `latest/download` followed the newest
  // release, so when 19 came out (5.9.2026) and stopped publishing those asset
  // names, every tier answered 404 and the download failed until noticed on
  // 21.9.2026. Pinned, the name can only change here — and the version then
  // matches the engine built into the Android app
  // (`packages/stockfish/ios/Stockfish/src`), so both platforms analyse alike.
  static const List<String> _windowsBuildTiers = [
    'stockfish-windows-x86-64-universal',
  ];

  static const String _releaseBaseUrl =
      'https://github.com/official-stockfish/Stockfish/releases/download/sf_19';

  bool _busy = false;

  Future<Directory> _engineDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}engine');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Downloads the most compatible working Stockfish build, saves it under
  /// the app's support directory and points `custom_engine_path` at it.
  /// Returns the installed executable path.
  Future<String> downloadAndInstall(
      {EngineDownloadProgress? onProgress}) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
          'Automatic engine download is currently supported only on Windows.');
    }
    if (_busy) {
      throw StateError('Download is already in progress.');
    }
    _busy = true;
    final dir = await _engineDir();
    final zipPath = '${dir.path}${Platform.pathSeparator}download.zip';
    final exePath = '${dir.path}${Platform.pathSeparator}stockfish.exe';
    final errors = <String>[];

    try {
      for (final tier in _windowsBuildTiers) {
        try {
          onProgress?.call('Downloading ($tier)...', 0);
          await _downloadFile('$_releaseBaseUrl/$tier.zip', zipPath, (p) {
            onProgress?.call('Downloading ($tier)...', p);
          });

          onProgress?.call('Extracting...', null);
          final extracted = await _extractExe(zipPath, exePath);
          if (!extracted) {
            errors.add('$tier: archive does not contain a .exe file');
            continue;
          }

          onProgress?.call('Verifying engine...', null);
          final works = await _verifyEngine(exePath);
          if (!works) {
            errors.add('$tier: engine does not run on this computer');
            continue;
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('custom_engine_path', exePath);
          AppLogger.log(
              '[EngineDownloadService] ✅ Installed $tier at $exePath');
          return exePath;
        } catch (e) {
          AppLogger.log('[EngineDownloadService] ⚠️ $tier failed: $e');
          errors.add('$tier: $e');
        } finally {
          final zipFile = File(zipPath);
          if (await zipFile.exists()) {
            await zipFile.delete();
          }
        }
      }

      throw Exception(
          'Failed to download or run any engine version:\n${errors.join('\n')}');
    } finally {
      _busy = false;
    }
  }

  Future<void> _downloadFile(
      String url, String savePath, void Function(double) onProgress) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} for $url');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final file = File(savePath);
      final sink = file.openWrite();
      await response.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) onProgress(received / total);
        return chunk;
      }).pipe(sink);
      await sink.close();
    } finally {
      client.close();
    }
  }

  Future<bool> _extractExe(String zipPath, String exePath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      if (entry.isFile && entry.name.toLowerCase().endsWith('.exe')) {
        final outFile = File(exePath);
        await outFile.writeAsBytes(entry.content as List<int>);
        return true;
      }
    }
    return false;
  }

  /// Launches the engine and waits for a UCI handshake to confirm it can
  /// actually run on this CPU before the path is saved.
  Future<bool> _verifyEngine(String exePath) async {
    Process? process;
    try {
      process = await Process.start(exePath, []);
      final completer = Completer<bool>();
      final sub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.contains('uciok') && !completer.isCompleted) {
          completer.complete(true);
        }
      }, onError: (_) {
        if (!completer.isCompleted) completer.complete(false);
      });

      process.stdin.writeln('uci');
      final exitFuture = process.exitCode.then((_) {
        if (!completer.isCompleted) completer.complete(false);
      });

      final result = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );
      await sub.cancel();
      unawaited(exitFuture);
      return result;
    } catch (e) {
      AppLogger.log('[EngineDownloadService] ❌ Verify failed: $e');
      return false;
    } finally {
      try {
        process?.kill();
      } catch (_) {}
    }
  }

  /// Removes the pref, and if it pointed at a file we downloaded ourselves,
  /// deletes it too so no orphaned binaries pile up.
  Future<void> clearCustomEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('custom_engine_path');
    await prefs.remove('custom_engine_path');
    if (path == null || path.isEmpty) return;

    try {
      final dir = await _engineDir();
      if (path.startsWith(dir.path)) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }
}
