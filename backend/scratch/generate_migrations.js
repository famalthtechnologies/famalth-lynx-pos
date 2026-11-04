"use strict";
const fs = require('fs');
const path = require('path');
const migration120SQL = `
        -- =========================================================================
        -- MIGRATION 120: CREATE ALL MISSING APPLICATION TABLES
        -- =========================================================================

        -- 1. master_announcements
        CREATE TABLE IF NOT EXISTS master_announcements (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            target_tenant_id UUID REFERENCES master_tenants(id) ON DELETE CASCADE,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            action_link VARCHAR(500),
            action_label VARCHAR(100) DEFAULT 'Learn More',
            badge_text VARCHAR(50) DEFAULT 'Special Offer',
            discount_code VARCHAR(50),
            is_active BOOLEAN DEFAULT TRUE,
            expires_at TIMESTAMP WITH TIME ZONE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 2. master_invoices
        CREATE TABLE IF NOT EXISTS master_invoices (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            tenant_id UUID REFERENCES master_tenants(id) ON DELETE CASCADE,
            invoice_number VARCHAR(100) UNIQUE NOT NULL,
            billing_period_start DATE NOT NULL,
            billing_period_end DATE NOT NULL,
            due_date DATE NOT NULL,
            subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            tax_rate NUMERIC(5, 2) DEFAULT 18.00,
            tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            status VARCHAR(50) DEFAULT 'ISSUED',
            pdf_data TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            paid_at TIMESTAMP WITH TIME ZONE
        );

        -- 3. app_branding
        CREATE TABLE IF NOT EXISTS app_branding (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER UNIQUE NOT NULL,
            company_name VARCHAR(255) NOT NULL DEFAULT 'Famalth Technologies',
            product_name VARCHAR(255) NOT NULL DEFAULT 'Famalth Inventory',
            support_email VARCHAR(255) NOT NULL DEFAULT 'help@famalth.com',
            support_website VARCHAR(255) NOT NULL DEFAULT 'www.famalth.com',
            support_phone VARCHAR(80) NOT NULL DEFAULT '+91-00000-00000',
            open_source_notice TEXT NOT NULL DEFAULT 'Famalth Technologies branding is applied across the product. Third-party packages remain available under their respective open-source licenses.',
            powered_by_label VARCHAR(255) NOT NULL DEFAULT 'Powered by Famalth Technologies',
            theme_key VARCHAR(80) NOT NULL DEFAULT 'famalth_classic',
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 4. bank_accounts
        CREATE TABLE IF NOT EXISTS bank_accounts (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            bank_name VARCHAR(150) NOT NULL,
            account_name VARCHAR(150) NOT NULL,
            account_number VARCHAR(50) NOT NULL,
            ifsc_code VARCHAR(20),
            branch_name VARCHAR(100),
            account_type VARCHAR(30) DEFAULT 'CURRENT',
            opening_balance NUMERIC(12, 2) DEFAULT 0.00,
            current_balance NUMERIC(12, 2) DEFAULT 0.00,
            is_active BOOLEAN DEFAULT TRUE,
            is_primary BOOLEAN DEFAULT FALSE,
            created_by INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- 5. chart_of_accounts
        CREATE TABLE IF NOT EXISTS chart_of_accounts (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            account_code VARCHAR(30),
            account_name VARCHAR(150) NOT NULL,
            group_name VARCHAR(100) NOT NULL,
            nature VARCHAR(30) NOT NULL,
            opening_debit NUMERIC(12, 2) DEFAULT 0.00,
            opening_credit NUMERIC(12, 2) DEFAULT 0.00,
            current_balance NUMERIC(12, 2) DEFAULT 0.00,
            is_system BOOLEAN DEFAULT FALSE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- 6. accounting_vouchers
        CREATE TABLE IF NOT EXISTS accounting_vouchers (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            voucher_no VARCHAR(50) NOT NULL,
            voucher_type VARCHAR(30) NOT NULL,
            voucher_date DATE NOT NULL,
            payment_mode VARCHAR(30) DEFAULT 'CASH',
            bank_account_id INTEGER,
            reference_no VARCHAR(100),
            narration TEXT,
            total_debit NUMERIC(12, 2) DEFAULT 0.00,
            total_credit NUMERIC(12, 2) DEFAULT 0.00,
            status VARCHAR(20) DEFAULT 'POSTED',
            created_by INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- 7. voucher_lines
        CREATE TABLE IF NOT EXISTS voucher_lines (
            id SERIAL PRIMARY KEY,
            voucher_id INTEGER NOT NULL,
            line_type VARCHAR(20) NOT NULL,
            account_id INTEGER,
            account_name VARCHAR(150) NOT NULL,
            account_type VARCHAR(50) DEFAULT 'GENERAL',
            debit_amount NUMERIC(12, 2) DEFAULT 0.00,
            credit_amount NUMERIC(12, 2) DEFAULT 0.00,
            particulars VARCHAR(255)
        );

        -- 8. business_loans
        CREATE TABLE IF NOT EXISTS business_loans (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            loan_name VARCHAR(150) NOT NULL,
            lender_name VARCHAR(150),
            principal_amount NUMERIC(12, 2) DEFAULT 0.00,
            interest_rate NUMERIC(5, 2) DEFAULT 0.00,
            tenure_months INTEGER DEFAULT 12,
            monthly_emi NUMERIC(12, 2) DEFAULT 0.00,
            remaining_principal NUMERIC(12, 2) DEFAULT 0.00,
            status VARCHAR(30) DEFAULT 'ACTIVE',
            notes TEXT,
            created_by INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- 9. capital_assets
        CREATE TABLE IF NOT EXISTS capital_assets (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            asset_name VARCHAR(150) NOT NULL,
            asset_category VARCHAR(50) DEFAULT 'FIXED_ASSET',
            purchase_date DATE DEFAULT CURRENT_DATE,
            purchase_cost NUMERIC(12, 2) DEFAULT 0.00,
            current_value NUMERIC(12, 2) DEFAULT 0.00,
            notes TEXT,
            created_by INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        -- 10. user_notes
        CREATE TABLE IF NOT EXISTS user_notes (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL DEFAULT 0,
            user_id INTEGER DEFAULT 1,
            title VARCHAR(255) NOT NULL,
            content TEXT DEFAULT '',
            color_hex VARCHAR(20) DEFAULT '#FEF08A',
            is_pinned BOOLEAN DEFAULT FALSE,
            is_completed BOOLEAN DEFAULT FALSE,
            is_archived BOOLEAN DEFAULT FALSE,
            is_trashed BOOLEAN DEFAULT FALSE,
            deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
            reminder_type VARCHAR(50) DEFAULT 'NONE',
            reminder_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
            reminder_time VARCHAR(30) DEFAULT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 11. business_day_status
        CREATE TABLE IF NOT EXISTS business_day_status (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            business_date DATE NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
            opened_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            closed_at TIMESTAMP WITH TIME ZONE,
            opened_by INTEGER,
            closed_by INTEGER,
            notes TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 12. night_audit_runs
        CREATE TABLE IF NOT EXISTS night_audit_runs (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            audit_date DATE NOT NULL,
            run_type VARCHAR(20) NOT NULL DEFAULT 'MANUAL',
            status VARCHAR(30) NOT NULL DEFAULT 'IN_PROGRESS',
            gross_sales NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            total_discounts NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            total_taxes NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            net_sales NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            cash_expected NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            cash_physical NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            cash_variance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            denominations JSONB DEFAULT '{}'::jsonb,
            open_kot_count INTEGER NOT NULL DEFAULT 0,
            unclosed_shift_count INTEGER NOT NULL DEFAULT 0,
            execution_log JSONB DEFAULT '[]'::jsonb,
            z_report_url VARCHAR(500),
            started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            completed_at TIMESTAMP WITH TIME ZONE,
            performed_by INTEGER,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 13. night_audit_details
        CREATE TABLE IF NOT EXISTS night_audit_details (
            id SERIAL PRIMARY KEY,
            audit_run_id INTEGER NOT NULL,
            outlet_id INTEGER NOT NULL,
            section_type VARCHAR(50) NOT NULL,
            detail_key VARCHAR(100) NOT NULL,
            detail_value JSONB NOT NULL DEFAULT '{}'::jsonb,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 14. sales_refunds
        CREATE TABLE IF NOT EXISTS sales_refunds (
            id SERIAL PRIMARY KEY,
            outlet_id INTEGER NOT NULL,
            sale_id INTEGER NOT NULL,
            refund_no VARCHAR(50) NOT NULL,
            refund_date DATE NOT NULL,
            amount_pending NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            amount_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            payment_mode VARCHAR(20),
            reference_no VARCHAR(100),
            status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
            notes TEXT,
            created_by INTEGER,
            updated_by INTEGER,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 15. stock_transfer_headers
        CREATE TABLE IF NOT EXISTS stock_transfer_headers (
            id SERIAL PRIMARY KEY,
            transfer_no VARCHAR(50) UNIQUE NOT NULL,
            source_outlet_id INTEGER NOT NULL,
            destination_outlet_id INTEGER NOT NULL,
            status VARCHAR(30) NOT NULL DEFAULT 'DISPATCHED',
            dispatch_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            received_date TIMESTAMP WITH TIME ZONE,
            total_qty NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            dispatched_by_user_id INTEGER,
            received_by_user_id INTEGER,
            notes TEXT,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 16. stock_transfer_items
        CREATE TABLE IF NOT EXISTS stock_transfer_items (
            id SERIAL PRIMARY KEY,
            transfer_id INTEGER NOT NULL,
            item_id INTEGER,
            item_code VARCHAR(50) NOT NULL,
            item_name VARCHAR(200),
            transfer_qty NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            unit_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            total_cost NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 17. tax_profiles
        CREATE TABLE IF NOT EXISTS tax_profiles (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            outlet_id INTEGER NOT NULL,
            country_code VARCHAR(10) NOT NULL DEFAULT 'US',
            tax_regime VARCHAR(50) NOT NULL DEFAULT 'SALES_TAX',
            default_is_inclusive BOOLEAN DEFAULT FALSE,
            tax_id_label VARCHAR(50) DEFAULT 'Tax ID',
            tax_registration_no VARCHAR(100),
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 18. tax_groups
        CREATE TABLE IF NOT EXISTS tax_groups (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            outlet_id INTEGER NOT NULL,
            tax_profile_id UUID REFERENCES tax_profiles(id) ON DELETE SET NULL,
            group_name VARCHAR(150) NOT NULL,
            group_code VARCHAR(50),
            total_rate NUMERIC(7, 4) NOT NULL DEFAULT 0.0000,
            is_tax_inclusive BOOLEAN DEFAULT FALSE,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );

        -- 19. tax_group_components
        CREATE TABLE IF NOT EXISTS tax_group_components (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            tax_group_id UUID NOT NULL REFERENCES tax_groups(id) ON DELETE CASCADE,
            component_code VARCHAR(50) NOT NULL,
            component_name VARCHAR(100) NOT NULL,
            rate NUMERIC(7, 4) NOT NULL DEFAULT 0.0000,
            calculation_order INTEGER DEFAULT 1,
            calculation_type VARCHAR(30) DEFAULT 'FLAT_PERCENT',
            gl_account_code VARCHAR(50),
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
`;
const migration121SQL = `
        -- =========================================================================
        -- MIGRATION 121: ADD ALL MISSING ENTERPRISE COLUMNS ACROSS TABLES
        -- =========================================================================

        -- master_licenses
        ALTER TABLE master_licenses ADD COLUMN IF NOT EXISTS grace_period_days INTEGER DEFAULT 0;
        ALTER TABLE master_licenses ADD COLUMN IF NOT EXISTS subscription_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE master_licenses ADD COLUMN IF NOT EXISTS tax_percentage NUMERIC(5, 2) DEFAULT 18.00;
        ALTER TABLE master_licenses ADD COLUMN IF NOT EXISTS next_payment_date DATE;
        ALTER TABLE master_licenses ADD COLUMN IF NOT EXISTS payment_status VARCHAR(30) DEFAULT 'ACTIVE';
        ALTER TABLE master_licenses ADD COLUMN IF NOT EXISTS last_payment_date DATE;

        -- master_resellers
        ALTER TABLE master_resellers ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

        -- customers
        ALTER TABLE customers ADD COLUMN IF NOT EXISTS customer_email VARCHAR(255);

        -- damage_headers
        ALTER TABLE damage_headers ADD COLUMN IF NOT EXISTS approved_by INTEGER;
        ALTER TABLE damage_headers ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;
        ALTER TABLE damage_headers ADD COLUMN IF NOT EXISTS rejected_by INTEGER;
        ALTER TABLE damage_headers ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP WITH TIME ZONE;
        ALTER TABLE damage_headers ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

        -- request_headers
        ALTER TABLE request_headers ADD COLUMN IF NOT EXISTS approved_by INTEGER;
        ALTER TABLE request_headers ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;
        ALTER TABLE request_headers ADD COLUMN IF NOT EXISTS rejected_by INTEGER;
        ALTER TABLE request_headers ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP WITH TIME ZONE;
        ALTER TABLE request_headers ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

        -- delivery_customers
        ALTER TABLE delivery_customers ADD COLUMN IF NOT EXISTS email VARCHAR(255) DEFAULT '';
        ALTER TABLE delivery_customers ADD COLUMN IF NOT EXISTS otp_code VARCHAR(10) DEFAULT '';
        ALTER TABLE delivery_customers ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMP WITH TIME ZONE;

        -- email_configurations
        ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS provider_type VARCHAR(50) DEFAULT 'SMTP';
        ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS gmail_client_id VARCHAR(255);
        ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS gmail_client_secret VARCHAR(255);
        ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS gmail_refresh_token TEXT;
        ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS resend_api_key VARCHAR(255);

        -- goods_receipt_items
        ALTER TABLE goods_receipt_items ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE goods_receipt_items ADD COLUMN IF NOT EXISTS total_after_tax NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE goods_receipt_items ADD COLUMN IF NOT EXISTS department VARCHAR(100);
        ALTER TABLE goods_receipt_items ADD COLUMN IF NOT EXISTS sale_rate NUMERIC(12, 2) DEFAULT 0.00;

        -- purchase_order_items
        ALTER TABLE purchase_order_items ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE purchase_order_items ADD COLUMN IF NOT EXISTS total_after_tax NUMERIC(12, 2) DEFAULT 0.00;

        -- hr_attendance_punches
        ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS leave_type_id INTEGER;

        -- item_master
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS retail_sale_price NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(5, 2) DEFAULT 0.00;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS tax_group_id UUID;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS discount_applicable BOOLEAN DEFAULT TRUE;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS scheme_applicable BOOLEAN DEFAULT TRUE;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_recipe_based BOOLEAN DEFAULT FALSE;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_tax_inclusive BOOLEAN DEFAULT FALSE;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS applicable_item_ids TEXT;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS deduct_raw_item_id INTEGER;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS deduct_qty NUMERIC(12, 4) DEFAULT 0.0000;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS dietary_type VARCHAR(20) DEFAULT 'VEG';
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_veg BOOLEAN DEFAULT TRUE;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_modifier BOOLEAN DEFAULT FALSE;
        ALTER TABLE item_master ADD COLUMN IF NOT EXISTS food_type VARCHAR(20) DEFAULT 'VEG';

        -- item_modifiers
        ALTER TABLE item_modifiers ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(5, 2) DEFAULT 0.00;
        ALTER TABLE item_modifiers ADD COLUMN IF NOT EXISTS inventory_item_id INTEGER;
        ALTER TABLE item_modifiers ADD COLUMN IF NOT EXISTS deduct_qty NUMERIC(12, 4) DEFAULT 0.0000;

        -- kot_headers
        ALTER TABLE kot_headers ADD COLUMN IF NOT EXISTS client_tag VARCHAR(100) DEFAULT 'Bill 1';
        ALTER TABLE kot_headers ADD COLUMN IF NOT EXISTS sub_table VARCHAR(50);

        -- milk_subscriptions
        ALTER TABLE milk_subscriptions ADD COLUMN IF NOT EXISTS delivery_charge_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE milk_subscriptions ADD COLUMN IF NOT EXISTS delivery_charge_gst_percent NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE milk_subscriptions ADD COLUMN IF NOT EXISTS delivery_charge_tax_amount NUMERIC(12, 2) DEFAULT 0.00;

        -- outlets
        ALTER TABLE outlets ADD COLUMN IF NOT EXISTS supervisor_pin VARCHAR(100);
        ALTER TABLE outlets ADD COLUMN IF NOT EXISTS supervisor_pin_type VARCHAR(30) DEFAULT 'STATIC';
        ALTER TABLE outlets ADD COLUMN IF NOT EXISTS parent_outlet_id INTEGER;
        ALTER TABLE outlets ADD COLUMN IF NOT EXISTS is_master BOOLEAN DEFAULT FALSE;
        ALTER TABLE outlets ADD COLUMN IF NOT EXISTS outlet_role VARCHAR(30) DEFAULT 'STORE';

        -- property_info
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS print_mobile VARCHAR(50) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS print_email VARCHAR(100) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS print_website VARCHAR(150) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS thermal_footer_note TEXT DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS terms_and_conditions TEXT DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS bank_acc_no VARCHAR(50) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS bank_ifsc VARCHAR(30) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS upi_payee_name VARCHAR(150) DEFAULT '';
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS print_bank_details BOOLEAN DEFAULT FALSE;
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS print_upi_qr BOOLEAN DEFAULT FALSE;
        ALTER TABLE property_info ADD COLUMN IF NOT EXISTS print_digital_signature BOOLEAN DEFAULT FALSE;

        -- recurring_expenses
        ALTER TABLE recurring_expenses ADD COLUMN IF NOT EXISTS remind_days_before INTEGER DEFAULT 7;

        -- restaurant_tables
        ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS assigned_user_id INTEGER;
        ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS assigned_user_name VARCHAR(150);
        ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS x_coordinate NUMERIC(10, 2) DEFAULT 0.00;
        ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS y_coordinate NUMERIC(10, 2) DEFAULT 0.00;

        -- sales_headers
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS table_id INTEGER;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS change_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS balance_due NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS order_type VARCHAR(50) DEFAULT 'DINE_IN';
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS billing_tax_mode VARCHAR(30) DEFAULT 'EXCLUSIVE';
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS bill_format VARCHAR(30) DEFAULT 'STANDARD';
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(5, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS taxable_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS cgst_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS sgst_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS igst_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS total_tax NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS tax_breakup JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS charges JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS charge_total NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS charge_tax_total NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS coupon_discount_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS voucher_label VARCHAR(100);
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS previous_sale_id INTEGER;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS replaced_by_sale_id INTEGER;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS version_no INTEGER DEFAULT 1;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS is_latest BOOLEAN DEFAULT TRUE;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS modified_by INTEGER;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS modified_at TIMESTAMP WITH TIME ZONE;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS modification_note TEXT;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS commission_fixed_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS token_no VARCHAR(50);
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS client_tag VARCHAR(100);
        ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS sub_table VARCHAR(50);

        -- sales_items
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS tax_percent NUMERIC(5, 2) DEFAULT 0.00;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS discount_applicable BOOLEAN DEFAULT TRUE;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS scheme_applicable BOOLEAN DEFAULT TRUE;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS taxable_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS tax_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS line_total NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS tax_breakup JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS modifier_objects JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS notes TEXT;

        -- sales_schemes
        ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS item_id INTEGER;
        ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS free_qty NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS cycle_days INTEGER DEFAULT 0;
        ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS require_no_gaps BOOLEAN DEFAULT FALSE;

        -- supplier_master
        ALTER TABLE supplier_master ADD COLUMN IF NOT EXISTS email VARCHAR(150);
        ALTER TABLE supplier_master ADD COLUMN IF NOT EXISTS gstin VARCHAR(50);
        ALTER TABLE supplier_master ADD COLUMN IF NOT EXISTS opening_balance NUMERIC(12, 2) DEFAULT 0.00;

        -- system_settings
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS default_printer_name VARCHAR(150);
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS default_printer_url VARCHAR(255);
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS billing_tax_mode VARCHAR(30) DEFAULT 'EXCLUSIVE';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS bill_format VARCHAR(30) DEFAULT 'STANDARD';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS default_charges JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS merchant_upi_id VARCHAR(255) DEFAULT '';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS sub_delivery_charge_enabled BOOLEAN DEFAULT FALSE;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS sub_delivery_charge_name VARCHAR(255) DEFAULT 'Subscription Delivery';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS sub_delivery_charge_amount NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS sub_delivery_charge_type VARCHAR(50) DEFAULT 'FLAT';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS sub_delivery_charge_gst_percent NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS sub_delivery_free_above NUMERIC(12, 2) DEFAULT 0.00;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS bill_copies_count INTEGER DEFAULT 1;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_token_system BOOLEAN DEFAULT FALSE;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS token_copies_count INTEGER DEFAULT 1;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS device_printer_mappings JSONB DEFAULT '{}'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS base_currency_code VARCHAR(20) DEFAULT 'KES';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS base_currency_symbol VARCHAR(20) DEFAULT 'KSh';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS currency_symbol_position VARCHAR(20) DEFAULT 'BEFORE';
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS currency_decimals INTEGER DEFAULT 2;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS payment_modes JSONB DEFAULT '[]'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS receipt_template_config JSONB DEFAULT '{}'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS a4_template_config JSONB DEFAULT '{}'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS a5_template_config JSONB DEFAULT '{}'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS kot_template_config JSONB DEFAULT '{}'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS token_template_config JSONB DEFAULT '{}'::jsonb;
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS restaurant_settlement_mode VARCHAR(30) DEFAULT 'DIRECT';

        -- users
        ALTER TABLE users ADD COLUMN IF NOT EXISTS show_in_quick_login BOOLEAN DEFAULT FALSE;
`;
const migrationCodeTS = `  {
    version: 120,
    description: "Create all missing core application tables (accounting, master control plane, night audit, transfers, branding, notes, refunds, and multi-regime tax engines)",
    up: async (db: any) => {
      await db.query(\`${migration120SQL}      \`);
    }
  },
  {
    version: 121,
    description: "Comprehensive ALTER TABLE upgrade adding all missing enterprise columns, indexes, and constraints across existing tables",
    up: async (db: any) => {
      await db.query(\`${migration121SQL}      \`);
    }
  }
];

export default migrations;`;
const migrationCodeJS = `  {
    version: 120,
    description: "Create all missing core application tables (accounting, master control plane, night audit, transfers, branding, notes, refunds, and multi-regime tax engines)",
    up: async (db) => {
      await db.query(\`${migration120SQL}      \`);
    }
  },
  {
    version: 121,
    description: "Comprehensive ALTER TABLE upgrade adding all missing enterprise columns, indexes, and constraints across existing tables",
    up: async (db) => {
      await db.query(\`${migration121SQL}      \`);
    }
  }
];

module.exports = migrations;`;
// 1. Update backend/utils/migrations.ts
const tsPath = path.join(__dirname, '../utils/migrations.ts');
let tsContent = fs.readFileSync(tsPath, 'utf8');
const tsTarget = '];\n\nexport default migrations;';
const tsTargetCRLF = '];\r\n\r\nexport default migrations;';
if (tsContent.includes(tsTarget)) {
    tsContent = tsContent.replace(tsTarget, ',\n' + migrationCodeTS);
}
else if (tsContent.includes(tsTargetCRLF)) {
    tsContent = tsContent.replace(tsTargetCRLF, ',\r\n' + migrationCodeTS);
}
else {
    console.error('Could not find tsTarget in migrations.ts');
}
fs.writeFileSync(tsPath, tsContent, 'utf8');
console.log('✅ Updated backend/utils/migrations.ts with Version 120 and 121');
// 2. Update backend/utils/migrations.js
const jsPath = path.join(__dirname, '../utils/migrations.js');
let jsContent = fs.readFileSync(jsPath, 'utf8');
const jsTarget = '];\n\nmodule.exports = migrations;';
const jsTargetCRLF = '];\r\n\r\nmodule.exports = migrations;';
if (jsContent.includes(jsTarget)) {
    jsContent = jsContent.replace(jsTarget, ',\n' + migrationCodeJS);
}
else if (jsContent.includes(jsTargetCRLF)) {
    jsContent = jsContent.replace(jsTargetCRLF, ',\r\n' + migrationCodeJS);
}
else {
    console.error('Could not find jsTarget in migrations.js');
}
fs.writeFileSync(jsPath, jsContent, 'utf8');
console.log('✅ Updated backend/utils/migrations.js with Version 120 and 121');
