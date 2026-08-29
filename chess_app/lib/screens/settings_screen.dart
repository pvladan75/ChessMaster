import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chess_app/core/build_info.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/widgets/account_stats_card.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/widgets/parent_email_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class SettingsScreen extends StatefulWidget {
  final UserSession session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService.instance;
  final _stockfishService = StockfishService();
  late final _lichessTokenController =
      TextEditingController(text: _settings.lichessApiToken);

  static const List<(String, String)> _analysisPanelToggles = [
    ('Stablo poteza', 'move_tree'),
    ('Taktički motivi', 'tactical_motifs'),
    ('Pozicioni faktori', 'positional_factors'),
    ('Opening Explorer (baza otvaranja)', 'opening_explorer'),
    ('Sud o potezu (teorija / igrivo / greška)', 'opening_judge'),
    ('Tablebase (Syzygy)', 'syzygy'),
    ('Panel analize engine-a', 'engine_analysis'),
  ];

  Future<void> _openEngineSettings() async {
    await showEngineSettingsDialog(context,
        stockfishService: _stockfishService);
    await _settings.refreshCustomEnginePath();
  }

  /// Opens the Lichess token form with the description filled in and no scope
  /// asked for. A browser that refuses to open says so — a button that looks
  /// like it worked and did nothing is the worst of the three outcomes.
  Future<void> _openLichessTokenPage() async {
    final uri = Uri.parse(OpeningExplorerService.createTokenUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppFeedback.show(
        context,
        () => SnackBar(
          content: Text('Nije moguće otvoriti lichess.org u pregledaču.',
              style: AppText.body.copyWith(color: context.colors.canvas)),
          backgroundColor: context.colors.danger,
        ),
      );
    }
  }

  /// Puts the build line on the clipboard, so it can be pasted into a bug
  /// report without being copied off the screen by hand.
  Future<void> _copyBuildLabel() async {
    final label = buildLabel();
    await Clipboard.setData(ClipboardData(text: label));
    if (!mounted) return;
    // Do the thing, then say it.
    AppFeedback.show(
      context,
      () => SnackBar(content: Text('Kopirano: $label')),
    );
  }

  Future<void> _saveLichessToken() async {
    await _settings.setLichessApiToken(_lichessTokenController.text);
    if (!mounted) return;
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text(
          _settings.lichessApiToken.isEmpty
              ? 'Token uklonjen.'
              : 'Lichess token sačuvan.',
          style: AppText.body.copyWith(color: context.colors.canvas),
        ),
        backgroundColor: context.colors.success,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Whoever opens this screen is usually here because of the voice, and may
    // have installed one since the app started. Asking again costs a moment
    // and saves a restart.
    SpeechService.instance.refresh();
  }

  /// Turning speech on has to reach two places: what is remembered, and what
  /// is running. Writing only the setting left the voice silent until a
  /// restart, which reads as the switch not working.
  Future<void> _setSpeechEnabled(bool enabled) async {
    await _settings.setSpeechEnabled(enabled);
    await SpeechService.instance.setEnabled(enabled);
  }

  Future<void> _setSpeechLanguage(String language) async {
    await _settings.setSpeechLanguage(language);
    await SpeechService.instance.setLanguage(language);
  }

  Future<void> _setSpeechRate(double rate) async {
    await _settings.setSpeechRate(rate);
    await SpeechService.instance.setRate(rate);
  }

  /// Everything that can be read wrongly, in one sentence.
  ///
  /// Not a greeting: the parts of a chess sentence that a voice gets wrong are
  /// the file names, the ordinals and the notation, so the test button says all
  /// three. If the files come out sounding English, the voice chosen is an
  /// English one - which the list says, and which this makes audible.
  static const _speechSample =
      'Linije se čitaju ovako: a, b, c, d, e, f, g, h. '
      'Greška je napravljena u 8. potezu, posle Rd8.';

  /// The FEN the previews are drawn from.
  ///
  /// The opening position rather than a contrived one: it is the board a
  /// reader recognises, it puts both colours on both square colours, and the
  /// back ranks are exactly where a piece skin succeeds or fails.
  static const _previewFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// One choice, drawn as whatever it would look like if it were chosen.
  ///
  /// [preview] is built by the caller rather than described to this method,
  /// because a board skin and a piece skin are judged by looking at different
  /// things — a whole board for the squares, four large pieces for the pieces.
  Widget _skinChoice(
    BuildContext context, {
    required String name,
    required bool selected,
    required Widget preview,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: AppRadii.roundedSm,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadii.roundedSm,
            border: Border.all(
              // Two pixels in both states, a different colour rather than a
              // different width: a border that changes width changes the tile's
              // width, and a Wrap then re-flows under the finger that just
              // tapped it.
              color: selected ? context.colors.accent : context.colors.border,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              preview,
              const SizedBox(height: AppSpacing.xs),
              Text(
                name,
                style: AppText.caption.copyWith(
                  color: selected
                      ? context.colors.accent
                      : context.colors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Four pieces on two squares of the chosen board, at a size where the fill
  /// and the stroke are separately visible.
  ///
  /// A [BoardThumbnail] is the wrong preview here: at the width this card can
  /// spare, one of its squares is about nine pixels, and a piece skin is a fill
  /// colour, a stroke colour and a decoration colour that all disappear at that
  /// size. The board previews above use a whole board because square colours
  /// are what a whole board shows.
  Widget _piecePreview(BoardSkin board, PieceSkin pieces) {
    // 30 rather than 34 for one reason that is arithmetic rather than taste:
    // four squares plus the tile's padding and border come to 140, and two of
    // those fit the 316 dp a card has on a 360 dp phone. At 34 they do not, and
    // the three piece sets stack into three rows of one.
    const square = 30.0;
    return ClipRRect(
      borderRadius: AppRadii.roundedXs,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        // A white piece on a dark square and a black piece on a light one, and
        // then the other way round: the two pairings that fail are a pale piece
        // on a pale square and a dark one on a dark square, so both are shown.
        children: [
          for (final (letter, isLight) in const [
            ('K', false),
            ('p', true),
            ('N', true),
            ('q', false),
          ])
            Container(
              width: square,
              height: square,
              color: isLight ? board.lightSquare : board.darkSquare,
              alignment: Alignment.center,
              child: chessPieceWidget(letter, size: square - 4, skin: pieces),
            ),
        ],
      ),
    );
  }

  /// Theme, board and pieces — the three questions about how the app looks.
  ///
  /// The theme picker was removed in August 2026 and is back because
  /// `AppTheme.light` now carries a full `AppColorTokens.light`; before that,
  /// choosing "Svetla" painted dark-theme text on a light scaffold. The board
  /// and piece skins are deliberately *not* part of the theme: a green board in
  /// the light theme is a legitimate choice, so a skin survives a switch
  /// between light and dark untouched.
  Widget _appearanceCard(BuildContext context) {
    final board = _settings.boardSkin;
    final pieces = _settings.pieceSkin;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tema aplikacije:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.sm),
            // A Wrap rather than a Row or a SegmentedButton: three Serbian
            // labels plus a large text scale is exactly the shape that gets
            // clipped without a word of warning in a release build.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final entry in AppSettingsService.kThemeModeNames.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _settings.themeMode == entry.key,
                    onSelected: (_) => _settings.setThemeMode(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Sistem prati podešavanje telefona ili računara. Boje table se '
              'biraju odvojeno i ne menjaju se sa temom.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            const Divider(height: 24),
            const Text('Boja table:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final skin in BoardSkin.all)
                  _skinChoice(
                    context,
                    name: skin.name,
                    selected: skin.id == board.id,
                    // The pieces on it are the chosen ones, so this row also
                    // answers "how do my pieces look on that board".
                    preview: BoardThumbnail(
                      fen: _previewFen,
                      size: 72,
                      skin: skin,
                      pieceSkin: pieces,
                    ),
                    onTap: () => _settings.setBoardSkin(skin.id),
                  ),
              ],
            ),
            const Divider(height: 24),
            const Text('Figure:',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final skin in PieceSkin.all)
                  _skinChoice(
                    context,
                    name: skin.name,
                    selected: skin.id == pieces.id,
                    preview: _piecePreview(board, skin),
                    onTap: () => _settings.setPieceSkin(skin.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Figure se crtaju na izabranoj tabli, pa se ovde vidi i kako '
              'stoje jedne pored drugih.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  /// The stated year of birth, and the way back to it.
  ///
  /// The gate asks once and then never appears again, so without this row a
  /// mistyped year would be permanent — and the year decides whether the
  /// account is treated as a child's. It says out loud when nothing has been
  /// stated, rather than showing an empty value that reads as "fine".
  Widget _birthYearCard(BuildContext context) {
    final standing = AccountStandingService.instance;
    return AnimatedBuilder(
      animation: standing,
      builder: (context, _) {
        final known = standing.current?.birthYear;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
          child: ListTile(
            leading: Icon(Icons.cake_outlined, color: context.colors.accent),
            title: const Text('Godina rođenja'),
            subtitle: Text(known == null
                ? 'Nije uneta.'
                : '$known — dodirnite da ispravite.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.birthYear),
          ),
        );
      },
    );
  }

  /// The address a parent is written to, shown only when there is a parent to
  /// write to — that is, when the server says this account belongs to a minor.
  ///
  /// An empty row here is not cosmetic: a relationship with a trainer stops at
  /// "waiting for a parent" and stays there until an address exists, so this is
  /// where a stuck relationship is unstuck. Saving one sends whatever was
  /// waiting.
  Widget _parentEmailCard(BuildContext context) {
    final standing = AccountStandingService.instance;
    return AnimatedBuilder(
      animation: standing,
      builder: (context, _) {
        final current = standing.current;
        if (current == null || !current.minor) return const SizedBox.shrink();
        final onFile = current.parentEmailOnFile;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
            child: ListTile(
              leading: Icon(
                onFile ? Icons.mark_email_read_outlined : Icons.email_outlined,
                color: onFile ? context.colors.accent : context.colors.warning,
              ),
              title: const Text('Email roditelja'),
              subtitle: Text(onFile
                  ? 'Upisan. Dodirnite da ga promenite — poruka o saglasnosti '
                      'ide na novu adresu.'
                  : 'Nije upisan. Bez njega trener ne može da radi sa vama.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showParentEmailDialog(context),
            ),
          ),
        );
      },
    );
  }

  Widget _speechCard(BuildContext context) {
    final speech = SpeechService.instance;
    return AnimatedBuilder(
      animation: speech,
      builder: (context, _) {
        final languages = speech.availableLanguages;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Izgovaraj poruke',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Poruke iz info panela se čitaju naglas, da pogled može da '
                    'ostane na tabli.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                  value: _settings.speechEnabled,
                  onChanged: _setSpeechEnabled,
                ),
                if (speech.state == SpeechState.noVoice ||
                    speech.state == SpeechState.failed) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber,
                          color: context.colors.warning, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          speech.state == SpeechState.failed
                              ? 'Ovaj uređaj nema sintezu govora, pa čitanje '
                                  'nije moguće.'
                              : 'Nema instaliranog glasa za srpski. Windows ga '
                                  'i ne nudi — instalirajte hrvatski '
                                  '(Podešavanja → Vreme i jezik → Govor → '
                                  'Dodaj glasove), koji čita srpski latinični '
                                  'tekst ispravno. Na Androidu: Podešavanja → '
                                  'Pristupačnost → Tekst u govor.',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: speech.refresh,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Potraži glasove ponovo'),
                    ),
                  ),
                ],
                if (languages.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text('Jezik govora:',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButton<String>(
                    isExpanded: true,
                    // Only a value the list actually holds. A DropdownButton
                    // whose value is missing from its items does not fall back
                    // to the hint - it asserts, and takes the screen with it.
                    value: languages.contains(speech.language)
                        ? speech.language
                        : null,
                    hint: const Text('Izaberite glas'),
                    items: [
                      for (final language in languages)
                        DropdownMenuItem(
                          value: language,
                          child: Text(SpeechService.fitsSerbian(language)
                              ? '$language · čita srpski'
                              : language),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _setSpeechLanguage(value);
                    },
                  ),
                  Text(
                    'Spisak je ono što uređaj stvarno ima. Glas koji ne čita '
                    'srpski sme da se izabere — pročitaće naš tekst svojom '
                    'fonetikom, što je korisno da se čuje, ali nije za rad. '
                    'Jezik same aplikacije je zasebno pitanje i čeka prevod '
                    'svih tekstova.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Brzina čitanja:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      _settings.speechRate.toStringAsFixed(2),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: context.colors.accent),
                    ),
                  ],
                ),
                Slider(
                  value: _settings.speechRate.clamp(0.2, 1.0),
                  min: 0.2,
                  max: 1.0,
                  divisions: 8,
                  label: _settings.speechRate.toStringAsFixed(2),
                  activeColor: context.colors.accent,
                  onChanged: _setSpeechRate,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _settings.speechEnabled
                        ? () => speech.speak(_speechSample, force: true)
                        : null,
                    icon: const Icon(Icons.volume_up, size: 16),
                    label: const Text('Probaj'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _lichessTokenController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    // Only the credentials go: prefs.clear() used to also wipe the engine path,
    // board scale, panel layout and Lichess token, which survive a sign-out.
    await SessionService.instance.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Podešavanja Aplikacije'),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // User Profile Header Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
                elevation: 2,
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: context.colors.brand,
                        child: Text(
                          widget.session.name.isNotEmpty
                              ? widget.session.name[0].toUpperCase()
                              : 'K',
                          style: AppText.display
                              .copyWith(color: context.colors.canvas),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.session.name,
                              style: AppText.headline,
                            ),
                            Text(
                              widget.session.email,
                              style: AppText.bodyLarge
                                  .copyWith(color: context.colors.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs),
                              decoration: BoxDecoration(
                                color: context.colors.accent
                                    .withValues(alpha: 0.2),
                                borderRadius: AppRadii.roundedSm,
                              ),
                              child: Text(
                                'Korisnik',
                                style: AppText.captionBold
                                    .copyWith(color: context.colors.accent),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          widget.session.isGuest ? Icons.login : Icons.logout,
                          color: widget.session.isGuest
                              ? context.colors.success
                              : context.colors.danger,
                        ),
                        tooltip:
                            widget.session.isGuest ? 'Prijavi se' : 'Odjavi se',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Odjava'),
                              content: const Text(
                                  'Da li ste sigurni da želite da se odjavite?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Otkaži')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: context.colors.danger,
                                      foregroundColor: context.colors.canvas),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _logout();
                                  },
                                  child: const Text('Odjavi se'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // A language picker for the *app* used to live here, but there
              // is no localization layer — every string is hardcoded Serbian —
              // so it silently did nothing. Re-add it together with real i18n.
              // The voice's language is a different question and is settable
              // below: it picks among the voices the machine actually has.

              const SizedBox(height: AppSpacing.xxl),
              Text('IZGLED',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),
              _appearanceCard(context),

              const SizedBox(height: AppSpacing.xxl),
              Text('NALOG',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),
              // Moved here from the first tab, where it was the first thing
              // under the buttons for starting a lesson. A plan name and a
              // saved-position count are facts about the account, and this is
              // the screen about the account.
              AccountStatsCard(session: widget.session),

              const SizedBox(height: AppSpacing.xxl),
              Text('STOCKFISH ENGINE',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),

              Card(
                shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // What is left in Settings is the *opponent*: how
                      // strongly the engine plays and how long it may think.
                      // How deep a board analyses, and how many lines it shows,
                      // moved onto the boards themselves on 27.8.2026 — one
                      // number used to answer both questions, so turning the
                      // opponent down to help a beginner also made every
                      // evaluation in the app shallower.
                      const Text('Jačina motora kada igra protiv vas:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<String>(
                        segments: [
                          for (final entry in AppSettingsService
                              .kEnginePlayLevelNames.entries)
                            ButtonSegment<String>(
                              value: entry.key,
                              label: Text(entry.value),
                            ),
                        ],
                        selected: {_settings.enginePlayLevel},
                        showSelectedIcon: false,
                        onSelectionChanged: (picked) {
                          if (picked.isEmpty) return;
                          _settings.setEnginePlayLevel(picked.first);
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Motor odigra potez čim dostigne dubinu svog nivoa — '
                        'Lako ${AppSettingsService.kEnginePlayDepths['lako']}, '
                        'Srednje ${AppSettingsService.kEnginePlayDepths['srednje']}, '
                        'Teško ${AppSettingsService.kEnginePlayDepths['tesko']} '
                        'poteza unapred.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Expanded, not a bare Text: this label is 38
                          // characters and the row it sits in overflowed by 303
                          // pixels on a 360 dp phone — invisibly, because a
                          // release build clips instead of striping.
                          const Expanded(
                            child: Text(
                                'Maksimalno vreme razmišljanja engine-a:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          Text(
                            '${_settings.defaultEngineMoveTimeSeconds} s',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.accent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.defaultEngineMoveTimeSeconds
                            .toDouble()
                            .clamp(1.0, 60.0),
                        min: 1,
                        max: 60,
                        divisions: 59,
                        label: '${_settings.defaultEngineMoveTimeSeconds} s',
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setEngineMoveTimeSeconds(val.round());
                        },
                      ),
                      Text(
                        'Motor igra potez čim dostigne dubinu svog nivoa ILI čim '
                        'istekne ovo vreme — šta se pre desi.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Dubina analize i broj linija se podešavaju na samoj '
                        'tabli, ispod prekidača „Prikaži evaluaciju" — na '
                        'svakom ekranu gde se evaluacija prikazuje. Poslednje '
                        'izabrano važi i za sledeću tablu koju otvorite.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (isCustomEngineSupported) ...[
                        const Divider(height: 24),
                        const Text('Lokalni engine (.exe):',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _settings.customEnginePath.isNotEmpty
                              ? _settings.customEnginePath
                              : 'Podrazumevani (Online / FFI paket)',
                          style: AppText.caption.copyWith(
                            color: _settings.customEnginePath.isNotEmpty
                                ? context.colors.accent
                                : context.colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _openEngineSettings,
                            icon: const Icon(Icons.settings_suggest, size: 16),
                            label: const Text('Podesi lokalni engine'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              Text('IZGLED TABLE I PANELA',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),

              Card(
                shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('Veličina table:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          Text(
                            '${(_settings.boardSizeScale * 100).round()}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.accent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.boardSizeScale.clamp(0.6, 1.0),
                        min: 0.6,
                        max: 1.0,
                        divisions: 8,
                        label: '${(_settings.boardSizeScale * 100).round()}%',
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setBoardSizeScale(val);
                        },
                      ),
                      Text(
                        'Smanjite tablu da biste oslobodili više prostora za panele pored nje.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Koordinate oko table',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          'Slova i brojevi uz ivicu table, na svim ekranima. '
                          'Isti prekidač stoji i na samim ekranima sa tablom.',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted),
                        ),
                        value: _settings.showBoardCoordinates,
                        onChanged: (val) =>
                            _settings.setShowBoardCoordinates(val),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('Animacija poteza:',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          Text(
                            _settings.moveAnimationDurationMs == 0
                                ? 'Isključeno'
                                : '${_settings.moveAnimationDurationMs} ms',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: context.colors.accent),
                          ),
                        ],
                      ),
                      Slider(
                        value: _settings.moveAnimationDurationMs.toDouble(),
                        min: 0,
                        max: 500,
                        divisions: 10,
                        label: _settings.moveAnimationDurationMs == 0
                            ? 'Isključeno'
                            : '${_settings.moveAnimationDurationMs} ms',
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setMoveAnimationDurationMs(val.round());
                        },
                      ),
                      Text(
                        'Koliko dugo figura klizi ka odredišnom polju. Krajnje levo isključuje animaciju.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      const Text('Paneli u Analizi (Tabla za Analizu):',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: AppSpacing.xs),
                      ..._analysisPanelToggles.map((panel) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            value: _settings.isPanelVisible(panel.$2),
                            title: Text(panel.$1, style: AppText.bodyLarge),
                            activeColor: context.colors.accent,
                            onChanged: (val) {
                              _settings.setPanelVisible(panel.$2, val ?? true);
                            },
                          )),
                      const Divider(height: 24),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        value: _settings.manualCommentMode,
                        title: const Text(
                            'Ručno biranje komentara u stablu poteza',
                            style: AppText.bodyLarge),
                        subtitle: Text(
                          'Isključi automatski komentar — sam biraš koje nalaze da zadržiš iz ponuđene liste.',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted),
                        ),
                        activeColor: context.colors.accent,
                        onChanged: (val) {
                          _settings.setManualCommentMode(val ?? false);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              Text('GOVOR (ČITANJE PORUKA)',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),
              _speechCard(context),

              if (!widget.session.isGuest) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('NALOG',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textMuted)),
                const SizedBox(height: AppSpacing.sm),
                _birthYearCard(context),
                _parentEmailCard(context),
              ],

              const SizedBox(height: AppSpacing.xxl),
              Text('PREČICE NA TASTATURI',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),

              Card(
                shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
                child: ListTile(
                  leading: Icon(Icons.keyboard, color: context.colors.accent),
                  title: const Text('Spisak prečica'),
                  // The row exists because the keys are invisible. Ctrl+, was
                  // built, tested and unusable for exactly as long as there was
                  // nowhere to read that it existed.
                  subtitle:
                      const Text('Šta koji taster radi. Isto otvara i F1.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.shortcuts),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
              Text('BAZA OTVARANJA (OPENING EXPLORER)',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textMuted)),
              const SizedBox(height: AppSpacing.sm),

              Card(
                shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Izvor podataka:',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Lichess'),
                              selected: _settings.openingDbSource == 'lichess',
                              onSelected: (_) =>
                                  _settings.setOpeningDbSource('lichess'),
                              avatar: const Icon(Icons.bar_chart, size: 16),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('ChessDB'),
                              selected: _settings.openingDbSource == 'chessdb',
                              onSelected: (_) =>
                                  _settings.setOpeningDbSource('chessdb'),
                              avatar: const Icon(Icons.memory, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _settings.openingDbSource == 'lichess'
                            ? 'Lichess: popularnost poteza iz stvarno odigranih partija igrača. Ne traži nikakvo podešavanje — upit ide preko našeg servera, koji pamti odgovore.'
                            : 'ChessDB: procena kvaliteta poteza iz deljene baze motorske analize (chessdb.cn) — ne pokazuje statistiku odigranih partija.',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const Divider(height: 24),
                      Text(
                        'Lični Lichess token nije potreban. Unesite ga samo ako želite da vaši upiti idu direktno na Lichess, na vaš nalog, umesto preko zajedničkog. Dugme otvara stranicu sa već popunjenim opisom i bez ijedne tražene dozvole — ostaje samo „Create".',
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _lichessTokenController,
                        obscureText: true,
                        style: AppText.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Lichess API token (nije obavezan)',
                          hintText: 'lip_...',
                          isDense: true,
                          border: const OutlineInputBorder(),
                          suffixIcon: _settings.lichessApiToken.isNotEmpty
                              ? Icon(Icons.check_circle,
                                  color: context.colors.accent, size: 18)
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Wrap, not Row: two buttons and a long label fit on a
                      // desktop and do not on a 360 dp phone, where a release
                      // build clips the overflow without a word of warning.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openLichessTokenPage,
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Napravi token'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _saveLichessToken,
                            icon: const Icon(Icons.save, size: 16),
                            label: const Text('Sačuvaj token'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Which build this is, and a tap to carry it into a report.
              //
              // It used to read "Šahovski trener v2.0 • Pro Edition" - a name
              // the app has not carried since the brand was chosen, and a
              // version that was never in pubspec. During a testing campaign
              // the one thing this line is good for is saying which build the
              // tester is looking at, so that is what it says.
              Center(
                child: InkWell(
                  onTap: _copyBuildLabel,
                  borderRadius: AppRadii.roundedSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Text(
                      buildLabel(),
                      textAlign: TextAlign.center,
                      style: AppText.body
                          .copyWith(color: context.colors.textMuted),
                    ),
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.roundedMd,
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.palette_outlined,
                      color: context.colors.brand,
                    ),
                    title: const Text('Galerija dizajna (Debug)'),
                    subtitle: const Text(
                      'Pregled palete boja, tipografije, dugmadi i komponenti.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.designGallery),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}
