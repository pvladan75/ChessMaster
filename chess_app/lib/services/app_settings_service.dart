import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/theme/board_skins.dart';

/// The rating bands a repertoire can be built against.
///
/// Lichess's own Explorer buckets, and only those: a band is a bucket floor and
/// the answer unions everything above it, so 1600 means "1600 and up". The
/// server validates against the same list and refuses an unknown value by name,
/// which is why 1500 and 2100 are not options — they do not exist.
///
/// Masters is deliberately not on this ladder. It is a different database
/// answering a different question — "what is theory" rather than "what will I
/// meet" — and putting it at the top would quietly change what the number
/// means.
const List<int> kRepertoireRatingBands = [1400, 1600, 1800, 2000];

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();

  AppSettingsService._internal();

  /// Dark until something stored says otherwise, because dark is what this app
  /// has always opened as and a fresh install should not look like a different
  /// program.
  ThemeMode _themeMode = ThemeMode.dark;

  /// How hard the engine plays **when it is the one making the move**.
  ///
  /// Three levels rather than a depth in plies, because that is the question a
  /// person actually has: "how strong an opponent do I want". The depths behind
  /// them are [kEnginePlayDepths]. Until 27.8.2026 this one number was also the
  /// depth every board analysed at, so making the opponent easier quietly made
  /// every evaluation in the app shallower — two unrelated questions answered
  /// by one slider. Analysis now asks the board it is on.
  String _enginePlayLevel = 'srednje';

  /// How long the engine may think before it has to move anyway, when the
  /// depth above has not been reached in time.
  int _defaultEngineMoveTimeSeconds = 2;

  /// Where a board's own depth/line dials start, and where they are remembered.
  ///
  /// Not the same as the play level and deliberately kept apart from it: a
  /// person who wants an easy opponent still wants to see what the engine
  /// really thinks of the position.
  int _analysisDepth = 20;

  /// Which rating band the opening book answers from, for the repertoire.
  ///
  /// 1600 by default, and that is a decision rather than a middle value: it is
  /// the club and youth-competitive baseline, so Top-1 is what the student will
  /// actually meet rather than what is theoretically best. A repertoire built
  /// against 2200 games prepares for opponents this child does not have.
  ///
  /// Only the values Lichess's Explorer knows. 1500 and 2100 are not among
  /// them — the server refuses an unknown one by name — so the ladder is theirs
  /// and not ours.
  int _repertoireMinRating = 1600;
  int _analysisLines = 3;
  String _customEnginePath = '';
  double _boardSizeScale = 1.0;
  Set<String> _hiddenPanels = {};
  String _lichessApiToken = '';
  bool _manualCommentMode = false;

  /// How long a piece takes to slide from its origin to destination square
  /// after a move. 0 disables the animation (piece snaps instantly, as
  /// flutter_chess_board does natively).
  int _moveAnimationDurationMs = 200;

  /// Spoken feedback: whether the app reads its messages out loud, how fast,
  /// and with which of the machine's voices.
  ///
  /// The language is stored as the engine named it rather than as a code the
  /// app invented, because it is handed straight back to the engine. An empty
  /// string means "whatever fits Serbian best", which is what a machine with a
  /// newly installed voice should do without anyone going into settings.
  /// What the board is allowed to draw on top of the pieces.
  ///
  /// Three separate switches because they answer three different questions and
  /// arrive from three different places: the arrow for the move you chose, the
  /// statistics arrows out of the opening book, and the engine's lines. All
  /// three default to on — that is what the app does today, and a switch that
  /// silently turns something off on upgrade is a bug report about a missing
  /// feature.
  ///
  /// Per device, like every other setting here: the same repertoire on a phone
  /// and on a desktop can reasonably want different amounts of ink.
  bool _showChosenMoveArrow = true;
  bool _showStatisticsArrows = true;
  bool _showEngineArrows = true;

  /// How many positions a day the reader is aiming for.
  ///
  /// Ten by default, and it is a target rather than a limit: nothing stops at
  /// it and nothing is withheld before it. It exists because the schedule alone
  /// gives a beginner nothing to do on day three — and a number somebody can
  /// finish is the difference between a habit and an app that says „nema ništa
  /// za danas".
  ///
  /// Zero turns the whole thing off, for somebody who does not want to be
  /// counted.
  int _dailyTarget = 10;

  bool _speechEnabled = false;
  double _speechRate = 0.5;
  String _speechLanguage = '';

  /// Whether the endgame trainer also serves positions and games mined from
  /// online play.
  ///
  /// Off by default, and that is the whole point of the setting. Over-the-board
  /// games and the master bases are one pool; online is a different rating
  /// scale wearing the same numbers, and difficulty in the trainer is the
  /// rating of whoever got the position wrong.
  bool _endgameIncludeOnline = false;

  /// Whether boards are framed with file letters and rank numbers.
  ///
  /// On by default. The people this app is for are learning to read a board,
  /// and half the screens turn it around on their own — the endgame trainer
  /// orients every position toward whoever has to solve it — so "which way is
  /// this" stops being answerable from the pieces alone. It is a setting
  /// because a trainer who already reads coordinates wants the extra room the
  /// gutter takes, especially on a phone.
  bool _showBoardCoordinates = true;

  /// Which board and which pieces the reader has chosen.
  ///
  /// Stored as ids rather than as resolved skins, and **not normalised on
  /// read**: an id this build does not know falls back to `classic` when it is
  /// resolved, but the stored string is left alone. So a preference written by
  /// a newer build survives a downgrade and comes back when they upgrade
  /// again, instead of being silently overwritten with the default the older
  /// build understood.
  String _boardSkinId = BoardSkin.classic.id;
  String _pieceSkinId = PieceSkin.classic.id;

  /// Which opening database the Analysis Studio Opening Explorer panel
  /// queries: 'lichess' (real-game move popularity, needs an API token) or
  /// 'chessdb' (ChessDB.cn's shared engine analysis, no token needed).
  String _openingDbSource = 'lichess';

  ThemeMode get themeMode => _themeMode;

  /// The reader-facing name of each mode, in the order Settings offers them.
  ///
  /// Sistem first, because it is the answer that stops being a decision: the
  /// phone already knows whether it is night.
  static const Map<ThemeMode, String> kThemeModeNames = {
    ThemeMode.system: 'Sistem',
    ThemeMode.light: 'Svetla',
    ThemeMode.dark: 'Tamna',
  };

  /// The three strings that have ever been written under `app_theme_mode`,
  /// unchanged since the first picker in August 2026. They are kept exactly as
  /// they were: a preference written before the picker was removed is a
  /// preference this build has to be able to read.
  static ThemeMode _themeModeFromString(String? stored) {
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  /// The three levels, and what each one is worth in plies.
  static const Map<String, int> kEnginePlayDepths = {
    'lako': 18,
    'srednje': 24,
    'tesko': 30,
  };

  /// The reader-facing name of each level, in the order they are offered.
  static const Map<String, String> kEnginePlayLevelNames = {
    'lako': 'Lako',
    'srednje': 'Srednje',
    'tesko': 'Teško',
  };

  String get enginePlayLevel => _enginePlayLevel;

  /// The depth the engine plays to. Reading a level rather than a number
  /// everywhere means the three levels can be retuned in one place.
  int get enginePlayDepth => kEnginePlayDepths[_enginePlayLevel] ?? 24;

  int get defaultEngineMoveTimeSeconds => _defaultEngineMoveTimeSeconds;
  int get analysisDepth => _analysisDepth;
  int get repertoireMinRating => _repertoireMinRating;
  int get analysisLines => _analysisLines;
  String get customEnginePath => _customEnginePath;
  double get boardSizeScale => _boardSizeScale;
  String get lichessApiToken => _lichessApiToken;
  String get openingDbSource => _openingDbSource;
  bool get endgameIncludeOnline => _endgameIncludeOnline;
  bool get showBoardCoordinates => _showBoardCoordinates;

  /// The chosen skins, resolved. Every board in the app reads these rather than
  /// the ids, so an id nothing recognises draws `classic` instead of nothing.
  BoardSkin get boardSkin => BoardSkin.byId(_boardSkinId);
  PieceSkin get pieceSkin => PieceSkin.byId(_pieceSkinId);
  int get dailyTarget => _dailyTarget;

  bool get showChosenMoveArrow => _showChosenMoveArrow;
  bool get showStatisticsArrows => _showStatisticsArrows;
  bool get showEngineArrows => _showEngineArrows;

  bool get speechEnabled => _speechEnabled;
  double get speechRate => _speechRate;
  String get speechLanguage => _speechLanguage;

  /// When true, moves no longer get an auto-generated tactical comment —
  /// the user picks which findings to keep (plus their own text) through
  /// the comment dialog's checklist instead.
  bool get manualCommentMode => _manualCommentMode;

  int get moveAnimationDurationMs => _moveAnimationDurationMs;

  /// Panels default to visible; only explicitly hidden keys are stored, so
  /// new panels added later don't need a migration to stay visible.
  bool isPanelVisible(String key) => !_hiddenPanels.contains(key);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _themeModeFromString(prefs.getString('app_theme_mode'));

    _defaultEngineMoveTimeSeconds =
        (prefs.getInt('app_engine_movetime') ?? 2).clamp(1, 60);

    // Migration, once: the old single depth was both the opponent's strength
    // and the analysis depth. It becomes the nearest level for play, and the
    // analysis depth keeps the number the reader had actually chosen.
    final storedLevel = prefs.getString('app_engine_play_level');
    final legacyDepth = prefs.getInt('app_engine_depth');
    if (kEnginePlayDepths.containsKey(storedLevel)) {
      _enginePlayLevel = storedLevel!;
    } else if (legacyDepth != null) {
      _enginePlayLevel = _levelNearest(legacyDepth);
      await prefs.setString('app_engine_play_level', _enginePlayLevel);
    }

    _analysisDepth =
        (prefs.getInt('app_analysis_depth') ?? legacyDepth ?? 20).clamp(6, 50);
    final storedBand = prefs.getInt('app_repertoire_min_rating');
    // An unknown value falls back to the default rather than being clamped to
    // the nearest: the Explorer's buckets are a list, not a range, and 1700
    // clamped to 1600 would be a silent answer to a question nobody asked.
    _repertoireMinRating =
        kRepertoireRatingBands.contains(storedBand) ? storedBand! : 1600;
    _analysisLines = (prefs.getInt('app_analysis_lines') ??
            prefs.getInt('app_multi_pv') ??
            3)
        .clamp(1, 5);
    _customEnginePath = prefs.getString('custom_engine_path') ?? '';
    _boardSizeScale =
        (prefs.getDouble('app_board_scale') ?? 1.0).clamp(0.6, 1.0);
    _hiddenPanels = (prefs.getStringList('app_hidden_panels') ?? []).toSet();
    _lichessApiToken = prefs.getString('lichess_api_token') ?? '';
    _manualCommentMode = prefs.getBool('app_manual_comment_mode') ?? false;
    _moveAnimationDurationMs =
        (prefs.getInt('app_move_animation_ms') ?? 200).clamp(0, 500);
    _endgameIncludeOnline =
        prefs.getBool('app_endgame_include_online') ?? false;
    _showBoardCoordinates = prefs.getBool('app_board_coordinates') ?? true;
    _boardSkinId = prefs.getString('app_board_skin') ?? BoardSkin.classic.id;
    _pieceSkinId = prefs.getString('app_piece_skin') ?? PieceSkin.classic.id;
    _dailyTarget = (prefs.getInt('app_daily_target') ?? 10).clamp(0, 200);
    _showChosenMoveArrow = prefs.getBool('app_arrow_chosen_move') ?? true;
    _showStatisticsArrows = prefs.getBool('app_arrow_statistics') ?? true;
    _showEngineArrows = prefs.getBool('app_arrow_engine') ?? true;
    _speechEnabled = prefs.getBool('app_speech_enabled') ?? false;
    _speechRate = (prefs.getDouble('app_speech_rate') ?? 0.5).clamp(0.2, 1.0);
    _speechLanguage = prefs.getString('app_speech_language') ?? '';
    final storedSource = prefs.getString('app_opening_db_source');
    _openingDbSource = (storedSource == 'chessdb') ? 'chessdb' : 'lichess';
    notifyListeners();
  }

  /// Re-reads the engine path from prefs (call after EngineDownloadService
  /// or the manual file picker writes a new one).
  Future<void> refreshCustomEnginePath() async {
    final prefs = await SharedPreferences.getInstance();
    _customEnginePath = prefs.getString('custom_engine_path') ?? '';
    notifyListeners();
  }

  /// Which of the three levels is closest to a depth somebody had set by hand.
  static String _levelNearest(int depth) {
    var best = 'srednje';
    var bestGap = 1 << 30;
    kEnginePlayDepths.forEach((level, plies) {
      final gap = (plies - depth).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = level;
      }
    });
    return best;
  }

  /// Light, dark, or whatever the machine says.
  ///
  /// Until 29.8.2026 [init] stamped `dark` over whatever was stored here on
  /// every launch, because the light [ThemeData] carried no [AppColorTokens]
  /// and every screen would have painted dark-theme text on a light scaffold.
  /// `AppTheme.light` exists now, so the stamp is gone and this setter is the
  /// only thing that writes the key.
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_mode', _themeModeToString(mode));
  }

  Future<void> setEnginePlayLevel(String level) async {
    if (!kEnginePlayDepths.containsKey(level)) return;
    _enginePlayLevel = level;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_engine_play_level', level);
  }

  /// Remembers what a board's dials were last set to.
  ///
  /// Saved rather than kept per screen so the next board opens where the last
  /// one was left — the dial is still the board's, but nobody has to set it
  /// again on every screen they visit.
  /// Changes the band the repertoire's book answers from.
  ///
  /// Refuses anything the Explorer does not know, rather than clamping: the
  /// server would refuse it too, and one silent correction here would mean the
  /// screen and the server disagreed about what was asked.
  Future<void> setRepertoireMinRating(int band) async {
    if (!kRepertoireRatingBands.contains(band)) return;
    _repertoireMinRating = band;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_repertoire_min_rating', band);
  }

  Future<void> setAnalysisDepth(int depth) async {
    _analysisDepth = depth.clamp(6, 50);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_analysis_depth', _analysisDepth);
  }

  Future<void> setAnalysisLines(int count) async {
    _analysisLines = count.clamp(1, 5);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_analysis_lines', _analysisLines);
  }

  Future<void> setEngineMoveTimeSeconds(int seconds) async {
    _defaultEngineMoveTimeSeconds = seconds.clamp(1, 60);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_engine_movetime', _defaultEngineMoveTimeSeconds);
  }

  Future<void> setBoardSizeScale(double scale) async {
    _boardSizeScale = scale.clamp(0.6, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_board_scale', _boardSizeScale);
  }

  Future<void> setPanelVisible(String key, bool visible) async {
    if (visible) {
      _hiddenPanels.remove(key);
    } else {
      _hiddenPanels.add(key);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('app_hidden_panels', _hiddenPanels.toList());
  }

  Future<void> setLichessApiToken(String token) async {
    _lichessApiToken = token.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lichess_api_token', _lichessApiToken);
  }

  Future<void> setManualCommentMode(bool enabled) async {
    _manualCommentMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_manual_comment_mode', _manualCommentMode);
  }

  Future<void> setMoveAnimationDurationMs(int ms) async {
    _moveAnimationDurationMs = ms.clamp(0, 500);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_move_animation_ms', _moveAnimationDurationMs);
  }

  Future<void> setEndgameIncludeOnline(bool include) async {
    _endgameIncludeOnline = include;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_endgame_include_online', _endgameIncludeOnline);
  }

  Future<void> setShowBoardCoordinates(bool show) async {
    _showBoardCoordinates = show;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_board_coordinates', show);
  }

  /// Ignores an id no catalogue holds, the same way [setEnginePlayLevel] does:
  /// a setter that quietly stores a value nothing can draw is the shape of bug
  /// this codebase keeps finding.
  Future<void> setBoardSkin(String id) async {
    if (!BoardSkin.all.any((s) => s.id == id)) return;
    _boardSkinId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_board_skin', id);
  }

  Future<void> setPieceSkin(String id) async {
    if (!PieceSkin.all.any((s) => s.id == id)) return;
    _pieceSkinId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_piece_skin', id);
  }

  Future<void> setDailyTarget(int positions) async {
    _dailyTarget = positions.clamp(0, 200);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_daily_target', _dailyTarget);
  }

  Future<void> setShowChosenMoveArrow(bool show) async {
    _showChosenMoveArrow = show;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_arrow_chosen_move', show);
  }

  Future<void> setShowStatisticsArrows(bool show) async {
    _showStatisticsArrows = show;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_arrow_statistics', show);
  }

  Future<void> setShowEngineArrows(bool show) async {
    _showEngineArrows = show;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_arrow_engine', show);
  }

  Future<void> setSpeechEnabled(bool enabled) async {
    _speechEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_speech_enabled', _speechEnabled);
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.2, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('app_speech_rate', _speechRate);
  }

  Future<void> setSpeechLanguage(String language) async {
    _speechLanguage = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_speech_language', _speechLanguage);
  }

  Future<void> setOpeningDbSource(String source) async {
    _openingDbSource = (source == 'chessdb') ? 'chessdb' : 'lichess';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_opening_db_source', _openingDbSource);
  }
}
