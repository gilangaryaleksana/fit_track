import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';
import 'add_activity_screen.dart';
import 'history_screen.dart';
import 'live_tracking_screen.dart';
import 'target_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  double _totalCalories = 0;
  DailyTarget? _target;
  List<Activity> _todayActivities = [];
  Map<int, ActivityType> _typesById = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final today = DateTime.now();
    final total = await _db.getTotalCaloriesByDate(widget.userId, today);
    final target = await _db.getTargetByDate(widget.userId, today);
    final activities = await _db.getActivitiesByDate(widget.userId, today);
    final types = await _db.getActivityTypes();
    setState(() {
      _totalCalories = total;
      _target = target;
      _todayActivities = activities;
      _typesById = {for (final t in types) t.id!: t};
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetCalories = _target?.targetCalories ?? 0;
    final progress = targetCalories > 0
        ? (_totalCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Tracking Kesehatan')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2EC4B6), Color(0xFF1B9AAA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2EC4B6).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.local_fire_department,
                          color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text('Kalori Terbakar Hari Ini',
                          style: TextStyle(fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  if (targetCalories > 0) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Target: ${targetCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ] else
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TargetScreen(userId: widget.userId),
                          ),
                        );
                        _loadData();
                      },
                      label: const Text('Set target hari ini'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Aktivitas Hari Ini (${_todayActivities.length})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_todayActivities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Belum ada aktivitas hari ini')),
              )
            else
              ..._todayActivities.map((a) {
                final typeName = _typesById[a.activityTypeId]?.name ?? '';
                final style = styleForActivity(typeName);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: style.color.withValues(alpha: 0.15),
                      child: Icon(style.icon, color: style.color),
                    ),
                    title: Text(typeName.isEmpty ? 'Aktivitas' : typeName),
                    subtitle: Text(
                        '${a.durationMinutes} menit${a.note != null ? ' • ${a.note}' : ''}'),
                    trailing: Text(
                      '${a.caloriesBurned.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                          color: style.color, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tambah Aktivitas'),
        onPressed: () async {
          final choice = await showModalBottomSheet<String>(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.timer, color: Color(0xFF2EC4B6)),
                    title: const Text('Aktivitas Langsung'),
                    subtitle: const Text('Timer & kalori berjalan real-time'),
                    onTap: () => Navigator.pop(ctx, 'live'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: const Text('Input Manual'),
                    subtitle: const Text('Masukkan durasi setelah selesai'),
                    onTap: () => Navigator.pop(ctx, 'manual'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );

          if (!mounted || choice == null) return;

          final target = choice == 'live'
              ? LiveTrackingScreen(userId: widget.userId)
              : AddActivityScreen(userId: widget.userId);

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => target),
          );
          _loadData();
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) async {
          if (index == 0) {
            _loadData();
            return;
          }
          final target = index == 1
              ? HistoryScreen(userId: widget.userId)
              : TargetScreen(userId: widget.userId);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => target),
          );
          _loadData();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Target'),
        ],
      ),
    );
  }
}
