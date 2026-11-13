import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../db/database_helper.dart';
import '../../models/models.dart';
import '../../services/settings_service.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_sections.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  final Future<void> Function() onLogout;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _database = DatabaseHelper.instance;
  final _settings = SettingsService.instance;
  final _nameController = TextEditingController();
  final _initialsController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  AppUser? _user;
  String? _birthDate;
  String? _gender;
  String? _avatarPath;
  int _activityCount = 0;
  double _totalCalories = 0;
  int _streak = 0;
  bool _loading = true;
  bool _saving = false;
  bool _updatingProfile = false;
  String? _error;
  late WeightUnit _weightUnit;

  @override
  void initState() {
    super.initState();
    _weightUnit = _settings.weightUnit;
    _settings.addListener(_settingsChanged);
    _nameController.addListener(_profileChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _settings.removeListener(_settingsChanged);
    _nameController.removeListener(_profileChanged);
    _nameController.dispose();
    _initialsController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _profileChanged() {
    if (mounted && !_updatingProfile) setState(() {});
  }

  void _settingsChanged() {
    final unit = _settings.weightUnit;
    if (unit != _weightUnit) {
      final weight = double.tryParse(_weightController.text.trim());
      if (weight != null) {
        final converted = unit == WeightUnit.pound
            ? weight * 2.2046226218
            : weight / 2.2046226218;
        _weightController.text = _formatNumber(converted);
      }
      _weightUnit = unit;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    try {
      await _settings.initialize();
      _weightUnit = _settings.weightUnit;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(today.year, today.month, today.day - 29);
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final user = await _database.getUser(widget.userId);
      final activities = await _database.getActivitiesByUser(widget.userId);
      final recentActivities = await _database.getActivitiesInRange(
        widget.userId,
        start,
        tomorrow,
      );
      final targets = await _database.getTargetsInRange(
        widget.userId,
        start,
        tomorrow,
      );

      final weight = user == null
          ? null
          : _weightUnit == WeightUnit.pound
              ? user.weightKg * 2.2046226218
              : user.weightKg;
      if (!mounted) return;
      _updatingProfile = true;
      setState(() {
        _user = user;
        if (user != null) {
          _nameController.text = user.name;
          _initialsController.text = user.avatarInitials ?? '';
          _heightController.text =
              user.heightCm == 0 ? '' : _formatNumber(user.heightCm);
          _weightController.text =
              user.weightKg == 0 ? '' : _formatNumber(weight!);
          _birthDate = user.birthDate;
          _gender = user.gender;
          _avatarPath = user.avatarPath;
        }
        _activityCount = activities.length;
        _totalCalories = activities.fold<double>(
          0,
          (total, activity) => total + activity.caloriesBurned,
        );
        _streak = _calculateStreak(recentActivities, targets, start, today);
        _loading = false;
      });
      _updatingProfile = false;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Profil gagal dimuat: $error';
        _loading = false;
      });
    }
  }

  int _calculateStreak(
    List<Activity> activities,
    List<DailyTarget> targets,
    DateTime start,
    DateTime today,
  ) {
    final totals = <DateTime, _DailyTotals>{};
    for (final activity in activities) {
      final day = DateTime(
        activity.date.year,
        activity.date.month,
        activity.date.day,
      );
      final total = totals.putIfAbsent(day, _DailyTotals.new);
      total.calories += activity.caloriesBurned;
      total.minutes += activity.durationMinutes;
    }

    final targetsByDay = <DateTime, DailyTarget>{
      for (final target in targets)
        DateTime(target.date.year, target.date.month, target.date.day): target,
    };
    final completedDays = <bool>[
      for (var index = 0; index < 30; index++)
        () {
          final day = DateTime(start.year, start.month, start.day + index);
          final target = targetsByDay[day];
          final total = totals[day];
          return target != null &&
              total != null &&
              total.calories >= target.targetCalories &&
              total.minutes >= target.targetDurationMinutes;
        }(),
    ];

    var cursor = completedDays.length - 1;
    if (!completedDays[cursor]) cursor--;
    var streak = 0;
    while (cursor >= 0 && completedDays[cursor]) {
      streak++;
      cursor--;
    }
    return streak;
  }

  String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  String _initialsFor(String name) {
    final customInitials = _initialsController.text.trim();
    if (customInitials.isNotEmpty) return customInitials.toUpperCase();
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => String.fromCharCode(part.runes.first).toUpperCase())
        .join();
  }

  Future<void> _saveProfile() async {
    final existing = _user;
    if (existing == null) {
      setState(() => _error = 'Data profil tidak ditemukan.');
      return;
    }
    final name = _nameController.text.trim();
    final height = double.tryParse(_heightController.text.trim());
    final enteredWeight = double.tryParse(_weightController.text.trim());
    final weightKg = enteredWeight == null
        ? null
        : _weightUnit == WeightUnit.pound
            ? enteredWeight / 2.2046226218
            : enteredWeight;
    if (name.isEmpty ||
        height == null ||
        !height.isFinite ||
        height < 50 ||
        height > 260 ||
        weightKg == null ||
        !weightKg.isFinite ||
        weightKg < 20 ||
        weightKg > 400) {
      setState(() {
        _error =
            'Isi nama, tinggi (50–260 cm), dan berat (20–400 kg) dengan benar.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = AppUser(
        id: existing.id,
        name: name,
        email: existing.email,
        heightCm: height,
        weightKg: weightKg,
        birthDate: _birthDate,
        gender: _gender,
        avatarInitials: _initialsController.text.trim().isEmpty
            ? null
            : _initialsController.text.trim().toUpperCase(),
        avatarPath: _avatarPath,
      );
      await _database.updateUser(updated);
      if (existing.avatarPath != null &&
          existing.avatarPath != updated.avatarPath) {
        final oldAvatar = File(existing.avatarPath!);
        if (await oldAvatar.exists()) await oldAvatar.delete();
      }
      if (!mounted) return;
      setState(() {
        _user = updated;
        _saving = false;
      });
      _showMessage('Profil berhasil disimpan.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Profil gagal disimpan: $error';
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (selected == null) return;
      final directory = await getApplicationDocumentsDirectory();
      final extension = path.extension(selected.path);
      final destination = path.join(
        directory.path,
        'fittrack_avatar_${widget.userId}${extension.isEmpty ? '.jpg' : extension}',
      );
      await File(destination)
          .writeAsBytes(await selected.readAsBytes(), flush: true);
      if (mounted) setState(() => _avatarPath = destination);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Foto profil gagal dipilih: $error');
    }
  }

  void _removeAvatar() => setState(() => _avatarPath = null);

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final current = _birthDate == null ? null : DateTime.tryParse(_birthDate!);
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (date != null) {
      setState(() => _birthDate = DateFormat('yyyy-MM-dd').format(date));
    }
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(userId: widget.userId),
      ),
    );
  }

  Future<void> _changePassword() async {
    // TODO: Connect this action when the backend exposes a password-change endpoint.
    await _showPlaceholder(
      'Perubahan kata sandi belum tersedia karena layanan backend belum mendukungnya.',
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _confirm(
      title: 'Hapus akun?',
      message:
          'Penghapusan akun belum tersedia. Tidak ada data yang akan dihapus.',
      confirmLabel: 'Lanjutkan',
      destructive: true,
    );
    if (!confirmed) return;
    // TODO: Use the backend account-deletion endpoint once it is available.
    await _showPlaceholder('Layanan penghapusan akun belum tersedia.');
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

  Future<void> _logout() => widget.onLogout();

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _settings,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Profil'),
            actions: [
              IconButton(
                tooltip: 'Pengaturan',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _user == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SettingsValueError(
                          message: _error ?? 'Data profil tidak ditemukan.',
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_error != null) ...[
                          _ErrorMessage(message: _error!),
                          const SizedBox(height: 12),
                        ],
                        _ProfileHeader(
                          name: _nameController.text,
                          initials: _initialsFor(_nameController.text),
                          avatarPath: _avatarPath,
                          onTap: _pickAvatar,
                          onRemove: _avatarPath == null ? null : _removeAvatar,
                        ),
                        const SizedBox(height: 12),
                        ProfileSettingsSection(
                          nameController: _nameController,
                          initialsController: _initialsController,
                          heightController: _heightController,
                          weightController: _weightController,
                          weightUnit: _weightUnit,
                          birthDate: _birthDate,
                          gender: _gender,
                          onPickBirthDate: _pickBirthDate,
                          onGenderChanged: (value) =>
                              setState(() => _gender = value),
                          onSave: _saveProfile,
                          saving: _saving,
                        ),
                        SettingsSection(
                          title: 'Ringkasan',
                          icon: Icons.insights_outlined,
                          children: [
                            _SummaryTile(
                              label: 'Total aktivitas',
                              value: '$_activityCount',
                              icon: Icons.directions_run_outlined,
                            ),
                            _SummaryTile(
                              label: 'Total kalori',
                              value:
                                  '${_totalCalories.toStringAsFixed(0)} kcal',
                              icon: Icons.local_fire_department_outlined,
                            ),
                            _SummaryTile(
                              label: 'Streak saat ini',
                              value: '$_streak hari',
                              icon: Icons.bolt_outlined,
                            ),
                            if (_activityCount == 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Belum ada aktivitas. Mulai olahraga untuk melihat ringkasanmu.',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        AccountSettingsSection(
                          onChangePassword: _changePassword,
                          onLogout: _logout,
                          onDeleteAccount: _deleteAccount,
                        ),
                      ],
                    ),
        ),
      );
}

class _DailyTotals {
  double calories = 0;
  int minutes = 0;
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String initials;
  final String? avatarPath;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _ProfileHeader({
    required this.name,
    required this.initials,
    required this.avatarPath,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath != null && File(avatarPath!).existsSync();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Ubah foto profil',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundImage:
                      hasAvatar ? FileImage(File(avatarPath!)) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          initials.isEmpty ? 'P' : initials,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.trim().isEmpty ? 'Pengguna' : name.trim(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ketuk foto untuk mengubah avatar',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'Hapus foto profil',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      );
}
