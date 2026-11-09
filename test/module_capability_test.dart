import 'package:retailpos/core/config/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retailpos/core/permissions/module_capability.dart';

void main() {
  group('ModuleCapability User Scenarios Tests', () {
    test('Scenario 1: Retailer wants ONLY POS, not inventory', () {
      const mod = 'RETAIL';
      expect(ModuleCapability.hasRetail(mod), isTrue);
      expect(ModuleCapability.hasBilling(mod), isTrue);
      expect(ModuleCapability.hasInventory(mod), isFalse, reason: 'Inventory must be hidden for POS-only retailer');
      expect(ModuleCapability.hasHrms(mod), isFalse, reason: 'HRMS must be hidden');
      expect(ModuleCapability.hasRestaurant(mod), isFalse);
      expect(ModuleCapability.hasClinic(mod), isFalse);
      expect(ModuleCapability.hasAccounting(mod), isFalse);
    });

    test('Scenario 2: Retailer wants POS and Inventory, not HRMS', () {
      const mod = 'RETAIL,INVENTORY';
      expect(ModuleCapability.hasRetail(mod), isTrue);
      expect(ModuleCapability.hasBilling(mod), isTrue);
      expect(ModuleCapability.hasInventory(mod), isTrue, reason: 'Inventory must be enabled');
      expect(ModuleCapability.hasHrms(mod), isFalse, reason: 'HRMS must be hidden');
      expect(ModuleCapability.hasRestaurant(mod), isFalse);
      expect(ModuleCapability.hasClinic(mod), isFalse);
    });

    test('Scenario 3: Retailer wants HRMS, Inventory and POS', () {
      const mod = 'RETAIL,INVENTORY,HRMS';
      expect(ModuleCapability.hasRetail(mod), isTrue);
      expect(ModuleCapability.hasBilling(mod), isTrue);
      expect(ModuleCapability.hasInventory(mod), isTrue);
      expect(ModuleCapability.hasHrms(mod), isTrue, reason: 'HRMS must be enabled');
      expect(ModuleCapability.hasRestaurant(mod), isFalse);
      expect(ModuleCapability.hasClinic(mod), isFalse);
    });

    test('Scenario 4: Restaurant cases (Only, +Inventory, +Inventory+HRMS)', () {
      // 4a. Restaurant Only (no inventory, no HRMS)
      const restOnly = 'RESTAURANT';
      expect(ModuleCapability.hasRestaurant(restOnly), isTrue);
      expect(ModuleCapability.hasBilling(restOnly), isTrue);
      expect(ModuleCapability.hasInventory(restOnly), isFalse, reason: 'Warehouse stock hidden for dining-only');
      expect(ModuleCapability.hasHrms(restOnly), isFalse);
      expect(ModuleCapability.hasRetail(restOnly), isFalse);

      // 4b. Restaurant + Inventory (no HRMS)
      const restInv = 'RESTAURANT,INVENTORY';
      expect(ModuleCapability.hasRestaurant(restInv), isTrue);
      expect(ModuleCapability.hasInventory(restInv), isTrue);
      expect(ModuleCapability.hasHrms(restInv), isFalse);

      // 4c. Restaurant + Inventory + HRMS
      const restInvHrms = 'RESTAURANT,INVENTORY,HRMS';
      expect(ModuleCapability.hasRestaurant(restInvHrms), isTrue);
      expect(ModuleCapability.hasInventory(restInvHrms), isTrue);
      expect(ModuleCapability.hasHrms(restInvHrms), isTrue);
    });

    test('Scenario 5: Doctors / Clinic cases (Only, +Pharmacy/Inventory)', () {
      // 5a. Clinic Only (no inventory/pharmacy, no HRMS)
      const clinicOnly = 'CLINIC';
      expect(ModuleCapability.hasClinic(clinicOnly), isTrue);
      expect(ModuleCapability.hasBilling(clinicOnly), isTrue);
      expect(ModuleCapability.hasInventory(clinicOnly), isFalse);
      expect(ModuleCapability.hasHrms(clinicOnly), isFalse);

      // 5b. Clinic + Inventory (Pharmacy medicine stock)
      const clinicPharmacy = 'CLINIC,INVENTORY';
      expect(ModuleCapability.hasClinic(clinicPharmacy), isTrue);
      expect(ModuleCapability.hasInventory(clinicPharmacy), isTrue);
      expect(ModuleCapability.hasHrms(clinicPharmacy), isFalse);
    });

    test('Scenario 6: Someone wants ONLY HRMS module', () {
      const hrmsOnly = 'HRMS';
      expect(ModuleCapability.hasHrms(hrmsOnly), isTrue);
      expect(ModuleCapability.hasBilling(hrmsOnly), isFalse);
      expect(ModuleCapability.hasInventory(hrmsOnly), isFalse);
      expect(ModuleCapability.hasRetail(hrmsOnly), isFalse);
      expect(ModuleCapability.hasRestaurant(hrmsOnly), isFalse);
      expect(ModuleCapability.hasClinic(hrmsOnly), isFalse);
      expect(ModuleCapability.hasAccounting(hrmsOnly), isFalse);
    });

    test('Scenario 7: Someone wants ONLY Inventory module', () {
      const invOnly = 'INVENTORY';
      expect(ModuleCapability.hasInventory(invOnly), isTrue);
      expect(ModuleCapability.hasBilling(invOnly), isFalse);
      expect(ModuleCapability.hasRetail(invOnly), isFalse);
      expect(ModuleCapability.hasRestaurant(invOnly), isFalse);
      expect(ModuleCapability.hasClinic(invOnly), isFalse);
      expect(ModuleCapability.hasHrms(invOnly), isFalse);
    });

    test('Scenario 8: Complete Full Suite (ALL)', () {
      const allMod = 'ALL';
      expect(ModuleCapability.hasRetail(allMod), isTrue);
      expect(ModuleCapability.hasRestaurant(allMod), isTrue);
      expect(ModuleCapability.hasClinic(allMod), isTrue);
      expect(ModuleCapability.hasInventory(allMod), isTrue);
      expect(ModuleCapability.hasAccounting(allMod), isTrue);
      expect(ModuleCapability.hasHrms(allMod), isTrue);
      expect(ModuleCapability.hasBilling(allMod), isTrue);
    });

    test('Scenario 9: Product Assembly is decoupled from HRMS and pure Inventory', () {
      // Product Assembly should NOT be allowed for pure Inventory or HRMS
      expect(ModuleCapability.isAssemblyAllowed('INVENTORY'), isFalse, reason: 'Product assembly not for pure inventory');
      expect(ModuleCapability.isAssemblyAllowed('HRMS'), isFalse, reason: 'Product assembly not for HRMS');
      expect(ModuleCapability.isAssemblyAllowed('INVENTORY,HRMS'), isFalse, reason: 'Product assembly not for inventory+hrms without retail/restaurant');

      // Product Assembly IS allowed for Retail, Restaurant, Clinic and ALL
      expect(ModuleCapability.isAssemblyAllowed('RETAIL'), isTrue);
      expect(ModuleCapability.isAssemblyAllowed('RETAIL,INVENTORY'), isTrue);
      expect(ModuleCapability.isAssemblyAllowed('RESTAURANT'), isTrue);
      expect(ModuleCapability.isAssemblyAllowed('CLINIC'), isTrue);
      expect(ModuleCapability.isAssemblyAllowed('ALL'), isTrue);
    });

    test('Scenario 10: Loyalty, Schemes, Commissions, Night Audit decoupled from pure Inventory and HRMS', () {
      const invOnly = 'INVENTORY';
      const hrmsOnly = 'HRMS';
      const retailMod = 'RETAIL';

      // Inventory only should NOT have loyalty, schemes, sales commission, or night audit
      expect(ModuleCapability.isReportAllowed('SCHEME_REPORT', invOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('SCHEME_ANALYSIS', invOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('LOYALTY_REPORT', invOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('SOURCE_ANALYSIS', invOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('COMMISSION_REPORT', invOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('NIGHT_AUDIT', invOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('SUBSCRIPTION_REPORT', invOnly), isFalse);
      expect(ModuleCapability.isPermissionAllowed('LOYALTY_PROGRAM', invOnly), isFalse);

      // HRMS only should also NOT have them
      expect(ModuleCapability.isReportAllowed('SCHEME_REPORT', hrmsOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('LOYALTY_REPORT', hrmsOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('COMMISSION_REPORT', hrmsOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('NIGHT_AUDIT', hrmsOnly), isFalse);
      expect(ModuleCapability.isReportAllowed('SUBSCRIPTION_REPORT', hrmsOnly), isFalse);
      expect(ModuleCapability.isPermissionAllowed('LOYALTY_PROGRAM', hrmsOnly), isFalse);

      // Retail POS SHOULD have them
      expect(ModuleCapability.isReportAllowed('SCHEME_REPORT', retailMod), isTrue);
      expect(ModuleCapability.isReportAllowed('SCHEME_ANALYSIS', retailMod), isTrue);
      expect(ModuleCapability.isReportAllowed('LOYALTY_REPORT', retailMod), isTrue);
      expect(ModuleCapability.isReportAllowed('COMMISSION_REPORT', retailMod), isTrue);
      expect(ModuleCapability.isReportAllowed('NIGHT_AUDIT', retailMod), isTrue);
      expect(ModuleCapability.isReportAllowed('SUBSCRIPTION_REPORT', retailMod), isTrue);
      expect(ModuleCapability.isPermissionAllowed('LOYALTY_PROGRAM', retailMod), isTrue);
    });

    test('Scenario 11: Document Sequences divided strictly by module', () {
      // 1. Inventory Only: Only PO, Receiving, Indent, Request, Damage
      expect(ModuleCapability.isSequenceAllowed('PO', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('RECEIVING', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('INDENT', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('REQUEST', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('DAMAGE', 'INVENTORY'), isTrue);
      // Inventory should NOT see Sales, KOT, Token, or Accounting Vouchers
      expect(ModuleCapability.isSequenceAllowed('SALES', 'INVENTORY'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('KOT', 'INVENTORY'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('TOKEN', 'INVENTORY'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('CONTRA', 'INVENTORY'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('PAYMENT', 'INVENTORY'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('JOURNAL', 'INVENTORY'), isFalse);

      // 2. Retail POS Only (No inventory): Only SALES and TOKEN
      expect(ModuleCapability.isSequenceAllowed('SALES', 'RETAIL'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('TOKEN', 'RETAIL'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('PO', 'RETAIL'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('RECEIVING', 'RETAIL'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('DAMAGE', 'RETAIL'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('KOT', 'RETAIL'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('CONTRA', 'RETAIL'), isFalse);

      // 3. Restaurant: SALES, KOT, TOKEN
      expect(ModuleCapability.isSequenceAllowed('SALES', 'RESTAURANT'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('KOT', 'RESTAURANT'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('TOKEN', 'RESTAURANT'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('PO', 'RESTAURANT'), isFalse);

      // 4. Accounting: CONTRA, PAYMENT, RECEIPT, JOURNAL
      expect(ModuleCapability.isSequenceAllowed('CONTRA', 'ACCOUNTING'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('PAYMENT', 'ACCOUNTING'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('RECEIPT', 'ACCOUNTING'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('JOURNAL', 'ACCOUNTING'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('SALES', 'ACCOUNTING'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('PO', 'ACCOUNTING'), isFalse);

      // 5. HRMS Only: none of sales, inventory, restaurant, or accounting sequences
      expect(ModuleCapability.isSequenceAllowed('SALES', 'HRMS'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('PO', 'HRMS'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('KOT', 'HRMS'), isFalse);
      expect(ModuleCapability.isSequenceAllowed('CONTRA', 'HRMS'), isFalse);
    });

    test('Scenario 12: Drawer items correctly hide Product Assembly, Loyalty, Scheme, Commission, Night Audit for Inventory Only and HRMS Only', () {
      final sampleDrawer = [
        {'label': 'Product Assembly', 'permission': 'PRODUCT_ASSEMBLY', 'category': 'Operations'},
        {'label': 'Loyalty Program', 'permission': 'LOYALTY_PROGRAM', 'category': 'Masters'},
        {'label': 'Scheme Report', 'permission': 'SCHEME_REPORT', 'category': 'Reports'},
        {'label': 'Scheme Analysis', 'permission': 'SCHEME_ANALYSIS', 'category': 'Reports'},
        {'label': 'Loyalty Report', 'permission': 'LOYALTY_REPORT', 'category': 'Reports'},
        {'label': 'Sale Source Analysis', 'permission': 'SOURCE_ANALYSIS', 'category': 'Reports'},
        {'label': 'Commission Report', 'permission': 'COMMISSION_REPORT', 'category': 'Reports'},
        {'label': 'Night Audit (EOD)', 'permission': 'NIGHT_AUDIT', 'category': 'Reports'},
        {'label': 'Goods Receiving (GRN)', 'permission': 'STOCK_TRANSFER', 'category': 'Operations'},
      ];

      // Inventory Only:
      // Product Assembly, Loyalty Program, Scheme Report/Analysis, Loyalty Report, Sale Source Analysis, Commission Report, Night Audit
      // MUST ALL BE FILTERED OUT! Only Goods Receiving (GRN) remains!
      final invItems = ModuleCapability.filterDrawerItems(sampleDrawer, 'INVENTORY').map((e) => e['label']).toList();
      expect(invItems.contains('Goods Receiving (GRN)'), isTrue);
      expect(invItems.contains('Product Assembly'), isFalse);
      expect(invItems.contains('Loyalty Program'), isFalse);
      expect(invItems.contains('Scheme Report'), isFalse);
      expect(invItems.contains('Scheme Analysis'), isFalse);
      expect(invItems.contains('Loyalty Report'), isFalse);
      expect(invItems.contains('Sale Source Analysis'), isFalse);
      expect(invItems.contains('Commission Report'), isFalse);
      expect(invItems.contains('Night Audit (EOD)'), isFalse);

      // HRMS Only: All of these should be filtered out
      final hrmsItems = ModuleCapability.filterDrawerItems(sampleDrawer, 'HRMS').map((e) => e['label']).toList();
      expect(hrmsItems.isEmpty, isTrue);

      // Retail POS only (without inventory operations):
      final retailItems = ModuleCapability.filterDrawerItems(sampleDrawer, 'RETAIL').map((e) => e['label']).toList();
      expect(retailItems.contains('Loyalty Program'), isTrue);
      expect(retailItems.contains('Scheme Report'), isTrue);
      expect(retailItems.contains('Scheme Analysis'), isTrue);
      expect(retailItems.contains('Loyalty Report'), isTrue);
      expect(retailItems.contains('Sale Source Analysis'), isTrue);
      expect(retailItems.contains('Commission Report'), isTrue);
      expect(retailItems.contains('Night Audit (EOD)'), isTrue);

      // Full Enterprise Suite (ALL) or Retail + Inventory:
      // Product Assembly and all billing/scheme items are present
      final allItems = ModuleCapability.filterDrawerItems(sampleDrawer, 'ALL').map((e) => e['label']).toList();
      expect(allItems.contains('Product Assembly'), isTrue);
      expect(allItems.contains('Goods Receiving (GRN)'), isTrue);
      expect(allItems.contains('Loyalty Program'), isTrue);
      expect(allItems.contains('Scheme Report'), isTrue);
      expect(allItems.contains('Night Audit (EOD)'), isTrue);
    });

    test('Scenario 13: Dedicated Pure HRMS filtering gives ONLY HRMS, Finance Cash/Bank Ledger & Settings', () {
      const hrmsMod = 'HRMS';
      expect(ModuleCapability.isHrmsOnly(hrmsMod), isTrue);
      expect(ModuleCapability.isHrmsOnly('RETAIL,HRMS'), isFalse);
      expect(ModuleCapability.isHrmsOnly('INVENTORY,HRMS'), isFalse);
      expect(ModuleCapability.isHrmsOnly('ALL'), isFalse);

      final fullDrawer = [
        // HRMS (SHOULD KEEP)
        {'label': 'Employee Management', 'permission': 'HR_EMPLOYEES', 'category': 'HR & Payroll'},
        {'label': 'Attendance & Leaves', 'permission': 'HR_ATTENDANCE', 'category': 'HR & Payroll'},
        {'label': 'Payroll', 'permission': 'HR_PAYROLL', 'category': 'HR & Payroll'},
        {'label': 'HR Masters', 'permission': 'HR_MASTERS', 'category': 'HR & Payroll'},
        
        // Finance / Cash Ledger (SHOULD KEEP)
        {'label': 'Regular Expenses', 'permission': 'CASH_LEDGER', 'category': 'Finance & Expenses'},
        {'label': 'Finance & Reports', 'permission': 'CASH_LEDGER', 'category': 'Reports'},

        // Settings / System (SHOULD KEEP)
        {'label': 'Settings', 'permission': 'SETTINGS', 'category': 'System'},
        {'label': 'User Management', 'permission': 'USER_MANAGEMENT', 'category': 'System'},
        {'label': 'Outlet Detail Modification', 'permission': 'PROPERTY_INFORMATION', 'category': 'System'},

        // Stock / Operations / Modify / Masters (MUST HIDE)
        {'label': 'Modify Request', 'permission': null, 'category': 'Modify'},
        {'label': 'Modify Purchase Order', 'permission': null, 'category': 'Modify'},
        {'label': 'Item Master', 'permission': 'ITEM_MASTER', 'category': 'Masters'},
        {'label': 'Vendor Master', 'permission': 'SUPPLIER_MASTER', 'category': 'Masters'},
        {'label': 'Vendor Purchase Order (PO)', 'permission': 'PURCHASE_ORDER', 'category': 'Operations'},
        {'label': 'Stock Balance', 'permission': 'STOCK_BALANCE', 'category': 'Stock View'},
        {'label': 'Billing (POS)', 'permission': 'RETAIL_SALES', 'category': 'Billing'},
        {'label': 'Captain Console', 'permission': 'RESTAURANT_CONSOLE', 'category': 'Restaurant (Beta)'},
        {'label': 'Doctor Appointments', 'permission': 'POS_SALE', 'category': 'Clinic & Health (Beta)'},
        {'label': 'Accounting Vouchers', 'permission': 'CASH_LEDGER', 'category': 'Finance & Accounting (Beta)'},
        {'label': 'Retail Sales Report', 'permission': 'RETAIL_SALES_REPORT', 'category': 'Reports'},
      ];

      final filtered = ModuleCapability.filterDrawerItems(fullDrawer, hrmsMod);
      final filteredLabels = filtered.map((e) => e['label']).toList();

      // Only HRMS, Finance Cash/Bank Ledger, Regular Expenses & Settings must be present:
      expect(filteredLabels.contains('Employee Management'), isTrue);
      expect(filteredLabels.contains('Attendance & Leaves'), isTrue);
      expect(filteredLabels.contains('Payroll'), isTrue);
      expect(filteredLabels.contains('HR Masters'), isTrue);
      expect(filteredLabels.contains('Regular Expenses'), isTrue);
      expect(filteredLabels.contains('Cash / Bank Ledger'), isTrue); // Adapted from Finance & Reports
      expect(filteredLabels.contains('Settings'), isTrue);
      expect(filteredLabels.contains('User Management'), isTrue);
      expect(filteredLabels.contains('Outlet Detail Modification'), isTrue);

      // Inventory, operations, modify, masters, billing, clinic, restaurant, accounting vouchers MUST BE HIDDEN:
      expect(filteredLabels.contains('Modify Request'), isFalse);
      expect(filteredLabels.contains('Modify Purchase Order'), isFalse);
      expect(filteredLabels.contains('Item Master'), isFalse);
      expect(filteredLabels.contains('Vendor Master'), isFalse);
      expect(filteredLabels.contains('Vendor Purchase Order (PO)'), isFalse);
      expect(filteredLabels.contains('Stock Balance'), isFalse);
      expect(filteredLabels.contains('Billing (POS)'), isFalse);
      expect(filteredLabels.contains('Captain Console'), isFalse);
      expect(filteredLabels.contains('Doctor Appointments'), isFalse);
      expect(filteredLabels.contains('Accounting Vouchers'), isFalse);
      expect(filteredLabels.contains('Retail Sales Report'), isFalse);
    });

    test('Scenario 14: User Management Roles strictly filtered by active subscribed module', () {
      // 14a. HRMS only: only ADMIN, MANAGER, HR
      final hrmsRoles = AppConstants.getRolesForModule('HRMS');
      expect(hrmsRoles.contains('ADMIN'), isTrue);
      expect(hrmsRoles.contains('MANAGER'), isTrue);
      expect(hrmsRoles.contains('HR'), isTrue);
      expect(hrmsRoles.contains('DOCTOR'), isFalse, reason: 'DOCTOR must NOT appear in HRMS module');
      expect(hrmsRoles.contains('WAITER'), isFalse);
      expect(hrmsRoles.contains('STORE'), isFalse);
      expect(hrmsRoles.contains('CASHIER'), isFalse);

      // 14b. Inventory only: only ADMIN, MANAGER, STORE
      final invRoles = AppConstants.getRolesForModule('INVENTORY');
      expect(invRoles.contains('ADMIN'), isTrue);
      expect(invRoles.contains('MANAGER'), isTrue);
      expect(invRoles.contains('STORE'), isTrue);
      expect(invRoles.contains('DOCTOR'), isFalse, reason: 'DOCTOR must NOT appear in INVENTORY module');
      expect(invRoles.contains('HR'), isFalse);
      expect(invRoles.contains('WAITER'), isFalse);
      expect(invRoles.contains('CASHIER'), isFalse);

      // 14c. Retail POS only: only ADMIN, MANAGER, RETAIL, CASHIER, MARKETING
      final retailRoles = AppConstants.getRolesForModule('RETAIL');
      expect(retailRoles.contains('ADMIN'), isTrue);
      expect(retailRoles.contains('MANAGER'), isTrue);
      expect(retailRoles.contains('RETAIL'), isTrue);
      expect(retailRoles.contains('CASHIER'), isTrue);
      expect(retailRoles.contains('DOCTOR'), isFalse, reason: 'DOCTOR must NOT appear in RETAIL module');
      expect(retailRoles.contains('WAITER'), isFalse);

      // 14d. Clinic: DOCTOR, RECEPTIONIST, PHARMACIST, CASHIER
      final clinicRoles = AppConstants.getRolesForModule('CLINIC');
      expect(clinicRoles.contains('DOCTOR'), isTrue);
      expect(clinicRoles.contains('RECEPTIONIST'), isTrue);
      expect(clinicRoles.contains('PHARMACIST'), isTrue);
      expect(clinicRoles.contains('WAITER'), isFalse);
    });

    test('Scenario 15: Supervisor PIN only for Restaurant, and Max Discount only when Billing/POS is active', () {
      // Supervisor PIN is for restaurant only
      expect(ModuleCapability.hasRestaurant('HRMS'), isFalse);
      expect(ModuleCapability.hasRestaurant('INVENTORY'), isFalse);
      expect(ModuleCapability.hasRestaurant('COMMUNITY,HRMS'), isFalse);
      expect(ModuleCapability.hasRestaurant('RESTAURANT'), isTrue);
      expect(ModuleCapability.hasRestaurant('RESTAURANT,INVENTORY'), isTrue);

      // Max Manual Discount is enabled only when POS/Billing is active, otherwise saves 0.0
      expect(ModuleCapability.hasBilling('HRMS'), isFalse);
      expect(ModuleCapability.hasBilling('INVENTORY'), isFalse);
      expect(ModuleCapability.hasBilling('COMMUNITY,HRMS'), isFalse);
      expect(ModuleCapability.hasBilling('RETAIL'), isTrue);
      expect(ModuleCapability.hasBilling('RESTAURANT'), isTrue);
      expect(ModuleCapability.hasBilling('ALL'), isTrue);
    });

    test('Scenario 16: Inventory reports decoupled from non-inventory, and Item Master enabled for Billing POS', () {
      // Inventory reports: Receiving, Closing, Vendor Payment, Return, Request
      expect(ModuleCapability.isReportAllowed('STOCK_IN_REPORT', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isReportAllowed('CLOSING_REPORT', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isReportAllowed('VENDOR_PAYMENT_REPORT', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isReportAllowed('RETURN_REPORT', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isReportAllowed('REQUEST_REPORT', 'INVENTORY'), isTrue);

      // Not allowed in pure RETAIL (without inventory)
      expect(ModuleCapability.isReportAllowed('STOCK_IN_REPORT', 'RETAIL'), isFalse);
      expect(ModuleCapability.isReportAllowed('CLOSING_REPORT', 'RETAIL'), isFalse);
      expect(ModuleCapability.isReportAllowed('VENDOR_PAYMENT_REPORT', 'RETAIL'), isFalse);
      expect(ModuleCapability.isReportAllowed('RETURN_REPORT', 'RETAIL'), isFalse);
      expect(ModuleCapability.isReportAllowed('REQUEST_REPORT', 'RETAIL'), isFalse);

      // Drawer items check for pure RETAIL (billing active, inventory inactive)
      final sampleItems = [
        {'category': 'Reports', 'label': 'Receiving Report'},
        {'category': 'Reports', 'label': 'Closing Report'},
        {'category': 'Reports', 'label': 'Vendor Payment Report'},
        {'category': 'Reports', 'label': 'Return Report'},
        {'category': 'Reports', 'label': 'Request Report'},
        {'category': 'Masters', 'label': 'Item Master'},
      ];

      final filteredRetail = ModuleCapability.filterDrawerItems(sampleItems, 'RETAIL');
      final retailLabels = filteredRetail.map((e) => e['label']).toList();

      expect(retailLabels.contains('Receiving Report'), isFalse);
      expect(retailLabels.contains('Closing Report'), isFalse);
      expect(retailLabels.contains('Vendor Payment Report'), isFalse);
      expect(retailLabels.contains('Return Report'), isFalse);
      expect(retailLabels.contains('Request Report'), isFalse);
      expect(retailLabels.contains('Item Master'), isTrue, reason: 'Item master must be accessible for POS billing to manage catalog and images');
    });

    test('Scenario 17: Restaurant sales report allowed and renamed from Retail Sales Report to Sales Report', () {
      final sampleItems = [
        {'category': 'Reports', 'label': 'Retail Sales Report', 'permission': 'RETAIL_SALES_REPORT'},
      ];

      // 17a. In RESTAURANT: it must be included and renamed to 'Sales Report'
      final restaurantDrawer = ModuleCapability.filterDrawerItems(sampleItems, 'RESTAURANT');
      expect(restaurantDrawer.length, 1);
      expect(restaurantDrawer.first['label'], 'Sales Report');

      // 17b. In RETAIL: it must be included as 'Retail Sales Report'
      final retailDrawer = ModuleCapability.filterDrawerItems(sampleItems, 'RETAIL');
      expect(retailDrawer.length, 1);
      expect(retailDrawer.first['label'], 'Retail Sales Report');

      // 17c. In pure HRMS: it must be blocked
      final hrmsDrawer = ModuleCapability.filterDrawerItems(sampleItems, 'HRMS');
      expect(hrmsDrawer.isEmpty, isTrue);

      // 17d. In pure INVENTORY: it must be blocked
      final invDrawer = ModuleCapability.filterDrawerItems(sampleItems, 'INVENTORY');
      expect(invDrawer.isEmpty, isTrue);
    });

    test('Scenario 18: Permissions in User Management strictly filtered by subscribed module', () {
      // 18a. Clinic module: has clinic permissions, NO inventory modification permissions
      expect(ModuleCapability.isPermissionAllowed('CLINIC_APPOINTMENTS', 'CLINIC'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('DOCTOR_CONSULTATION', 'CLINIC'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('MODIFY_REQUEST', 'CLINIC'), isFalse);
      expect(ModuleCapability.isPermissionAllowed('MODIFY_PURCHASE', 'CLINIC'), isFalse);
      expect(ModuleCapability.isPermissionAllowed('REPRINT_RECEIVING', 'CLINIC'), isFalse);

      // 18b. HRMS module: has HR permissions, NO inventory or marketing permissions
      expect(ModuleCapability.isPermissionAllowed('HR_ATTENDANCE', 'HRMS'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('HR_EMPLOYEES', 'HRMS'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('MODIFY_REQUEST', 'HRMS'), isFalse);
      expect(ModuleCapability.isPermissionAllowed('WHATSAPP_INTEGRATION', 'HRMS'), isFalse);
      expect(ModuleCapability.isPermissionAllowed('RESTAURANT_KDS', 'HRMS'), isFalse);

      // 18c. Inventory module: has inventory permissions, NO restaurant/clinic permissions
      expect(ModuleCapability.isPermissionAllowed('MODIFY_REQUEST', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('MODIFY_RECEIVING', 'INVENTORY'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('RESTAURANT_KDS', 'INVENTORY'), isFalse);
      expect(ModuleCapability.isPermissionAllowed('CLINIC_APPOINTMENTS', 'INVENTORY'), isFalse);

      // 18d. Retail module: has retail/billing permissions, NO inventory doc modifications
      expect(ModuleCapability.isPermissionAllowed('RETAIL_SALES', 'RETAIL'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('MODIFY_REQUEST', 'RETAIL'), isFalse);
      expect(ModuleCapability.isPermissionAllowed('RESTAURANT_KDS', 'RETAIL'), isFalse);

      // 18e. Multi-module: RETAIL,INVENTORY gets both
      expect(ModuleCapability.isPermissionAllowed('RETAIL_SALES', 'RETAIL,INVENTORY'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('MODIFY_REQUEST', 'RETAIL,INVENTORY'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('CLINIC_APPOINTMENTS', 'RETAIL,INVENTORY'), isFalse);
    });

    test('Scenario 19: Clinic module cases (Pharmacy Sale Report, Expenses & Delivery Challans, Deduplicated Billing/Masters, Appointment Token)', () {
      // 19a. Case 1: In Clinic-only, Sales Report label adapts to 'Pharmacy Sale Report'
      expect(ModuleCapability.adaptLabel('Retail Sales Report', 'CLINIC'), 'Pharmacy Sale Report');
      expect(ModuleCapability.adaptLabel('Sales Report', 'CLINIC'), 'Pharmacy Sale Report');
      // In Restaurant, it adapts to 'Sales Report'
      expect(ModuleCapability.adaptLabel('Retail Sales Report', 'RESTAURANT'), 'Sales Report');
      // In Retail, it remains 'Retail Sales Report'
      expect(ModuleCapability.adaptLabel('Retail Sales Report', 'RETAIL'), 'Retail Sales Report');

      // 19b. Case 2: Recurring Expenses & Delivery Challans are allowed for Retail, Restaurant, and Clinic
      expect(ModuleCapability.isPermissionAllowed('RECURRING_EXPENSES', 'RETAIL'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('RECURRING_EXPENSES', 'RESTAURANT'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('RECURRING_EXPENSES', 'CLINIC'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('RECURRING_EXPENSES', 'HRMS'), isFalse);

      expect(ModuleCapability.isPermissionAllowed('DELIVERY_CHALLANS', 'RETAIL'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('DELIVERY_CHALLANS', 'RESTAURANT'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('DELIVERY_CHALLANS', 'CLINIC'), isTrue);
      expect(ModuleCapability.isPermissionAllowed('DELIVERY_CHALLANS', 'HRMS'), isFalse);

      // 19c. Case 3 & 4: In Clinic-only, generic Billing drawer group and generic Item Master are removed
      final sampleDrawer = [
        {'category': 'Billing', 'label': 'Billing (POS)'},
        {'category': 'Clinic & Health (Beta)', 'label': 'Clinic Billing & Pharmacy POS', 'permission': 'POS_SALE'},
        {'category': 'Clinic & Health (Beta)', 'label': 'Medicines, Lab Tests & Services Master', 'permission': 'ITEM_MASTER'},
        {'category': 'Masters', 'label': 'Item Master'},
      ];

      final clinicDrawer = ModuleCapability.filterDrawerItems(sampleDrawer, 'CLINIC');
      final clinicLabels = clinicDrawer.map((e) => e['label']).toList();

      expect(clinicLabels.contains('Clinic Billing & Pharmacy POS'), isTrue);
      expect(clinicLabels.contains('Medicines, Lab Tests & Services Master'), isTrue);
      expect(clinicLabels.contains('Billing (POS)'), isFalse, reason: 'Generic billing must be hidden in clinic-only');
      expect(clinicLabels.contains('Item Master'), isFalse, reason: 'Generic item master must be hidden in clinic-only');

      // 19d. Case 5: Token Sequence is allowed for Clinic (as Appointment Token)
      expect(ModuleCapability.isSequenceAllowed('TOKEN', 'CLINIC'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('TOKEN', 'RESTAURANT'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('TOKEN', 'RETAIL'), isTrue);
      expect(ModuleCapability.isSequenceAllowed('TOKEN', 'HRMS'), isFalse);
    });

    test('Scenario 20: User Management permissions and categories adapted strictly by active module', () {
      // 20a. Category allowed check
      expect(ModuleCapability.isCategoryAllowed('Inventory & Stock', 'CLINIC'), isFalse, reason: 'Inventory not allowed in pure clinic');
      expect(ModuleCapability.isCategoryAllowed('Modify Documents', 'CLINIC'), isFalse);
      expect(ModuleCapability.isCategoryAllowed('Restaurant & Dining', 'CLINIC'), isFalse);
      expect(ModuleCapability.isCategoryAllowed('HR & Attendance', 'CLINIC'), isFalse);
      expect(ModuleCapability.isCategoryAllowed('Clinic & Healthcare', 'CLINIC'), isTrue);
      expect(ModuleCapability.isCategoryAllowed('Retail Sales & POS', 'CLINIC'), isTrue);

      expect(ModuleCapability.isCategoryAllowed('Restaurant & Dining', 'RESTAURANT'), isTrue);
      expect(ModuleCapability.isCategoryAllowed('Clinic & Healthcare', 'RESTAURANT'), isFalse);

      // 20b. Category name adaptation
      expect(ModuleCapability.adaptCategoryName('Retail Sales & POS', 'CLINIC'), 'Pharmacy & Clinic Billing');
      expect(ModuleCapability.adaptCategoryName('Retail Sales & POS', 'RESTAURANT'), 'Restaurant Sales & Billing POS');
      expect(ModuleCapability.adaptCategoryName('Retail Sales & POS', 'RETAIL'), 'Retail Sales & POS');
      expect(ModuleCapability.adaptCategoryName('Accounts & Finance', 'CLINIC'), 'Clinic Finance & Cash Ledger');
      expect(ModuleCapability.adaptCategoryName('Marketing & Campaigns', 'CLINIC'), 'Patient Outreach & Loyalty');
      expect(ModuleCapability.adaptCategoryName('Reports & Intelligence', 'CLINIC'), 'Clinic Reports & Analytics');

      // 20c. Permission label adaptation
      expect(ModuleCapability.adaptPermissionLabel('ITEM_MASTER', 'Item Master / Products', 'CLINIC'), 'Medicines, Lab Tests & Services Master');
      expect(ModuleCapability.adaptPermissionLabel('ITEM_MASTER', 'Item Master / Products', 'RESTAURANT'), 'Menu Items & Recipes Master');
      expect(ModuleCapability.adaptPermissionLabel('ITEM_MASTER', 'Item Master / Products', 'RETAIL'), 'Item Master / Products');

      expect(ModuleCapability.adaptPermissionLabel('ENTERPRISE_POS', 'Enterprise POS Terminal', 'CLINIC'), 'Pharmacy & Clinic Billing Terminal');
      expect(ModuleCapability.adaptPermissionLabel('CUSTOMER_LIST', 'Customer Master & Directory', 'CLINIC'), 'Patient Directory & Profiles');
      expect(ModuleCapability.adaptPermissionLabel('ADD_CUSTOMER', 'Add New Customer', 'CLINIC'), 'Add New Patient');
      expect(ModuleCapability.adaptPermissionLabel('DRAFT_BILLS', 'Draft Bills & Saved Carts', 'CLINIC'), 'Draft Prescriptions & Saved Carts');

      expect(ModuleCapability.adaptPermissionLabel('ENTERPRISE_POS', 'Enterprise POS Terminal', 'RESTAURANT'), 'Restaurant POS Terminal');
      expect(ModuleCapability.adaptPermissionLabel('CUSTOMER_LIST', 'Customer Master & Directory', 'RESTAURANT'), 'Guest & Diner Directory');
      expect(ModuleCapability.adaptPermissionLabel('PRODUCT_ASSEMBLY', 'Product Assembly / Recipe', 'RESTAURANT'), 'Recipe Management');
    });
  });
}
