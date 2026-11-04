"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.waitForPostgres = waitForPostgres;
const sequelize_1 = require("sequelize");
require("pg");
const decryptConfig_1 = __importDefault(require("./decryptConfig"));
async function waitForPostgres() {
    const config = (0, decryptConfig_1.default)();
    const host = config.db_host || "127.0.0.1";
    const user = config.db_user || "postgres";
    const password = config.db_password;
    const portsToTry = [
        Number(config.db_port) || 5432,
        5432,
        5433
    ];
    let retries = 30;
    while (retries > 0) {
        for (const port of portsToTry) {
            try {
                if (!config.db_database) {
                    console.log("🔥 Config:", config);
                    throw new Error("❌ Database name missing in config.enc");
                }
                const sequelize = new sequelize_1.Sequelize("postgres", user, password, {
                    host: host,
                    port: port,
                    dialect: "postgres",
                    logging: false,
                    dialectOptions: { connectTimeout: 3000 }
                });
                await sequelize.authenticate();
                await sequelize.close();
                console.log(`✅ PostgreSQL ready on ${host}:${port}`);
                return true;
            }
            catch (err) {
                console.log(`❌ Failed on port ${port}:`, err.message);
            }
        }
        retries--;
        console.log(`⏳ Waiting for PostgreSQL... (${retries} retries left)`);
        await new Promise(r => setTimeout(r, 3000));
    }
    throw new Error("PostgreSQL not reachable");
}
exports.default = waitForPostgres;
