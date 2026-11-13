import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:permission_handler/permission_handler.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../services/tracking_task_handler.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../utils/activity_style.dart';
import '../utils/unit_formatter.dart';
import '../widgets/step_indicator.dart';
import '../theme/app_colors.dart';

const _cartoKey = 'cb1_3xnq_1_d5f34b66a55d20c44f8bb363';

/// Step 2 of "Aktivitas Langsung". The layout depends on the activity type:
/// outdoor types get a live map + GPS, the rest get a big centered timer.
///
/// Pops with `true` when the whole flow should close (activity saved, or a
/// session is in progress in the background) and `false` when the user just
/// backs out before starting, so they can change the type on step 1.
class LiveTrackingScreen extends StatefulWidget {
  final int userId;

  /// Type picked on step 1. Null when re-opening an already running/paused
  /// session (e.g. from the Home banner) — it's restored from storage then.
  final ActivityType? initialType;

  const LiveTrackingScreen({super.key, required this.userId, this.initialType});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _db = DatabaseHelper.instance;
  final _noteController = TextEditingController();
  final _mapController = MapController();

  ActivityType? _selectedType;
  bool _ready = false;

  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  bool _saving = false;
  DateTime? _startedAt;

  // Drives smooth per-second UI updates between the background service's
  // 3-second sync ticks, so the displayed clock doesn't jump by 3s at a time.
  Timer? _uiTicker;
  Duration _displayBaseElapsed = Duration.zero;
  DateTime? _displayBaseAt;

  final List<RoutePoint> _routePoints = [];
  ll.LatLng? _currentLatLng;
  double _totalDistanceMeters = 0;
  int _movingSeconds = 0;
  String? _locationError;
  bool _autoPauseSession = false;

  bool get _usesMap => _selectedType == null
      ? true
      : styleForActivity(_selectedType!.name).usesMap;

  bool get _hasProgress => _elapsed > Duration.zero || _isRunning;

  Duration get _displayElapsed {
    if (_autoPauseSession) return _elapsed;
    if (!_isRunning || _displayBaseAt == null) return _elapsed;
    return _displayBaseElapsed + DateTime.now().difference(_displayBaseAt!);
  }

  void _resyncDisplay() {
    _displayBaseElapsed = _elapsed;
    _displayBaseAt = DateTime.now();
  }

  void _startUiTicker() {
    _uiTicker?.cancel();
    _resyncDisplay();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = null;
    _elapsed = _displayElapsed;
  }

  @override
  void initState() {
    super.initState();
    _autoPauseSession = SettingsService.instance.autoPause;
    SettingsService.instance.addListener(_settingsChanged);
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    _init();
  }

  void _settingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    final types = await _db.getActivityTypes();

    if (widget.initialType != null) {
      for (final t in types) {
        if (t.id == widget.initialType!.id) {
          _selectedType = t;
          break;
        }
      }
    }

    await _resumeIfServiceRunning(types);
    if (!mounted) return;

    setState(() {
      _selectedType ??= types.isNotEmpty ? types.first : null;
      _ready = true;
    });

