"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanDatabaseSchema = cleanDatabaseSchema;
exports.executeSqlFileViaNode = executeSqlFileViaNode;
exports.executeDatabaseRestore = executeDatabaseRestore;
exports.autoRestoreLatest = autoRestoreLatest;
exports.restoreFromEncBuffer = restoreFromEncBuffer;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const child_process_1 = require("child_process");
const pg_1 = require("pg");
const driveService_1 = require("./driveService");
const decrypt_1 = require("../utils/decrypt");
const decryptConfig_1 = __importDefault(require("../utils/decryptConfig"));
const pgBinaries_1 = require("../utils/pgBinaries");
const migrationRunner_1 = __importDefault(require("../utils/migrationRunner"));
const propertyDb = require("../db/models");
const isCompiled = typeof process.pkg !== 'undefined';
const baseDir = isCompiled ? path_1.default.dirname(process.execPath) : path_1.default.join(__dirname, '..');
function getDbClientConfig(db_name, db_user, db_pass, host, port) {
    const config = (0, decryptConfig_1.default)();
    const dbUrl = process.env.DATABASE_URL || config.DATABASE_URL;
    if (dbUrl) {
        return {
            connectionString: dbUrl,
            ssl: (process.env.DB_SSL === 'true' || dbUrl.includes('render.com')) ? { rejectUnauthorized: false } : false
        };
    }
    return {
        host: host || config.db_host || "127.0.0.1",
        port: Number(port || config.db_port || 5432),
        user: db_user || config.db_user || "postgres",
        password: String(db_pass || config.db_password || ""),
        database: db_name || config.db_database || "postgres"
    };
}
async function cleanDatabaseSchema(db_name, db_user, db_pass, host, port) {
    const psqlPath = (0, pgBinaries_1.findPostgresBinary)("psql");
    const h = host || "127.0.0.1";
    const p = String(port || 5432);
    console.log(`🧹 Cleaning database schema for ${db_name}...`);
    try {
        await new Promise((resolve, reject) => {
            const env = { ...process.env, PGPASSWORD: db_pass };
            const args = [
                "-h", h,
                "-p", p,
                "-U", db_user,
                "-d", db_name,
                "-c", "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO public;"
            ];
            const cleanProcess = (0, child_process_1.spawn)(psqlPath, args, { env });
            cleanProcess.stderr.on("data", (data) => console.log(`🧹 psql cleanup: ${data.toString().trim()}`));
            cleanProcess.on("close", (code) => {
                if (code === 0) {
                    console.log("✅ Database schema cleaned successfully via psql!");
                    resolve();
                }
                else {
                    reject(new Error("psql schema cleanup exited with code " + code));
                }
            });
            cleanProcess.on("error", (err) => {
                reject(err);
            });
        });
    }
    catch (psqlErr) {
        console.warn(`⚠️ psql schema cleanup failed (${psqlErr.message}). Using direct Node.js DB connection...`);
        const client = new pg_1.Client(getDbClientConfig(db_name, db_user, db_pass, host, port));
        await client.connect();
        try {
            await client.query("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO public;");
            console.log("✅ Database schema cleaned successfully via Node.js client!");
        }
        finally {
            await client.end().catch(() => { });
        }
    }
}
async function executeSqlFileViaNode(sqlFilePath, db_name, db_user, db_pass, host, port) {
    console.log("⚡ Executing SQL restore payload via pure Node.js PG client...");
    const client = new pg_1.Client(getDbClientConfig(db_name, db_user, db_pass, host, port));
    await client.connect();
    try {
        let sqlContent = fs_1.default.readFileSync(sqlFilePath, "utf8");
        // Remove psql meta-commands (lines starting with \) so pure Node PG client does not choke
        sqlContent = sqlContent
            .split(/\r?\n/)
            .filter(line => !line.trim().startsWith('\\'))
            .join('\n');
        // If the SQL file does not create tables (e.g. Node fallback dump), run migrations first
        const hasCreateTable = /CREATE\s+TABLE/i.test(sqlContent);
        if (!hasCreateTable) {
            console.log("📦 Backup contains data-only dump. Generating schema migrations first...");
            await (0, migrationRunner_1.default)(propertyDb);
        }
        await client.query(sqlContent);
        console.log("✅ SQL restore completed via Node.js client");
    }
    finally {
        await client.end().catch(() => { });
    }
}
async function executeDatabaseRestore(sqlFilePath, db_name, db_user, db_pass, host, port) {
    const config = (0, decryptConfig_1.default)();
    const targetDb = db_name || config.db_database;
    const targetUser = db_user || config.db_user || "postgres";
    const targetPass = db_pass || config.db_password || "";
    const targetHost = host || config.db_host || "127.0.0.1";
    const targetPort = port || config.db_port || 5432;
    const psqlPath = (0, pgBinaries_1.findPostgresBinary)("psql");
    if (!fs_1.default.existsSync(sqlFilePath) || fs_1.default.statSync(sqlFilePath).size === 0) {
        throw new Error("Restore SQL file is missing or empty.");
    }
    const hasPsql = psqlPath && fs_1.default.existsSync(psqlPath);
    if (!hasPsql) {
        console.warn("⚠️ psql.exe was not found (" + psqlPath + "). Restoring directly via pure Node.js PG client...");
        await executeSqlFileViaNode(sqlFilePath, targetDb, targetUser, targetPass, targetHost, targetPort);
        return;
    }
    // 2. Perform the actual restore
    try {
        console.log(`🚀 Starting database restore for ${targetDb} via psql (${psqlPath})...`);
        await new Promise((resolve, reject) => {
            const env = { ...process.env, PGPASSWORD: targetPass };
            const args = [
                "-X",
                "-h", targetHost,
                "-p", String(targetPort),
                "-U", targetUser,
                "-d", targetDb,
                "-f", sqlFilePath
            ];
            const restoreProcess = (0, child_process_1.spawn)(psqlPath, args, { env, stdio: ["ignore", "pipe", "pipe"] });
            let stderrOutput = "";
            restoreProcess.stdout.resume(); // Drain stdout to prevent OS pipe buffer saturation
            restoreProcess.stderr.on("data", (data) => { stderrOutput += data.toString(); });
            restoreProcess.on("close", (code) => {
                if (code === 0) {
                    console.log("✅ Database restored completely via psql!");
                    resolve();
                }
                else {
                    const lines = stderrOutput.trim().split(/\r?\n/);
                    let errorIndex = -1;
                    for (let i = lines.length - 1; i >= 0; i--) {
                        if (/\bERROR:/i.test(lines[i])) {
                            errorIndex = i;
                            break;
                        }
                    }
                    const details = errorIndex >= 0
                        ? lines.slice(errorIndex, Math.min(lines.length, errorIndex + 8)).join("\n")
                        : lines.slice(-8).join("\n");
                    reject(new Error("psql restore failed with code " + code + ": " + (details || "no PostgreSQL error details were returned")));
                }
            });
            restoreProcess.on("error", (err) => {
                reject(err);
            });
        });
    }
    catch (psqlErr) {
        console.warn("⚠️ psql restore failed (" + psqlErr?.message + "). Falling back to pure Node.js PG client...");
        await executeSqlFileViaNode(sqlFilePath, targetDb, targetUser, targetPass, targetHost, targetPort);
    }
    // 3. Post-Restore Schema Alignment & Migration verification
    try {
        console.log("🔄 Reconciling database schema and running migrations after restore...");
        await (0, migrationRunner_1.default)(propertyDb);
        console.log("✅ Post-restore migrations verified successfully");
    }
    catch (migErr) {
        console.warn("⚠️ Notice during post-restore migration check:", migErr.message);
    }
}
async function autoRestoreLatest(folderId) {
    const config = (0, decryptConfig_1.default)();
    const restoreDir = path_1.default.join(baseDir, "backups", `restore-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`);
    const encFile = path_1.default.join(restoreDir, "restore.enc");
    const zipFile = path_1.default.join(restoreDir, "restore.zip");
    const sqlFile = path_1.default.join(restoreDir, "backup.sql");
    try {
        fs_1.default.mkdirSync(restoreDir, { recursive: true });
        console.log("[RESTORE] Locating latest backup in Google Drive...");
        // 1. Request Download
        const res = await (0, driveService_1.sendToGoogleScript)({
            action: 'download_latest_backup',
            folderId: folderId
        });
        // Validation: Verify cloud response contains actual file data
        if (!res || !res.base64) {
            throw new Error("No backup files found in the cloud directory.");
        }
        fs_1.default.writeFileSync(encFile, Buffer.from(res.base64, 'base64'));
        console.log(`[RESTORE] Successfully downloaded payload: ${res.filename}`);
        // Validation: Ensure the file was actually written to the local disk
        if (!fs_1.default.existsSync(encFile)) {
            throw new Error("Local I/O Error: Failed to write downloaded backup to disk.");
        }
        // 2. Decrypt & Unzip
        console.log("[RESTORE] Decrypting and extracting backup archive...");
        const extractedSqlFile = await (0, decrypt_1.decryptAndUnzip)(encFile, zipFile, restoreDir);
        // Validation: Ensure the SQL file was successfully extracted from the ZIP
        if (!fs_1.default.existsSync(extractedSqlFile)) {
            throw new Error("Extraction corrupted: 'backup.sql' was not found in the archive.");
        }
        // 3. Restore Database
        console.log("[RESTORE] Applying database payload...");
        await executeDatabaseRestore(extractedSqlFile, config.db_database, config.db_user, config.db_password, config.db_host, config.db_port);
        // 4. Cleanup temporary files
        console.log("[RESTORE] Scrubbing temporary files...");
        [encFile, zipFile, sqlFile, extractedSqlFile].forEach(file => {
            if (file && fs_1.default.existsSync(file)) {
                try {
                    fs_1.default.unlinkSync(file);
                }
                catch (_) { }
            }
        });
        if (fs_1.default.existsSync(restoreDir)) {
            fs_1.default.rmSync(restoreDir, { recursive: true, force: true });
        }
        console.log("[RESTORE] Database recovery sequence completed successfully.");
    }
    catch (error) {
        console.error(`[RESTORE] Workflow Interrupted: ${error.message}`);
        // Safety cleanup
        [encFile, zipFile, sqlFile].forEach(file => {
            if (fs_1.default.existsSync(file)) {
                try {
                    fs_1.default.unlinkSync(file);
                }
                catch (e) { }
            }
        });
        if (fs_1.default.existsSync(restoreDir)) {
            try {
                fs_1.default.rmSync(restoreDir, { recursive: true, force: true });
            }
            catch (e) { }
        }
        throw error;
    }
}
async function restoreFromEncBuffer(encBuffer) {
    const config = (0, decryptConfig_1.default)();
    const restoreDir = path_1.default.join(baseDir, "backups", `restore-local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`);
    const encFile = path_1.default.join(restoreDir, "restore.enc");
    const zipFile = path_1.default.join(restoreDir, "restore.zip");
    try {
        fs_1.default.mkdirSync(restoreDir, { recursive: true });
        fs_1.default.writeFileSync(encFile, encBuffer);
        const extractedSqlFile = await (0, decrypt_1.decryptAndUnzip)(encFile, zipFile, restoreDir);
        if (!fs_1.default.existsSync(extractedSqlFile)) {
            throw new Error("Extraction corrupted: 'backup.sql' was not found in the archive.");
        }
        await executeDatabaseRestore(extractedSqlFile, config.db_database, config.db_user, config.db_password, config.db_host, config.db_port);
    }
    finally {
        if (fs_1.default.existsSync(restoreDir)) {
            try {
                fs_1.default.rmSync(restoreDir, { recursive: true, force: true });
            }
            catch (_) { }
        }
    }
}
exports.default = { autoRestoreLatest, restoreFromEncBuffer, executeDatabaseRestore, cleanDatabaseSchema };
