import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';

class DataDictionaryColumn {
  final String name;
  final String type;
  final String description;
  final bool isPrimaryKey;
  final bool isForeignKey;

  const DataDictionaryColumn({
    required this.name,
    required this.type,
    required this.description,
    this.isPrimaryKey = false,
    this.isForeignKey = false,
  });
}

class DataDictionaryTable {
  final String tableName;
  final String displayName;
  final String domain;
  final IconData icon;
  final String businessUse;
  final String defaultQuery;
  final List<DataDictionaryColumn> columns;

  const DataDictionaryTable({
    required this.tableName,
    required this.displayName,
    required this.domain,
    required this.icon,
    required this.businessUse,
    required this.defaultQuery,
    required this.columns,
  });
}

class QueryRecipe {
  final String title;
  final String domain;
  final IconData icon;
  final String sql;

  const QueryRecipe({
    required this.title,
    required this.domain,
    required this.icon,
    required this.sql,
  });
}

class SystemDataDictionary {
  static const List<QueryRecipe> commonRecipes = [
    QueryRecipe(
      title: 'Products & Prices',
      domain: 'Catalog',
      icon: Icons.inventory_2_rounded,
      sql: 'SELECT id, item_code, item_name, rate, mrp, opening_balance FROM item_master LIMIT 20;',
    ),
    QueryRecipe(
      title: 'Recent 10 Invoices',
      domain: 'Sales',
      icon: Icons.receipt_long_rounded,
      sql: 'SELECT id, sale_no, customer_name, payment_mode, net_amount, status, created_at FROM sales_headers ORDER BY created_at DESC LIMIT 10;',
    ),
    QueryRecipe(
      title: 'Invoice Line Items',
      domain: 'Sales',
      icon: Icons.shopping_cart_checkout_rounded,
      sql: 'SELECT id, sale_id, item_code, item_name, qty, rate, amount, net_amount FROM sales_items LIMIT 25;',
    ),
    QueryRecipe(
      title: 'Missing Barcodes',
      domain: 'Catalog',
      icon: Icons.qr_code_scanner_rounded,
      sql: "SELECT id, item_code, item_name, rate, barcode FROM item_master WHERE barcode IS NULL OR barcode = '' LIMIT 20;",
    ),
    QueryRecipe(
      title: 'Low Stock Items',
      domain: 'Stock',
      icon: Icons.trending_down_rounded,
      sql: 'SELECT item_code, item_name, opening_balance, min_level FROM item_master WHERE opening_balance <= min_level LIMIT 25;',
    ),
    QueryRecipe(
      title: 'Cashier Staff Logins',
      domain: 'Users',
      icon: Icons.badge_rounded,
      sql: 'SELECT id, username, full_name, role, is_active, last_login FROM users LIMIT 15;',
    ),
    QueryRecipe(
      title: 'Branch Outlets & Terminals',
      domain: 'Store',
      icon: Icons.storefront_rounded,
      sql: 'SELECT id, outlet_name, outlet_code, outlet_type, business_module, is_active FROM outlets LIMIT 10;',
    ),
    QueryRecipe(
      title: 'Cash Drawer Shifts',
      domain: 'Cash',
      icon: Icons.point_of_sale_rounded,
      sql: 'SELECT id, txn_date, transaction_type, payment_method, amount_in, amount_out, balance, created_by FROM cash_ledger ORDER BY id DESC LIMIT 10;',
    ),
    QueryRecipe(
      title: 'Restaurant KOTs',
      domain: 'Dining',
      icon: Icons.restaurant_rounded,
      sql: 'SELECT id, kot_no, table_id, service_type, status, waiter_id, created_at FROM kot_headers ORDER BY id DESC LIMIT 10;',
    ),
    QueryRecipe(
      title: 'Tax Profile Rules',
      domain: 'Tax',
      icon: Icons.percent_rounded,
      sql: 'SELECT id, tax_name, default_rate, is_editable FROM taxes_master LIMIT 10;',
    ),
  ];

  static const List<DataDictionaryTable> tables = [
    // 1. item_master
    DataDictionaryTable(
      tableName: 'item_master',
      displayName: 'Product Catalog & Item Master',
      domain: 'Catalog & Inventory',
      icon: Icons.inventory_2_rounded,
      businessUse: 'Core retail & restaurant merchandise catalog. Holds selling prices, tax slabs, barcodes, departments, and stock tracking flags.',
      defaultQuery: 'SELECT id, item_code, item_name, barcode, rate, retail_sale_price, tax_percent, opening_balance, is_active FROM item_master LIMIT 20;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Primary unique product identifier', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID this product belongs to', isForeignKey: true),
        DataDictionaryColumn(name: 'item_code', type: 'VARCHAR(50)', description: 'SKU or internal item code used for inventory reference'),
        DataDictionaryColumn(name: 'item_name', type: 'VARCHAR(255)', description: 'Full commercial title displayed on cash register and receipt'),
        DataDictionaryColumn(name: 'item_group', type: 'VARCHAR(100)', description: 'Top-level department (e.g. Grocery, Footwear, Bakery, Apparel)'),
        DataDictionaryColumn(name: 'sub_category', type: 'VARCHAR(100)', description: 'Sub-department categorization (e.g. T-Shirts, Biscuits)'),
        DataDictionaryColumn(name: 'barcode', type: 'VARCHAR(100)', description: 'EAN-13, UPC, or custom code scanned by cashiers at checkout'),
        DataDictionaryColumn(name: 'rate', type: 'NUMERIC(12,2)', description: 'Base purchase/cost price from vendor before markup'),
        DataDictionaryColumn(name: 'retail_sale_price', type: 'NUMERIC(12,2)', description: 'Selling price charged to shoppers at POS'),
        DataDictionaryColumn(name: 'tax_percent', type: 'NUMERIC(5,2)', description: 'Applicable GST / VAT tax rate (e.g. 5.00, 18.00)'),
        DataDictionaryColumn(name: 'hsn_sac_code', type: 'VARCHAR(50)', description: 'Harmonized System of Nomenclature code for statutory tax compliance'),
        DataDictionaryColumn(name: 'opening_balance', type: 'NUMERIC(12,2)', description: 'Current available physical stock on store floor'),
        DataDictionaryColumn(name: 'min_level', type: 'INT', description: 'Reorder safety threshold; triggers low stock warning'),
        DataDictionaryColumn(name: 'max_level', type: 'INT', description: 'Overstock ceiling to prevent excessive working capital lockup'),
        DataDictionaryColumn(name: 'stockable', type: 'BOOLEAN', description: 'true = track physical stock count; false = service or digital item'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'true = enabled for sales; false = archived/discontinued'),
      ],
    ),

