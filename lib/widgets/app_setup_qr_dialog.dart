import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/auth/token_storage.dart';
import '../core/config/app_config.dart';

enum AppSetupQrMode {
  staff,
  customer,
}

/// Data model and parser for App Configuration QR Codes
class AppConfigQrPayload {
  final String serverUrl;
  final String? outletCode;
  final String? outletName;

  AppConfigQrPayload({
    required this.serverUrl,
    this.outletCode,
    this.outletName,
  });

  /// Robust parser for all QR formats: JSON, Deep Link / URI, Piped string, or plain URL.
  static AppConfigQrPayload? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 1. JSON Format
    if (text.startsWith('{') && text.endsWith('}')) {
      try {
        final map = jsonDecode(text);
        if (map is Map) {
          final server = (map['serverUrl'] ??
                  map['baseUrl'] ??
                  map['url'] ??
                  map['server_url'] ??
                  map['server'] ??
                  '')
              .toString()
              .trim();
          final outlet = (map['outletCode'] ??
                  map['outlet_code'] ??
                  map['outlet'] ??
                  map['code'] ??
                  '')
              .toString()
              .trim();
          final name = (map['outletName'] ??
                  map['outlet_name'] ??
                  map['name'] ??
                  map['store'] ??
                  '')
              .toString()
              .trim();

          if (server.isNotEmpty) {
            return AppConfigQrPayload(
              serverUrl: _cleanUrl(server),
              outletCode: outlet.isNotEmpty ? outlet : null,
              outletName: name.isNotEmpty ? name : null,
            );
          }
        }
      } catch (_) {}
    }

    // 2. URI / Query string (e.g. retailsale://config?server=...&outlet=...)
    try {
      final uri = Uri.parse(text);
      if (uri.hasQuery) {
        final queryServer = uri.queryParameters['server'] ??
            uri.queryParameters['serverUrl'] ??
            uri.queryParameters['url'];
        final queryOutlet = uri.queryParameters['outlet'] ??
            uri.queryParameters['outletCode'] ??
            uri.queryParameters['outlet_code'];
        final queryName =
            uri.queryParameters['name'] ?? uri.queryParameters['outletName'];

        if (queryServer != null && queryServer.trim().isNotEmpty) {
          return AppConfigQrPayload(
            serverUrl: _cleanUrl(queryServer.trim()),
            outletCode: queryOutlet?.trim(),
            outletName: queryName?.trim(),
          );
        } else if (uri.scheme == 'http' || uri.scheme == 'https') {
          final baseUri = Uri(
            scheme: uri.scheme,
            userInfo: uri.userInfo,
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
            path: uri.path.isNotEmpty && uri.path != '/' ? uri.path : '',
          ).toString();
          return AppConfigQrPayload(
            serverUrl: _cleanUrl(baseUri),
            outletCode: queryOutlet?.trim(),
            outletName: queryName?.trim(),
          );
        }
      }
    } catch (_) {}

    // 3. Pipe delimited format: URL|OUTLET_CODE or URL|OUTLET_CODE|NAME
    if (text.contains('|')) {
      final parts = text.split('|').map((s) => s.trim()).toList();
      if (parts.isNotEmpty &&
          (parts[0].startsWith('http://') || parts[0].startsWith('https://'))) {
        return AppConfigQrPayload(
          serverUrl: _cleanUrl(parts[0]),
          outletCode: parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
          outletName: parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
        );
      }
    }

