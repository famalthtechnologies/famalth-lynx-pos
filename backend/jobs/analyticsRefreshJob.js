"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.startAnalyticsRefreshJob = startAnalyticsRefreshJob;
const node_cron_1 = __importDefault(require("node-cron"));
const { refreshAllAnalytics } = require('../services/analytics.service');
const { withDistributedLock } = require('../utils/distributedLock');
function startAnalyticsRefreshJob(db) {
    if (!db)
        return;
    console.log('Initializing analytics refresh cron: 30 2 * * *');
    node_cron_1.default.schedule('30 2 * * *', async () => {
        await withDistributedLock(db, 'analytics_refresh_job', async () => {
            try {
                await refreshAllAnalytics(db);
                console.log('[ANALYTICS] Nightly refresh complete');
            }
            catch (error) {
                console.error(`[ANALYTICS] Nightly refresh failed: ${error.message}`);
            }
        });
    });
}
module.exports = { startAnalyticsRefreshJob };
