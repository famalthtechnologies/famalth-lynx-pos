import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ControlPlaneStorage {
  static const _tokenKey = 'master_control_plane_token';
  static const _userKey = 'master_control_plane_user';
  static const _serverUrlKey = 'master_control_plane_server_url';

  static Future<void> saveToken(String token, [String? serverUrl]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_serverUrlKey, (serverUrl ?? AppConfig.baseUrl).trim());
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedServer = prefs.getString(_serverUrlKey);
    // Security check: if server_config.json was altered on disk to point to another server,
    // immediately invalidate the token to prevent cross-server unauthorized access without login.
    if (savedServer != null && savedServer.isNotEmpty && savedServer.trim() != AppConfig.baseUrl.trim()) {
      await clear();
      return null;
    }
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_userKey);
    if (str == null || str.isEmpty) return null;
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_serverUrlKey);
  }
}
