import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/screens/age_gate_screen.dart';
import 'package:chess_app/widgets/desktop_shortcuts.dart';
import 'package:chess_app/widgets/session_watch.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.instance.init();
  // Routes build screens from the session, so it has to be loaded before the
  // first route is resolved.
  await SessionService.instance.init();
  await GameSessionService.instance.init();
  // Not awaited. Asking the platform what voices it has takes a moment on a
  // cold start, and nothing on the first screen speaks; making the app wait for
  // an answer it does not need yet would only delay the board.
  final settings = AppSettingsService.instance;
  unawaited(SpeechService.instance.init(
    enabled: settings.speechEnabled,
    rate: settings.speechRate,
    preferred: settings.speechLanguage.isEmpty ? null : settings.speechLanguage,
  ));

  runApp(const ProviderScope(child: ChessApp()));
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'Mislisha',
          routerConfig: appRouter,
          // Wrapped around every screen the router builds, so Escape and the
          // settings chord work wherever the reader is - including on screens
          // written after this.
          //
          // The age gate sits outside all of it, for the same reason: a
          // question asked on one screen is a question the other forty screens
          // never ask, and this one has to reach accounts that were made long
          // before it existed.
          builder: (context, child) => SessionWatch(
            child: AgeGate(
              child: DesktopShortcuts(
                router: appRouter,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
          // Pairs with the router's own scope id so Android can rebuild the
          // navigation stack after the process is killed in the background.
          restorationScopeId: 'chess_app',
          themeMode: AppSettingsService.instance.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
        );
      },
    );
  }
}
