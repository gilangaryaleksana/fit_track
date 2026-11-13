import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/settings_service.dart';
import '../../theme/app_colors.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 19, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}

class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: onChanged,
      );
}

class SettingsSelectionTile<T> extends StatelessWidget {
  final String title;
  final String? subtitle;
  final T value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  const SettingsSelectionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          items: [
            for (final option in values)
              DropdownMenuItem(value: option, child: Text(labelFor(option))),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

class ProfileSettingsSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController initialsController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final WeightUnit weightUnit;
  final String? birthDate;
  final String? gender;
  final VoidCallback onPickBirthDate;
  final ValueChanged<String?> onGenderChanged;
  final VoidCallback onSave;
  final bool saving;

  const ProfileSettingsSection({
    super.key,
    required this.nameController,
    required this.initialsController,
    required this.heightController,
    required this.weightController,
    required this.weightUnit,
    required this.birthDate,
    required this.gender,
    required this.onPickBirthDate,
    required this.onGenderChanged,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Data Diri',
        icon: Icons.person_outline,
        children: [
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nama'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: initialsController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
              decoration: const InputDecoration(
                labelText: 'Inisial avatar',
                helperText: 'Kosongkan untuk memakai inisial nama',
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tinggi (cm)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        'Berat (${weightUnit == WeightUnit.kilogram ? 'kg' : 'lb'})',
                  ),
                ),
              ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tanggal lahir'),
            subtitle: Text(birthDate ?? 'Belum diatur'),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: onPickBirthDate,
          ),
          DropdownButtonFormField<String>(
            initialValue: gender,
            decoration: const InputDecoration(labelText: 'Jenis kelamin'),
            items: const [
              DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
              DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
              DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
              DropdownMenuItem(
                  value: 'Tidak ingin menyebutkan',
                  child: Text('Tidak ingin menyebutkan')),
            ],
            onChanged: onGenderChanged,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan profil'),
            ),
          ),
        ],
      );
}

class UnitsSettingsSection extends StatelessWidget {
  final SettingsService settings;
  final ValueChanged<DistanceUnit> onDistanceChanged;
  final ValueChanged<WeightUnit> onWeightChanged;
  final ValueChanged<PaceUnit> onPaceChanged;

  const UnitsSettingsSection({
    super.key,
    required this.settings,
    required this.onDistanceChanged,
    required this.onWeightChanged,
    required this.onPaceChanged,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Satuan',
        icon: Icons.straighten,
        children: [
          SettingsSelectionTile(
            title: 'Jarak',
            value: settings.distanceUnit,
            values: DistanceUnit.values,
            labelFor: (v) => v == DistanceUnit.kilometer ? 'km' : 'mil',
            onChanged: onDistanceChanged,
          ),
          SettingsSelectionTile(
            title: 'Berat',
            value: settings.weightUnit,
            values: WeightUnit.values,
            labelFor: (v) => v == WeightUnit.kilogram ? 'kg' : 'lb',
            onChanged: onWeightChanged,
          ),
          SettingsSelectionTile(
            title: 'Pace',
            value: settings.paceUnit,
            values: PaceUnit.values,
            labelFor: (v) =>
                v == PaceUnit.minutePerKilometer ? 'menit/km' : 'menit/mil',
            onChanged: onPaceChanged,
          ),
        ],
      );
}

class AppearanceSettingsSection extends StatelessWidget {
  final ThemePreference value;
  final ValueChanged<ThemePreference> onChanged;

  const AppearanceSettingsSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Tampilan',
        icon: Icons.dark_mode_outlined,
        children: [
          SettingsSelectionTile(
            title: 'Tema',
            value: value,
            values: ThemePreference.values,
            labelFor: (v) => switch (v) {
              ThemePreference.automatic => 'Otomatis',
              ThemePreference.light => 'Terang',
              ThemePreference.dark => 'Gelap',
            },
            onChanged: onChanged,
          ),
          Text(
            'Mode otomatis mengikuti sensor cahaya. Peta mengikuti tema aplikasi.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.inkSoft,
                ),
          ),
        ],
      );
}

class NotificationSettingsSection extends StatelessWidget {
  final SettingsService settings;
  final ValueChanged<bool> onReminderChanged;
  final VoidCallback onPickReminderTime;
  final ValueChanged<bool> onGoalChanged;
  final ValueChanged<bool> onOngoingChanged;

