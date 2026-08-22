import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/models/pending_session_intent.dart';
import 'package:chess_app/screens/home_screen.dart';
import 'package:chess_app/screens/login_screen.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/position_scanner/screens/scan_review_screen.dart';
import 'package:chess_app/features/position_scanner/screens/saved_positions_screen.dart';

/// The app's navigation graph.
///
/// Screens are built from [SessionService] rather than from arguments passed
/// by whoever navigated, so a cold-started deep link produces the same screen
/// as an in-app tap.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  restorationScopeId: 'chess_app_router',
  routes: [
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
    GoRoute(
      path: AppRoutes.tactics,
      builder: (context, state) => TacticsTrainerScreen(
        session: SessionService.instance.current,
      ),
    ),
    GoRoute(
      path: AppRoutes.endgames,
      builder: (context, state) => EndgameTrainerScreen(
        session: SessionService.instance.current,
        mode: state.uri.queryParameters['mode'] == 'draw'
            ? EndgameMode.draw
            : EndgameMode.win,
      ),
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
  ],
  errorBuilder: (context, state) =>
      _InvalidRouteScreen(detail: state.uri.toString()),
);

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
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Ova putanja ne postoji.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
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
