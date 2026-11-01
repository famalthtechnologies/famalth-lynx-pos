import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:retailpos/core/config/app_config.dart';

class ServerBootstrapper {
  static Future<bool> ensureServerIsRunning() async {
    if (kIsWeb) return true;

    final String serverUrl = AppConfig.baseUrl;

    // 1. Try to ping the server first
    if (await _pingServer(serverUrl)) {
      return true;
    }

    // 2. NETWORK CHECK: Are we the Host or a Client / Cloud connection?
    if (!AppConfig.isLocalServer) {
      debugPrint("Client/Cloud Mode: Cannot reach server at $serverUrl. Local wake up skipped.");
      return false;
    }

    // 3. If we are the local Host machine, wake up the local server process!
    if (!kIsWeb && Platform.isWindows) {
      try {
        final String appDir = Platform.resolvedExecutable.isNotEmpty
            ? File(Platform.resolvedExecutable).parent.path
            : Directory.current.path;

        final String vbsPath = '$appDir\\run_hidden.vbs';
        final String exePath = '$appDir\\server.exe';

        if (File(vbsPath).existsSync()) {
          await Process.start(
            'wscript.exe',
            [vbsPath],
            workingDirectory: appDir,
            mode: ProcessStartMode.detached,
          );
        } else if (File(exePath).existsSync()) {
          await Process.start(
            exePath,
            [],
            workingDirectory: appDir,
            mode: ProcessStartMode.detached,
          );
        } else {
          debugPrint("No server executable or vbs found in $appDir");
          return false;
        }

        // Wait dynamically with active polling (up to 12 seconds)
        for (int i = 0; i < 12; i++) {
          await Future.delayed(const Duration(seconds: 1));
          if (await _pingServer(serverUrl)) {
            return true;
          }
        }
      } catch (e) {
        debugPrint("Failed to start local server: $e");
        return false;
      }
    }

    return false;
  }

  static Future<bool> _pingServer(String baseUrl) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
