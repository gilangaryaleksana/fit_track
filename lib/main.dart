import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/database_helper.dart';
import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracking Kesehatan',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2EC4B6),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const StartupScreen(),
    );
  }
}

/// Key used to remember which LOCAL sqlite user row (not the server's user
/// id) belongs to the account currently logged in via [ApiClient].
const kLocalUserIdKey = 'local_user_id';

/// Decides where to land: straight into the app if there's a saved session
/// (API token + matching local row), otherwise the Login/Register screen.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  int? _localUserId;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await ApiClient.instance.isLoggedIn;
    if (!loggedIn) {
      setState(() => _loading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getInt(kLocalUserIdKey);
    final localUser = localId != null ? await _db.getUser(localId) : null;

    setState(() {
      _localUserId = localUser?.id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_localUserId == null) {
      return const AuthScreen();
    }
    return MainNavigationScreen(userId: _localUserId!);
  }
}