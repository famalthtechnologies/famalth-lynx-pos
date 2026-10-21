import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

Future<void> showControlPlaneServerDialog(
  BuildContext context, {
  VoidCallback? onSaved,
  bool isReadOnly = false,
  VoidCallback? onLogoutRequested,
}) async {
  final urlCtrl = TextEditingController(text: AppConfig.baseUrl);
  bool isTesting = false;
  String? testMsg;
  bool? testSuccess;

  await showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> runTest(String testUrl) async {
            if (testUrl.isEmpty) {
              setDialogState(() {
                testSuccess = false;
                testMsg = 'Please enter a server URL first.';
              });
              return;
            }

            setDialogState(() {
              isTesting = true;
              testMsg = null;
              testSuccess = null;
            });

            try {
              String normalized = testUrl.trim();
              if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
                normalized = 'http://$normalized';
                urlCtrl.text = normalized;
              }
              if (normalized.endsWith('/')) {
                normalized = normalized.substring(0, normalized.length - 1);
              }

              final uri = Uri.parse('$normalized/health');
              final stopwatch = Stopwatch()..start();
              final res = await http.get(uri).timeout(const Duration(seconds: 5));
              stopwatch.stop();

              if (res.statusCode == 200) {
                final body = jsonDecode(res.body);
                setDialogState(() {
                  testSuccess = true;
                  testMsg = 'Connected in ${stopwatch.elapsedMilliseconds}ms. Status: ${body["status"] ?? "ONLINE"}';
                });
              } else {
                setDialogState(() {
                  testSuccess = false;
                  testMsg = 'Server responded with HTTP code ${res.statusCode}.';
                });
              }
            } catch (e) {
              setDialogState(() {
                testSuccess = false;
                testMsg = 'Unreachable: Verify server is running on that IP and port.';
              });
            } finally {
              setDialogState(() => isTesting = false);
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isReadOnly ? const Color(0xFFFEF2F2) : const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isReadOnly ? const Color(0xFFFECACA) : const Color(0xFFBAE6FD)),
                  ),
                  child: Icon(
                    isReadOnly ? Icons.lock_rounded : Icons.dns_rounded,
                    color: isReadOnly ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isReadOnly ? 'Server Connectivity (Locked)' : 'Server Connectivity',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      isReadOnly
                          ? 'Active Operator Session (Endpoint Changes Restricted)'
                          : 'Configure Master Control Plane Target Endpoint',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReadOnly) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Server change is restricted after login. Changing server endpoint is disabled while an operator session is running to prevent cross-server access without login.',
                              style: TextStyle(color: Color(0xFF991B1B), fontSize: 12, height: 1.3, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    const Text(
                      'Set the backend server URL or IP address that this Enterprise Console connects to for Telemetry, Tenants, and Support queries.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'CURRENT TARGET SERVER URL / IP',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: urlCtrl,
                    enabled: !isReadOnly,
                    readOnly: isReadOnly,
                    style: TextStyle(
                      fontSize: 13,
                      color: isReadOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. http://127.0.0.1:3000 or http://192.168.1.100:3000',
                      filled: true,
                      fillColor: isReadOnly ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
                      prefixIcon: Icon(
                        isReadOnly ? Icons.lock_outline : Icons.link_rounded,
                        size: 20,
                        color: const Color(0xFF64748B),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF0284C7)),
                        tooltip: 'Test Connection',
                        onPressed: isTesting ? null : () => runTest(urlCtrl.text.trim()),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      ),
                    ),
                  ),

                  if (!isReadOnly) ...[
                    const SizedBox(height: 10),
                    // Quick presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.computer_rounded, size: 14, color: Color(0xFF0284C7)),
                          label: const Text('Localhost (127.0.0.1:3000)', style: TextStyle(fontSize: 11)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            urlCtrl.text = 'http://127.0.0.1:3000';
                            runTest('http://127.0.0.1:3000');
                          },
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.cloud_queue_rounded, size: 14, color: Color(0xFF0284C7)),
                          label: const Text('localhost:3000', style: TextStyle(fontSize: 11)),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onPressed: () {
                            urlCtrl.text = 'http://localhost:3000';
                            runTest('http://localhost:3000');
                          },
                        ),
                      ],
                    ),
                  ],

                  if (isTesting) ...[
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))),
                        SizedBox(width: 10),
                        Text('Connecting & pinging health check...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ] else if (testMsg != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: testSuccess == true ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: testSuccess == true ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            testSuccess == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 18,
                            color: testSuccess == true ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              testMsg!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: testSuccess == true ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(isReadOnly ? 'Close' : 'Cancel', style: const TextStyle(color: Color(0xFF64748B))),
              ),
              if (isReadOnly) ...[
                if (onLogoutRequested != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Log Out to Switch Server'),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      onLogoutRequested();
                    },
                  ),
              ] else ...[
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  onPressed: () async {
                    final newUrl = urlCtrl.text.trim();
                    if (newUrl.isNotEmpty) {
                      await AppConfig.saveConfig(newUrl, AppConfig.outlets);
                      if (context.mounted) {
                        Navigator.pop(dialogCtx);
                        onSaved?.call();
                      }
                    }
                  },
                  child: const Text('Save & Apply Endpoint'),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}

class ControlPlaneServerBadge extends StatefulWidget {
  final VoidCallback? onChanged;
  final bool isReadOnly;
  final VoidCallback? onLogoutRequested;
  const ControlPlaneServerBadge({
    super.key,
    this.onChanged,
    this.isReadOnly = false,
    this.onLogoutRequested,
  });

  @override
  State<ControlPlaneServerBadge> createState() => _ControlPlaneServerBadgeState();
}

class _ControlPlaneServerBadgeState extends State<ControlPlaneServerBadge> {
  bool _isChecking = false;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    if (!mounted) return;
    setState(() => _isChecking = true);
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isOnline = (res.statusCode == 200);
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isOnline = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final bgColor = _isOnline ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final borderColor = _isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showControlPlaneServerDialog(
        context,
        isReadOnly: widget.isReadOnly,
        onLogoutRequested: widget.onLogoutRequested,
        onSaved: () {
          _checkHealth();
          widget.onChanged?.call();
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _isChecking ? const Color(0xFFF59E0B) : statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isOnline ? 'Server: ${AppConfig.baseUrl}' : 'Server: ${AppConfig.baseUrl} (Offline)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _isOnline ? const Color(0xFF065F46) : const Color(0xFF991B1B),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.settings_outlined, size: 14, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}
