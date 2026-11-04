"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.isCloudEnvironment = isCloudEnvironment;
exports.getBackupStatus = getBackupStatus;
exports.updateSyncSuccess = updateSyncSuccess;
exports.toggleCloudBackup = toggleCloudBackup;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const STATUS_FILE = path_1.default.join(rootDir, 'backup_status.json');
function isCloudEnvironment() {
    return (process.env.RENDER === 'true' ||
        !!process.env.RENDER ||
        process.env.IS_CLOUD === 'true' ||
        process.env.CLOUD_MODE === 'true' ||
        (!!process.env.DATABASE_URL && !process.env.DATABASE_URL.includes('localhost') && !process.env.DATABASE_URL.includes('127.0.0.1')) ||
        (!!process.env.DB_HOST && !['localhost', '127.0.0.1'].includes(process.env.DB_HOST)));
}
function _readAllStatuses() {
    if (!fs_1.default.existsSync(STATUS_FILE))
        return {};
    try {
        return JSON.parse(fs_1.default.readFileSync(STATUS_FILE, 'utf8'));
    }
    catch (e) {
        return {};
    }
}
function getBackupStatus(outletCode) {
    const allData = _readAllStatuses();
    const defaultState = isCloudEnvironment();
    if (!allData[outletCode]) {
        return { lastSyncTime: null, isCloudEnabled: defaultState };
    }
    const record = allData[outletCode];
    if (typeof record.isCloudEnabled === 'undefined') {
        record.isCloudEnabled = defaultState;
    }
    else if (isCloudEnvironment() && record.isCloudEnabled === false && !record.userManuallyDisabled) {
        record.isCloudEnabled = true;
    }
    return record;
}
function updateSyncSuccess(outletCode) {
    const allData = _readAllStatuses();
    const defaultState = isCloudEnvironment();
    if (!allData[outletCode]) {
        allData[outletCode] = { lastSyncTime: null, isCloudEnabled: defaultState };
    }
    allData[outletCode].lastSyncTime = new Date().getTime();
    fs_1.default.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}
function toggleCloudBackup(outletCode, enabled) {
    const allData = _readAllStatuses();
    if (!allData[outletCode]) {
        allData[outletCode] = { lastSyncTime: null, isCloudEnabled: enabled };
    }
    allData[outletCode].isCloudEnabled = enabled;
    allData[outletCode].userManuallyDisabled = !enabled;
    fs_1.default.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}
module.exports = {
    getBackupStatus,
    updateSyncSuccess,
    toggleCloudBackup,
    isCloudEnvironment
};
