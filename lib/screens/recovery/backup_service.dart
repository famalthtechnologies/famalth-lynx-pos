import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/auth/token_storage.dart';
import '../../core/utils/file_download_helper.dart';
import 'package:http/http.dart' as http;

class BackupService {
  static Future<String> checkStatus() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.backupStatus);

      if (res['success'] == true) {
        return res['alert'] ?? 'NONE';
      }

      return 'NONE';
    } catch (e) {
      debugPrint("Error checking backup status: $e");
      return 'NONE';
    }
  }

  static Future<Map<String, dynamic>> checkDetailedStatus() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.backupStatus);
      if (res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      return const {};
    } catch (e) {
      debugPrint("Error checking detailed backup status: $e");
      return const {};
    }
  }

  static Future<bool> syncLatest() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.syncLatest);

      if (res['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error syncing database: $e");
      return false;
    }
  }

  static Future<bool> uploadLatest() async {
    try {
      final res = await ApiClient.post(ApiEndpoints.uploadLatest, {});

      if (res['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error uploading database: $e");
      return false;
    }
  }

  static Future<bool> toggleCloudSync(bool enable) async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.toggleBackup,
        {'enabled': enable},
      );

      if (res['success'] == true) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Error toggling backup: $e");
      return false;
    }
  }

  static Future<String> createAndSaveLocalEncBackup() async {
    final res = await ApiClient.get(ApiEndpoints.localEncBackup);
    final data = Map<String, dynamic>.from(res['data'] ?? const {});
    final fileName = (data['filename'] ?? 'backup.enc').toString();
    final base64Payload = (data['base64'] ?? '').toString();
    if (base64Payload.isEmpty) {
      throw Exception('Backup payload is empty');
    }

    final bytes = base64Decode(base64Payload);
    final safeName = fileName.toLowerCase().endsWith('.enc')
        ? fileName
        : '${p.basenameWithoutExtension(fileName)}.enc';

    final saved = await saveOrDownloadBinaryFile(filename: safeName, bytes: bytes);
    return saved ?? safeName;
  }

  static Future<String> createAndSaveLocalFambakBackup({
    String scope = 'OUTLET',
    String? outletCode,
  }) async {
    final result = await createFambakBackup(
      scope: scope,
      outletCode: outletCode,
      saveToDrive: false,
    );
    final filename = (result['filename'] ?? 'backup.fambak').toString();
    final downloadUrl = (result['downloadUrl'] ?? '').toString();

    if (!kIsWeb) {
      try {
        final localServerFile = File(p.join(Directory.current.path, 'backups', filename));
        if (await localServerFile.exists()) {
          final downloads = await getDownloadsDirectory();
          final targetDir = downloads ?? await getApplicationDocumentsDirectory();
          final targetPath = p.join(targetDir.path, filename);
          await localServerFile.copy(targetPath);
          return targetPath;
        }
      } catch (_) {}
    }

    if (downloadUrl.isNotEmpty) {
      final token = await TokenStorage.read();
      final fullUrl = downloadUrl.startsWith('http')
          ? downloadUrl
          : '${AppConfig.baseUrl}$downloadUrl';
      final uri = Uri.parse(fullUrl);
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final saved = await saveOrDownloadBinaryFile(filename: filename, bytes: response.bodyBytes);
        return saved ?? filename;
      }
    }

    return filename;
  }

  static Future<Map<String, dynamic>> restoreFromLocalEnc({
    required String fileName,
    required List<int> bytes,
  }) async {
    final lower = fileName.toLowerCase();
    if (!lower.endsWith('.enc') && !lower.endsWith('.fambak') && !lower.endsWith('.posbak')) {
      throw Exception('Only .fambak, .posbak, or .enc backup file is allowed');
    }
    final res = await ApiClient.post(ApiEndpoints.restoreLocalEncBackup, {
      'filename': fileName,
      'base64': base64Encode(bytes),
    });
    return Map<String, dynamic>.from(res is Map ? res : {});
  }

  /// Create Granular .fambak archive backup (All Outlets or Scoped Outlet)
  static Future<Map<String, dynamic>> createFambakBackup({
    required String scope, // 'ALL' or 'OUTLET'
    String? outletCode,
    int? outletId,
    bool saveToDrive = true,
    bool saveToLocalDownloads = true,
    bool sendEmailLink = false,
    String? recipientEmail,
  }) async {
    final res = await ApiClient.post(ApiEndpoints.createFambakBackup, {
      'scope': scope,
      'outletCode': outletCode,
      'outletId': outletId,
      'saveToDrive': saveToDrive,
      'sendEmailLink': sendEmailLink,
      if (recipientEmail != null && recipientEmail.isNotEmpty)
        'recipientEmail': recipientEmail,
    });

    if (res['success'] != true || res['data'] == null) {
      throw Exception(res['message'] ?? 'Failed to create .fambak backup archive');
    }

    final data = Map<String, dynamic>.from(res['data']);
    // data contains backup archive filename

    if (saveToLocalDownloads) {
      try {
        final downloadUrl = data['downloadUrl']?.toString();
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          // If downloadable, we can query it or if it has bytes/file
          final fileRes = await ApiClient.get(downloadUrl);
          if (fileRes != null) {
            // saved on server
          }
        }
      } catch (_) {}
    }

    return data;
  }

  /// Pre-inspect backup manifest (.fambak, .posbak, .zip, .enc, .json)
  static Future<Map<String, dynamic>> inspectBackup({
    String? filename,
    List<int>? bytes,
  }) async {
    final payload = <String, dynamic>{};
    if (filename != null && filename.isNotEmpty) {
      payload['filename'] = filename;
    }
    if (bytes != null && bytes.isNotEmpty) {
      payload['base64'] = base64Encode(bytes);
    }

    final res = await ApiClient.post(ApiEndpoints.inspectBackup, payload);
    if (res['success'] != true || res['manifest'] == null) {
      throw Exception(res['message'] ?? 'Failed to inspect backup manifest');
    }

    return Map<String, dynamic>.from(res['manifest']);
  }

  /// Upgraded Granular Restore (.fambak) with Selective Outlet & Conflict Strategy
  static Future<Map<String, dynamic>> restoreFambak({
    String? filename,
    List<int>? bytes,
    required String scope,
    String? selectedOutletCode,
    int? targetOutletId,
    String? targetOutletCode,
    bool overwriteExisting = false,
  }) async {
    final payload = <String, dynamic>{
      'scope': scope,
      'overwriteExisting': overwriteExisting,
    };
    if (filename != null && filename.isNotEmpty) {
      payload['filename'] = filename;
    }
    if (bytes != null && bytes.isNotEmpty) {
      payload['base64'] = base64Encode(bytes);
    }
    if (selectedOutletCode != null && selectedOutletCode.isNotEmpty) {
      payload['selectedOutletCode'] = selectedOutletCode;
    }
    if (targetOutletId != null) {
      payload['targetOutletId'] = targetOutletId;
    }
    if (targetOutletCode != null && targetOutletCode.isNotEmpty) {
      payload['targetOutletCode'] = targetOutletCode;
    }

    final res = await ApiClient.post(ApiEndpoints.restoreFambak, payload);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to restore .fambak archive');
    }

    return Map<String, dynamic>.from(res);
  }

  /// Fetch Cloud Backups History List
  static Future<List<Map<String, dynamic>>> fetchCloudBackups([String? outletCode]) async {
    try {
      final query = outletCode != null && outletCode.isNotEmpty ? '?outlet_code=$outletCode' : '';
      final res = await ApiClient.get('${ApiEndpoints.cloudBackups}$query', silent: true);
      if (res != null && res['success'] == true && res['data'] is List) {
        return (res['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('fetchCloudBackups error: ');
      return [];
    }
  }

  /// 1-Click Restore Cloud Backup Snapshot
  static Future<Map<String, dynamic>> restoreCloudBackup({
    required String filename,
    required String scope,
    String? selectedOutletCode,
    int? targetOutletId,
    String? targetOutletCode,
    bool overwriteExisting = false,
  }) async {
    return restoreFambak(
      filename: filename,
      scope: scope,
      selectedOutletCode: selectedOutletCode,
      targetOutletId: targetOutletId,
      targetOutletCode: targetOutletCode,
      overwriteExisting: overwriteExisting,
    );
  }

  /// Off-Server Disaster Recovery: Email signed 7-day download link to operator
  static Future<Map<String, dynamic>> emailBackupLink({
    required String filename,
    String? recipientEmail,
    String? scope,
    String? outletCode,
  }) async {
    final payload = <String, dynamic>{
      'filename': filename,
    };
    if (recipientEmail != null && recipientEmail.trim().isNotEmpty) {
      payload['recipientEmail'] = recipientEmail.trim();
    }
    if (scope != null && scope.trim().isNotEmpty) {
      payload['scope'] = scope.trim();
    }
    if (outletCode != null && outletCode.trim().isNotEmpty) {
      payload['outletCode'] = outletCode.trim();
    }

    final res = await ApiClient.post(ApiEndpoints.emailBackupLink, payload);
    if (res['success'] != true) {
      throw Exception(res['message'] ?? 'Failed to email backup download link');
    }
    return Map<String, dynamic>.from(res);
  }

  /// Data Retention Policy: Dry-Run Preview of matching records
  static Future<Map<String, dynamic>> previewRetentionPurge({
    String? dateFilterType,
    int? olderThanYears,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? modules,
    bool allOutlets = false,
    String? outletCode,
  }) async {
    final payload = <String, dynamic>{
      'dry_run': true,
      'date_filter_type': dateFilterType ?? 'OLDER_THAN',
      'older_than_years': olderThanYears ?? 5,
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
      if (modules != null && modules.isNotEmpty) 'modules': modules,
      if (outletCode != null && outletCode.isNotEmpty) 'outlet_code': outletCode,
      'allOutlets': allOutlets,
    };

    final url = allOutlets
        ? ApiEndpoints.providerRetentionPreview
        : ApiEndpoints.clearTransactionData;

    final res = await ApiClient.post(url, payload);
    if (res != null && res['success'] == true) {
      return Map<String, dynamic>.from(res['preview'] ?? const {});
    }
    throw Exception(res?['message'] ?? 'Failed to preview retention matching records');
  }

  /// Data Retention Policy: Execute Scoped Pruning with Mandatory / Auto Safety Backup
  static Future<Map<String, dynamic>> executeRetentionPurge({
    required String confirmText,
    String? dateFilterType,
    int? olderThanYears,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? modules,
    bool backupFirst = true,
    String? recipientEmail,
    bool allOutlets = false,
    String? outletCode,
  }) async {
    final payload = <String, dynamic>{
      'confirm_text': confirmText,
      'confirmText': confirmText,
      'date_filter_type': dateFilterType ?? 'OLDER_THAN',
      'older_than_years': olderThanYears ?? 5,
      'olderThanYears': olderThanYears ?? 5,
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (modules != null && modules.isNotEmpty) 'modules': modules,
      'backup_first': backupFirst,
      'createBackupFirst': backupFirst,
      if (recipientEmail != null && recipientEmail.trim().isNotEmpty)
        'recipient_email': recipientEmail.trim(),
      if (recipientEmail != null && recipientEmail.trim().isNotEmpty)
        'recipientEmail': recipientEmail.trim(),
      if (outletCode != null && outletCode.isNotEmpty) 'outlet_code': outletCode,
      'allOutlets': allOutlets,
    };

    final url = allOutlets
        ? ApiEndpoints.providerRetentionPurge
        : ApiEndpoints.clearTransactionData;

    final res = await ApiClient.post(url, payload);
    if (res != null && res['success'] == true) {
      return Map<String, dynamic>.from(res);
    }
    throw Exception(res?['message'] ?? 'Failed to execute retention purge');
  }

  /// Famalth Lynx Metered Cloud/Offline Storage Quota (GET /api/backup/storage-quota)
  static Future<Map<String, dynamic>> fetchStorageQuota([String? outletCode]) async {
    try {
      final query = outletCode != null && outletCode.isNotEmpty
          ? '?outlet_code=${Uri.encodeComponent(outletCode)}'
          : '';
      final res = await ApiClient.get('${ApiEndpoints.storageQuota}$query');
      if (res != null && res['success'] == true && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
    } catch (_) {}
    return {};
  }

  /// 1-Click Monthly Storage Expansion (POST /api/backup/storage-quota/upgrade)
  static Future<Map<String, dynamic>> upgradeStorageQuota(String addonPlanCode, [String? outletCode]) async {
    final payload = {
      'addon_plan_code': addonPlanCode,
      if (outletCode != null && outletCode.isNotEmpty) 'outlet_code': outletCode,
    };
    final res = await ApiClient.post(ApiEndpoints.storageQuotaUpgrade, payload);
    if (res != null && res['success'] == true) {
      return Map<String, dynamic>.from(res);
    }
    throw Exception(res?['message'] ?? 'Failed to upgrade storage quota');
  }

  /// Admin Console: Get All Clients Storage Usage & Paid Addons Overview
  static Future<Map<String, dynamic>> fetchAdminStorageOverview() async {
    final res = await ApiClient.get(ApiEndpoints.adminStorageOverview);
    if (res != null && res['success'] == true && res['data'] != null) {
      return Map<String, dynamic>.from(res['data']);
    }
    throw Exception(res?['message'] ?? 'Failed to load enterprise storage overview');
  }

  /// Admin Console: Manually Increase / Grant Storage Quota to Any Client
  static Future<Map<String, dynamic>> adminModifyStorage({
    required String outletCode,
    required String action, // 'ADD_GB', 'SET_TOTAL_GB', 'ADD_BONUS_GB', 'FREEZE', 'UNFREEZE'
    double? additionalGb,
    double? totalGb,
    String? notes,
  }) async {
    final payload = {
      'outlet_code': outletCode,
      'action': action,
      if (additionalGb != null) 'additional_gb': additionalGb,
      if (totalGb != null) 'total_gb': totalGb,
      if (notes != null) 'notes': notes,
    };
    final res = await ApiClient.post(ApiEndpoints.adminModifyStorage, payload);
    if (res != null && res['success'] == true) {
      return Map<String, dynamic>.from(res);
    }
    throw Exception(res?['message'] ?? 'Failed to modify outlet storage');
  }

  /// Automatic Storage Increment on Payment Success
  static Future<Map<String, dynamic>> processStoragePaymentSuccess({
    required String outletCode,
    required String planCode,
    double? amount,
    String? transactionId,
  }) async {
    final payload = {
      'outlet_code': outletCode,
      'plan_code': planCode,
      if (amount != null) 'amount': amount,
      if (transactionId != null) 'transaction_id': transactionId,
    };
    final res = await ApiClient.post(ApiEndpoints.storagePaymentSuccess, payload);
    if (res != null && res['success'] == true) {
      return Map<String, dynamic>.from(res);
    }
    throw Exception(res?['message'] ?? 'Failed to process storage payment');
  }
}
