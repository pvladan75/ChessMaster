import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/build_info.dart';
import 'package:chess_app/core/user_manual.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/saved_sign_ins.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/widgets/account_stats_card.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/widgets/parent_email_dialog.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/app_slider.dart';

class SettingsScreen extends StatefulWidget {
  final UserSession session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettingsService.instance;
  final _stockfishService = StockfishService();

  Future<void> _openEngineSettings() async {
    await showEngineSettingsDialog(context,
        stockfishService: _stockfishService);
    await _settings.refreshCustomEnginePath();
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
      () => SnackBar(content: Text('Copied: $label')),
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
      'Files are read as follows: a, b, c, d, e, f, g, h. '
      'Mistake was made on move 8, after Rd8.';

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
            const Text('App theme:',
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
              'System follows your phone or computer settings. Board colors are '
              'chosen separately and do not change with the theme.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            const Divider(height: 24),
            const Text('Board color:',
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
            const Text('Pieces:',
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
              'Pieces are rendered on the selected board, showing how they '
              'look side by side.',
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
            title: const Text('Birth year'),
            subtitle:
                Text(known == null ? 'Not set.' : '$known — tap to correct.'),
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
              title: const Text('Parent email'),
              subtitle: Text(onFile
                  ? 'Saved. Tap to change — the consent email '
                      'will be sent to the new address.'
                  : 'Not saved. Without it the trainer cannot work with you.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showParentEmailDialog(context),
            ),
          ),
        );
      },
    );
  }

  /// „Saved sign-in on this computer": where „Remember me" kept this
  /// account's password, and the way to take it back
  /// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md` §4.1). Drawn only while one is
  /// kept, which is only ever on Windows — a row that says „nothing saved"
  /// on every phone would be a row about nothing. A guest never reaches it:
  /// the section it stands in is drawn only for a signed-in account, and
  /// that one guard is the one the tests hold.
  Widget _savedSignInCard(BuildContext context) {
    final saved = SavedSignIns.instance;
    return AnimatedBuilder(
      animation: saved,
      builder: (context, _) {
        final email = widget.session.email;
        if (!saved.hasPassword(email)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
            // „Forget" under the sentence rather than beside it: in a column
            // 281 px wide (three columns at the smallest window) a trailing
            // button squeezed the title into four lines of one word each.
            child: Padding(
              key: const Key('saved-sign-in'),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Icon(Icons.key, color: context.colors.accent),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saved sign-in on this computer',
                            style: AppText.bodyLarge),
                        Text(
                          'Your email and password are kept in '
                          '${saved.storeName}.',
                          style: AppText.body
                              .copyWith(color: context.colors.textMuted),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const Key('forget-saved-sign-in'),
                            onPressed: () => _forgetSavedSignIn(email),
                            child: const Text('Forget'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Done first, then said — and a store that would not let go is said too,
  /// because a „Forget" that left the password behind must not read as done.
  Future<void> _forgetSavedSignIn(String email) async {
    final gone = await SavedSignIns.instance.forget(email);
    if (!mounted) return;
    if (gone) {
      AppFeedback.success(
          context,
          'Forgotten. The next sign-in on this computer asks for your email '
          'and password.');
    } else {
      AppFeedback.warning(
          context,
          'The password could not be removed from '
          '${SavedSignIns.instance.storeName}. Remove it there.');
    }
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
                  title: const Text('Speak messages',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Messages from the info panel are read aloud so your eyes '
                    'can stay on the board.',
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
                              ? 'This device does not have speech synthesis, so reading '
                                  'is not available.'
                              : 'No installed voice found for this language. On Windows: '
                                  'Settings → Time & Language → Speech → Add voices. '
                                  'On Android: Settings → Accessibility → Text-to-speech.',
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
                      label: const Text('Check for voices again'),
                    ),
                  ),
                ],
                if (languages.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text('Speech language:',
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
                    hint: const Text('Choose a voice'),
                    items: [
                      for (final language in languages)
                        DropdownMenuItem(
                          value: language,
                          child: Text(SpeechService.fitsAppLanguage(language)
                              ? '$language · supported'
                              : language),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _setSpeechLanguage(value);
                    },
                  ),
                  Text(
                    'This list shows the voices installed on your device. '
                    'Voices will pronounce text using their own phonetics.',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
                ],
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Speech rate:',
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
                AppSlider(
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
                    label: const Text('Test'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    // Only the credentials go: prefs.clear() used to also wipe the engine path,
    // board scale and panel layout, which survive a sign-out.
    await SessionService.instance.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  /// Asked before signing out, as it always was; only the words changed —
  /// „Sign out", the verb the sign-in screen and the age gate already use.
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.danger,
                foregroundColor: context.colors.canvas),
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  /// Who is signed in, and the way out — or, for a guest, the way in.
  ///
  /// Three things changed on 29.9.2026 (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`,
  /// D6). The button has a label: it was an icon with a tooltip, and for a
  /// guest the icon said „Log in" while the click asked „Are you sure you
  /// want to log out?" (F2) — a guest now goes straight to the sign-in
  /// screen, with nothing to confirm. A guest is „Guest", with no address
  /// (F3). And the „User" badge is gone: it once showed the role, which
  /// decides nothing now but `admin` (F4).
  Widget _profileStrip(BuildContext context) {
    final guest = widget.session.isGuest;
    final name = widget.session.name;
    final button = guest
        ? FilledButton.tonalIcon(
            key: const Key('settings-sign-in'),
            onPressed: () => context.go(AppRoutes.login),
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
          )
        : OutlinedButton.icon(
            key: const Key('settings-sign-out'),
            onPressed: _confirmSignOut,
            style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.danger),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          );
    final who = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: AppText.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(
          guest
              ? 'Not signed in. Sign in to keep your work and join sessions.'
              : widget.session.email,
          style: AppText.bodyLarge.copyWith(color: context.colors.textMuted),
          maxLines: guest ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return Card(
      key: const Key('settings-profile'),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
      elevation: 2,
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        // On a phone the button goes under the name, so the address keeps
        // the width it needs to be read.
        child: LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 480;
          return Row(
            crossAxisAlignment:
                narrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: context.colors.brand,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppText.display.copyWith(color: context.colors.canvas),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          who,
                          const SizedBox(height: AppSpacing.sm),
                          button,
                        ],
                      )
                    : who,
              ),
              if (!narrow) ...[
                const SizedBox(width: AppSpacing.lg),
                button,
              ],
            ],
          );
        }),
      ),
    );
  }

  /// One section: its heading and its cards, dealt as a unit into the
  /// columns. The gap under it is its own, because the columns add none.
  Widget _section(BuildContext context, String title, List<Widget> cards) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style:
                  AppText.bodyBold.copyWith(color: context.colors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          ...cards,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('App Settings'),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _profileStrip(context),
              const SizedBox(height: AppSpacing.xxl),

              // A language picker for the *app* used to live here, but there
              // is no localization layer, so it silently did nothing. Re-add
              // it together with real i18n. The voice's language is a
              // different question and is settable below: it picks among the
              // voices the machine actually has.

              // The sections flow into columns — four in a 1536 px window,
              // three at the 900 px minimum, one on a phone, in this order
              // (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D2 A; the rule the
              // Home and Teach tabs use, `PLAN-POCETNI-TABOVI.md` §3). Here a
              // whole section is the peer card: each holds one to five small
              // cards, and a section stretched across the width with one
              // card in it would be a row of air.
              AdaptiveCardColumns(
                children: [
                  _section(context, 'ACCOUNT', [
                    // Moved here from the first tab, where it was the first
                    // thing under the buttons for starting a session. A plan
                    // name and a saved-position count are facts about the
                    // account, and this is the screen about the account.
                    AccountStatsCard(session: widget.session),
                    // A signed-in account's month, its year of birth, its
                    // parent's address and its saved sign-in. A guest has no
                    // account for any of them — one guard, here, for all four.
                    if (!widget.session.isGuest) ...[
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: AppRadii.roundedMd),
                        child: ListTile(
                          key: const Key('open-usage'),
                          leading: Icon(Icons.data_usage,
                              color: context.colors.accent),
                          title: const Text('Usage this month'),
                          subtitle: const Text(
                              'What your account has used, and your plan\'s '
                              'monthly limits.'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(AppRoutes.usage),
                        ),
                      ),
                      _birthYearCard(context),
                      _parentEmailCard(context),
                      _savedSignInCard(context),
                    ],
                  ]),
                  _section(context, 'APPEARANCE', [_appearanceCard(context)]),
                  // Two sections until 29.9.2026, each with too little to
                  // stand alone once the 17.9 review had moved everything else
                  // onto the screens that read it.
                  _section(context, 'BOARD AND ENGINE', [
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.roundedMd),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Board coordinates',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                'Letters and numbers along the board edges on all screens. '
                                'The same toggle is also available on board screens.',
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
                                  child: Text('Move animation:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ),
                                Text(
                                  _settings.moveAnimationDurationMs == 0
                                      ? 'Off'
                                      : '${_settings.moveAnimationDurationMs} ms',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.accent),
                                ),
                              ],
                            ),
                            AppSlider(
                              value:
                                  _settings.moveAnimationDurationMs.toDouble(),
                              min: 0,
                              max: 500,
                              divisions: 10,
                              label: _settings.moveAnimationDurationMs == 0
                                  ? 'Off'
                                  : '${_settings.moveAnimationDurationMs} ms',
                              activeColor: context.colors.accent,
                              onChanged: (val) {
                                _settings
                                    .setMoveAnimationDurationMs(val.round());
                              },
                            ),
                            Text(
                              'How long a piece slides to the destination square. Far left disables animation.',
                              style: AppText.caption
                                  .copyWith(color: context.colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.roundedMd),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The opponent's strength and think time moved onto
                            // the exercise screen on 17.9.2026, the one screen that
                            // reads them; the analysis dials went onto every board
                            // on 27.8.2026. What is left here is where things are.
                            Text(
                              'Analysis depth and number of lines are set on the board '
                              'itself, below the "Show evaluation" toggle — on '
                              'every screen where evaluation is shown. How strongly '
                              'the engine plays against you is set on the exercise '
                              'screen. The last selection applies to the next board '
                              'you open.',
                              style: AppText.caption
                                  .copyWith(color: context.colors.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (isCustomEngineSupported) ...[
                              const Divider(height: 24),
                              const Text('Local engine (.exe):',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _settings.customEnginePath.isNotEmpty
                                    ? _settings.customEnginePath
                                    : 'Default (Online / FFI package)',
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
                                  icon: const Icon(Icons.settings_suggest,
                                      size: 16),
                                  label: const Text('Configure local engine'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ]),
                  _section(context, 'SPEECH (READING MESSAGES)',
                      [_speechCard(context)]),
                  _section(context, 'HELP', [
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.roundedMd),
                      child: ListTile(
                        key: const Key('open-user-manual'),
                        leading:
                            Icon(Icons.menu_book, color: context.colors.accent),
                        title: const Text('User manual'),
                        // Task by task, because „where is the button for this?" is
                        // the question the manual exists to answer
                        // (docs/PLAN-PRIRUCNIK.md).
                        subtitle: const Text(
                            'What you can do in the app, and where to find it. '
                            'Opens in your browser.'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => openUserManual(context),
                      ),
                    ),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.roundedMd),
                      child: ListTile(
                        leading:
                            Icon(Icons.keyboard, color: context.colors.accent),
                        title: const Text('Keyboard shortcuts'),
                        // The row exists because the keys are invisible. Ctrl+, was
                        // built, tested and unusable for exactly as long as there was
                        // nowhere to read that it existed.
                        subtitle: const Text(
                            'What each key does. F1 also opens this.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.shortcuts),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
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
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
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
                          title: const Text('Design Gallery (Debug)'),
                          subtitle: const Text(
                            'Preview color palette, typography, buttons, and components.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(AppRoutes.designGallery),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
