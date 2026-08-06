import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/home_screen.dart';
import 'package:chess_app/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.instance.init();
  final prefs = await SharedPreferences.getInstance();
  
  final rememberMe = prefs.getBool('remember_me') ?? false;
  final token = prefs.getString('user_token');
  
  UserSession? savedSession;
  if (rememberMe && token != null) {
    savedSession = UserSession(
      token: token,
      id: prefs.getInt('user_id') ?? 0,
      email: prefs.getString('user_email') ?? '',
      name: prefs.getString('user_name') ?? '',
      role: prefs.getString('user_role') ?? 'korisnik',
    );
  }

  runApp(ChessApp(savedSession: savedSession));
}

class ChessApp extends StatelessWidget {
  final UserSession? savedSession;

  const ChessApp({super.key, this.savedSession});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Chess Master',
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
          ),
          home: savedSession != null
              ? HomeScreen(session: savedSession!)
              : const LoginRegisterScreen(),
        );
      },
    );
  }
}
