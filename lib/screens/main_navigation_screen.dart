import 'package:flutter/material.dart';
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

  static const _titles = [
    'Tracking Kesehatan',
    'Riwayat Aktivitas',
    'Target Harian'
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
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
