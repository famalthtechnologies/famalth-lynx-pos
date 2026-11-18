"use strict";
const db = require('../db/models');

async function run() {
  try {
    await db.authenticate();
    console.log("Connected to DB successfully.");

    await db.query(`
      CREATE TABLE IF NOT EXISTS hr_offices (
        id SERIAL PRIMARY KEY,
        outlet_id INTEGER NOT NULL DEFAULT 1,
        office_code VARCHAR(50) NOT NULL,
        office_name VARCHAR(255) NOT NULL,
        address TEXT,
        city VARCHAR(100),
        state VARCHAR(100),
        pincode VARCHAR(20),
        latitude DECIMAL(10, 7) DEFAULT 0.0,
        longitude DECIMAL(10, 7) DEFAULT 0.0,
        radius_meters INTEGER DEFAULT 150,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      CREATE INDEX IF NOT EXISTS idx_hr_offices_outlet ON hr_offices(outlet_id, is_active);

      ALTER TABLE hr_employees ADD COLUMN IF NOT EXISTS office_id INTEGER;
      ALTER TABLE hr_employees ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
      ALTER TABLE hr_employees ADD COLUMN IF NOT EXISTS reset_otp VARCHAR(10);
      ALTER TABLE hr_employees ADD COLUMN IF NOT EXISTS reset_otp_expires_at TIMESTAMP;
      CREATE INDEX IF NOT EXISTS idx_hr_employees_office_id ON hr_employees(office_id);

      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS office_id INTEGER;
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS checkin_latitude DECIMAL(10, 7);
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS checkin_longitude DECIMAL(10, 7);
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS checkin_distance_meters DECIMAL(10, 2);
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS checkout_latitude DECIMAL(10, 7);
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS checkout_longitude DECIMAL(10, 7);
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS checkout_distance_meters DECIMAL(10, 2);
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS is_geofence_compliant BOOLEAN DEFAULT TRUE;
      ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS early_departure_mins INTEGER DEFAULT 0;
      CREATE INDEX IF NOT EXISTS idx_hr_attendance_punches_office ON hr_attendance_punches(office_id);

      INSERT INTO hr_offices (outlet_id, office_code, office_name, address, city, state, pincode, latitude, longitude, radius_meters)
      SELECT 1, 'HO-01', 'Head Office - Dehradun', 'Rajpur Road', 'Dehradun', 'Uttarakhand', '248001', 30.3165000, 78.0322000, 200
      WHERE NOT EXISTS (SELECT 1 FROM hr_offices WHERE office_code = 'HO-01');

      UPDATE hr_employees SET office_id = (SELECT id FROM hr_offices ORDER BY id ASC LIMIT 1) WHERE office_id IS NULL;
    `);

    console.log("Migration 129 applied successfully!");

    const [offices] = await db.query("SELECT * FROM hr_offices;");
    console.log("Seeded offices:", offices);

    const [empCount] = await db.query("SELECT COUNT(*) as count FROM hr_employees WHERE office_id IS NOT NULL;");
    console.log("Employees with office_id:", empCount);

  } catch (err) {
    console.error("Migration failed:", err);
  } finally {
    process.exit(0);
  }
}

run();
