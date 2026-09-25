import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';

class HistoryScreen extends StatefulWidget {
  final int userId;
  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseHelper.instance;
  List<Activity> _activities = [];
  Map<int, ActivityType> _typesById = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final activities = await _db.getActivitiesByUser(widget.userId);
    final types = await _db.getActivityTypes();
    setState(() {
      _activities = activities;
      _typesById = {for (final t in types) t.id!: t};
    });
  }

  Future<void> _delete(int id) async {
    await _db.deleteActivity(id);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Aktivitas')),
      body: _activities.isEmpty
          ? const Center(child: Text('Belum ada riwayat aktivitas'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _activities.length,
              itemBuilder: (context, index) {
                final activity = _activities[index];
                final type = _typesById[activity.activityTypeId];
                final style = styleForActivity(type?.name ?? '');
                return Dismissible(
                  key: Key(activity.id.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _delete(activity.id!),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: style.color.withValues(alpha: 0.15),
                        child: Icon(style.icon, color: style.color),
                      ),
                      title: Text(type?.name ?? 'Aktivitas'),
                      subtitle: Text(
                          '${activity.durationMinutes} menit • ${dateFormat.format(activity.date)}'),
                      trailing: Text(
                        '${activity.caloriesBurned.toStringAsFixed(0)} kcal',
                        style: TextStyle(
                            color: style.color, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
