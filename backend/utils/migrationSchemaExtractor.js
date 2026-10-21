"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.extractSchemaFromMigrations = extractSchemaFromMigrations;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));

const TABLE_BUSINESS_USES = {
    item_master: {
        displayName: 'Item Master (Product Catalog)',
        domain: 'Inventory & Items',
        businessUse: 'Central product catalog. Stores item codes, barcodes, HSN/SAC codes, cost rates, retail sale prices, tax slabs, and current inventory levels.',
    },
    sales_headers: {
        displayName: 'Sales Headers (Invoices & Bills)',
        domain: 'Sales & POS',
        businessUse: 'Master invoice records. Stores invoice number, transaction date, customer details, gross amount, taxes, discounts, net payable, and payment status.',
    },
    sales_items: {
        displayName: 'Sales Items (Invoice Line Items)',
        domain: 'Sales & POS',
        businessUse: 'Line-item level details for invoices. Stores product ID, quantity billed, unit rate, discounts applied, and tax calculations per line.',
    },
    stock_ledger: {
        displayName: 'Stock Ledger (Inventory Transactions)',
        domain: 'Inventory & Items',
        businessUse: 'Double-entry physical inventory ledger recording every stock movement (Purchases IN, Sales OUT, Returns, Damages, Adjustments).',
    },
    users: {
        displayName: 'Users & Cashiers',
        domain: 'Security & Access',
        businessUse: 'Operator accounts, POS cashiers, managers, assigned outlets, encrypted credentials, and maximum allowed discount limits.',
    },
    outlets: {
        displayName: 'Outlets & Stores',
        domain: 'Control Plane & Fleet',
        businessUse: 'Multi-store retail/restaurant outlets, store codes, GSTIN numbers, recovery credentials, and active statuses.',
    },
    customers: {
        displayName: 'Customer Master',
        domain: 'Sales & POS',
        businessUse: 'Customer profiles, mobile phone lookups, loyalty point balances, and credit/debit ledger balances.',
    },
    cash_ledger: {
        displayName: 'Cash Drawer Ledger',
        domain: 'Finance & Accounts',
        businessUse: 'Cash drawer floating balance, cash-in/cash-out tracking, cash drop to safe, and end-of-shift reconciliation.',
    },
    kot_headers: {
        displayName: 'KOT Headers (Kitchen Orders)',
        domain: 'Restaurant & Dining',
        businessUse: 'Kitchen Order Tickets for restaurants, dine-in table numbers, steward name, and KOT dispatch status.',
    },
    kot_items: {
        displayName: 'KOT Line Items',
        domain: 'Restaurant & Dining',
        businessUse: 'Individual food dishes sent to kitchen stations, cooking notes, modifiers, and preparation status.',
    },
    taxes_master: {
        displayName: 'Tax Slabs Master',
        domain: 'Finance & Accounts',
        businessUse: 'GST/VAT tax slabs, CGST/SGST/IGST split rates, cess rates, and tax category mapping.',
    },
    supplier_master: {
        displayName: 'Supplier Master (Vendors)',
        domain: 'Purchases & Vendors',
        businessUse: 'Vendor profiles, addresses, GSTIN numbers, contact details, payment terms, and opening debit/credit balances.',
    },
    supplier_bills: {
        displayName: 'Purchase Bills',
        domain: 'Purchases & Vendors',
        businessUse: 'Purchase bills and vendor invoices entered against Goods Received Notes (GRN), invoice dates, and payable amounts.',
    },
    supplier_payments: {
        displayName: 'Vendor Payments',
        domain: 'Purchases & Vendors',
        businessUse: 'Payment disbursements made to vendors against purchase bills, cheque/NEFT references, and bank accounts.',
    },
    stock_locations: {
        displayName: 'Stock Locations & Bins',
        domain: 'Inventory & Items',
        businessUse: 'Physical godowns, store racks, warehouse bins, and outlet-specific storage areas.',
    },
    batches: {
        displayName: 'Product Batches & Expiry',
        domain: 'Inventory & Items',
        businessUse: 'Batch-tracked inventory for pharmaceuticals and perishable food items, storing manufacturing dates and expiry dates.',
    },
    barcodes: {
        displayName: 'Multi-Barcodes Mapping',
        domain: 'Inventory & Items',
        businessUse: 'Multiple barcodes mapped to a single item (e.g. manufacturer EAN, inner pack UPC, case barcodes).',
    },
    pos_sessions: {
        displayName: 'POS Cashier Sessions',
        domain: 'Sales & POS',
        businessUse: 'Cash register opening/closing shifts, float cash, drawer balance, cashier ID, and shift totals.',
    },
    customer_groups: {
        displayName: 'Customer Groups & Tiers',
        domain: 'Sales & POS',
        businessUse: 'Customer segmentation tiers (e.g. Retail, Wholesale, VIP, Staff) with default discount margins.',
    },
    hr_employees: {
        displayName: 'Employees & Staff',
        domain: 'HR & Payroll',
        businessUse: 'Human resource employee master records, designation, department, contact information, and base salary.',
    },
    expenses: {
        displayName: 'Expense Vouchers',
        domain: 'Finance & Accounts',
        businessUse: 'Store operating expense vouchers (e.g. rent, utilities, tea, packaging, maintenance) and cash outflow records.',
    },
    bank_accounts: {
        displayName: 'Bank Accounts',
        domain: 'Finance & Accounts',
        businessUse: 'Company bank accounts, UPI IDs, cheque clearing accounts, and reconciled book balances.',
    },
    day_book: {
        displayName: 'Day Book Ledger',
        domain: 'Finance & Accounts',
        businessUse: 'Daily chronological accounting entries showing debits and credits across all heads of accounts.',
    },
    chart_of_accounts: {
        displayName: 'Chart of Accounts',
        domain: 'Finance & Accounts',
        businessUse: 'General ledger chart of accounts defining Assets, Liabilities, Incomes, and Expenses.',
    },
    sync_queue: {
        displayName: 'Sync Queue (Replication)',
        domain: 'Cloud & Sync',
        businessUse: 'Offline-to-online transaction synchronization queue for multi-outlet distributed replication.',
    },
    audit_logs: {
        displayName: 'System Audit Logs',
        domain: 'Security & Access',
        businessUse: 'Security audit trail capturing user actions, voids, price overrides, cancellations, and administrative events.',
    },
};

