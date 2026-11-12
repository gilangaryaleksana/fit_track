import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

const _teal = Color(0xFF2EC4B6);
const _tealDark = Color(0xFF1B9AAA);
const _orange = Color(0xFFFF8A3D);
const _green = Color(0xFF22A06B);

// Form limits and step sizes.
const _kcalStep = 50;
const _kcalMin = 50;
const _kcalMax = 5000;
const _minutesStep = 5;
const _minutesMin = 5;
const _minutesMax = 600;

// Used when there's no target at all yet (first ever launch).
const _defaultKcal = 500;
const _defaultMinutes = 45;

/// How many days back we look, so the streak can run longer than the strip.
const _windowDays = 30;

String _dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

class _Preset {
  final String name;
  final int kcal;
  final int minutes;
  const _Preset(this.name, this.kcal, this.minutes);
}

const _presets = [
  _Preset('Ringan', 300, 30),
  _Preset('Sedang', 500, 45),
  _Preset('Intens', 800, 60),
];

class _Totals {
  double kcal = 0;
  int minutes = 0;
}

class _DayStat {
  final DateTime day;
  final double kcal;
  final int minutes;
  final DailyTarget? target;
  const _DayStat({
    required this.day,
    required this.kcal,
    required this.minutes,
    required this.target,
  });

  double _ratio(num value, num goal) => goal <= 0 ? 1.0 : (value / goal).toDouble();

  /// Both goals count: the day is only done once calories AND duration are.
  bool get met =>
      target != null &&
      _ratio(kcal, target!.targetCalories) >= 1 &&
      _ratio(minutes, target!.targetDurationMinutes) >= 1;

  /// 0..1, limited by whichever goal is further behind.
  double get progress {
    if (target == null) return 0;
    final r = math.min(
      _ratio(kcal, target!.targetCalories),
      _ratio(minutes, target!.targetDurationMinutes),
    );
    return math.min(1.0, math.max(0.0, r));
  }
}

/// Tab body — no own Scaffold/AppBar, rendered inside MainNavigationScreen.
class TargetScreen extends StatefulWidget {
  final int userId;
  const TargetScreen({super.key, required this.userId});

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  final _db = DatabaseHelper.instance;

  bool _loaded = false;
  bool _saving = false;

  _DayStat? _today;
  List<_DayStat> _week = [];
  int _streak = 0;

  int _formKcal = _defaultKcal;
  int _formMinutes = _defaultMinutes;
  DateTime? _prefillFrom;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowStart = DateTime(today.year, today.month, today.day - (_windowDays - 1));
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    final activities = await _db.getActivitiesInRange(widget.userId, windowStart, tomorrow);
    final targets = await _db.getTargetsInRange(widget.userId, windowStart, tomorrow);
    final latest = await _db.getLatestTarget(widget.userId);

    final totals = <DateTime, _Totals>{};
    for (final a in activities) {
      final key = DateTime(a.date.year, a.date.month, a.date.day);
      final t = totals.putIfAbsent(key, _Totals.new);
      t.kcal += a.caloriesBurned;
      t.minutes += a.durationMinutes;
    }

    final targetByDay = <DateTime, DailyTarget>{};
    for (final t in targets) {
      targetByDay[DateTime(t.date.year, t.date.month, t.date.day)] = t;
    }

    final days = <_DayStat>[
      for (var i = 0; i < _windowDays; i++)
        () {
          final day = DateTime(windowStart.year, windowStart.month, windowStart.day + i);
          return _DayStat(
            day: day,
            kcal: totals[day]?.kcal ?? 0,
            minutes: totals[day]?.minutes ?? 0,
            target: targetByDay[day],
          );
        }(),
    ];

    // Today is still in progress, so not having finished it yet doesn't
    // break the streak; it just isn't counted until it's done.
    var streak = 0;
    var cursor = days.length - 1;
    if (!days[cursor].met) cursor--;
    while (cursor >= 0 && days[cursor].met) {
      streak++;
      cursor--;
    }

