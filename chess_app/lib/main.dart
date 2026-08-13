import 'package:flutter/material.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.instance.init();
  // Routes build screens from the session, so it has to be loaded before the
  // first route is resolved.
  await SessionService.instance.init();

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
          title: 'Chess Master',
          routerConfig: appRouter,
          // Pairs with the router's own scope id so Android can rebuild the
          // navigation stack after the process is killed in the background.
          restorationScopeId: 'chess_app',
          themeMode: AppSettingsService.instance.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.deepPurple,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Colors.deepPurple,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            extensions: const [AppColorTokens.dark],
          ),
        );
      },
    );
  }
}
