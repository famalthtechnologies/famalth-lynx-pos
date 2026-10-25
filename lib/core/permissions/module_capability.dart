class ModuleCapability {
  ModuleCapability._();

  static const String inventory = 'INVENTORY';
  static const String retail = 'RETAIL';
  static const String restaurant = 'RESTAURANT';
  static const String clinic = 'CLINIC';
  static const String hrms = 'HRMS';
  static const String all = 'ALL';

  /// Normalizes module input string or returns a list of active modules
  static String normalize(String? rawModule) {
    if (rawModule == null || rawModule.trim().isEmpty) return all;
    final upper = rawModule.trim().toUpperCase();

    // Multi-module list preserved if comma-separated
    if (upper.contains(',')) return upper;

    if (upper.contains('RESTAURANT') || upper.contains('KDS') || upper.contains('KOT') || upper.contains('CAFE') || upper.contains('BAR')) {
      return restaurant;
    }
    if (upper.contains('CLINIC') || upper.contains('DOCTOR') || upper.contains('HOSPITAL')) {
      return clinic;
    }
    if (upper.contains('HRMS') || upper.contains('ATTENDANCE') || upper.contains('PAYROLL')) {
      return hrms;
    }
    if (upper.contains('RETAIL') || upper.contains('POS') || upper.contains('KIRANA') || upper.contains('MART')) {
      return retail;
    }
    if (upper.contains('INVENTORY') || upper.contains('WAREHOUSE')) {
      return inventory;
    }
    if (upper.contains('ALL')) {
      return all;
    }
    return upper;
  }

  /// Checks if Inventory module is supported (Items, Stock, Batches, Receiving, PO, Suppliers, Expiry)
  /// Inventory is supported in INVENTORY, RETAIL, RESTAURANT, CLINIC, and ALL.
  /// Hidden ONLY if the account is purely dedicated to HRMS.
  static bool hasInventory([String? module]) {
    final mod = normalize(module);
    if (mod == all) return true;
    if (mod == hrms) return false;
    return true;
  }

  /// Checks if Retail Sale / POS & Customer Delivery features are supported
  static bool hasRetail([String? module]) {
    final mod = normalize(module);
    if (mod == all) return true;
    return mod.contains(retail) || mod.contains('POS');
  }

  /// Checks if Billing / Cashier Counter feature is supported
  /// Supported in Retail, Restaurant, Clinic, and ALL.
  /// Hidden in INVENTORY ONLY and HRMS ONLY.
  static bool hasBilling([String? module]) {
    final mod = normalize(module);
    if (mod == all) return true;
    if (mod == inventory || mod == hrms) return false;
    return mod.contains(retail) || mod.contains(restaurant) || mod.contains(clinic) || mod.contains('POS') || mod.contains('BILLING');
  }

  /// Checks if Restaurant dining (Tables, KOT, KDS, Waiter, Captain) is supported
  static bool hasRestaurant([String? module]) {
    final mod = normalize(module);
    if (mod == all) return true;
    return mod.contains(restaurant) || mod.contains('KDS') || mod.contains('KOT') || mod.contains('DINING');
  }

  /// Checks if Clinic & Healthcare features (Doctors, Appointments, Prescriptions, Medical Reports) are supported
  static bool hasClinic([String? module]) {
    final mod = normalize(module);
    if (mod == all) return true;
    return mod.contains(clinic) || mod.contains('DOCTOR') || mod.contains('HEALTH');
  }

  /// Checks if HRMS & Attendance System features are supported
  static bool hasHrms([String? module]) {
    final mod = normalize(module);
    if (mod == all) return true;
    return mod.contains(hrms) || mod.contains('ATTENDANCE') || mod.contains('PAYROLL') || mod.contains('HR');
  }

  /// Stock Transfer: Retailers & ALL only. Hidden in Inventory only, Restaurant only, Clinic, or HRMS.
  static bool isStockTransferAllowed(String? module) {
    final mod = normalize(module);
    if (mod == all) return true;
    return mod.contains(retail);
  }

  /// Product Assembly / Recipe: Allowed in Retail, Restaurant, Clinic, and ALL. Hide in Inventory only or HRMS only.
  static bool isAssemblyAllowed(String? module) {
    final mod = normalize(module);
    if (mod == all) return true;
    return mod != inventory && mod != hrms;
  }

  /// Gets display label for Product Assembly / Recipe
  static String? getAssemblyLabel(String? module) {
    final mod = normalize(module);
    if (hasRestaurant(mod)) return 'Recipe Management';
    if (mod == inventory || mod == hrms) return null;
    return 'Product Assembly';
  }

  /// Lucky Draw Campaign: Retailer, Restaurant & ALL. Hide in Inventory only or HRMS.
  static bool isLuckyDrawAllowed(String? module) {
    final mod = normalize(module);
    if (mod == all) return true;
    return mod != inventory && mod != hrms && mod != clinic;
  }

  /// Reprint / Modify Sales Bill: Allowed wherever Billing is enabled.
  static bool isReprintSalesAllowed(String? module) {
    return hasBilling(module);
  }

  /// Document sequence module filtering
  static bool isSequenceAllowed(String sequenceModule, String? module) {
    final mod = normalize(module);
    final seqUpper = sequenceModule.toUpperCase();
    if (mod == all) return true;

    if (mod == inventory || mod == hrms) {
      if (seqUpper == 'SALES' || seqUpper == 'KOT' || seqUpper == 'APPOINTMENT') return false;
    }

    if (!hasRestaurant(mod) && seqUpper == 'KOT') {
      return false;
    }

    if (!hasClinic(mod) && seqUpper == 'APPOINTMENT') {
      return false;
    }

    return true;
  }

  /// Reports & Analytics visibility check
  static bool isReportAllowed(String reportKey, String? module) {
    final mod = normalize(module);
    final keyUpper = reportKey.toUpperCase();
    if (mod == all) return true;

    if (mod == inventory || mod == hrms) {
      const inventoryHiddenReports = {
        'STOCK_TRANSFER',
        'SCHEME',
        'LOYALTY',
        'STORE_ANALYSIS',
        'BRAND_ANALYSIS',
        'SALE_SOURCE',
        'COMMISSION',
        'PAYMENT_METHOD',
        'FINANCE_HUB',
        'RETAIL_SALES',
        'DAILY_CLOSING',
      };
      if (inventoryHiddenReports.contains(keyUpper)) return false;
    }

    if (!hasRestaurant(mod)) {
      if (keyUpper.contains('RESTAURANT') || keyUpper.contains('KOT') || keyUpper.contains('KDS') || keyUpper.contains('TABLE')) {
        return false;
      }
    }

    if (!hasClinic(mod)) {
      if (keyUpper.contains('CLINIC') || keyUpper.contains('DOCTOR') || keyUpper.contains('APPOINTMENT') || keyUpper.contains('PRESCRIPTION')) {
        return false;
      }
    }

    return true;
  }

  /// Checks if a permission key is allowed under the current business module
  static bool isPermissionAllowed(String? permissionKey, String? module) {
    if (permissionKey == null || permissionKey.isEmpty) return true;
    final key = permissionKey.toUpperCase();
    final mod = normalize(module);

    if (mod == all) return true;

    // Rules for Stock Transfer
    if (key.contains('STOCK_TRANSFER') || key.contains('TRANSFER')) {
      if (!isStockTransferAllowed(mod)) return false;
    }

    // Rules for Assembly / Recipe
    if (key.contains('ASSEMBLY') || key.contains('RECIPE')) {
      if (!isAssemblyAllowed(mod)) return false;
    }

    // Rules for Lucky Draw
    if (key.contains('LUCKY_DRAW')) {
      if (!isLuckyDrawAllowed(mod)) return false;
    }

    // Rules for Sales Reprint / Modify
    if (key.contains('REPRINT_SALES') || key.contains('MODIFY_SALES')) {
      if (!isReprintSalesAllowed(mod)) return false;
    }

    // Retail specific permissions
    const retailPermissions = {
      'CUSTOMER_APP',
      'RETAILER_CONSOLE',
      'RIDER_PORTAL',
      'STORE_ANALYSIS',
      'BRAND_ANALYSIS',
    };

    // Restaurant specific permissions
    const restaurantPermissions = {
      'RESTAURANT_CONSOLE',
      'RESTAURANT_FLOOR_DESIGN',
      'RESTAURANT_KDS',
      'RESTAURANT_SETUP',
    };

    // Clinic specific permissions
    const clinicPermissions = {
      'CLINIC_MODULE',
      'CLINIC_APPOINTMENTS',
      'DOCTOR_CONSULTATION',
      'PRESCRIPTIONS',
    };

    // HRMS specific permissions
    const hrmsPermissions = {
      'HRMS_MODULE',
      'EMPLOYEE_MASTER',
      'ATTENDANCE',
      'PAYROLL',
    };

    if (retailPermissions.contains(key) && !hasRetail(mod)) {
      return false;
    }

    if (restaurantPermissions.contains(key) && !hasRestaurant(mod)) {
      return false;
    }

    if (clinicPermissions.contains(key) && !hasClinic(mod)) {
      return false;
    }

    if (hrmsPermissions.contains(key) && !hasHrms(mod)) {
      return false;
    }

    return true;
  }

  /// Dynamically adapts labels for Restaurant/Inventory/Clinic modules
  static String adaptLabel(String label, String? module) {
    final mod = normalize(module);
    if (hasRestaurant(mod)) {
      if (label.toUpperCase().contains('ASSEMBLY')) {
        return getAssemblyLabel(mod) ?? label;
      }
      if (label.contains('Supplier / Retailer Console')) {
        return 'Supplier & Kitchen Console';
      }
      if (label.contains('Retailer Console')) {
        return 'Restaurant Console';
      }
      if (label.contains('Retail Sales')) {
        return 'Dining & Restaurant Sales';
      }
      if (label.contains('Retail POS')) {
        return 'Restaurant POS';
      }
      if (label.contains('Retailer')) {
        return label.replaceAll('Retailer', 'Restaurant');
      }
    }
    if (hasClinic(mod) && !hasRetail(mod)) {
      if (label.contains('Retail POS')) {
        return 'Pharmacy & Clinic Billing';
      }
      if (label.contains('Billing (POS)')) {
        return 'Pharmacy Billing (POS)';
      }
      if (label.contains('Retailer')) {
        return label.replaceAll('Retailer', 'Clinic');
      }
    }
    if (mod == inventory) {
      if (label.contains('Retailer')) {
        return label.replaceAll('Retailer', 'Inventory');
      }
    }
    return label;
  }

  /// Filters drawer menu items dynamically based on module access
  static List<Map<String, dynamic>> filterDrawerItems(
      List<Map<String, dynamic>> items, String? module) {
    final mod = normalize(module);
    if (mod == all) return items;

    return items.where((item) {
      final String? perm = item['permission']?.toString();
      final String? category = item['category']?.toString();
      final String? label = item['label']?.toString();

      if (perm != null && perm.isNotEmpty) {
        if (!isPermissionAllowed(perm, mod)) return false;
      }

      if (category != null) {
        final catUpper = category.toUpperCase();
        if (catUpper.contains('RESTAURANT') && !hasRestaurant(mod)) return false;
        if ((catUpper.contains('CLINIC') || catUpper.contains('HEALTH')) && !hasClinic(mod)) return false;
        if ((catUpper.contains('HR') || catUpper.contains('PAYROLL')) && !hasHrms(mod)) return false;
        if (catUpper.contains('BILLING') && !hasBilling(mod)) return false;
        if (catUpper.contains('INNOVATION') && mod == hrms) return false;
      }

      if (label != null) {
        final labelUpper = label.toUpperCase();

        // Stock Transfer check
        if (labelUpper.contains('STOCK TRANSFER') && !isStockTransferAllowed(mod)) {
          return false;
        }

        // Product Assembly check
        if ((labelUpper.contains('ASSEMBLY') || labelUpper.contains('RECIPE')) &&
            !isAssemblyAllowed(mod)) {
          return false;
        }

        // Lucky Draw check
        if (labelUpper.contains('LUCKY DRAW') && !isLuckyDrawAllowed(mod)) {
          return false;
        }

        // Billing / POS checks
        if ((labelUpper.contains('BILLING (POS)') ||
                labelUpper.contains('DRAFT & HOLD BILLS') ||
                labelUpper.contains('MODIFY BILLS')) &&
            !hasBilling(mod)) {
          return false;
        }

        // Sales Bill Reprint / Modify check
        if ((labelUpper.contains('REPRINT') ||
                labelUpper.contains('SALES BILL') ||
                labelUpper.contains('MODIFY SALES')) &&
            !isReprintSalesAllowed(mod)) {
          return false;
        }

        // Restaurant checks
        if ((labelUpper.contains('KDS') ||
                labelUpper.contains('RESTAURANT') ||
                labelUpper.contains('CAPTAIN') ||
                labelUpper.contains('FLOOR PLAN') ||
                labelUpper.contains('KOT') ||
                labelUpper.contains('TABLE RESERVATION') ||
                labelUpper.contains('WAITER FLOOR')) &&
            !hasRestaurant(mod)) {
          return false;
        }

        // Clinic checks
        if ((labelUpper.contains('CLINIC') ||
                labelUpper.contains('DOCTOR') ||
                labelUpper.contains('APPOINTMENT') ||
                labelUpper.contains('PRESCRIPTION')) &&
            !hasClinic(mod)) {
          return false;
        }

        // HRMS checks
        if ((labelUpper.contains('ATTENDANCE') ||
                labelUpper.contains('PAYROLL') ||
                labelUpper.contains('HRMS') ||
                labelUpper.contains('EMPLOYEE MASTER') ||
                labelUpper.contains('SHIFTS & ROSTER') ||
                labelUpper.contains('PAY SCHEDULES')) &&
            !hasHrms(mod)) {
          return false;
        }

        // Retail checks
        if ((labelUpper.contains('RETAIL SALES') ||
                labelUpper.contains('CUSTOMER APP') ||
                labelUpper.contains('RETAILER CONSOLE') ||
                labelUpper.contains('RIDER DELIVERY') ||
                labelUpper.contains('STORE ANALYSIS') ||
                labelUpper.contains('BRAND ANALYSIS')) &&
            !hasRetail(mod)) {
          return false;
        }

        // Inventory check
        if (!hasInventory(mod)) {
          if (labelUpper.contains('ITEM MASTER') ||
              labelUpper.contains('STOCK') ||
              labelUpper.contains('PURCHASE ORDER') ||
              labelUpper.contains('GOODS RECEIVING') ||
              labelUpper.contains('EXPIRY TRACKER') ||
              labelUpper.contains('DAMAGE') ||
              labelUpper.contains('SUPPLIER')) {
            return false;
          }
        }

        // Reports check for Inventory module
        if (mod == inventory) {
          if (labelUpper.contains('LOYALTY') ||
              labelUpper.contains('SCHEME') ||
              labelUpper.contains('COMMISSION') ||
              labelUpper.contains('PAYMENT METHOD ANALYSIS') ||
              labelUpper.contains('SALE SOURCE') ||
              labelUpper.contains('FINANCE HUB') ||
              labelUpper.contains('CASHIER SHIFT HANDOVER') ||
              labelUpper.contains('SALES REPORT')) {
            return false;
          }
        }
      }

      return true;
    }).map((item) {
      final label = item['label']?.toString();
      if (label != null) {
        final adapted = adaptLabel(label, mod);
        if (adapted != label) {
          final copy = Map<String, dynamic>.from(item);
          copy['label'] = adapted;
          return copy;
        }
      }
      return item;
    }).toList();
  }
}
