import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class TargetScreen extends StatefulWidget {
  final int userId;
  const TargetScreen({super.key, required this.userId});

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;
  final _caloriesController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesFocus = FocusNode();
  final _durationFocus = FocusNode();

  DailyTarget? _existingTarget;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _caloriesFocus.addListener(() => setState(() {}));
    _durationFocus.addListener(() => setState(() {}));
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final target = await _db.getTargetByDate(widget.userId, DateTime.now());
    if (target != null) {
      _caloriesController.text = target.targetCalories.toStringAsFixed(0);
      _durationController.text = target.targetDurationMinutes.toString();
    }
    setState(() => _existingTarget = target);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final target = DailyTarget(
      userId: widget.userId,
      targetCalories: double.parse(_caloriesController.text),
      targetDurationMinutes: int.parse(_durationController.text),
      date: DateTime.now(),
    );

    await _db.insertOrUpdateTarget(target);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _caloriesFocus.dispose();
    _durationFocus.dispose();
    super.dispose();
  }

  String get _todayLabel {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final now = DateTime.now();
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Target Harian')),
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
                      if (_existingTarget != null) ...[
                        _SummaryCard(
                          calories: _existingTarget!.targetCalories,
                          duration: _existingTarget!.targetDurationMinutes,
                        ),
                        const SizedBox(height: 24),
                      ],
                      const _FieldLabel('Target Kalori (kcal)'),
                      _StyledField(
                        controller: _caloriesController,
                        focusNode: _caloriesFocus,
                        icon: Icons.local_fire_department,
                        iconColor: const Color(0xFFFF8A3D),
                        unit: 'kcal',
                        hint: '680',
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Wajib diisi';
                          if (double.tryParse(value) == null)
                            return 'Harus berupa angka';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      const _FieldLabel('Target Durasi (menit)'),
                      _StyledField(
                        controller: _durationController,
                        focusNode: _durationFocus,
                        icon: Icons.timer,
                        iconColor: const Color(0xFF1B9AAA),
                        unit: 'menit',
                        hint: '60',
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Wajib diisi';
                          if (int.tryParse(value) == null)
                            return 'Harus berupa angka';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2EC4B6),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Simpan Target'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Target berlaku untuk hari ini, $_todayLabel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11.5, color: Color(0xFF5B6B69)),
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

class _SummaryCard extends StatelessWidget {
  final double calories;
  final int duration;
  const _SummaryCard({required this.calories, required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2EC4B6), Color(0xFF1B9AAA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2EC4B6).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.local_fire_department,
              label: 'Target Kalori',
              value: '${calories.toStringAsFixed(0)} kcal',
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white24),
          const SizedBox(width: 14),
          Expanded(
            child: _SummaryItem(
              icon: Icons.timer,
              label: 'Target Durasi',
              value: '$duration menit',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final Color iconColor;
  final String unit;
  final String hint;
  final String? Function(String?) validator;

  const _StyledField({
    required this.controller,
    required this.focusNode,
    required this.icon,
    required this.iconColor,
    required this.unit,
    required this.hint,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isFocused = focusNode.hasFocus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? const Color(0xFF2EC4B6) : const Color(0xFFE4EAE9),
          width: isFocused ? 1.5 : 1.5,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF2EC4B6).withValues(alpha: 0.12),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              validator: validator,
            ),
          ),
          Text(unit,
              style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B69))),
        ],
      ),
    );
  }
}
