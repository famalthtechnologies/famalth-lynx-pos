import '../screens/recovery/backup_service.dart';

import '../core/settings/local_preferences.dart';
import '../core/auth/token_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/config/app_config.dart';

class StorageBackupCard extends StatefulWidget {
  final bool compact;
  final VoidCallback? onBackupChanged;

  const StorageBackupCard({
    super.key,
    this.compact = false,
    this.onBackupChanged,
  });

  @override
  State<StorageBackupCard> createState() => _StorageBackupCardState();
}

class _StorageBackupCardState extends State<StorageBackupCard> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _storageData;

  @override
  void initState() {
    super.initState();
    _fetchStorageStats();
  }

  Future<void> _fetchStorageStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.get(ApiEndpoints.storageStats, silent: true);
      if (res != null && res['success'] == true && res['data'] != null) {
        if (!mounted) return;
        setState(() {
          _storageData = res['data'] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = res?['message'] ?? 'Could not load storage stats';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openManageBackupsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ManageBackupsDialog(
        initialData: _storageData,
        onRefreshParent: () {
          _fetchStorageStats();
          widget.onBackupChanged?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_errorMessage != null || _storageData == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.storage_rounded, color: Colors.grey.shade400, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage ?? 'Storage stats unavailable',
                style: TextStyle(color: Colors.red.shade400, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _fetchStorageStats,
            ),
          ],
        ),
      );
    }

    final totalUsedPretty = _storageData!['totalUsedPretty'] ?? '0 B';
    final totalFreePretty = _storageData!['totalFreePretty'] ?? '0 B';
    final breakdown = (_storageData!['breakdown'] as Map<String, dynamic>?) ?? {};
    final backupsPretty = breakdown['backupsPretty'] ?? '0 B';
    final backupsCount = breakdown['backupsCount'] ?? 0;
    final uploadsPretty = breakdown['uploadsPretty'] ?? '0 B';
    final databasePretty = breakdown['databasePretty'] ?? '0 B';

    final latestBackup = _storageData!['latestBackup'] as Map<String, dynamic>?;
    final latestTimeAgo = latestBackup != null ? latestBackup['timeAgo'] ?? 'Recently' : 'No backups taken';

    // Segment calculation for multi-tone progress bar
    final totalDiskBytes = (_storageData!['totalDiskBytes'] as num?)?.toDouble() ?? 100000000.0;
    final backupsBytes = (breakdown['backupsBytes'] as num?)?.toDouble() ?? 0.0;
    final uploadsBytes = (breakdown['uploadsBytes'] as num?)?.toDouble() ?? 0.0;
    final databaseBytes = (breakdown['databaseBytes'] as num?)?.toDouble() ?? 0.0;

    double backupsFraction = (backupsBytes / totalDiskBytes).clamp(0.01, 0.6);
    double uploadsFraction = (uploadsBytes / totalDiskBytes).clamp(0.01, 0.4);
    if (backupsBytes == 0 && uploadsBytes == 0) {
      backupsFraction = (databaseBytes / totalDiskBytes).clamp(0.02, 0.3);
      uploadsFraction = 0.0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: "STORAGE" title matching Enterprise Standard
          Row(
            children: [
              Icon(Icons.dns_rounded, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'STORAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _fetchStorageStats,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.refresh, size: 14, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Storage Value: "5.3 GB used"
          Text(
            '$totalUsedPretty used',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),

          // Subtitle: "7.6 GB free"
          Text(
            '$totalFreePretty free',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Multi-color segmented progress bar (Enterprise storage palette)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 7,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              child: Row(
                children: [
                  Flexible(
                    flex: (backupsFraction * 100).toInt().clamp(1, 100),
                    child: Container(color: const Color(0xFFEF4444)), // Red/Coral for Backups
                  ),
                  if (uploadsFraction > 0)
                    Flexible(
                      flex: (uploadsFraction * 100).toInt().clamp(1, 100),
                      child: Container(color: const Color(0xFFFCA5A5)), // Light Coral for Uploads
                    ),
                  Expanded(
                    child: Container(color: Colors.transparent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Breakdown text: "3.2 GB backups (3) • 2.2 GB uploads • 104 MB database"
          Text(
            '$backupsPretty backups ($backupsCount) • $uploadsPretty uploads • $databasePretty database',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Footer Row: "Latest backup 3 hours ago" & "Manage backups"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Latest backup $latestTimeAgo',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _openManageBackupsDialog,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Manage backups',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444), // Accent action link
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManageBackupsDialog extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback onRefreshParent;

  const _ManageBackupsDialog({
    this.initialData,
    required this.onRefreshParent,
  });

  @override
  State<_ManageBackupsDialog> createState() => _ManageBackupsDialogState();
}

class _ManageBackupsDialogState extends State<_ManageBackupsDialog> {
  bool _isActionInProgress = false;
  String? _statusMessage;
  String? _dialogAlertMessage;
  String _dialogAlertType = 'SUCCESS'; // 'SUCCESS', 'WARNING', 'ERROR', 'INFO'
  List<dynamic> _backupsList = [];
  String _backupScope = 'OUTLET'; // 'OUTLET' or 'ALL'
  bool _saveToGoogleDrive = true;
  bool _emailDownloadLinkToOperator = true;
  String? _currentOutletCode;
  int _dialogTab = 0; // 0 = Outlet Backups, 1 = Admin Console
  Map<String, dynamic>? _adminOverview;
  bool _isAdminOverviewLoading = false;

  Future<void> _fetchAdminOverview() async {
    setState(() => _isAdminOverviewLoading = true);
    try {
      final res = await BackupService.fetchAdminStorageOverview();
      if (mounted) {
        setState(() {
          _adminOverview = res;
          _isAdminOverviewLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdminOverviewLoading = false);
        _showDialogMessage('Failed to load enterprise storage overview: $e', type: 'ERROR');
      }
    }
  }

  
  
  void _showAdminIncreaseStorageModal(Map<String, dynamic> client) {
    final oCode = (client['outletCode'] ?? '').toString();
    final oName = (client['outletName'] ?? oCode).toString();
    final currAlloc = (client['totalAllocatedPretty'] ?? '15.00 GB').toString();

    double selectedGb = 25.0;
    String actionType = 'ADD_GB';
    final customController = TextEditingController(text: '25');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_to_photos_rounded, color: Colors.blue, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Admin Storage Grant: $oName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              Text('Outlet: $oCode • Current: $currAlloc', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Allocation Action:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('+ Additional Add-On GB'),
                          selected: actionType == 'ADD_GB',
                          onSelected: (_) => setModalState(() => actionType = 'ADD_GB'),
                        ),
                        ChoiceChip(
                          label: const Text('🎁 Promotional Bonus GB'),
                          selected: actionType == 'ADD_BONUS_GB',
                          onSelected: (_) => setModalState(() => actionType = 'ADD_BONUS_GB'),
                        ),
                        ChoiceChip(
                          label: Text(client['isFrozen'] == true ? '🔓 Unfreeze' : '❄️ Freeze'),
                          selected: actionType == (client['isFrozen'] == true ? 'UNFREEZE' : 'FREEZE'),
                          onSelected: (_) => setModalState(() => actionType = (client['isFrozen'] == true ? 'UNFREEZE' : 'FREEZE')),
                        ),
                      ],
                    ),
                    if (actionType == 'ADD_GB' || actionType == 'ADD_BONUS_GB') ...[
                      const SizedBox(height: 14),
                      const Text('Quick Add Storage Options:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      Row(
                        children: [10, 25, 50, 100].map((gb) {
                          final isSel = selectedGb == gb.toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isSel ? Colors.blue.withValues(alpha: 0.15) : null,
                                side: BorderSide(color: isSel ? Colors.blue : Colors.grey.shade400),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  selectedGb = gb.toDouble();
                                  customController.text = gb.toString();
                                });
                              },
                              child: Text('+$gb GB', style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: customController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Custom GB to Add',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            setModalState(() => selectedGb = parsed);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Apply Quota Change'),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            setState(() {
                              _isActionInProgress = true;
                              _statusMessage = 'Applying storage adjustment for $oCode...';
                            });
                            try {
                              final res = await BackupService.adminModifyStorage(
                                outletCode: oCode,
                                action: actionType,
                                additionalGb: (actionType == 'ADD_GB' || actionType == 'ADD_BONUS_GB') ? selectedGb : null,
                              );
                              _showDialogMessage(res['message'] ?? '✓ Storage updated successfully!', type: 'SUCCESS');
                              await _fetchAdminOverview();
                            } catch (e) {
                              _showDialogMessage('Failed to update storage: $e', type: 'ERROR');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showUpgradeStorageModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plans = [
      {
        'code': 'ADDON_25GB',
        'name': 'Famalth Lynx +25 GB',
        'storage': '+25 GB Storage',
        'price': '₹99 / month',
        'desc': 'Ideal for busy stores backing up 2+ years of sales & invoices',
        'color': const Color(0xFF0284C7),
      },
      {
        'code': 'ADDON_50GB',
        'name': 'Famalth Lynx +50 GB',
        'storage': '+50 GB Storage',
        'price': '₹189 / month',
        'desc': 'Popular for multi-terminal branches with extensive item photos & reports',
        'color': const Color(0xFF7C3AED),
      },
      {
        'code': 'ADDON_100GB',
        'name': 'Famalth Lynx +100 GB',
        'storage': '+100 GB Storage',
        'price': '₹349 / month',
        'desc': 'Enterprise capacity with high-frequency snapshots and audit trails',
        'color': const Color(0xFF059669),
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF0284C7), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Famalth Lynx Storage Expansion',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Baseline 15 GB auto-allocated. Expand capacity anytime without disruption.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...plans.map((p) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (p['color'] as Color).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  p['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (p['color'] as Color).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p['price'] as String,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p['color'] as Color),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              p['desc'] as String,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: p['color'] as Color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            _isActionInProgress = true;
                            _statusMessage = 'Upgrading to ${p['name']}...';
                          });
                          try {
                            final res = await BackupService.upgradeStorageQuota(
                              p['code'] as String,
                              _currentOutletCode,
                            );
                            _showDialogMessage(
                              '✓ Storage expanded! Total allocation is now ${res['totalAllocatedPretty'] ?? 'expanded'}.',
                              type: 'SUCCESS',
                            );
                            widget.onRefreshParent();
                          } catch (err) {
                            _showDialogMessage('Upgrade failed: $err', type: 'ERROR');
                          }
                        },
                        child: const Text('Add Plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _showDialogMessage(String message, {String type = 'SUCCESS'}) {
    if (!mounted) return;
    setState(() {
      _dialogAlertMessage = message;
      _dialogAlertType = type;
      _isActionInProgress = false;
      _statusMessage = null;
    });
  }

  @override
  void initState() {
    super.initState();
    if (!AppConfig.isLocalServer) {
      _backupScope = 'OUTLET';
    }
    _backupsList = widget.initialData?['backupsList'] as List<dynamic>? ?? [];
    _loadCurrentOutletAndBackups();
  }

  Future<void> _loadCurrentOutletAndBackups() async {
    final code = await TokenStorage.getOutletCode();
    if (mounted) {
      setState(() {
        _currentOutletCode = code ?? (AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : 'DEFAULT');
      });
    }
    await _fetchUpdatedList();
  }

  Future<void> _fetchUpdatedList() async {
    try {
      final cloudItems = await BackupService.fetchCloudBackups(
        (AppConfig.isLocalServer && _backupScope == 'ALL') ? 'ALL' : _currentOutletCode,
      );
      if (cloudItems.isNotEmpty) {
        if (!mounted) return;
        final filtered = (!AppConfig.isLocalServer && _currentOutletCode != null && _currentOutletCode!.isNotEmpty)
            ? cloudItems.where((b) {
                final oCode = (b['outletCode'] ?? '').toString();
                return oCode == _currentOutletCode;
              }).toList()
            : cloudItems;
        setState(() {
          _backupsList = filtered;
        });
        return;
      }

      final res = await ApiClient.get(ApiEndpoints.storageStats, silent: true);
      if (res != null && res['success'] == true && res['data'] != null) {
        if (!mounted) return;
        setState(() {
          _backupsList = res['data']['backupsList'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _takeFambakBackup() async {
    final isAll = _backupScope == 'ALL';
    setState(() {
      _dialogAlertMessage = null;
      _isActionInProgress = true;
      _statusMessage = isAll
          ? 'Securing Complete Enterprise Database across all outlets into .fambak archive...'
          : 'Securing isolated snapshot for outlet ${_currentOutletCode ?? ""} into .fambak archive...';
    });

    try {
      final result = await BackupService.createFambakBackup(
        scope: _backupScope,
        outletCode: _currentOutletCode,
        saveToDrive: _saveToGoogleDrive,
        sendEmailLink: _emailDownloadLinkToOperator,
      );

      if (!mounted) return;
      final totalRec = result['totalRecords'] ?? 0;
      final filename = result['filename'] ?? 'backup.fambak';
      final driveMsg = result['driveStatus']?['message'];

      _showDialogMessage(
        isAll
            ? '✓ Enterprise backup created ($totalRec records)! Archive: $filename${driveMsg != null ? " • $driveMsg" : ""}'
            : '✓ Outlet backup created ($totalRec records)! Archive: $filename${driveMsg != null ? " • $driveMsg" : ""}',
        type: 'SUCCESS',
      );

      widget.onRefreshParent();
      await _fetchUpdatedList();
    } catch (e) {
      if (!mounted) return;
      _showDialogMessage('Backup creation failed: $e', type: 'ERROR');
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
          _statusMessage = null;
        });
      }
    }
  }

  /// Off-Server Disaster Recovery: Email signed 7-day download link
  Future<void> _showEmailBackupDialog(String filename, {String? scope}) async {
    final emailCtrl = TextEditingController();
    try {
      final user = await TokenStorage.getUser();
      if (user != null && user['email'] != null) {
        emailCtrl.text = user['email'].toString();
      }
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: Colors.blue.shade700, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Off-Site Disaster Recovery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We will send an email with a secure 7-day signed download link and bare-metal restoration commands.\n\n'
              'Download and keep this backup file on your local PC or USB disk so your business is safe even if your cloud server or droplet is destroyed.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Archive: $filename',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Recipient Email Address',
                hintText: 'admin@yourcompany.com',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send Recovery Email'),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address.')),
                );
                return;
              }
              Navigator.pop(dialogCtx);
              setState(() {
                _isActionInProgress = true;
                _statusMessage = 'Sending disaster recovery backup link to $email...';
              });
              try {
                final res = await BackupService.emailBackupLink(
                  filename: filename,
                  recipientEmail: email,
                  scope: scope ?? _backupScope,
                  outletCode: _currentOutletCode,
                );
                if (!mounted) return;
                final bool emailFailed = res['emailSent'] == false;
                _showDialogMessage(
                  res['message'] ?? (emailFailed ? 'Email delivery skipped: Please configure SMTP in Settings.' : 'Disaster recovery email sent successfully!'),
                  type: emailFailed ? 'WARNING' : 'SUCCESS',
                );
              } catch (e) {
                if (!mounted) return;
                _showDialogMessage('Failed to send email: $e', type: 'ERROR');
              } finally {
                if (mounted) {
                  setState(() {
                    _isActionInProgress = false;
                    _statusMessage = null;
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String downloadPath) async {
    final serverBase = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = downloadPath.startsWith('/') ? downloadPath : '/$downloadPath';
    final token = await TokenStorage.read();

    final separator = cleanPath.contains('?') ? '&' : '?';
    final tokenParam = (token != null && token.isNotEmpty && !cleanPath.contains('token='))
        ? '${separator}token=${Uri.encodeComponent(token)}'
        : '';
    final fullUrl = '$serverBase$cleanPath$tokenParam';

    setState(() {
      _isActionInProgress = true;
      _statusMessage = 'Downloading backup archive to local storage...';
    });

    try {
      if (!kIsWeb) {
        final uri = Uri.parse(fullUrl);
        final headers = <String, String>{};
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }

        final response = await http.get(uri, headers: headers);
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          Directory? targetDir;
          try {
            targetDir = await getDownloadsDirectory();
          } catch (_) {}
          targetDir ??= await getApplicationDocumentsDirectory();

          String filename = 'backup_${DateTime.now().millisecondsSinceEpoch}.fambak';
          final uriLast = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
          if (uriLast.isNotEmpty &&
              (uriLast.endsWith('.fambak') ||
                  uriLast.endsWith('.posbak') ||
                  uriLast.endsWith('.enc') ||
                  uriLast.endsWith('.zip'))) {
            filename = Uri.decodeComponent(uriLast);
          }

          final saveFile = File(p.join(targetDir.path, filename));
          await saveFile.writeAsBytes(response.bodyBytes);

          if (!mounted) return;
          _showDialogMessage('✓ Saved to Downloads: ${saveFile.path}', type: 'SUCCESS');
          return;
        }
      }

      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        _showDialogMessage('Could not open download link: $fullUrl', type: 'ERROR');
      }
    } catch (e) {
      try {
        final uri = Uri.parse(fullUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          _showDialogMessage('Download failed: $e', type: 'ERROR');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
          _statusMessage = null;
        });
      }
    }
  }

  /// Pre-inspects backup manifest and displays selective outlet restore dialog
  Future<void> _inspectAndRestore({String? filename, Uint8List? bytes, String? displayName}) async {
    setState(() {
      _isActionInProgress = true;
      _statusMessage = 'Pre-inspecting backup manifest and validating integrity...';
    });

    Map<String, dynamic> manifest;
    try {
      manifest = await BackupService.inspectBackup(filename: filename, bytes: bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isActionInProgress = false;
        _statusMessage = null;
      });
      _showDialogMessage('Inspection failed: $e', type: 'ERROR');
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
          _statusMessage = null;
        });
      }
    }

    if (!mounted) return;

    final nameToShow = displayName ?? filename ?? 'Uploaded Backup Archive';
    final outletsInBackup = (manifest['outlets'] as List<dynamic>?) ?? [];
    final manifestScope = (manifest['scope'] ?? 'OUTLET').toString().toUpperCase();
    final isEnterpriseBackup = manifestScope == 'ALL' || outletsInBackup.length > 1;

    String restoreChoice = isEnterpriseBackup ? 'SELECTIVE' : 'OUTLET';
    String? selectedSourceOutlet = outletsInBackup.isNotEmpty ? outletsInBackup.first['code']?.toString() : _currentOutletCode;
    String targetOutlet = _currentOutletCode ?? (selectedSourceOutlet ?? 'OUT_1');
    bool overwrite = false;

    final proceedResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_outlined, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pre-Restore Inspection',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Manifest Summary Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nameToShow,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isEnterpriseBackup ? Colors.green.shade50 : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isEnterpriseBackup ? Colors.green.shade300 : Colors.blue.shade300),
                                ),
                                child: Text(
                                  isEnterpriseBackup ? 'ENTERPRISE SCOPE' : 'OUTLET SCOPE',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isEnterpriseBackup ? Colors.green.shade800 : Colors.blue.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Format: ${manifest['format'] ?? 'FAMALTH_V3'} • Version: ${manifest['version'] ?? '3.0'} • Records: ${manifest['totalRecords'] ?? 0}',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          if (outletsInBackup.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text('Outlets Secured in Backup:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: outletsInBackup.map((o) {
                                final oCode = o['code'] ?? 'OUT';
                                final oName = o['name'] ?? '';
                                final oCount = o['recordCount'] ?? 0;
                                return Chip(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  label: Text('$oCode: $oName ($oCount rec)', style: const TextStyle(fontSize: 10.5)),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Restore Scope Selector
                    if (isEnterpriseBackup) ...[
                      const Text('Selective Outlet Restore:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        'This archive contains a complete multi-outlet dataset. Choose whether to restore all outlets or selectively ingest one outlet.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        value: 'SELECTIVE',
                        groupValue: restoreChoice,
                        onChanged: (val) => setDlgState(() => restoreChoice = val ?? 'SELECTIVE'),
                        title: const Text('Selective Outlet Restore (Recommended)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                        subtitle: const Text('Extracts and restores only a specific outlet from the complete archive into this local station.', style: TextStyle(fontSize: 11)),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (restoreChoice == 'SELECTIVE') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 32, bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: selectedSourceOutlet,
                                decoration: const InputDecoration(
                                  labelText: 'Source Outlet from Archive',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: outletsInBackup.map((o) {
                                  final code = (o['code'] ?? '').toString();
                                  final name = (o['name'] ?? '').toString();
                                  final count = o['recordCount'] ?? 0;
                                  return DropdownMenuItem<String>(
                                    value: code,
                                    child: Text('$code - $name ($count rows)', style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) => setDlgState(() {
                                  selectedSourceOutlet = val;
                                  if (val != null && targetOutlet.isEmpty) targetOutlet = val;
                                }),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: targetOutlet,
                                decoration: const InputDecoration(
                                  labelText: 'Target Local Outlet Code',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  helperText: 'Records will be mapped to this local outlet code.',
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: (val) => targetOutlet = val.trim(),
                              ),
                            ],
                          ),
                        ),
                      ],
                      RadioListTile<String>(
                        value: 'ALL',
                        groupValue: restoreChoice,
                        onChanged: (val) => setDlgState(() => restoreChoice = val ?? 'ALL'),
                        title: const Text('Restore Complete Database (All Outlets)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                        subtitle: const Text('Replaces or synchronizes all outlets, users, and multi-tenant catalogs.', style: TextStyle(fontSize: 11)),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 16),
                    ],

                    // Conflict Strategy
                    const Text('Conflict Strategy & Data Safety:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: overwrite,
                      onChanged: (val) => setDlgState(() => overwrite = val ?? false),
                      title: const Text('Safe Merge (Non-Destructive)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                      subtitle: const Text('• Preserves transactions recorded between backup time and now.\n• Safe for continuous operations.', style: TextStyle(fontSize: 11)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: overwrite,
                      onChanged: (val) => setDlgState(() => overwrite = val ?? true),
                      title: Text('Point-in-Time Rollback (Overwrite)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.red.shade700)),
                      subtitle: const Text('• Reverts target outlet cleanly back to snapshot state.\n• Safe transaction with automatic rollback if errors occur.', style: TextStyle(fontSize: 11)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: overwrite ? Colors.red.shade700 : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.settings_backup_restore, size: 18),
                label: Text(overwrite ? 'Confirm Rollback' : 'Proceed Safe Restore'),
                onPressed: () => Navigator.pop(ctx, {
                  'proceed': true,
                  'overwrite': overwrite,
                  'scope': restoreChoice,
                  'selectedOutletCode': selectedSourceOutlet,
                  'targetOutletCode': targetOutlet,
                }),
              ),
            ],
          );
        },
      ),
    );

    if (proceedResult == null || proceedResult['proceed'] != true) return;

    final bool isOverwrite = proceedResult['overwrite'] == true;
    final String chosenScope = proceedResult['scope'] ?? 'OUTLET';
    final String? chosenSourceOutlet = proceedResult['selectedOutletCode'];
    final String? chosenTargetOutlet = proceedResult['targetOutletCode'];

    setState(() {
      _isActionInProgress = true;
      _statusMessage = isOverwrite
          ? 'Executing transactional point-in-time rollback for outlet ${chosenTargetOutlet ?? ""}...'
          : 'Safely merging records inside database transaction...';
    });

    try {
      final restoreRes = await BackupService.restoreFambak(
        filename: filename,
        bytes: bytes,
        scope: chosenScope,
        selectedOutletCode: chosenSourceOutlet,
        targetOutletCode: chosenTargetOutlet,
        overwriteExisting: isOverwrite,
      );

      if (!mounted) return;
      final restoredOutlet = restoreRes['data']?['restoredOutletCode'] ?? chosenTargetOutlet ?? _currentOutletCode ?? 'DEFAULT';
      final totalRestored = restoreRes['data']?['totalRecordsRestored'] ?? 0;

      // Auto-Link on Sign-In
      await LocalPreferences.setLastOutletCode(restoredOutlet);
      if (!AppConfig.outlets.contains(restoredOutlet)) {
        AppConfig.outlets.insert(0, restoredOutlet);
        await AppConfig.saveConfig(AppConfig.baseUrl, AppConfig.outlets);
      }
      await TokenStorage.saveOutletCode(restoredOutlet);
      if (!mounted) return;

      _showDialogMessage(
        '✓ Restored $totalRestored records into outlet $restoredOutlet successfully! Switch outlet on Login to proceed.',
        type: 'SUCCESS',
      );

      widget.onRefreshParent();
      await _fetchUpdatedList();
    } catch (e) {
      if (!mounted) return;
      _showDialogMessage('Restore execution failed: $e', type: 'ERROR');
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _uploadAndRestoreExternalFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fambak', 'posbak', 'zip', 'enc', 'json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      Uint8List? bytes = pickedFile.bytes;

      if (bytes == null && pickedFile.path != null) {
        bytes = await File(pickedFile.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read backup file content.')),
        );
        return;
      }

      await _inspectAndRestore(
        bytes: bytes,
        displayName: pickedFile.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File picker error: $e')),
      );
    }
  }

  Future<void> _deleteBackupFile(String filename) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Backup Snapshot'),
        content: Text('Are you sure you want to permanently delete "$filename"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ApiClient.delete('/api/backup/${Uri.encodeComponent(filename)}');
      if (res != null && res['success'] == true) {
        if (!mounted) return;
        setState(() {
          _backupsList.removeWhere((item) => (item is Map && item['filename'] == filename));
        });
        _showDialogMessage('✓ ' + (res['message'] ?? 'Snapshot deleted successfully.'), type: 'SUCCESS');
        widget.onRefreshParent();
        await _fetchUpdatedList();
      } else {
        if (!mounted) return;
        _showDialogMessage(res?['message'] ?? 'Backup file not found or could not be removed.', type: 'ERROR');
      }
    } catch (e) {
      if (!mounted) return;
      _showDialogMessage('Delete error: $e', type: 'ERROR');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storage_rounded, color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Granular Backup, Cloud Storage & Restore',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConfig.isLocalServer
                              ? 'Export .fambak archives (Single Outlet or All Outlets), store to Famalth Lynx Cloud Storage, and safely restore with pre-inspection.'
                              : 'Export .fambak archives for your store (${_currentOutletCode ?? "Active"}), sync to Famalth Lynx Cloud Storage, and safely restore with pre-inspection.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (AppConfig.isLocalServer) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _dialogTab = 0),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _dialogTab == 0 ? const Color(0xFFEF4444) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Outlet Backups & Restore',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: _dialogTab == 0 ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() => _dialogTab = 1);
                            if (_adminOverview == null) {
                              _fetchAdminOverview();
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: _dialogTab == 1 ? const Color(0xFF0284C7) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings_rounded,
                                    size: 15,
                                    color: _dialogTab == 1 ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Admin Console (Clients & Storage)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: _dialogTab == 1 ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_dialogTab == 1) ...[
                // ADMIN CONSOLE: ALL CLIENTS & RUNNING PAID VERSIONS
                if (_isAdminOverviewLoading) ...[
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_adminOverview == null) ...[
                  Expanded(
                    child: Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Load Enterprise Storage Overview'),
                        onPressed: _fetchAdminOverview,
                      ),
                    ),
                  ),
                ] else ...[
                  // Metric Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Outlets', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${_adminOverview!['totalOutlets'] ?? 0} Active', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('Total Quota: ${_adminOverview!['totalAllocatedPretty'] ?? ""}', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Running Paid Add-ons', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${_adminOverview!['paidSubscriptionsCount'] ?? 0} Outlets', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                              Text('+${_adminOverview!['totalPaidAddonPretty'] ?? "0 GB"} Paid Storage', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly Add-on Revenue', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('₹${_adminOverview!['monthlyRecurringRevenue'] ?? 0} / mo', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                              Text('Active Recurring Plans', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Outlets Quota Table Header
                  Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      const Text('Client Outlets Storage Quotas & Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        tooltip: 'Refresh Outlets Data',
                        onPressed: _fetchAdminOverview,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Scrollable Outlets List
                  Expanded(
                    child: ListView.builder(
                      itemCount: (_adminOverview!['outlets'] as List? ?? []).length,
                      itemBuilder: (context, idx) {
                        final o = (_adminOverview!['outlets'] as List)[idx] as Map<String, dynamic>;
                        final oCode = (o['outletCode'] ?? '').toString();
                        final oName = (o['outletName'] ?? oCode).toString();
                        final totalUsed = (o['totalUsedPretty'] ?? '0 B').toString();
                        final totalAlloc = (o['totalAllocatedPretty'] ?? '15.00 GB').toString();
                        final usagePct = (o['usagePct'] as num?)?.toDouble() ?? 0.0;
                        final isPaid = o['isPaidPlan'] == true;
                        final isFrozen = o['isFrozen'] == true;
                        final planCode = (o['activePlanCode'] ?? 'STARTER_15GB').toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isFrozen
                                  ? Colors.red.shade300
                                  : (usagePct > 90 ? Colors.orange.shade300 : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPaid ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isPaid ? Icons.workspace_premium_rounded : Icons.store_rounded,
                                  color: isPaid ? Colors.purple : Colors.blue,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(oName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: isPaid ? Colors.purple.shade50 : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: isPaid ? Colors.purple.shade200 : Colors.blue.shade200),
                                          ),
                                          child: Text(
                                            isPaid ? 'Paid Addon ($planCode)' : '15GB Free Starter',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isPaid ? Colors.purple.shade700 : Colors.blue.shade700,
                                            ),
                                          ),
                                        ),
                                        if (isFrozen) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('FROZEN', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.red)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Code: $oCode • Used: $totalUsed of $totalAlloc (${usagePct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (usagePct / 100).clamp(0.01, 1.0),
                                    minHeight: 6,
                                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                    color: isFrozen ? Colors.red : (usagePct > 90 ? Colors.orange : const Color(0xFF059669)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.bolt_rounded, size: 14),
                                label: const Text('Increase Storage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _showAdminIncreaseStorageModal(o),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ] else ...[
                // Storage Quota Bar (Famalth Lynx Ecosystem)
              if (widget.initialData?['quota'] != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Famalth Lynx Storage: ${widget.initialData!['quota']['totalUsedPretty'] ?? "0 B"} of ${widget.initialData!['quota']['totalAllocatedPretty'] ?? "15.00 GB"} used (${widget.initialData!['quota']['usagePct'] ?? 0}%)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 14),
                        label: const Text('Get More Storage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _showUpgradeStorageModal,
                      ),
                    ],
                  ),
                ),
              ],

              // Backup Creation & Scope Selector Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, size: 16, color: Color(0xFFEF4444)),
                        const SizedBox(width: 6),
                        const Text('Backup Scope Selector:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _saveToGoogleDrive = !_saveToGoogleDrive),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _saveToGoogleDrive,
                                onChanged: (v) => setState(() => _saveToGoogleDrive = v ?? true),
                                activeColor: const Color(0xFF0284C7),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Text('Famalth Lynx Cloud Sync', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => setState(() => _emailDownloadLinkToOperator = !_emailDownloadLinkToOperator),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _emailDownloadLinkToOperator,
                                onChanged: (v) => setState(() => _emailDownloadLinkToOperator = v ?? true),
                                activeColor: Colors.indigo,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Text('Email Delivery (Off-Server)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Scope Radio Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _backupScope = 'OUTLET'),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _backupScope == 'OUTLET'
                                    ? (isDark ? const Color(0xFF0284C7).withValues(alpha: 0.2) : Colors.blue.shade50)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _backupScope == 'OUTLET' ? const Color(0xFF0284C7) : Colors.grey.shade300,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _backupScope == 'OUTLET' ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 16,
                                    color: _backupScope == 'OUTLET' ? const Color(0xFF0284C7) : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Particular Outlet (${_currentOutletCode ?? "Active"})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        Text('Isolated sales, items, customers, ledger & staff', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (AppConfig.isLocalServer) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _backupScope = 'ALL'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _backupScope == 'ALL'
                                      ? (isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _backupScope == 'ALL' ? Colors.green.shade600 : Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _backupScope == 'ALL' ? Icons.radio_button_checked : Icons.radio_button_off,
                                      size: 16,
                                      color: _backupScope == 'ALL' ? Colors.green.shade600 : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('All Outlets (Enterprise DB)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                                          Text('Complete multi-tenant catalogs & transactions', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Trigger Buttons Row (Restricted on Client PC)
                    if (AppConfig.isClientPc)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_clock_rounded, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Client Terminal Notice: Database backup & restore operations are restricted to the Main Server PC. Backups cannot be initiated from this client terminal.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.download_for_offline_rounded, size: 16),
                            label: Text(
                              _backupScope == 'ALL' ? 'Create Complete Enterprise Backup (.fambak)' : 'Create Outlet Backup (.fambak)',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            onPressed: _isActionInProgress ? null : _takeFambakBackup,
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Upload & Pre-Inspect Archive (.fambak)', style: TextStyle(fontSize: 12)),
                            onPressed: _isActionInProgress ? null : _uploadAndRestoreExternalFile,
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              if (_isActionInProgress) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage ?? 'Processing operation...',
                          style: TextStyle(color: Colors.blue.shade900, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Inline Dialog Result Banner (Clearly visible inside Dialog instead of hidden behind SnackBar)
              if (_dialogAlertMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _dialogAlertType == 'ERROR'
                        ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.25) : const Color(0xFFFEF2F2))
                        : (_dialogAlertType == 'WARNING'
                            ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.25) : const Color(0xFFFFFBEB))
                            : (_dialogAlertType == 'INFO'
                                ? (isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.25) : const Color(0xFFF0F9FF))
                                : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFECFDF5)))),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _dialogAlertType == 'ERROR'
                          ? const Color(0xFFEF4444)
                          : (_dialogAlertType == 'WARNING'
                              ? const Color(0xFFF59E0B)
                              : (_dialogAlertType == 'INFO'
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF10B981))),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        _dialogAlertType == 'ERROR'
                            ? Icons.error_rounded
                            : (_dialogAlertType == 'WARNING'
                                ? Icons.warning_rounded
                                : (_dialogAlertType == 'INFO'
                                    ? Icons.info_rounded
                                    : Icons.check_circle_rounded)),
                        size: 20,
                        color: _dialogAlertType == 'ERROR'
                            ? const Color(0xFFDC2626)
                            : (_dialogAlertType == 'WARNING'
                                ? const Color(0xFFD97706)
                                : (_dialogAlertType == 'INFO'
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF059669))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dialogAlertMessage!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _dialogAlertType == 'ERROR'
                                ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                : (_dialogAlertType == 'WARNING'
                                    ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E))
                                    : (_dialogAlertType == 'INFO'
                                        ? (isDark ? const Color(0xFF7DD3FC) : const Color(0xFF075985))
                                        : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46)))),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _dialogAlertMessage = null),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Disaster Recovery 3-2-1 Banner
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.indigo.withValues(alpha: 0.15) : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: Colors.indigo.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Disaster Recovery Tip: Never rely solely on cloud VPS or Droplet disks. Retain offline copies on your PC via emailed links or local downloads.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.indigo.shade200 : Colors.indigo.shade900),
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                children: [
                  Text(
                    'Cloud Snapshots & Backup History (${_backupsList.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Refresh snapshots',
                    onPressed: _fetchUpdatedList,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Backups List
              Expanded(
                child: _backupsList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No backup snapshots available yet.', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _backupsList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _backupsList[i] as Map<String, dynamic>;
                          final filename = (item['filename'] ?? 'snapshot.fambak').toString();
                          final sizePretty = (item['sizePretty'] ?? '').toString();
                          final timeAgo = (item['timeAgo'] ?? '').toString();
                          final downloadUrl = (item['downloadUrl'] ?? '').toString();
                          final scope = (item['scope'] ?? (filename.contains('all') || filename.contains('enterprise') ? 'ALL' : 'OUTLET')).toString().toUpperCase();
                          final outletCode = item['outletCode']?.toString() ?? '';
                          final storageLoc = item['storageLocation']?.toString() ?? 'LOCAL';

                          final isAll = scope == 'ALL';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isAll ? Colors.green.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isAll ? Icons.domain_rounded : Icons.store_rounded,
                                size: 20,
                                color: isAll ? Colors.green.shade700 : const Color(0xFF0284C7),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    filename,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAll ? Colors.green.shade100 : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isAll ? 'ENTERPRISE' : (outletCode.isNotEmpty ? outletCode : 'OUTLET'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: isAll ? Colors.green.shade900 : Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                                if (storageLoc == 'ENTERPRISE_CLOUD' || storageLoc == 'GOOGLE_DRIVE') ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      storageLoc == 'GOOGLE_DRIVE' ? 'DRIVE' : 'CLOUD',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '$sizePretty • $timeAgo',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.file_download_outlined, color: Colors.blue, size: 20),
                                  tooltip: 'Download Archive',
                                  onPressed: () => _downloadFile(downloadUrl),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.forward_to_inbox_rounded, color: Colors.indigo, size: 20),
                                  tooltip: 'Email Download Link (Off-Site Disaster Recovery)',
                                  onPressed: () => _showEmailBackupDialog(filename, scope: scope),
                                ),
                                if (!AppConfig.isClientPc) ...[
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade800,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    icon: const Icon(Icons.settings_backup_restore, size: 15),
                                    label: const Text('Inspect & Restore', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _inspectAndRestore(filename: filename),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    tooltip: 'Delete Snapshot',
                                    onPressed: () => _deleteBackupFile(filename),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}
