import 'package:flutter/material.dart';

import 'package:chess_app/core/services/game_review_judge.dart'
    show TablebaseLookup;
import 'package:chess_app/core/services/tutorial_language.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/analysis_studio/services/position_study/position_study.dart';
import 'package:chess_app/features/analysis_studio/widgets/comments_language_menu.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_slider.dart';

/// „Study this position" — `docs/PLAN-STUDIJA-POZICIJE.md`, the door that
/// took Auto Analysis's place on 28.9.2026.
///
/// One decision and one dial: whether the comments are written, and how deep
/// the engine looks. Everything else the old dialog asked — how many plies,
/// how many candidates, the cutoff — the study decides from the position.
///
/// The dialog draws only what it was given (rule 15): with no [ask] the tick
/// is drawn off and says why ([noWordsReason]); with no [onOpenAsTutorial]
/// the done view has no such button.
class PositionStudyDialog extends StatefulWidget {
  const PositionStudyDialog({
    super.key,
    required this.startNode,
    required this.analyzer,
    required this.onCompleted,
    this.tablebase,
    this.ask,
    this.noWordsReason,
    this.onOpenAsTutorial,
    this.onHold,
    this.onRelease,
  });

  /// The node the study is made of, and written under.
  final AnalysisNode startNode;
  final PositionAnalyzer analyzer;
  final TablebaseLookup? tablebase;

  /// How the words are asked for; null when they cannot be.
  final StudyWordsAsker? ask;

  /// Why [ask] is null, as a sentence for the reader.
  final String? noWordsReason;

  /// Called once the study is in the tree.
  final ValueChanged<StudyResult> onCompleted;

  /// Opens the study as a tutorial; called after the dialog has closed.
  final VoidCallback? onOpenAsTutorial;

  /// Called around the engine's work, so the screen can keep its own
  /// searches out of the study's way.
  final VoidCallback? onHold;
  final VoidCallback? onRelease;

  static const String title = 'Study this position';
  static const String withWords = 'Write comments with AI';
  static const String start = 'Start';
  static const String openAsTutorial = 'Open as a tutorial';
  static const String commentsIn = CommentsLanguageMenu.label;

  @override
  State<PositionStudyDialog> createState() => _PositionStudyDialogState();
}

enum _Stage { asking, searching, writing, done, refused }

class _PositionStudyDialogState extends State<PositionStudyDialog> {
  late int _depth = AppSettingsService.instance.analysisDepth;
  late bool _words = widget.ask != null;

  /// The language the comments are written in, remembered from the last
  /// study (`docs/PLAN-JEZIK-STUDIJE.md`, L1); a code this build does not
  /// know is English.
  TutorialLanguage _language =
      TutorialLanguage.of(AppSettingsService.instance.studyLanguage) ??
          TutorialLanguage.english;
  _Stage _stage = _Stage.asking;
  int _searched = 0;
  String _what = '';
  StudyResult? _result;
  String? _refusedBecause;
  bool _cancelled = false;
  bool _holding = false;

  @override
  void dispose() {
    _cancelled = true;
    _release();
    super.dispose();
  }

  void _release() {
    if (!_holding) return;
    _holding = false;
    widget.onRelease?.call();
  }

