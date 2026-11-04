import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

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
    final downloads = await getDownloadsDirectory();
    final targetDir = downloads ?? await getApplicationDocumentsDirectory();
    final safeName = fileName.toLowerCase().endsWith('.enc')
        ? fileName
        : '${p.basenameWithoutExtension(fileName)}.enc';
    final filePath = p.join(targetDir.path, safeName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> restoreFromLocalEnc({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!fileName.toLowerCase().endsWith('.enc')) {
      throw Exception('Only .enc file is allowed');
    }
    await ApiClient.post(ApiEndpoints.restoreLocalEncBackup, {
      'filename': fileName,
      'base64': base64Encode(bytes),
    });
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
}