  const NotificationSettingsSection({
    super.key,
    required this.settings,
    required this.onReminderChanged,
    required this.onPickReminderTime,
    required this.onGoalChanged,
    required this.onOngoingChanged,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Notifikasi',
        icon: Icons.notifications_outlined,
        children: [
          SettingsSwitchTile(
            title: 'Pengingat olahraga harian',
            value: settings.dailyReminderEnabled,
            onChanged: onReminderChanged,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Waktu pengingat'),
            subtitle: Text(
              '${settings.reminderHour.toString().padLeft(2, '0')}:'
              '${settings.reminderMinute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.schedule),
            onTap: onPickReminderTime,
          ),
          SettingsSwitchTile(
            title: 'Target tercapai',
            value: settings.goalNotificationEnabled,
            onChanged: onGoalChanged,
          ),
          SettingsSwitchTile(
            title: 'Notifikasi sesi berlangsung',
            subtitle: 'Saat dimatikan, notifikasi minimum layanan tetap aktif.',
            value: settings.ongoingNotificationEnabled,
            onChanged: onOngoingChanged,
          ),
        ],
      );
}

class TrackingSettingsSection extends StatelessWidget {
  final SettingsService settings;
  final ValueChanged<bool> onAutoPauseChanged;
  final ValueChanged<GpsAccuracy> onGpsAccuracyChanged;
  final ValueChanged<int> onCountdownChanged;

  const TrackingSettingsSection({
    super.key,
    required this.settings,
    required this.onAutoPauseChanged,
    required this.onGpsAccuracyChanged,
    required this.onCountdownChanged,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Tracking',
        icon: Icons.gps_fixed,
        children: [
          SettingsSwitchTile(
            title: 'Jeda otomatis saat diam',
            subtitle: 'Berlaku untuk sesi berikutnya.',
            value: settings.autoPause,
            onChanged: onAutoPauseChanged,
          ),
          SettingsSelectionTile(
            title: 'Akurasi GPS',
            subtitle: 'Berlaku untuk sesi berikutnya.',
            value: settings.gpsAccuracy,
            values: GpsAccuracy.values,
            labelFor: (v) => switch (v) {
              GpsAccuracy.batterySaver => 'Hemat baterai',
              GpsAccuracy.balanced => 'Seimbang',
              GpsAccuracy.precise => 'Presisi',
            },
            onChanged: onGpsAccuracyChanged,
          ),
          SettingsSelectionTile<int>(
            title: 'Hitung mundur sebelum mulai',
            value: settings.countdownSeconds,
            values: const [0, 3, 5],
            labelFor: (v) => v == 0 ? 'Mati' : '$v detik',
            onChanged: onCountdownChanged,
          ),
        ],
      );
}

class SyncSettingsSection extends StatelessWidget {
  final SettingsService settings;
  final int pendingCount;
  final bool syncing;
  final VoidCallback onSync;
  final ValueChanged<bool> onWifiOnlyChanged;

  const SyncSettingsSection({
    super.key,
    required this.settings,
    required this.pendingCount,
    required this.syncing,
    required this.onSync,
    required this.onWifiOnlyChanged,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Sinkronisasi',
        icon: Icons.sync,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sinkronisasi terakhir'),
            subtitle: Text(
              settings.lastSyncAt == null
                  ? 'Belum pernah'
                  : '${settings.lastSyncAt!.toLocal().day.toString().padLeft(2, '0')}/'
                      '${settings.lastSyncAt!.toLocal().month.toString().padLeft(2, '0')}/'
                      '${settings.lastSyncAt!.toLocal().year} '
                      '${settings.lastSyncAt!.toLocal().hour.toString().padLeft(2, '0')}:'
                      '${settings.lastSyncAt!.toLocal().minute.toString().padLeft(2, '0')}',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Item menunggu'),
            trailing: Text('$pendingCount'),
          ),
          SettingsSwitchTile(
            title: 'Sinkronkan hanya melalui Wi-Fi',
            value: settings.wifiOnlySync,
            onChanged: onWifiOnlyChanged,
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: syncing ? null : onSync,
              icon: syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: const Text('Sinkronkan sekarang'),
            ),
          ),
        ],
      );
}

class DataSettingsSection extends StatelessWidget {
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const DataSettingsSection({
    super.key,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Data',
        icon: Icons.storage_outlined,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Ekspor riwayat sebagai CSV'),
            onTap: onExport,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              'Hapus semua data lokal',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: onDelete,
          ),
        ],
      );
}

class AccountSettingsSection extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const AccountSettingsSection({
    super.key,
    required this.onChangePassword,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Akun',
        icon: Icons.manage_accounts_outlined,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ubah kata sandi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onChangePassword,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Keluar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onLogout,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Hapus akun',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onDeleteAccount,
          ),
        ],
      );
}

class PermissionsSettingsSection extends StatefulWidget {
  const PermissionsSettingsSection({super.key});

  @override
  State<PermissionsSettingsSection> createState() =>
      _PermissionsSettingsSectionState();
}

class _PermissionsSettingsSectionState
    extends State<PermissionsSettingsSection> {
  final Map<Permission, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final results = await Future.wait([
      Permission.locationWhenInUse.status,
      Permission.notification.status,
      Permission.activityRecognition.status,
    ]);
    if (!mounted) return;
    setState(() {
      _statuses[Permission.locationWhenInUse] = results[0];
      _statuses[Permission.notification] = results[1];
      _statuses[Permission.activityRecognition] = results[2];
    });
  }

  Future<void> _request(Permission permission) async {
    var status = _statuses[permission] ?? await permission.status;
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
    } else {
      status = await permission.request();
      if (status.isPermanentlyDenied || status.isRestricted) {
        await openAppSettings();
      }
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Izin',
        icon: Icons.security_outlined,
        children: [
          _permissionTile(
            context,
            Permission.locationWhenInUse,
            'Lokasi',
          ),
          _permissionTile(
            context,
            Permission.notification,
            'Notifikasi',
          ),
          _permissionTile(
            context,
            Permission.activityRecognition,
            'Aktivitas fisik',
          ),
        ],
      );

  Widget _permissionTile(
    BuildContext context,
    Permission permission,
    String title,
  ) {
    final status = _statuses[permission];
    final label = status == null
        ? 'Memeriksa...'
        : status.isGranted
            ? 'Diizinkan'
            : status.isPermanentlyDenied
                ? 'Ditolak permanen'
                : 'Belum diizinkan';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _request(permission),
    );
  }
}

class AboutSettingsSection extends StatelessWidget {
  final String version;
  final VoidCallback onHelp;

  const AboutSettingsSection({
    super.key,
    required this.version,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Tentang',
        icon: Icons.info_outline,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Versi aplikasi'),
            trailing: Text(version),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Peta'),
            subtitle: Text('© OpenStreetMap contributors'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bantuan & kontak'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onHelp,
          ),
        ],
      );
}

class SettingsValueError extends StatelessWidget {
  final String message;

  const SettingsValueError({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
}
