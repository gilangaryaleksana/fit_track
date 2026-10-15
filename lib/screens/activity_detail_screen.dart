import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../db/database_helper.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../utils/activity_style.dart';
import '../theme/app_colors.dart';

const _cartoKey = 'cb1_3xnq_1_d5f34b66a55d20c44f8bb363';

class ActivityDetailScreen extends StatefulWidget {
  final Activity activity;
  final ActivityType? type;
  const ActivityDetailScreen({super.key, required this.activity, required this.type});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final _db = DatabaseHelper.instance;
  List<RoutePoint> _routePoints = [];
  int? _serverId;
  bool _loading = true;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final points = await _db.getRoutePoints(widget.activity.id!);
    final serverId = await _db.getActivityServerId(widget.activity.id!);
    if (!mounted) return;
    setState(() {
      _routePoints = points;
      _serverId = serverId;
      _loading = false;
    });
  }

  double get _distanceMeters {
    double total = 0;
    for (var i = 1; i < _routePoints.length; i++) {
      total += _haversine(_routePoints[i - 1], _routePoints[i]);
    }
    return total;
  }

  double _haversine(RoutePoint a, RoutePoint b) {
    const earthRadius = 6371000.0;
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadius * c;
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  /// What this session actually earned per minute (e.g. "3" or "3.5").
  String get _caloriesPerMinuteLabel {
    final minutes = widget.activity.durationMinutes;
    if (minutes <= 0) return '0';
    final rate = double.parse((widget.activity.caloriesBurned / minutes).toStringAsFixed(1));
    return rate % 1 == 0 ? rate.toStringAsFixed(0) : rate.toStringAsFixed(1);
  }

  String get _paceLabel {
    final km = _distanceMeters / 1000;
    if (km < 0.02) return "\u2013'\u2013\u2013\"";
    final paceMinutes = widget.activity.durationMinutes / km;
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Aktivitas?'),
        content: const Text('Data ini akan dihapus permanen dari HP kamu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    final serverId = _serverId;
    await _db.deleteActivity(widget.activity.id!);
    if (serverId != null) SyncService.instance.deleteRemote(serverId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.type != null
        ? styleForActivity(widget.type!.name)
        : const ActivityStyle(Icons.sports, Colors.teal);
    final hasRoute = _routePoints.length > 1;
    // Swimming/yoga/gym never record a route, so "no GPS data" would be
    // misleading for them: they get a time-focused layout instead.
    final timeFocused = !style.usesMap;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Aktivitas'),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            onPressed: _deleting ? null : _delete,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (hasRoute)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 160,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FlutterMap(
                            options: MapOptions(
                              initialCenter: ll.LatLng(
                                _routePoints[_routePoints.length ~/ 2].latitude,
                                _routePoints[_routePoints.length ~/ 2].longitude,
                              ),
                              initialZoom: 14,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                              ),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://basemaps.cartocdn.com/rastertiles/${context.isDark ? 'dark' : 'light'}_nolabels/{z}/{x}/{y}.png?key=$_cartoKey',
                                userAgentPackageName: 'com.gilangarya.fittrack',
                              ),
                              PolylineLayer(polylines: [
                                Polyline(
                                  points: _routePoints
                                      .map((p) => ll.LatLng(p.latitude, p.longitude))
                                      .toList(),
                                  color: style.color,
                                  strokeWidth: 4,
                                  strokeCap: StrokeCap.round,
                                  strokeJoin: StrokeJoin.round,
                                ),
                              ]),
                              MarkerLayer(markers: [
                                Marker(
                                  point: ll.LatLng(
                                      _routePoints.first.latitude, _routePoints.first.longitude),
                                  width: 14,
                                  height: 14,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2EC4B6),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                                Marker(
                                  point: ll.LatLng(
                                      _routePoints.last.latitude, _routePoints.last.longitude),
                                  width: 14,
                                  height: 14,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: style.color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _SyncChip(synced: _serverId != null),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (timeFocused)
                  _TimeHero(style: style, minutes: widget.activity.durationMinutes)
                else
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 30, color: context.colors.lineStrong),
                        const SizedBox(height: 8),
                        Text('Tidak ada data rute GPS',
                            style: TextStyle(color: context.colors.inkSoft, fontSize: 12.5)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: style.color.withValues(alpha: 0.15),
                      child: Icon(style.icon, color: style.color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.type?.name ?? 'Aktivitas',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(dateFormat.format(widget.activity.date),
                              style: TextStyle(
                                  fontSize: 12, color: context.colors.inkSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.9,
                  children: [
                    if (timeFocused) ...[
                      // Duration is already the hero, so show what it earned.
                      _StatTile(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Kalori',
                        value: '${widget.activity.caloriesBurned.toStringAsFixed(0)} kcal',
                      ),
                      _StatTile(
                        icon: Icons.bolt_outlined,
                        label: 'Laju',
                        value: '$_caloriesPerMinuteLabel kcal/mnt',
                      ),
                    ] else ...[
                      _StatTile(
                        icon: Icons.timer_outlined,
                        label: 'Durasi',
                        value: '${widget.activity.durationMinutes} menit',
                      ),
                      if (hasRoute) ...[
                        _StatTile(
                          icon: Icons.location_on_outlined,
                          label: 'Jarak',
                          value: '${(_distanceMeters / 1000).toStringAsFixed(2)} km',
                        ),
                        _StatTile(
                          icon: Icons.bolt_outlined,
                          label: 'Pace',
                          value: '$_paceLabel /km',
                        ),
                      ],
                      _StatTile(
                        icon: Icons.local_fire_department_outlined,
                        label: 'Kalori',
                        value: '${widget.activity.caloriesBurned.toStringAsFixed(0)} kcal',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CATATAN',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.colors.inkSoft)),
                      const SizedBox(height: 6),
                      Text(
                        (widget.activity.note?.isNotEmpty ?? false)
                            ? widget.activity.note!
                            : 'Tidak ada catatan',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontStyle: (widget.activity.note?.isNotEmpty ?? false)
                              ? FontStyle.normal
                              : FontStyle.italic,
                          color: (widget.activity.note?.isNotEmpty ?? false)
                              ? context.colors.ink
                              : context.colors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasRoute
                            ? 'Jenis: Aktivitas Langsung'
                            : (timeFocused
                                ? 'Kalori dihitung dari durasi'
                                : 'Jenis: Input Manual'),
                        style: TextStyle(fontSize: 11.5, color: context.colors.inkSoft),
                      ),
                      if (!hasRoute)
                        Text(
                          _serverId != null ? '\u2601\ufe0f Tersinkron' : '\u2601\ufe0f Belum sinkron',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _serverId != null
                                ? const Color(0xFF1B9AAA)
                                : const Color(0xFFB7914A),
                          ),
                        )
                      else
                        Text('${_routePoints.length} titik GPS',
                            style: TextStyle(fontSize: 11.5, color: context.colors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// 32 -> "32 menit", 65 -> "1 jam 5 menit", 120 -> "2 jam".
String _formatLongDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m menit';
  if (m == 0) return '$h jam';
  return '$h jam $m menit';
}

/// Hero for activities without a map: the duration, big, on the type's color.
class _TimeHero extends StatelessWidget {
  final ActivityStyle style;
  final int minutes;
  const _TimeHero({required this.style, required this.minutes});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [style.color.withValues(alpha: 0.7), style.color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Oversized, faint icon as a watermark.
            Positioned(
              right: -18,
              bottom: -22,
              child: Icon(style.icon, size: 130, color: Colors.white.withValues(alpha: 0.14)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        const Text(
                          'DURASI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _formatLongDuration(minutes),
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  final bool synced;
  const _SyncChip({required this.synced});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_outlined,
              size: 13, color: synced ? const Color(0xFF1B9AAA) : const Color(0xFFB7914A)),
          const SizedBox(width: 5),
          Text(
            synced ? 'Tersinkron' : 'Belum sinkron',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: synced ? const Color(0xFF1B9AAA) : const Color(0xFFB7914A),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: context.colors.inkSoft),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, color: context.colors.inkSoft)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
