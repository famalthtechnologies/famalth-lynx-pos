const propertyDb = require('../db/propertyDb').default || require('../db/propertyDb');

async function check() {
  const [tables] = await propertyDb.query(`SELECT table_name, table_schema FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') AND table_name ILIKE '%hr%'`);
  console.log('HR tables:', tables);
  process.exit(0);
}
check();
