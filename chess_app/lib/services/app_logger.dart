import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static final List<String> _logs = [];
  static const int _maxLogs = 5000;
  static ValueNotifier<int> logUpdateNotifier = ValueNotifier<int>(0);

  static void log(String message, {String name = 'App'}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = '[$timestamp] [$name] $message';

    // 1. Output to system / developer log
    developer.log(message, name: name);
    if (kDebugMode) {
      debugPrint(logLine);
    }

    // 2. Add to in-app memory log buffer
    _logs.add(logLine);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    logUpdateNotifier.value++;
  }

  static List<String> get logs => List.unmodifiable(_logs);

  static void clear() {
    _logs.clear();
    logUpdateNotifier.value++;
  }

  static String get formattedLogs => _logs.join('\n');
}
