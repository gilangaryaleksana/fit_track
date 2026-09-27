import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';
import 'add_activity_screen.dart';
import 'live_tracking_screen.dart';

/// Tab body — no own Scaffold app bar/bottom nav, rendered inside
/// MainNavigationScreen. Keeps its own nested Scaffold only so its FAB
/// attaches locally without affecting the other tabs.
class HomeScreen extends StatefulWidget {
  final int userId;
  final VoidCallback? onGoToTarget;
  const HomeScreen({super.key, required this.userId, this.onGoToTarget});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  double _totalCalories = 0;
  DailyTarget? _target;
  List<Activity> _todayActivities = [];
  Map<int, ActivityType> _typesById = {};
  _OngoingSession? _ongoingSession;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  /// Public so the parent tab bar can trigger a refresh (e.g. after
  /// switching back to this tab) without needing a full rebuild.
  Future<void> loadData() async {
    final today = DateTime.now();
    final total = await _db.getTotalCaloriesByDate(widget.userId, today);
    final target = await _db.getTargetByDate(widget.userId, today);
    final activities = await _db.getActivitiesByDate(widget.userId, today);
    final types = await _db.getActivityTypes();
    if (!mounted) return;
    setState(() {
      _totalCalories = total;
      _target = target;
      _todayActivities = activities;
      _typesById = {for (final t in types) t.id!: t};
    });
    await _checkOngoingSession();
  }

  Future<void> _checkOngoingSession() async {
    final sessionActive =
        await FlutterForegroundTask.getData<bool>(key: 'sessionActive') ??
            false;
    if (!sessionActive) {
      if (mounted) setState(() => _ongoingSession = null);
      return;
    }

    final isRunning = await FlutterForegroundTask.isRunningService;
    final typeId =
        await FlutterForegroundTask.getData<int>(key: 'activityTypeId');
    final seconds =
        await FlutterForegroundTask.getData<int>(key: 'accumulatedSeconds') ??
            0;
    final distance = await FlutterForegroundTask.getData<double>(
            key: 'accumulatedDistance') ??
        0;
    final movingSeconds = await FlutterForegroundTask.getData<int>(
            key: 'accumulatedMovingSeconds') ??
        0;

    final type = typeId != null ? _typesById[typeId] : null;
    final calories =
        type != null ? (movingSeconds / 60) * type.caloriesPerMinute : 0.0;

    if (!mounted) return;
    setState(() {
      _ongoingSession = _OngoingSession(
        type: type,
        elapsed: Duration(seconds: seconds),
        distanceMeters: distance,
        calories: calories,
        isRunning: isRunning,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetCalories = _target?.targetCalories ?? 0;
    final progress = targetCalories > 0
        ? (_totalCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_ongoingSession != null) ...[
              _OngoingSessionBanner(
                session: _ongoingSession!,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveTrackingScreen(userId: widget.userId),
                    ),
                  );
                  loadData();
                },
              ),
              const SizedBox(height: 14),
            ],
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
                          style:
                              TextStyle(fontSize: 14, color: Colors.white70)),
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
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Target: ${targetCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ] else
                    TextButton.icon(
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: widget.onGoToTarget,
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
                        '${a.durationMinutes} menit${a.note != null ? ' \u2022 ${a.note}' : ''}'),
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
          loadData();
        },
      ),
    );
  }
}

class _OngoingSession {
  final ActivityType? type;
  final Duration elapsed;
  final double distanceMeters;
  final double calories;
  final bool isRunning;

  _OngoingSession({
    required this.type,
    required this.elapsed,
    required this.distanceMeters,
    required this.calories,
    required this.isRunning,
  });
}

class _OngoingSessionBanner extends StatelessWidget {
  final _OngoingSession session;
  final VoidCallback onTap;
  const _OngoingSessionBanner({required this.session, required this.onTap});

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final style = session.type != null
        ? styleForActivity(session.type!.name)
        : const ActivityStyle(Icons.sports, Colors.teal);
    final km = session.distanceMeters / 1000;
    final dotColor =
        session.isRunning ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24);
    final label =
        session.isRunning ? 'SEDANG BERLANGSUNG' : 'DIJEDA \u2014 lanjutkan?';

    return Material(
      color: const Color(0xFF1C2744),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, color: Colors.white70, size: 12),
                        const SizedBox(width: 5),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.type?.name ?? 'Aktivitas',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDuration(session.elapsed)} \u2022 ${km.toStringAsFixed(1)} km \u2022 ${session.calories.toStringAsFixed(0)} kcal',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