    // 2. sales_headers
    DataDictionaryTable(
      tableName: 'sales_headers',
      displayName: 'Invoices & Sales Transactions',
      domain: 'Sales & Billing',
      icon: Icons.receipt_long_rounded,
      businessUse: 'Master bill record for every completed, parked, or returned sales transaction generated at store checkout.',
      defaultQuery: 'SELECT id, invoice_number, grand_total, total_tax, discount_amount, payment_mode, is_hold, created_at FROM sales_headers ORDER BY created_at DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Unique internal sales invoice transaction key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Store branch where the transaction took place', isForeignKey: true),
        DataDictionaryColumn(name: 'invoice_number', type: 'VARCHAR(100)', description: 'Legal receipt number printed on customer invoice (e.g. INV-2026-0042)'),
        DataDictionaryColumn(name: 'customer_id', type: 'INT', description: 'Reference to shopper profile in customers table', isForeignKey: true),
        DataDictionaryColumn(name: 'user_id', type: 'INT', description: 'Cashier/operator user ID who processed the billing', isForeignKey: true),
        DataDictionaryColumn(name: 'total_tax', type: 'NUMERIC(12,2)', description: 'Cumulative tax breakdown (CGST+SGST/VAT) collected on bill'),
        DataDictionaryColumn(name: 'discount_amount', type: 'NUMERIC(12,2)', description: 'Overall bill coupon, scheme, or manual discount deducted'),
        DataDictionaryColumn(name: 'grand_total', type: 'NUMERIC(12,2)', description: 'Net final payable amount settled by customer'),
        DataDictionaryColumn(name: 'payment_mode', type: 'VARCHAR(50)', description: 'Payment tender (CASH, CARD, UPI, SPLIT, CREDIT)'),
        DataDictionaryColumn(name: 'is_hold', type: 'BOOLEAN', description: 'true = temporarily parked/held bill; false = finalized invoice'),
        DataDictionaryColumn(name: 'created_at', type: 'TIMESTAMPTZ', description: 'Exact audit timestamp when the bill was recorded'),
      ],
    ),

    // 3. sales_items
    DataDictionaryTable(
      tableName: 'sales_items',
      displayName: 'Invoice Line Items',
      domain: 'Sales & Billing',
      icon: Icons.shopping_cart_checkout_rounded,
      businessUse: 'Line-by-line item details inside each invoice, showing quantity sold, unit price, discounts, and line tax.',
      defaultQuery: 'SELECT id, sale_header_id, item_name, quantity, unit_price, discount, net_amount FROM sales_items LIMIT 20;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Line item primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'sale_header_id', type: 'BIGINT', description: 'Foreign key link to parent sales_headers record', isForeignKey: true),
        DataDictionaryColumn(name: 'item_id', type: 'BIGINT', description: 'Product key pointing to item_master', isForeignKey: true),
        DataDictionaryColumn(name: 'item_name', type: 'VARCHAR(255)', description: 'Snapshot of product title at time of sale'),
        DataDictionaryColumn(name: 'quantity', type: 'NUMERIC(10,3)', description: 'Number of units, weight in KG, or pieces rung up'),
        DataDictionaryColumn(name: 'unit_price', type: 'NUMERIC(12,2)', description: 'Item price charged per unit'),
        DataDictionaryColumn(name: 'discount', type: 'NUMERIC(12,2)', description: 'Item-level promo or manual discount deducted'),
        DataDictionaryColumn(name: 'net_amount', type: 'NUMERIC(12,2)', description: 'Final subtotal for this line: (quantity * unit_price) - discount'),
      ],
    ),

    // 4. stock_ledger
    DataDictionaryTable(
      tableName: 'stock_ledger',
      displayName: 'Perpetual Stock Ledger',
      domain: 'Catalog & Inventory',
      icon: Icons.history_edu_rounded,
      businessUse: 'Full audit ledger of every inventory movement (inward purchase, sale checkout, return, damage adjustment, or inter-store transfer).',
      defaultQuery: 'SELECT id, item_id, transaction_type, quantity_in, quantity_out, balance_qty, reference_no, created_at FROM stock_ledger ORDER BY created_at DESC LIMIT 20;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Stock ledger entry ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Branch outlet where movement occurred', isForeignKey: true),
        DataDictionaryColumn(name: 'item_id', type: 'BIGINT', description: 'Product reference from item_master', isForeignKey: true),
        DataDictionaryColumn(name: 'transaction_type', type: 'VARCHAR(50)', description: 'Type: SALE, PURCHASE, RETURN, DAMAGE, AUDIT_ADJUSTMENT'),
        DataDictionaryColumn(name: 'quantity_in', type: 'NUMERIC(10,3)', description: 'Positive quantity added to stock'),
        DataDictionaryColumn(name: 'quantity_out', type: 'NUMERIC(10,3)', description: 'Quantity deducted from stock'),
        DataDictionaryColumn(name: 'balance_qty', type: 'NUMERIC(10,3)', description: 'Updated inventory balance immediately after entry'),
        DataDictionaryColumn(name: 'reference_no', type: 'VARCHAR(100)', description: 'Document voucher number (Invoice #, GRN #, or Challan #)'),
      ],
    ),

    // 5. users
    DataDictionaryTable(
      tableName: 'users',
      displayName: 'POS Cashier & Staff Accounts',
      domain: 'Store & IAM',
      icon: Icons.badge_rounded,
      businessUse: 'Store cashier, supervisor, and store manager login accounts with roles, pin codes, and active status flags.',
      defaultQuery: 'SELECT id, username, full_name, email, role, is_active, outlet_id, created_at FROM users LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'User account primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Branch store assigned to this operator', isForeignKey: true),
        DataDictionaryColumn(name: 'username', type: 'VARCHAR(100)', description: 'Cashier login username entered on login screen'),
        DataDictionaryColumn(name: 'full_name', type: 'VARCHAR(150)', description: 'Full staff name printed on bill receipts ("Billed by: Sarah")'),
        DataDictionaryColumn(name: 'email', type: 'VARCHAR(150)', description: 'Official staff email address'),
        DataDictionaryColumn(name: 'role', type: 'VARCHAR(50)', description: 'Access tier: CASHIER, SUPERVISOR, STORE_MANAGER, ADMIN'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'true = active operator; false = login blocked / deactivated'),
      ],
    ),

    // 6. outlets
    DataDictionaryTable(
      tableName: 'outlets',
      displayName: 'Store Branches & Properties',
      domain: 'Store & Infrastructure',
      icon: Icons.storefront_rounded,
      businessUse: 'Branch outlets registered for merchant property. Controls terminal kill-switch, machine hardware binding, and store addresses.',
      defaultQuery: 'SELECT id, outlet_name, outlet_code, address, hardware_machine_id, is_active, created_at FROM outlets LIMIT 10;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Outlet branch ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_name', type: 'VARCHAR(150)', description: 'Commercial branch title (e.g. Main High Street Branch)'),
        DataDictionaryColumn(name: 'outlet_code', type: 'VARCHAR(50)', description: 'Unique store identifier code (e.g. OUT01)'),
        DataDictionaryColumn(name: 'address', type: 'TEXT', description: 'Physical store location address printed on receipts'),
        DataDictionaryColumn(name: 'hardware_machine_id', type: 'VARCHAR(100)', description: 'Licensed POS terminal machine hardware fingerprint'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'Remote kill-switch: true = store active; false = locked down'),
      ],
    ),

    // 7. customers
    DataDictionaryTable(
      tableName: 'customers',
      displayName: 'Shopper Directory & Loyalty',
      domain: 'Customers & CRM',
      icon: Icons.people_alt_rounded,
      businessUse: 'Customer address book, phone numbers for SMS/WhatsApp receipts, loyalty reward points, and credit ledger balances.',
      defaultQuery: 'SELECT id, customer_name, phone, email, credit_balance, loyalty_points, is_active FROM customers LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Customer unique identifier', isPrimaryKey: true),
        DataDictionaryColumn(name: 'customer_name', type: 'VARCHAR(150)', description: 'Shopper or company account name'),
        DataDictionaryColumn(name: 'phone', type: 'VARCHAR(30)', description: 'Mobile phone number used for lookup at checkout'),
        DataDictionaryColumn(name: 'email', type: 'VARCHAR(150)', description: 'Email address for e-receipts and statements'),
        DataDictionaryColumn(name: 'credit_balance', type: 'NUMERIC(12,2)', description: 'Current outstanding credit balance owed on ledger'),
        DataDictionaryColumn(name: 'loyalty_points', type: 'INT', description: 'Accumulated reward points redeemable as bill discounts'),
      ],
    ),

    // 8. cash_ledger
    DataDictionaryTable(
      tableName: 'cash_ledger',
      displayName: 'Cash Drawer Float & Shifts',
      domain: 'Finance & Cash',
      icon: Icons.point_of_sale_rounded,
      businessUse: 'Cash drawer session float tracking. Records opening cash, closing cash count, petty cash in/out, and shift reconciliation.',
      defaultQuery: 'SELECT id, cashier_id, opening_cash, closing_cash, cash_in, cash_out, shift_status, created_at FROM cash_ledger ORDER BY created_at DESC LIMIT 10;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Cash drawer shift session ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'cashier_id', type: 'INT', description: 'Cashier who opened the drawer float', isForeignKey: true),
        DataDictionaryColumn(name: 'opening_cash', type: 'NUMERIC(12,2)', description: 'Starting cash change placed into drawer at shift start'),
        DataDictionaryColumn(name: 'closing_cash', type: 'NUMERIC(12,2)', description: 'Physical cash declared by cashier at shift close'),
        DataDictionaryColumn(name: 'cash_in', type: 'NUMERIC(12,2)', description: 'Manual ad-hoc cash additions during the day'),
        DataDictionaryColumn(name: 'cash_out', type: 'NUMERIC(12,2)', description: 'Petty cash payouts removed from the till'),
        DataDictionaryColumn(name: 'shift_status', type: 'VARCHAR(30)', description: 'Session status: OPEN or CLOSED'),
      ],
    ),

    // 9. kot_headers
    DataDictionaryTable(
      tableName: 'kot_headers',
      displayName: 'Kitchen Order Tickets (Dining)',
      domain: 'F&B & Restaurant',
      icon: Icons.restaurant_rounded,
      businessUse: 'Kitchen Order Tickets (KOT) created when restaurant servers place food orders for dine-in tables, room service, or takeaway.',
      defaultQuery: 'SELECT id, kot_number, table_number, server_name, order_status, total_items, created_at FROM kot_headers ORDER BY created_at DESC LIMIT 10;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Kitchen ticket unique ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'kot_number', type: 'VARCHAR(50)', description: 'KOT sequence number printed in kitchen (e.g. KOT-104)'),
        DataDictionaryColumn(name: 'table_number', type: 'VARCHAR(30)', description: 'Dining table number or Area (e.g. T-04, Patio-2)'),
        DataDictionaryColumn(name: 'server_name', type: 'VARCHAR(100)', description: 'Waiter or server who punched the food order'),
        DataDictionaryColumn(name: 'order_status', type: 'VARCHAR(50)', description: 'Status: PENDING, COOKING, READY, SERVED, CANCELLED'),
        DataDictionaryColumn(name: 'total_items', type: 'INT', description: 'Total count of food dishes on this kitchen slip'),
      ],
    ),

    // 10. taxes_master
    DataDictionaryTable(
      tableName: 'taxes_master',
      displayName: 'Tax Configurations & Profiles',
      domain: 'Taxation & Legal',
      icon: Icons.percent_rounded,
      businessUse: 'Tax rates, slabs, and calculation rules applied to billable line items (e.g. GST 18%, VAT 5%, Exempt).',
      defaultQuery: 'SELECT id, tax_name, tax_percent, tax_type, is_active FROM taxes_master LIMIT 10;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Tax slab primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'tax_name', type: 'VARCHAR(100)', description: 'Tax display label (e.g. GST 18%, VAT 5%, Zero Rated)'),
        DataDictionaryColumn(name: 'tax_percent', type: 'NUMERIC(5,2)', description: 'Applicable percentage rate (e.g. 18.00)'),
        DataDictionaryColumn(name: 'tax_type', type: 'VARCHAR(50)', description: 'Calculation mode: INCLUSIVE (in item price) or EXCLUSIVE (added on top)'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'true = active tax slab; false = retired slab'),
      ],
    ),

    // 11. supplier_master
    DataDictionaryTable(
      tableName: 'supplier_master',
      displayName: 'Supplier Master (Vendors)',
      domain: 'Purchases & Vendors',
      icon: Icons.local_shipping_rounded,
      businessUse: 'Vendor profiles, GSTIN numbers, contact details, payment terms, and opening debit/credit balances.',
      defaultQuery: 'SELECT id, supplier_name, gstin, phone, email, balance, is_active FROM supplier_master LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Supplier primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'supplier_name', type: 'VARCHAR(150)', description: 'Vendor company or trade name'),
        DataDictionaryColumn(name: 'gstin', type: 'VARCHAR(20)', description: 'Tax registration number (GSTIN / VAT)'),
        DataDictionaryColumn(name: 'phone', type: 'VARCHAR(30)', description: 'Contact phone number'),
        DataDictionaryColumn(name: 'email', type: 'VARCHAR(150)', description: 'Email address'),
        DataDictionaryColumn(name: 'balance', type: 'NUMERIC(12,2)', description: 'Outstanding payable balance'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'true = active vendor; false = blacklisted/archived'),
      ],
    ),

    // 12. supplier_bills
    DataDictionaryTable(
      tableName: 'supplier_bills',
      displayName: 'Purchase Bills & Inward GRNs',
      domain: 'Purchases & Vendors',
      icon: Icons.inventory_rounded,
      businessUse: 'Vendor purchase bills, GRN voucher numbers, taxable values, and payment status.',
      defaultQuery: 'SELECT id, bill_number, supplier_id, total_amount, paid_amount, payment_status, bill_date FROM supplier_bills ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Bill primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'supplier_id', type: 'BIGINT', description: 'Vendor pointer in supplier_master', isForeignKey: true),
        DataDictionaryColumn(name: 'bill_number', type: 'VARCHAR(100)', description: 'Invoice/Bill number issued by supplier'),
        DataDictionaryColumn(name: 'total_amount', type: 'NUMERIC(12,2)', description: 'Gross invoice payable value'),
        DataDictionaryColumn(name: 'paid_amount', type: 'NUMERIC(12,2)', description: 'Total disbursed payments against this bill'),
        DataDictionaryColumn(name: 'payment_status', type: 'VARCHAR(30)', description: 'PAID, PARTIAL, or PENDING'),
        DataDictionaryColumn(name: 'bill_date', type: 'DATE', description: 'Invoice bill date'),
      ],
    ),

    // 13. supplier_payments
    DataDictionaryTable(
      tableName: 'supplier_payments',
      displayName: 'Vendor Payments',
      domain: 'Purchases & Vendors',
      icon: Icons.payments_rounded,
      businessUse: 'Payment disbursements made to vendors against purchase bills, cheque/NEFT references, and bank accounts.',
      defaultQuery: 'SELECT id, payment_number, supplier_id, amount, payment_mode, payment_date FROM supplier_payments ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Payment voucher ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'supplier_id', type: 'BIGINT', description: 'Vendor pointer', isForeignKey: true),
        DataDictionaryColumn(name: 'payment_number', type: 'VARCHAR(100)', description: 'Internal payment voucher number'),
        DataDictionaryColumn(name: 'amount', type: 'NUMERIC(12,2)', description: 'Payment settlement amount'),
        DataDictionaryColumn(name: 'payment_mode', type: 'VARCHAR(50)', description: 'CASH, CHEQUE, NEFT, RTGS, UPI'),
        DataDictionaryColumn(name: 'payment_date', type: 'DATE', description: 'Payment execution date'),
      ],
    ),

    // 14. purchase_orders
    DataDictionaryTable(
      tableName: 'purchase_orders',
      displayName: 'Purchase Orders (PO)',
      domain: 'Purchases & Vendors',
      icon: Icons.assignment_rounded,
      businessUse: 'Procurement orders dispatched to suppliers before inward goods delivery.',
      defaultQuery: 'SELECT id, po_number, supplier_id, total_amount, status, order_date FROM purchase_orders ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'PO primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'po_number', type: 'VARCHAR(100)', description: 'Sequential PO reference (e.g. PO-2026-001)'),
        DataDictionaryColumn(name: 'supplier_id', type: 'BIGINT', description: 'Supplier reference', isForeignKey: true),
        DataDictionaryColumn(name: 'total_amount', type: 'NUMERIC(12,2)', description: 'Estimated PO total'),
        DataDictionaryColumn(name: 'status', type: 'VARCHAR(50)', description: 'DRAFT, SENT, RECEIVED, CANCELLED'),
        DataDictionaryColumn(name: 'order_date', type: 'DATE', description: 'Date PO was created'),
      ],
    ),

    // 15. bank_accounts
    DataDictionaryTable(
      tableName: 'bank_accounts',
      displayName: 'Bank Accounts',
      domain: 'Finance & Accounts',
      icon: Icons.account_balance_rounded,
      businessUse: 'Merchant bank accounts, UPI handles, clearing accounts, and reconciled book balances.',
      defaultQuery: 'SELECT id, account_name, bank_name, account_number, current_balance, is_active FROM bank_accounts LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Bank account ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'account_name', type: 'VARCHAR(150)', description: 'Account display title'),
        DataDictionaryColumn(name: 'bank_name', type: 'VARCHAR(100)', description: 'Banking institution name (e.g. HDFC, Chase)'),
        DataDictionaryColumn(name: 'account_number', type: 'VARCHAR(50)', description: 'Bank account number'),
        DataDictionaryColumn(name: 'current_balance', type: 'NUMERIC(14,2)', description: 'Current available balance in account'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'true = active; false = closed'),
      ],
    ),

    // 16. chart_of_accounts
    DataDictionaryTable(
      tableName: 'chart_of_accounts',
      displayName: 'Chart of Accounts (COA)',
      domain: 'Finance & Accounts',
      icon: Icons.account_tree_rounded,
      businessUse: 'General ledger chart of accounts hierarchy defining Assets, Liabilities, Incomes, and Expenses.',
      defaultQuery: 'SELECT id, account_code, account_name, account_type, is_active FROM chart_of_accounts ORDER BY account_code LIMIT 20;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'COA primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'account_code', type: 'VARCHAR(50)', description: 'Standard accounting code (e.g. 1000, 2000)'),
        DataDictionaryColumn(name: 'account_name', type: 'VARCHAR(150)', description: 'Ledger account title'),
        DataDictionaryColumn(name: 'account_type', type: 'VARCHAR(50)', description: 'ASSET, LIABILITY, EQUITY, INCOME, EXPENSE'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'Active status flag'),
      ],
    ),

    // 17. accounting_vouchers
    DataDictionaryTable(
      tableName: 'accounting_vouchers',
      displayName: 'Accounting Vouchers',
      domain: 'Finance & Accounts',
      icon: Icons.receipt_long_rounded,
      businessUse: 'Double-entry journal, payment, receipt, and contra voucher header records.',
      defaultQuery: 'SELECT id, voucher_number, voucher_type, voucher_date, total_debit, total_credit FROM accounting_vouchers ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Voucher primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'voucher_number', type: 'VARCHAR(100)', description: 'Voucher sequence identifier'),
        DataDictionaryColumn(name: 'voucher_type', type: 'VARCHAR(50)', description: 'JOURNAL, PAYMENT, RECEIPT, CONTRA'),
        DataDictionaryColumn(name: 'voucher_date', type: 'DATE', description: 'Transaction date'),
        DataDictionaryColumn(name: 'total_debit', type: 'NUMERIC(14,2)', description: 'Sum of debit entries'),
        DataDictionaryColumn(name: 'total_credit', type: 'NUMERIC(14,2)', description: 'Sum of credit entries'),
      ],
    ),

    // 18. expenses
    DataDictionaryTable(
      tableName: 'expenses',
      displayName: 'Expense Entries',
      domain: 'Finance & Accounts',
      icon: Icons.money_off_rounded,
      businessUse: 'Operational daily store expense records (petty cash, stationery, packaging, tea, logistics).',
      defaultQuery: 'SELECT id, title, amount, category, payment_mode, expense_date FROM expenses ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Expense entry ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'title', type: 'VARCHAR(200)', description: 'Expense title / narration'),
        DataDictionaryColumn(name: 'amount', type: 'NUMERIC(12,2)', description: 'Amount spent'),
        DataDictionaryColumn(name: 'category', type: 'VARCHAR(100)', description: 'Expense head / category'),
        DataDictionaryColumn(name: 'payment_mode', type: 'VARCHAR(50)', description: 'CASH, BANK, UPI'),
        DataDictionaryColumn(name: 'expense_date', type: 'DATE', description: 'Date incurred'),
      ],
    ),

    // 19. hr_employees
    DataDictionaryTable(
      tableName: 'hr_employees',
      displayName: 'Employees & Payroll Staff',
      domain: 'HR & Payroll',
      icon: Icons.badge_rounded,
      businessUse: 'Employee profiles, designations, departments, basic salary, and joining dates.',
      defaultQuery: 'SELECT id, employee_code, first_name, designation, department, basic_salary, is_active FROM hr_employees LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Employee ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'employee_code', type: 'VARCHAR(50)', description: 'Unique staff badge code'),
        DataDictionaryColumn(name: 'first_name', type: 'VARCHAR(100)', description: 'Staff first name'),
        DataDictionaryColumn(name: 'designation', type: 'VARCHAR(100)', description: 'Job role / designation'),
        DataDictionaryColumn(name: 'department', type: 'VARCHAR(100)', description: 'Department (Sales, Kitchen, Cashier)'),
        DataDictionaryColumn(name: 'basic_salary', type: 'NUMERIC(12,2)', description: 'Monthly basic remuneration'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'true = active; false = exited'),
      ],
    ),

    // 20. hr_attendance_punches
    DataDictionaryTable(
      tableName: 'hr_attendance_punches',
      displayName: 'Staff Attendance & Punches',
      domain: 'HR & Payroll',
      icon: Icons.timer_rounded,
      businessUse: 'Daily employee clock-in and clock-out punch logs with geolocation or terminal device ID.',
      defaultQuery: 'SELECT id, employee_id, punch_time, punch_type, status FROM hr_attendance_punches ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Punch log ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'employee_id', type: 'BIGINT', description: 'Staff member pointer', isForeignKey: true),
        DataDictionaryColumn(name: 'punch_time', type: 'TIMESTAMPTZ', description: 'Exact timestamp of punch'),
        DataDictionaryColumn(name: 'punch_type', type: 'VARCHAR(20)', description: 'IN, OUT, BREAK_START, BREAK_END'),
        DataDictionaryColumn(name: 'status', type: 'VARCHAR(30)', description: 'PRESENT, LATE, HALF_DAY'),
      ],
    ),

    // 21. milk_subscriptions
    DataDictionaryTable(
      tableName: 'milk_subscriptions',
      displayName: 'Milk Subscriptions & Deliveries',
      domain: 'Deliveries & Subscriptions',
      icon: Icons.local_drink_rounded,
      businessUse: 'Daily customer milk subscription routines, allocated bottles/litres, and delivery routes.',
      defaultQuery: 'SELECT id, customer_id, item_id, quantity, delivery_time, status FROM milk_subscriptions LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Subscription ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'customer_id', type: 'BIGINT', description: 'Customer pointer', isForeignKey: true),
        DataDictionaryColumn(name: 'item_id', type: 'BIGINT', description: 'Milk product pointer', isForeignKey: true),
        DataDictionaryColumn(name: 'quantity', type: 'NUMERIC(8,2)', description: 'Litres/units delivered per routine'),
        DataDictionaryColumn(name: 'delivery_time', type: 'VARCHAR(20)', description: 'MORNING, EVENING, BOTH'),
        DataDictionaryColumn(name: 'status', type: 'VARCHAR(30)', description: 'ACTIVE, PAUSED, CANCELLED'),
      ],
    ),

    // 22. delivery_agents
    DataDictionaryTable(
      tableName: 'delivery_agents',
      displayName: 'Delivery Agents & Drivers',
      domain: 'Deliveries & Subscriptions',
      icon: Icons.two_wheeler_rounded,
      businessUse: 'Fleet delivery drivers, assigned routes, mobile phone numbers, and active delivery tracking.',
      defaultQuery: 'SELECT id, agent_name, phone, vehicle_number, is_active FROM delivery_agents LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Delivery agent ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'agent_name', type: 'VARCHAR(150)', description: 'Driver / rider name'),
        DataDictionaryColumn(name: 'phone', type: 'VARCHAR(30)', description: 'Mobile phone number'),
        DataDictionaryColumn(name: 'vehicle_number', type: 'VARCHAR(50)', description: 'Motorbike / van registration'),
        DataDictionaryColumn(name: 'is_active', type: 'BOOLEAN', description: 'Active driver status'),
      ],
    ),

    // 23. whatsapp_campaigns
    DataDictionaryTable(
      tableName: 'whatsapp_campaigns',
      displayName: 'WhatsApp Campaigns',
      domain: 'CRM & WhatsApp',
      icon: Icons.campaign_rounded,
      businessUse: 'Marketing broadcasts, promotional message schedules, and recipient target customer groups.',
      defaultQuery: 'SELECT id, campaign_name, template_name, total_recipients, sent_count, status FROM whatsapp_campaigns ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Campaign ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'campaign_name', type: 'VARCHAR(150)', description: 'Broadcast campaign name'),
        DataDictionaryColumn(name: 'template_name', type: 'VARCHAR(100)', description: 'Meta approved WhatsApp template'),
        DataDictionaryColumn(name: 'total_recipients', type: 'INT', description: 'Total phone numbers queued'),
        DataDictionaryColumn(name: 'sent_count', type: 'INT', description: 'Successfully delivered count'),
        DataDictionaryColumn(name: 'status', type: 'VARCHAR(30)', description: 'SCHEDULED, IN_PROGRESS, COMPLETED'),
      ],
    ),

    // 24. system_settings
    DataDictionaryTable(
      tableName: 'system_settings',
      displayName: 'System Settings & Regional Flags',
      domain: 'Store & Infrastructure',
      icon: Icons.settings_rounded,
      businessUse: 'Store-level configuration flags: base currency symbol, rounding, tax mode, printers, and feature toggles.',
      defaultQuery: 'SELECT id, outlet_id, base_currency_symbol, base_currency_code, billing_country, print_mode FROM system_settings LIMIT 5;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'Settings ID', isPrimaryKey: true),
        DataDictionaryColumn(name: 'outlet_id', type: 'INT', description: 'Outlet branch ID', isForeignKey: true),
        DataDictionaryColumn(name: 'base_currency_symbol', type: 'VARCHAR(20)', description: 'Active currency symbol (e.g. \$, ₹, £)'),
        DataDictionaryColumn(name: 'base_currency_code', type: 'VARCHAR(20)', description: 'Currency ISO code (e.g. USD, INR)'),
        DataDictionaryColumn(name: 'billing_country', type: 'VARCHAR(100)', description: 'Tax jurisdiction country'),
        DataDictionaryColumn(name: 'print_mode', type: 'VARCHAR(50)', description: 'DIRECT, PRINT_DIALOG'),
      ],
    ),

    // 25. master_tenants
    DataDictionaryTable(
      tableName: 'master_tenants',
      displayName: 'Master Tenants (SaaS Clients)',
      domain: 'Control Plane & Fleet',
      icon: Icons.business_rounded,
      businessUse: 'Multi-tenant SaaS client business entities, company trade names, tax identifiers, and contact details.',
      defaultQuery: 'SELECT id, client_code, trade_name, contact_email, contact_phone, status FROM master_tenants LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'UUID', description: 'Tenant UUID primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'client_code', type: 'VARCHAR(50)', description: 'Unique merchant code'),
        DataDictionaryColumn(name: 'trade_name', type: 'VARCHAR(200)', description: 'Business trading name'),
        DataDictionaryColumn(name: 'contact_email', type: 'VARCHAR(150)', description: 'Billing contact email'),
        DataDictionaryColumn(name: 'contact_phone', type: 'VARCHAR(50)', description: 'Primary phone number'),
        DataDictionaryColumn(name: 'status', type: 'VARCHAR(30)', description: 'ACTIVE, SUSPENDED, DEACTIVATED'),
      ],
    ),

    // 26. master_licenses
    DataDictionaryTable(
      tableName: 'master_licenses',
      displayName: 'Master SaaS Licenses',
      domain: 'Control Plane & Fleet',
      icon: Icons.verified_user_rounded,
      businessUse: 'SaaS software licenses, expiry valid_till dates, payment statuses, and permitted terminal counts.',
      defaultQuery: 'SELECT id, tenant_id, license_key, tier_name, valid_till, payment_status, status FROM master_licenses ORDER BY id DESC LIMIT 15;',
      columns: [
        DataDictionaryColumn(name: 'id', type: 'BIGSERIAL', description: 'License primary key', isPrimaryKey: true),
        DataDictionaryColumn(name: 'tenant_id', type: 'UUID', description: 'Tenant reference', isForeignKey: true),
        DataDictionaryColumn(name: 'license_key', type: 'VARCHAR(100)', description: 'Encrypted cryptographic license key'),
        DataDictionaryColumn(name: 'tier_name', type: 'VARCHAR(50)', description: 'ENTERPRISE_UNLIMITED, PROFESSIONAL'),
        DataDictionaryColumn(name: 'valid_till', type: 'DATE', description: 'Expiration date of software license'),
        DataDictionaryColumn(name: 'payment_status', type: 'VARCHAR(30)', description: 'PAID, PENDING, OVERDUE'),
        DataDictionaryColumn(name: 'status', type: 'VARCHAR(30)', description: 'ACTIVE, EXPIRED, REVOKED'),
      ],
    ),
  ];

  static void showDictionaryModal(BuildContext context, Function(String sql) onSelectQuery) {
    showDialog(
      context: context,
      builder: (ctx) => _DataDictionaryDialog(onSelectQuery: onSelectQuery),
    );
  }
}

