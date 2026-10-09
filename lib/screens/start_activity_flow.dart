import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'activity_type_picker_screen.dart';
import 'add_activity_screen.dart';
import 'live_tracking_screen.dart';

/// Opens the "how do you want to add it?" sheet, then the matching flow:
/// live tracking (type picker first) or the manual form. If a live session
/// is already running/paused, "live" resumes it instead of starting a second.
///
/// Completes once the user comes back, so callers can refresh their data.
Future<void> startActivityFlow(BuildContext context, int userId) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.timer, color: Color(0xFF2EC4B6)),
            title: const Text('Aktivitas Langsung'),
            subtitle: const Text('Timer & kalori berjalan real-time'),
            onTap: () => Navigator.pop(ctx, 'live'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Input Manual'),
            subtitle: const Text('Masukkan durasi setelah selesai'),
            onTap: () => Navigator.pop(ctx, 'manual'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return;

  final Widget target;
  if (choice == 'live') {
    final sessionActive =
        await FlutterForegroundTask.getData<bool>(key: 'sessionActive') ??
            false;
    target = sessionActive
        ? LiveTrackingScreen(userId: userId)
        : ActivityTypePickerScreen(userId: userId);
  } else {
    target = AddActivityScreen(userId: userId);
  }

  if (!context.mounted) return;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => target));
}
