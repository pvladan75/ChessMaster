import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// The app's log line: the developer log always, and the console in a debug
/// build.
///
/// It also kept the last 5000 lines in memory, for the „Engine Logs" dialog
/// on the Analysis bar — a tool from the weeks the engine's start-up was being
/// debugged. The dialog went on 30.9.2026 on the owner's word, and the buffer
/// went with it: nothing else read it.
class AppLogger {
  static void log(String message, {String name = 'App'}) {
    developer.log(message, name: name);
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String().substring(11, 19);
      debugPrint('[$timestamp] [$name] $message');
    }
  }
}
