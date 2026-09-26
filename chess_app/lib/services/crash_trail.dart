import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

/// What the app was doing just before a native crash — read from disk, in
/// minutes, rather than guessed at from a minidump alone.
///
/// docs/PLAN-FORENZIKA-PADA.md, phase 1. A native crash (the Windows engine
/// fault of 20–22.9.2026, `AccessibilityBridge::SetRoleFromFlutterUpdate`)
/// kills the process before Dart runs again, so every entry is written
/// **synchronously**, at the moment it happens — never batched, never
/// debounced, never merely started. A ring of the last 40 lines goes to
/// `<application support>/crash_logs/trail.log`. Nothing here may throw into
/// the path it observes: a directory that cannot be written costs nothing.
class CrashTrail {
  CrashTrail._();

  /// The one instance the app shares; a test resets it with [resetForTest]
  /// rather than making a second one.
  static final CrashTrail instance = CrashTrail._();

  static const int _ringCap = 40;
  static const String _dirName = 'crash_logs';
  static const String _fileName = 'trail.log';
  static const String _previousFileName = 'trail-previous.log';

  final List<String> _ring = <String>[];
  final List<String> _buffer = <String>[];
  Directory? _support;
  bool _tapsStarted = false;
  GoRouter? _watching;
  String? _lastRoute;

  /// How many entries wait for the directory — the one thing the cap on the
  /// buffer changes, since [init] trims what it flushes to the ring anyway.
  @visibleForTesting
  int get pendingForTest => _buffer.length;

  /// The `GoRouter` last handed to [watched], so the app's wiring can be
  /// checked against it.
  GoRouter? get watching => _watching;

  /// Writes `push <name>` / `pop <name>` (and `remove`/`replace`, cheaply)
  /// for every route change on the `Navigator` it is given to.
  late final NavigatorObserver observer = _CrashTrailObserver(this);

  /// Reads the support directory (once, at start) and moves any trail left by
  /// a previous run aside before anything new is written to it. Entries
  /// recorded before this finishes are buffered and flushed here.
  Future<void> init({Future<Directory> Function()? supportDirectory}) async {
    try {
      final dir = await (supportDirectory ?? getApplicationSupportDirectory)();
      final logsDir = Directory('${dir.path}${Platform.pathSeparator}'
          '$_dirName');
      logsDir.createSync(recursive: true);
      final trail = File('${logsDir.path}${Platform.pathSeparator}'
          '$_fileName');
      final previous = File('${logsDir.path}${Platform.pathSeparator}'
          '$_previousFileName');
      // The last run's trail is kept apart: a run that crashed left the
      // trail worth reading here, and the first route of the new run must
      // not overwrite it.
      if (trail.existsSync()) {
        if (previous.existsSync()) previous.deleteSync();
        trail.renameSync(previous.path);
      }
      _support = dir;
      if (_buffer.isNotEmpty) {
        _ring.addAll(_buffer);
        _buffer.clear();
        if (_ring.length > _ringCap) {
          _ring.removeRange(0, _ring.length - _ringCap);
        }
      }
      _writeSync();
    } catch (_) {
      // A directory that cannot be read or written costs nothing; the app
      // never waits on this and never fails because of it.
    }
  }

  /// Adds one line, timestamped now, to the ring and rewrites the file
  /// synchronously. Buffered instead when the directory is not known yet.
  void record(String entry) {
    try {
      final line = '${DateTime.now().toUtc().toIso8601String()} $entry';
      if (_support == null) {
        // Capped like the ring: a directory that never comes (a platform
        // call that fails, a test that never calls init) must not grow this
        // for the life of the process.
        _buffer.add(line);
        if (_buffer.length > _ringCap) {
          _buffer.removeRange(0, _buffer.length - _ringCap);
        }
        return;
      }
      _ring.add(line);
      if (_ring.length > _ringCap) {
        _ring.removeRange(0, _ring.length - _ringCap);
      }
      _writeSync();
    } catch (_) {
      // Do the thing, then say it — never the other way round, and never at
      // the cost of throwing into the caller's path.
    }
  }

  void _writeSync() {
    try {
      final support = _support;
      if (support == null) return;
      final logsDir = Directory('${support.path}${Platform.pathSeparator}'
          '$_dirName');
      if (!logsDir.existsSync()) logsDir.createSync(recursive: true);
      final file = File('${logsDir.path}${Platform.pathSeparator}'
          '$_fileName');
      file.writeAsStringSync('${_ring.join('\n')}\n');
    } catch (_) {}
  }

  /// A whole file beside the log, for what one line cannot hold — the update
  /// the engine's model could not settle (phase 2b), kept so the next
  /// session can replay it. Synchronous and silent, like the rest.
  void recordAside(String name, String content) {
    try {
      final support = _support;
      if (support == null) return;
      File('${support.path}${Platform.pathSeparator}$_dirName'
              '${Platform.pathSeparator}$name')
          .writeAsStringSync(content, flush: true);
    } catch (_) {}
  }