  Future<void> _start() async {
    if (_stage != _Stage.asking) return;
    setState(() {
      _stage = _Stage.searching;
      _searched = 0;
      _what = 'Reading the position';
    });
    _holding = true;
    widget.onHold?.call();
    try {
      final result = await runPositionStudy(
        start: widget.startNode,
        analyzer: widget.analyzer,
        depth: _depth,
        tablebase: widget.tablebase,
        ask: _words ? widget.ask : null,
        language: _language == TutorialLanguage.english ? null : _language.code,
        isCancelled: () => _cancelled,
        onProgress: (searched, budget, what) {
          if (!mounted) return;
          setState(() {
            _searched = searched + 1;
            _what = what;
          });
        },
        onWriting: () {
          if (!mounted) return;
          setState(() => _stage = _Stage.writing);
        },
      );
      // Do the thing, then say it: the tree has the study before anything
      // is drawn about it.
      widget.onCompleted(result);
      if (!mounted) return;
      setState(() {
        _result = result;
        _stage = _Stage.done;
      });
    } on StudyCancelled {
      // Closed by the reader; nothing was written and nothing is said.
    } on StudyRefused catch (e) {
      if (!mounted) return;
      setState(() {
        _refusedBecause = e.reason;
        _stage = _Stage.refused;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _refusedBecause = 'The study could not be made: $e';
        _stage = _Stage.refused;
      });
    } finally {
      _release();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Each stage ends with a gap and then its buttons.
    final stage = switch (_stage) {
      _Stage.asking => _asking(context),
      _Stage.searching || _Stage.writing => _working(context),
      _Stage.done => _done(context, _result!),
      _Stage.refused => _refused(context),
    };
    final body = stage.sublist(0, stage.length - 2);
    final buttons = stage.last;
    // What is read scrolls; what is pressed does not. In the Analysis screen
    // on a 360 x 640 phone „Start" stood 49 px below the screen's end, inside
    // a dialog nothing said could be scrolled.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_stories, color: colors.warning, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      PositionStudyDialog.title,
                      style: AppText.title.copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: body,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Align(alignment: Alignment.centerRight, child: buttons),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _asking(BuildContext context) {
    final colors = context.colors;
    final canWrite = widget.ask != null;
    return [
      Text(
        'The engine works out the main line, the moves that are as good, '
        'the tempting moves that fail and the traps on the way. The lines '
        'are added to the tree under the move you are on.',
        style: AppText.body.copyWith(color: colors.textMuted),
      ),
      const SizedBox(height: AppSpacing.md),
      CheckboxListTile(
        key: const ValueKey('study-with-words'),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _words && canWrite,
        onChanged: canWrite ? (v) => setState(() => _words = v ?? false) : null,
        title: Text(
          PositionStudyDialog.withWords,
          style: AppText.body.copyWith(color: colors.textPrimary),
        ),
        subtitle: Text(
          canWrite
              ? 'The engine\'s analysis decides what is said; the model '
                  'only puts it into words.'
              : (widget.noWordsReason ?? 'Comments cannot be written now.'),
          style: AppText.caption.copyWith(color: colors.textMuted),
        ),
      ),
      CommentsLanguageMenu(
        menuKey: const ValueKey('study-language'),
        value: _language,
        onChanged: _words && canWrite
            ? (chosen) {
                setState(() => _language = chosen);
                AppSettingsService.instance.setStudyLanguage(chosen.code);
              }
            : null,
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Engine depth: $_depth',
        style: AppText.body.copyWith(color: colors.textPrimary),
      ),
      AppSlider(
        value: _depth.toDouble(),
        min: 6,
        max: AppSettingsService.kMaxEngineDepth.toDouble(),
        divisions: AppSettingsService.kMaxEngineDepth - 6,
        activeColor: colors.warning,
        onChanged: (v) => setState(() => _depth = v.round()),
      ),
      Text(
        'Up to $kStudySearchBudget positions are searched at depth $_depth; '
        'most studies need about half of that.',
        style: AppText.caption.copyWith(color: colors.textMuted),
      ),
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const ValueKey('study-start'),
            icon: const Icon(Icons.play_arrow),
            label: const Text(PositionStudyDialog.start),
            onPressed: _start,
          ),
        ],
      ),
    ];
  }

  List<Widget> _working(BuildContext context) {
    final colors = context.colors;
    final writing = _stage == _Stage.writing;
    return [
      LinearProgressIndicator(
        value: writing
            ? null
            : (_searched / kStudySearchBudget).clamp(0.0, 1.0).toDouble(),
        backgroundColor: colors.surfaceRaised,
        color: colors.warning,
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        writing ? 'Writing the comments…' : _what,
        style: AppText.bodyBold.copyWith(color: colors.textPrimary),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        writing
            ? 'The engine has finished. This can take a minute or two.'
            : 'Position $_searched of at most $kStudySearchBudget',
        style: AppText.caption.copyWith(color: colors.textMuted),
      ),
      const SizedBox(height: AppSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          icon: Icon(Icons.cancel, color: colors.danger),
          label: Text('Cancel', style: TextStyle(color: colors.danger)),
          onPressed: () {
            _cancelled = true;
            Navigator.of(context).pop();
          },
        ),
      ),
    ];
  }

  List<Widget> _done(BuildContext context, StudyResult result) {
    final colors = context.colors;
    final written = result.written;
    final notes = <String>[
      if (result.refusal != null)
        'No comments were written: ${result.refusal!.message}',
      if (result.answered > result.kept)
        '${_count(result.answered - result.kept, 'comment')} left out: what '
            'the model wrote was not borne out by the engine\'s analysis.',
      if (result.untranslated > 0 && result.refusal == null)
        '${_count(result.untranslated, 'comment')} left out: the translation '
            'into ${TutorialLanguage.of(result.language)?.label ?? result.language} '
            'did not pass the check.',
      if (result.lostSearches.isNotEmpty)
        '${_count(result.lostSearches.length, 'search', 'searches')} ran out '
            'of time, and what depended on them was left out.',
    ];
    return [
      Row(
        children: [
          Icon(Icons.check_circle, color: colors.accent, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'The study is in the tree.',
              style: AppText.subtitle.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        '${_count(written.moves, 'move')} added'
        '${written.sentences > 0 ? ', ${_count(written.sentences, 'comment')} written' : ''}. '
        'The main line starts with '
        '${result.study.mainLine.first.move.label}.',
        style: AppText.body.copyWith(color: colors.textSecondary),
      ),
      for (final note in notes) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(note, style: AppText.caption.copyWith(color: colors.textMuted)),
      ],
      const SizedBox(height: AppSpacing.lg),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (widget.onOpenAsTutorial != null)
            FilledButton.icon(
              key: const ValueKey('study-open-as-tutorial'),
              icon: const Icon(Icons.school),
              label: const Text(PositionStudyDialog.openAsTutorial),
              onPressed: () {
                final open = widget.onOpenAsTutorial!;
                Navigator.of(context).pop();
                open();
              },
            ),
        ],
      ),
    ];
  }

  List<Widget> _refused(BuildContext context) {
    final colors = context.colors;
    return [
      Text(
        _refusedBecause ?? 'The study could not be made.',
        style: AppText.body.copyWith(color: colors.danger),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'Nothing was added to the tree.',
        style: AppText.caption.copyWith(color: colors.textMuted),
      ),
      const SizedBox(height: AppSpacing.lg),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ),
    ];
  }
}

String _count(int n, String one, [String? many]) =>
    n == 1 ? '1 $one' : '$n ${many ?? '${one}s'}';
