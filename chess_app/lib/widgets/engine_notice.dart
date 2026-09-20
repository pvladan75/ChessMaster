import 'package:flutter/material.dart';

import 'package:chess_app/services/engine_silence.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Says on the screen that the engine is not answering — whichever screen.
///
/// Sits above the router in `main.dart` for the reason everything else up
/// there does: six screens use the engine, and a sentence taught to one of
/// them is a sentence the other five never say. [EngineSilence] changes only
/// when the answer changes, so this speaks once per fault, not once per
/// timeout.
class EngineNotice extends StatefulWidget {
  const EngineNotice({super.key, required this.child, this.silence});

  final Widget child;

  /// Defaults to the one the service feeds; a test passes its own.
  final EngineSilence? silence;

  @override
  State<EngineNotice> createState() => _EngineNoticeState();
}

class _EngineNoticeState extends State<EngineNotice> {
  late final EngineSilence _silence = widget.silence ?? EngineSilence.instance;

  @override
  void initState() {
    super.initState();
    _silence.addListener(_say);
  }

  @override
  void dispose() {
    _silence.removeListener(_say);
    super.dispose();
  }

  void _say() {
    final problem = _silence.value;
    if (problem == null || !mounted) return;
    AppFeedback.warning(context, problem);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
