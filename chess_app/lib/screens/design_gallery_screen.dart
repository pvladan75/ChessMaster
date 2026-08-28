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
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isWideScreen = Breakpoints.isWide(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Design Galerija — Mislisha'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.18),
                  borderRadius: AppRadii.roundedPill,
                  border:
                      Border.all(color: colors.brand.withValues(alpha: 0.4)),
                ),
                child: Text(
                  isWideScreen ? 'Desktop (>= 840dp)' : 'Mobilni (< 840dp)',
                  style: AppText.captionBold.copyWith(color: colors.brand),
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
                    title: '1. Paleta boja (Tokeni & Kontrast)',
                    subtitle:
                        '15 token uloga sa izmerenim WCAG AA/AAA kontrastnim odnosima',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PaletteGrid(colors: colors),
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                    title: '2. Tipografska skala',
                    subtitle: 'Skala veličina teksta definisana u AppText',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _TypographySection(colors: colors),
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                    title: '3. Skala razmaka i zaobljenja',
                    subtitle: 'AppSpacing (4–32dp) i AppRadii (4–20dp, pill)',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SpacingAndRadiiSection(colors: colors),
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                    title: '4. Dugmad i interaktivne kontrole',
                    subtitle:
                        'Prilagođeno deci: minimalna dodirna površina 48×48 dp',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ButtonsSection(colors: colors),
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                    title: '5. Kartice i površine',
                    subtitle: 'Sistemski nivoi elevacije i granica',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CardsSection(colors: colors),
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                    title: '6. Unos teksta i forme',
                    subtitle: 'Polja za unos, preklopnici i opcije',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FormsSection(colors: colors),
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                    title: '7. Šahovske komponente',
                    subtitle:
                        'Traka evaluacije, notacija poteza i panel analize',
                    colors: colors,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ChessComponentsSection(colors: colors),
                  const SizedBox(height: AppSpacing.xxl),
                  _SectionHeader(
                    title: '8. Dijalozi i obaveštenja',
                    subtitle: 'Stilizacija modalnih prozora',
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
                  'Sistem boja, tipografije, razmaka i komponenti prilagođen deci (7–14 god.) i šahovskim trenerima. '
                  'Sve interaktivne komponente poštuju minimalni touch target od 48×48 dp.',
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
      _SwatchData('canvas', colors.canvas, '#0F172A', 'Pozadina ekrana'),
      _SwatchData('surface', colors.surface, '#1E293B', 'Kartice i paneli'),
      _SwatchData(
          'surfaceRaised', colors.surfaceRaised, '#334155', 'Izdignuti redovi'),
      _SwatchData('border', colors.border, '12% White', 'Suptilne linije'),
      _SwatchData(
          'borderStrong', colors.borderStrong, '24% White', 'Granice u fokusu'),
      _SwatchData('textPrimary', colors.textPrimary, '#F8FAFC', '13.98:1 AAA'),
      _SwatchData(
          'textSecondary', colors.textSecondary, '#CBD5E1', '9.85:1 AAA'),
      _SwatchData('textMuted', colors.textMuted, '#94A3B8', '5.71:1 AA'),
      _SwatchData(
          'accent (Teal)', colors.accent, '#2DD4BF', '7.86:1 AA Šah/Tabla'),
      _SwatchData('accentAlt (Purple)', colors.accentAlt, '#C084FC',
          '5.54:1 AA Varijante'),
      _SwatchData(
          'brand (Violet)', colors.brand, '#A78BFA', '5.38:1 AA Mislisha'),
      _SwatchData('info (Sky)', colors.info, '#38BDF8', '6.83:1 AA Info/Pomoć'),
      _SwatchData(
          'warning (Amber)', colors.warning, '#FBBF24', '8.76:1 AA Upozorenje'),
      _SwatchData(
          'danger (Rose)', colors.danger, '#FDA4AF', '7.71:1 AA Greška/Mat'),
      _SwatchData('success (Green)', colors.success, '#4ADE80',
          '8.40:1 AA Tačan potez'),
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
  final String hex;
  final String note;

  const _SwatchData(this.name, this.color, this.hex, this.note);
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
            data.hex,
            style: AppText.micro.copyWith(color: colors.textSecondary),
          ),
          Text(
            data.note,
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
      ('AppText.display', '22px Bold', AppText.display, 'Pozicija 1. e4'),
      (
        'AppText.headline',
        '18px Bold',
        AppText.headline,
        'Šahovski trener i vežbe'
      ),
      (
        'AppText.title',
        '16px Bold',
        AppText.title,
        'Taktika i Repertoar otvaranja'
      ),
      (
        'AppText.subtitle',
        '14px Semibold',
        AppText.subtitle,
        'Vežbajte osnovno matiranje protiv Stockfish-a'
      ),
      (
        'AppText.bodyLargeBold',
        '13px Bold',
        AppText.bodyLargeBold,
        'Nf3 Sc6 3. Bc4 Bc5 (Giuoco Piano)'
      ),
      (
        'AppText.bodyLarge',
        '13px Regular',
        AppText.bodyLarge,
        'Preporučeni potez sa procenom +0.8'
      ),
      (
        'AppText.bodyBold',
        '12px Bold',
        AppText.bodyBold,
        'Mat u 2 poteza — Zagonetka #4120'
      ),
      (
        'AppText.body',
        '12px Regular',
        AppText.body,
        'Standardni tekst unutar kartica i panela za objašnjenja.'
      ),
      (
        'AppText.captionBold',
        '11px Bold',
        AppText.captionBold,
        'Rejting: 1450 • Dubina: 18'
      ),
      (
        'AppText.caption',
        '11px Regular',
        AppText.caption,
        'Poslednja izmena pre 2 sata • 35 zadataka'
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
                          const SizedBox(height: 2),
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
              Text('Skala razmaka (AppSpacing)',
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
              Text('Zaobljenja uglova (AppRadii)',
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
            'Varijante dugmadi (Sva dugmad imaju min. visinu 48dp)',
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
                label: const Text('Primarno'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.brand.withValues(alpha: 0.22),
                  foregroundColor: colors.brand,
                  side: BorderSide(
                    color: colors.brand.withValues(alpha: 0.45),
                  ),
                ),
                onPressed: () {},
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Tonalno'),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Izdignuto'),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list),
                label: const Text('Uokvireno'),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh),
                label: const Text('Tekstualno'),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Nazad',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Onemogućena stanja (Disabled)',
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
                label: const Text('Započni trening'),
              ),
              ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Održi remi'),
              ),
              OutlinedButton(
                onPressed: null,
                child: const Text('Onemogućeno'),
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
                      'Standardna kartica',
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Boja pozadine je `context.colors.surface` sa suptilnim `border` obrubom.',
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
                      'Izdignuta kartica',
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Boja pozadine je `context.colors.surfaceRaised` za isticanje važnih sekcija.',
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
                      'Tematska kartica',
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Istaknuti rub sa `accentAlt` ili `accent` bojom za tematske kategorije vežbi.',
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
          Text('Polja za unos i statusi',
              style: AppText.subtitle.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.md),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Korisničko ime ili kod sobe',
              hintText: 'npr. SOBA-1234',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: InputDecoration(
              labelText: 'Neispravan FEN unos',
              errorText: 'Pozicija nije validna šahovska notacija.',
              prefixIcon: const Icon(Icons.error_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Bedževi i statusne oznake',
              style: AppText.subtitle.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusBadge(
                label: 'Tačan potez',
                icon: Icons.check_circle_outline,
                color: colors.success,
              ),
              _StatusBadge(
                label: 'Previđanje (Blunder)',
                icon: Icons.warning_amber_outlined,
                color: colors.warning,
              ),
              _StatusBadge(
                label: 'Greška (-3.2)',
                icon: Icons.cancel_outlined,
                color: colors.danger,
              ),
              _StatusBadge(
                label: 'Dubina 24',
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
                'Traka evaluacije (Eval Bar) i Notacija poteza',
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
                      color: const Color(0xFF1E1E1E), // Black side
                      borderRadius: AppRadii.roundedSm,
                      border: Border.all(color: colors.borderStrong),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // White advantage fill (e.g. 65% white)
                        Container(
                          height: 78,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
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
                              color: Colors.black,
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
                            'Stockfish 16 • Analiza',
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
                      'DUBINA 22',
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
                    padding: const EdgeInsets.only(left: 2),
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
                    padding: const EdgeInsets.only(left: 2),
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
              vertical: 2,
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
            'Pregled dijaloga (Modal Dialog)',
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
                          'Završi trening?',
                          style:
                              AppText.title.copyWith(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Da li ste sigurni da želite da prekinete trenutni trening? Vaš napredak će ostati sačuvan.',
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
                        child: const Text('Nastavi'),
                      ),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('Završi'),
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
