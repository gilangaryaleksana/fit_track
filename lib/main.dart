import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'db/database_helper.dart';
import 'models/models.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const HealthTrackerApp());
}

class HealthTrackerApp extends StatelessWidget {
  const HealthTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tracking Kesehatan',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2EC4B6),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const StartupScreen(),
    );
  }
}

// Checks if a user already exists (id = 1). If not, shows a quick
// profile setup form first. This app is single-user/local for simplicity.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  final _db = DatabaseHelper.instance;
  bool _loading = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final user = await _db.getUser(1);
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return ProfileSetupScreen(onDone: _checkUser);
    }
    return HomeScreen(userId: _user!.id!);
  }
}

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ProfileSetupScreen({super.key, required this.onDone});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _db = DatabaseHelper.instance;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await _db.insertUser(AppUser(
      name: _nameController.text,
      email: _emailController.text,
      heightCm: double.parse(_heightController.text),
      weightKg: double.parse(_weightController.text),
    ));
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lengkapi Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(labelText: 'Tinggi Badan (cm)'),
                keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v ?? '') == null
                    ? 'Harus berupa angka'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Berat Badan (kg)'),
                keyboardType: TextInputType.number,
                validator: (v) => double.tryParse(v ?? '') == null
                    ? 'Harus berupa angka'
                    : null,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Mulai')),
            ],
          ),
        ),
      ),
    );
  }
}