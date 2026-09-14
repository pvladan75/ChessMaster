/// Notices that the computer was asleep — phase 2 of `docs/PLAN-SKELET.md`.
///
/// Phase 0 met this the ordinary way: a laptop's battery ran out in the middle
/// of a game, and when it woke every search in flight had passed its timeout.
/// Those searches did nothing wrong, and a build that counted them against its
/// one retry would tell a trainer the engine failed.
///
/// **A heartbeat against the wall clock.** A timer ticks every [tick]; each
/// tick compares the wall clock with the previous one, and a gap longer than
/// [threshold] is a sleep. It does not matter whether the platform's monotonic
/// clock counts time asleep: either the tick fires the moment the machine wakes
/// or a second later, and in both cases the wall clock has jumped.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

class SleepWatch {
  SleepWatch({
    DateTime Function()? now,
    this.tick = const Duration(seconds: 1),
    this.threshold = const Duration(seconds: 30),
  }) : _now = now ?? clock.now;

  final DateTime Function() _now;
  final Duration tick;
  final Duration threshold;

  Timer? _timer;
  DateTime? _last;
  int _sleeps = 0;

  /// How many sleeps have been noticed since [start].
  int get sleeps => _sleeps;

  void start() {
    _last = _now();
    _timer ??= Timer.periodic(tick, (_) => check());
  }

  @visibleForTesting
  void check() {
    final now = _now();
    final last = _last;
    if (last != null && now.difference(last) > threshold) _sleeps++;
    _last = now;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
