"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.initClient = initClient;
const os_1 = __importDefault(require("os"));
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const uuid_1 = require("uuid");
const backupJob_1 = require("../jobs/backupJob");
const driveService_1 = require("./driveService");
const updownconfig_1 = require("./updownconfig");
const syncTracker_1 = require("../utils/syncTracker");
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const CLIENT_FILE = path_1.default.join(rootDir, "client.json");
const DATA_DIR = path_1.default.dirname(CLIENT_FILE);
const LOG_FILE = path_1.default.join(rootDir, "init_process.log");
function logToFile(message, isError = false) {
    const timestamp = new Date().toISOString();
    const logPrefix = isError ? "[ERROR]" : "[INFO]";
    const formattedMessage = `${timestamp} ${logPrefix} ${message}\n`;
    if (isError) {
        console.error(formattedMessage.trim());
    }
    else {
        console.log(formattedMessage.trim());
    }
    try {
        fs_1.default.appendFileSync(LOG_FILE, formattedMessage);
    }
    catch (err) {
        console.error(`Failed to write to log file: ${err.message}`);
    }
}
// Use a Set to track running backup jobs per outlet to prevent duplicate executions
const activeBackupJobs = new Set();
async function initClient(config, outlet) {
    if (!fs_1.default.existsSync(DATA_DIR)) {
        fs_1.default.mkdirSync(DATA_DIR, { recursive: true });
    }
    let clients = [];
    let needsSave = false;
    // 1. Load and parse the client file as an array
    const candidateFiles = [
        CLIENT_FILE,
        path_1.default.join(rootDir, "backend", "client.json"),
        path_1.default.join(process.cwd(), "client.json"),
        path_1.default.join(process.cwd(), "backend", "client.json")
    ];
    const existingFile = candidateFiles.find(f => fs_1.default.existsSync(f));
    try {
        if (existingFile) {
            const fileData = fs_1.default.readFileSync(existingFile, "utf8");
            clients = JSON.parse(fileData);
            // Migrate legacy single-object configurations to an array format
            if (!Array.isArray(clients)) {
                clients = [clients];
                needsSave = true;
            }
        }
        else {
            needsSave = true;
        }
    }
    catch (err) {
        logToFile("[INIT] Invalid client.json format. Reinitializing file.", true);
        clients = [];
        needsSave = true;
    }
    // 2. Identify or create the specific client configuration
    let clientIndex = clients.findIndex(c => c.outlet_code === outlet.outlet_code);
    let client = clientIndex >= 0 ? clients[clientIndex] : null;
    if (!client) {
        client = {
            client_id: (0, uuid_1.v4)(),
            folderId: null,
            outlet_code: outlet.outlet_code,
            outlet_id: outlet.id,
            property_name: outlet.outlet_name,
            machine_id: os_1.default.hostname(),
            db_name: config.db_database,
            created_at: new Date().toISOString(),
            status: "ACTIVE",
            expiry_date: "",
            contact_email: outlet.contact_email || "",
            contact_phone: outlet.contact_phone || "",
            tax_id: outlet.tax_id || "",
            pin: outlet.recovery_pin_hash || "",
        };
        clients.push(client);
        clientIndex = clients.length - 1;
        needsSave = true;
    }
    // Fetch synchronization state specific to this outlet
    const syncState = (0, syncTracker_1.getSyncState)(client.outlet_code);
    // 3. Task: Create Cloud Directory
    if (!syncState.folder_created || !client.folderId) {
        try {
            logToFile(`[INIT] Creating cloud directory for outlet: ${client.outlet_code}`);
            const newFolderId = await (0, driveService_1.createClientFolder)(client.outlet_code);
            if (newFolderId) {
                client.folderId = newFolderId;
                clients[clientIndex] = client;
                (0, syncTracker_1.updateSyncState)(client.outlet_code, 'folder_created', true);
                fs_1.default.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2));
                needsSave = false;
                logToFile(`[INIT] Directory allocated. ID: ${client.folderId}`);
            }
        }
        catch (err) {
            logToFile(`[INIT] Directory creation failed: ${err.message}`, true);
            client.folderId = null;
        }
    }
    // 4. Task: Initialize Backup Scheduler
    if (client.folderId && !syncState.backup_synced) {
        if (!activeBackupJobs.has(client.outlet_code)) {
            try {
                activeBackupJobs.add(client.outlet_code);
                (0, syncTracker_1.updateSyncState)(client.outlet_code, 'backup_synced', true);
                (0, backupJob_1.startBackupJob)(client, config);
                logToFile(`[INIT] Backup scheduler activated for outlet: ${client.outlet_code}`);
            }
            catch (err) {
                logToFile(`[INIT] Backup scheduler failed: ${err.message}`, true);
                activeBackupJobs.delete(client.outlet_code);
            }
        }
    }
    // 5. Task: Synchronize Cloud Ledger (Sheets)
    if (!syncState.sheet_synced) {
        try {
            logToFile(`[INIT] Synchronizing ledger for outlet: ${client.outlet_code}`);
            await (0, driveService_1.upsertClient)(client);
            (0, syncTracker_1.updateSyncState)(client.outlet_code, 'sheet_synced', true);
        }
        catch (err) {
            logToFile(`[INIT] Ledger synchronization failed: ${err.message}`, true);
        }
    }
    if (!syncState.config_synced && client.folderId) {
        try {
            logToFile(`[INIT] Uploading system configurations and license for outlet: ${client.outlet_code}`);
            await (0, updownconfig_1.uploadSystemConfigs)(client.folderId);
            (0, syncTracker_1.updateSyncState)(client.outlet_code, 'config_synced', true);
        }
        catch (err) {
            logToFile(`[INIT] Configuration upload failed: ${err.message}`, true);
        }
    }
    if (needsSave) {
        try {
            const dataStr = JSON.stringify(clients, null, 2);
            fs_1.default.writeFileSync(CLIENT_FILE, dataStr);
            const backendClientFile = path_1.default.join(rootDir, "backend", "client.json");
            if (backendClientFile !== CLIENT_FILE && fs_1.default.existsSync(path_1.default.dirname(backendClientFile))) {
                try {
                    fs_1.default.writeFileSync(backendClientFile, dataStr);
                }
                catch (_) { }
            }
            logToFile(`[INIT] Local configuration updated successfully.`);
        }
        catch (err) {
            logToFile(`[INIT] Failed to persist local configuration: ${err.message}`, true);
        }
    }
    return client;
}
exports.default = { initClient };
