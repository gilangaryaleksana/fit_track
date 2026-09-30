import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show kLocalUserIdKey;
import '../services/api_client.dart';
import 'auth_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'target_screen.dart';

/// Owns the shared AppBar + bottom NavigationBar so the footer stays
/// visible across all three tabs. Switching tabs slides the PageView
/// instead of pushing a whole new route.
class MainNavigationScreen extends StatefulWidget {
  final int userId;
  const MainNavigationScreen({super.key, required this.userId});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final _pageController = PageController();
  final _homeKey = GlobalKey<HomeScreenState>();
  int _index = 0;

  static const _titles = ['Tracking Kesehatan', 'Riwayat Aktivitas', 'Target Harian'];

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
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Keluar')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) {
          setState(() => _index = i);
          if (i == 0) _homeKey.currentState?.loadData();
        },
        children: [
          HomeScreen(
            key: _homeKey,
            userId: widget.userId,
            onGoToTarget: () => _goToTab(2),
          ),
          HistoryScreen(userId: widget.userId),
          TargetScreen(userId: widget.userId),
        ],
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