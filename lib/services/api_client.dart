import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when the backend returns a 4xx/5xx response. [errors] holds
/// Laravel's per-field validation messages when present (422 responses).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? errors;
  ApiException(this.statusCode, this.message, {this.errors});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  // Update this when the ngrok tunnel URL changes.
  static const String baseUrl = 'https://modified-outgrow-sasquatch.ngrok-free.dev/api';

  String? _token;

  Future<String?> get token async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<bool> get isLoggedIn async => (await token) != null;

  Map<String, String> get _jsonHeaders => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Future<Map<String, String>> _authHeaders() async {
    final t = await token;
    return {
      ..._jsonHeaders,
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  dynamic _handle(http.Response res) {
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    throw ApiException(
      res.statusCode,
      body is Map ? (body['message'] ?? 'Terjadi kesalahan') : 'Terjadi kesalahan',
      errors: body is Map ? body['errors'] as Map<String, dynamic>? : null,
    );
  }

  Map<String, dynamic> _parseProfile(dynamic value) {
    final profile = Map<String, dynamic>.from(value as Map);
    profile.remove('height');
    profile.remove('weight');
    profile['height_cm'] = num.tryParse(profile['height_cm'].toString());
    profile['weight_kg'] = num.tryParse(profile['weight_kg'].toString());
    final birthDate = profile['birth_date'] as String?;
    profile['birth_date'] =
        birthDate == null || birthDate.length < 10
            ? null
            : birthDate.substring(0, 10);
    return profile;
  }

  // ---------- AUTH ----------

  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    final data = _handle(res);
    await _saveToken(data['token']);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'login': login, 'password': password}),
    );
    final data = _handle(res);
    await _saveToken(data['token']);
    return data;
  }

  Future<void> logout() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: await _authHeaders(),
      );
      _handle(res);
    } finally {
      await clearToken();
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await http.get(Uri.parse('$baseUrl/me'), headers: await _authHeaders());
    return _parseProfile(_handle(res));
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    double? heightCm,
    double? weightKg,
    String? birthDate,
    String? gender,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (birthDate != null) 'birth_date': birthDate,
      if (gender != null) 'gender': gender,
    };
    final res = await http.put(
      Uri.parse('$baseUrl/profile'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    return _parseProfile(_handle(res));
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }),
    );
    return Map<String, dynamic>.from(_handle(res) as Map);
  }

  Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/account'),
      headers: await _authHeaders(),
      body: jsonEncode({'password': password}),
    );
    return Map<String, dynamic>.from(_handle(res) as Map);
  }

  // ---------- GENERIC AUTHENTICATED REQUESTS ----------
  // Reuse these for activities, activity-streams/bulk, follows, dst.

  Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl/$path'), headers: await _authHeaders());
    return _handle(res);
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl/$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/$path'),
      headers: await _authHeaders(),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  }
}