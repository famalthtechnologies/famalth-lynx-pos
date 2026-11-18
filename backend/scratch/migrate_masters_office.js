const propertyDb = require('../db/propertyDb').default || require('../db/propertyDb');

async function migrate() {
  console.log("Adding office_id to HR master tables...");
  const queries = [
    "ALTER TABLE hr_designations ADD COLUMN IF NOT EXISTS office_id INTEGER;",
    "CREATE INDEX IF NOT EXISTS idx_hr_designations_office ON hr_designations(office_id);",
    
    "ALTER TABLE hr_shifts ADD COLUMN IF NOT EXISTS office_id INTEGER;",
    "CREATE INDEX IF NOT EXISTS idx_hr_shifts_office ON hr_shifts(office_id);",

    "ALTER TABLE hr_leave_types ADD COLUMN IF NOT EXISTS office_id INTEGER;",
    "CREATE INDEX IF NOT EXISTS idx_hr_leave_types_office ON hr_leave_types(office_id);",

    "ALTER TABLE hr_salary_components ADD COLUMN IF NOT EXISTS office_id INTEGER;",
    "CREATE INDEX IF NOT EXISTS idx_hr_salary_components_office ON hr_salary_components(office_id);",

    "ALTER TABLE hr_pay_structures ADD COLUMN IF NOT EXISTS office_id INTEGER;",
    "CREATE INDEX IF NOT EXISTS idx_hr_pay_structures_office ON hr_pay_structures(office_id);",

    "ALTER TABLE hr_payroll_runs ADD COLUMN IF NOT EXISTS office_id INTEGER;",
    "CREATE INDEX IF NOT EXISTS idx_hr_payroll_runs_office ON hr_payroll_runs(office_id);"
  ];

  for (const q of queries) {
    try {
      await propertyDb.query(q);
      console.log("Executed:", q);
    } catch (e) {
      console.error("Error executing:", q, e.message);
    }
  }
  console.log("Migration complete!");
  process.exit(0);
}

migrate();
