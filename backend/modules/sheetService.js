"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.touchClient = touchClient;
exports.syncDatabaseOnly = syncDatabaseOnly;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const driveService_1 = require("./driveService");
const decryptConfig_1 = __importDefault(require("../utils/decryptConfig"));
const backupJob_1 = require("../jobs/backupJob");
const restore_1 = require("./restore");
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const CLIENT_FILE = path_1.default.join(rootDir, "client.json");
async function touchClient(outletCode) {
    if (!outletCode) {
        console.error("[TOUCH] Missing outletCode parameter.");
        return;
    }
    try {
        if (!fs_1.default.existsSync(CLIENT_FILE)) {
            return;
        }
        const config = (0, decryptConfig_1.default)();
        const fileData = fs_1.default.readFileSync(CLIENT_FILE, "utf8");
        let clients = JSON.parse(fileData);
        if (!Array.isArray(clients)) {
            clients = [clients];
        }
        const targetClient = clients.find((c) => c && c.outlet_code === outletCode);
        if (targetClient) {
            (0, backupJob_1.startBackupJob)(targetClient, config);
            await (0, driveService_1.upsertClient)(targetClient);
        }
        else {
            console.warn(`[TOUCH] Outlet configuration for ${outletCode} not found.`);
        }
    }
    catch (err) {
        console.error(`[TOUCH] Client sync failed: ${err.message}`);
    }
}
async function syncDatabaseOnly(req, res) {
    try {
        const outletCode = req.user?.outlet_code;
        if (!outletCode) {
            return res.status(400).json({
                success: false,
                message: "Missing outlet code in request."
            });
        }
        const fileData = fs_1.default.readFileSync(CLIENT_FILE, "utf8");
        let clients = JSON.parse(fileData);
        if (!Array.isArray(clients)) {
            clients = [clients];
        }
        const targetClient = clients.find((c) => c && c.outlet_code === outletCode);
        if (!targetClient || !targetClient.folderId) {
            return res.status(404).json({
                success: false,
                message: "Client not found or missing Google Drive folder ID."
            });
        }
        console.log(`[SYNC] Executing on-demand database sync from folder: ${targetClient.folderId}`);
        await (0, restore_1.autoRestoreLatest)(targetClient.folderId);
        console.log("[SYNC] Database sync sequence complete. Local data is up to date.");
        res.json({
            success: true,
            message: "Database synced successfully!"
        });
    }
    catch (error) {
        console.error(`[SYNC] Critical Sync Failure: ${error.message}`);
        res.status(500).json({
            success: false,
            message: "Data sync failed: " + error.message
        });
    }
}
exports.default = { touchClient, syncDatabaseOnly };
