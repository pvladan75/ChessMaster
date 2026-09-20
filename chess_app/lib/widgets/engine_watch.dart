import 'package:flutter/material.dart';

import 'package:chess_app/services/stockfish_service.dart';

/// Tells the engine to quit when the app is torn down under it.
///
/// On Android, leaving the app with Back destroys the activity and the Flutter
/// engine but usually **not the process**. The native engine runs on a thread
/// of that process, blocked reading its standard input, and nothing told it to
/// stop — `StockfishService.shutdown` had one caller, the engine settings
/// dialog. Opened again, the app starts a second engine in the same process;
/// the package points the process's one stdin at a new pipe while the first
/// thread still holds it, so the newcomer prints its banner and then waits
/// behind a reader that will never finish. No `uciok`, no `readyok`, no
/// evaluation, and no error either (owner's report of 20.9.2026, a phone that
/// had just played a homework game against the engine).
///
/// `detached` is the last word the framework gives before that teardown. The
/// quit is a synchronous write into the engine's pipe, so it lands even if
/// this isolate does not live to see anything after it.
class EngineWatch extends StatefulWidget {
  const EngineWatch({super.key, required this.child, this.onDetached});

  final Widget child;

  /// What to do when the app detaches. Defaults to shutting the engine down;
  /// a test passes its own.
  final VoidCallback? onDetached;

  @override
  State<EngineWatch> createState() => _EngineWatchState();
}

class _EngineWatchState extends State<EngineWatch> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.detached) return;
    (widget.onDetached ?? StockfishService().shutdown)();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
