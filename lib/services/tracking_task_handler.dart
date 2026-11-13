import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import '../utils/unit_formatter.dart';

/// Minimum speed (m/s) to count a tick as "actually moving". Below this,
/// GPS drift while stationary is ignored so calories stop accruing.
const _movementThresholdMetersPerSecond = 0.5;

/// Runs in a background isolate kept alive by the Android foreground
/// service, so it keeps working even after the app is closed/minimized.
///
/// Two modes, chosen by the screen via the saved `usesGps` flag:
/// - GPS (outdoor): distance + movement-based active time.
/// - No GPS (swimming, yoga, gym): no location access at all; every tick
///   counts as active time, so calories become duration-based.
class TrackingTaskHandler extends TaskHandler {
  Position? _lastPosition;
  double _distanceMeters = 0;
  int _accumulatedSeconds = 0;
  int _movingSeconds = 0;
  bool _useGps = true;
  bool _autoPause = false;
  bool _notificationEnabled = true;
  bool _distanceMiles = false;
  LocationAccuracy _accuracy = LocationAccuracy.high;
  String _typeName = 'Aktivitas';
  DateTime? _tickStart;
  DateTime? _lastTickTime;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _accumulatedSeconds =
        (await FlutterForegroundTask.getData<int>(key: 'accumulatedSeconds')) ??
            0;
    _distanceMeters = (await FlutterForegroundTask.getData<double>(
            key: 'accumulatedDistance')) ??
        0;
    _movingSeconds = (await FlutterForegroundTask.getData<int>(
            key: 'accumulatedMovingSeconds')) ??
        0;
    _useGps =
        (await FlutterForegroundTask.getData<bool>(key: 'usesGps')) ?? true;
    _autoPause =
        (await FlutterForegroundTask.getData<bool>(key: 'autoPause')) ?? false;
    _notificationEnabled = (await FlutterForegroundTask.getData<bool>(
            key: 'notificationEnabled')) ??
        true;
    _distanceMiles =
        (await FlutterForegroundTask.getData<bool>(key: 'distanceMiles')) ??
            false;
    final accuracy =
        await FlutterForegroundTask.getData<String>(key: 'gpsAccuracy');
    _accuracy = switch (accuracy) {
      'batterySaver' => LocationAccuracy.low,
      'balanced' => LocationAccuracy.medium,
      _ => LocationAccuracy.high,
    };
    _typeName = (await FlutterForegroundTask.getData<String>(
            key: 'activityTypeName')) ??
        'Aktivitas';
    _tickStart = timestamp;
    _lastTickTime = timestamp;
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    try {
      final tickSeconds =
          timestamp.difference(_lastTickTime ?? timestamp).inSeconds;

      Position? position;
      var isMoving = !_useGps;
      if (_useGps) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(accuracy: _accuracy),
        );

        if (_lastPosition != null) {
          final deltaMeters = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          _distanceMeters += deltaMeters;

          // Only count this tick as "moving" if speed is above the noise
          // threshold, so standing still doesn't keep burning calories.
          final speed = tickSeconds > 0 ? deltaMeters / tickSeconds : 0;
          if (speed >= _movementThresholdMetersPerSecond) {
            _movingSeconds += tickSeconds;
            isMoving = true;
          }
        }
        _lastPosition = position;
      } else {
        // Nothing to detect movement with, so all elapsed time counts.
        _movingSeconds += tickSeconds;
      }
      _lastTickTime = timestamp;

      final elapsedSeconds = _autoPause && _useGps
          ? _accumulatedSeconds + (isMoving ? tickSeconds : 0)
          : _accumulatedSeconds + timestamp.difference(_tickStart!).inSeconds;
      if (_autoPause && _useGps) _accumulatedSeconds = elapsedSeconds;

      // Persist progress so the UI can restore it even after the app
      // process was killed and reopened while this service keeps running.
      await FlutterForegroundTask.saveData(
          key: 'accumulatedSeconds', value: elapsedSeconds);
      await FlutterForegroundTask.saveData(
          key: 'accumulatedDistance', value: _distanceMeters);
      await FlutterForegroundTask.saveData(
          key: 'accumulatedMovingSeconds', value: _movingSeconds);

      _notificationEnabled = await FlutterForegroundTask.getData<bool>(
              key: 'notificationEnabled') ??
          _notificationEnabled;
      _distanceMiles =
          await FlutterForegroundTask.getData<bool>(key: 'distanceMiles') ??
              _distanceMiles;
      final durationText = _formatDuration(elapsedSeconds);
      FlutterForegroundTask.updateService(
        notificationTitle: _notificationEnabled
            ? 'FitTrack \u2014 $_typeName berlangsung'
            : 'FitTrack',
        notificationText: _notificationEnabled
            ? _useGps
                ? '$durationText \u2022 ${UnitFormatter.formatDistanceWithUnit(_distanceMeters, useMiles: _distanceMiles)}'
                : durationText
            : 'Sesi olahraga sedang berlangsung',
      );

      FlutterForegroundTask.sendDataToMain({
        if (position != null) 'lat': position.latitude,
        if (position != null) 'lng': position.longitude,
        'distanceMeters': _distanceMeters,
        'elapsedSeconds': elapsedSeconds,
        'movingSeconds': _movingSeconds,
      });
    } catch (_) {
      // GPS fix not available this tick, try again next interval.
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  String _formatDuration(int totalSeconds) {
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

@pragma('vm:entry-point')
void startTrackingCallback() {
  FlutterForegroundTask.setTaskHandler(TrackingTaskHandler());
}
