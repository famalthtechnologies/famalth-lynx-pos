import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';
import '../auth/control_plane_storage.dart';
import '../auth/token_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  static String get baseUrl => AppConfig.baseUrl;

  static Uri _uri(String path) {
    // Avoid accidental double slashes when baseUrl ends with '/' and path starts with '/'.
    // Also supports users configuring baseUrl with/without trailing slash.
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final base = Uri.parse(AppConfig.baseUrl);
    return base.resolve(path);
  }

  // ---------------- COMMON HEADERS ----------------
  static Future<Map<String, String>> _headers([String? path]) async {
    String? token;
    final cleanPath = (path ?? '').trim();
    final isControlPlaneRoute = cleanPath.contains('api/v1/control-plane');
    final isPublicCpRoute = cleanPath.contains('auth/login') ||
        cleanPath.contains('auth/request-owner-setup-otp') ||
        cleanPath.contains('auth/setup-status') ||
        cleanPath.contains('auth/initialize-master') ||
        cleanPath.contains('auth/recover-username') ||
        cleanPath.contains('auth/forgot-password') ||
        cleanPath.contains('license-and-rm-status') ||
        cleanPath.contains('register-property');

    if (isControlPlaneRoute) {
      token = await ControlPlaneStorage.getToken();
      // Only client-facing CP routes (like license warning banner or POS ticket creation) fallback to merchant token
      if (token == null && (isPublicCpRoute || cleanPath.contains('support/tickets'))) {
        token = await TokenStorage.read();
      }
    } else {
      token = await TokenStorage.read();
    }

    final userMap = await TokenStorage.getUser();
    final int activeOutletId = int.tryParse((userMap?['outlet_id'] ?? userMap?['outletId'] ?? userMap?['property_id'] ?? userMap?['propertyId'] ?? 1).toString()) ?? 1;
    final String outletCode = (userMap?['outlet_code'] ?? userMap?['outletCode'] ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '')).toString().trim();

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'x-outlet-id': activeOutletId.toString(),
      'outlet_id': activeOutletId.toString(),
      if (outletCode.isNotEmpty) 'x-outlet-code': outletCode,
      if (outletCode.isNotEmpty) 'outlet_code': outletCode,
    };
  }

  // ---------------- GET ----------------
  static Future<dynamic> get(String path, {bool silent = false}) async {
    final response = await http.get(
      _uri(path),
      headers: await _headers(path),
    );
    return _handleResponse(response, silent: silent);
  }

  // ---------------- POST ----------------
  static Future<dynamic> post(String path, dynamic body, {bool silent = false}) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(path),
      body: jsonEncode(body),
    );
    return _handleResponse(response, silent: silent);
  }

  // ---------------- PUT ----------------
  static Future<dynamic> put(String path, Map body, {bool silent = false}) async {
    final response = await http.put(
      _uri(path),
      headers: await _headers(path),
      body: jsonEncode(body),
    );
    return _handleResponse(response, silent: silent);
  }

  // ---------------- PATCH ----------------
  static Future<dynamic> patch(String path, dynamic body, {bool silent = false}) async {
    final response = await http.patch(
      _uri(path),
      headers: await _headers(path),
      body: jsonEncode(body),
    );
    return _handleResponse(response, silent: silent);
  }

  // ---------------- DELETE ----------------
  static Future<dynamic> delete(String path, {Map? body, bool silent = false}) async {
    final response = await http.delete(
      _uri(path),
      headers: await _headers(path),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response, silent: silent);
  }

  // ---------------- RESPONSE HANDLER ----------------
  static dynamic _handleResponse(http.Response response, {bool silent = false}) {
    if (response.body.isEmpty) {
      if (!silent) showErrorSnackbar('Empty server response');
      throw Exception('Empty server response');
    }
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      String errorMessage = data['error'] ?? data['message'] ?? "API Error";

      final lowerMsg = errorMessage.toLowerCase();
      final isAuthError = response.statusCode == 401 ||
          lowerMsg.contains('no token provided') ||
          lowerMsg.contains('token expired') ||
          lowerMsg.contains('jwt expired') ||
          lowerMsg.contains('unauthorized');

      if (!isAuthError && !silent) {
        showErrorSnackbar(errorMessage);
      }

      throw Exception(errorMessage);
    }

    return data;
  }
}

void showErrorSnackbar(String message) {
  globalSnackbarKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}
