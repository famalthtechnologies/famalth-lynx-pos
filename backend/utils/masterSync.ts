import fs from 'fs';
import path from 'path';
import initMasterModels from '../models/master';

export async function syncClientsJsonToMaster(db: any) {
  const rootDir = (process as any).pkg ? path.dirname(process.execPath) : process.cwd();
  const clientJsonPath = path.join(rootDir, 'client.json');

  if (!fs.existsSync(clientJsonPath)) {
    return;
  }

  try {
    const rawData = fs.readFileSync(clientJsonPath, 'utf8');
    const clients: any[] = JSON.parse(rawData);
    if (!Array.isArray(clients) || clients.length === 0) return;

    const { MasterTenant, MasterOutlet, MasterLicense, MasterRelationshipManager } = initMasterModels(db);
    const defaultRm = await MasterRelationshipManager.findOne({ where: { is_active: true } });

    for (const item of clients) {
      if (!item.client_id) continue;

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

      const tenantId = (tenant as any)?.id || (tenant as any)?.get?.('id') || item.client_id;

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
  } catch (err: any) {
    console.warn('⚠️ syncClientsJsonToMaster notice:', err.message);
  }
}

export default syncClientsJsonToMaster;
