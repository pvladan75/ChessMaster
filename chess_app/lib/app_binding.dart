import 'package:flutter/widgets.dart';

import 'package:chess_app/services/semantics_shadow.dart';

/// The app's own binding: [WidgetsFlutterBinding] with [OrphanWatch] mixed
/// in, so every semantics update the app sends is checked against the
/// Windows engine's own rule before it leaves `build()`.
/// docs/PLAN-FORENZIKA-PADA.md, phase 2.
///
/// A pure mixin-application (`class AppBinding = WidgetsFlutterBinding with
/// OrphanWatch;`) cannot carry [ensureInitialized] — a class alias has no
/// body — so this is written the way [WidgetsFlutterBinding] itself is:
/// [WidgetsFlutterBinding.ensureInitialized].
class AppBinding extends WidgetsFlutterBinding with OrphanWatch {
  static AppBinding? _instance;

  AppBinding() {
    _instance = this;
  }

  /// Creates the binding if nothing has, exactly as
  /// [WidgetsFlutterBinding.ensureInitialized] does — `main()` calls this
  /// instead, so the app's binding is the one with the orphan watch, from the
  /// first frame.
  static WidgetsBinding ensureInitialized() {
    if (_instance == null) {
      AppBinding();
    }
    return WidgetsBinding.instance;
  }
}
