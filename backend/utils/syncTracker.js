"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getAllSyncStates = getAllSyncStates;
exports.getSyncState = getSyncState;
exports.updateSyncState = updateSyncState;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const SYNC_FILE = path_1.default.join(rootDir, "sync_status.json");
const DEFAULT_STATE = {
    folder_created: false,
    sheet_synced: false,
    config_synced: false,
    file_created: false,
    backup_synced: false
};
function getAllSyncStates() {
    try {
        if (fs_1.default.existsSync(SYNC_FILE)) {
            return JSON.parse(fs_1.default.readFileSync(SYNC_FILE, "utf8"));
        }
    }
    catch (err) {
        console.error("[SYNC] Could not read sync_status.json, initializing new tracker.");
    }
    return {};
}
function getSyncState(outletCode) {
    if (!outletCode) {
        throw new Error("[SYNC] Outlet code is required to fetch sync state.");
    }
    const allStates = getAllSyncStates();
    return allStates[outletCode] || { ...DEFAULT_STATE };
}
function updateSyncState(outletCode, taskName, status) {
    if (!outletCode) {
        throw new Error("[SYNC] Outlet code is required to update sync state.");
    }
    const allStates = getAllSyncStates();
    if (!allStates[outletCode]) {
        allStates[outletCode] = { ...DEFAULT_STATE };
    }
    allStates[outletCode][taskName] = status;
    try {
        const dir = path_1.default.dirname(SYNC_FILE);
        if (!fs_1.default.existsSync(dir)) {
            fs_1.default.mkdirSync(dir, { recursive: true });
        }
        fs_1.default.writeFileSync(SYNC_FILE, JSON.stringify(allStates, null, 2));
    }
    catch (err) {
        console.error(`[SYNC] Could not save sync state for ${taskName} at ${outletCode}: ${err.message}`);
    }
}
exports.default = {
    getSyncState,
    updateSyncState
};
