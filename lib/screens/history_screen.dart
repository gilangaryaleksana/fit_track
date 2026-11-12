import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';
import '../services/sync_service.dart';
import 'activity_detail_screen.dart';
import 'start_activity_flow.dart';
import '../theme/app_colors.dart';

const _weekdays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// 3200 -> "3.200" (Indonesian thousands separator, no locale data needed).
String _formatThousands(num value) => value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

/// 192 -> "3j 12m", 65 -> "1j 5m", 45 -> "45m", 120 -> "2j".
String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}j';
  return '${h}j ${m}m';
}

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daysAgo = today.difference(day).inDays;

  final base = '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}'
      '${day.year != now.year ? ' ${day.year}' : ''}';

  if (daysAgo == 0) return 'Hari ini \u00b7 $base';
  if (daysAgo == 1) return 'Kemarin \u00b7 $base';
  return base;
}

class _DayHeader {
  final DateTime day;
  double kcal = 0;
  _DayHeader(this.day);
}

/// Tab body — no own Scaffold/AppBar, rendered inside MainNavigationScreen.
class HistoryScreen extends StatefulWidget {
  final int userId;
  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseHelper.instance;

  List<Activity> _activities = [];
  List<ActivityType> _types = [];
  Map<int, ActivityType> _typesById = {};
  Set<int> _routeIds = {};
  Set<int> _syncedIds = {};
  int? _filterTypeId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await _loadLocalData();
    final syncedAny =
        await SyncService.instance.syncPendingActivities(widget.userId);
    if (syncedAny) await _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final activities = await _db.getActivitiesByUser(widget.userId);
    final types = await _db.getActivityTypes();
    final routeIds = await _db.getActivityIdsWithRoute(widget.userId);
    final syncedIds = await _db.getSyncedActivityIds(widget.userId);
    if (!mounted) return;
    setState(() {
      _activities = activities;
      _types = types;
      _typesById = {for (final t in types) t.id!: t};
      _routeIds = routeIds;
      _syncedIds = syncedIds;
      _loaded = true;
    });
  }

  Future<void> _delete(Activity activity) async {
    // Drop it from the list right away: a dismissed Dismissible must leave
    // the tree in the same frame, so we can't wait for the database.
    setState(() => _activities.removeWhere((a) => a.id == activity.id));

    final serverId = await _db.getActivityServerId(activity.id!);
    await _db.deleteActivity(activity.id!);
    if (serverId != null) SyncService.instance.deleteRemote(serverId);

    loadData();
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

  List<Object> _buildRows(List<Activity> list) {
    final rows = <Object>[];
    _DayHeader? header;

    for (final a in list) {
      final day = DateTime(a.date.year, a.date.month, a.date.day);
      if (header == null || header.day != day) {
        header = _DayHeader(day);
        rows.add(header);
      }
      header.kcal += a.caloriesBurned;
      rows.add(a);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    if (_activities.isEmpty) {
      return _EmptyHistory(
        onStart: () async {
          await startActivityFlow(context, widget.userId);
          loadData();
        },
      );
    }

    final visible = _filterTypeId == null
        ? _activities
        : _activities.where((a) => a.activityTypeId == _filterTypeId).toList();
    final filterType = _filterTypeId != null ? _typesById[_filterTypeId] : null;

    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = visible.where((a) => a.date.isAfter(cutoff)).toList();
    final recentMinutes = recent.fold<int>(0, (sum, a) => sum + a.durationMinutes);
    final recentKcal = recent.fold<double>(0, (sum, a) => sum + a.caloriesBurned);

    final rows = _buildRows(visible);

    return RefreshIndicator(
      onRefresh: loadData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: [
                  _SummaryCard(
                    label: filterType != null
                        ? '${filterType.name.toUpperCase()} \u00b7 7 HARI TERAKHIR'
                        : '7 HARI TERAKHIR',
                    count: recent.length,
                    minutes: recentMinutes,
                    kcal: recentKcal,
                    tint: filterType != null
                        ? styleForActivity(filterType.name).color
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _FilterChips(
                    types: _types,
                    selectedId: _filterTypeId,
                    onSelected: (id) => setState(() => _filterTypeId = id),
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Belum ada aktivitas ${filterType?.name ?? ''}'.trim(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.inkSoft),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final row = rows[index];
                    if (row is _DayHeader) return _DayHeaderRow(header: row);

                    final activity = row as Activity;
                    return _HistoryItem(
                      activity: activity,
                      type: _typesById[activity.activityTypeId],
                      hasRoute: _routeIds.contains(activity.id),
                      synced: _syncedIds.contains(activity.id),
                      onTap: () => _openDetail(activity),
                      onDismissed: () => _delete(activity),
                    );
                  },
                  childCount: rows.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final int minutes;
  final double kcal;

  /// Null = the default teal; set when a type filter is active.
  final Color? tint;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.minutes,
    required this.kcal,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = tint != null
        ? [tint!.withValues(alpha: 0.7), tint!]
        : const [Color(0xFF2EC4B6), Color(0xFF1B9AAA)];
    final shadow = tint ?? const Color(0xFF2EC4B6);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadow.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              children: [
                _SummaryStat(value: '$count', label: 'Aktivitas'),
                const _SummaryDivider(),
                _SummaryStat(value: _formatMinutes(minutes), label: 'Durasi'),
                const _SummaryDivider(),
                _SummaryStat(value: _formatThousands(kcal), label: 'kkal'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String value;
  final String label;
  const _SummaryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.only(right: 12),
      color: Colors.white24,
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<ActivityType> types;
  final int? selectedId;
  final ValueChanged<int?> onSelected;
  const _FilterChips({
    required this.types,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'Semua',
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final type in types) ...[
            const SizedBox(width: 7),
            _FilterChip(
              label: type.name,
              icon: styleForActivity(type.name).icon,
              iconColor: styleForActivity(type.name).color,
              selected: selectedId == type.id,
              onTap: () => onSelected(type.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.ink;
    return Material(
      color: selected ? ink : context.colors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? ink : context.colors.line),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? context.colors.onInk : iconColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? context.colors.onInk : context.colors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeaderRow extends StatelessWidget {
  final _DayHeader header;
  const _DayHeaderRow({required this.header});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              _dayLabel(header.day),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatThousands(header.kcal)} kkal',
            style: TextStyle(fontSize: 11, color: context.colors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final Activity activity;
  final ActivityType? type;
  final bool hasRoute;
  final bool synced;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _HistoryItem({
    required this.activity,
    required this.type,
    required this.hasRoute,
    required this.synced,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleForActivity(type?.name ?? '');
    final time = DateFormat('HH:mm').format(activity.date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: ValueKey(activity.id),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => onDismissed(),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Material(
            color: context.colors.surface,
            child: InkWell(
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
                          Text(
                            type?.name ?? 'Aktivitas',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${activity.durationMinutes} menit \u2022 $time',
                            style: TextStyle(
                                fontSize: 11.5, color: context.colors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${activity.caloriesBurned.toStringAsFixed(0)} kcal',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: style.color,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasRoute) ...[
                              Icon(Icons.place_outlined,
                                  size: 13, color: context.colors.inkSoft),
                              const SizedBox(width: 4),
                            ],
                            Icon(
                              synced
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_upload_outlined,
                              size: 13,
                              color: synced
                                  ? const Color(0xFF1B9AAA)
                                  : const Color(0xFFB7914A),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final VoidCallback onStart;
  const _EmptyHistory({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2EC4B6).withValues(alpha: 0.18),
                    const Color(0xFF2EC4B6).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: const Icon(Icons.history, size: 40, color: Color(0xFF1B9AAA)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum ada riwayat',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Aktivitas yang kamu simpan bakal muncul di sini, lengkap dengan ringkasan mingguannya.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.55, color: context.colors.inkSoft),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2EC4B6),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              ),
              child: const Text('Mulai Aktivitas'),
            ),
          ],
        ),
      ),
    );
  }
}