const DOMAIN_KEYWORDS = {
    sales: 'Sales & POS',
    invoice: 'Sales & POS',
    pos: 'Sales & POS',
    customer: 'Sales & POS',
    discount: 'Sales & POS',
    scheme: 'Sales & POS',
    coupon: 'Sales & POS',
    voucher: 'Sales & POS',
    loyalty: 'Sales & POS',
    quotation: 'Sales & POS',
    order: 'Sales & POS',
    item: 'Inventory & Items',
    stock: 'Inventory & Items',
    product: 'Inventory & Items',
    batch: 'Inventory & Items',
    barcode: 'Inventory & Items',
    unit: 'Inventory & Items',
    brand: 'Inventory & Items',
    category: 'Inventory & Items',
    supplier: 'Purchases & Vendors',
    purchase: 'Purchases & Vendors',
    grn: 'Purchases & Vendors',
    vendor: 'Purchases & Vendors',
    cash: 'Finance & Accounts',
    bank: 'Finance & Accounts',
    expense: 'Finance & Accounts',
    account: 'Finance & Accounts',
    ledger: 'Finance & Accounts',
    tax: 'Finance & Accounts',
    payment: 'Finance & Accounts',
    gst: 'Finance & Accounts',
    kot: 'Restaurant & Dining',
    kitchen: 'Restaurant & Dining',
    table: 'Restaurant & Dining',
    dining: 'Restaurant & Dining',
    menu: 'Restaurant & Dining',
    recipe: 'Restaurant & Dining',
    captain: 'Restaurant & Dining',
    employee: 'HR & Payroll',
    hr: 'HR & Payroll',
    payroll: 'HR & Payroll',
    attendance: 'HR & Payroll',
    shift: 'HR & Payroll',
    salary: 'HR & Payroll',
    commission: 'HR & Payroll',
    sync: 'Cloud & Sync',
    offline: 'Cloud & Sync',
    cloud: 'Cloud & Sync',
    tenant: 'Control Plane & Fleet',
    outlet: 'Control Plane & Fleet',
    user: 'Security & Access',
    role: 'Security & Access',
    permission: 'Security & Access',
    audit: 'Security & Access',
    setting: 'System & Config',
};

function formatDisplayName(tableName) {
    return tableName
        .split('_')
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');
}

function resolveDomain(tableName) {
    const lower = tableName.toLowerCase();
    for (const [kw, domain] of Object.entries(DOMAIN_KEYWORDS)) {
        if (lower.includes(kw))
            return domain;
    }
    return 'General Operations';
}

function generateBusinessUse(tableName, domain) {
    const formatted = formatDisplayName(tableName);
    return `Stores operational data for ${formatted}. Used across the ${domain} module for transaction recording, state tracking, and auditing.`;
}

// In-memory cache for parsed schema
let cachedSchema = null;

