import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../../main.dart' show kLocalUserIdKey, themeController;
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../services/pull_sync_service.dart';
import '../../services/settings_service.dart';
import '../../services/sync_service.dart';
import 'settings_sections.dart';
import '../auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  final int userId;

  const SettingsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _database = DatabaseHelper.instance;
  final _settings = SettingsService.instance;

  String _version = '...';
  int _pendingCount = 0;
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _settings.initialize();
      final values = await Future.wait([
        _database.getPendingActivitiesByUser(widget.userId),
        PackageInfo.fromPlatform(),
      ]);
      final pending = values[0] as List<Activity>;
      final package = values[1] as PackageInfo;
      if (!mounted) return;
      setState(() {
        _pendingCount = pending.length;
        _version = '${package.version}+${package.buildNumber}';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Pengaturan gagal dimuat: $error';
        _loading = false;
      });
    }
  }

  Future<void> _changeDistanceUnit(DistanceUnit unit) async {
    await _settings.setDistanceUnit(unit);
    await _updateActiveTaskData(
      'distanceMiles',
      unit == DistanceUnit.mile,
    );
  }

  Future<void> _setOngoingNotification(bool enabled) async {
    await _settings.setOngoingNotificationEnabled(enabled);
    await _updateActiveTaskData('notificationEnabled', enabled);
  }

  Future<void> _updateActiveTaskData<T extends Object>(
      String key, T value) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.saveData(key: key, value: value);
    }
  }

  Future<void> _changeTheme(ThemePreference preference) async {
    await _settings.setThemePreference(preference);
    themeController.setManualMode(switch (preference) {
      ThemePreference.automatic => null,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    });
  }

  Future<void> _setDailyReminder(bool enabled) async {
    if (enabled && !await Permission.notification.request().isGranted) {
      _showMessage('Izin notifikasi diperlukan untuk pengingat harian.');
      return;
    }
    await _settings.setDailyReminder(
      enabled: enabled,
      hour: _settings.reminderHour,
      minute: _settings.reminderMinute,
    );
    await NotificationService.instance.updateDailyReminder();
  }

  Future<void> _setGoalNotification(bool enabled) async {
    if (enabled && !await Permission.notification.request().isGranted) {
      _showMessage('Izin notifikasi diperlukan untuk pemberitahuan target.');
      return;
    }
    await _settings.setGoalNotificationEnabled(enabled);
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.reminderHour,
        minute: _settings.reminderMinute,
      ),
      helpText: 'Pilih waktu pengingat',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (selected == null) return;
    await _settings.setDailyReminder(
      enabled: _settings.dailyReminderEnabled,
      hour: selected.hour,
      minute: selected.minute,
    );
    if (_settings.dailyReminderEnabled) {
      await NotificationService.instance.updateDailyReminder();
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      if (!await ApiClient.instance.isLoggedIn) {
        throw StateError('Silakan masuk ke akun untuk menyinkronkan data.');
      }
      await SyncService.instance.syncPendingActivities(widget.userId);
      final pulled =
          await PullSyncService.instance.pullActivities(widget.userId);
      if (!pulled) {
        throw StateError('Riwayat gagal diambil dari server.');
      }
      final pending = await _database.getPendingActivitiesByUser(widget.userId);
      if (pending.isEmpty) await _settings.recordSync(DateTime.now());
      if (!mounted) return;
      setState(() {
        _pendingCount = pending.length;
        _syncing = false;
      });
      _showMessage(
        pending.isEmpty
            ? 'Sinkronisasi selesai.'
            : 'Sinkronisasi selesai. ${pending.length} item masih menunggu.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _error = 'Sinkronisasi gagal: $error';
      });
    }
  }

  Future<void> _exportCsv() async {
    try {
      final activities = await _database.getActivitiesByUser(widget.userId);
      final types = await _database.getActivityTypes();
      final typeNames = {for (final type in types) type.id!: type.name};
      String cell(String value) => '"${value.replaceAll('"', '""')}"';
      final rows = <String>[
        'Tanggal,Aktivitas,Durasi (menit),Kalori,Catatan',
        for (final activity in activities)
          [
            cell(activity.date.toIso8601String()),
            cell(typeNames[activity.activityTypeId] ?? 'Aktivitas'),
            activity.durationMinutes,
            activity.caloriesBurned.toStringAsFixed(1),
            cell(activity.note ?? ''),
          ].join(','),
      ];
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(rows.join('\r\n'))),
            mimeType: 'text/csv',
            name: 'fittrack_riwayat.csv',
          ),
        ],
        subject: 'Riwayat FitTrack (CSV)',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Ekspor CSV gagal: $error');
    }
  }

  Future<void> _deleteLocalData() async {
    final confirmed = await _confirm(
      title: 'Hapus semua data lokal?',
      message:
          'Profil, riwayat, dan target lokal akan dihapus permanen. Kamu akan keluar dari perangkat ini; data akun di server tidak dihapus.',
      confirmLabel: 'Hapus data',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      final user = await _database.getUser(widget.userId);
      final avatarPath = user?.avatarPath;
      if (avatarPath != null) {
        final avatarFile = File(avatarPath);
        if (await avatarFile.exists()) await avatarFile.delete();
      }
      await _database.deleteUserData(widget.userId);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(kLocalUserIdKey);
      await ApiClient.instance.clearToken();
      await _settings.clearSyncMetadata();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Data lokal gagal dihapus: $error');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                confirmLabel,
                style: destructive
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
              ),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showPlaceholder(String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Belum tersedia'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );

  Future<void> _showHelp() => _showPlaceholder(
        'Informasi kontak bantuan belum dikonfigurasi.',
      );

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _settings,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('Pengaturan')),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null) ...[
                      Material(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    UnitsSettingsSection(
                      settings: _settings,
                      onDistanceChanged: _changeDistanceUnit,
                      onWeightChanged: _settings.setWeightUnit,
                      onPaceChanged: _settings.setPaceUnit,
                    ),
                    AppearanceSettingsSection(
                      value: _settings.themePreference,
                      onChanged: _changeTheme,
                    ),
                    NotificationSettingsSection(
                      settings: _settings,
                      onReminderChanged: _setDailyReminder,
                      onPickReminderTime: _pickReminderTime,
                      onGoalChanged: _setGoalNotification,
                      onOngoingChanged: _setOngoingNotification,
                    ),
                    TrackingSettingsSection(
                      settings: _settings,
                      onAutoPauseChanged: _settings.setAutoPause,
                      onGpsAccuracyChanged: _settings.setGpsAccuracy,
                      onCountdownChanged: _settings.setCountdownSeconds,
                    ),
                    SyncSettingsSection(
                      settings: _settings,
                      pendingCount: _pendingCount,
                      syncing: _syncing,
                      onSync: _syncNow,
                      onWifiOnlyChanged: _settings.setWifiOnlySync,
                    ),
                    DataSettingsSection(
                      onExport: _exportCsv,
                      onDelete: _deleteLocalData,
                    ),
                    const PermissionsSettingsSection(),
                    AboutSettingsSection(version: _version, onHelp: _showHelp),
                  ],
                ),
        ),
      );
}
