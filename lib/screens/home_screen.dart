import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';
import 'activity_detail_screen.dart';
import 'live_tracking_screen.dart';
import 'start_activity_flow.dart';
import '../theme/app_colors.dart';

const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const _teal = Color(0xFF2EC4B6);
const _tealDark = Color(0xFF1B9AAA);
const _green1 = Color(0xFF2FBF8A);
const _green2 = Color(0xFF1E9E6E);

/// Items listed under "Aktivitas Hari Ini"; the rest are one tap away on Riwayat.
const _maxTodayItems = 5;

String _greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 11) return 'Selamat pagi';
  if (h >= 11 && h < 15) return 'Selamat siang';
  if (h >= 15 && h < 18) return 'Selamat sore';
  return 'Selamat malam';
}

double _ratio(num value, num goal) => goal <= 0 ? 1.0 : (value / goal).toDouble();
double _unit(double v) => math.min(1.0, math.max(0.0, v));

/// Tab body — no own Scaffold app bar/bottom nav, rendered inside
/// MainNavigationScreen. Keeps its own nested Scaffold only so its FAB
/// attaches locally without affecting the other tabs.
class HomeScreen extends StatefulWidget {
  final int userId;
  final VoidCallback? onGoToTarget;
  final VoidCallback? onGoToHistory;
  const HomeScreen({
    super.key,
    required this.userId,
    this.onGoToTarget,
    this.onGoToHistory,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  String _userName = '';
  double _totalCalories = 0;
  int _totalMinutes = 0;
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
    final user = await _db.getUser(widget.userId);
    final total = await _db.getTotalCaloriesByDate(widget.userId, today);
    final target = await _db.getTargetByDate(widget.userId, today);
    final activities = await _db.getActivitiesByDate(widget.userId, today);
    final types = await _db.getActivityTypes();
    if (!mounted) return;
    setState(() {
      _userName = user?.name ?? '';
      _totalCalories = total;
      _totalMinutes = activities.fold<int>(0, (sum, a) => sum + a.durationMinutes);
      _target = target;
      _todayActivities = activities;
      _typesById = {for (final t in types) t.id!: t};
    });
    await _checkOngoingSession();
  }

  Future<void> _checkOngoingSession() async {
    final sessionActive =
        await FlutterForegroundTask.getData<bool>(key: 'sessionActive') ?? false;
    if (!sessionActive) {
      if (mounted) setState(() => _ongoingSession = null);
      return;
    }

    final isRunning = await FlutterForegroundTask.isRunningService;
    final typeId = await FlutterForegroundTask.getData<int>(key: 'activityTypeId');
    final seconds =
        await FlutterForegroundTask.getData<int>(key: 'accumulatedSeconds') ?? 0;
    final distance =
        await FlutterForegroundTask.getData<double>(key: 'accumulatedDistance') ?? 0;
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

  Future<void> _openDetail(Activity activity) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityDetailScreen(
          activity: activity,
          type: _typesById[activity.activityTypeId],
        ),
      ),
    );
    loadData();
  }

  Future<void> _startActivity() async {
    await startActivityFlow(context, widget.userId);
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final shown = _todayActivities.take(_maxTodayItems).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Bottom space so the last item isn't hidden behind the FAB.
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            _GreetingRow(name: _userName, now: now),
            const SizedBox(height: 14),
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
              const SizedBox(height: 12),
            ],
            _HeroCard(
              kcal: _totalCalories,
              minutes: _totalMinutes,
              target: _target,
              onSetTarget: widget.onGoToTarget,
            ),
            const SizedBox(height: 14),
            _SectionHeader(
              count: _todayActivities.length,
              onSeeAll: _todayActivities.isEmpty ? null : widget.onGoToHistory,
            ),
            const SizedBox(height: 8),
            if (_todayActivities.isEmpty)
              _EmptyToday(onStart: _startActivity)
            else
              for (final activity in shown)
                _TodayItem(
                  activity: activity,
                  type: _typesById[activity.activityTypeId],
                  onTap: () => _openDetail(activity),
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Tambah Aktivitas'),
        onPressed: _startActivity,
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  final String name;
  final DateTime now;
  const _GreetingRow({required this.name, required this.now});

  @override
  Widget build(BuildContext context) {
    final shown = name.trim().isEmpty ? 'Pengguna' : name.trim();
    final initial = String.fromCharCode(shown.runes.first).toUpperCase();

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_teal, _tealDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _teal.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            initial,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greetingFor(now)} \ud83d\udc4b',
                style: TextStyle(fontSize: 11.5, color: context.colors.inkSoft),
              ),
              Text(
                shown,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.colors.line),
          ),
          child: Text(
            '${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600, color: context.colors.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final double kcal;
  final int minutes;
  final DailyTarget? target;
  final VoidCallback? onSetTarget;
  const _HeroCard({
    required this.kcal,
    required this.minutes,
    required this.target,
    required this.onSetTarget,
  });

  @override
  Widget build(BuildContext context) {
    final t = target;
    final kcalRatio = t == null ? 0.0 : _ratio(kcal, t.targetCalories);
    final minutesRatio = t == null ? 0.0 : _ratio(minutes, t.targetDurationMinutes);
    final achieved = t != null && kcalRatio >= 1 && minutesRatio >= 1;

    String? pill;
    if (t != null) {
      if (achieved) {
        pill = 'Tercapai \ud83c\udf89';
      } else if (kcal <= 0 && minutes <= 0) {
        pill = 'Belum mulai';
      } else {
        // Limited by whichever goal is further behind, same as the Target tab.
        pill = '${(_unit(math.min(kcalRatio, minutesRatio)) * 100).round()}% tercapai';
      }
    }

    final colors = achieved ? const [_green1, _green2] : const [_teal, _tealDark];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HARI INI',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white70,
                ),
              ),
              if (pill != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pill,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                kcal.round().toString(),
                style: const TextStyle(
                  fontSize: 38,
                  height: 1.1,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
              const Text('kcal terbakar',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          if (t == null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: onSetTarget,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_outlined, size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Set target hari ini',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            _HeroBar(
              icon: Icons.local_fire_department,
              label: 'Kalori',
              valueText:
                  '${kcal.round()} / ${t.targetCalories.round()} kcal${kcalRatio >= 1 ? ' \u2713' : ''}',
              ratio: _unit(kcalRatio),
            ),
            const SizedBox(height: 9),
            _HeroBar(
              icon: Icons.timer_outlined,
              label: 'Durasi',
              valueText:
                  '$minutes / ${t.targetDurationMinutes} menit${minutesRatio >= 1 ? ' \u2713' : ''}',
              ratio: _unit(minutesRatio),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroBar extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueText;
  final double ratio;
  const _HeroBar({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text(label, style: style),
              ],
            ),
            Text(valueText, style: style),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 7, color: Colors.white.withValues(alpha: 0.25)),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(height: 7, color: const Color(0xFFFFFFFF)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int count;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.count, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Aktivitas Hari Ini',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              if (count > 0) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.tealTintStrong,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: _tealDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Lihat semua \u203a',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.bold, color: _tealDark),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayItem extends StatelessWidget {
  final Activity activity;
  final ActivityType? type;
  final VoidCallback onTap;
  const _TodayItem({required this.activity, required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = styleForActivity(type?.name ?? '');
    final time = DateFormat('HH:mm').format(activity.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 1,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: style.color.withValues(alpha: 0.15),
                  child: Icon(style.icon, color: style.color, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type?.name ?? 'Aktivitas',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text('${activity.durationMinutes} menit \u2022 $time',
                          style: TextStyle(fontSize: 11.5, color: context.colors.inkSoft)),
                    ],
                  ),
                ),
                Text(
                  '${activity.caloriesBurned.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: style.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyToday({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter:
          _DashedRRectPainter(color: context.colors.lineStrong, radius: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _teal.withValues(alpha: 0.2),
                  _teal.withValues(alpha: 0.05),
                ]),
              ),
              child: const Icon(Icons.directions_walk, size: 26, color: _tealDark),
            ),
            const SizedBox(height: 10),
            const Text('Belum ada aktivitas hari ini',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Yuk mulai gerak, sekecil apa pun tetap dihitung.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: context.colors.inkSoft),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              ),
              child: const Text('Mulai Aktivitas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    const dash = 6.0;
    const gap = 4.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.75);
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
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
    final label = session.isRunning ? 'SEDANG BERLANGSUNG' : 'DIJEDA \u2014 lanjutkan?';

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
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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
