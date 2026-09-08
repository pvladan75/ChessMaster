import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';

/// Comprehensive internal design gallery for Mislisha.
///
/// Showcases the design token palette, typography scale, spacing rhythm,
/// button variants, child-friendly touch targets, input fields, cards,
/// and domain-specific chess components (eval bar, move notation, dense analysis panel).
///
/// Designed to be reviewed on both 360dp mobile screens and >=840dp desktop windows.
class DesignGalleryScreen extends StatefulWidget {
  const DesignGalleryScreen({super.key});

  @override
  State<DesignGalleryScreen> createState() => _DesignGalleryScreenState();
}

class _DesignGalleryScreenState extends State<DesignGalleryScreen> {
  /// Which palette the gallery is showing. Local to this screen: it overrides
  /// the theme for what is inside it and changes nothing about the app.
  ///
  /// Starts dark, rather than reading the ambient brightness. Rule 19's second
  /// half stands and is not lifted by the light palette existing: no widget in
  /// `lib/` asks `Theme.of(context).brightness`, because a widget that branches
  /// on it is a third palette nobody measures. The gallery does not need to ask
  /// — the app ships dark, so dark is what it opens on.
  bool _isLightMode = false;

  @override
  Widget build(BuildContext context) {
    final isWideScreen = Breakpoints.isWide(context);

    final theme = _isLightMode ? AppTheme.light : AppTheme.dark;

    return Theme(
        data: theme,
        child: Builder(builder: (context) {
          final colors = context.colors;
          return Scaffold(
            backgroundColor: colors.canvas,
            appBar: AppBar(
              title: const Text('Design Gallery — Mislisha'),
              elevation: 0,
              actions: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Light',
                        style: AppText.caption
                            .copyWith(color: colors.textPrimary)),
                    Switch(
                      value: _isLightMode,
                      onChanged: (val) => setState(() => _isLightMode = val),
                      activeTrackColor: colors.brand.withValues(alpha: 0.5),
                      activeThumbColor: colors.brand,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.10),
                        borderRadius: AppRadii.roundedPill,
                        border: Border.all(
                            color: colors.brand.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        isWideScreen
                            ? 'Desktop (>= 840dp)'
                            : 'Mobile (< 840dp)',
                        style:
                            AppText.captionBold.copyWith(color: colors.brand),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _IntroBanner(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '1. Color Palette (Tokens & Contrast)',
                          subtitle:
                              '15 token roles with measured WCAG AA/AAA contrast ratios',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _PaletteGrid(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '2. Typography Scale',
                          subtitle: 'Text size scale defined in AppText',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _TypographySection(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '3. Spacing and Corner Radii Scale',
                          subtitle:
                              'AppSpacing (4–32dp) and AppRadii (4–20dp, pill)',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SpacingAndRadiiSection(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '4. Buttons and Interactive Controls',
                          subtitle:
                              'Accessible: minimum touch target of 48×48 dp',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ButtonsSection(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '5. Cards and Surfaces',
                          subtitle: 'System elevation levels and borders',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _CardsSection(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '6. Text Input and Forms',
                          subtitle: 'Input fields, switches, and options',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _FormsSection(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '7. Chess Components',
                          subtitle:
                              'Evaluation bar, move notation, and analysis panel',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ChessComponentsSection(colors: colors),
                        const SizedBox(height: AppSpacing.xxl),
                        _SectionHeader(
                          title: '8. Dialogs and Notifications',
                          subtitle: 'Modal dialog styling',
                          colors: colors,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _DialogPreviewSection(colors: colors),
                        const SizedBox(height: AppSpacing.xxxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }));
  }
}

class _IntroBanner extends StatelessWidget {
  final AppColorTokens colors;

  const _IntroBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: colors.brand.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.palette_outlined, color: colors.brand, size: 28),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mislisha Design System',
                  style: AppText.headline.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Color, typography, spacing, and component system designed for players and chess trainers. '
                  'All interactive components respect the minimum touch target of 48×48 dp.',
                  style: AppText.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final AppColorTokens colors;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppText.title.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: AppText.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  final AppColorTokens colors;

  const _PaletteGrid({required this.colors});

  @override
  Widget build(BuildContext context) {
    final swatches = [
      _SwatchData('canvas', colors.canvas, 'Screen background'),
      _SwatchData('surface', colors.surface, 'Cards and panels'),
      _SwatchData('surfaceRaised', colors.surfaceRaised, 'Elevated rows'),
      _SwatchData('border', colors.border, 'Subtle borders'),
      _SwatchData('borderStrong', colors.borderStrong, 'Focused borders'),
      _SwatchData('textPrimary', colors.textPrimary, 'Titles and body'),
      _SwatchData('textSecondary', colors.textSecondary, 'Secondary text'),
      _SwatchData('textMuted', colors.textMuted, 'Muted'),
      _SwatchData('accent (Teal)', colors.accent, 'Engine, active state'),
      _SwatchData('accentAlt (Purple)', colors.accentAlt, 'Variations'),
      _SwatchData('brand (Violet)', colors.brand, 'Mislisha'),
      _SwatchData('info (Sky)', colors.info, 'Info and help'),
      _SwatchData('warning (Amber)', colors.warning, 'Warning'),
      _SwatchData('danger (Rose)', colors.danger, 'Blunder, checkmate'),
      _SwatchData('success (Green)', colors.success, 'Correct move'),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children:
          swatches.map((s) => _SwatchCard(data: s, colors: colors)).toList(),
    );
  }
}

class _SwatchData {
  final String name;
  final Color color;

  /// What the role is for. Not what it measures, and not what it is worth in
  /// hex: until 29.8.2026 both of those were typed out beside every swatch,
  /// which was true of one palette and became a lie the moment the gallery
  /// learned to render the other. `#1E293B` under a white square, and
  /// `12% White` under a black overlay. Both are now read off the colour.
  final String note;

  const _SwatchData(this.name, this.color, this.note);
}

/// `#RRGGBB`, or `#RRGGBB @ NN%` when the role is an overlay rather than a
/// solid — `border` and `borderStrong` are the two, and their alpha is the
/// whole point of them.
String _hexOf(Color c) {
  final argb = c.toARGB32();
  final rgb = argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  final alpha = (argb >> 24) & 0xFF;
  if (alpha == 0xFF) return '#$rgb';
  return '#$rgb @ ${(alpha / 255 * 100).round()}%';
}

/// WCAG 2.1 relative luminance, and the ratio between two of them.
///
/// Computed rather than remembered. The three false contrast claims found on
/// 28.8.2026 were all numbers somebody had written down beside a colour, and
/// the header of this gallery was one of them.
double _relativeLuminance(Color c) {
  double channel(int v) {
    final s = v / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final argb = c.toARGB32();
  return 0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

class _SwatchCard extends StatelessWidget {
  final _SwatchData data;
  final AppColorTokens colors;

  const _SwatchCard({required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: data.color,
              borderRadius: AppRadii.roundedSm,
              border: Border.all(color: colors.border),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.name,
            style: AppText.captionBold.copyWith(color: colors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _hexOf(data.color),
            style: AppText.micro.copyWith(color: colors.textSecondary),
          ),
          Text(
            data.note,
            style: AppText.micro.copyWith(color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Against the card the swatch is sitting on, measured now rather
          // than quoted from whenever the palette was last looked at.
          //
          // Only for a solid colour. `border` and `borderStrong` are overlays,
          // and a ratio computed from an overlay's own channels ignores the
          // compositing that decides what the reader actually sees — it came
          // out at 14.63:1 for a hairline nobody can see. A number that is
          // wrong in a new way is not an improvement on one that is stale.
          if ((data.color.toARGB32() >> 24) == 0xFF)
            Text(
              '${_contrastRatio(data.color, colors.surface).toStringAsFixed(2)}:1 on surface',
              style: AppText.micro.copyWith(color: colors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _TypographySection extends StatelessWidget {
  final AppColorTokens colors;

  const _TypographySection({required this.colors});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('AppText.display', '22px Bold', AppText.display, 'Position 1. e4'),
      (
        'AppText.headline',
        '18px Bold',
        AppText.headline,
        'Chess trainer and exercises'
      ),
      (
        'AppText.title',
        '16px Bold',
        AppText.title,
        'Tactics and Opening Repertoire'
      ),
      (
        'AppText.subtitle',
        '14px Semibold',
        AppText.subtitle,
        'Practice basic checkmates against Stockfish'
      ),
      (
        'AppText.bodyLargeBold',
        '13px Bold',
        AppText.bodyLargeBold,
        'Nf3 Nc6 3. Bc4 Bc5 (Giuoco Piano)'
      ),
      (
        'AppText.bodyLarge',
        '13px Regular',
        AppText.bodyLarge,
        'Recommended move with eval +0.8'
      ),
      (
        'AppText.bodyBold',
        '12px Bold',
        AppText.bodyBold,
        'Mate in 2 — Puzzle #4120'
      ),
      (
        'AppText.body',
        '12px Regular',
        AppText.body,
        'Standard text inside cards and explanation panels.'
      ),
      (
        'AppText.captionBold',
        '11px Bold',
        AppText.captionBold,
        'Rating: 1450 • Depth: 18'
      ),
      (
        'AppText.caption',
        '11px Regular',
        AppText.caption,
        'Last edited 2 hours ago • 35 tasks'
      ),
      (
        'AppText.micro',
        '10px Regular',
        AppText.micro,
        'MIN • SEC • EVAL • BEST'
      ),
    ];

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          return Column(
            children: rows.map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: 2,
                            children: [
                              Text(
                                r.$1,
                                style: AppText.micro
                                    .copyWith(color: colors.textMuted),
                              ),
                              Text(
                                r.$2,
                                style:
                                    AppText.micro.copyWith(color: colors.brand),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            r.$4,
                            style: r.$3.copyWith(color: colors.textPrimary),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              r.$1,
                              style: AppText.micro
                                  .copyWith(color: colors.textMuted),
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              r.$2,
                              style:
                                  AppText.micro.copyWith(color: colors.brand),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r.$4,
                              style: r.$3.copyWith(color: colors.textPrimary),
                            ),
                          ),
                        ],
                      ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SpacingAndRadiiSection extends StatelessWidget {
  final AppColorTokens colors;

  const _SpacingAndRadiiSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    final spacings = [
      ('xxs', 2.0),
      ('xs', 4.0),
      ('sm', 8.0),
      ('md', 12.0),
      ('lg', 16.0),
      ('xl', 20.0),
      ('xxl', 24.0),
      ('xxxl', 32.0),
    ];

    final radii = [
      ('xs (4dp)', AppRadii.roundedXs),
      ('sm (8dp)', AppRadii.roundedSm),
      ('md (12dp)', AppRadii.roundedMd),
      ('lg (16dp)', AppRadii.roundedLg),
      ('xl (20dp)', AppRadii.roundedXl),
      ('pill', AppRadii.roundedPill),
    ];

    return Column(
      children: [
        // Spacing Rulers
        Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Spacing scale (AppSpacing)',
                  style: AppText.subtitle.copyWith(color: colors.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: spacings.map((s) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${s.$1} (${s.$2.toInt()}dp)',
                          style:
                              AppText.micro.copyWith(color: colors.textMuted)),
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        height: 24,
                        width: s.$2 * 3,
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.3),
                          borderRadius: AppRadii.roundedXs,
                          border: Border.all(color: colors.accent),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Corner Radii Cards
        Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Corner radii (AppRadii)',
                  style: AppText.subtitle.copyWith(color: colors.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: radii.map((r) {
                  return Container(
                    width: 120,
                    height: 54,
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: r.$2,
                      border: Border.all(color: colors.borderStrong),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      r.$1,
                      style: AppText.captionBold
                          .copyWith(color: colors.textSecondary),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ButtonsSection extends StatelessWidget {
  final AppColorTokens colors;

  const _ButtonsSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Button variants (All buttons have min. height of 48dp)',
            style: AppText.subtitle.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow),
                label: const Text('Primary'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brand.withValues(alpha: 0.10),
                  foregroundColor: colors.brand,
                  side: BorderSide(
                    color: colors.brand.withValues(alpha: 0.45),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Tonal'),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Elevated'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list),
                label: const Text('Outlined'),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh),
                label: const Text('Text'),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Disabled states',
            style: AppText.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start training'),
              ),
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Hold a draw'),
              ),
              OutlinedButton(
                onPressed: null,
                child: const Text('Disabled'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardsSection extends StatelessWidget {
  final AppColorTokens colors;

  const _CardsSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        // Standard Surface Card
        Container(
          width: 290,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_outlined, color: colors.accent, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Standard card',
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Background color is `context.colors.surface` with subtle `border`.',
                style: AppText.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        // Raised Card
        Container(
          width: 290,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: colors.borderStrong),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.upgrade, color: colors.brand, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Elevated card',
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Background color is `context.colors.surfaceRaised` to emphasize key sections.',
                style: AppText.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        // Accent Bordered Card
        Container(
          width: 290,
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: colors.accentAlt, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: colors.accentAlt, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Themed card',
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Accent border with `accentAlt` or `accent` color for themed exercise categories.',
                style: AppText.body.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormsSection extends StatelessWidget {
  final AppColorTokens colors;

  const _FormsSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Input fields and statuses',
              style: AppText.subtitle.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Username or room code',
              hintText: 'e.g. ROOM-1234',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: InputDecoration(
              labelText: 'Invalid FEN input',
              errorText: 'Position is not valid chess notation.',
              prefixIcon: const Icon(Icons.error_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Badges and status indicators',
              style: AppText.subtitle.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusBadge(
                label: 'Correct move',
                icon: Icons.check_circle_outline,
                color: colors.success,
              ),
              _StatusBadge(
                label: 'Blunder',
                icon: Icons.warning_amber_outlined,
                color: colors.warning,
              ),
              _StatusBadge(
                label: 'Mistake (-3.2)',
                icon: Icons.cancel_outlined,
                color: colors.danger,
              ),
              _StatusBadge(
                label: 'Depth 24',
                icon: Icons.info_outline,
                color: colors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadii.roundedPill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppText.captionBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _ChessComponentsSection extends StatelessWidget {
  final AppColorTokens colors;

  const _ChessComponentsSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Evaluation Bar + Move Notation Row
        Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Evaluation bar (Eval Bar) and Move notation',
                style: AppText.subtitle.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Vertical Eval Bar sample
                  Container(
                    width: 28,
                    height: 120,
                    decoration: BoxDecoration(
                      color: colors.sideBlack, // Black side
                      borderRadius: AppRadii.roundedSm,
                      border: Border.all(color: colors.borderStrong),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // White advantage fill (e.g. 65% white)
                        Container(
                          height: 78,
                          decoration: BoxDecoration(
                            color: colors.sideWhite,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(AppRadii.xs),
                            ),
                          ),
                        ),
                        // Eval score label
                        Positioned(
                          bottom: 4,
                          child: Text(
                            '+1.8',
                            style: AppText.micro.copyWith(
                              color: colors.canvas,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // Move List Sample
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MoveRow(
                          moveNum: '1.',
                          whiteMove: 'e4',
                          blackMove: 'e5',
                          whiteGlyph: null,
                          blackGlyph: null,
                          isCurrent: false,
                          colors: colors,
                        ),
                        _MoveRow(
                          moveNum: '2.',
                          whiteMove: 'Nf3',
                          blackMove: 'Nc6',
                          whiteGlyph: null,
                          blackGlyph: null,
                          isCurrent: false,
                          colors: colors,
                        ),
                        _MoveRow(
                          moveNum: '3.',
                          whiteMove: 'Bc4',
                          blackMove: 'Nf6',
                          whiteGlyph: '!',
                          blackGlyph: '?!',
                          isCurrent: true,
                          colors: colors,
                        ),
                        _MoveRow(
                          moveNum: '4.',
                          whiteMove: 'Ng5',
                          blackMove: 'd5',
                          whiteGlyph: null,
                          blackGlyph: null,
                          isCurrent: false,
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Dense Analysis Panel Sample
        Container(
          padding: AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.roundedLg,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.biotech, color: colors.accent, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            'Stockfish 16 • Analysis',
                            style: AppText.subtitle
                                .copyWith(color: colors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: AppRadii.roundedXs,
                    ),
                    child: Text(
                      'DEPTH 22',
                      style: AppText.micro.copyWith(color: colors.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),
              const SizedBox(height: AppSpacing.xs),
              _EngineLineRow(
                rank: '1',
                eval: '+1.82',
                moves: '4. Ng5 d5 5. exd5 Na5 6. Bb5+ c6',
                isBest: true,
                colors: colors,
              ),
              _EngineLineRow(
                rank: '2',
                eval: '+0.45',
                moves: '4. d3 Bc5 5. c3 O-O 6. O-O d6',
                isBest: false,
                colors: colors,
              ),
              _EngineLineRow(
                rank: '3',
                eval: '0.00',
                moves: '4. d4 exd4 5. e5 d5 6. Bb5 Ne4',
                isBest: false,
                colors: colors,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MoveRow extends StatelessWidget {
  final String moveNum;
  final String whiteMove;
  final String blackMove;
  final String? whiteGlyph;
  final String? blackGlyph;
  final bool isCurrent;
  final AppColorTokens colors;

  const _MoveRow({
    required this.moveNum,
    required this.whiteMove,
    required this.blackMove,
    required this.whiteGlyph,
    required this.blackGlyph,
    required this.isCurrent,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isCurrent
            ? colors.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: AppRadii.roundedSm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              moveNum,
              style: AppText.captionBold.copyWith(color: colors.textMuted),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  whiteMove,
                  style: AppText.bodyBold.copyWith(
                    color: isCurrent ? colors.accent : colors.textPrimary,
                  ),
                ),
                if (whiteGlyph != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xxs),
                    child: Text(
                      whiteGlyph!,
                      style: AppText.captionBold.copyWith(color: colors.info),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  blackMove,
                  style: AppText.bodyBold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (blackGlyph != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xxs),
                    child: Text(
                      blackGlyph!,
                      style:
                          AppText.captionBold.copyWith(color: colors.warning),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineLineRow extends StatelessWidget {
  final String rank;
  final String eval;
  final String moves;
  final bool isBest;
  final AppColorTokens colors;

  const _EngineLineRow({
    required this.rank,
    required this.eval,
    required this.moves,
    required this.isBest,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Container(
            width: 18,
            alignment: Alignment.center,
            child: Text(
              rank,
              style: AppText.captionBold.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: isBest
                  ? colors.accent.withValues(alpha: 0.18)
                  : colors.surfaceRaised,
              borderRadius: AppRadii.roundedXs,
            ),
            child: Text(
              eval,
              style: AppText.captionBold.copyWith(
                color: isBest ? colors.accent : colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              moves,
              style: AppText.caption.copyWith(color: colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogPreviewSection extends StatelessWidget {
  final AppColorTokens colors;

  const _DialogPreviewSection({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dialog preview (Modal Dialog)',
            style: AppText.subtitle.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: AppSpacing.cardPaddingComfortable,
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: AppRadii.roundedXl,
                border: Border.all(color: colors.borderStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline, color: colors.brand, size: 24),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'End training?',
                          style:
                              AppText.title.copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Are you sure you want to stop the current training? Your progress will be saved.',
                    style: AppText.body.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Continue'),
                      ),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('End'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
