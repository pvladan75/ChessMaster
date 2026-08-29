import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// One line of the list: the keys, what they do, and nothing implied.
class AppShortcut {
  const AppShortcut(this.keys, this.what);

  /// Drawn one after another, so `['Ctrl', ',']` reads as a chord.
  final List<String> keys;

  final String what;
}

/// A group of shortcuts and, in [where], the honest answer to "where does this
/// work". A list that lets the reader assume a key works everywhere, when it
/// works on one screen, is worse than no list at all: they press it, nothing
/// happens, and they stop trusting the rest of the page.
class ShortcutGroup {
  const ShortcutGroup(this.title, this.where, this.shortcuts);

  final String title;
  final String where;
  final List<AppShortcut> shortcuts;
}

/// Every shortcut the application answers, in one place.
///
/// This is the list, not a copy of it: a key added to a screen and not added
/// here is a key nobody will find. Ctrl+, is why this page exists at all — it
/// was built, it passed its test, and the person it was built for could not
/// find it or use it. A shortcut nobody knows about does not exist.
const kShortcutGroups = <ShortcutGroup>[
  ShortcutGroup(
    'Svuda u aplikaciji',
    'Rade na svakom ekranu.',
    [
      AppShortcut(['Esc'], 'Zatvara ono što je otvoreno preko rada.'),
      AppShortcut(['Ctrl', ','], 'Otvara Podešavanja.'),
      AppShortcut(['F1'], 'Otvara ovaj spisak.'),
      AppShortcut(
          ['Ctrl', 'C'], 'Kopira FEN pozicije sa table koja je na ekranu.'),
    ],
  ),
  ShortcutGroup(
    'Tabovi',
    'Na početnom ekranu, gde su četiri taba. Dok je otvorena vežba ili soba '
        'preko njega, tasteri pripadaju onome što je gore.',
    [
      AppShortcut(['Ctrl', '1'], 'Trening.'),
      AppShortcut(['Ctrl', '2'], 'Časovi.'),
      AppShortcut(['Ctrl', '3'], 'Biblioteka.'),
      AppShortcut(['Ctrl', '4'], 'Ljudi.'),
    ],
  ),
  ShortcutGroup(
    'Kretanje kroz poteze',
    'Svuda gde ispod table stoji traka sa potezima: analiza, soba, lekcija, '
        'ponavljanje, vežbe i šetnja kroz partiju. Dok je fokus u polju za '
        'tekst, strelice pripadaju polju.',
    [
      AppShortcut(['←'], 'Potez unazad.'),
      AppShortcut(['→'], 'Potez unapred.'),
      AppShortcut(['↑'], 'Na početak linije.'),
      AppShortcut(['↓'], 'Na kraj linije.'),
      AppShortcut(['Home'], 'Na početak linije, isto kao ↑.'),
      AppShortcut(['End'], 'Na kraj linije, isto kao ↓.'),
    ],
  ),
  ShortcutGroup(
    'Trener završnica',
    'Na ekranu sa završnicama. Svako slovo pritiska dugme koje je u tom '
        'trenutku na ekranu, i ćuti kad tog dugmeta nema.',
    [
      AppShortcut(['N'], 'Sledeća pozicija.'),
      AppShortcut(['R'], 'Ispočetka, isto što i istoimeno dugme.'),
      AppShortcut(['H'], 'Pomoć.'),
      AppShortcut(['T'], 'Nalaz tablica, dok se pozicija igra do kraja.'),
      AppShortcut(['U'], 'Vrati potez, posle greške u igranju do kraja.'),
    ],
  ),
  ShortcutGroup(
    'Reprodukcija snimka',
    'Na ekranu sa snimljenim časom. Dok je fokus na nekom dugmetu, razmak '
        'pripada tom dugmetu.',
    [
      AppShortcut(['Razmak'], 'Pusti ili pauziraj snimak.'),
    ],
  ),
  ShortcutGroup(
    'Stablo poteza',
    'U Analizi, i to tek kad se u samo stablo klikne — dok fokus nije u njemu, '
        'strelice pripadaju traci sa potezima ispod table.',
    [
      AppShortcut(['↑'], 'Na potez iz kog ova varijanta izlazi.'),
      AppShortcut(['↓'], 'Na prvi nastavak.'),
      AppShortcut(['←'], 'Na prethodnu varijantu istog poteza.'),
      AppShortcut(['→'], 'Na sledeću varijantu istog poteza.'),
      AppShortcut(['+'], 'Uvećaj stablo.'),
      AppShortcut(['−'], 'Umanji stablo.'),
    ],
  ),
  ShortcutGroup(
    'Miš',
    'Na svakoj tabli u sobi i u vežbama.',
    [
      AppShortcut(['Desni klik'], 'Kopira FEN pozicije.'),
    ],
  ),
];

/// The keyboard shortcuts, written down.
///
/// A page and not a dialog because it is reached from two places that must not
/// know about each other — the F1 key and a row in Settings — and a route is
/// what both can name.
class ShortcutsScreen extends StatelessWidget {
  const ShortcutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prečice na tastaturi'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Nijedna prečica nije jedini put do nečega — sve što je ovde ima i '
            'svoje dugme. Na telefonu, gde tastature nema, radi samo desni '
            'klik, i to sa mišem.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final group in kShortcutGroups) ...[
            _GroupCard(group: group),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final ShortcutGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.title, style: AppText.bodyBold),
            const SizedBox(height: AppSpacing.xs),
            Text(
              group.where,
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            const Divider(height: 20),
            for (final shortcut in group.shortcuts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                // Wrap and not Row: „Esc" plus a full sentence is wider than a
                // 360 dp phone, and a release build clips the overflow without
                // drawing a single stripe to say so.
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final key in shortcut.keys) _KeyCap(label: key),
                    ConstrainedBox(
                      // Leaves room for the widest key cap on the narrowest
                      // screen, so the sentence wraps inside the card instead
                      // of pushing past it.
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 140,
                      ),
                      child: Text(shortcut.what, style: AppText.body),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.borderStrong),
      ),
      child: Text(
        label,
        style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
      ),
    );
  }
}
