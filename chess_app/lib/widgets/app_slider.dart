import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// The app's one slider — every slider in `lib/` is this one.
///
/// Why not Flutter's [Slider]: on Flutter 3.47 a Material slider keeps an
/// `OverlayPortal` open for its value bubble at all times, and when the slider
/// arrives with a new route — a dialog, a sheet, a popup menu, a pushed screen,
/// which is everywhere this app has one — the framework sends that overlay's
/// semantics node one update before the node it is grafted under. Windows
/// refuses such an update, its accessibility tree stays broken from then on,
/// and a few updates later the engine reads freed memory and the app dies
/// (22.9.2026, `AccessibilityBridge::SetRoleFromFlutterUpdate`;
/// flutter/flutter#190357). It happens whenever a UI Automation client is
/// attached — Narrator, and the touch keyboard. `ShowValueIndicator.never`
/// does not help: the overlay stays, only its content goes.
///
/// So this slider draws itself, bubble included, inside its own box and needs
/// no overlay. It takes exactly the parameters the app used on [Slider].
/// `test/app_slider_test.dart` holds its behaviour and
/// `test/move_tree_semantics_orphan_test.dart` the reason it exists.
class AppSlider extends StatefulWidget {
  const AppSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    this.activeColor,
  })  : assert(min < max),
        assert(divisions == null || divisions > 0);

  final double value;
  final double min;
  final double max;

  /// Discrete steps between [min] and [max]; null for a continuous slider.
  final int? divisions;

  /// Shown in a bubble above the thumb while it is dragged. A screen reader
  /// hears a percentage, as with [Slider]: the label names only the current
  /// value, and the value it would step to must be read the same way.
  final String? label;

  /// Null disables the slider.
  final ValueChanged<double>? onChanged;

  /// The track and thumb. Defaults to the theme's primary colour, as [Slider].
  final Color? activeColor;

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  /// Room at each end of the track for the thumb and its halo, as [Slider].
  static const double _pad = 24.0;
  static const double _height = 48.0;

  bool _dragging = false;
  bool _hovering = false;
  bool _focused = false;

  bool get _enabled => widget.onChanged != null;

  double get _fraction =>
      ((widget.value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);

  /// One keyboard or screen-reader step: a division, or a twentieth.
  double get _step => (widget.max - widget.min) / (widget.divisions ?? 20);

  double _snap(double v) {
    final clamped = v.clamp(widget.min, widget.max);
    final divisions = widget.divisions;
    if (divisions == null) return clamped;
    final step = (widget.max - widget.min) / divisions;
    return widget.min + ((clamped - widget.min) / step).round() * step;
  }

  void _emit(double v) {
    final next = _snap(v);
    if (next != widget.value) widget.onChanged?.call(next);
  }

  void _toPosition(double dx, double width) {
    final track = (width - 2 * _pad).clamp(1.0, double.infinity);
    final t = ((dx - _pad) / track).clamp(0.0, 1.0);
    _emit(widget.min + t * (widget.max - widget.min));
  }

  String _spoken(double v) =>
      '${(((v - widget.min) / (widget.max - widget.min)) * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _enabled
        ? (widget.activeColor ?? theme.colorScheme.primary)
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    final up = _snap(widget.value + _step);
    final down = _snap(widget.value - _step);

    return Semantics(
      container: true,
      slider: true,
      enabled: _enabled,
      value: _spoken(widget.value),
      increasedValue: _spoken(up),
      decreasedValue: _spoken(down),
      onIncrease: _enabled ? () => _emit(widget.value + _step) : null,
      onDecrease: _enabled ? () => _emit(widget.value - _step) : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: _enabled,
          mouseCursor:
              _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onShowHoverHighlight: (v) => setState(() => _hovering = v),
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowRight): _Nudge(1),
            SingleActivator(LogicalKeyboardKey.arrowUp): _Nudge(1),
            SingleActivator(LogicalKeyboardKey.arrowLeft): _Nudge(-1),
            SingleActivator(LogicalKeyboardKey.arrowDown): _Nudge(-1),
          },
          actions: {
            _Nudge: CallbackAction<_Nudge>(
              onInvoke: (i) => _emit(widget.value + i.by * _step),
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled
                ? (d) => _toPosition(d.localPosition.dx, _width)
                : null,
            onHorizontalDragStart: _enabled
                ? (d) {
                    setState(() => _dragging = true);
                    _toPosition(d.localPosition.dx, _width);
                  }
                : null,
            onHorizontalDragUpdate: _enabled
                ? (d) => _toPosition(d.localPosition.dx, _width)
                : null,
            onHorizontalDragEnd:
                _enabled ? (_) => setState(() => _dragging = false) : null,
            onHorizontalDragCancel:
                _enabled ? () => setState(() => _dragging = false) : null,
            child: _SliderSize(
              child: CustomPaint(
                painter: _SliderPainter(
                  fraction: _fraction,
                  divisions: widget.divisions,
                  active: active,
                  halo: _enabled && (_dragging || _hovering || _focused),
                  bubble: _dragging ? widget.label : null,
                  bubbleStyle: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                  pad: _pad,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The width the gesture landed in — read off the box at the moment, since
  /// the slider takes whatever width its parent gives it.
  double get _width =>
      (context.findRenderObject() as RenderBox?)?.size.width ?? 0;
}

/// Sizes the slider as [Slider] does, without a `LayoutBuilder`: all the width
/// it is offered, a preferred 144-point track where the width is unbounded,
/// and 48 high. A popup menu measures its items' intrinsic width, which a
/// `LayoutBuilder` refuses — the first version of this widget broke the
/// „Board view" menu exactly so.
class _SliderSize extends SingleChildRenderObjectWidget {
  const _SliderSize({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSliderSize();
}

class _RenderSliderSize extends RenderProxyBox {
  static const double _preferredWidth = 144.0 + 2 * _AppSliderState._pad;
  static const double _height = _AppSliderState._height;

  @override
  double computeMinIntrinsicWidth(double height) => _preferredWidth;
  @override
  double computeMaxIntrinsicWidth(double height) => _preferredWidth;
  @override
  double computeMinIntrinsicHeight(double width) => _height;
  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints);

  Size _sizeFor(BoxConstraints c) => c.constrain(
        Size(c.hasBoundedWidth ? c.maxWidth : _preferredWidth, _height),
      );

  @override
  void performLayout() {
    size = _sizeFor(constraints);
    child?.layout(BoxConstraints.tight(size));
  }
}

class _Nudge extends Intent {
  const _Nudge(this.by);
  final int by;
}

class _SliderPainter extends CustomPainter {
  _SliderPainter({
    required this.fraction,
    required this.divisions,
    required this.active,
    required this.halo,
    required this.bubble,
    required this.bubbleStyle,
    required this.pad,
  });

  final double fraction;
  final int? divisions;
  final Color active;
  final bool halo;
  final String? bubble;
  final TextStyle? bubbleStyle;
  final double pad;

  static const double _track = 4.0;
  static const double _thumb = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final left = pad;
    final right = size.width - pad;
    final x = left + (right - left) * fraction;
    final rest = Paint()..color = active.withValues(alpha: 0.24);
    final done = Paint()..color = active;

    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        y - _track / 2,
        right,
        y + _track / 2,
        const Radius.circular(_track / 2),
      ),
      rest,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        y - _track / 2,
        x,
        y + _track / 2,
        const Radius.circular(_track / 2),
      ),
      done,
    );

    final d = divisions;
    if (d != null && d <= (right - left) / 6) {
      for (var i = 0; i <= d; i++) {
        final tx = left + (right - left) * i / d;
        canvas.drawCircle(
          Offset(tx, y),
          1.0,
          Paint()
            ..color = tx <= x
                ? Colors.white.withValues(alpha: 0.54)
                : active.withValues(alpha: 0.54),
        );
      }
    }

    if (halo) {
      canvas.drawCircle(
        Offset(x, y),
        _thumb * 2,
        Paint()..color = active.withValues(alpha: 0.12),
      );
    }
    canvas.drawCircle(Offset(x, y), _thumb, done);

    final text = bubble;
    if (text != null && text.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: bubbleStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width + 16;
      final h = tp.height + 8;
      // Above the thumb, and outside this box: painting past its own bounds
      // needs no overlay, which is the point of this widget.
      final box = RRect.fromLTRBR(
        x - w / 2,
        y - _thumb - 8 - h,
        x + w / 2,
        y - _thumb - 8,
        const Radius.circular(6),
      );
      canvas.drawRRect(box, done);
      tp.paint(canvas, Offset(box.left + 8, box.top + 4));
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.fraction != fraction ||
      old.divisions != divisions ||
      old.active != active ||
      old.halo != halo ||
      old.bubble != bubble ||
      old.bubbleStyle != bubbleStyle;
}
