"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.startLoyaltyExpiryJob = startLoyaltyExpiryJob;
const node_cron_1 = __importDefault(require("node-cron"));
const { expireDuePoints } = require('../services/loyalty.service');
const { withDistributedLock } = require('../utils/distributedLock');
function startLoyaltyExpiryJob(db) {
    if (!db)
        return;
    console.log('Initializing loyalty expiry cron: 15 0 * * *');
    node_cron_1.default.schedule('15 0 * * *', async () => {
        await withDistributedLock(db, 'loyalty_expiry_job', async () => {
            try {
                const result = await expireDuePoints(db, { batchSize: 500 });
                if ((result?.expired_rows || 0) > 0) {
                    console.log(`[LOYALTY] Expired rows: ${result.expired_rows}, expired points: ${result.expired_points}`);
                }
            }
            catch (error) {
                console.error(`[LOYALTY] Expiry cron failed: ${error.message}`);
            }
        });
    });
}
module.exports = { startLoyaltyExpiryJob };
