const propertyDb = require('../../db/propertyDb').default || require('../../db/propertyDb');
const initMasterModels = require('../../models/master').default || require('../../models/master');
const { isCloudEnvironment } = require('../../utils/backupTracker');
const { sendToGoogleScript } = require("../../modules/driveService");
const sysConfig = require('../../utils/configManager');
const effectiveConfig = (sysConfig && sysConfig.default) ? sysConfig.default : (sysConfig || {});

const SHEET_ID = effectiveConfig.sheetId || null;

// In-memory cache for verified licenses: outletCode -> { data, timestamp }
const licenseCache = new Map();
const LICENSE_CACHE_TTL_MS = 30 * 1000; // 30-second TTL so admin panel updates auto-reflect within seconds

function invalidateLicenseCache(outletCode) {
    if (outletCode) {
        licenseCache.delete(outletCode);
    } else {
        licenseCache.clear();
    }
}

async function verifyLicenseOnline(outletCode) {
    if (!outletCode) {
        return { license_status: 'EXPIRED', days_remaining: 0, message: 'Outlet code required' };
    }

    // Check memory cache first
    const cached = licenseCache.get(outletCode);
    if (cached && (Date.now() - cached.timestamp < LICENSE_CACHE_TTL_MS)) {
        return cached.data;
    }

    try {
        const { MasterOutlet, MasterTenant, MasterLicense } = initMasterModels(propertyDb);

        // 1. Direct real-time check against multi-tenant master PostgreSQL database
        let outlet = await MasterOutlet.findOne({
            where: { outlet_code: outletCode },
            include: [{
                model: MasterTenant,
                as: 'tenant',
                include: [{ model: MasterLicense, as: 'licenses' }]
            }]
        });

        // Fallback: If not found in MasterOutlet, check if outlet is registered in local outlets table
        if (!outlet && propertyDb?.models?.outlets) {
            try {
                const localOutlet = await propertyDb.models.outlets.findOne({
                    where: { outlet_code: outletCode, is_active: true },
                    bypassOutletFilter: true
                });
                if (localOutlet) {
                    const { syncSingleOutletToMaster } = require('../../services/masterSync.service');
                    await syncSingleOutletToMaster(propertyDb, localOutlet);
                    outlet = await MasterOutlet.findOne({
                        where: { outlet_code: outletCode },
                        include: [{
                            model: MasterTenant,
                            as: 'tenant',
                            include: [{ model: MasterLicense, as: 'licenses' }]
                        }]
                    });
                }
            } catch (localSyncErr: any) {
                console.warn('[LICENSE] Local outlet sync fallback error:', localSyncErr.message);
            }
        }

        if (outlet) {
            // Check tenant status
            if (outlet.tenant?.status === 'SUSPENDED' || outlet.tenant?.status === 'DEACTIVATED') {
                const res = {
                    license_status: 'SUSPENDED',
                    days_remaining: 0,
                    message: 'Client tenant account has been suspended by administration.'
                };
                licenseCache.set(outletCode, { data: res, timestamp: Date.now() });
                return res;
            }

            // Check outlet kill-switch / active status
            if (outlet.is_kill_switched || !outlet.is_active) {
                const res = {
                    license_status: 'LOCKED',
                    days_remaining: 0,
                    message: 'Outlet access has been remotely locked by administrator.'
                };
                licenseCache.set(outletCode, { data: res, timestamp: Date.now() });
                return res;
            }

            const activeLic = (outlet.tenant?.licenses || [])[0];
            if (!activeLic || !activeLic.valid_till) {
                const res = {
                    license_status: 'EXPIRED',
                    days_remaining: 0,
                    message: 'No active license found for this outlet. Please contact administration.'
                };
                licenseCache.set(outletCode, { data: res, timestamp: Date.now() });
                return res;
            }

            const expiryDate = new Date(activeLic.valid_till);
            const graceDays = Number(activeLic.grace_period_days || 15);
            const diffMs = expiryDate.getTime() - Date.now();
            const daysRemaining = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

            let licenseState = 'VALID';
            let message = 'License active';

            if (daysRemaining <= 0) {
                licenseState = 'EXPIRED';
                message = `Software license expired on ${expiryDate.toLocaleDateString()}. Please renew subscription to continue.`;
            } else if (daysRemaining <= (activeLic.warning_zone_days || 15)) {
                licenseState = 'WARNING';
                message = `Software license expires in ${daysRemaining} days on ${expiryDate.toLocaleDateString()}.`;
            }

            const result = {
                license_status: licenseState,
                days_remaining: daysRemaining,
                valid_till: activeLic.valid_till,
                grace_period_days: graceDays,
                software_start_date: activeLic.valid_from,
                payment_status: activeLic.payment_status || 'PAID',
                message
            };

            licenseCache.set(outletCode, { data: result, timestamp: Date.now() });
            return result;
        }

        // Check if outlet exists in local client.json for local server installations
        if (!isCloudEnvironment()) {
            try {
                const fs = require('fs');
                const path = require('path');
                const rootDir = (process as any).pkg ? path.dirname(process.execPath) : process.cwd();
                const candidateFiles = [
                    path.join(rootDir, 'client.json'),
                    path.join(rootDir, 'backend', 'client.json'),
                    path.join(process.cwd(), 'client.json'),
                    path.join(process.cwd(), 'backend', 'client.json')
                ];
                const foundClientFile = candidateFiles.find(f => fs.existsSync(f));
                if (foundClientFile) {
                    const clients = JSON.parse(fs.readFileSync(foundClientFile, 'utf8'));
                    const match = Array.isArray(clients) ? clients.find((c: any) => c.outlet_code === outletCode) : null;
                    if (match) {
                        const localResult = {
                            license_status: 'VALID',
                            days_remaining: 365,
                            valid_till: match.expiry_date || new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
                            message: 'Local server verified outlet via client configuration.'
                        };
                        licenseCache.set(outletCode, { data: localResult, timestamp: Date.now() });
                        return localResult;
                    }
                }
            } catch (_) {}
        }

        // Outlet not found in Master Enterprise Database:
        // Rule: If running on Cloud Online Server, DO NOT use Google Sheets/Drive.
        // If running on Local Server, use Google Script and Google Sheet as fallback.
        if (!isCloudEnvironment() && SHEET_ID) {
            try {
                const timeoutPromise = new Promise((_, reject) =>
                    setTimeout(() => reject(new Error("LICENSE_CHECK_TIMEOUT")), 3000)
                );

                const fetchPromise = sendToGoogleScript({
                    action: 'check_license',
                    sheetId: SHEET_ID,
                    outletCode: outletCode
                });

                const res: any = await Promise.race([fetchPromise, timeoutPromise]);
                const rawStatus = res.license_status ? String(res.license_status).trim().toUpperCase() : 'UNKNOWN';

                if (rawStatus === 'ACTIVE' && res.expiry_date) {
                    const expiryDate = new Date(res.expiry_date);
                    const daysRemaining = Math.ceil((expiryDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24));
                    let licenseState = daysRemaining <= 0 ? 'EXPIRED' : (daysRemaining <= 10 ? 'WARNING' : 'VALID');

                    const sheetResult = {
                        license_status: licenseState,
                        days_remaining: daysRemaining,
                        valid_till: res.expiry_date,
                        message: `Local server validated license via Google Sheet: ${licenseState}`
                    };
                    licenseCache.set(outletCode, { data: sheetResult, timestamp: Date.now() });
                    return sheetResult;
                }
            } catch (sheetErr: any) {
                console.warn('[LICENSE] Local Google Script fallback check failed:', sheetErr.message);
            }
        }

        // Outlet not found in Master Enterprise Database
        const unregisteredResult = {
            license_status: 'EXPIRED',
            days_remaining: 0,
            message: 'Unregistered outlet code. Access must be provisioned in Master Enterprise Control Plane.'
        };
        licenseCache.set(outletCode, { data: unregisteredResult, timestamp: Date.now() });
        return unregisteredResult;

    } catch (error) {
        if (cached) return cached.data;
        return { license_status: 'VALID', days_remaining: 365, message: 'Offline validation' };
    }
}

module.exports = { verifyLicenseOnline, invalidateLicenseCache };
export default { verifyLicenseOnline, invalidateLicenseCache };
