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
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2EC4B6), Color(0xFF1B9AAA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2EC4B6).withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  _isRegister ? 'Buat Akun FitTrack' : 'Masuk ke FitTrack',
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 22),
                if (_isRegister) const _RegisterForm() else const _LoginForm(),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar',
                    style: const TextStyle(
                        color: Color(0xFF1B9AAA), fontWeight: FontWeight.w600),
                  ),
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

/// Field style shared across the app: white rounded box, icon badge,
/// teal border on focus. Manages its own FocusNode so callers don't need
/// external boilerplate.
class _StyledTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_StyledTextField> createState() => _StyledTextFieldState();
}

class _StyledTextFieldState extends State<_StyledTextField> {
  final _focusNode = FocusNode();
  late bool _obscured = widget.obscureText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            widget.label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5B6B69)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isFocused ? const Color(0xFF2EC4B6) : const Color(0xFFE4EAE9),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor:
                    const Color(0xFF2EC4B6).withValues(alpha: 0.12),
                child:
                    Icon(widget.icon, size: 14, color: const Color(0xFF1B9AAA)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText && _obscured,
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: const TextStyle(color: Color(0xFFA7B3B1)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (widget.obscureText)
                GestureDetector(
                  onTap: () => setState(() => _obscured = !_obscured),
                  child: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 16,
                    color: const Color(0xFFB7C2C0),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
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
      await _enterAppWithServerUser(
          context, data['user'] as Map<String, dynamic>);
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
          _StyledTextField(
            controller: _loginController,
            label: 'Email atau Username',
            icon: Icons.person_outline,
            hint: 'gilang',
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 14),
          _StyledTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            hint: '••••••••',
            obscureText: true,
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2EC4B6)),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
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
          _StyledTextField(
            controller: _nameController,
            label: 'Nama',
            icon: Icons.badge_outlined,
            hint: 'Gilang Arya',
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 14),
          _StyledTextField(
            controller: _usernameController,
            label: 'Username',
            icon: Icons.alternate_email,
            hint: 'gilang',
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 14),
          _StyledTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.mail_outline,
            hint: 'nama@email.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 14),
          _StyledTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            hint: 'min. 8 karakter',
            obscureText: true,
            validator: (v) =>
                v == null || v.length < 8 ? 'Minimal 8 karakter' : null,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StyledTextField(
                  controller: _heightController,
                  label: 'Tinggi (cm)',
                  icon: Icons.straighten,
                  hint: '170',
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Angka' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StyledTextField(
                  controller: _weightController,
                  label: 'Berat (kg)',
                  icon: Icons.monitor_weight_outlined,
                  hint: '65',
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      double.tryParse(v ?? '') == null ? 'Angka' : null,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12.5)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2EC4B6)),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Daftar'),
          ),
        ],
      ),
    );
  }
}
