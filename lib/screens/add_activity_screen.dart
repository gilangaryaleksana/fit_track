import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../utils/activity_style.dart';

class AddActivityScreen extends StatefulWidget {
  final int userId;
  const AddActivityScreen({super.key, required this.userId});

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  List<ActivityType> _types = [];
  ActivityType? _selectedType;
  final _durationController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    final types = await _db.getActivityTypes();
    setState(() {
      _types = types;
      _selectedType = types.isNotEmpty ? types.first : null;
    });
  }

  Future<void> _pickActivityType() async {
    final result = await showModalBottomSheet<ActivityType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ActivityTypeSheet(
        types: _types,
        selected: _selectedType,
      ),
    );
    if (result != null) setState(() => _selectedType = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedType == null) return;

    setState(() => _saving = true);
    final duration = int.parse(_durationController.text);
    final calories = duration * _selectedType!.caloriesPerMinute;

    final activity = Activity(
      userId: widget.userId,
      activityTypeId: _selectedType!.id!,
      durationMinutes: duration,
      caloriesBurned: calories,
      date: DateTime.now(),
      note: _noteController.text.isEmpty ? null : _noteController.text,
    );

    await _db.insertActivity(activity);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final style = _selectedType != null
        ? styleForActivity(_selectedType!.name)
        : const ActivityStyle(Icons.sports, Colors.teal);

    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Aktivitas')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Center(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('Jenis Aktivitas'),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _pickActivityType,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE4EAE9)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor:
                                    style.color.withValues(alpha: 0.15),
                                child: Icon(style.icon,
                                    color: style.color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedType?.name ?? 'Pilih jenis',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFFB7C2C0)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Durasi (menit)'),
                      TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(hintText: 'contoh: 30'),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Wajib diisi';
                          if (int.tryParse(value) == null)
                            return 'Harus berupa angka';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Catatan (opsional)'),
                      TextFormField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                            hintText: 'contoh: lari sore'),
                      ),
                      const SizedBox(height: 30),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2EC4B6),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Simpan'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5B6B69),
        ),
      ),
    );
  }
}

class _ActivityTypeSheet extends StatelessWidget {
  final List<ActivityType> types;
  final ActivityType? selected;
  const _ActivityTypeSheet({required this.types, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4EAE9),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            for (final type in types)
              InkWell(
                onTap: () => Navigator.pop(context, type),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: selected?.id == type.id
                      ? const Color(0xFFEAF7F6)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: styleForActivity(type.name)
                            .color
                            .withValues(alpha: 0.15),
                        child: Icon(
                          styleForActivity(type.name).icon,
                          color: styleForActivity(type.name).color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(type.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
