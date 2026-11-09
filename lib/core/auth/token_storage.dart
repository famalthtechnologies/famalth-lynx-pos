import 'dart:convert';

import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class TokenStorage {
  static const _key = 'auth_token';
  static const _roleKey = 'user_role';
  static const _permKey = 'user_permissions';
  static const _userKey = 'user_data';
  static const _sessionTimeKey = 'session_login_time';
  static const _serverUrlKey = 'client_authenticated_server_url';

  // In-memory synchronous cache to prevent asynchronous layout thrashing during navigation
  static Map<String, dynamic>? _cachedUser;
  static String? _cachedRole;
  static List<String>? _cachedPermissions;

  static Map<String, dynamic>? get cachedUser => _cachedUser;
  static String? get cachedRole => _cachedRole;
  static List<String> get cachedPermissions => _cachedPermissions ?? [];

  static Future<void> saveLoginTime([DateTime? time]) async {
    final prefs = await SharedPreferences.getInstance();
    final loginTime = time ?? DateTime.now();
    await prefs.setString(_sessionTimeKey, loginTime.toIso8601String());
  }

  static Future<DateTime> getLoginTime() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_sessionTimeKey);
    if (str != null) {
      final dt = DateTime.tryParse(str);
      if (dt != null) return dt;
    }
    final now = DateTime.now();
    await prefs.setString(_sessionTimeKey, now.toIso8601String());
    return now;
  }

  static Future<void> save(String token, [String? serverUrl]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
    await prefs.setString(_serverUrlKey, (serverUrl ?? AppConfig.baseUrl).trim());
  }

  static Future<void> saveRole(String role) async {
    _cachedRole = role;
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_roleKey, role);
  }

  static Future<void> savePermissions(List<String> perms) async {
    _cachedPermissions = perms;
    final pref = await SharedPreferences.getInstance();
    await pref.setStringList(_permKey, perms);
  }

  static Future<String?> getRole() async {
    if (_cachedRole != null) return _cachedRole;
    final pref = await SharedPreferences.getInstance();
    _cachedRole = pref.getString(_roleKey);
    return _cachedRole;
  }

  static Future<List<String>> getPermissions() async {
    if (_cachedPermissions != null) return _cachedPermissions!;
    final pref = await SharedPreferences.getInstance();
    _cachedPermissions = pref.getStringList(_permKey) ?? [];
    return _cachedPermissions!;
  }

  static Future<String?> getRawToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final savedServer = prefs.getString(_serverUrlKey);
    // Security check: if server_config.json was altered on disk to point to another server,
    // immediately invalidate client session so unauthorized screens cannot be viewed without login.
    if (savedServer != null && savedServer.isNotEmpty && savedServer.trim() != AppConfig.baseUrl.trim()) {
      await clear();
      return null;
    }
    final token = prefs.getString(_key);
    if (token != null && token.isNotEmpty) {
      if (isExpired(token)) {
        await clear();
        return null;
      }
    }
    return token;
  }

  static Future<void> clear() async {
    _cachedUser = null;
    _cachedRole = null;
    _cachedPermissions = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_permKey);
    await prefs.remove(_sessionTimeKey);
    await prefs.remove(_serverUrlKey);
  }

  static bool isExpired(String token) {
    try {
      return Jwt.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    _cachedUser = user;
    if (user['role'] != null) _cachedRole = user['role'].toString();
    if (user['permissions'] is List) {
      _cachedPermissions = List<String>.from(user['permissions']);
    }
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final pref = await SharedPreferences.getInstance();
    final data = pref.getString(_userKey);

    if (data == null) return null;

    try {
      _cachedUser = jsonDecode(data);
      if (_cachedUser?['role'] != null) _cachedRole = _cachedUser!['role'].toString();
      if (_cachedUser?['permissions'] is List) {
        _cachedPermissions = List<String>.from(_cachedUser!['permissions']);
      }
      return _cachedUser;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getOutletCode() async {
    final user = await getUser();
    if (user != null && user['outlet_code'] != null && user['outlet_code'].toString().isNotEmpty) {
      return user['outlet_code'].toString();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('outlet_code') ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : null);
  }

  static Future<void> saveOutletCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('outlet_code', code);
    final user = await getUser();
    if (user != null) {
      user['outlet_code'] = code;
      await saveUser(user);
    }
  }

  static Future<String> getBusinessModule() async {
    final user = await getUser();
    return (user?['business_module'] ?? user?['outlet_module'] ?? user?['outlet_type'] ?? 'ALL').toString().toUpperCase();
  }

  static Future<bool> isRestaurantModuleActive() async {
    final mod = await getBusinessModule();
    return mod == 'ALL' || mod == 'RESTAURANT' || mod == 'HOTEL' || mod == 'CAFE' || mod == 'DINE_IN';
  }
}
