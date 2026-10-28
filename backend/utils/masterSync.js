var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);
var masterSync_exports = {};
__export(masterSync_exports, {
  default: () => masterSync_default,
  ensureMasterDatabaseSync: () => ensureMasterDatabaseSync,
  syncClientsJsonToMaster: () => syncClientsJsonToMaster
});
module.exports = __toCommonJS(masterSync_exports);
var import_fs = __toESM(require("fs"));
var import_path = __toESM(require("path"));
var import_master = __toESM(require("../models/master"));
const { invalidateLicenseCache } = require("../controllers/public/licenseManager");
async function syncClientsJsonToMaster(db) {
  const rootDir = process.pkg ? import_path.default.dirname(process.execPath) : process.cwd();
  const candidateClientPaths = [
    import_path.default.join(rootDir, "client.json"),
    import_path.default.join(rootDir, "backend", "client.json"),
    import_path.default.join(process.cwd(), "client.json"),
    import_path.default.join(process.cwd(), "backend", "client.json"),
    "C:\\Retailpos\\client.json"
  ];
  const foundClientFile = candidateClientPaths.find((p) => import_fs.default.existsSync(p));
  try {
    try {
      await db.query(`
        ALTER TABLE ticket_messages ADD COLUMN IF NOT EXISTS is_read_by_support BOOLEAN DEFAULT FALSE;
        ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS last_read_by_support_at TIMESTAMP WITH TIME ZONE;
      `);
    } catch (_) {
    }
    const { MasterTenant, MasterOutlet, MasterLicense, MasterRelationshipManager } = (0, import_master.default)(db);
    let defaultRm = null;
    try {
      defaultRm = await MasterRelationshipManager.findOne({ where: { is_active: true } });
    } catch (_) {
    }
    if (foundClientFile) {
      try {
        const rawData = import_fs.default.readFileSync(foundClientFile, "utf8");
        const clients = JSON.parse(rawData);
        if (Array.isArray(clients) && clients.length > 0) {
          for (const item of clients) {
            const clientCode = item.outlet_code || (item.client_id ? `CLIENT-${item.client_id.substring(0, 8)}` : null);
            if (!clientCode) continue;
            const [tenant] = await MasterTenant.findOrCreate({
              where: { client_code: clientCode },
              defaults: {
                id: item.client_id || void 0,
                client_code: clientCode,
                legal_name: item.property_name || "Retail Client",
                trade_name: item.property_name || "Retail Client",
                contact_email: item.contact_email || "admin@client.com",
                contact_phone: String(item.contact_phone || ""),
                tax_identifier: item.tax_id || "",
                status: item.status || "ACTIVE",
                pin_hash: item.pin || null,
                rm_id: item.rm_id || null,
                custom_metadata: {
                  folderId: item.folderId || "",
                  machine_id: item.machine_id || "",
                  db_name: item.db_name || "POSINVRETAIL"
                }
              }
            });
            const tenantId = tenant?.id || tenant?.get?.("id") || item.client_id;
            const outletCode = item.outlet_code || clientCode;
            await MasterOutlet.findOrCreate({
              where: { outlet_code: outletCode },
              defaults: {
                tenant_id: tenantId,
                outlet_code: outletCode,
                outlet_name: item.property_name || "Main Outlet",
                outlet_type: "RETAIL",
                hardware_machine_id: item.machine_id || "",
                is_active: item.status === "ACTIVE",
                is_kill_switched: item.status === "SUSPENDED" || item.status === "DEACTIVATED",
                last_ping_at: /* @__PURE__ */ new Date()
              }
            });
            const licenseKey = `LIC-${outletCode}-${Date.now().toString(36).toUpperCase()}`;
            const validTill = item.expiry_date && !isNaN(new Date(item.expiry_date).getTime()) ? new Date(item.expiry_date) : new Date(Date.now() + 365 * 24 * 60 * 60 * 1e3);
            const existingLicense = await MasterLicense.findOne({ where: { tenant_id: tenantId } });
            if (!existingLicense) {
              await MasterLicense.create({
                tenant_id: tenantId,
                license_key: licenseKey,
                tier_name: "ENTERPRISE_UNLIMITED",
                max_outlets: 10,
                max_terminals: 20,
                valid_from: /* @__PURE__ */ new Date(),
                valid_till: validTill,
                warning_zone_days: 15,
                grace_period_days: 15,
                subscription_amount: 4999,
                tax_percentage: 18,
                payment_status: "PAID",
                is_perpetual: false,
                status: "ACTIVE"
              });
            }
          }
          const targetRootClient = import_path.default.join(rootDir, "client.json");
          if (!import_fs.default.existsSync(targetRootClient)) {
            try {
              import_fs.default.writeFileSync(targetRootClient, rawData, "utf8");
            } catch (_) {
            }
          }
        }
      } catch (clientErr) {
        console.warn("\u26A0\uFE0F [MASTER_SYNC] Notice reading client.json:", clientErr.message);
      }
    }
    try {
      let dbOutlets = [];
      if (db.models && db.models.outlets) {
        dbOutlets = await db.models.outlets.findAll({ bypassOutletFilter: true });
      } else {
        const [rows] = await db.query("SELECT * FROM outlets");
        dbOutlets = rows || [];
      }
      for (const o of dbOutlets) {
        const rawOutlet = o.toJSON ? o.toJSON() : o;
        const code = rawOutlet.outlet_code;
        if (!code) continue;
        let masterOutlet = await MasterOutlet.findOne({
          where: { outlet_code: code },
          include: [{ model: MasterTenant, as: "tenant" }]
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
              contact_phone: String(rawOutlet.contact_phone || ""),
              tax_identifier: rawOutlet.tax_id || "",
              status: rawOutlet.is_active ? "ACTIVE" : "SUSPENDED",
              pin_hash: rawOutlet.recovery_pin_hash || null,
              rm_id: null,
              custom_metadata: {
                registered_via: "LOCAL_DATABASE_SYNC",
                synced_at: (/* @__PURE__ */ new Date()).toISOString()
              }
            });
          }
        }
        const tenantId = tenant?.id || tenant?.get?.("id");
        if (!masterOutlet) {
          masterOutlet = await MasterOutlet.create({
            tenant_id: tenantId,
            outlet_code: code,
            outlet_name: rawOutlet.outlet_name || `${rawOutlet.outlet_code} Main`,
            outlet_type: rawOutlet.outlet_type || "RETAIL",
            is_active: rawOutlet.is_active !== false,
            is_kill_switched: false,
            last_ping_at: /* @__PURE__ */ new Date()
          });
        }
        const activeLic = await MasterLicense.findOne({ where: { tenant_id: tenantId } });
        if (!activeLic) {
          await MasterLicense.create({
            tenant_id: tenantId,
            license_key: `LIC-${code}-${Date.now().toString(36).toUpperCase()}`,
            tier_name: "ENTERPRISE_UNLIMITED",
            max_outlets: 10,
            max_terminals: 20,
            valid_from: /* @__PURE__ */ new Date(),
            valid_till: new Date(Date.now() + 365 * 24 * 60 * 60 * 1e3),
            warning_zone_days: 15,
            grace_period_days: 15,
            subscription_amount: 4999,
            tax_percentage: 18,
            payment_status: "PAID",
            is_perpetual: false,
            status: "ACTIVE"
          });
        }
        try {
          invalidateLicenseCache(code);
        } catch (_) {
        }
      }
      console.log(`\u2705 [MASTER_SYNC] Verified/synced ${dbOutlets.length} database outlets into Master Enterprise Control Plane.`);
    } catch (dbErr) {
      console.warn("\u26A0\uFE0F [MASTER_SYNC] Notice syncing database outlets:", dbErr.message);
    }
  } catch (err) {
    console.warn("\u26A0\uFE0F syncClientsJsonToMaster global notice:", err.message);
  }
}
const ensureMasterDatabaseSync = syncClientsJsonToMaster;
var masterSync_default = {
  syncClientsJsonToMaster,
  ensureMasterDatabaseSync
};
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  ensureMasterDatabaseSync,
  syncClientsJsonToMaster
});