    // Only outdoor types need the location (and its permission) up front.
    if (_usesMap) _initOneShotLocation();
  }

  Future<void> _resumeIfServiceRunning(List<ActivityType> types) async {
    final sessionActive =
        await FlutterForegroundTask.getData<bool>(key: 'sessionActive') ??
            false;
    if (!sessionActive) return;

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
    final startedAtRaw =
        await FlutterForegroundTask.getData<String>(key: 'sessionStartedAt');
    final autoPause =
        await FlutterForegroundTask.getData<bool>(key: 'autoPause') ?? false;

    ActivityType? matchedType;
    for (final t in types) {
      if (t.id == typeId) {
        matchedType = t;
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      if (matchedType != null) _selectedType = matchedType;
      _elapsed = Duration(seconds: seconds);
      _totalDistanceMeters = distance;
      _movingSeconds = movingSeconds;
      _autoPauseSession = autoPause;
      _startedAt =
          startedAtRaw != null ? DateTime.tryParse(startedAtRaw) : null;
      _isRunning = isRunning;
    });
    if (isRunning) _startUiTicker();
  }

  void _moveMap(ll.LatLng target, [double? zoom]) {
    if (!_ready || !_usesMap) return;
    try {
      _mapController.move(target, zoom ?? _mapController.camera.zoom);
    } catch (_) {
      // Map isn't attached yet; the next update will move it.
    }
  }

  Future<bool> _ensureForegroundLocationPermission() async {
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

  /// Just centers the map on open — no continuous stream/service yet,
  /// so we don't burn battery or ask for background permission until
  /// the user actually taps Mulai.
  Future<void> _initOneShotLocation() async {
    final granted = await _ensureForegroundLocationPermission();
    if (!granted) return;
    try {
      final current = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final latLng = ll.LatLng(current.latitude, current.longitude);
      setState(() => _currentLatLng = latLng);
      _moveMap(latLng, 17);
    } catch (_) {
      // no fix yet, ignore
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is! Map || !mounted) return;
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;
    final distance = data['distanceMeters'] as double?;
    final seconds = data['elapsedSeconds'] as int?;
    final movingSeconds = data['movingSeconds'] as int?;

    setState(() {
      // No lat/lng when the service runs without GPS (indoor types).
      if (lat != null && lng != null) {
        _currentLatLng = ll.LatLng(lat, lng);
        _routePoints.add(RoutePoint(
          activityId: 0,
          latitude: lat,
          longitude: lng,
          recordedAt: DateTime.now(),
        ));
      }
      if (distance != null) _totalDistanceMeters = distance;
      if (seconds != null) _elapsed = Duration(seconds: seconds);
      if (movingSeconds != null) _movingSeconds = movingSeconds;
    });

    if (_isRunning) _resyncDisplay();
    if (lat != null && lng != null) _moveMap(ll.LatLng(lat, lng));
  }

  /// Outdoor: movement-based (only time spent actually moving counts).
  /// Indoor: the service counts all elapsed time, so it's duration-based.
  double get _liveCalories {
    if (_selectedType == null) return 0;
    final minutes = _movingSeconds / 60;
    return minutes * _selectedType!.caloriesPerMinute;
  }

  String get _paceLabel {
    return '${UnitFormatter.formatPace(
      distanceMeters: _totalDistanceMeters,
      elapsed: _displayElapsed,
    )} ${UnitFormatter.paceUnitLabel}';
  }

  Future<void> _initForegroundTaskOptions() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'fittrack_tracking',
        channelName: 'Tracking Aktivitas',
        channelDescription:
            'Menampilkan status aktivitas yang sedang berlangsung',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(3000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<bool> _ensurePermissions() async {
    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Indoor types never touch location, so there's nothing else to ask.
    if (!_usesMap) return true;

    final foregroundOk = await _ensureForegroundLocationPermission();
    if (!foregroundOk) return false;

    // Background location so tracking keeps running once minimized/closed.
    final bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) {
      setState(() => _locationError =
          'Aktifkan izin lokasi "Allow all the time" di pengaturan HP biar tracking jalan di background');
      return false;
    }
    return true;
  }

  Future<void> _start() async {
    if (_selectedType == null) return;
    final granted = await _ensurePermissions();
    if (!granted) return;
    if (!mounted) return;
    final countdown = SettingsService.instance.countdownSeconds;
    if (countdown > 0) {
      final shouldStart = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _CountdownDialog(seconds: countdown),
      );
      if (shouldStart != true) return;
    }

    await _initForegroundTaskOptions();

    _startedAt ??= DateTime.now();
    final settings = SettingsService.instance;
    _autoPauseSession = settings.autoPause;

    await FlutterForegroundTask.saveData(
        key: 'accumulatedSeconds', value: _elapsed.inSeconds);
    await FlutterForegroundTask.saveData(
        key: 'accumulatedDistance', value: _totalDistanceMeters);
    await FlutterForegroundTask.saveData(
        key: 'accumulatedMovingSeconds', value: _movingSeconds);
    await FlutterForegroundTask.saveData(
        key: 'activityTypeId', value: _selectedType!.id!);
    await FlutterForegroundTask.saveData(
        key: 'activityTypeName', value: _selectedType!.name);
    await FlutterForegroundTask.saveData(key: 'usesGps', value: _usesMap);
    await FlutterForegroundTask.saveData(
      key: 'autoPause',
      value: settings.autoPause,
    );
    await FlutterForegroundTask.saveData(
      key: 'notificationEnabled',
      value: settings.ongoingNotificationEnabled,
    );
    await FlutterForegroundTask.saveData(
      key: 'distanceMiles',
      value: settings.distanceUnit == DistanceUnit.mile,
    );
    await FlutterForegroundTask.saveData(
      key: 'gpsAccuracy',
      value: settings.gpsAccuracy.name,
    );
    await FlutterForegroundTask.saveData(
        key: 'sessionStartedAt', value: _startedAt!.toIso8601String());
    await FlutterForegroundTask.saveData(key: 'sessionActive', value: true);

    await FlutterForegroundTask.startService(
      notificationTitle: settings.ongoingNotificationEnabled
          ? 'FitTrack \u2014 ${_selectedType!.name} berlangsung'
          : 'FitTrack',
      notificationText: settings.ongoingNotificationEnabled
          ? _usesMap
              ? 'Menyiapkan GPS...'
              : 'Timer berjalan'
          : 'Sesi olahraga sedang berlangsung',
      callback: startTrackingCallback,
    );

    setState(() => _isRunning = true);
    _startUiTicker();
  }

  Future<void> _pause() async {
    await FlutterForegroundTask.stopService();
    _stopUiTicker();
    setState(() => _isRunning = false);
  }

  Future<void> _finish() async {
    if (_selectedType == null) return;
    if (_isRunning) await FlutterForegroundTask.stopService();
    _stopUiTicker();
    if (_elapsed.inSeconds < 1) return;

    setState(() => _saving = true);

    final durationMinutes = (_elapsed.inSeconds / 60).round().clamp(1, 999999);

    final activity = Activity(
      userId: widget.userId,
      activityTypeId: _selectedType!.id!,
      durationMinutes: durationMinutes,
      caloriesBurned: _liveCalories,
      date: _startedAt ?? DateTime.now(),
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    final activityId = await _db.insertActivity(activity);
    if (_routePoints.isNotEmpty) {
      await _db.insertRoutePoints(activityId, _routePoints);
    }
    await NotificationService.instance.checkGoalAchievement(widget.userId);

    // Fire-and-forget: app must keep working fully offline, so this never
    // blocks navigation or shows an error if there's no connection.
    SyncService.instance.syncActivity(
      localActivityId: activityId,
      activity: activity,
      activityTypeName: _selectedType!.name,
      routePoints: _routePoints,
    );

    await FlutterForegroundTask.saveData(key: 'sessionActive', value: false);

    if (mounted) Navigator.pop(context, true);
  }

  void _leave() => Navigator.pop(context, _hasProgress);

  void _recenter() {
    if (_currentLatLng != null) _moveMap(_currentLatLng!, 17);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    SettingsService.instance.removeListener(_settingsChanged);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _uiTicker?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final style = _selectedType != null
        ? styleForActivity(_selectedType!.name)
        : const ActivityStyle(Icons.sports, Colors.teal);
    final started = _hasProgress;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: _selectedType?.name ?? 'Aktivitas Langsung',
                style: style,
                onBack: _leave,
              ),
              Expanded(
                child: _usesMap
                    ? _buildMapArea(style, started)
                    : _buildFocusArea(style, started),
              ),
              _buildBottomPanel(style, started),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Outdoor: map ----------

  Widget _buildMapArea(ActivityStyle style, bool started) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLatLng ?? const ll.LatLng(-6.2, 106.816),
            initialZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://basemaps.cartocdn.com/rastertiles/${context.isDark ? 'dark' : 'light'}_nolabels/{z}/{x}/{y}.png?key=$_cartoKey',
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
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.3),
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

        // Locked: the type was chosen on step 1.
        if (!started)
          Positioned(
            top: 12,
            left: 12,
            child: _TypePill(style: style, name: _selectedType?.name ?? ''),
          ),

        if (_isRunning)
          const Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _BackgroundActiveBadge(),
          ),

        Positioned(
          right: 12,
          bottom: 12,
          child: _RoundIconButton(icon: Icons.my_location, onTap: _recenter),
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
    );
  }

  // ---------- Indoor: time focus ----------

  Widget _buildFocusArea(ActivityStyle style, bool started) {
    final elapsed = _displayElapsed;
    final progress = started ? (elapsed.inSeconds % 60) / 60 : 0.0;
    final rate = _selectedType?.caloriesPerMinute ?? 0;
    final rateText =
        rate % 1 == 0 ? rate.toStringAsFixed(0) : rate.toStringAsFixed(1);

    final Color? dotColor = _isRunning
        ? const Color(0xFF4ADE80)
        : (started ? const Color(0xFFFBBF24) : null);

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.9,
          colors: [style.color.withValues(alpha: 0.10), Colors.transparent],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FocusTypeChip(style: style, name: _selectedType?.name ?? ''),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(220, 220),
                      painter:
                          _RingPainter(progress: progress, color: style.color),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (dotColor != null) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    color: dotColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text('Durasi',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: context.colors.inkSoft)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(elapsed),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _MiniStat(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Kalori',
                    value: '${_liveCalories.toStringAsFixed(0)} kcal',
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    icon: Icons.bolt_outlined,
                    label: 'Laju',
                    value: '$rateText /mnt',
                  ),
                  const SizedBox(width: 8),
                  _MiniStat(
                    icon: Icons.schedule,
                    label: 'Mulai',
                    value: _startedAt != null
                        ? DateFormat('HH:mm').format(_startedAt!)
                        : '--:--',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Kalori dihitung dari durasi (tanpa GPS)',
                style: TextStyle(fontSize: 10.5, color: context.colors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Shared bottom panel ----------

  Widget _buildBottomPanel(ActivityStyle style, bool started) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
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
          // Indoor types show these in the main area instead.
          if (_usesMap) ...[
            Row(
              children: [
                _Stat(
                    label: '\u23f1 Durasi',
                    value: _formatDuration(_displayElapsed)),
                const _StatDivider(),
                _Stat(label: '\u26a1 Pace', value: _paceLabel),
                const _StatDivider(),
                _Stat(
                  label: '\ud83d\udd25 Kalori',
                  value: _liveCalories.toStringAsFixed(0),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (!_isRunning && started) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.line),
              ),
              child: TextField(
                controller: _noteController,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Catatan (opsional)',
                  hintStyle: TextStyle(color: context.colors.inkSoft),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (!started)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _start,
                style: FilledButton.styleFrom(
                  backgroundColor: style.color,
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
                    onPressed: _saving ? null : (_isRunning ? _pause : _start),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: context.colors.line),
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
          const SizedBox(height: 10),
          const StepIndicator(step: 2),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final ActivityStyle style;
  final VoidCallback onBack;
  const _TopBar(
      {required this.title, required this.style, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: style.color.withValues(alpha: 0.15),
                  child: Icon(style.icon, color: style.color, size: 13),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Read-only: the type can't change here, go back to step 1 for that.
class _TypePill extends StatelessWidget {
  final ActivityStyle style;
  final String name;
  const _TypePill({required this.style, required this.name});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: style.color.withValues(alpha: 0.15),
              child: Icon(style.icon, color: style.color, size: 14),
            ),
            const SizedBox(width: 9),
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _FocusTypeChip extends StatelessWidget {
  final ActivityStyle style;
  final String name;
  const _FocusTypeChip({required this.style, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: style.color.withValues(alpha: 0.15),
            child: Icon(style.icon, color: style.color, size: 13),
          ),
          const SizedBox(width: 8),
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Circular progress for the current minute: starts empty at :00 and
/// closes up at :59, then begins again.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withValues(alpha: 0.15),
    );

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.max(sweep, 0.1),
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 11, color: context.colors.inkSoft),
                const SizedBox(width: 3),
                Text(label,
                    style:
                        TextStyle(fontSize: 10, color: context.colors.inkSoft)),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundActiveBadge extends StatelessWidget {
  const _BackgroundActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active, color: Colors.white, size: 13),
            SizedBox(width: 6),
            Text('Tetap tracking walau app ditutup',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
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
      color: context.colors.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: context.colors.ink),
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
              style: TextStyle(fontSize: 10.5, color: context.colors.inkSoft)),
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
    return Container(width: 1, height: 30, color: context.colors.line);
  }
}

class _CountdownDialog extends StatefulWidget {
  final int seconds;

  const _CountdownDialog({required this.seconds});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int _remaining = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Bersiap'),
        content: Text(
          'Aktivitas dimulai dalam $_remaining detik',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
        ],
      );
}
