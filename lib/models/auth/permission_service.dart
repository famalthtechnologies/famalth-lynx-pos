import 'package:retailpos/models/auth/permission_model.dart';
import '../../core/permissions/module_capability.dart';

class PermissionService {
  static UserPermission? user;

  static void init({
    required String role,
    required List<String> permissions,
  }) {
    user = UserPermission(
      role: role,
      permissions: permissions,
    );
  }

  static bool can(String permission, [String? currentModule]) {
    if (user == null) return false;

    final role = user!.role.toUpperCase().trim();
    if (role == 'ADMIN' || role == 'SUPERADMIN' || role == 'OWNER') return true;

    // Handle alternative permissions separated by '|' or ','
    if (permission.contains('|') || permission.contains(',')) {
      final perms = permission.split(RegExp(r'[,|]')).map((e) => e.trim()).where((e) => e.isNotEmpty);
      return perms.any((p) => can(p, currentModule));
    }

    if (currentModule != null && currentModule.isNotEmpty) {
      if (!ModuleCapability.isPermissionAllowed(permission, currentModule)) {
        return false;
      }
    }

    final pUpper = permission.trim().toUpperCase();

    // If user has Full Access Clinic permission, grant access to all clinic features
    if (user!.permissions.contains('CLINIC_MODULE')) {
      if (pUpper.startsWith('CLINIC_') ||
          pUpper == 'PRESCRIPTIONS' ||
          pUpper == 'DOCTOR_CONSULTATION' ||
          (pUpper == 'POS_SALE' && ModuleCapability.hasClinic(currentModule))) {
        return true;
      }
    }

    // Role-based fallbacks for Doctor / Clinician / Receptionist / Pharmacist
    if (role.contains('DOCTOR') || role.contains('CLINICIAN') || role.contains('PHYSICIAN')) {
      if (pUpper == 'DOCTOR_CONSULTATION' ||
          pUpper == 'CLINIC_APPOINTMENTS' ||
          pUpper == 'PRESCRIPTIONS' ||
          pUpper == 'CLINIC_MODULE' ||
          pUpper == 'POS_SALE') {
        return true;
      }
    }
    if (role.contains('RECEPTION') || role.contains('FRONTDESK')) {
      if (pUpper == 'CLINIC_APPOINTMENTS' || pUpper == 'CLINIC_MODULE') {
        return true;
      }
    }
    if (role.contains('PHARMAC')) {
      if (pUpper == 'CLINIC_PHARMACY' || pUpper == 'CLINIC_MODULE') {
        return true;
      }
    }

    return user!.permissions.contains(pUpper) || user!.permissions.contains('ALL');
  }
}

