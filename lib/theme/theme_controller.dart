import 'dart:async';
import 'package:flutter/material.dart';
import 'package:light/light.dart';

/// Picks light or dark mode from the phone's ambient light sensor: dark in a
/// dark room, light when it's bright.
///
/// - Two thresholds (hysteresis) plus a short settle time, so a hand passing
///   over the sensor or a lamp flicker doesn't make the app flash.
/// - Falls back to the system setting ([ThemeMode.system]) until the first
///   reading arrives, and for good if there's no usable sensor.
/// - Stops listening while the app is in the background.
class ThemeController with WidgetsBindingObserver {
  /// Goes dark below this many lux (a dim room at night).
  static const double darkBelowLux = 20;

  /// Goes back to light above this many lux. Higher than [darkBelowLux] on
  /// purpose: readings in between keep whatever mode is active.
  static const double lightAboveLux = 60;

  /// A change only happens if the reading stays on the other side this long.
  static const Duration settleTime = Duration(seconds: 3);

  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  StreamSubscription<int>? _subscription;
  Timer? _settleTimer;
  double? _lastLux;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
    mode.dispose();
  }

  void _listen() {
    _subscription?.cancel();
    try {
      _subscription = Light().lightSensorStream.listen(
            _onLux,
            onError: (Object _) => _fallBackToSystem(),
            cancelOnError: false,
          );
    } catch (_) {
      // No light sensor, or a platform the plugin doesn't support.
      _fallBackToSystem();
    }
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _settleTimer?.cancel();
    _settleTimer = null;
  }

  void _fallBackToSystem() {
    _stopListening();
    mode.value = ThemeMode.system;
  }

  void _onLux(int lux) {
    _lastLux = lux.toDouble();

    // First reading: decide right away instead of waiting out the settle time.
    if (mode.value == ThemeMode.system) {
      const midpoint = (darkBelowLux + lightAboveLux) / 2;
      _apply(dark: _lastLux! < midpoint);
      return;
    }

    _evaluate();
  }

  bool _wantsDark(double lux, {required bool currentlyDark}) =>
      currentlyDark ? lux <= lightAboveLux : lux < darkBelowLux;

  void _evaluate() {
    final lux = _lastLux;
    if (lux == null) return;

    final isDark = mode.value == ThemeMode.dark;
    if (_wantsDark(lux, currentlyDark: isDark) == isDark) {
      // Back on the current side: forget the pending change.
      _settleTimer?.cancel();
      _settleTimer = null;
      return;
    }

    _settleTimer ??= Timer(settleTime, () {
      _settleTimer = null;
      final latest = _lastLux;
      if (latest == null) return;

      final nowDark = mode.value == ThemeMode.dark;
      final wantsDark = _wantsDark(latest, currentlyDark: nowDark);
      if (wantsDark != nowDark) _apply(dark: wantsDark);
    });
  }

  void _apply({required bool dark}) {
    final next = dark ? ThemeMode.dark : ThemeMode.light;
    if (mode.value != next) mode.value = next;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopListening();
    } else if (state == AppLifecycleState.resumed && _subscription == null) {
      _listen();
    }
  }
}