class _DataDictionaryDialog extends StatefulWidget {
  final Function(String sql) onSelectQuery;

  const _DataDictionaryDialog({required this.onSelectQuery});

  @override
  State<_DataDictionaryDialog> createState() => _DataDictionaryDialogState();
}

class _DataDictionaryDialogState extends State<_DataDictionaryDialog> {
  String _search = '';
  String _selectedDomain = 'ALL';
  List<DataDictionaryTable> _tables = SystemDataDictionary.tables;
  List<String> _domains = ['ALL', 'Catalog & Inventory', 'Sales & Billing', 'Purchases & Vendors', 'Finance & Accounts', 'HR & Payroll', 'Deliveries & Subscriptions', 'CRM & WhatsApp', 'F&B & Restaurant', 'Store & Infrastructure', 'Control Plane & Fleet'];
  bool _isLoadingSchema = false;
  int _totalColumns = 0;
  bool _isFromMigrations = false;

  @override
  void initState() {
    super.initState();
    _fetchMigrationSchema();
  }

  Future<void> _fetchMigrationSchema() async {
    setState(() => _isLoadingSchema = true);
    try {
      final res = await ApiClient.get('/api/v1/control-plane/support/data-doctor/schema');
      if (res != null && res['success'] == true && res['data'] != null && mounted) {
        final data = res['data'];
        final rawTables = (data['tables'] as List<dynamic>? ?? []);
        final rawDomains = (data['domains'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        final totalCols = data['totalColumns'] as int? ?? 0;

        final parsedTables = rawTables.map((t) {
          final rawCols = (t['columns'] as List<dynamic>? ?? []);
          final cols = rawCols.map((c) => DataDictionaryColumn(
            name: c['name']?.toString() ?? '',
            type: c['type']?.toString() ?? '',
            description: (c['description']?.toString().isNotEmpty == true)
                ? c['description'].toString()
                : (c['isPrimaryKey'] == true
                    ? 'Primary key identifier'
                    : (c['isForeignKey'] == true
                        ? 'Foreign key reference pointer'
                        : 'Attribute field for ${t['tableName']}')),
            isPrimaryKey: c['isPrimaryKey'] == true,
            isForeignKey: c['isForeignKey'] == true,
          )).toList();

          final domain = t['domain']?.toString() ?? 'General Operations';

          return DataDictionaryTable(
            tableName: t['tableName']?.toString() ?? '',
            displayName: t['displayName']?.toString() ?? t['tableName']?.toString() ?? '',
            domain: domain,
            icon: _resolveDomainIcon(domain),
            businessUse: t['businessUse']?.toString() ?? 'Stores operational records for ${t['tableName']}.',
            defaultQuery: t['defaultQuery']?.toString() ?? 'SELECT * FROM ${t['tableName']} LIMIT 25;',
            columns: cols,
          );
        }).toList();

        if (parsedTables.isNotEmpty) {
          setState(() {
            _tables = parsedTables;
            _domains = rawDomains.isNotEmpty ? rawDomains : ['ALL'];
            _totalColumns = totalCols;
            _isFromMigrations = true;
            _isLoadingSchema = false;
          });
          return;
        }
      }
    } catch (err) {
      debugPrint('Failed to fetch migration schema: $err');
    }
    if (mounted) {
      setState(() => _isLoadingSchema = false);
    }
  }

  IconData _resolveDomainIcon(String domain) {
    final d = domain.toLowerCase();
    if (d.contains('sales') || d.contains('pos')) return Icons.receipt_long_rounded;
    if (d.contains('inventory') || d.contains('item')) return Icons.inventory_2_rounded;
    if (d.contains('purchase') || d.contains('vendor')) return Icons.local_shipping_rounded;
    if (d.contains('finance') || d.contains('account')) return Icons.account_balance_wallet_rounded;
    if (d.contains('restaurant') || d.contains('dining')) return Icons.restaurant_menu_rounded;
    if (d.contains('hr') || d.contains('payroll')) return Icons.badge_rounded;
    if (d.contains('security') || d.contains('access')) return Icons.security_rounded;
    if (d.contains('fleet') || d.contains('control')) return Icons.hub_rounded;
    if (d.contains('sync') || d.contains('cloud')) return Icons.cloud_sync_rounded;
    return Icons.table_chart_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTables = _tables.where((tbl) {
      final matchesDomain = _selectedDomain == 'ALL' || tbl.domain == _selectedDomain;
      final q = _search.toLowerCase();
      final matchesSearch = q.isEmpty ||
          tbl.tableName.toLowerCase().contains(q) ||
          tbl.displayName.toLowerCase().contains(q) ||
          tbl.businessUse.toLowerCase().contains(q) ||
          tbl.columns.any((c) => c.name.toLowerCase().contains(q) || c.description.toLowerCase().contains(q));
      return matchesDomain && matchesSearch;
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF0284C7), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Support Engineer Database Dictionary & Schema Guide',
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            if (_isFromMigrations)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_tables.length} Tables • ${_totalColumns > 0 ? "$_totalColumns Cols • " : ""}Live Migrations',
                                      style: const TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            if (_isLoadingSchema) ...[
                              const SizedBox(width: 8),
                              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Browse complete database table structures, business uses, and column definitions extracted directly from migrations.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Bar & Domain Filters
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search 130+ tables, columns, or business purposes (e.g. invoice, discount, tax, barcode, loyalty)...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0284C7)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      onChanged: (val) => setState(() => _search = val.trim()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _domains.map((domain) {
                    final isSelected = _selectedDomain == domain;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(domain),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0284C7),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (_) => setState(() => _selectedDomain = domain),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Showing ${filteredTables.length} tables matching filter',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFFE2E8F0), height: 1),
              const SizedBox(height: 14),
              // Tables List
              Expanded(
                child: filteredTables.isEmpty
                    ? const Center(
                        child: Text('No tables match your search query.', style: TextStyle(color: Color(0xFF94A3B8))),
                      )
                    : ListView.builder(
                        itemCount: filteredTables.length,
                        itemBuilder: (ctx, i) {
                          final tbl = filteredTables[i];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            color: const Color(0xFFF8FAFC),
                            child: ExpansionTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(tbl.icon, color: const Color(0xFF0284C7), size: 20),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    tbl.tableName,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tbl.domain,
                                      style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${tbl.columns.length} columns',
                                      style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const Spacer(),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      widget.onSelectQuery(tbl.defaultQuery);
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                    label: const Text('Load in Studio', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  tbl.businessUse,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                              ),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'COLUMNS & USAGE DEFINITIONS',
                                        style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.8),
                                      ),
                                      const SizedBox(height: 10),
                                      Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(2.2),
                                          1: FlexColumnWidth(1.8),
                                          2: FlexColumnWidth(5.0),
                                        },
                                        border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                        children: [
                                          const TableRow(
                                            decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                                            children: [
                                              Padding(padding: EdgeInsets.all(8), child: Text('COLUMN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155)))),
                                              Padding(padding: EdgeInsets.all(8), child: Text('DATA TYPE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155)))),
                                              Padding(padding: EdgeInsets.all(8), child: Text('WHAT IT STORES & HOW IT IS USED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155)))),
                                            ],
                                          ),
                                          ...tbl.columns.map((col) {
                                            return TableRow(
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Row(
                                                    children: [
                                                      Text(col.name, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                                      if (col.isPrimaryKey) ...[
                                                        const SizedBox(width: 4),
                                                        const Tooltip(message: 'Primary Key', child: Icon(Icons.vpn_key_rounded, size: 12, color: Color(0xFFF59E0B))),
                                                      ],
                                                      if (col.isForeignKey) ...[
                                                        const SizedBox(width: 4),
                                                        const Tooltip(message: 'Foreign Key / Reference', child: Icon(Icons.link_rounded, size: 13, color: Color(0xFF0284C7))),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Text(col.type, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF0284C7))),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(8),
                                                  child: Text(col.description, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                                ),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ],
                                  ),
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
