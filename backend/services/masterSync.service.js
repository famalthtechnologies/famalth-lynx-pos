"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureMasterDatabaseSync = exports.syncSingleOutletToMaster = void 0;
const masterSync_1 = require("../utils/masterSync");
Object.defineProperty(exports, "ensureMasterDatabaseSync", { enumerable: true, get: function () { return masterSync_1.ensureMasterDatabaseSync; } });
const syncSingleOutletToMaster = async (db, outlet, recoveryPinHash) => {
    return (0, masterSync_1.syncClientsJsonToMaster)(db);
};
exports.syncSingleOutletToMaster = syncSingleOutletToMaster;
exports.default = {
    syncSingleOutletToMaster: exports.syncSingleOutletToMaster,
    ensureMasterDatabaseSync: masterSync_1.ensureMasterDatabaseSync
};
