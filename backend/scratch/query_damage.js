"use strict";
const db = require('../db/models');

(async () => {
  try {
    await db.authenticate();
    const [sales] = await db.query("SELECT id, sale_no, outlet_id, created_at FROM sales_headers ORDER BY id DESC LIMIT 5");
    console.log("Recent sales:", sales);
  } catch (e) {
    console.error(e);
  } finally {
    process.exit(0);
  }
})();
