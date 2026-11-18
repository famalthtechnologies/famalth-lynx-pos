"use strict";
const Sequelize = require('sequelize');
const loadConfig = require('./utils/decryptConfig');

async function check() {
    try {
        const config = loadConfig();
        const db = new Sequelize("famalth_lynx", config.db_user, config.db_password, {
            host: config.db_host,
            port: Number(config.db_port),
            dialect: "postgres",
            logging: false
        });
        await db.authenticate();
        const [items] = await db.query("SELECT id, item_code, item_name, rate, retail_sale_price FROM item_master WHERE item_name ILIKE '%Backpack%'");
        console.log("BACKPACK ITEMS:", items);
        const [dis] = await db.query("SELECT * FROM damage_items WHERE item_id IN (SELECT id FROM item_master WHERE item_name ILIKE '%Backpack%')");
        console.log("DAMAGE ITEMS FOR BACKPACK:", dis);
        if (dis.length > 0) {
            const damageIds = dis.map(d => d.damage_id);
            const [dhs] = await db.query("SELECT * FROM damage_headers WHERE id IN (" + damageIds.join(',') + ")");
            console.log("DAMAGE HEADERS FOR BACKPACK:", dhs);
        }
        await db.close();
    } catch (e) {
        console.error("❌ Error:", e.message);
    }
}
check();
