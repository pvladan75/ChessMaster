import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/models/pending_session_intent.dart';
import 'package:chess_app/screens/home_screen.dart';
import 'package:chess_app/screens/age_gate_screen.dart';
import 'package:chess_app/screens/login_screen.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/screens/shortcuts_screen.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/blunder_walk_screen.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_picker_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/screens/custom_assignment_overview_screen.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/assignments/screens/my_assignments_screen.dart';
import 'package:chess_app/features/assignments/screens/student_progress_screen.dart';
import 'package:chess_app/features/assignments/widgets/assignment_detail_gate.dart';
import 'package:chess_app/features/reviews/screens/review_session_screen.dart';
import 'package:chess_app/features/archive/screens/archive_import_screen.dart';
import 'package:chess_app/features/archive/screens/mistake_drill_screen.dart';
import 'package:chess_app/features/archive/screens/endgame_audit_screen.dart';
import 'package:chess_app/features/archive/screens/opening_leak_report_screen.dart';
import 'package:chess_app/features/archive/screens/player_profile_screen.dart';
import 'package:chess_app/features/archive/screens/repertoire_diff_screen.dart';
import 'package:chess_app/features/training/screens/training_hub_screen.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/features/position_scanner/screens/scan_review_screen.dart';
import 'package:chess_app/features/position_scanner/screens/saved_positions_screen.dart';
import 'package:chess_app/screens/design_gallery_screen.dart';

/// The app's navigation graph.
///
/// Screens are built from [SessionService] rather than from arguments passed
/// by whoever navigated, so a cold-started deep link produces the same screen
/// as an in-app tap.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  restorationScopeId: 'chess_app_router',
  routes: appRouteTable,
  errorBuilder: appRouteErrorBuilder,
  refreshListenable: SessionService.instance,
  redirect: expiredSessionRedirect,
);

/// Where somebody goes when their session ended without them asking.
///
/// The one place that turns "the server no longer accepts this device" into
/// leaving the screen they are on. Before this, a token that had run out was
/// noticed in pieces — a banner on the dashboard, a socket that would not
/// connect, a request that came back empty — and the app went on considering
/// the user signed in, so the way back in was to find "Odjava" and sign out of
/// something that was already gone. Reported live on 22.8.2026.
///
/// Only [SessionService.sessionExpired] sends anybody anywhere. A guest is not
/// redirected: signing in is optional in this app, and a rule that reads "not
/// signed in → login" would lock the door on the people it was never about.
String? expiredSessionRedirect(BuildContext context, GoRouterState state) {
  if (!SessionService.instance.sessionExpired) return null;
  // The destination itself is exempt. go_router stops on its own when a
  // redirect names the location it is already going to, so this is belt and
  // braces rather than the thing that prevents a loop — it is kept because the
  // sentence it makes is the true one: the login screen is where an expired
  // session is *supposed* to be, and it clears the flag once it has said why.
  // Deliberately not covered by a test: removing it changes nothing that can be
  // observed, and a test that passes with the guard gone is worse than none.
  if (state.matchedLocation == AppRoutes.login) return null;
  return AppRoutes.login;
}

/// What a link to nowhere lands on. Exposed beside [appRouteTable] and for the
/// same reason: a test that builds its own router should get the app's answer
/// to a bad path, not go_router's default one.
Widget appRouteErrorBuilder(BuildContext context, GoRouterState state) =>
    _InvalidRouteScreen(detail: state.uri.toString());

