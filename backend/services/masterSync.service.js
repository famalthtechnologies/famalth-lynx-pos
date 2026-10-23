"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureMasterDatabaseSync = exports.syncSingleOutletToMaster = void 0;

const masterSync = require("../utils/masterSync");
const syncClientsJsonToMaster = masterSync.syncClientsJsonToMaster;
const ensureMasterDatabaseSync = masterSync.ensureMasterDatabaseSync;

const syncSingleOutletToMaster = async (db, outlet, recoveryPinHash) => {
    return syncClientsJsonToMaster(db);
};

exports.syncSingleOutletToMaster = syncSingleOutletToMaster;
exports.ensureMasterDatabaseSync = ensureMasterDatabaseSync;

exports.default = {
    syncSingleOutletToMaster,
    ensureMasterDatabaseSync
};
module.exports = {
    syncSingleOutletToMaster,
    ensureMasterDatabaseSync,
    default: {
        syncSingleOutletToMaster,
        ensureMasterDatabaseSync
    }
};
