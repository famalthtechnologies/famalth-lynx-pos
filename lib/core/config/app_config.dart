import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String baseUrl = 'http://127.0.0.1:3000';
  static List<String> outlets = [];
  static bool isMobileBilling = false;
  static bool isSupplierApp = false;
  static late String _configPath;

  static Future<void> init() async {
    try {
      if (kIsWeb) {
        _configPath = 'server_config.json';
      } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        isMobileBilling = true;
        final directory = await getApplicationDocumentsDirectory();
        _configPath = p.join(directory.path, 'server_config.json');
      } else {
        _configPath = p.join(Directory.current.path, 'server_config.json');
      }
    } catch (_) {
      _configPath = 'server_config.json';
    }
    await loadConfig();
  }

  static Future<bool> configExists() async {
    if (kIsWeb) return true;
    try {
      return File(_configPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> loadConfig() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final savedUrl = prefs.getString('server_base_url');

        if (savedUrl != null && savedUrl.trim().isNotEmpty) {
          baseUrl = savedUrl.trim();
        } else {
          final origin = Uri.base.origin;
          final host = Uri.base.host.toLowerCase();
          final port = Uri.base.port;

          if ((host == 'localhost' || host == '127.0.0.1') && port != 3000) {
            baseUrl = 'http://localhost:3000';
          } else {
            baseUrl = origin;
          }
        }

        final saved = prefs.getStringList('web_linked_outlets') ?? [];
        outlets = saved;
        return true;
      }

      final file = File(_configPath);
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final data = jsonDecode(contents);

        if (data['baseUrl'] != null && data['baseUrl'].toString().isNotEmpty) {
          baseUrl = data['baseUrl'].toString().trim();
        }

        if (data['outlets'] != null) {
          outlets = List<String>.from(data['outlets']).map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
        return true;
      }
    } catch (e) {
      print('Error loading config: $e');
    }
    return false;
  }

  static Future<void> saveConfig(String url, List<String> newOutlets) async {
    try {
      String cleanUrl = url.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      baseUrl = cleanUrl;
      outlets = newOutlets;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_base_url', cleanUrl);

      if (kIsWeb) {
        await prefs.setStringList('web_linked_outlets', newOutlets);
        return;
      }

      final file = File(_configPath);
      await file.writeAsString(jsonEncode({'baseUrl': cleanUrl, 'outlets': newOutlets}));

      // If running on a local workstation (not a remote/cloud server), also keep server_port.txt synchronized
      if (isLocalServer) {
        try {
          final uri = Uri.tryParse(cleanUrl);
          if (uri != null && uri.hasPort && uri.port > 0) {
            final portFile = File(p.join(p.dirname(_configPath), 'server_port.txt'));
            await portFile.writeAsString(uri.port.toString());
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Error saving config: $e');
      throw Exception(
          "Failed to save configuration to disk. Please check folder permissions.");
    }
  }

  static bool get isLocalServer {
    if (kIsWeb) return false;
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
    } catch (_) {
      final lower = baseUrl.toLowerCase();
      return lower.contains('localhost') || lower.contains('127.0.0.1') || lower.contains('0.0.0.0');
    }
  }

  /// True if this terminal is a Client PC connected to a local server across LAN
  static bool get isClientPc {
    if (kIsWeb) return false;
    if (isLocalServer) return false;
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host.toLowerCase();
      if (host.startsWith('192.168.') || host.startsWith('10.') || host.endsWith('.local')) {
        return true;
      }
      if (host.startsWith('172.')) {
        final parts = host.split('.');
        if (parts.length >= 2) {
          final second = int.tryParse(parts[1]) ?? 0;
          if (second >= 16 && second <= 31) return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// True if connected to an online cloud hosted server (e.g. VPS, DigitalOcean, Cloud domain)
  static bool get isCloudServer => !isLocalServer && !isClientPc;

  /// Resolves the system's actual Wi-Fi / Ethernet LAN IP when connected to a local server (localhost / 127.0.0.1)
  /// so that mobile companion devices (Waiter, Billing, Rider, Customer, Dining, Clinic) can connect over Wi-Fi.
  static Future<String> getLanServerUrl({String? customUrl}) async {
    final target = (customUrl != null && customUrl.trim().isNotEmpty) ? customUrl.trim() : baseUrl;
    try {
      final uri = Uri.parse(target);
      final host = uri.host.toLowerCase();
      final isLocal = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '0.0.0.0' ||
          host == '::1' ||
          host.startsWith('127.');
      if (!isLocal) {
        return target;
      }

      String? lanIp;

      // 1. On native platforms (Windows, Android, iOS, macOS, Linux)
      if (!kIsWeb) {
        try {
          final interfaces = await NetworkInterface.list(
            type: InternetAddressType.IPv4,
            includeLoopback: false,
          );

          for (final iface in interfaces) {
            for (final addr in iface.addresses) {
              final ip = addr.address;
              if (!addr.isLoopback && !ip.startsWith('169.254.') && !ip.startsWith('127.')) {
                if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
                  lanIp = ip;
                  break;
                } else if (lanIp == null) {
                  lanIp = ip;
                }
              }
            }
            if (lanIp != null && (lanIp.startsWith('192.168.') || lanIp.startsWith('10.'))) {
              break;
            }
          }
        } catch (_) {}
      }

      // 2. Query backend network-info endpoint if needed
      if (lanIp == null) {
        try {
          final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
          final request = await client.getUrl(Uri.parse('$target/api/system/server-time/network-info'));
          final response = await request.close();
          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            final data = jsonDecode(body);
            final primary = data['primaryIp']?.toString();
            if (primary != null && primary.isNotEmpty && primary != '127.0.0.1') {
              lanIp = primary;
            }
          }
        } catch (_) {}
      }

      if (lanIp != null && lanIp.isNotEmpty) {
        return uri.replace(host: lanIp).toString();
      }
    } catch (_) {}
    return target;
  }
}
