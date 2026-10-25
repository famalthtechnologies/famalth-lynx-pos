"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// Patch TextDecoder to support 'ascii' encoding under packaged Node environments (like pkg target node18)
try {
    new TextDecoder('ascii');
}
catch (e) {
    const OriginalTextDecoder = globalThis.TextDecoder || (typeof global !== 'undefined' ? global.TextDecoder : null);
    if (OriginalTextDecoder) {
        const PatchedTextDecoder = class TextDecoder extends OriginalTextDecoder {
            constructor(encoding, options) {
                if (typeof encoding === 'string' && (encoding.toLowerCase() === 'ascii' || encoding.toLowerCase() === 'us-ascii')) {
                    super('utf-8', options);
                }
                else {
                    super(encoding, options);
                }
            }
        };
        if (typeof globalThis !== 'undefined') {
            globalThis.TextDecoder = PatchedTextDecoder;
        }
        if (typeof global !== 'undefined') {
            global.TextDecoder = PatchedTextDecoder;
        }
        try {
            const util = require('util');
            if (util && util.TextDecoder) {
                util.TextDecoder = PatchedTextDecoder;
            }
        }
        catch (utilErr) {
            // Ignore if util cannot be loaded or patched
        }
    }
}
// Global safety handlers to ensure background workers / crons never crash the process
process.on('uncaughtException', (err) => {
    console.error('⚠️ [PROCESS] Uncaught Exception caught safely:', err?.message || err);
});
process.on('unhandledRejection', (reason) => {
    console.error('⚠️ [PROCESS] Unhandled Rejection caught safely:', reason?.message || reason);
});
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const dotenv_1 = __importDefault(require("dotenv"));
const rateLimit_middleware_1 = require("./middlewares/rateLimit.middleware");
const context_middleware_1 = require("./middlewares/context.middleware");
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
dotenv_1.default.config({
    path: path_1.default.join(rootDir, '.env')
});
const security_middleware_1 = require("./middlewares/security.middleware");
const requestId_middleware_1 = require("./middlewares/requestId.middleware");
const app = (0, express_1.default)();
app.set('trust proxy', 1);
app.use(security_middleware_1.securityHeadersMiddleware);
app.use(rateLimit_middleware_1.ddosBurstLimiter);
app.use(requestId_middleware_1.requestIdMiddleware);
app.use(context_middleware_1.contextMiddleware);
app.use((req, res, next) => {
    res.setHeader('X-Powered-By', 'Famalth Business Solutions - FAMALTH LYNX');
    res.setHeader('X-Platform-Vendor', 'Famalth Ecosystem');
    const reqId = req.id || '-';
    console.log(`[REQUEST] [${reqId}] ${req.method} ${req.originalUrl || req.url}`);
    next();
});
const decryptConfig_1 = __importDefault(require("./utils/decryptConfig"));
require("pg");
const waitForPostgres_1 = __importDefault(require("./utils/waitForPostgres"));
const sequelize_1 = require("sequelize");
const propertyDb = require('./db/models');
const backupJob_1 = require("./jobs/backupJob");
const loyaltyExpiryJob_1 = require("./jobs/loyaltyExpiryJob");
const analyticsRefreshJob_1 = require("./jobs/analyticsRefreshJob");
const subscriptionDeliveryJob_1 = require("./jobs/subscriptionDeliveryJob");
const luckyDrawJob_1 = require("./jobs/luckyDrawJob");
const db_middleware_1 = __importDefault(require("./middlewares/db.middleware"));
const ensureDatabase_1 = __importDefault(require("./utils/ensureDatabase"));
const migrationRunner_1 = __importDefault(require("./utils/migrationRunner"));
const backupTracker_1 = require("./utils/backupTracker");
const timezone_middleware_1 = __importDefault(require("./middlewares/timezone.middleware"));
const whatsappQueueJob_1 = require("./jobs/whatsappQueueJob");
const recurringExpensesJob_1 = require("./jobs/recurringExpensesJob");
const nightAuditJob_1 = require("./jobs/nightAuditJob");
const notesReminderJob_1 = require("./jobs/notesReminderJob");
const licenseExpiryNotificationJob_1 = require("./jobs/licenseExpiryNotificationJob");
const masterSync_1 = require("./utils/masterSync");
const socketHub_service_1 = require("./services/socketHub.service");
const CLIENT_FILE = path_1.default.join(rootDir, "client.json");
// body limits
app.use(express_1.default.json({
    limit: '100mb',
    verify: (req, res, buf) => {
        req.rawBody = buf;
    }
}));
app.use(express_1.default.urlencoded({ extended: true, limit: '100mb' }));
app.use((0, cors_1.default)({
    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin)
            return callback(null, true);
        callback(null, true);
    },
    credentials: true
}));
app.use('/uploads', express_1.default.static(path_1.default.join(rootDir, 'uploads')));
// health
app.get('/health', async (req, res) => {
    try {
        const licensePath = path_1.default.join(rootDir, 'license.key');
        if (!fs_1.default.existsSync(licensePath)) {
            return res.json({ success: false, action: 'LICENSE_ERROR', message: "License key is missing." });
        }
        try {
            const license = JSON.parse(fs_1.default.readFileSync(licensePath, 'utf8'));
            if (new Date() > new Date(license.valid_till)) {
                return res.json({ success: false, action: 'LICENSE_ERROR', message: "License has expired." });
            }
        }
        catch (e) {
            return res.json({ success: false, action: 'LICENSE_ERROR', message: "License file is corrupted." });
        }
        if (!process.env.DATABASE_URL && !process.env.DB_HOST) {
            const configPath = path_1.default.join(rootDir, 'config.enc');
            const sysConfigPath = path_1.default.join(rootDir, 'sysConfig.enc');
            if (!fs_1.default.existsSync(configPath)) {
                return res.json({ success: false, action: 'RECOVER_CONFIG', message: "Configuration missing." });
            }
            try {
                const config = (0, decryptConfig_1.default)();
                const testDb = new sequelize_1.Sequelize(config.db_database, config.db_user, config.db_password, {
                    host: config.db_host || "127.0.0.1",
                    port: Number(config.db_port || 5432),
                    dialect: "postgres",
                    logging: false
                });
                await testDb.authenticate();
                await testDb.close();
            }
            catch (dbError) {
                console.log(dbError);
                return res.json({ success: false, action: 'FULL_RECOVERY', message: "Database connection failed." });
            }
            if (!fs_1.default.existsSync(sysConfigPath)) {
                return res.json({ success: false, action: 'AUTO_REINSTALL', message: "System files missing." });
            }
        }
        else {
            try {
                await propertyDb.authenticate();
            }
            catch (dbError) {
                return res.json({ success: false, action: 'FULL_RECOVERY', message: "Cloud database connection failed." });
            }
        }
        res.json({ success: true, action: 'OK', status: 'RUNNING', time: new Date() });
    }
    catch (error) {
        res.status(500).json({ success: false, action: 'ERROR', message: "Fatal health check error." });
    }
});
app.use(db_middleware_1.default);
app.use(timezone_middleware_1.default);
app.use('/api', rateLimit_middleware_1.apiLimiter);
const licensePath = path_1.default.join(rootDir, 'license.key');
let license = { allowed_mode: 'OFFLINE' };
if (!fs_1.default.existsSync(licensePath)) {
    console.error('⚠️ [SYSTEM] LICENSE FILE MISSING. Booting in limited Recovery Mode.');
}
else {
    try {
        const parsedLicense = JSON.parse(fs_1.default.readFileSync(licensePath, 'utf8'));
        if (new Date() > new Date(parsedLicense.valid_till)) {
            console.error('⚠️ [SYSTEM] LICENSE EXPIRED. Booting in limited Recovery Mode.');
        }
        else {
            license = parsedLicense;
        }
    }
    catch (e) {
        console.error('⚠️ [SYSTEM] INVALID LICENSE FILE FORMAT. Booting in limited Recovery Mode.');
    }
}
(async () => {
    try {
        const configPath = path_1.default.join(rootDir, 'config.enc');
        if (!process.env.DATABASE_URL && !process.env.DB_HOST && !fs_1.default.existsSync(configPath)) {
            console.log('⚠️ [SYSTEM] config.enc is missing and cloud DB not set. Skipping database boot.');
            console.log('🛡️ [SYSTEM] Server entering Recovery Mode.');
            return;
        }
        const config = (0, decryptConfig_1.default)();
        if (!process.env.DATABASE_URL) {
            await (0, waitForPostgres_1.default)();
            await (0, ensureDatabase_1.default)();
        }
        await propertyDb.authenticate();
        console.log('✅ Database connected successfully');
        // Dynamically add merchant_upi_id and subscription delivery charge columns if missing to prevent DB query crashes
        try {
            await propertyDb.query(`
                ALTER TABLE system_settings 
                ADD COLUMN IF NOT EXISTS time_zone VARCHAR(100) DEFAULT 'Asia/Kolkata',
                ADD COLUMN IF NOT EXISTS merchant_upi_id VARCHAR(255) DEFAULT '',
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_enabled BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_name VARCHAR(255) DEFAULT 'Subscription Delivery',
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_amount NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_type VARCHAR(50) DEFAULT 'FLAT',
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_gst_percent NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS sub_delivery_free_above NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS enable_salesperson_tagging BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS bill_copies_count INTEGER DEFAULT 1,
                ADD COLUMN IF NOT EXISTS show_brand_name BOOLEAN DEFAULT TRUE,
                ADD COLUMN IF NOT EXISTS enable_token_system BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS token_copies_count INTEGER DEFAULT 1,
                ADD COLUMN IF NOT EXISTS device_printer_mappings JSONB DEFAULT '{}',
                ADD COLUMN IF NOT EXISTS base_currency_code VARCHAR(20) DEFAULT 'USD',
                ADD COLUMN IF NOT EXISTS base_currency_symbol VARCHAR(20) DEFAULT '$',
                ADD COLUMN IF NOT EXISTS currency_symbol_position VARCHAR(20) DEFAULT 'BEFORE',
                ADD COLUMN IF NOT EXISTS currency_decimals INTEGER DEFAULT 2,
                ADD COLUMN IF NOT EXISTS receipt_template_config JSONB DEFAULT '{}',
                ADD COLUMN IF NOT EXISTS a4_template_config JSONB DEFAULT '{}',
                ADD COLUMN IF NOT EXISTS a5_template_config JSONB DEFAULT '{}',
                ADD COLUMN IF NOT EXISTS kot_template_config JSONB DEFAULT '{}',
                ADD COLUMN IF NOT EXISTS token_template_config JSONB DEFAULT '{}',
                ADD COLUMN IF NOT EXISTS restaurant_settlement_mode VARCHAR(30) DEFAULT 'DIRECT',
                ADD COLUMN IF NOT EXISTS enable_clinic_module BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS allow_public_appointments BOOLEAN DEFAULT TRUE,
                ADD COLUMN IF NOT EXISTS allow_public_table_booking BOOLEAN DEFAULT TRUE,
                ADD COLUMN IF NOT EXISTS usb_mobile_push_enabled BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS custom_settings JSONB DEFAULT '{}';
            `);
            console.log('✅ Verified/added currency, payment_modes, template configs, merchant_upi_id and subscription delivery charge columns in system_settings table');
        }
        catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table system_settings:', colErr.message);
        }
        try {
            await propertyDb.query(`
                ALTER TABLE milk_subscriptions 
                ADD COLUMN IF NOT EXISTS delivery_charge_amount NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS delivery_charge_gst_percent NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS delivery_charge_tax_amount NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS subscription_type VARCHAR(40) DEFAULT 'DAILY_QTY',
                ADD COLUMN IF NOT EXISTS total_allowed_services INTEGER DEFAULT 0,
                ADD COLUMN IF NOT EXISTS services_consumed INTEGER DEFAULT 0,
                ADD COLUMN IF NOT EXISTS service_unit_name VARCHAR(50) DEFAULT 'Services',
                ADD COLUMN IF NOT EXISTS per_service_price NUMERIC(12,2) DEFAULT 0.0;
            `);
            console.log('✅ Verified/added delivery charge and service quota columns in milk_subscriptions table');
        }
        catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table milk_subscriptions:', colErr.message);
        }
        try {
            await propertyDb.query(`
                ALTER TABLE delivery_customers 
                ADD COLUMN IF NOT EXISTS email VARCHAR(255) DEFAULT '',
                ADD COLUMN IF NOT EXISTS otp_code VARCHAR(10) DEFAULT '',
                ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMP DEFAULT NULL;
            `);
            console.log('✅ Verified/added email and otp columns in delivery_customers table');
        }
        catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table delivery_customers:', colErr.message);
        }
        try {
            await propertyDb.query(`
                ALTER TABLE property_info 
                ADD COLUMN IF NOT EXISTS terms_and_conditions TEXT DEFAULT '',
                ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150) DEFAULT '',
                ADD COLUMN IF NOT EXISTS bank_acc_no VARCHAR(50) DEFAULT '',
                ADD COLUMN IF NOT EXISTS bank_ifsc VARCHAR(30) DEFAULT '',
                ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100) DEFAULT '',
                ADD COLUMN IF NOT EXISTS upi_payee_name VARCHAR(150) DEFAULT '',
                ADD COLUMN IF NOT EXISTS print_bank_details BOOLEAN DEFAULT false,
                ADD COLUMN IF NOT EXISTS print_upi_qr BOOLEAN DEFAULT false,
                ADD COLUMN IF NOT EXISTS print_digital_signature BOOLEAN DEFAULT false;

                ALTER TABLE restaurant_tables 
                ADD COLUMN IF NOT EXISTS assigned_user_id INTEGER,
                ADD COLUMN IF NOT EXISTS assigned_user_name VARCHAR(150),
                ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

                ALTER TABLE kot_headers
                ADD COLUMN IF NOT EXISTS client_tag VARCHAR(100) DEFAULT 'Bill 1',
                ADD COLUMN IF NOT EXISTS sub_table VARCHAR(50);

                ALTER TABLE sales_headers
                ADD COLUMN IF NOT EXISTS table_id INTEGER,
                ADD COLUMN IF NOT EXISTS client_tag VARCHAR(100),
                ADD COLUMN IF NOT EXISTS sub_table VARCHAR(50);

                ALTER TABLE item_master
                ADD COLUMN IF NOT EXISTS is_modifier BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS applicable_item_ids TEXT,
                ADD COLUMN IF NOT EXISTS deduct_raw_item_id INTEGER,
                ADD COLUMN IF NOT EXISTS deduct_qty DECIMAL(12, 4) DEFAULT 0,
                ADD COLUMN IF NOT EXISTS food_type VARCHAR(20) DEFAULT 'VEG',
                ADD COLUMN IF NOT EXISTS dietary_type VARCHAR(20) DEFAULT 'VEG',
                ADD COLUMN IF NOT EXISTS is_veg BOOLEAN DEFAULT TRUE;

                ALTER TABLE users
                ADD COLUMN IF NOT EXISTS login_qr_token VARCHAR(255),
                ADD COLUMN IF NOT EXISTS speciality VARCHAR(100),
                ADD COLUMN IF NOT EXISTS qualification VARCHAR(100),
                ADD COLUMN IF NOT EXISTS experience_years INTEGER DEFAULT 0,
                ADD COLUMN IF NOT EXISTS consultation_fee NUMERIC(10,2) DEFAULT 0.00,
                ADD COLUMN IF NOT EXISTS is_public_listed BOOLEAN DEFAULT TRUE,
                ADD COLUMN IF NOT EXISTS is_verified_badge BOOLEAN DEFAULT TRUE,
                ADD COLUMN IF NOT EXISTS doctor_city VARCHAR(100),
                ADD COLUMN IF NOT EXISTS doctor_bio TEXT,
                ADD COLUMN IF NOT EXISTS available_days VARCHAR(100) DEFAULT 'Mon,Tue,Wed,Thu,Fri,Sat';

                ALTER TABLE customers
                ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP;

                CREATE TABLE IF NOT EXISTS clinic_appointments (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    patient_id INTEGER,
                    patient_name VARCHAR(150) NOT NULL,
                    patient_phone VARCHAR(20) NOT NULL,
                    patient_email VARCHAR(150),
                    patient_age INTEGER,
                    patient_gender VARCHAR(20),
                    appointment_date DATE NOT NULL,
                    appointment_time VARCHAR(20) NOT NULL,
                    doctor_name VARCHAR(150),
                    doctor_id INTEGER,
                    consultation_fee NUMERIC(10,2) DEFAULT 0.00,
                    is_email_verified BOOLEAN DEFAULT FALSE,
                    email_otp_verified_at TIMESTAMP,
                    department VARCHAR(100),
                    reason_for_visit TEXT,
                    status VARCHAR(30) DEFAULT 'SCHEDULED',
                    visited_at TIMESTAMP,
                    prescription_notes TEXT,
                    prescribed_medicines JSONB DEFAULT '[]',
                    billing_sale_id INTEGER,
                    billing_status VARCHAR(30) DEFAULT 'PENDING',
                    source VARCHAR(30) DEFAULT 'POS',
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS hr_biometric_devices (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    device_name VARCHAR(150) NOT NULL,
                    ip_address VARCHAR(100) NOT NULL,
                    port INTEGER DEFAULT 4370,
                    machine_id VARCHAR(100) DEFAULT '1',
                    protocol VARCHAR(50) DEFAULT 'STANDALONE_TCP',
                    push_api_key VARCHAR(255),
                    is_active BOOLEAN DEFAULT TRUE,
                    last_sync_at TIMESTAMP WITH TIME ZONE,
                    last_ping_status VARCHAR(50) DEFAULT 'OFFLINE',
                    total_punches_synced INTEGER DEFAULT 0,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                );

                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_hrms_module BOOLEAN DEFAULT FALSE;
                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_retail_billing BOOLEAN DEFAULT TRUE;
                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_restaurant_module BOOLEAN DEFAULT TRUE;
                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_inventory_module BOOLEAN DEFAULT TRUE;
                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_clinic_module BOOLEAN DEFAULT FALSE;
                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS allow_public_appointments BOOLEAN DEFAULT TRUE;
                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS allow_public_table_booking BOOLEAN DEFAULT TRUE;
                ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS usb_mobile_push_enabled BOOLEAN DEFAULT FALSE;

                ALTER TABLE goods_receipts ADD COLUMN IF NOT EXISTS round_off_amount NUMERIC(12, 2) DEFAULT 0.00;
                ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS round_off_amount NUMERIC(12, 2) DEFAULT 0.00;
                ALTER TABLE supplier_payments ADD COLUMN IF NOT EXISTS round_off NUMERIC(12, 2) DEFAULT 0.00;
                ALTER TABLE supplier_bills ADD COLUMN IF NOT EXISTS round_off_amount NUMERIC(12, 2) DEFAULT 0.00;

                ALTER TABLE table_reservations ADD COLUMN IF NOT EXISTS customer_email VARCHAR(150);
                ALTER TABLE table_reservations ADD COLUMN IF NOT EXISTS reservation_date DATE;
                ALTER TABLE table_reservations ADD COLUMN IF NOT EXISTS source VARCHAR(30) DEFAULT 'IN_HOUSE';

                ALTER TABLE milk_subscription_consumptions ADD COLUMN IF NOT EXISTS consumption_type VARCHAR(40) DEFAULT 'DAILY_QTY';
                ALTER TABLE milk_subscription_consumptions ADD COLUMN IF NOT EXISTS is_paid_visit BOOLEAN DEFAULT FALSE;

                ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS remarks TEXT;
                ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS biometric_device_id INTEGER;

                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS payment_status VARCHAR(30) DEFAULT 'UNPAID';
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS payment_mode VARCHAR(50);
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(10, 2) DEFAULT 0.00;
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS package_name VARCHAR(150);
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS session_number INTEGER DEFAULT 0;
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS total_package_sessions INTEGER DEFAULT 0;
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS is_package_session BOOLEAN DEFAULT FALSE;
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS token_number INTEGER DEFAULT 1;

                ALTER TABLE users ADD COLUMN IF NOT EXISTS registration_no VARCHAR(100);
                ALTER TABLE users ADD COLUMN IF NOT EXISTS whatsapp_no VARCHAR(50);
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS billing_sale_id INTEGER;
                ALTER TABLE clinic_appointments ADD COLUMN IF NOT EXISTS billing_sale_no VARCHAR(50);
                ALTER TABLE users ADD COLUMN IF NOT EXISTS public_display_options JSONB DEFAULT '{"show_clinic_name":true,"show_doctor_name":true,"show_address":true,"show_phone":true,"show_whatsapp":true,"show_email":true,"show_fees":true}'::jsonb;
            `);
            console.log('✅ Verified/added custom columns in property_info, restaurant_tables, kot_headers, sales_headers, item_master, clinic_appointments, and hr_biometric_devices');
        }
        catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table property_info/restaurant_tables/item_master:', colErr.message);
        }
        try {
            await propertyDb.query(`
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
                    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
                ALTER TABLE user_notes
                ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS is_trashed BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
            `);
            // Auto purge notes in trash older than 30 days
            await propertyDb.query(`
                DELETE FROM user_notes 
                WHERE is_trashed = true 
                  AND deleted_at IS NOT NULL 
                  AND deleted_at < NOW() - INTERVAL '30 days';
            `);
            console.log('✅ Verified user_notes table columns and purged notes in Trash older than 30 days');
        }
        catch (noteErr) {
            console.warn('⚠️ Failed to verify user_notes table:', noteErr.message);
        }
        try {
            await propertyDb.query(`
                ALTER TABLE recurring_expenses
                ADD COLUMN IF NOT EXISTS remind_days_before INTEGER DEFAULT 7;
            `);
            console.log('✅ Verified/added remind_days_before column in recurring_expenses table');
        }
        catch (recErr) {
            console.warn('⚠️ Failed to dynamically alter table recurring_expenses:', recErr.message);
        }
        try {
            await propertyDb.query(`
                CREATE TABLE IF NOT EXISTS bank_accounts (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    bank_name VARCHAR(150) NOT NULL,
                    account_name VARCHAR(150) NOT NULL,
                    account_number VARCHAR(50) NOT NULL,
                    ifsc_code VARCHAR(20),
                    branch_name VARCHAR(100),
                    account_type VARCHAR(30) DEFAULT 'CURRENT',
                    opening_balance NUMERIC(12,2) DEFAULT 0.00,
                    current_balance NUMERIC(12,2) DEFAULT 0.00,
                    is_active BOOLEAN DEFAULT TRUE,
                    is_primary BOOLEAN DEFAULT FALSE,
                    created_by INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                ALTER TABLE bank_accounts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT FALSE;
                CREATE TABLE IF NOT EXISTS chart_of_accounts (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    account_code VARCHAR(30),
                    account_name VARCHAR(150) NOT NULL,
                    group_name VARCHAR(100) NOT NULL,
                    nature VARCHAR(30) NOT NULL,
                    opening_debit NUMERIC(12,2) DEFAULT 0.00,
                    opening_credit NUMERIC(12,2) DEFAULT 0.00,
                    current_balance NUMERIC(12,2) DEFAULT 0.00,
                    is_system BOOLEAN DEFAULT FALSE,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
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
                    total_debit NUMERIC(12,2) DEFAULT 0.00,
                    total_credit NUMERIC(12,2) DEFAULT 0.00,
                    status VARCHAR(20) DEFAULT 'POSTED',
                    created_by INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS voucher_lines (
                    id SERIAL PRIMARY KEY,
                    voucher_id INTEGER NOT NULL,
                    line_type VARCHAR(20) NOT NULL,
                    account_id INTEGER,
                    account_name VARCHAR(150) NOT NULL,
                    account_type VARCHAR(50) DEFAULT 'GENERAL',
                    debit_amount NUMERIC(12,2) DEFAULT 0.00,
                    credit_amount NUMERIC(12,2) DEFAULT 0.00,
                    particulars VARCHAR(255)
                );
                CREATE TABLE IF NOT EXISTS business_loans (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    loan_name VARCHAR(150) NOT NULL,
                    lender_name VARCHAR(150),
                    principal_amount NUMERIC(12,2) DEFAULT 0.00,
                    interest_rate NUMERIC(5,2) DEFAULT 0.00,
                    tenure_months INTEGER DEFAULT 12,
                    monthly_emi NUMERIC(12,2) DEFAULT 0.00,
                    remaining_principal NUMERIC(12,2) DEFAULT 0.00,
                    status VARCHAR(30) DEFAULT 'ACTIVE',
                    notes TEXT,
                    created_by INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS capital_assets (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    asset_name VARCHAR(150) NOT NULL,
                    asset_category VARCHAR(50) DEFAULT 'FIXED_ASSET',
                    purchase_date DATE DEFAULT CURRENT_DATE,
                    purchase_cost NUMERIC(12,2) DEFAULT 0.00,
                    current_value NUMERIC(12,2) DEFAULT 0.00,
                    notes TEXT,
                    created_by INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            `);
            console.log('✅ Verified/created accounting database tables (bank_accounts, chart_of_accounts, accounting_vouchers, voucher_lines)');
        }
        catch (accErr) {
            console.warn('⚠️ Failed to verify accounting tables:', accErr.message);
        }
        await (0, migrationRunner_1.default)(propertyDb);
        console.log('✅ Database migrations complete');
        // Note: Model sync disabled to prevent duplicate PostgreSQL constraint index generation. Database migrations manage table schema.
        // await propertyDb.sync({ alter: false });
        initializeAllBackups();
        (0, loyaltyExpiryJob_1.startLoyaltyExpiryJob)(propertyDb);
        (0, analyticsRefreshJob_1.startAnalyticsRefreshJob)(propertyDb);
        (0, subscriptionDeliveryJob_1.startSubscriptionDeliveryJob)(propertyDb);
        (0, luckyDrawJob_1.startLuckyDrawJob)(propertyDb);
        // Start background WhatsApp message queue worker
        (0, whatsappQueueJob_1.startWhatsappQueueJob)(propertyDb);
        // Start background recurring expenses worker
        (0, recurringExpensesJob_1.startRecurringExpensesJob)(propertyDb);
        // Start background Night Audit worker
        (0, nightAuditJob_1.startNightAuditJob)(propertyDb);
        // Start background Notes Reminder worker
        (0, notesReminderJob_1.startNotesReminderJob)(propertyDb);
        // Start background License Expiry & 10-Day Renewal Invoice notification dispatcher
        (0, licenseExpiryNotificationJob_1.startLicenseExpiryNotificationJob)(propertyDb);
        // Auto-sync client properties to Master Control Plane
        await (0, masterSync_1.syncClientsJsonToMaster)(propertyDb);
    }
    catch (err) {
        console.error('❌ Database connection failed', err);
        process.exit(1);
    }
})();
// routes
// No-auth: Flutter uses this at startup to anchor its internal clock against DB time
app.use('/api/system/server-time', require('./routes/systemTime.routes'));
const rawSystemRoutes = require('./routes/system.routes');
app.use('/api/system', rawSystemRoutes.default || rawSystemRoutes);
// Global Maintenance Mode Guard: Pauses all store terminals during server maintenance
const rawMaintenance = require('./middlewares/maintenance.middleware');
const maintenanceGuard = rawMaintenance.default || rawMaintenance.maintenanceMiddleware || rawMaintenance;
app.use(maintenanceGuard);
app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/public', require('./routes/public.routes'));
app.use('/api/v1/public', require('./routes/public.routes'));
app.use('/api/inventory', require('./routes/inventory.routes'));
app.use('/api/purchase-orders', require('./routes/purchase.routes'));
app.use('/api/inventory/purchase-orders', require('./routes/purchase.routes'));
app.use('/api/receiving', require('./routes/receiving.routes'));
app.use('/api/suppliers', require('./routes/supplier.routes'));
app.use('/api/sales', require('./routes/sales.routes'));
app.use('/api/lucky-draw', require('./routes/luckyDraw.routes'));
app.use('/api/analytics', require('./routes/analytics.routes'));
app.use('/api/users', require('./routes/user.routes'));
app.use('/api/reports', rateLimit_middleware_1.reportQueryLimiter, require('./routes/reports.routes'));
app.use('/api/finance', require('./routes/finance.routes'));
app.use('/api/accounting', require('./routes/accounting.routes'));
app.use('/api/notifications', require('./routes/notification.routes'));
app.use('/api/delivery', require('./routes/delivery.routes'));
app.use('/api/audit', require('./routes/audit.routes'));
app.use('/api/night-audit', require('./routes/nightAudit.routes'));
app.use('/webhooks/whatsapp', require('./routes/whatsappWebhook.routes'));
app.use('/api/whatsapp', require('./routes/whatsapp.routes'));
app.use('/api/hrms', require('./routes/hrms.routes'));
app.use('/api/restaurant', require('./routes/restaurant.routes'));
app.use('/api/settings/smtp', require('./routes/restaurant.routes'));
app.use('/api/settings/tax-groups', require('./routes/taxGroup.routes'));
app.use('/api/inventory/tax-groups', require('./routes/taxGroup.routes'));
app.use('/api/v1/ai', require('./routes/ai_assist.routes'));
app.use('/api/v1/intelligence', require('./routes/intelligence.routes'));
app.use('/api/v1/operations', require('./routes/operations.routes'));
app.use('/api/v1/workflows', require('./routes/workflow.routes'));
app.use('/api/v1/agent', require('./routes/autonomous_agent.routes'));
app.use('/api/v1/developer', require('./routes/developer.routes'));
app.use('/api/v1/plugins', require('./routes/plugin.routes'));
app.use('/api/v1/open', require('./routes/open_api.routes'));
app.use('/api/notes', require('./routes/userNote.routes'));
app.use('/api/community', require('./routes/community.routes'));
app.use('/api/payments/mpesa', require('./routes/mpesa.routes'));
app.use('/api/payments/gateways', require('./routes/paymentGateways.routes'));
app.use('/api/marketplace', require('./routes/marketplace.routes'));
app.use('/api/v1/control-plane', require('./routes/control_plane.routes'));
app.use('/api/clinic', require('./routes/clinic.routes'));
app.use('/api/backup', require('./routes/backup.routes'));
// Google-style Unsubscribe Landing Route
const { renderUnsubscribePage } = require('./controllers/public/unsubscribe.controller');
app.get(['/unsubscribe', '/api/v1/unsubscribe', '/api/unsubscribe'], renderUnsubscribePage);
// Web SPA static file serving (Only active if public/ directory exists)
const webBuildPath = path_1.default.join(rootDir, 'public');
if (fs_1.default.existsSync(webBuildPath)) {
    app.use(express_1.default.static(webBuildPath));
    app.use((req, res, next) => {
        if (req.method === 'GET' && !req.path.startsWith('/api') && !req.path.startsWith('/health') && !req.path.startsWith('/uploads') && !req.path.startsWith('/webhooks')) {
            return res.sendFile(path_1.default.join(webBuildPath, 'index.html'));
        }
        next();
    });
}
// not found
app.use((req, res) => {
    res.status(404).json({ success: false, message: 'API not found' });
});
// error
app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
});
// server
const PORT = process.env.PORT || 3000;
const HOST = license.allowed_mode === 'ONLINE' ? '0.0.0.0' : '0.0.0.0';
const server = app.listen(PORT, HOST, () => {
    console.log(`INV API running on http://${HOST}:${PORT}`);
});
// Initialize Real-time Socket.io Hub for Support Console & Fleet Remote Control
const io = (0, socketHub_service_1.initSocketHub)(server);
// Anti-DDoS Slowloris Socket Protection
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000;
server.requestTimeout = 30000;
// Production Graceful Shutdown Handlers (Zero downtime deployment / PM2 / Docker)
function gracefulShutdown(signal) {
    console.log(`\n🛑 [SYSTEM] Received ${signal}. Starting graceful shutdown...`);
    server.close(async () => {
        console.log('🔒 [SYSTEM] HTTP server stopped accepting connections.');
        try {
            if (propertyDb && typeof propertyDb.close === 'function') {
                await propertyDb.close();
                console.log('💾 [SYSTEM] PostgreSQL database connection closed cleanly.');
            }
        }
        catch (dbCloseErr) {
            console.error('⚠️ [SYSTEM] Error closing database connection:', dbCloseErr.message);
        }
        process.exit(0);
    });
    // Force exit after 10 seconds if shutdown hangs
    setTimeout(() => {
        console.error('⚠️ [SYSTEM] Forced shutdown due to timeout.');
        process.exit(1);
    }, 10000).unref();
}
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
function initializeAllBackups() {
    console.log("🔄 Initializing background backups for all registered outlets...");
    if (!fs_1.default.existsSync(CLIENT_FILE)) {
        console.log("⚠️ Client file not found. Bypassing backup initialization.");
        return;
    }
    const config = (0, decryptConfig_1.default)();
    try {
        const fileData = fs_1.default.readFileSync(CLIENT_FILE, "utf8");
        let clients = JSON.parse(fileData);
        if (!Array.isArray(clients)) {
            clients = [clients];
        }
        if (clients.length === 0) {
            console.log("⚠️ No outlets found in client file. Bypassing backups.");
            return;
        }
        clients.forEach((client) => {
            if (client && client.outlet_code) {
                const status = (0, backupTracker_1.getBackupStatus)(client.outlet_code);
                console.log(`▶️ Scheduling backups for outlet: [${client.outlet_code}] | Cloud Sync: ${status.isCloudEnabled ? 'ON' : 'OFF'}`);
                (0, backupJob_1.startBackupJob)(client, config);
            }
        });
    }
    catch (error) {
        console.error(`❌ Failed to initialize backups: ${error.message}`);
    }
}
exports.default = app;