  /// [record], and the same line appended to `crash_logs/crash.log` with the
  /// route the trail last saw — for what must outlive the ring: the trail
  /// keeps 40 lines, and a crash can come many taps after the line that
  /// explains it. Synchronous, like [record]; `CrashBreadcrumbService`
  /// resolves its directory asynchronously, so it cannot write this.
  void recordLasting(String entry) {
    record(entry);
    try {
      final support = _support;
      if (support == null) return;
      final now = DateTime.now().toUtc().toIso8601String();
      File('${support.path}${Platform.pathSeparator}$_dirName'
              '${Platform.pathSeparator}crash.log')
          .writeAsStringSync(
        '[$now] $entry (route ${_lastRoute ?? '?'})\n---\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  /// Wraps [router] so every change of its current location writes
  /// `route <uri>`. Returns the same router, so it can be assigned in place.
  GoRouter watched(GoRouter router) {
    router.routerDelegate.addListener(() {
      _lastRoute = '${router.routerDelegate.currentConfiguration.uri}';
      record('route $_lastRoute');
    });
    _watching = router;
    return router;
  }

  /// Starts watching every pointer-down for a tap to name. Idempotent — the
  /// app calls this once at start, and a test may call it again per case
  /// without adding a second listener.
  void startTaps() {
    if (_tapsStarted) return;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointer);
    _tapsStarted = true;
  }

  void _handlePointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    try {
      final result = HitTestResult();
      GestureBinding.instance
          .hitTestInView(result, event.position, event.viewId);
      final label = _labelFor(result);
      record(label != null ? 'tap "$label"' : 'tap ?');
    } catch (_) {}
  }

  static String? _labelFor(HitTestResult result) {
    // The first RenderParagraph on the hit path is a button's text — unless
    // it is an icon glyph, which is a RenderParagraph too and sits first on
    // the hit path of an IconButton.
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderParagraph) {
        final text = target.text.toPlainText();
        if (_isRealText(text)) return _cut(text);
      }
    }
    // Otherwise the nearest ancestor with a tooltip or label — an icon
    // button's own Tooltip attaches one of these.
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderSemanticsAnnotations) {
        final tooltip = target.properties.tooltip;
        if (tooltip != null && tooltip.isNotEmpty) return _cut(tooltip);
        final label = target.properties.label;
        if (label != null && label.isNotEmpty) return _cut(label);
      }
    }
    return null;
  }

  /// Text made only of private-use characters (U+E000–U+F8FF) is an icon
  /// glyph, not a name.
  static bool _isRealText(String text) {
    if (text.trim().isEmpty) return false;
    for (final code in text.runes) {
      if (code < 0xE000 || code > 0xF8FF) return true;
    }
    return false;
  }

  static String _cut(String text) =>
      text.length <= 60 ? text : text.substring(0, 60);

  /// Clears the ring and buffer and deletes both files — the trail goes with
  /// the account, like the drafts ([AccountLocalState.clear]).
  Future<void> forget() async {
    try {
      _ring.clear();
      _buffer.clear();
      final support = _support;
      if (support == null) return;
      final logsDir = Directory('${support.path}${Platform.pathSeparator}'
          '$_dirName');
      final trail = File('${logsDir.path}${Platform.pathSeparator}'
          '$_fileName');
      final previous = File('${logsDir.path}${Platform.pathSeparator}'
          '$_previousFileName');
      if (trail.existsSync()) trail.deleteSync();
      if (previous.existsSync()) previous.deleteSync();
    } catch (_) {}
  }

  /// Clears the ring, the buffer and the known directory, and removes the tap
  /// route so the next case starts from nothing. Leaves [watching] alone —
  /// the app router is wrapped once, at start.
  @visibleForTesting
  void resetForTest() {
    _ring.clear();
    _buffer.clear();
    _support = null;
    if (_tapsStarted) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointer);
      _tapsStarted = false;
    }
  }
}

class _CrashTrailObserver extends NavigatorObserver {
  _CrashTrailObserver(this._trail);

  final CrashTrail _trail;

  String _nameOf(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    // A MaterialPageRoute (or any other PageRoute built with a `builder:`)
    // prints its builder's runtime type as `(BuildContext) => Screen`; the
    // part after `=> ` is the screen's name.
    final fromBuilder = _nameFromBuilder(route);
    if (fromBuilder != null) return fromBuilder;
    return route.runtimeType.toString();
  }

  String? _nameFromBuilder(Route<dynamic> route) {
    try {
      final dynamic dyn = route;
      final builder = dyn.builder;
      if (builder == null) return null;
      final printed = builder.runtimeType.toString();
      const marker = '=> ';
      final index = printed.lastIndexOf(marker);
      if (index == -1) return null;
      return printed.substring(index + marker.length);
    } catch (_) {
      return null;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trail.record('push ${_nameOf(route)}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trail.record('pop ${_nameOf(route)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _trail.record('remove ${_nameOf(route)}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _trail.record('replace ${_nameOf(newRoute)}');
  }
}