function extractSchemaFromMigrations() {
    if (cachedSchema) {
        return cachedSchema;
    }
    // Look for migrations.js or migrations.ts in utils directory
    const possiblePaths = [
        path_1.default.join(__dirname, 'migrations.js'),
        path_1.default.join(__dirname, 'migrations.ts'),
        path_1.default.join(__dirname, '../utils/migrations.js'),
        path_1.default.join(__dirname, '../utils/migrations.ts'),
        path_1.default.join(process.cwd(), 'backend/utils/migrations.js'),
        path_1.default.join(process.cwd(), 'backend/utils/migrations.ts'),
    ];
    let migrationContent = '';
    for (const p of possiblePaths) {
        if (fs_1.default.existsSync(p)) {
            try {
                migrationContent = fs_1.default.readFileSync(p, 'utf8');
                if (migrationContent.length > 1000)
                    break;
            }
            catch (_) { }
        }
    }
    if (!migrationContent) {
        throw new Error('Migration definitions file could not be read.');
    }
    const tablesMap = {};
    // 1. Parse CREATE TABLE statements
    const createRegex = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)\s*\(([\s\S]*?)\);/gi;
    let match;
    while ((match = createRegex.exec(migrationContent)) !== null) {
        const tableName = match[1].toLowerCase();
        const body = match[2];
        if (!tablesMap[tableName]) {
            tablesMap[tableName] = {
                tableName,
                columns: [],
            };
        }
        const lines = body.split('\n');
        for (let rawLine of lines) {
            const line = rawLine.trim();
            if (!line || line.startsWith('--') || line.startsWith('/*'))
                continue;
            if (/^(CONSTRAINT|PRIMARY\s+KEY|FOREIGN\s+KEY|UNIQUE|CHECK)\b/i.test(line))
                continue;
            const colMatch = line.match(/^([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+(?:\([0-9,\s]+\))?)(.*)/);
            if (colMatch) {
                const colName = colMatch[1];
                const colType = colMatch[2];
                const rest = colMatch[3] || '';
                let comment = '';
                const commentMatch = rest.match(/--\s*(.*)$/);
                if (commentMatch)
                    comment = commentMatch[1].trim();
                const isPk = /PRIMARY\s+KEY/i.test(rest) || (colName === 'id' && /SERIAL/i.test(colType));
                const notNull = /NOT\s+NULL/i.test(rest);
                const isFk = /REFERENCES|_id\b/i.test(colName) || /REFERENCES/i.test(rest);
                if (!tablesMap[tableName].columns.find((c) => c.name.toLowerCase() === colName.toLowerCase())) {
                    tablesMap[tableName].columns.push({
                        name: colName,
                        type: colType.toUpperCase(),
                        isPrimaryKey: isPk,
                        isForeignKey: isFk,
                        isNullable: !notNull,
                        description: comment || '',
                    });
                }
            }
        }
    }
    // 2. Parse ALTER TABLE ADD COLUMN statements
    const alterRegex = /ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?([a-zA-Z0-9_]+)\s+ADD\s+COLUMN\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z0-9_]+)\s+([a-zA-Z0-9_]+(?:\([0-9,\s]+\))?)([^;]*);/gi;
    while ((match = alterRegex.exec(migrationContent)) !== null) {
        const tableName = match[1].toLowerCase();
        const colName = match[2];
        const colType = match[3];
        const rest = match[4] || '';
        let comment = '';
        const commentMatch = rest.match(/--\s*(.*)$/);
        if (commentMatch)
            comment = commentMatch[1].trim();
        if (tablesMap[tableName]) {
            if (!tablesMap[tableName].columns.find((c) => c.name.toLowerCase() === colName.toLowerCase())) {
                const notNull = /NOT\s+NULL/i.test(rest);
                const isFk = /REFERENCES|_id\b/i.test(colName) || /REFERENCES/i.test(rest);
                tablesMap[tableName].columns.push({
                    name: colName,
                    type: colType.toUpperCase(),
                    isPrimaryKey: false,
                    isForeignKey: isFk,
                    isNullable: !notNull,
                    description: comment || '',
                });
            }
        }
    }
    const tableList = [];
    const domainSet = new Set();
    let totalColumns = 0;
    for (const rawTable of Object.values(tablesMap)) {
        const tName = rawTable.tableName;
        const curated = TABLE_BUSINESS_USES[tName];
        const displayName = curated ? curated.displayName : formatDisplayName(tName);
        const domain = curated ? curated.domain : resolveDomain(tName);
        const businessUse = curated ? curated.businessUse : generateBusinessUse(tName, domain);
        const hasOutletId = rawTable.columns.some((c) => c.name.toLowerCase() === 'outlet_id');
        const defaultQuery = hasOutletId
            ? `SELECT * FROM ${tName} WHERE outlet_id = 1 ORDER BY 1 DESC LIMIT 25;`
            : `SELECT * FROM ${tName} ORDER BY 1 DESC LIMIT 25;`;
        domainSet.add(domain);
        totalColumns += rawTable.columns.length;
        tableList.push({
            tableName: tName,
            displayName,
            domain,
            businessUse,
            defaultQuery,
            columnCount: rawTable.columns.length,
            columns: rawTable.columns,
        });
    }
    // Sort tables alphabetically
    tableList.sort((a, b) => a.tableName.localeCompare(b.tableName));
    cachedSchema = {
        totalTables: tableList.length,
        totalColumns,
        domains: ['ALL', ...Array.from(domainSet).sort()],
        tables: tableList,
    };
    return cachedSchema;
}

exports.default = {
    extractSchemaFromMigrations,
};
