import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnit { kilometer, mile }

enum WeightUnit { kilogram, pound }

enum PaceUnit { minutePerKilometer, minutePerMile }

enum ThemePreference { automatic, light, dark }

enum GpsAccuracy { batterySaver, balanced, precise }

class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  SharedPreferences? _preferences;
  bool _initialized = false;

  DistanceUnit distanceUnit = DistanceUnit.kilometer;
  WeightUnit weightUnit = WeightUnit.kilogram;
  PaceUnit paceUnit = PaceUnit.minutePerKilometer;
  ThemePreference themePreference = ThemePreference.automatic;
  bool dailyReminderEnabled = false;
  int reminderHour = 7;
  int reminderMinute = 0;
  bool goalNotificationEnabled = true;
  bool ongoingNotificationEnabled = true;
  bool autoPause = false;
  GpsAccuracy gpsAccuracy = GpsAccuracy.balanced;
  int countdownSeconds = 0;
  bool wifiOnlySync = false;
  DateTime? lastSyncAt;

  Future<void> initialize() async {
    if (_initialized) return;
    _preferences = await SharedPreferences.getInstance();
    final prefs = _preferences!;
    distanceUnit = _enumValue(
      DistanceUnit.values,
      prefs.getString('settings.distanceUnit'),
      DistanceUnit.kilometer,
    );
    weightUnit = _enumValue(
      WeightUnit.values,
      prefs.getString('settings.weightUnit'),
      WeightUnit.kilogram,
    );
    paceUnit = _enumValue(
      PaceUnit.values,
      prefs.getString('settings.paceUnit'),
      PaceUnit.minutePerKilometer,
    );
    themePreference = _enumValue(
      ThemePreference.values,
      prefs.getString('settings.themePreference'),
      ThemePreference.automatic,
    );
    dailyReminderEnabled =
        prefs.getBool('settings.dailyReminderEnabled') ?? false;
    reminderHour = prefs.getInt('settings.reminderHour') ?? 7;
    reminderMinute = prefs.getInt('settings.reminderMinute') ?? 0;
    goalNotificationEnabled =
        prefs.getBool('settings.goalNotificationEnabled') ?? true;
    ongoingNotificationEnabled =
        prefs.getBool('settings.ongoingNotificationEnabled') ?? true;
    autoPause = prefs.getBool('settings.autoPause') ?? false;
    gpsAccuracy = _enumValue(
      GpsAccuracy.values,
      prefs.getString('settings.gpsAccuracy'),
      GpsAccuracy.balanced,
    );
    countdownSeconds = prefs.getInt('settings.countdownSeconds') ?? 0;
    wifiOnlySync = prefs.getBool('settings.wifiOnlySync') ?? false;
    final lastSync = prefs.getString('settings.lastSyncAt');
    lastSyncAt = lastSync == null ? null : DateTime.tryParse(lastSync);
    _initialized = true;
  }

  Future<void> setDistanceUnit(DistanceUnit value) async {
    distanceUnit = value;
    await _saveEnum('settings.distanceUnit', value);
  }

  Future<void> setWeightUnit(WeightUnit value) async {
    weightUnit = value;
    await _saveEnum('settings.weightUnit', value);
  }

  Future<void> setPaceUnit(PaceUnit value) async {
    paceUnit = value;
    await _saveEnum('settings.paceUnit', value);
  }

  Future<void> setThemePreference(ThemePreference value) async {
    themePreference = value;
    await _saveEnum('settings.themePreference', value);
  }

  Future<void> setDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    dailyReminderEnabled = enabled;
    reminderHour = hour;
    reminderMinute = minute;
    final prefs = await _prefs;
    await prefs.setBool('settings.dailyReminderEnabled', enabled);
    await prefs.setInt('settings.reminderHour', hour);
    await prefs.setInt('settings.reminderMinute', minute);
    notifyListeners();
  }

  Future<void> setGoalNotificationEnabled(bool value) =>
      _saveBool('settings.goalNotificationEnabled', value, (v) {
        goalNotificationEnabled = v;
      });

  Future<void> setOngoingNotificationEnabled(bool value) =>
      _saveBool('settings.ongoingNotificationEnabled', value, (v) {
        ongoingNotificationEnabled = v;
      });

  Future<void> setAutoPause(bool value) =>
      _saveBool('settings.autoPause', value, (v) => autoPause = v);

  Future<void> setGpsAccuracy(GpsAccuracy value) async {
    gpsAccuracy = value;
    await _saveEnum('settings.gpsAccuracy', value);
  }

  Future<void> setCountdownSeconds(int value) async {
    countdownSeconds = value;
    final prefs = await _prefs;
    await prefs.setInt('settings.countdownSeconds', value);
    notifyListeners();
  }

  Future<void> setWifiOnlySync(bool value) =>
      _saveBool('settings.wifiOnlySync', value, (v) => wifiOnlySync = v);

  Future<void> recordSync(DateTime dateTime) async {
    lastSyncAt = dateTime;
    final prefs = await _prefs;
    await prefs.setString('settings.lastSyncAt', dateTime.toIso8601String());
    notifyListeners();
  }

  Future<void> clearSyncMetadata() async {
    lastSyncAt = null;
    final prefs = await _prefs;
    await prefs.remove('settings.lastSyncAt');
    notifyListeners();
  }

  Future<SharedPreferences> get _prefs async {
    await initialize();
    return _preferences!;
  }

  Future<void> _saveEnum<T extends Enum>(String key, T value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value.name);
    notifyListeners();
  }

  Future<void> _saveBool(
    String key,
    bool value,
    void Function(bool) update,
  ) async {
    update(value);
    final prefs = await _prefs;
    await prefs.setBool(key, value);
    notifyListeners();
  }

  T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