/// The destinations themselves, apart from the router that starts at the home
/// screen.
///
/// Separated so a test can build a router that opens at any one of them. The
/// alternative is starting every navigation test on the home screen and walking
/// to the place under test, which makes each test a test of everything between.
final List<RouteBase> appRouteTable = [
  GoRoute(
    path: AppRoutes.login,
    builder: (context, state) => LoginRegisterScreen(
        pendingIntent: state.extra as PendingSessionIntent?),
  ),
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => HomeScreen(
      session: SessionService.instance.current,
      pendingIntent: state.extra as PendingSessionIntent?,
    ),
  ),
  GoRoute(
    path: AppRoutes.room,
    builder: (context, state) {
      final roomCode = state.pathParameters['roomCode'] ?? '';
      final role = state.uri.queryParameters['role'];
      return ChessGamePage(
        roomCode: roomCode,
        // The room's role wins over the account's own role for this screen.
        userSession: SessionService.instance.current.copyWith(role: role),
        initialRole: role,
      );
    },
  ),
  GoRoute(
    path: AppRoutes.analysis,
    builder: (context, state) => AnalysisStudioScreen(
      userSession: SessionService.instance.current,
      initialFen: state.uri.queryParameters['fen'],
    ),
  ),
  GoRoute(
    path: AppRoutes.replay,
    builder: (context, state) {
      final id = int.tryParse(state.pathParameters['recordingId'] ?? '');
      if (id == null) {
        return const _InvalidRouteScreen(detail: 'Neispravan ID snimka.');
      }
      return ReplayPlayerScreen(
        recordingId: id,
        userSession: SessionService.instance.current,
      );
    },
  ),
  // Homework and repetition. Seven screens hung off a MaterialPageRoute until
  // now, which meant none of them could be linked to, restored, or reached by a
  // test without walking the whole way there first.
  GoRoute(
    path: AppRoutes.assignments,
    builder: (context, state) =>
        MyAssignmentsScreen(session: SessionService.instance.current),
  ),
  GoRoute(
    path: AppRoutes.assignmentReview,
    builder: (context, state) => AssignmentReviewScreen(
      session: SessionService.instance.current,
      assignmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      // Decoration until the fetch answers: the screen shows the title it gets
      // back and only falls back on this one.
      title: state.uri.queryParameters['title'] ?? '',
    ),
  ),
  // These two are built from the whole assignment rather than from its id, so
  // the id is turned into one first. Tapping through from the list hands the
  // object over and nothing is fetched.
  GoRoute(
    path: AppRoutes.assignmentOverview,
    builder: (context, state) => AssignmentDetailGate(
      session: SessionService.instance.current,
      assignmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      detail: state.extra is AssignmentDetail
          ? state.extra as AssignmentDetail
          : null,
      builder: (detail) => CustomAssignmentOverviewScreen(
        session: SessionService.instance.current,
        detail: detail,
      ),
    ),
  ),
  GoRoute(
    path: AppRoutes.assignmentLesson,
    builder: (context, state) => AssignmentDetailGate(
      session: SessionService.instance.current,
      assignmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      detail: state.extra is AssignmentDetail
          ? state.extra as AssignmentDetail
          : null,
      builder: (detail) => LessonViewerScreen(
        session: SessionService.instance.current,
        detail: detail,
      ),
    ),
  ),
  // The same gate as the two above, and for the same reason: what is left of an
  // assignment is worked out from the assignment, so the id is enough. Handing
  // over the list of puzzle ids in a query would be a path that stops being
  // true the moment one of them is answered.
  GoRoute(
    path: AppRoutes.assignmentTactics,
    builder: (context, state) => AssignmentDetailGate(
      session: SessionService.instance.current,
      assignmentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      detail: state.extra is AssignmentDetail
          ? state.extra as AssignmentDetail
          : null,
      builder: (detail) {
        final pending = detail.pending;
        if (pending.isEmpty) {
          return const _NothingLeftScreen();
        }
        return TacticsTrainerScreen(
          session: SessionService.instance.current,
          assignmentId: detail.assignment.id,
          assignmentTitle: detail.assignment.title,
          // Only what is left, so coming back to a half-done assignment picks
          // up where the student stopped instead of starting over.
          puzzleIds: pending.map((item) => item.puzzleId!).toList(),
        );
      },
    ),
  ),
  GoRoute(
    path: AppRoutes.review,
    builder: (context, state) =>
        ReviewSessionScreen(session: SessionService.instance.current),
  ),
  GoRoute(
    path: AppRoutes.studentProgress,
    builder: (context, state) => StudentProgressScreen(
      session: SessionService.instance.current,
      studentId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
      studentName: state.uri.queryParameters['name'] ?? '',
    ),
  ),
  GoRoute(
    path: AppRoutes.training,
    builder: (context, state) => TrainingHubScreen(
      session: SessionService.instance.current,
    ),
  ),
  // One screen for three exercises that share a board and a verdict. Three
  // near-identical screens would be three places to fix the same bug, and the
  // differences between them are a preset and a title.
  GoRoute(
    path: AppRoutes.trainingDrill,
    builder: (context, state) {
      final category = state.uri.queryParameters['category'] ?? 'mate_puzzle';
      return AiStudioScreen(
        userSession: SessionService.instance.current,
        initialCategory: category,
        mateDepth: state.uri.queryParameters['depth'],
        basicMateLevel: state.uri.queryParameters['level'],
      );
    },
  ),
  GoRoute(
    path: AppRoutes.tactics,
    builder: (context, state) => TacticsTrainerScreen(
      session: SessionService.instance.current,
    ),
  ),
  GoRoute(
    path: AppRoutes.endgames,
    builder: (context, state) {
      final query = state.uri.queryParameters;
      return EndgameTrainerScreen(
        session: SessionService.instance.current,
        mode: query['mode'] == 'draw' ? EndgameMode.draw : EndgameMode.win,
        // Absent means "everything", which is what the picker sends when
        // nothing was unticked.
        material: query['material'],
        band: query['band'],
        oppositeOnly: query['oppositeBishops'] == 'true',
      );
    },
  ),
  GoRoute(
    path: AppRoutes.repertoire,
    builder: (context, state) => const RepertoireListScreen(),
  ),
  GoRoute(
    path: AppRoutes.archiveImport,
    builder: (context, state) => const ArchiveImportScreen(),
  ),
  GoRoute(
    path: AppRoutes.archiveEndgames,
    builder: (context, state) {
      // Same refusal as the leak report: an audit for nobody is an empty list
      // wearing the same shape as a player who threw nothing away.
      final subject = state.uri.queryParameters['subject']?.trim() ?? '';
      if (subject.isEmpty) return const ArchiveImportScreen();
      return EndgameAuditScreen(
        session: SessionService.instance.current,
        username: subject,
      );
    },
  ),
  GoRoute(
    path: AppRoutes.archiveLeaks,
    builder: (context, state) {
      // Reached only from the import screen, which knows the handle it just
      // imported under. A report for nobody is an empty list wearing the same
      // shape as a clean archive, so this refuses rather than guesses.
      final subject = state.uri.queryParameters['subject']?.trim() ?? '';
      if (subject.isEmpty) return const ArchiveImportScreen();
      return OpeningLeakReportScreen(subject: subject);
    },
  ),
  GoRoute(
    path: AppRoutes.archiveMistakes,
    builder: (context, state) => const MistakeDrillScreen(),
  ),
  GoRoute(
    path: AppRoutes.archiveProfile,
    builder: (context, state) {
      final subject = state.uri.queryParameters['subject']?.trim() ?? '';
      if (subject.isEmpty) return const ArchiveImportScreen();
      return PlayerProfileScreen(username: subject);
    },
  ),
  GoRoute(
    path: AppRoutes.archiveRepertoire,
    builder: (context, state) {
      final subject = state.uri.queryParameters['subject'];
      final color = state.uri.queryParameters['color'];
      return RepertoireDiffScreen(subject: subject ?? '', color: color);
    },
  ),
  GoRoute(
    path: AppRoutes.endgamePicker,
    builder: (context, state) {
      final mode = state.uri.queryParameters['mode'] == 'draw'
          ? EndgameMode.draw
          : EndgameMode.win;
      return EndgamePickerScreen(
        session: SessionService.instance.current,
        mode: mode,
        onStart: (choice) {
          final params = <String, String>{'mode': mode.name};
          // Already resolved by the picker, which is the only place that
          // holds the catalog and so the only one that can tell a full
          // selection from a partial one.
          if (choice.materialsParam != null) {
            params['material'] = choice.materialsParam!;
          }
          if (choice.bandId != null) params['band'] = choice.bandId!;
          if (choice.oppositeOnly) params['oppositeBishops'] = 'true';
          final query = Uri(queryParameters: params).query;
          context.pushReplacement('${AppRoutes.endgames}?$query');
        },
      );
    },
  ),
  GoRoute(
    path: AppRoutes.blunderGames,
    builder: (context, state) {
      int? number(String key) {
        final raw = state.uri.queryParameters[key];
        return raw == null ? null : int.tryParse(raw);
      }

      return BlunderWalkScreen(
        session: SessionService.instance.current,
        minBlunders: number('minBlunders'),
        maxBlunders: number('maxBlunders'),
        minElo: number('minElo'),
        maxElo: number('maxElo'),
        material: state.uri.queryParameters['material'],
      );
    },
  ),
  GoRoute(
    path: AppRoutes.scan,
    builder: (context, state) => ScanReviewScreen(
      session: SessionService.instance.current,
    ),
  ),
  GoRoute(
    path: AppRoutes.savedPositions,
    builder: (context, state) => SavedPositionsScreen(
      session: SessionService.instance.current,
    ),
  ),
  GoRoute(
    path: AppRoutes.preferences,
    builder: (context, state) =>
        SettingsScreen(session: SessionService.instance.current),
  ),
  GoRoute(
    path: AppRoutes.shortcuts,
    builder: (context, state) => const ShortcutsScreen(),
  ),
  GoRoute(
    path: AppRoutes.birthYear,
    builder: (context, state) => const BirthYearScreen(canCancel: true),
  ),
  GoRoute(
    path: AppRoutes.designGallery,
    builder: (context, state) => const DesignGalleryScreen(),
  ),
];

/// An assignment opened when there is nothing left in it.
///
/// Reachable now that this is a path: the list checks before it navigates, but
/// a link or a restored session does not, and answering the last puzzle on
/// another device makes it true while the screen is being opened.
class _NothingLeftScreen extends StatelessWidget {
  const _NothingLeftScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zadatak')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48, color: context.colors.success),
            const SizedBox(height: AppSpacing.md),
            const Text('Ovaj zadatak je već završen.'),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Nazad'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of a crash when a link points somewhere that does not exist.
class _InvalidRouteScreen extends StatelessWidget {
  final String detail;

  const _InvalidRouteScreen({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stranica nije pronađena')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off,
                  size: 48, color: context.colors.textSecondary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ova putanja ne postoji.',
                style: AppText.title,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                detail,
                textAlign: TextAlign.center,
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home),
                label: const Text('Nazad na početnu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
