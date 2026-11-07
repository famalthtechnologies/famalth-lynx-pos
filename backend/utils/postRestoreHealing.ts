import runMigrations from './migrationRunner';
import { toggleCloudBackup } from './backupTracker';

/**
 * Ensures complete database schema healing and migration after any backup restore,
 * preventing 'table not found' or 'column not found' errors from legacy or partial backups.
 * Also ensures cloud backup is turned OFF by default for data safety upon restore.
 * @param db Active Sequelize instance or database model
 */
export async function runPostRestoreHealing(db: any): Promise<void> {
  const activeDb = db?.sequelize || db;
  console.log('🔄 Running post-restore schema healing, table synchronization & migrations...');

  try {
    // 1. Ensure all Sequelize models are synced without dropping anything
    if (typeof activeDb.sync === 'function') {
      await activeDb.sync().catch((err: any) => {
        if (!err.message?.includes('foreign key constraint')) {
          console.warn('⚠️ Model sync notice during post-restore healing:', err.message);
        }
      });
    }

    // 2. Add any missing columns to existing tables
    await activeDb.query(`
      ALTER TABLE outlets ADD COLUMN IF NOT EXISTS business_module VARCHAR(50) DEFAULT 'ALL';
      ALTER TABLE outlets ADD COLUMN IF NOT EXISTS supervisor_pin VARCHAR(100) DEFAULT '1234';
      ALTER TABLE outlets ADD COLUMN IF NOT EXISTS supervisor_pin_type VARCHAR(50) DEFAULT 'STATIC';
      ALTER TABLE users ADD COLUMN IF NOT EXISTS pin_code VARCHAR(100) DEFAULT NULL;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS show_in_quick_login BOOLEAN DEFAULT FALSE;
      ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS salesman_id INTEGER NULL;
      ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS coupon_discount_amount DECIMAL(12, 2) NULL;
      ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS token_no VARCHAR(50) NULL;
      ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS bill_format VARCHAR(30) DEFAULT 'STANDARD';
      ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS original_rate DECIMAL(12, 2) NULL;
      ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS scheme_discount_per_unit DECIMAL(12, 2) NULL;
      ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS free_item_id INTEGER NULL;
      ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS days_of_week VARCHAR(255) NULL;
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS leave_type_id INTEGER NULL;
      ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS x_coordinate INTEGER NULL;
      ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS y_coordinate INTEGER NULL;
      ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_recipe_based BOOLEAN DEFAULT FALSE;
      ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_tax_inclusive BOOLEAN DEFAULT FALSE;
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS time_zone VARCHAR(100) DEFAULT 'Asia/Kolkata';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS is_cloud_enabled BOOLEAN DEFAULT FALSE;
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS bill_format VARCHAR(30) DEFAULT 'STANDARD';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_salesperson_tagging BOOLEAN DEFAULT FALSE;
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS bill_copies_count INTEGER DEFAULT 1;
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_token_system BOOLEAN DEFAULT FALSE;
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS token_copies_count INTEGER DEFAULT 1;
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS device_printer_mappings JSONB DEFAULT '{}';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS base_currency_code VARCHAR(20) DEFAULT 'KES';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS base_currency_symbol VARCHAR(20) DEFAULT 'KSh';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS currency_symbol_position VARCHAR(20) DEFAULT 'BEFORE';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS currency_decimals INTEGER DEFAULT 2;
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS receipt_template_config JSONB DEFAULT '{}';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS a4_template_config JSONB DEFAULT '{}';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS a5_template_config JSONB DEFAULT '{}';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS kot_template_config JSONB DEFAULT '{}';
      ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS token_template_config JSONB DEFAULT '{}';
      ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS provider_type VARCHAR(50) DEFAULT 'SMTP';
      ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS gmail_client_id TEXT NULL;
      ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS gmail_client_secret TEXT NULL;
      ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS gmail_refresh_token TEXT NULL;
      ALTER TABLE email_configurations ADD COLUMN IF NOT EXISTS resend_api_key TEXT NULL;

      CREATE TABLE IF NOT EXISTS outlet_storage_quotas (
        id SERIAL PRIMARY KEY,
        outlet_id INTEGER NOT NULL,
        outlet_code VARCHAR(64) NOT NULL UNIQUE,
        base_quota_bytes BIGINT NOT NULL DEFAULT 16106127360,
        addon_quota_bytes BIGINT NOT NULL DEFAULT 0,
        promotional_bonus_bytes BIGINT NOT NULL DEFAULT 0,
        total_allocated_bytes BIGINT NOT NULL DEFAULT 16106127360,
        current_backups_bytes BIGINT NOT NULL DEFAULT 0,
        current_uploads_bytes BIGINT NOT NULL DEFAULT 0,
        current_db_bytes BIGINT NOT NULL DEFAULT 0,
        total_used_bytes BIGINT NOT NULL DEFAULT 0,
        warning_threshold_pct INTEGER NOT NULL DEFAULT 80,
        is_frozen BOOLEAN NOT NULL DEFAULT FALSE,
        active_plan_code VARCHAR(64) NOT NULL DEFAULT 'STARTER_15GB',
        plan_expires_at TIMESTAMP WITH TIME ZONE NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );
    `).catch((err: any) => console.warn('⚠️ Column alter notice:', err.message));

    // 3. Run all versioned migrations (schema_version)
    await runMigrations(activeDb);
    console.log('✅ Post-restore migrations executed successfully');

    // 4. CRITICAL: Turn cloud backup OFF by default upon restore!
    await activeDb.query(`UPDATE system_settings SET is_cloud_enabled = FALSE;`).catch(() => {});

    // 5. Turn off in backup_status.json for all restored outlets:
    try {
      const [rows]: any = await activeDb.query(`SELECT outlet_code FROM outlets WHERE is_active = true;`).catch(() => [[]]);
      if (Array.isArray(rows) && rows.length > 0) {
        for (const r of rows) {
          const code = r.outlet_code || r[0];
          if (code) {
            toggleCloudBackup(code, false);
          }
        }
      }
    } catch (_) {}

    console.log('✅ Post-restore: Cloud backup disabled by default in both DB and JSON tracker.');
  } catch (error: any) {
    console.error('❌ Post-restore schema healing error:', error.message);
  }
}

(runPostRestoreHealing as any).default = runPostRestoreHealing;
(runPostRestoreHealing as any).runPostRestoreHealing = runPostRestoreHealing;
module.exports = runPostRestoreHealing;
export default runPostRestoreHealing;
