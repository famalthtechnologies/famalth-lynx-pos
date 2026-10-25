import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
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
          // Header: "STORAGE" title matching Discourse
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

          // Multi-color segmented progress bar (Discourse red / coral / gray)
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
                      color: Color(0xFFEF4444), // Discourse style red/coral action link
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
  List<dynamic> _backupsList = [];

  @override
  void initState() {
    super.initState();
    _backupsList = widget.initialData?['backupsList'] as List<dynamic>? ?? [];
    _fetchUpdatedList();
  }

  Future<void> _fetchUpdatedList() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.storageStats, silent: true);
      if (res != null && res['success'] == true && res['data'] != null) {
        if (!mounted) return;
        setState(() {
          _backupsList = res['data']['backupsList'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _takeTenantBackup() async {
    setState(() {
      _isActionInProgress = true;
      _statusMessage = 'Securing outlet data & creating portable .posbak archive...';
    });

    try {
      final res = await ApiClient.post(ApiEndpoints.createTenantBackup, {});
      if (res != null && res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Tenant backup generated successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onRefreshParent();
        await _fetchUpdatedList();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?['message'] ?? 'Failed to create backup.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _downloadFile(String downloadPath) async {
    final serverBase = AppConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = downloadPath.startsWith('/') ? downloadPath : '/$downloadPath';
    final fullUrl = '$serverBase$cleanPath';

    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open download link: $fullUrl')),
      );
    }
  }

  Future<Map<String, dynamic>?> _showRestoreOptionsDialog(String filename) async {
    bool overwrite = false;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings_backup_restore, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Tenant Restore & Conflict Strategy', style: TextStyle(fontSize: 16))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Snapshot: "$filename"', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 12),
                const Text('How should existing records and newer transactions be handled?', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                RadioListTile<bool>(
                  value: false,
                  groupValue: overwrite,
                  onChanged: (val) => setDlgState(() => overwrite = val ?? false),
                  activeColor: Colors.blue.shade700,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Safe Merge (Non-Destructive)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: const Text(
                    '• Recommended for operational continuity.\n• Transactions recorded between backup time and now are safely preserved.\n• Only missing or deleted items are restored without ID conflicts.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                const Divider(height: 16),
                RadioListTile<bool>(
                  value: true,
                  groupValue: overwrite,
                  onChanged: (val) => setDlgState(() => overwrite = val ?? true),
                  activeColor: Colors.red.shade700,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Point-in-Time Rollback (Overwrite)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red.shade800)),
                  subtitle: const Text(
                    '• Reverts this outlet completely back to the snapshot state.\n• Discards transactions created after backup timestamp.\n• Other merchants and cloud outlets are 100% unaffected.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: overwrite ? Colors.red.shade700 : Colors.orange.shade800,
              ),
              onPressed: () => Navigator.pop(ctx, {'proceed': true, 'overwrite': overwrite}),
              child: Text(overwrite ? 'Confirm Rollback' : 'Proceed Safe Merge', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreExistingBackup(String filename) async {
    final decision = await _showRestoreOptionsDialog(filename);
    if (decision == null || decision['proceed'] != true) return;

    final bool overwrite = decision['overwrite'] == true;

    setState(() {
      _isActionInProgress = true;
      _statusMessage = overwrite
          ? 'Performing point-in-time rollback for this outlet...'
          : 'Safely merging backup records (preserving newer transactions)...';
    });

    try {
      final res = await ApiClient.post(ApiEndpoints.restoreTenantBackup, {
        'filename': filename,
        'overwriteExisting': overwrite,
      });

      if (res != null && res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Backup restored successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onRefreshParent();
        await _fetchUpdatedList();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?['message'] ?? 'Failed to restore backup.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
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
        allowedExtensions: ['zip', 'posbak', 'enc', 'json'],
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

      final decision = await _showRestoreOptionsDialog(pickedFile.name);
      if (decision == null || decision['proceed'] != true) return;

      final bool overwrite = decision['overwrite'] == true;
      final base64Payload = base64Encode(bytes);

      setState(() {
        _isActionInProgress = true;
        _statusMessage = overwrite
            ? 'Uploading and rolling back to external backup state...'
            : 'Uploading and safely merging external backup records...';
      });

      final res = await ApiClient.post(ApiEndpoints.restoreTenantBackup, {
        'filename': pickedFile.name,
        'base64': base64Payload,
        'overwriteExisting': overwrite,
      });

      if (res != null && res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'External backup migrated and restored successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onRefreshParent();
        await _fetchUpdatedList();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?['message'] ?? 'Migration restore failed.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File migration error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionInProgress = false;
          _statusMessage = null;
        });
      }
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
        // Immediate real-time UI removal
        setState(() {
          _backupsList.removeWhere((item) => (item is Map && item['filename'] == filename));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Snapshot deleted successfully.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        widget.onRefreshParent();
        await _fetchUpdatedList();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res?['message'] ?? 'Backup file not found or could not be removed.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete error: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
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
                          'Manage Backups & Cloud Migration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Export your outlet data, migrate between Cloud & Offline servers, or restore snapshots.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
              const SizedBox(height: 18),

              // Action Toolbar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.download_for_offline_rounded, size: 18),
                      label: const Text('Take Outlet Backup Now', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: _isActionInProgress ? null : _takeTenantBackup,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Upload & Restore File (.posbak)'),
                      onPressed: _isActionInProgress ? null : _uploadAndRestoreExternalFile,
                    ),
                  ],
                ),
              ),

              if (_isActionInProgress) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage ?? 'Processing operation...',
                          style: TextStyle(color: Colors.blue.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              Text(
                'Available Outlet Snapshots (${_backupsList.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

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
                          final filename = item['filename'] ?? 'snapshot.posbak';
                          final sizePretty = item['sizePretty'] ?? '';
                          final timeAgo = item['timeAgo'] ?? '';
                          final downloadUrl = item['downloadUrl'] ?? '';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF64748B)),
                            ),
                            title: Text(
                              filename,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$sizePretty • $timeAgo',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.file_download_outlined, color: Colors.blue),
                                  tooltip: 'Download Backup',
                                  onPressed: () => _downloadFile(downloadUrl),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.restore_page_outlined, color: Colors.orange),
                                  tooltip: 'Restore to this Outlet',
                                  onPressed: () => _restoreExistingBackup(filename),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Delete Snapshot',
                                  onPressed: () => _deleteBackupFile(filename),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
