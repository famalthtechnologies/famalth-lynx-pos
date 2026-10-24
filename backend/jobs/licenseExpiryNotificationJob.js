"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.startLicenseExpiryNotificationJob = void 0;
const node_cron_1 = __importDefault(require("node-cron"));
const controlPlaneNotification_service_1 = __importDefault(require("../services/controlPlaneNotification.service"));

function startLicenseExpiryNotificationJob(db) {
    if (!db) return;

    console.log('⏰ Initializing License Expiry & 10-Day Renewal Invoice Job (Daily 09:00 AM + Startup Check)...');

    // Daily cron at 09:00 AM
    node_cron_1.default.schedule('0 9 * * *', async () => {
        try {
            console.log('⏰ [CRON] Running daily License Expiry & 10-Day Renewal Invoice dispatcher...');
            const result = await controlPlaneNotification_service_1.default.checkAndDispatchExpiryAndRenewalNotices(db);
            console.log(`⏰ [CRON FINISHED] Dispatched ${result.renewalCount} renewal invoice(s) and ${result.expiredCount} expiry alert(s).`);
        } catch (err) {
            console.error('[CRON ERROR: LICENSE NOTIFICATIONS]', err.message);
        }
    });

    // Startup catch-up check after 15 seconds
    setTimeout(async () => {
        try {
            console.log('🚀 [STARTUP] Running initial catch-up check for 10-Day Renewal Invoices & Expired Licenses...');
            const result = await controlPlaneNotification_service_1.default.checkAndDispatchExpiryAndRenewalNotices(db);
            if (result.renewalCount > 0 || result.expiredCount > 0) {
                console.log(`🚀 [STARTUP CATCH-UP COMPLETE] Sent ${result.renewalCount} renewal invoice(s) and ${result.expiredCount} expiry notice(s).`);
            }
        } catch (err) {
            console.error('[STARTUP LICENSE NOTIFICATIONS ERROR]', err.message);
        }
    }, 15000);
}

exports.startLicenseExpiryNotificationJob = startLicenseExpiryNotificationJob;
module.exports = { startLicenseExpiryNotificationJob };
