"use strict";
const propertyDb = require('../db/propertyDb');
async function run() {
    await propertyDb.authenticate();
    const [entries] = await propertyDb.query(`
    SELECT id, txn_date, transaction_type, reference_type, reference_id, reference_no, party_name, payment_method, amount_in, amount_out, adjustment_amount, notes 
    FROM cash_ledger 
    WHERE party_name ILIKE '%Coastal%' OR notes ILIKE '%454%' OR notes ILIKE '%RC-14-26%' 
    ORDER BY id DESC LIMIT 10
  `);
    console.log('Cash ledger entries:', JSON.stringify(entries, null, 2));
    const [bills] = await propertyDb.query(`
    SELECT * FROM supplier_bills WHERE bill_no = '454' OR grn_no = 'RC-14-26'
  `);
    console.log('Supplier bills:', JSON.stringify(bills, null, 2));
    const [suppliers] = await propertyDb.query(`
    SELECT * FROM supplier_master WHERE supplier_name ILIKE '%Coastal%'
  `);
    console.log('Suppliers:', JSON.stringify(suppliers, null, 2));
}
run().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
