import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';
import '../widgets/step_indicator.dart';
import 'live_tracking_screen.dart';

/// Step 1 of "Aktivitas Langsung": pick the activity type first. The next
/// screen adapts to it (map + GPS for outdoor types, big timer for the rest).
class ActivityTypePickerScreen extends StatefulWidget {
  final int userId;
  const ActivityTypePickerScreen({super.key, required this.userId});

  @override
  State<ActivityTypePickerScreen> createState() =>
      _ActivityTypePickerScreenState();
}

class _ActivityTypePickerScreenState extends State<ActivityTypePickerScreen> {
  final _db = DatabaseHelper.instance;
  List<ActivityType> _types = [];
  ActivityType? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await _db.getActivityTypes();
    if (!mounted) return;
    setState(() {
      _types = types;
      _selected = types.isNotEmpty ? types.first : null;
    });
  }

  Future<void> _continue() async {
    if (_selected == null) return;

    // The tracking screen pops with `true` when the whole flow is over
    // (activity saved, or a session is already running in the background),
    // so we close this step too and land back on Home.
    final leaveFlow = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          userId: widget.userId,
          initialType: _selected,
        ),
      ),
    );
    if (leaveFlow == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas Langsung')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Mau olahraga apa?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              const Text(
                'Pilih salah satu buat lanjut ke tracking',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF5B6B69)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _types.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.95,
                        children: [
                          for (final type in _types)
                            _TypeCard(
                              type: type,
                              selected: _selected?.id == type.id,
                              onTap: () => setState(() => _selected = type),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _selected == null ? null : _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2EC4B6),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('Lanjut ke Tracking \u2192'),
              ),
              const SizedBox(height: 12),
              const StepIndicator(step: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final ActivityType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard(
      {required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = styleForActivity(type.name);

    return Material(
      color: selected ? const Color(0xFFEAF7F6) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFF2EC4B6) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: style.color.withValues(alpha: 0.15),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                type.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    style.usesMap ? Icons.place_outlined : Icons.timer_outlined,
                    size: 11,
                    color: const Color(0xFF5B6B69),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    style.usesMap ? 'Pakai peta' : 'Fokus waktu',
                    style:
                        const TextStyle(fontSize: 10, color: Color(0xFF5B6B69)),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 3),
                const Text(
                  '\u2713 Dipilih',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B9AAA),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
