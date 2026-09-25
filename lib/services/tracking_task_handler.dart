import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

/// Runs in a background isolate kept alive by the Android foreground
/// service, so it keeps working even after the app is closed/minimized.
class TrackingTaskHandler extends TaskHandler {
  Position? _lastPosition;
  double _distanceMeters = 0;
  int _accumulatedSeconds = 0;
  DateTime? _tickStart;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _accumulatedSeconds =
        (await FlutterForegroundTask.getData<int>(key: 'accumulatedSeconds')) ??
            0;
    _distanceMeters = (await FlutterForegroundTask.getData<double>(
            key: 'accumulatedDistance')) ??
        0;
    _tickStart = timestamp;
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (_lastPosition != null) {
        _distanceMeters += Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }
      _lastPosition = position;

      final elapsedSeconds =
          _accumulatedSeconds + timestamp.difference(_tickStart!).inSeconds;

      FlutterForegroundTask.updateService(
        notificationTitle: 'FitTrack \u2014 Aktivitas berlangsung',
        notificationText:
            '${_formatDuration(elapsedSeconds)} \u2022 ${(_distanceMeters / 1000).toStringAsFixed(2)} km',
      );

      FlutterForegroundTask.sendDataToMain({
        'lat': position.latitude,
        'lng': position.longitude,
        'distanceMeters': _distanceMeters,
        'elapsedSeconds': elapsedSeconds,
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
