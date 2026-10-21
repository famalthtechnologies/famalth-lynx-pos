"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncClientsJsonToMaster = syncClientsJsonToMaster;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const master_1 = __importDefault(require("../models/master"));
async function syncClientsJsonToMaster(db) {
    const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
    const clientJsonPath = path_1.default.join(rootDir, 'client.json');
    if (!fs_1.default.existsSync(clientJsonPath)) {
        return;
    }
    try {
        const rawData = fs_1.default.readFileSync(clientJsonPath, 'utf8');
        const clients = JSON.parse(rawData);
        if (!Array.isArray(clients) || clients.length === 0)
            return;
        const { MasterTenant, MasterOutlet, MasterLicense, MasterRelationshipManager } = (0, master_1.default)(db);
        const defaultRm = await MasterRelationshipManager.findOne({ where: { is_active: true } });
        for (const item of clients) {
            if (!item.client_id)
                continue;
            // 1. Upsert Tenant
            const [tenant] = await MasterTenant.findOrCreate({
                where: { id: item.client_id },
                defaults: {
                    id: item.client_id,
                    client_code: item.outlet_code || `CLIENT-${item.client_id.substring(0, 8)}`,
                    legal_name: item.property_name || 'Retail Client',
                    trade_name: item.property_name || 'Retail Client',
                    contact_email: item.contact_email || 'admin@client.com',
                    contact_phone: String(item.contact_phone || ''),
                    tax_identifier: item.tax_id || '',
                    status: item.status || 'ACTIVE',
                    pin_hash: item.pin || null,
                    rm_id: defaultRm ? defaultRm.id : null,
                    custom_metadata: {
                        folderId: item.folderId || '',
                        machine_id: item.machine_id || '',
                        db_name: item.db_name || 'POSINVRETAIL',
                    },
                },
            });
            const tenantId = tenant?.id || tenant?.get?.('id') || item.client_id;
            // 2. Upsert Outlet
            const outletCode = item.outlet_code || `OUTLET-${item.client_id.substring(0, 6)}`;
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
            // 3. Upsert License
            const licenseKey = `LIC-${(item.client_id || '').toUpperCase().substring(0, 16)}`;
            const validTill = item.expiry_date && !isNaN(new Date(item.expiry_date).getTime())
                ? new Date(item.expiry_date)
                : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000); // 1 year default
            await MasterLicense.findOrCreate({
                where: { tenant_id: tenantId },
                defaults: {
                    tenant_id: tenantId,
                    license_key: licenseKey,
                    tier_name: 'PROFESSIONAL',
                    max_outlets: 5,
                    max_terminals: 10,
                    valid_from: new Date(),
                    valid_till: validTill,
                    warning_zone_days: 15,
                    status: 'ACTIVE',
                },
            });
        }
        console.log(`✅ Synced ${clients.length} properties from client.json to Master Control Plane.`);
    }
    catch (err) {
        console.warn('⚠️ syncClientsJsonToMaster notice:', err.message);
    }
}
exports.default = syncClientsJsonToMaster;
