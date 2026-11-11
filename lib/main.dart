import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db/database_helper.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/api_client.dart';
import 'services/pull_sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Light/dark is driven by the phone's ambient light sensor.
final themeController = ThemeController();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  themeController.start();
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Tracking Kesehatan',
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: mode,
        // Screens without an AppBar (login, live tracking) wouldn't update the
        // status bar icons on their own, so they'd vanish on a dark background.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: child!,
        ),
        home: const StartupScreen(),
      ),
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

    // Non-blocking: pick up anything added from another device. The local
    // data we already have is shown immediately either way.
    if (localUser != null) {
      PullSyncService.instance.pullActivities(localUser.id!);
    }
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
