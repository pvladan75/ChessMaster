import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';

class OpeningBanner extends StatefulWidget {
  final String fen;
  final OpeningBookEntry? Function(String fen)? lookup;

  const OpeningBanner({
    super.key,
    required this.fen,
    this.lookup,
    this.bare = false,
  });

  /// Without the bordered card around it, for a place that already frames it.
  ///
  /// Since 5.9.2026 this rides in the screen's app bar on a wide window, beside
  /// the repertoire's own name. There it is one line of text that may
  /// ellipsize: the bar is the frame, and a bordered pill inside a bar reads as
  /// a mistake.
  final bool bare;

  @override
  State<OpeningBanner> createState() => _OpeningBannerState();
}

class _OpeningBannerState extends State<OpeningBanner> {
  OpeningBookEntry? _lastNamed;

  @override
  void initState() {
    super.initState();
    _updateLookup();
  }

  @override
  void didUpdateWidget(covariant OpeningBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fen != widget.fen) {
      _updateLookup();
    }
  }

  void _updateLookup() {
    final lookupFn = widget.lookup ?? OpeningBookService.instance.lookupByFen;
    final normalized = OpeningBookService.normalizeFen(widget.fen);
    final entry = lookupFn(normalized);
    if (entry != null) {
      _lastNamed = entry;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lastNamed == null) {
      return const SizedBox.shrink();
    }

    final said = '${_lastNamed!.eco} · ${_lastNamed!.name}';

    if (widget.bare) {
      return Text(
        said,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: AppRadii.roundedSm,
        border: Border.all(
          color: context.colors.accent,
          width: 1.0,
        ),
      ),
      child: Text(
        said,
        style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
