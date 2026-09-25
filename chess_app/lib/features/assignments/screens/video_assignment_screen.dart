import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

import '../models/assignment.dart';
import '../services/assignment_api_service.dart';

/// Opens [uri] outside the app — the platform's browser, which downloads it.
typedef VideoLauncher = Future<bool> Function(Uri uri);

Future<bool> _openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// A tutorial the trainer sent — as its film (`docs/PLAN-TUTORIJAL-VIDEO.md`).
///
/// The student downloads it; the app does not play it. **The server decides
/// when it counts**: once the file's last byte has gone out, the assignment is
/// done (D3). The download runs in the browser, after this screen has handed
/// the link over, so the screen reads the assignment again whenever the app
/// comes back to the front rather than claiming a download it has not seen.
class VideoAssignmentScreen extends StatefulWidget {
  const VideoAssignmentScreen({
    super.key,
    required this.session,
    required this.detail,
    this.api,
    this.launch = _openInBrowser,
  });

  final UserSession session;
  final AssignmentDetail detail;
  final AssignmentApiService? api;
  final VideoLauncher launch;

  @override
  State<VideoAssignmentScreen> createState() => _VideoAssignmentScreenState();
}

class _VideoAssignmentScreenState extends State<VideoAssignmentScreen>
    with WidgetsBindingObserver {
  late final AssignmentApiService _api;
  late AssignmentDetail _detail;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AssignmentApiService(authToken: widget.session.token);
    _detail = widget.detail;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reread();
  }

  /// The assignment as the server has it now — whether the download it
  /// started has arrived.
  Future<void> _reread() async {
    final read = await _api.fetchDetail(_detail.assignment.id);
    final detail = read.detail;
    if (!mounted || detail == null) return;
    setState(() => _detail = detail);
  }

  Future<void> _download() async {
    if (_fetching) return;
    setState(() => _fetching = true);
    final link = await _api.fetchVideoLink(_detail.assignment.id);
    if (!mounted) return;
    setState(() => _fetching = false);
    if (!link.ok) {
      AppFeedback.error(context, link.error ?? 'Could not fetch the video.');
      return;
    }
    // Do the thing, then say it.
    final opened = await widget.launch(
      Uri.parse(resolveMediaUrl(link.downloadUrl!)),
    );
    if (!mounted) return;
    if (opened) {
      AppFeedback.info(context, 'The download has started in your browser.');
    } else {
      AppFeedback.error(
        context,
        'Could not open the browser for the download.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final assignment = _detail.assignment;
    final video = _detail.video;
    final ready = video?.ready ?? false;
    final downloadedAt = _detail.downloadedAt;
    final facts = [
      if (video?.seconds != null) _length(video!.seconds!),
      if (video?.resolution != null) video!.resolution!,
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(title: const Text('Tutorial video')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Icon(Icons.movie_outlined, size: 32, color: colors.accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      assignment.title,
                      key: const Key('video-assignment-title'),
                      style: AppText.title,
                    ),
                  ),
                ],
              ),
              if (assignment.trainerName != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'From ${assignment.trainerName}',
                  style: AppText.caption.copyWith(color: colors.textSecondary),
                ),
              ],
              if (assignment.instructions != null &&
                  assignment.instructions!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(assignment.instructions!, style: AppText.bodyLarge),
              ],
              if (facts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  facts,
                  key: const Key('video-assignment-facts'),
                  style: AppText.body.copyWith(color: colors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                downloadedAt == null
                    ? 'Not downloaded yet.'
                    : 'Downloaded on ${_date(downloadedAt)}',
                key: const Key('video-assignment-status'),
                style: AppText.bodyBold,
              ),
              const SizedBox(height: AppSpacing.md),
              if (ready)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const Key('video-assignment-download'),
                    onPressed: _fetching ? null : _download,
                    icon: const Icon(Icons.download),
                    label: Text(
                      downloadedAt == null
                          ? 'Download video'
                          : 'Download again',
                    ),
                  ),
                )
              else
                Text(
                  'This video is no longer available. Ask your trainer to send it again.',
                  key: const Key('video-assignment-gone'),
                  style: AppText.body.copyWith(color: colors.textSecondary),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'The video opens in your browser and is saved to your device. '
                'It counts as downloaded once the whole file has arrived.',
                style: AppText.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _length(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m == 0 ? '$s s' : '$m min ${s.toString().padLeft(2, '0')} s';
  }

  /// The app's date, which ends in its own period: „25.9.2026."
  static String _date(DateTime d) => '${d.day}.${d.month}.${d.year}.';
}
