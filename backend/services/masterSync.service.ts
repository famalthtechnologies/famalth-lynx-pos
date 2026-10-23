import { syncClientsJsonToMaster, ensureMasterDatabaseSync } from '../utils/masterSync';

export const syncSingleOutletToMaster = async (db: any, outlet: any, recoveryPinHash?: string) => {
    return syncClientsJsonToMaster(db);
};

export { ensureMasterDatabaseSync };

export default {
    syncSingleOutletToMaster,
    ensureMasterDatabaseSync
};