    final todayStat = days.last;
    final source = todayStat.target ?? latest;

    if (!mounted) return;
    setState(() {
      _today = todayStat;
      _week = days.sublist(days.length - 7);
      _streak = streak;
      _formKcal = source?.targetCalories.round() ?? _defaultKcal;
      _formMinutes = source?.targetDurationMinutes ?? _defaultMinutes;
      _prefillFrom = todayStat.target == null ? latest?.date : null;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    await _db.insertOrUpdateTarget(DailyTarget(
      userId: widget.userId,
      targetCalories: _formKcal.toDouble(),
      targetDurationMinutes: _formMinutes,
      date: DateTime.now(),
    ));

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Target berhasil disimpan')),
    );
    await _loadData();
  }

  Future<int?> _askNumber({
    required String title,
    required int initial,
    required int min,
    required int max,
    required String unit,
  }) {
    final controller = TextEditingController(text: '$initial');
    String? error;

    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: unit,
              helperText: 'Antara $min\u2013$max',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                if (v == null || v < min || v > max) {
                  setLocal(() => error = 'Isi angka $min\u2013$max');
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editKcal() async {
    final v = await _askNumber(
      title: 'Target kalori',
      initial: _formKcal,
      min: _kcalMin,
      max: _kcalMax,
      unit: 'kcal',
    );
    if (v != null) setState(() => _formKcal = v);
  }

  Future<void> _editMinutes() async {
    final v = await _askNumber(
      title: 'Target durasi',
      initial: _formMinutes,
      min: _minutesMin,
      max: _minutesMax,
      unit: 'menit',
    );
    if (v != null) setState(() => _formMinutes = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    final today = _today!;
    final now = DateTime.now();
    final hasTarget = today.target != null;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          _ProgressCard(
            today: today,
            dateLabel:
                '${_weekdays[now.weekday - 1]}, ${_dayMonth(now)}',
          ),
          const SizedBox(height: 12),
          _WeekCard(week: _week, streak: _streak),
          const SizedBox(height: 12),
          _FormCard(
            kcal: _formKcal,
            minutes: _formMinutes,
            saving: _saving,
            hasTarget: hasTarget,
            prefillNote: _prefillFrom != null
                ? 'Diisi dari target terakhir (${_dayMonth(_prefillFrom!)})'
                : null,
            dateNote: 'Berlaku untuk hari ini \u00b7 ${_dayMonth(now)} ${now.year}',
            onPreset: (p) => setState(() {
              _formKcal = p.kcal;
              _formMinutes = p.minutes;
            }),
            onKcalChanged: (v) => setState(
                () => _formKcal = math.min(_kcalMax, math.max(_kcalMin, v))),
            onMinutesChanged: (v) => setState(() =>
                _formMinutes = math.min(_minutesMax, math.max(_minutesMin, v))),
            onEditKcal: _editKcal,
            onEditMinutes: _editMinutes,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress card
// ---------------------------------------------------------------------------

class _CardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _CardShell({
    required this.child,
  }) : padding = const EdgeInsets.fromLTRB(16, 14, 16, 14);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final _DayStat today;
  final String dateLabel;
  const _ProgressCard({required this.today, required this.dateLabel});

  String _remainingText(DailyTarget t) {
    final remKcal = math.max(0.0, t.targetCalories - today.kcal);
    final remMinutes = math.max(0, t.targetDurationMinutes - today.minutes);

    final parts = <String>[
      if (remKcal > 0) '${remKcal.ceil()} kcal',
      if (remMinutes > 0) '$remMinutes menit',
    ];
    return 'Tinggal ${parts.join(' dan ')} lagi \ud83d\udcaa';
  }

  @override
  Widget build(BuildContext context) {
    final target = today.target;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progres hari ini',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(dateLabel, style: TextStyle(fontSize: 11, color: context.colors.inkSoft)),
            ],
          ),
          const SizedBox(height: 12),
          if (target == null)
            const _NoTargetBody()
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _RingItem(
                  icon: Icons.local_fire_department,
                  label: 'Kalori',
                  value: today.kcal,
                  goal: target.targetCalories,
                  color: _orange,
                  valueText: today.kcal.round().toString(),
                  goalText: '/ ${target.targetCalories.round()} kcal',
                ),
                _RingItem(
                  icon: Icons.timer_outlined,
                  label: 'Durasi',
                  value: today.minutes.toDouble(),
                  goal: target.targetDurationMinutes.toDouble(),
                  color: _tealDark,
                  valueText: '${today.minutes}',
                  goalText: '/ ${target.targetDurationMinutes} menit',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusBanner(
              achieved: today.met,
              text: today.met
                  ? 'Target tercapai! Mantap \ud83c\udf89'
                  : _remainingText(target),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoTargetBody extends StatelessWidget {
  const _NoTargetBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _teal.withValues(alpha: 0.2),
                  _teal.withValues(alpha: 0.05),
                ]),
              ),
              child: const Icon(Icons.flag_outlined, size: 28, color: _tealDark),
            ),
            const SizedBox(height: 10),
            const Text('Belum ada target hari ini',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Tentuin dulu berapa kalori dan durasi yang mau kamu kejar hari ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: context.colors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double goal;
  final Color color;
  final String valueText;
  final String goalText;

  const _RingItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.valueText,
    required this.goalText,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 1.0 : math.min(1.0, math.max(0.0, value / goal));
    final done = ratio >= 1;
    final ringColor = done ? _green : color;

    return Column(
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(92, 92),
                painter: _RingPainter(progress: ratio, color: ringColor),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(valueText,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(
                    done ? '$goalText \u2713' : goalText,
                    style: TextStyle(fontSize: 9.5, color: context.colors.inkSoft),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: context.colors.inkSoft),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.inkSoft)),
          ],
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: 0.16),
    );

    if (progress <= 0) return;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _StatusBanner extends StatelessWidget {
  final bool achieved;
  final String text;
  const _StatusBanner({required this.achieved, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: achieved ? null : context.colors.tealTint,
        gradient: achieved
            ? const LinearGradient(colors: [Color(0xFF2FBF8A), Color(0xFF1E9E6E)])
            : null,
        borderRadius: BorderRadius.circular(12),
        boxShadow: achieved
            ? [
                BoxShadow(
                  color: _green.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: achieved ? Colors.white : _tealDark,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7-day strip
// ---------------------------------------------------------------------------

class _WeekCard extends StatelessWidget {
  final List<_DayStat> week;
  final int streak;
  const _WeekCard({required this.week, required this.streak});

  @override
  Widget build(BuildContext context) {
    final metCount = week.where((d) => d.met).length;

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('7 hari terakhir',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.colors.streakBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 12, color: context.colors.streakText),
                      const SizedBox(width: 3),
                      Text(
                        '$streak hari beruntun',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: context.colors.streakText,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            child: Stack(
              children: [
                // The target line: a full-height bar means the day was met.
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 1.5,
                    child: CustomPaint(painter: _DashedLinePainter(color: context.colors.lineStrong)),
                  ),
                ),
                Positioned.fill(
                  top: 4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < week.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.5),
                            child: _WeekBar(
                              stat: week[i],
                              isToday: i == week.length - 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < week.length; i++)
                Expanded(
                  child: Text(
                    _weekdays[week[i].day.weekday - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: i == week.length - 1 ? context.colors.ink : context.colors.inkSoft,
                      fontWeight:
                          i == week.length - 1 ? FontWeight.w800 : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Target tercapai $metCount dari 7 hari',
              style: TextStyle(fontSize: 11, color: context.colors.inkSoft)),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  final _DayStat stat;
  final bool isToday;
  const _WeekBar({required this.stat, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final progress = stat.progress;
    final heightFactor = math.max(progress, 0.07);

    Color? flat;
    List<Color>? gradient;

    if (stat.met) {
      gradient = isToday
          ? const [Color(0xFF46CF9B), _green]
          : const [_teal, _tealDark];
    } else if (isToday && progress > 0) {
      gradient = const [Color(0xFFFFB27A), _orange];
    } else if (progress > 0) {
      flat = context.colors.barPartial;
    } else {
      flat = context.colors.track;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: heightFactor,
        widthFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: flat,
            gradient: gradient == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradient,
                  ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
              bottom: Radius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 5.0;
    const gap = 4.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + dash, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Set-target form
// ---------------------------------------------------------------------------

class _FormCard extends StatelessWidget {
  final int kcal;
  final int minutes;
  final bool saving;
  final bool hasTarget;
  final String? prefillNote;
  final String dateNote;
  final ValueChanged<_Preset> onPreset;
  final ValueChanged<int> onKcalChanged;
  final ValueChanged<int> onMinutesChanged;
  final VoidCallback onEditKcal;
  final VoidCallback onEditMinutes;
  final VoidCallback onSave;

  const _FormCard({
    required this.kcal,
    required this.minutes,
    required this.saving,
    required this.hasTarget,
    required this.prefillNote,
    required this.dateNote,
    required this.onPreset,
    required this.onKcalChanged,
    required this.onMinutesChanged,
    required this.onEditKcal,
    required this.onEditMinutes,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Atur Target Harian',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (prefillNote != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.amberBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, size: 14, color: context.colors.amberText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      prefillNote!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.amberText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              for (var i = 0; i < _presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _PresetCard(
                    preset: _presets[i],
                    selected: _presets[i].kcal == kcal && _presets[i].minutes == minutes,
                    onTap: () => onPreset(_presets[i]),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _StepperRow(
            icon: Icons.local_fire_department,
            color: _orange,
            label: 'Kalori',
            value: kcal,
            unit: 'kcal',
            canDecrease: kcal > _kcalMin,
            canIncrease: kcal < _kcalMax,
            onDecrease: () => onKcalChanged(kcal - _kcalStep),
            onIncrease: () => onKcalChanged(kcal + _kcalStep),
            onTapValue: onEditKcal,
          ),
          const SizedBox(height: 12),
          _StepperRow(
            icon: Icons.timer_outlined,
            color: _tealDark,
            label: 'Durasi',
            value: minutes,
            unit: 'menit',
            canDecrease: minutes > _minutesMin,
            canIncrease: minutes < _minutesMax,
            onDecrease: () => onMinutesChanged(minutes - _minutesStep),
            onIncrease: () => onMinutesChanged(minutes + _minutesStep),
            onTapValue: onEditMinutes,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              style: FilledButton.styleFrom(
                backgroundColor: _teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(hasTarget ? 'Simpan Target' : 'Simpan Target Hari Ini'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(dateNote, style: TextStyle(fontSize: 10.5, color: context.colors.inkSoft)),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final _Preset preset;
  final bool selected;
  final VoidCallback onTap;
  const _PresetCard({required this.preset, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.tealTint : context.colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _teal : context.colors.line,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(preset.name,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(
                '${preset.kcal} kcal\n${preset.minutes} menit',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, height: 1.45, color: context.colors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final String unit;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onTapValue;

  const _StepperRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
    required this.onTapValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        _StepButton(icon: Icons.remove, onTap: canDecrease ? onDecrease : null),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTapValue,
          child: Container(
            constraints: const BoxConstraints(minWidth: 70),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: Alignment.center,
            child: Text.rich(
              TextSpan(
                text: '$value ',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w500, color: context.colors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
        _StepButton(icon: Icons.add, onTap: canIncrease ? onIncrease : null),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: context.colors.surface,
      shape: CircleBorder(
        side: BorderSide(
          color: enabled ? context.colors.lineStrong : context.colors.line,
          width: 1.5,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? context.colors.inkSoft : context.colors.lineStrong,
          ),
        ),
      ),
    );
  }
}