    // 4. Fallback: Plain HTTP/HTTPS URL
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return AppConfigQrPayload(serverUrl: _cleanUrl(text));
    }

    return null;
  }

  static String _cleanUrl(String url) {
    var cleaned = url.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  String toJsonString() {
    return jsonEncode({
      'type': 'retailsale_config',
      'serverUrl': serverUrl,
      if (outletCode != null && outletCode!.isNotEmpty) 'outletCode': outletCode,
      if (outletName != null && outletName!.isNotEmpty) 'outletName': outletName,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}

/// Dialog to view, copy, share, and print the Store Setup / Shopping QR Code.
class AppSetupQrDialog extends StatefulWidget {
  final String? serverUrl;
  final String? outletCode;
  final String? storeName;
  final AppSetupQrMode mode;

  const AppSetupQrDialog({
    super.key,
    this.serverUrl,
    this.outletCode,
    this.storeName,
    this.mode = AppSetupQrMode.staff,
  });

  static Future<void> show(
    BuildContext context, {
    String? serverUrl,
    String? outletCode,
    String? storeName,
    AppSetupQrMode mode = AppSetupQrMode.staff,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AppSetupQrDialog(
        serverUrl: serverUrl,
        outletCode: outletCode,
        storeName: storeName,
        mode: mode,
      ),
    );
  }

  @override
  State<AppSetupQrDialog> createState() => _AppSetupQrDialogState();
}

class _AppSetupQrDialogState extends State<AppSetupQrDialog> {
  late String _resolvedUrl;
  late String _resolvedOutlet;
  late String _resolvedStoreName;
  bool _isPrinting = false;
  bool _isLanDetected = false;
  List<Map<String, String>> _availableLanIps = [];

  bool get _isCustomer => widget.mode == AppSetupQrMode.customer;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = (widget.serverUrl != null && widget.serverUrl!.isNotEmpty)
        ? widget.serverUrl!
        : AppConfig.baseUrl;
    String initialOutlet = (widget.outletCode != null && widget.outletCode!.isNotEmpty)
        ? widget.outletCode!
        : '';
    if (initialOutlet.isEmpty || initialOutlet == '1' || int.tryParse(initialOutlet) != null) {
      if (AppConfig.outlets.isNotEmpty) {
        final found = AppConfig.outlets.firstWhere((o) => int.tryParse(o) == null, orElse: () => '');
        if (found.isNotEmpty) initialOutlet = found;
      }
    }
    _resolvedOutlet = initialOutlet.isNotEmpty ? initialOutlet : (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : '');
    if (_resolvedOutlet.isEmpty || _resolvedOutlet == '1' || int.tryParse(_resolvedOutlet) != null) {
      _resolvedOutlet = 'OUTLET202604212159';
    }
    _resolvedStoreName =
        (widget.storeName != null && widget.storeName!.isNotEmpty)
            ? widget.storeName!
            : (_isCustomer ? 'Store Shopping' : 'Store Setup');

    _loadOutletIfEmpty();
    _resolveSystemLanIp();
  }

  Future<void> _resolveSystemLanIp() async {
    final lanUrl = await AppConfig.getLanServerUrl(customUrl: _resolvedUrl);
    if (lanUrl != _resolvedUrl && mounted) {
      setState(() {
        _resolvedUrl = lanUrl;
        _isLanDetected = true;
      });
    }

    try {
      if (!kIsWeb) {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        final list = <Map<String, String>>[];
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final ip = addr.address;
            if (!addr.isLoopback && !ip.startsWith('169.254.') && !ip.startsWith('127.')) {
              list.add({'iface': iface.name, 'ip': ip});
            }
          }
        }
        if (list.isNotEmpty && mounted) {
          setState(() {
            _availableLanIps = list;
          });
        }
      }
    } catch (_) {}
  }

  void _changeLanIp(String newIp) {
    try {
      final uri = Uri.parse(_resolvedUrl);
      final newUri = uri.replace(host: newIp);
      setState(() {
        _resolvedUrl = newUri.toString();
        _isLanDetected = true;
      });
    } catch (_) {}
  }

  bool _isLanIp(String url) {
    try {
      final host = Uri.parse(url).host;
      return host.startsWith('192.168.') || host.startsWith('10.') || host.startsWith('172.');
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadOutletIfEmpty() async {
    if (_resolvedOutlet.isEmpty || _resolvedOutlet == '1' || int.tryParse(_resolvedOutlet) != null) {
      final code = await TokenStorage.getOutletCode();
      if (code != null && code.isNotEmpty && int.tryParse(code) == null && mounted) {
        setState(() {
          _resolvedOutlet = code;
        });
        return;
      }
      if (AppConfig.outlets.isNotEmpty) {
        final found = AppConfig.outlets.firstWhere((o) => int.tryParse(o) == null, orElse: () => '');
        if (found.isNotEmpty && mounted) {
          setState(() {
            _resolvedOutlet = found;
          });
          return;
        }
      }
    }
  }

  String get _qrData {
    return jsonEncode({
      'type': 'retailsale_config',
      'serverUrl': _resolvedUrl,
      if (_resolvedOutlet.isNotEmpty) 'outletCode': _resolvedOutlet,
      if (_resolvedStoreName.isNotEmpty) 'outletName': _resolvedStoreName,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _printStandee() async {
    setState(() => _isPrinting = true);
    try {
      final pdf = pw.Document();
      final qrString = _qrData;
      final storeTitle = _resolvedStoreName.isNotEmpty ? _resolvedStoreName : 'STORE APP SETUP';
      final outletDisplay = _resolvedOutlet.isNotEmpty ? _resolvedOutlet : 'DEFAULT';
      final urlDisplay = _resolvedUrl;

      final badgeText = _isCustomer
          ? 'FAMILY & FRIENDS STORE SHOPPING QR'
          : 'STAFF & COMPANION APPS AUTO-CONFIGURATION';

      final stepHeading = _isCustomer
          ? 'HOW TO SHOP FROM THIS STORE:'
          : 'HOW TO CONNECT YOUR DEVICE:';

      final stepInstructions = _isCustomer
          ? '1. Open the Customer Shopping App.\n'
            '2. Point your camera at this QR code on the setup screen.\n'
            '3. Browse items, add to cart, and start shopping immediately!'
          : '1. Open any companion app (Waiter, Billing, Rider, or Retailer Console).\n'
            '2. On the setup screen, point camera at this QR code (or upload image).\n'
            '3. App automatically configures server URL & outlet in 1 second!';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context ctx) {
            return pw.Center(
              child: pw.Container(
                width: 480,
                padding: const pw.EdgeInsets.all(28),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blueGrey800, width: 2),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      storeTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(20),
                        border: pw.Border.all(color: PdfColors.blue200),
                      ),
                      child: pw.Text(
                        badgeText,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // QR Code in Box
                    pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
                        borderRadius: pw.BorderRadius.circular(12),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrString,
                        width: 200,
                        height: 200,
                      ),
                    ),
                    pw.SizedBox(height: 20),

                    // Steps Box
                    pw.Container(
                      width: 400,
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            stepHeading,
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            stepInstructions,
                            style: const pw.TextStyle(fontSize: 8.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 16),

                    // Server details
                    pw.Text(
                      'Server: $urlDisplay | Outlet Code: $outletDisplay',
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Powered by RetailSale ERP & POS',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        name: 'Store_${_isCustomer ? "Customer_QR" : "Setup_QR"}_${_resolvedOutlet.isNotEmpty ? _resolvedOutlet : "Standee"}',
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _copyConfig() {
    Clipboard.setData(ClipboardData(text: _qrData));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isCustomer
              ? 'Store referral link copied to clipboard! Share on WhatsApp with family & friends.'
              : 'Setup configuration JSON copied to clipboard!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isCustomer ? 'Share Store with Family & Friends' : 'Staff App Setup QR';
    final subtitleText = _isCustomer
        ? 'Share this QR so family & friends can shop and order from this outlet'
        : 'Scan to auto-config companion devices';
    final pillText = _isCustomer
        ? 'Share with Family & Friends to shop online'
        : 'Universal QR: Waiter, Billing, Rider, Retailer';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isCustomer ? Icons.family_restroom_rounded : Icons.qr_code_2_rounded,
                      color: const Color(0xFF0284C7),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // QR Code Card
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    gapless: true,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Supported Apps Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      pillText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Details snippet
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dns_outlined, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _resolvedUrl,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isLanDetected || _isLanIp(_resolvedUrl)) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.wifi, size: 10, color: Color(0xFF059669)),
                                SizedBox(width: 3),
                                Text(
                                  'System LAN IP',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_availableLanIps.length > 1) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PopupMenuButton<String>(
                          tooltip: 'Switch Network IP',
                          padding: EdgeInsets.zero,
                          onSelected: _changeLanIp,
                          itemBuilder: (ctx) => _availableLanIps.map((item) {
                            return PopupMenuItem<String>(
                              value: item['ip'],
                              child: Text('${item['iface']}: ${item['ip']}'),
                            );
                          }).toList(),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_horiz, size: 14, color: Color(0xFF2563EB)),
                              SizedBox(width: 4),
                              Text(
                                'Switch Network Interface',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_resolvedOutlet.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Outlet: $_resolvedOutlet',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: Text(
                        _isCustomer ? 'Copy Share Link' : 'Copy Link',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _copyConfig,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.print_rounded, size: 17),
                      label: Text(
                        _isCustomer ? 'Print Poster' : 'Print Standee',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: _isPrinting ? null : _printStandee,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
