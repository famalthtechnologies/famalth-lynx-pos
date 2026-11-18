"use strict";
const db = require('../db/models');

(async () => {
  try {
    const [dbs] = await db.query("SELECT datname FROM pg_database WHERE datistemplate = false;");
    console.log('Databases:', dbs);
  } catch(e) {
    console.error(e);
  }
  process.exit(0);
})();
