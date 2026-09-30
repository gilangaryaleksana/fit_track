import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../main.dart' show kLocalUserIdKey;
import '../models/models.dart';
import '../services/api_client.dart';
import 'main_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isRegister = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fitness_center, size: 48, color: Color(0xFF2EC4B6)),
                const SizedBox(height: 12),
                Text(
                  _isRegister ? 'Buat Akun FitTrack' : 'Masuk ke FitTrack',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (_isRegister) const _RegisterForm() else const _LoginForm(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(_isRegister
                      ? 'Sudah punya akun? Masuk'
                      : 'Belum punya akun? Daftar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared after successful register/login: make sure a local SQLite user
/// row exists (the rest of the app is keyed off that local integer id),
/// remember it, then enter the app.
Future<void> _enterAppWithServerUser(
  BuildContext context,
  Map<String, dynamic> serverUser,
) async {
  final db = DatabaseHelper.instance;
  final email = serverUser['email'] as String;

  var localUser = await db.getUserByEmail(email);
  int localId;

  if (localUser == null) {
    localId = await db.insertUser(AppUser(
      name: serverUser['name'] as String,
      email: email,
      heightCm: (serverUser['height'] as num?)?.toDouble() ?? 0,
      weightKg: (serverUser['weight'] as num?)?.toDouble() ?? 0,
    ));
  } else {
    localId = localUser.id!;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(kLocalUserIdKey, localId);

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => MainNavigationScreen(userId: localId)),
    (route) => false,
  );
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.login(
        login: _loginController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      await _enterAppWithServerUser(context, data['user'] as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginController,
            decoration: const InputDecoration(labelText: 'Email atau Username'),
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Masuk'),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.register(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final serverUser = Map<String, dynamic>.from(data['user'] as Map);
      serverUser['height'] = double.tryParse(_heightController.text);
      serverUser['weight'] = double.tryParse(_weightController.text);

      if (!mounted) return;
      await _enterAppWithServerUser(context, serverUser);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nama'),
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password (min. 8 karakter)'),
            obscureText: true,
            validator: (v) =>
                v == null || v.length < 8 ? 'Minimal 8 karakter' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(labelText: 'Tinggi (cm)'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Angka' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(labelText: 'Berat (kg)'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Angka' : null,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Daftar'),
          ),
        ],
      ),
    );
  }
}