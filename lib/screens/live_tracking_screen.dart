import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:latlong2/latlong.dart' as ll;
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';

const _cartoKey = 'cb1_3xnq_1_d5f34b66a55d20c44f8bb363';

class LiveTrackingScreen extends StatefulWidget {
  final int userId;
  const LiveTrackingScreen({super.key, required this.userId});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _db = DatabaseHelper.instance;
  final _noteController = TextEditingController();
  final _mapController = MapController();

  List<ActivityType> _types = [];
  ActivityType? _selectedType;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  bool _saving = false;

  StreamSubscription<Position>? _positionSub;
  final List<RoutePoint> _routePoints = [];
  ll.LatLng? _currentLatLng;
  double _totalDistanceMeters = 0;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadTypes();
    _initLiveLocation();
  }

  Future<void> _loadTypes() async {
    final types = await _db.getActivityTypes();
    setState(() {
      _types = types;
      _selectedType = types.isNotEmpty ? types.first : null;
    });
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _locationError = 'Aktifkan GPS/Lokasi di HP kamu dulu');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _locationError = 'Izin lokasi ditolak');
      return false;
    }
    setState(() => _locationError = null);
    return true;
  }

  /// Keeps the blue dot + map centered on the user as soon as this screen
  /// opens, independent of whether tracking has started yet.
  Future<void> _initLiveLocation() async {
    final granted = await _ensureLocationPermission();
    if (!granted) return;

    try {
      final current = await Geolocator.getCurrentPosition();
      final latLng = ll.LatLng(current.latitude, current.longitude);
      setState(() => _currentLatLng = latLng);
      _mapController.move(latLng, 17);
    } catch (_) {
      // ignore, stream below will update once a fix is available
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((position) {
      final latLng = ll.LatLng(position.latitude, position.longitude);

      if (_isRunning) {
        if (_routePoints.isNotEmpty) {
          final last = _routePoints.last;
          _totalDistanceMeters += Geolocator.distanceBetween(
            last.latitude,
            last.longitude,
            position.latitude,
            position.longitude,
          );
        }
        _routePoints.add(RoutePoint(
          activityId: 0,
          latitude: position.latitude,
          longitude: position.longitude,
          recordedAt: DateTime.now(),
        ));
      }

      setState(() => _currentLatLng = latLng);
      _mapController.move(latLng, _mapController.camera.zoom);
    });
  }

  double get _liveCalories {
    if (_selectedType == null) return 0;
    final minutes = _elapsed.inMilliseconds / 60000;
    return minutes * _selectedType!.caloriesPerMinute;
  }

  String get _paceLabel {
    final km = _totalDistanceMeters / 1000;
    if (km < 0.02 || _elapsed.inSeconds < 5) return "–'––\"";
    final paceMinutes = (_elapsed.inSeconds / 60) / km;
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  void _start() {
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = _stopwatch.elapsed);
    });
    setState(() => _isRunning = true);
  }

  void _pause() {
    _stopwatch.stop();
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  Future<void> _finish() async {
    if (_selectedType == null || _elapsed.inSeconds < 1) return;
    _pause();
    setState(() => _saving = true);

    final durationMinutes = (_elapsed.inSeconds / 60).round().clamp(1, 999999);

    final activity = Activity(
      userId: widget.userId,
      activityTypeId: _selectedType!.id!,
      durationMinutes: durationMinutes,
      caloriesBurned: _liveCalories,
      date: DateTime.now(),
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    final activityId = await _db.insertActivity(activity);
    if (_routePoints.isNotEmpty) {
      await _db.insertRoutePoints(activityId, _routePoints);
    }

    if (mounted) Navigator.pop(context);
  }

  void _recenter() {
    if (_currentLatLng != null) {
      _mapController.move(_currentLatLng!, 17);
    }
  }

  Future<void> _pickActivityType() async {
    final result = await showModalBottomSheet<ActivityType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _ActivityTypeSheet(types: _types, selected: _selectedType),
    );
    if (result != null) setState(() => _selectedType = result);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _positionSub?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _selectedType != null
        ? styleForActivity(_selectedType!.name)
        : const ActivityStyle(Icons.sports, Colors.teal);

    final started = _elapsed > Duration.zero || _isRunning;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: _selectedType?.name ?? 'Aktivitas Langsung'),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _currentLatLng ?? const ll.LatLng(-6.2, 106.816),
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://basemaps.cartocdn.com/rastertiles/light_nolabels/{z}/{x}/{y}.png?key=$_cartoKey',
                        userAgentPackageName: 'com.gilangarya.fittrack',
                      ),
                      if (_routePoints.length > 1)
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
                      if (_currentLatLng != null)
                        MarkerLayer(markers: [
                          Marker(
                            point: _currentLatLng!,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4285F4)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                    ],
                  ),
                  if (!started)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: _TypePill(
                        style: style,
                        name: _selectedType?.name ?? 'Pilih jenis',
                        onTap: _pickActivityType,
                      ),
                    ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _RoundIconButton(
                        icon: Icons.my_location, onTap: _recenter),
                  ),
                  if (_locationError != null)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _locationError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom panel: stats + controls
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14142020),
                    blurRadius: 24,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _Stat(
                          label: '⏱ Durasi', value: _formatDuration(_elapsed)),
                      const _StatDivider(),
                      _Stat(label: '⚡ Pace', value: _paceLabel),
                      const _StatDivider(),
                      _Stat(
                        label: '🔥 Kalori',
                        value: _liveCalories.toStringAsFixed(0),
                      ),
                    ],
                  ),
                  if (!_isRunning && started) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE4EAE9)),
                      ),
                      child: TextField(
                        controller: _noteController,
                        style: const TextStyle(fontSize: 12.5),
                        decoration: const InputDecoration(
                          hintText: 'Catatan (opsional)',
                          hintStyle: TextStyle(color: Color(0xFF5B6B69)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!started)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _start,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Mulai'),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _saving ? null : (_isRunning ? _pause : _start),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE4EAE9)),
                            ),
                            child: Text(_isRunning ? 'Jeda' : 'Lanjut'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _finish,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2EC4B6),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Selesai & Simpan'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final ActivityStyle style;
  final String name;
  final VoidCallback onTap;
  const _TypePill(
      {required this.style, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: style.color.withValues(alpha: 0.15),
                child: Icon(style.icon, color: style.color, size: 15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFB7C2C0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: const Color(0xFF14201F)),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF5B6B69))),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 30, color: const Color(0xFFE4EAE9));
  }
}

class _ActivityTypeSheet extends StatelessWidget {
  final List<ActivityType> types;
  final ActivityType? selected;
  const _ActivityTypeSheet({required this.types, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4EAE9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            for (final type in types)
              InkWell(
                onTap: () => Navigator.pop(context, type),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: selected?.id == type.id
                      ? const Color(0xFFEAF7F6)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: styleForActivity(type.name)
                            .color
                            .withValues(alpha: 0.15),
                        child: Icon(
                          styleForActivity(type.name).icon,
                          color: styleForActivity(type.name).color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(type.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
