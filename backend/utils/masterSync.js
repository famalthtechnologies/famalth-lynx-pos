"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureMasterDatabaseSync = exports.syncClientsJsonToMaster = void 0;

const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const master_1 = __importDefault(require("../models/master"));
const { invalidateLicenseCache } = require('../controllers/public/licenseManager');

async function syncClientsJsonToMaster(db) {
    const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();

    const candidateClientPaths = [
        path_1.default.join(rootDir, 'client.json'),
        path_1.default.join(rootDir, 'backend', 'client.json'),
        path_1.default.join(process.cwd(), 'client.json'),
        path_1.default.join(process.cwd(), 'backend', 'client.json'),
        'C:\\Retailpos\\client.json'
    ];

    const foundClientFile = candidateClientPaths.find(p => fs_1.default.existsSync(p));

    try {
        const { MasterTenant, MasterOutlet, MasterLicense, MasterRelationshipManager } = (0, master_1.default)(db);
        let defaultRm = null;
        try {
            defaultRm = await MasterRelationshipManager.findOne({ where: { is_active: true } });
        } catch (_) {}

        // ==========================================
        // 1. SYNC FROM CLIENT.JSON (IF PRESENT)
        // ==========================================
        if (foundClientFile) {
            try {
                const rawData = fs_1.default.readFileSync(foundClientFile, 'utf8');
                const clients = JSON.parse(rawData);
                if (Array.isArray(clients) && clients.length > 0) {
                    for (const item of clients) {
                        const clientCode = item.outlet_code || (item.client_id ? `CLIENT-${item.client_id.substring(0, 8)}` : null);
                        if (!clientCode) continue;

                        const [tenant] = await MasterTenant.findOrCreate({
                            where: { client_code: clientCode },
                            defaults: {
                                id: item.client_id || undefined,
                                client_code: clientCode,
                                legal_name: item.property_name || 'Retail Client',
                                trade_name: item.property_name || 'Retail Client',
                                contact_email: item.contact_email || 'admin@client.com',
                                contact_phone: String(item.contact_phone || ''),
                                tax_identifier: item.tax_id || '',
                                status: item.status || 'ACTIVE',
                                pin_hash: item.pin || null,
                                rm_id: item.rm_id || null,
                                custom_metadata: {
                                    folderId: item.folderId || '',
                                    machine_id: item.machine_id || '',
                                    db_name: item.db_name || 'POSINVRETAIL',
                                },
                            },
                        });

                        const tenantId = tenant?.id || tenant?.get?.('id') || item.client_id;
                        const outletCode = item.outlet_code || clientCode;

                        await MasterOutlet.findOrCreate({
                            where: { outlet_code: outletCode },
                            defaults: {
                                tenant_id: tenantId,
                                outlet_code: outletCode,
                                outlet_name: item.property_name || 'Main Outlet',
                                outlet_type: 'RETAIL',
                                hardware_machine_id: item.machine_id || '',
                                is_active: item.status === 'ACTIVE',
                                is_kill_switched: item.status === 'SUSPENDED' || item.status === 'DEACTIVATED',
                                last_ping_at: new Date(),
                            },
                        });

                        const licenseKey = `LIC-${outletCode}-${Date.now().toString(36).toUpperCase()}`;
                        const validTill = item.expiry_date && !isNaN(new Date(item.expiry_date).getTime())
                            ? new Date(item.expiry_date)
                            : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000);

                        const existingLicense = await MasterLicense.findOne({ where: { tenant_id: tenantId } });
                        if (!existingLicense) {
                            await MasterLicense.create({
                                tenant_id: tenantId,
                                license_key: licenseKey,
                                tier_name: 'ENTERPRISE_UNLIMITED',
                                max_outlets: 10,
                                max_terminals: 20,
                                valid_from: new Date(),
                                valid_till: validTill,
                                warning_zone_days: 15,
                                grace_period_days: 15,
                                subscription_amount: 4999.00,
                                tax_percentage: 18.00,
                                payment_status: 'PAID',
                                is_perpetual: false,
                                status: 'ACTIVE',
                            });
                        }
                    }

                    // If client.json is missing in rootDir, create it to prevent future misses
                    const targetRootClient = path_1.default.join(rootDir, 'client.json');
                    if (!fs_1.default.existsSync(targetRootClient)) {
                        try {
                            fs_1.default.writeFileSync(targetRootClient, rawData, 'utf8');
                        } catch (_) {}
                    }
                }
            } catch (clientErr) {
                console.warn('⚠️ [MASTER_SYNC] Notice reading client.json:', clientErr.message);
            }
        }

        // ==========================================
        // 2. SYNC FROM DATABASE OUTLETS TABLE
        // ==========================================
        try {
            let dbOutlets = [];
            if (db.models && db.models.outlets) {
                dbOutlets = await db.models.outlets.findAll({ bypassOutletFilter: true });
            } else {
                const [rows] = await db.query('SELECT * FROM outlets');
                dbOutlets = rows || [];
            }

            for (const o of dbOutlets) {
                const rawOutlet = o.toJSON ? o.toJSON() : o;
                const code = rawOutlet.outlet_code;
                if (!code) continue;

                let masterOutlet = await MasterOutlet.findOne({
                    where: { outlet_code: code },
                    include: [{ model: MasterTenant, as: 'tenant' }]
                });

                let tenant = masterOutlet?.tenant;

                if (!tenant) {
                    tenant = await MasterTenant.findOne({ where: { client_code: code } });
                    if (!tenant) {
                        tenant = await MasterTenant.create({
                            client_code: code,
                            legal_name: rawOutlet.outlet_name || `Store ${code}`,
                            trade_name: rawOutlet.outlet_name || `Store ${code}`,
                            contact_email: rawOutlet.contact_email || `admin_${code.toLowerCase()}@retailpos.local`,
                            contact_phone: String(rawOutlet.contact_phone || ''),
                            tax_identifier: rawOutlet.tax_id || '',
                            status: rawOutlet.is_active ? 'ACTIVE' : 'SUSPENDED',
                            pin_hash: rawOutlet.recovery_pin_hash || null,
                            rm_id: null,
                            custom_metadata: {
                                registered_via: 'LOCAL_DATABASE_SYNC',
                                synced_at: new Date().toISOString()
                            }
                        });
                    }
                }

                const tenantId = tenant?.id || tenant?.get?.('id');

                if (!masterOutlet) {
                    masterOutlet = await MasterOutlet.create({
                        tenant_id: tenantId,
                        outlet_code: code,
                        outlet_name: rawOutlet.outlet_name || `${rawOutlet.outlet_code} Main`,
                        outlet_type: rawOutlet.outlet_type || 'RETAIL',
                        is_active: rawOutlet.is_active !== false,
                        is_kill_switched: false,
                        last_ping_at: new Date()
                    });
                }

                const activeLic = await MasterLicense.findOne({ where: { tenant_id: tenantId } });
                if (!activeLic) {
                    await MasterLicense.create({
                        tenant_id: tenantId,
                        license_key: `LIC-${code}-${Date.now().toString(36).toUpperCase()}`,
                        tier_name: 'ENTERPRISE_UNLIMITED',
                        max_outlets: 10,
                        max_terminals: 20,
                        valid_from: new Date(),
                        valid_till: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
                        warning_zone_days: 15,
                        grace_period_days: 15,
                        subscription_amount: 4999.00,
                        tax_percentage: 18.00,
                        payment_status: 'PAID',
                        is_perpetual: false,
                        status: 'ACTIVE'
                    });
                }

                try {
                    invalidateLicenseCache(code);
                } catch (_) {}
            }

            console.log(`✅ [MASTER_SYNC] Verified/synced ${dbOutlets.length} database outlets into Master Enterprise Control Plane.`);
        } catch (dbErr) {
            console.warn('⚠️ [MASTER_SYNC] Notice syncing database outlets:', dbErr.message);
        }

    } catch (err) {
        console.warn('⚠️ syncClientsJsonToMaster global notice:', err.message);
    }
}

exports.syncClientsJsonToMaster = syncClientsJsonToMaster;
exports.ensureMasterDatabaseSync = syncClientsJsonToMaster;
exports.default = {
    syncClientsJsonToMaster,
    ensureMasterDatabaseSync: syncClientsJsonToMaster
};
