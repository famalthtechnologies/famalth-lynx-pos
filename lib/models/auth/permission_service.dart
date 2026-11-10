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

    // Check if user has specific clinic sub-permissions defined in their permissions list
    final hasSpecificClinicSubPerms = user!.permissions.any((p) {
      final u = p.toUpperCase().trim();
      return u == 'CLINIC_APPOINTMENTS' ||
          u == 'DOCTOR_CONSULTATION' ||
          u == 'PRESCRIPTIONS' ||
          u == 'CLINIC_PHARMACY' ||
          u == 'CLINIC_THERAPY' ||
          u == 'CLINIC_ANALYTICS';
    });

    // If user has Full Access Clinic permission, grant access to clinic features only if no specific sub-permissions restrict them
    if (user!.permissions.contains('CLINIC_MODULE')) {
      if (!hasSpecificClinicSubPerms) {
        if (pUpper.startsWith('CLINIC_') ||
            pUpper == 'PRESCRIPTIONS' ||
            pUpper == 'DOCTOR_CONSULTATION' ||
            (pUpper == 'POS_SALE' && ModuleCapability.hasClinic(currentModule))) {
          return true;
        }
      } else {
        // If specific sub-permissions are assigned, base CLINIC_MODULE only grants entry to the clinic shell
        if (pUpper == 'CLINIC_MODULE') {
          return true;
        }
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

