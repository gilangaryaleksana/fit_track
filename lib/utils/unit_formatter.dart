import '../services/settings_service.dart';

class UnitFormatter {
  UnitFormatter._();

  static final SettingsService _settings = SettingsService.instance;

  static String formatDistance(double meters, {int decimals = 2}) {
    return formatDistanceWithUnit(
      meters,
      useMiles: _settings.distanceUnit == DistanceUnit.mile,
      decimals: decimals,
    );
  }

  static String formatDistanceWithUnit(
    double meters, {
    required bool useMiles,
    int decimals = 2,
  }) {
    if (useMiles) {
      return '${(meters / 1609.344).toStringAsFixed(decimals)} mil';
    }
    return '${(meters / 1000).toStringAsFixed(decimals)} km';
  }

  static String formatPace({
    required double distanceMeters,
    required Duration elapsed,
  }) {
    final useMiles = _settings.paceUnit == PaceUnit.minutePerMile;
    final distance =
        useMiles ? distanceMeters / 1609.344 : distanceMeters / 1000;
    if (distance < 0.02 || elapsed.inSeconds < 5) {
      return "\u2013'\u2013\u2013\"";
    }

    final paceMinutes = (elapsed.inSeconds / 60) / distance;
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  static String get paceUnitLabel =>
      _settings.paceUnit == PaceUnit.minutePerMile ? '/mil' : '/km';
}
