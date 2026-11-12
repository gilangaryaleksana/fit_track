import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show kLocalUserIdKey;
import '../services/api_client.dart';
import 'auth_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'target_screen.dart';
import '../theme/app_colors.dart';

/// Owns the bottom NavigationBar across all three tabs. Switching tabs slides
/// the PageView instead of pushing a whole new route.
class MainNavigationScreen extends StatefulWidget {
  final int userId;
  const MainNavigationScreen({super.key, required this.userId});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final _pageController = PageController();
  final _homeKey = GlobalKey<HomeScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  int _index = 0;

  void _goToTab(int i) {
    setState(() => _index = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (i == 0) _homeKey.currentState?.loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Kamu perlu login lagi untuk masuk ke akun ini.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (confirmed != true) return;

    await ApiClient.instance.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kLocalUserIdKey);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _openSettingsMenu() async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengaturan',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: context.colors.inkSoft),
                title: const Text('Keluar dari akun'),
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldLogout == true && mounted) await _logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (i) {
            setState(() => _index = i);
            if (i == 0) _homeKey.currentState?.loadData();
            if (i == 1) _historyKey.currentState?.loadData();
          },
          children: [
            HomeScreen(
              key: _homeKey,
              userId: widget.userId,
              onProfileTap: _openSettingsMenu,
              onGoToTarget: () => _goToTab(2),
              onGoToHistory: () => _goToTab(1),
            ),
            HistoryScreen(key: _historyKey, userId: widget.userId),
            TargetScreen(userId: widget.userId),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Target'),
        ],
      ),
    );
  }
}
