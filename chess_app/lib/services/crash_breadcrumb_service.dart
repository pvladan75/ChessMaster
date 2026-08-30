import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:chess_app/core/build_info.dart';

class CrashBreadcrumbService {
  CrashBreadcrumbService._();
  static final CrashBreadcrumbService instance = CrashBreadcrumbService._();

  static const int _maxSizeBytes = 256 * 1024; // 256 KB

  Future<Directory> Function()? _testDirectory;
  @visibleForTesting
  void setTestDirectory(Future<Directory> Function()? testDirectory) {
    _testDirectory = testDirectory;
  }

  Future<File> _logFile() async {
    final support = _testDirectory != null
        ? await _testDirectory!()
        : await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}crash_logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}crash.log');
  }

  Future<void> recordError(Object error, StackTrace stack) async {
    try {
      final file = await _logFile();
      final now = DateTime.now().toUtc().toIso8601String();
      final label = buildLabel();
      final platform = Platform.operatingSystem;
      final platformVersion = Platform.operatingSystemVersion;

      final entry =
          '[$now] [$label] [$platform $platformVersion]\n$error\n$stack\n---\n';

      await file.writeAsString(entry, mode: FileMode.append);

      final stat = await file.stat();
      if (stat.size > _maxSizeBytes) {
        final lines = await file.readAsLines();
        final remaining = lines.sublist(lines.length ~/ 2);
        await file.writeAsString('${remaining.join('\n')}\n');
      }
    } catch (_) {
      // Must not throw
    }
  }

  void recordFlutterError(FlutterErrorDetails details) {
    recordError(details.exception, details.stack ?? StackTrace.empty);
  }

  /// Records, and says nothing about whether the error was handled. The caller
  /// decides that — see `main.dart`, which deliberately does not claim it.
  void recordPlatformError(Object error, StackTrace stack) {
    recordError(error, stack);
  }
}
