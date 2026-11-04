"use strict";
const { Client } = require('pg');
const c = new Client({ host: '127.0.0.1', port: 5432, database: 'POSINVRETAIL', user: 'inv_admin_retail', password: 'R4QQB5NorGu5B5pK' });
c.connect().then(async () => {
    const cols = await c.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'plugins_installed'");
    console.log('plugins_installed cols:', cols.rows.map(r => r.column_name));
    await c.end();
}).catch(console.error);
