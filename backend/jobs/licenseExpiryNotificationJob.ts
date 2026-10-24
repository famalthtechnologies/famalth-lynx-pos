import cron from 'node-cron';
import ControlPlaneNotificationService from '../services/controlPlaneNotification.service';

export function startLicenseExpiryNotificationJob(db: any): void {
  if (!db) return;

  console.log('⏰ Initializing License Expiry & 10-Day Renewal Invoice Job (Daily 09:00 AM + Startup Check)...');

  // Daily cron at 09:00 AM
  cron.schedule('0 9 * * *', async () => {
    try {
      console.log('⏰ [CRON] Running daily License Expiry & 10-Day Renewal Invoice dispatcher...');
      const result = await ControlPlaneNotificationService.checkAndDispatchExpiryAndRenewalNotices(db);
      console.log(`⏰ [CRON FINISHED] Dispatched ${result.renewalCount} renewal invoice(s) and ${result.expiredCount} expiry alert(s).`);
    } catch (err: any) {
      console.error('[CRON ERROR: LICENSE NOTIFICATIONS]', err.message);
    }
  });

  // Startup catch-up check after 15 seconds to ensure any due notices while server was offline are delivered
  setTimeout(async () => {
    try {
      console.log('🚀 [STARTUP] Running initial catch-up check for 10-Day Renewal Invoices & Expired Licenses...');
      const result = await ControlPlaneNotificationService.checkAndDispatchExpiryAndRenewalNotices(db);
      if (result.renewalCount > 0 || result.expiredCount > 0) {
        console.log(`🚀 [STARTUP CATCH-UP COMPLETE] Sent ${result.renewalCount} renewal invoice(s) and ${result.expiredCount} expiry notice(s).`);
      }
    } catch (err: any) {
      console.error('[STARTUP LICENSE NOTIFICATIONS ERROR]', err.message);
    }
  }, 15000);
}

module.exports = { startLicenseExpiryNotificationJob };
