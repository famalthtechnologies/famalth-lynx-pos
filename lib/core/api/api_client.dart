import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';
import '../../screens/auth/login_screen.dart';
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
    final isControlPlaneRoute = cleanPath.contains('api/v1/control-plane') || isAdminConsole;
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
      if (isAdminConsole || isControlPlaneRoute) 'x-client-type': 'enterprise-console',
      if (isAdminConsole || isControlPlaneRoute) 'x-control-plane': 'true',
    };
  }

  // ---------------- GET ----------------
  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool silent = false,
  }) async {
    Uri uri = _uri(path);
    if (queryParams != null && queryParams.isNotEmpty) {
      final mergedParams = Map<String, String>.from(uri.queryParameters);
      queryParams.forEach((k, v) {
        if (v != null) mergedParams[k] = v.toString();
      });
      uri = uri.replace(queryParameters: mergedParams);
    }
    final response = await http.get(
      uri,
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

  static bool isAdminConsole = false;
  static bool _isMaintenanceDialogOpen = false;

  static void showMaintenanceLockoutDialog({
    String? title,
    String? message,
    int? remainingMinutes,
  }) {
    // Maintenance lockout is strictly for store clients / terminals, NEVER for Admin Console!
    if (isAdminConsole) return;
    if (_isMaintenanceDialogOpen) return;

    final context = globalNavigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showMaintenanceLockoutDialog(
          title: title,
          message: message,
          remainingMinutes: remainingMinutes,
        );
      });
      return;
    }

    _isMaintenanceDialogOpen = true;

    final resolvedTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : 'System Under Scheduled Maintenance';
    final resolvedMessage = (message != null && message.trim().isNotEmpty)
        ? message.trim()
        : 'Scheduled system optimization is in progress. Store operations are temporarily paused.';
    final resolvedMinutes = remainingMinutes ?? 30;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.engineering_rounded, color: Color(0xFFD97706), size: 48),
            title: Text(
              resolvedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  resolvedMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_filled_rounded, size: 20, color: Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          resolvedMinutes > 0
                              ? 'Estimated downtime: ~$resolvedMinutes mins remaining. Store operations are paused.'
                              : 'System maintenance is active. Store operations are temporarily paused.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: () async {
                    _isMaintenanceDialogOpen = false;
                    await TokenStorage.clear();
                    await ControlPlaneStorage.clear();
                    final nav = globalNavigatorKey.currentState;
                    if (nav != null) {
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- RESPONSE HANDLER ----------------
  static dynamic _handleResponse(http.Response response, {bool silent = false}) {
    if (response.body.isEmpty) {
      if (!silent) showErrorSnackbar('Empty server response');
      throw Exception('Empty server response');
    }
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || (data is Map && data['success'] == false)) {
      if (response.statusCode == 503 || (data is Map && data['maintenance'] == true)) {
        // Admin console is strictly exempt from client terminal lockout
        if (isAdminConsole) {
          return {
            'success': true,
            'maintenance': true,
            'title': (data is Map ? data['title'] : null) ?? 'System Under Scheduled Maintenance',
            'message': (data is Map ? data['message'] : null) ?? 'Scheduled system optimization is in progress.',
            'remainingMinutes': data is Map ? data['remainingMinutes'] : 30,
            'data': data is Map && data['data'] != null ? data['data'] : data,
          };
        }

        final title = (data is Map ? data['title'] : null) ?? 'System Under Scheduled Maintenance';
        final message = (data is Map ? data['message'] : null) ??
            'Scheduled system optimization is in progress. Store operations are temporarily paused.';
        final rawRemaining = data is Map ? data['remainingMinutes'] : null;
        final remaining = rawRemaining is num
            ? rawRemaining.toInt()
            : (int.tryParse(rawRemaining?.toString() ?? '') ?? 30);
        final notice = '⚠️ $title: $message (~$remaining mins remaining)';

        // Present non-dismissible lockout dialog with Log Out option only
        showMaintenanceLockoutDialog(
          title: title.toString(),
          message: message.toString(),
          remainingMinutes: remaining,
        );

        // Return controlled maintenance payload without throwing unhandled exception
        return {
          'success': false,
          'maintenance': true,
          'message': notice,
          'title': title,
          'remainingMinutes': remaining,
          'data': null,
        };
      }

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
