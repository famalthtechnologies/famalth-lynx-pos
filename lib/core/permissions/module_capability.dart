class ModuleCapability {
  ModuleCapability._();

  static const String inventory = 'INVENTORY';
  static const String retail = 'RETAIL';
  static const String restaurant = 'RESTAURANT';
  static const String clinic = 'CLINIC';
  static const String hrms = 'HRMS';
  static const String accounting = 'ACCOUNTING';
  static const String community = 'COMMUNITY';
  static const String all = 'ALL';

  /// All supported independent module identifiers
  static const List<String> allAvailableModules = [
    retail,
    restaurant,
    inventory,
    clinic,
    accounting,
    hrms,
  ];

  /// Parses module input string (single or comma-separated) into a Set of active modules
  static Set<String> parseModules(String? rawModule) {
    if (rawModule == null || rawModule.trim().isEmpty) {
      return {retail, inventory};
    }

    final upper = rawModule.trim().toUpperCase();
    if (upper == all) {
      return {all, ...allAvailableModules, community};
    }

    final Set<String> active = {};

    // Handle comma-separated list
    if (upper.contains(',')) {
      final tokens = upper.split(',').map((s) => s.trim().toUpperCase()).where((s) => s.isNotEmpty);
      for (final t in tokens) {
        if (t == all) {
          return {all, ...allAvailableModules, community};
        }
        if (t.contains('RESTAURANT') || t.contains('KDS') || t.contains('KOT') || t.contains('CAFE') || t.contains('BAR') || t.contains('DINING')) {
          active.add(restaurant);
        } else if (t.contains('CLINIC') || t.contains('DOCTOR') || t.contains('HOSPITAL') || t.contains('HEALTH') || t.contains('PHARMACY') || t.contains('MEDICAL')) {
          active.add(clinic);
        } else if (t.contains('ACCOUNTING') || t.contains('FINANCE') || t.contains('VOUCHER') || t.contains('LEDGER')) {
          active.add(accounting);
        } else if (t.contains('HRMS') || t.contains('ATTENDANCE') || t.contains('PAYROLL') || t.contains('STAFF')) {
          active.add(hrms);
        } else if (t.contains('INVENTORY') || t.contains('WAREHOUSE') || t.contains('STOCK')) {
          active.add(inventory);
        } else if (t.contains('RETAIL') || t.contains('POS') || t.contains('KIRANA') || t.contains('MART') || t.contains('STORE') || t.contains('SHOP')) {
          active.add(retail);
        } else if (t.contains('COMMUNITY') || t.contains('B2B') || t.contains('MARKETPLACE')) {
          active.add(community);
        }
      }
      if (active.isNotEmpty) return active;
    }

    // Single token normalization
    if (upper.contains('ALL')) {
      return {all, ...allAvailableModules, community};
    }
    if (upper.contains('RESTAURANT') || upper.contains('KDS') || upper.contains('KOT') || upper.contains('CAFE') || upper.contains('BAR') || upper.contains('DINING')) {
      active.add(restaurant);
    } else if (upper.contains('CLINIC') || upper.contains('DOCTOR') || upper.contains('HOSPITAL') || upper.contains('HEALTH') || upper.contains('MEDICAL')) {
      active.add(clinic);
    } else if (upper.contains('ACCOUNTING') || upper.contains('FINANCE')) {
      active.add(accounting);
    } else if (upper.contains('HRMS') || upper.contains('ATTENDANCE') || upper.contains('PAYROLL')) {
      active.add(hrms);
    } else if (upper.contains('INVENTORY') || upper.contains('WAREHOUSE')) {
      active.add(inventory);
    } else if (upper.contains('RETAIL') || upper.contains('POS') || upper.contains('KIRANA') || upper.contains('MART') || upper.contains('STORE') || upper.contains('SHOP')) {
      active.add(retail);
    } else {
      active.add(retail);
    }

    return active;
  }

  /// Normalizes module input string or returns a list of active modules
  static String normalize(String? rawModule) {
    if (rawModule == null || rawModule.trim().isEmpty) return retail;
    final upper = rawModule.trim().toUpperCase();

    // Multi-module list preserved if comma-separated
    if (upper.contains(',')) return upper;

    if (upper.contains('ALL')) return all;
    if (upper.contains('RESTAURANT') || upper.contains('KDS') || upper.contains('KOT') || upper.contains('CAFE') || upper.contains('BAR')) {
      return restaurant;
    }
    if (upper.contains('CLINIC') || upper.contains('DOCTOR') || upper.contains('HOSPITAL')) {
      return clinic;
    }
    if (upper.contains('ACCOUNTING') || upper.contains('FINANCE')) {
      return accounting;
    }
    if (upper.contains('HRMS') || upper.contains('ATTENDANCE') || upper.contains('PAYROLL')) {
      return hrms;
    }
    if (upper.contains('INVENTORY') || upper.contains('WAREHOUSE')) {
      return inventory;
    }
    if (upper.contains('RETAIL') || upper.contains('POS') || upper.contains('KIRANA') || upper.contains('MART') || upper.contains('STORE') || upper.contains('SHOP')) {
      return retail;
    }
    return upper;
  }

  /// Checks if Inventory module is supported (Items, Stock, Batches, Receiving, PO, Suppliers, Expiry)
  /// Enabled ONLY when INVENTORY is explicitly in active modules or ALL is active.
  /// POS-only retailers, restaurant-only, or HRMS-only accounts have this set to FALSE.
  static bool hasInventory([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(inventory);
  }

  /// Checks if Retail Sale / POS & Customer Delivery features are supported
  static bool hasRetail([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(retail);
  }

  /// Checks if Billing / Cashier Counter feature is supported
  /// Supported in Retail, Restaurant, Clinic, and ALL.
  static bool hasBilling([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(retail) || mods.contains(restaurant) || mods.contains(clinic);
  }

  /// Checks if Restaurant dining (Tables, KOT, KDS, Waiter, Captain) is supported
  static bool hasRestaurant([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(restaurant);
  }

  /// Checks if Clinic & Healthcare features (Doctors, Appointments, Prescriptions, Medical Reports) are supported
  static bool hasClinic([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(clinic);
  }

  /// Checks if HRMS & Attendance System features are supported
  static bool hasHrms([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(hrms);
  }

  /// Checks if the business outlet is configured strictly as HRMS only (no POS, no inventory, no clinic, no restaurant).
  static bool isHrmsOnly([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return false;
    return mods.contains(hrms) &&
        !mods.contains(retail) &&
        !mods.contains(restaurant) &&
        !mods.contains(clinic) &&
        !mods.contains(inventory);
  }

  /// Checks if the business outlet is configured strictly as Inventory only.
  static bool isInventoryOnly([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return false;
    return mods.contains(inventory) &&
        !mods.contains(retail) &&
        !mods.contains(restaurant) &&
        !mods.contains(clinic) &&
        !mods.contains(hrms);
  }

  /// Checks if Finance & Accounting Hub (Vouchers, Chart of Accounts, Bank Accounts, Ledger, Balance Sheet) is supported
  static bool hasAccounting([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(accounting);
  }

  /// Checks if Community & B2B Marketplace features are supported
  static bool hasCommunity([String? module]) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return mods.contains(community) || mods.contains(retail) || mods.contains(inventory);
  }

  /// Formats module name into human-friendly description
  static String formatDisplayModules(String? rawModule) {
    if (rawModule == null || rawModule.trim().isEmpty) return 'Retail POS';
    final upper = rawModule.trim().toUpperCase();
    if (upper == all) return 'Full Enterprise Suite (All Modules)';

    final mods = parseModules(rawModule);
    if (mods.contains(all)) return 'Full Enterprise Suite (All Modules)';

    final List<String> names = [];
    if (mods.contains(retail)) names.add('Retail POS');
    if (mods.contains(restaurant)) names.add('Restaurant & Dining');
    if (mods.contains(inventory)) names.add('Inventory & Stock');
    if (mods.contains(clinic)) names.add('Clinic & Healthcare');
    if (mods.contains(accounting)) names.add('Finance & Accounting');
    if (mods.contains(hrms)) names.add('HRMS & Payroll');

    if (names.isEmpty) return 'Retail POS';
    return names.join(' + ');
  }

  /// Stock Transfer: Retailers, Inventory & ALL.
  static bool isStockTransferAllowed(String? module) {
    return hasRetail(module) || hasInventory(module);
  }

  /// Product Assembly / Recipe: Allowed in Retail, Restaurant, Clinic and ALL.
  /// Decoupled: NOT allowed in pure Inventory or HRMS.
  static bool isAssemblyAllowed(String? module) {
    final mods = parseModules(module);
    if (mods.contains(all)) return true;
    return hasRetail(module) || hasRestaurant(module) || hasClinic(module);
  }

  /// Gets display label for Product Assembly / Recipe
  static String? getAssemblyLabel(String? module) {
    if (hasRestaurant(module)) return 'Recipe Management';
    if (hasRetail(module) || hasClinic(module)) return 'Product Assembly';
    return null;
  }

  /// Lucky Draw Campaign: Retailer, Restaurant & ALL.
  static bool isLuckyDrawAllowed(String? module) {
    return hasRetail(module) || hasRestaurant(module);
  }

  /// Reprint / Modify Sales Bill: Allowed wherever Billing is enabled.
  static bool isReprintSalesAllowed(String? module) {
    return hasBilling(module);
  }

  /// Document sequence module filtering
  static bool isSequenceAllowed(String sequenceModule, String? module) {
    final seqUpper = sequenceModule.toUpperCase();
    final mods = parseModules(module);
    if (mods.contains(all)) return true;

    // Billing / POS sequences
    if (seqUpper == 'SALES' || seqUpper == 'BILL') {
      return hasBilling(module);
    }

    // Token (Sweet shop / Food court / Counter POS / Clinic appointment)
    if (seqUpper == 'TOKEN') {
      return hasBilling(module) || hasRestaurant(module) || hasClinic(module);
    }

    // Restaurant sequences
    if (seqUpper == 'KOT' || seqUpper == 'KDS') {
      return hasRestaurant(module);
    }

    // Inventory sequences (PO, Receiving GRN, Indent, Request, Damage)
    if (seqUpper == 'PO' ||
        seqUpper == 'RECEIVING' ||
        seqUpper == 'INDENT' ||
        seqUpper == 'REQUEST' ||
        seqUpper == 'DAMAGE') {
      return hasInventory(module);
    }

    // Clinic sequences
    if (seqUpper == 'APPOINTMENT') {
      return hasClinic(module);
    }

    // Accounting sequences
    if (seqUpper.contains('VOUCHER') ||
        seqUpper == 'JOURNAL' ||
        seqUpper == 'CONTRA' ||
        seqUpper == 'PAYMENT' ||
        seqUpper == 'RECEIPT') {
      return hasAccounting(module);
    }

    return true;
  }

  /// Reports & Analytics visibility check
  static bool isReportAllowed(String reportKey, String? module) {
    final keyUpper = reportKey.toUpperCase();
    final mods = parseModules(module);
    if (mods.contains(all)) return true;

    // Sales reports require billing
    const salesReports = {
      'RETAIL_SALES',
      'DAILY_CLOSING',
      'SALE_SOURCE',
      'SOURCE_ANALYSIS',
      'PAYMENT_METHOD',
      'PAYMENT_ANALYSIS',
      'CASHIER_SHIFT_HANDOVER',
      'COMMISSION',
      'COMMISSION_REPORT',
      'LOYALTY',
      'LOYALTY_REPORT',
      'LOYALTY_PROGRAM',
      'SCHEME',
      'SCHEME_REPORT',
      'SCHEME_ANALYSIS',
      'STORE_ANALYSIS',
      'BRAND_ANALYSIS',
      'NIGHT_AUDIT',
      'SUBSCRIPTION',
      'SUBSCRIPTION_REPORT',
    };
    if (salesReports.contains(keyUpper) && !hasBilling(module)) {
      return false;
    }

    if ((keyUpper.contains('LOYALTY') ||
            keyUpper.contains('SCHEME') ||
            keyUpper.contains('COMMISSION') ||
            keyUpper.contains('NIGHT_AUDIT') ||
            keyUpper.contains('SUBSCRIPTION') ||
            keyUpper.contains('SOURCE_ANALYSIS') ||
            keyUpper.contains('PAYMENT_ANALYSIS')) &&
        !hasBilling(module)) {
      return false;
    }

    // Inventory reports require inventory
    const inventoryReports = {
      'STOCK_LEDGER',
      'STOCK_BALANCE',
      'PURCHASE',
      'VENDOR_PAYMENT',
      'VENDOR_PAYMENT_REPORT',
      'GOODS_RECEIVING',
      'RECEIVING_REPORT',
      'STOCK_IN_REPORT',
      'CLOSING_REPORT',
      'RETURN_REPORT',
      'REQUEST_REPORT',
      'DAMAGE',
      'EXPIRY',
      'STOCK_TRANSFER',
    };
    if (inventoryReports.contains(keyUpper) && !hasInventory(module)) {
      return false;
    }

    if ((keyUpper.contains('RECEIVING') ||
            keyUpper.contains('VENDOR_PAYMENT') ||
            keyUpper.contains('RETURN_REPORT') ||
            keyUpper.contains('REQUEST_REPORT') ||
            keyUpper.contains('CLOSING_REPORT')) &&
        !hasInventory(module)) {
      return false;
    }

    // Restaurant reports
    if ((keyUpper.contains('RESTAURANT') || keyUpper.contains('KOT') || keyUpper.contains('KDS') || keyUpper.contains('TABLE') || keyUpper.contains('DINING')) && !hasRestaurant(module)) {
      return false;
    }

    // Clinic reports
    if ((keyUpper.contains('CLINIC') || keyUpper.contains('DOCTOR') || keyUpper.contains('APPOINTMENT') || keyUpper.contains('PRESCRIPTION')) && !hasClinic(module)) {
      return false;
    }

    // Accounting reports
    if ((keyUpper.contains('ACCOUNTING') || keyUpper.contains('TRIAL_BALANCE') || keyUpper.contains('PROFIT_LOSS') || keyUpper.contains('BALANCE_SHEET') || keyUpper.contains('VOUCHER')) && !hasAccounting(module)) {
      return false;
    }

    // HRMS reports
    if ((keyUpper.contains('ATTENDANCE') || keyUpper.contains('PAYROLL') || keyUpper.contains('HRMS') || keyUpper.contains('EMPLOYEE')) && !hasHrms(module)) {
      return false;
    }

    return true;
  }

  /// Checks if a permission key is allowed under the current business module
  static bool isPermissionAllowed(String? permissionKey, String? module) {
    if (permissionKey == null || permissionKey.isEmpty) return true;
    final key = permissionKey.toUpperCase();
    final mods = parseModules(module);

    if (mods.contains(all)) return true;

    // Rules for Stock Transfer
    if (key.contains('STOCK_TRANSFER') || key.contains('TRANSFER')) {
      if (!isStockTransferAllowed(module)) return false;
    }

    // Rules for Assembly / Recipe
    if (key.contains('ASSEMBLY') || key.contains('RECIPE')) {
      if (!isAssemblyAllowed(module)) return false;
    }

    // Rules for Lucky Draw
    if (key.contains('LUCKY_DRAW')) {
      if (!isLuckyDrawAllowed(module)) return false;
    }

    // Rules for Sales Reprint / Modify
    if (key.contains('REPRINT_SALES') || key.contains('MODIFY_SALES') || key.contains('MODIFY_BILL')) {
      if (!isReprintSalesAllowed(module)) return false;
    }

    // Inventory specific permissions
    const inventoryPermissions = {
      'ITEM_REQUEST',
      'PURCHASE_ORDER',
      'STOCK_IN',
      'STOCK_OUT',
      'RETURN',
      'RETURN_ISSUE',
      'SUPPLIER_RETURN',
      'DAMAGE',
      'SUPPLIER_MASTER',
      'STOCK_LOCATION',
      'SUBMISSIONS_STATUS',
      'ITEM_BARCODE_MANAGER',
      'APPROVAL_CENTER',
      'MODIFY_REQUEST',
      'MODIFY_PURCHASE',
      'MODIFY_RECEIVING',
      'MODIFY_ISSUE',
      'REPRINT_REQUEST',
      'REPRINT_PURCHASE',
      'REPRINT_RECEIVING',
      'REPRINT_ISSUE',
      'STOCK_BALANCE',
      'ITEM_ADVANCE_REPORT',
      'DAMAGE_SUMMARY',
      'STOCK_IN_REPORT',
      'STOCK_OUT_REPORT',
      'SUPPLIER_PAYMENT',
      'SUPPLIER_RETURN_REFUND',
      'PENDING_REFUNDS',
      'STOCK_LEDGER_REPORT',
      'VENDOR_PAYMENT_REPORT',
      'PURCHASE_REPORT',
      'RETURN_REPORT',
      'REQUEST_REPORT',
      'DAMAGE_REPORT',
    };
    if (inventoryPermissions.contains(key) && !hasInventory(module)) {
      return false;
    }

    if (key == 'ITEM_MASTER' && !hasInventory(module) && !hasBilling(module) && !hasClinic(module)) {
      return false;
    }

    if (key == 'POS_SALE' && (hasBilling(module) || hasClinic(module))) {
      return true;
    }

    // Operations & Expenses allowed across Retail Billing, Clinic, and Restaurant
    if (key == 'DELIVERY_CHALLANS' || key == 'RECURRING_EXPENSES') {
      return hasBilling(module) || hasRestaurant(module) || hasClinic(module);
    }

    // Retail specific permissions
    const retailPermissions = {
      'RETAIL_SALES',
      'CUSTOMER_APP',
      'RETAILER_CONSOLE',
      'RIDER_PORTAL',
      'STORE_ANALYSIS',
      'BRAND_ANALYSIS',
    };
    if (retailPermissions.contains(key) && !hasRetail(module)) {
      return false;
    }

    // Billing & Counter Sales specific permissions
    const billingPermissions = {
      'ENTERPRISE_POS',
      'REPRINT_SALES_BILL',
      'MODIFY_SALES_BILL',
      'MODIFY_SALES_PAYMENT',
      'CUSTOMER_LIST',
      'ADD_CUSTOMER',
      'DRAFT_BILLS',
      'POS_SUBSCRIPTIONS',
      'SCHEME_MANAGEMENT',
      'RETAIL_SALES_REPORT',
      'SALES_REPORT',
      'SOURCE_ANALYSIS',
      'PAYMENT_ANALYSIS',
      'SCHEME_REPORT',
      'SCHEME_ANALYSIS',
      'LOYALTY_PROGRAM',
      'LOYALTY_REPORT',
      'COMMISSION_REPORT',
      'CLOSING_REPORT',
      'NIGHT_AUDIT',
      'SUBSCRIPTION',
      'SUBSCRIPTION_REPORT',
      'WHATSAPP_INTEGRATION',
      'PROMO_VOUCHERS',
      'HAPPY_HOUR',
      'COMMISSION_RULES',
      'CASHIER_HANDOVER',
    };
    if (billingPermissions.contains(key) && !hasBilling(module)) {
      return false;
    }

    // Restaurant specific permissions
    const restaurantPermissions = {
      'RESTAURANT_CONSOLE',
      'RESTAURANT_FLOOR_DESIGN',
      'RESTAURANT_KDS',
      'RESTAURANT_SETUP',
      'RESTAURANT_ANALYTICS',
      'TABLE_RESERVATIONS',
      'RUNNING_ORDERS',
      'KOTS_HISTORY',
    };
    if (restaurantPermissions.contains(key) && !hasRestaurant(module)) {
      return false;
    }

    // Clinic specific permissions
    const clinicPermissions = {
      'CLINIC_MODULE',
      'CLINIC_APPOINTMENTS',
      'DOCTOR_CONSULTATION',
      'PRESCRIPTIONS',
      'CLINIC_PHARMACY',
      'CLINIC_THERAPY',
      'CLINIC_ANALYTICS',
    };
    if (clinicPermissions.contains(key) && !hasClinic(module)) {
      return false;
    }

    // HRMS specific permissions
    const hrmsPermissions = {
      'HRMS_MODULE',
      'EMPLOYEE_MASTER',
      'ATTENDANCE',
      'PAYROLL',
      'HR_EMPLOYEES',
      'HR_ATTENDANCE',
      'HR_MASTERS',
      'PAY_SCHEDULE',
      'HR_PAYROLL',
    };
    if (hrmsPermissions.contains(key) && !hasHrms(module)) {
      return false;
    }

    // Accounting specific permissions
    const accountingPermissions = {
      'ACCOUNTING_VOUCHERS',
      'BANK_ACCOUNTS',
      'CHART_OF_ACCOUNTS',
      'TRIAL_BALANCE',
      'BALANCE_SHEET',
      'PROFIT_LOSS',
      'ACCOUNTING_MODULE',
      'FINANCE_HUB',
      'LOAN_EMI',
      'CREDIT_ANALYSIS',
      'EXPENSE_ANALYTICS',
    };
    if (accountingPermissions.contains(key) && !hasAccounting(module)) {
      return false;
    }

    return true;
  }


  /// Checks if a permission group category is allowed for the active business module
  static bool isCategoryAllowed(String category, String? module) {
    final cat = category.trim().toUpperCase();
    final mods = parseModules(module);
    if (mods.contains(all)) return true;

    if (cat.contains('INVENTORY') || cat.contains('MODIFY DOCUMENTS')) {
      return hasInventory(module);
    }
    if (cat.contains('HR &') || cat.contains('ATTENDANCE') || cat.contains('HRMS')) {
      return hasHrms(module);
    }
    if (cat.contains('RESTAURANT') || cat.contains('DINING')) {
      return hasRestaurant(module);
    }
    if (cat.contains('CLINIC') || cat.contains('HEALTHCARE')) {
      return hasClinic(module);
    }
    if (cat.contains('RETAIL SALES') || cat.contains('MARKETING')) {
      return hasBilling(module) || hasRetail(module) || hasRestaurant(module) || hasClinic(module);
    }
    return true;
  }

  /// Adapts category titles to match the active module terminology (Clinic, Restaurant, Retail)
  static String adaptCategoryName(String category, String? module) {
    final isCl = hasClinic(module) && !hasRetail(module);
    final isRest = hasRestaurant(module) && !hasRetail(module);

    if (category == 'Retail Sales & POS') {
      if (isCl) return 'Pharmacy & Clinic Billing';
      if (isRest) return 'Restaurant Sales & Billing POS';
      return 'Retail Sales & POS';
    }
    if (category == 'Inventory & Stock') {
      if (isCl) return 'Pharmacy Inventory & Stock';
      if (isRest) return 'Kitchen Stock & Inventory';
      return 'Inventory & Stock';
    }
    if (category == 'Accounts & Finance') {
      if (isCl) return 'Clinic Finance & Cash Ledger';
      if (isRest) return 'Restaurant Finance & Cash Ledger';
      return 'Accounts & Finance';
    }
    if (category == 'Marketing & Campaigns') {
      if (isCl) return 'Patient Outreach & Loyalty';
      if (isRest) return 'Diner Engagement & Loyalty';
      return 'Marketing & Campaigns';
    }
    if (category == 'Reports & Intelligence') {
      if (isCl) return 'Clinic Reports & Analytics';
      if (isRest) return 'Restaurant Reports & Analytics';
      return 'Reports & Intelligence';
    }
    return category;
  }

  /// Adapts individual permission labels to match active business module terminology
  static String adaptPermissionLabel(String key, String defaultLabel, String? module) {
    final isCl = hasClinic(module) && !hasRetail(module);
    final isRest = hasRestaurant(module) && !hasRetail(module);
    final k = key.trim().toUpperCase();

    if (k == 'ITEM_MASTER') {
      if (isCl) return 'Medicines, Lab Tests & Services Master';
      if (isRest) return 'Menu Items & Recipes Master';
      return 'Item Master / Products';
    }
    if (k == 'PRODUCT_ASSEMBLY') {
      if (isRest) return 'Recipe Management';
      return 'Product Assembly / Bundles';
    }
    if (k == 'ENTERPRISE_POS') {
      if (isCl) return 'Pharmacy & Clinic Billing Terminal';
      if (isRest) return 'Restaurant POS Terminal';
      return 'Enterprise POS Terminal';
    }
    if (k == 'RETAIL_SALES') {
      if (isCl) return 'Pharmacy Counter Sales (POS)';
      if (isRest) return 'Dine-in / Counter Sales (POS)';
      return 'Retail Sales (POS Billing)';
    }
    if (k == 'REPRINT_SALES_BILL') {
      if (isCl) return 'Reprint Pharmacy Bill / Token';
      if (isRest) return 'Reprint Food Bill / KOT';
      return 'Reprint Sales Bill';
    }
    if (k == 'MODIFY_SALES_BILL') {
      if (isCl) return 'Modify Pharmacy Bill';
      if (isRest) return 'Modify Restaurant Order / Bill';
      return 'Modify Sales Bill';
    }
    if (k == 'MODIFY_SALES_PAYMENT') {
      if (isCl) return 'Modify Consultation / Pharmacy Payment';
      if (isRest) return 'Modify Table / Food Payment';
      return 'Modify Sales Payment';
    }
    if (k == 'CUSTOMER_LIST') {
      if (isCl) return 'Patient Directory & Profiles';
      if (isRest) return 'Guest & Diner Directory';
      return 'Customer Master & Directory';
    }
    if (k == 'ADD_CUSTOMER') {
      if (isCl) return 'Add New Patient';
      if (isRest) return 'Add New Guest / Diner';
      return 'Add New Customer';
    }
    if (k == 'DRAFT_BILLS') {
      if (isCl) return 'Draft Prescriptions & Saved Carts';
      if (isRest) return 'Open KOTs & Table Tabs';
      return 'Draft Bills & Saved Carts';
    }
    if (k == 'POS_SUBSCRIPTIONS') {
      if (isCl) return 'Therapy & Service Subscriptions';
      if (isRest) return 'Meal Plans & Subscriptions';
      return 'Subscription Deliveries & Orders';
    }
    if (k == 'SCHEME_MANAGEMENT') {
      if (isCl) return 'Health Schemes & Discount Plans';
      if (isRest) return 'Food Combos & Happy Hour Schemes';
      return 'Create & Manage POS Schemes';
    }
    if (k == 'CUSTOMER_APP') {
      if (isCl) return 'Patient Self-Care App';
      if (isRest) return 'Diner Digital Menu App';
      return 'Customer App (Delivery)';
    }
    if (k == 'RETAIL_SALES_REPORT' || k == 'SALES_REPORT') {
      if (isCl) return 'Pharmacy Sales Report';
      if (isRest) return 'Restaurant Sales Report';
      return 'Retail Sales Report';
    }
    if (k == 'CLOSING_REPORT') {
      if (isCl) return 'Clinic Day-End Closing Report';
      if (isRest) return 'Shift / Day-End Closing Report';
      return 'Closing Report';
    }
    if (k == 'CREDIT_ANALYSIS') {
      if (isCl) return 'Patient Credit & Dues Ledger';
      if (isRest) return 'Diner Credit & Corporate Accounts';
      return 'Credit Ledger & Customer Accounts';
    }
    if (k == 'LOYALTY_PROGRAM') {
      if (isCl) return 'Patient Wellness & Loyalty Points';
      if (isRest) return 'Diner Loyalty & Rewards Program';
      return 'Loyalty Program Setup';
    }
    if (k == 'LOYALTY_REPORT') {
      if (isCl) return 'Patient Loyalty Report';
      if (isRest) return 'Diner Loyalty Report';
      return 'Loyalty Report';
    }
    if (k == 'SUBSCRIPTION_REPORT') {
      if (isCl) return 'Therapy Subscription Report';
      return 'Subscription Report';
    }

    return defaultLabel;
  }

  /// Dynamically adapts labels for Restaurant/Inventory/Clinic modules
  static String adaptLabel(String label, String? module) {
    if (hasRestaurant(module)) {
      if (label.toUpperCase().contains('ASSEMBLY')) {
        return getAssemblyLabel(module) ?? label;
      }
      if (label.contains('Supplier / Retailer Console')) {
        return 'Supplier & Kitchen Console';
      }
      if (label.contains('Retailer Console')) {
        return 'Restaurant Console';
      }
      if (label.contains('Retail Sales Report') || label.contains('Retail Sale Report')) {
        return 'Sales Report';
      }
      if (label.contains('Retail Sales')) {
        return 'Sales Report';
      }
      if (label.contains('Retail POS')) {
        return 'Restaurant POS';
      }
      if (label.contains('Retailer')) {
        return label.replaceAll('Retailer', 'Restaurant');
      }
    }
    if (hasClinic(module) && !hasRetail(module)) {
      if (label.contains('Retail Sales Report') || label.contains('Retail Sale Report') || label.contains('Sales Report')) {
        return 'Pharmacy Sale Report';
      }
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
    if (!hasRetail(module) && hasInventory(module)) {
      if (label.contains('Retailer')) {
        return label.replaceAll('Retailer', 'Inventory');
      }
    }
    return label;
  }

  /// Filters drawer menu items dynamically based on module access
  static List<Map<String, dynamic>> filterDrawerItems(
      List<Map<String, dynamic>> items, String? module) {
    final mods = parseModules(module);
    if (mods.contains(all)) return items;

    // Dedicated Pure HRMS filtering
    // In HRMS: show ONLY HR & Payroll, Finance (Cash/Bank Ledger & Expenses), and System/Settings
    if (isHrmsOnly(module)) {
      return items.where((item) {
        final String? category = item['category']?.toString();
        final String? label = item['label']?.toString();
        final String? perm = item['permission']?.toString();
        final catUpper = (category ?? '').toUpperCase();
        final labelUpper = (label ?? '').toUpperCase();

        // 1. HR & Payroll
        if (catUpper == 'HR & PAYROLL' || (perm != null && perm.startsWith('HR_'))) {
          return true;
        }

        // 2. Finance Cash/Bank Ledger & Regular Expenses
        if (catUpper == 'FINANCE & EXPENSES' || catUpper == 'REPORTS') {
          if (labelUpper == 'FINANCE & REPORTS' ||
              labelUpper == 'REGULAR EXPENSES' ||
              labelUpper == 'CASH / BANK LEDGER' ||
              labelUpper == 'EXPENSES') {
            return true;
          }
          if (labelUpper.contains('CASH') && labelUpper.contains('LEDGER')) {
            return true;
          }
        }

        // 3. System & Settings
        if (catUpper == 'SYSTEM') {
          if (labelUpper.contains('STOCK') ||
              labelUpper.contains('INVENTORY') ||
              labelUpper.contains('DISPATCH') ||
              labelUpper.contains('RECEIVE') ||
              labelUpper.contains('TRANSFER') ||
              labelUpper.contains('SEQUENCE') ||
              labelUpper.contains('BRAND') ||
              labelUpper.contains('BARCODE') ||
              labelUpper.contains('TAX')) {
            return false;
          }
          return true;
        }

        if (labelUpper == 'USER MANAGEMENT' ||
            labelUpper == 'STORE SETUP CHECKLIST & GUIDE' ||
            labelUpper == 'OUTLET DETAIL MODIFICATION' ||
            labelUpper == 'MASTER & CHILD OUTLETS SETUP' ||
            labelUpper == 'SETTINGS') {
          return true;
        }

        return false;
      }).map((item) {
        final label = item['label']?.toString();
        final cat = item['category']?.toString();
        if (label == 'Finance & Reports' || (cat == 'Reports' && label?.contains('Cash') == true)) {
          final copy = Map<String, dynamic>.from(item);
          copy['category'] = 'Finance & Expenses';
          copy['label'] = 'Cash / Bank Ledger';
          return copy;
        }
        return item;
      }).toList();
    }

    return items.where((item) {
      final String? perm = item['permission']?.toString();
      final String? category = item['category']?.toString();
      final String? label = item['label']?.toString();
      final catUpper = (category ?? '').toUpperCase();

      if (perm != null && perm.isNotEmpty) {
        if (!isPermissionAllowed(perm, module)) return false;
      }

      if (category != null) {
        final catUpper = category.toUpperCase();
        if (catUpper.contains('RESTAURANT') && !hasRestaurant(module)) return false;
        if ((catUpper.contains('CLINIC') || catUpper.contains('HEALTH')) && !hasClinic(module)) return false;
        if ((catUpper.contains('HR') || catUpper.contains('PAYROLL')) && !hasHrms(module)) return false;
        if (catUpper.contains('ACCOUNTING') && !hasAccounting(module)) return false;
        if (catUpper.contains('BILLING')) {
          if (!hasBilling(module)) return false;
          // In clinic mode without retail, generic billing group is hidden because Clinic section has Clinic Billing & Pharmacy POS
          if (hasClinic(module) && !hasRetail(module)) return false;
        }
        if ((catUpper == 'OPERATIONS' || catUpper == 'STOCK VIEW') && !hasInventory(module)) return false;
      }

      if (label != null) {
        final labelUpper = label.toUpperCase();

        // Finance & Accounting checks
        if ((labelUpper.contains('ACCOUNTING') ||
                labelUpper.contains('VOUCHER') ||
                labelUpper.contains('BANK ACCOUNT') ||
                labelUpper.contains('TRIAL BALANCE') ||
                labelUpper.contains('BALANCE SHEET') ||
                labelUpper.contains('PROFIT & LOSS') ||
                labelUpper.contains('CHART OF ACCOUNTS')) &&
            !hasAccounting(module)) {
          return false;
        }

        // Stock Transfer check
        if (labelUpper.contains('STOCK TRANSFER') && !isStockTransferAllowed(module)) {
          return false;
        }

        // Product Assembly check
        if ((labelUpper.contains('ASSEMBLY') || labelUpper.contains('RECIPE')) &&
            !isAssemblyAllowed(module)) {
          return false;
        }

        // Lucky Draw check
        if (labelUpper.contains('LUCKY DRAW') && !isLuckyDrawAllowed(module)) {
          return false;
        }

        // Billing / POS checks
        if ((labelUpper.contains('BILLING (POS)') ||
                labelUpper.contains('DRAFT & HOLD BILLS') ||
                labelUpper.contains('MODIFY BILLS') ||
                labelUpper.contains('RETAIL SALES REPORT') ||
                labelUpper.contains('SALES REPORT') ||
                labelUpper.contains('LOYALTY') ||
                labelUpper.contains('SCHEME') ||
                labelUpper.contains('COMMISSION') ||
                labelUpper.contains('NIGHT AUDIT') ||
                labelUpper.contains('SALE SOURCE') ||
                labelUpper.contains('PAYMENT METHOD ANALYSIS')) &&
            !hasBilling(module)) {
          return false;
        }

        // Sales Bill Reprint / Modify check
        if ((labelUpper.contains('REPRINT') ||
                labelUpper.contains('SALES BILL') ||
                labelUpper.contains('MODIFY SALES')) &&
            !isReprintSalesAllowed(module)) {
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
            !hasRestaurant(module)) {
          return false;
        }

        // Clinic checks
        if ((labelUpper.contains('CLINIC') ||
                labelUpper.contains('DOCTOR') ||
                labelUpper.contains('APPOINTMENT') ||
                labelUpper.contains('PRESCRIPTION')) &&
            !hasClinic(module)) {
          return false;
        }

        // HRMS checks
        if ((labelUpper.contains('ATTENDANCE') ||
                labelUpper.contains('PAYROLL') ||
                labelUpper.contains('HRMS') ||
                labelUpper.contains('EMPLOYEE MASTER') ||
                labelUpper.contains('SHIFTS & ROSTER') ||
                labelUpper.contains('PAY SCHEDULES')) &&
            !hasHrms(module)) {
          return false;
        }

        // Retail checks
        if ((labelUpper.contains('CUSTOMER APP') ||
                labelUpper.contains('RETAILER CONSOLE') ||
                labelUpper.contains('RIDER DELIVERY') ||
                labelUpper.contains('STORE ANALYSIS') ||
                labelUpper.contains('BRAND ANALYSIS')) &&
            !hasRetail(module)) {
          return false;
        }

        // Inventory check
        if (!hasInventory(module)) {
          if (catUpper == 'OPERATIONS' ||
              catUpper == 'STOCK VIEW') {
            return false;
          }
          if (catUpper == 'MASTERS' || catUpper == 'MASTERS & DEPARTMENTS') {
            // For clinic-only mode, generic Item Master is hidden because Clinic section has Medicines, Lab Tests & Services
            if (labelUpper.contains('ITEM MASTER') && hasClinic(module) && !hasRetail(module)) {
              return false;
            }
            // When billing is active, Item Master is enabled so products & item images can be managed for POS
            if (labelUpper.contains('ITEM') && hasBilling(module)) {
              // Allowed for POS billing
            } else if (labelUpper.contains('ITEM') ||
                labelUpper.contains('VENDOR') ||
                labelUpper.contains('SUPPLIER') ||
                labelUpper.contains('LOCATION') ||
                labelUpper.contains('DEPARTMENT')) {
              return false;
            }
          }
          if (catUpper == 'MODIFY') {
            if (labelUpper.contains('REPRINT') && isReprintSalesAllowed(module)) {
              // allow reprint/modify sales bill
            } else {
              return false;
            }
          }
          if ((!hasBilling(module) && labelUpper.contains('ITEM MASTER')) ||
              labelUpper.contains('RECEIVING') ||
              labelUpper.contains('CLOSING REPORT') ||
              labelUpper.contains('VENDOR PAYMENT') ||
              labelUpper.contains('RETURN REPORT') ||
              labelUpper.contains('RETURN PURCHASE') ||
              labelUpper.contains('RETURN DEPARTMENT') ||
              labelUpper.contains('VENDOR RETURN') ||
              labelUpper.contains('REQUEST REPORT') ||
              labelUpper.contains('MODIFY REQUEST') ||
              labelUpper.contains('STOCK') ||
              labelUpper.contains('PURCHASE ORDER') ||
              labelUpper.contains('GOODS RECEIVING') ||
              labelUpper.contains('EXPIRY TRACKER') ||
              labelUpper.contains('DAMAGE') ||
              labelUpper.contains('SUPPLIER')) {
            return false;
          }
        }
      }

      return true;
    }).map((item) {
      final label = item['label']?.toString();
      if (label != null) {
        final adapted = adaptLabel(label, module);
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
