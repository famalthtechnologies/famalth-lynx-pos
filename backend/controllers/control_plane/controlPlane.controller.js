"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ControlPlaneController = void 0;
const sequelize_1 = require("sequelize");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const propertyDb_1 = __importDefault(require("../../db/propertyDb"));
const master_1 = __importDefault(require("../../models/master"));
const socketHub_service_1 = require("../../services/socketHub.service");
const emailService_1 = require("../../modules/emailService");
const subscriptionInvoicePdf_service_1 = require("../../services/subscriptionInvoicePdf.service");
const controlPlaneNotification_service_1 = __importDefault(require("../../services/controlPlaneNotification.service"));
const { invalidateLicenseCache } = require('../public/licenseManager');
const { ensureMasterDatabaseSync } = require('../../services/masterSync.service');
const { MasterTenant, MasterOutlet, MasterLicense, MasterReseller, MasterRelationshipManager, MasterStaffUser, SupportTicket, MasterInvoice, MasterAnnouncement, } = (0, master_1.default)(propertyDb_1.default);
class ControlPlaneController {
    /**
     * 1. High-Level Fleet Overview (Azure/OCI Executive Health Dashboard with Analytics)
     */
    static async getFleetOverview(req, res) {
        try {
            try {
                await ensureMasterDatabaseSync(propertyDb_1.default);
            } catch (syncErr) {
                console.warn('[CONTROL_PLANE] Database auto-sync warning:', syncErr.message);
            }
            const isResellerRole = req.masterStaff?.role === 'RESELLER_ADMIN' || req.masterStaff?.role === 'RESELLER';
            let resellerFilterId = null;
            if (isResellerRole) {
                resellerFilterId = req.masterStaff?.reseller_id;
                if (!resellerFilterId) {
                    const callerReseller = await MasterReseller.findOne({ where: { email: req.masterStaff?.email } });
                    if (callerReseller)
                        resellerFilterId = callerReseller.id;
                }
            }
            const tenantWhere = {};
            if (resellerFilterId) {
                tenantWhere.reseller_id = resellerFilterId;
            }
            const totalTenants = await MasterTenant.count({ where: tenantWhere });
            const activeTenants = await MasterTenant.count({ where: { ...tenantWhere, status: 'ACTIVE' } });
            const suspendedTenants = await MasterTenant.count({
                where: { ...tenantWhere, status: { [sequelize_1.Op.in]: ['SUSPENDED', 'DEACTIVATED'] } },
            });
            const totalOutlets = await MasterOutlet.count();
            const activeOutlets = await MasterOutlet.count({ where: { is_active: true, is_kill_switched: false } });
            const totalResellers = await MasterReseller.count({ where: { is_active: true } });
            const totalRMs = await MasterRelationshipManager.count({ where: { is_active: true } });
            const openTickets = await SupportTicket.count({ where: { status: { [sequelize_1.Op.in]: ['OPEN', 'ASSIGNED', 'IN_PROGRESS'] } } });
            // Licenses status
            const today = new Date();
            const fifteenDaysFromNow = new Date(Date.now() + 15 * 24 * 60 * 60 * 1000);
            const expiringLicenses = await MasterLicense.count({
                where: {
                    valid_till: {
                        [sequelize_1.Op.lte]: fifteenDaysFromNow,
                        [sequelize_1.Op.gte]: today,
                    },
                },
            });
            const expiredLicenses = await MasterLicense.count({
                where: {
                    valid_till: {
                        [sequelize_1.Op.lt]: today,
                    },
                },
            });
            // Financial & License Payment status
            const allLicenses = await MasterLicense.findAll({
                include: [{ model: MasterTenant, as: 'tenant', where: tenantWhere, required: true }],
            });
            let totalRevenue = 0;
            let paidCount = 0;
            let pendingCount = 0;
            let totalPendingAmount = 0;
            const renewalsThisMonthList = [];
            const currentYear = today.getFullYear();
            const currentMonth = today.getMonth();
            for (const lic of allLicenses) {
                const subtotal = Number(lic.subscription_amount || 4999.00);
                const taxRate = Number(lic.tax_percentage || 18.00);
                const total = subtotal + (subtotal * (taxRate / 100));
                totalRevenue += total;
                if (lic.payment_status === 'PENDING') {
                    pendingCount++;
                    totalPendingAmount += total;
                }
                else {
                    paidCount++;
                }
                if (lic.valid_till) {
                    const vDate = new Date(lic.valid_till);
                    if (vDate.getFullYear() === currentYear && vDate.getMonth() === currentMonth) {
                        renewalsThisMonthList.push({
                            tenantId: lic.tenant_id,
                            clientCode: lic.tenant?.client_code || '',
                            legalName: lic.tenant?.legal_name || 'Client',
                            validTill: lic.valid_till,
                            amount: total,
                            paymentStatus: lic.payment_status || 'PAID',
                        });
                    }
                }
            }
            // Month-on-Month Growth Trends (Past 6 Months)
            const growthTrends = [];
            const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            for (let i = 5; i >= 0; i--) {
                const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
                const nextD = new Date(today.getFullYear(), today.getMonth() - i + 1, 1);
                const label = `${monthNames[d.getMonth()]} ${d.getFullYear().toString().substring(2)}`;
                const newUsers = await MasterTenant.count({
                    where: {
                        ...tenantWhere,
                        created_at: { [sequelize_1.Op.gte]: d, [sequelize_1.Op.lt]: nextD },
                    },
                });
                const churnUsers = await MasterTenant.count({
                    where: {
                        ...tenantWhere,
                        status: { [sequelize_1.Op.in]: ['SUSPENDED', 'DEACTIVATED'] },
                        updated_at: { [sequelize_1.Op.gte]: d, [sequelize_1.Op.lt]: nextD },
                    },
                });
                growthTrends.push({
                    month: label,
                    newUsers: newUsers || (i === 0 ? totalTenants : 0),
                    churnUsers: churnUsers || 0,
                    activeTotal: activeTenants,
                });
            }
            return res.json({
                success: true,
                data: {
                    isResellerScope: isResellerRole,
                    tenants: { total: totalTenants, active: activeTenants, suspended: suspendedTenants },
                    outlets: { total: totalOutlets, active: activeOutlets },
                    resellers: totalResellers,
                    relationshipManagers: totalRMs,
                    supportTickets: { open: openTickets },
                    licenses: {
                        inWarningZone: expiringLicenses,
                        expired: expiredLicenses,
                        paidCount,
                        pendingCount,
                        totalPendingAmount,
                        totalRevenue,
                    },
                    renewalsThisMonth: {
                        count: renewalsThisMonthList.length,
                        list: renewalsThisMonthList,
                    },
                    growthTrends,
                    systemTime: new Date(),
                },
            });
        }
        catch (err) {
            console.error('getFleetOverview error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 2. List all Tenants with full outlet details, RM, Reseller, and License countdown
     */
    static async getAllTenants(req, res) {
        try {
            try {
                await ensureMasterDatabaseSync(propertyDb_1.default);
            } catch (_) {}
            const { search, status, reseller_id, rm_id } = req.query;
            const whereClause = {};
            if (status)
                whereClause.status = status;
            if (reseller_id)
                whereClause.reseller_id = reseller_id;
            if (rm_id)
                whereClause.rm_id = rm_id;
            // Auto-scope for RM operators: only show tenants assigned to this Relationship Manager
            if (req.masterStaff?.role === 'RM') {
                const callerRm = await MasterRelationshipManager.findOne({ where: { email: req.masterStaff.email } });
                if (callerRm) {
                    whereClause.rm_id = callerRm.id;
                }
            }
            // Auto-scope for Reseller / Seller operators: ONLY show clients sold / assigned to them
            if (req.masterStaff?.role === 'RESELLER_ADMIN' || req.masterStaff?.role === 'RESELLER') {
                let rId = req.masterStaff.reseller_id;
                if (!rId) {
                    const callerReseller = await MasterReseller.findOne({ where: { email: req.masterStaff.email } });
                    if (callerReseller)
                        rId = callerReseller.id;
                }
                if (rId) {
                    whereClause.reseller_id = rId;
                }
            }
            if (search) {
                whereClause[sequelize_1.Op.or] = [
                    { legal_name: { [sequelize_1.Op.iLike]: `%${search}%` } },
                    { client_code: { [sequelize_1.Op.iLike]: `%${search}%` } },
                    { contact_email: { [sequelize_1.Op.iLike]: `%${search}%` } },
                    { contact_phone: { [sequelize_1.Op.iLike]: `%${search}%` } },
                ];
            }
            const tenants = await MasterTenant.findAll({
                where: whereClause,
                include: [
                    { model: MasterOutlet, as: 'outlets' },
                    { model: MasterLicense, as: 'licenses' },
                    { model: MasterRelationshipManager, as: 'relationship_manager' },
                    { model: MasterReseller, as: 'reseller' },
                ],
                order: [['created_at', 'DESC']],
            });
            // Auto-generate invoice if within 10 days of renewal and enrich tenants
            const enrichedTenants = [];
            for (const t of tenants) {
                const plain = t.toJSON();
                const activeLicense = (plain.licenses || [])[0];
                let daysLeft = 0;
                let warningLevel = 'SAFE';
                if (activeLicense && activeLicense.valid_till) {
                    const diffMs = new Date(activeLicense.valid_till).getTime() - Date.now();
                    daysLeft = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
                    if (daysLeft < 0) {
                        warningLevel = 'EXPIRED';
                    }
                    else if (daysLeft <= 3) {
                        warningLevel = 'CRITICAL_RED';
                    }
                    else if (daysLeft <= (activeLicense.warning_zone_days || 15)) {
                        warningLevel = 'WARNING_AMBER';
                    }
                    // Auto-generate invoice if within 10 days of renewal
                    if (daysLeft <= 10) {
                        const vDate = new Date(activeLicense.valid_till);
                        const invoiceNumber = `INV-${plain.client_code}-${vDate.getFullYear()}${(vDate.getMonth() + 1).toString().padStart(2, '0')}`;
                        const existingInv = await MasterInvoice.findOne({ where: { invoice_number: invoiceNumber } });
                        if (!existingInv) {
                            const subtotal = Number(activeLicense.subscription_amount || 4999.00);
                            const taxRate = Number(activeLicense.tax_percentage || 18.00);
                            const taxAmount = Number((subtotal * (taxRate / 100)).toFixed(2));
                            const totalAmount = Number((subtotal + taxAmount).toFixed(2));
                            await MasterInvoice.create({
                                tenant_id: plain.id,
                                invoice_number: invoiceNumber,
                                billing_period_start: activeLicense.valid_from || plain.created_at,
                                billing_period_end: activeLicense.valid_till,
                                due_date: activeLicense.next_payment_date || activeLicense.valid_till,
                                subtotal,
                                tax_rate: taxRate,
                                tax_amount: taxAmount,
                                total_amount: totalAmount,
                                status: activeLicense.payment_status === 'PAID' ? 'PAID' : 'ISSUED',
                            });
                        }
                    }
                }
                const subtotal = Number(activeLicense?.subscription_amount || 4999.00);
                const taxRate = Number(activeLicense?.tax_percentage || 18.00);
                const taxAmount = Number((subtotal * (taxRate / 100)).toFixed(2));
                const totalAmount = Number((subtotal + taxAmount).toFixed(2));
                const gracePeriodDays = Number(activeLicense?.grace_period_days || activeLicense?.warning_zone_days || 15);
                const softwareStartDate = activeLicense?.valid_from || plain.created_at;
                const licenseEndDate = activeLicense?.valid_till || null;
                let nextPaymentDate = null;
                if (licenseEndDate) {
                    const vDt = new Date(licenseEndDate);
                    nextPaymentDate = new Date(vDt.getTime() - 10 * 86400000).toISOString();
                }
                else if (activeLicense?.next_payment_date) {
                    nextPaymentDate = new Date(activeLicense.next_payment_date).toISOString();
                }
                const paymentStatus = activeLicense?.payment_status || 'PAID';
                const outletPings = (plain.outlets || []).map((o) => (o.last_ping_at ? new Date(o.last_ping_at).getTime() : 0));
                const maxPing = Math.max(0, ...outletPings);
                const lastActivity = maxPing > 0 ? new Date(maxPing).toISOString() : (plain.updated_at || plain.created_at || null);
                const meta = plain.custom_metadata || {};
                const currency = meta.currency || (meta.country === 'USA' ? 'USD' : 'INR');
                const taxName = meta.tax_name || (currency === 'USD' ? 'Sales Tax' : currency === 'INR' ? 'GST' : 'VAT');
                const country = meta.country || (currency === 'USD' ? 'United States' : currency === 'INR' ? 'India' : 'International');
                const realStorageBytes = meta.storage_used_bytes || plain.storage_used_bytes || null;
                const realBandwidthBytes = meta.bandwidth_used_bytes || plain.bandwidth_used_bytes || null;
                enrichedTenants.push({
                    ...plain,
                    currency,
                    tax_name: taxName,
                    country,
                    software_start_date: softwareStartDate,
                    license_end_date: licenseEndDate,
                    grace_period_days: gracePeriodDays,
                    subscription_amount: subtotal,
                    tax_percentage: taxRate,
                    total_payment_amount: totalAmount,
                    next_payment_date: nextPaymentDate,
                    payment_status: paymentStatus,
                    last_activity: lastActivity,
                    billing_address: meta.billing_address || meta.address || plain.billing_address || null,
                    storage_used_bytes: realStorageBytes,
                    bandwidth_used_bytes: realBandwidthBytes,
                    licenseMetrics: {
                        daysLeft,
                        warningLevel,
                        softwareStartDate,
                        validTill: licenseEndDate,
                        gracePeriodDays,
                        nextPaymentDate,
                        subtotal,
                        taxRate,
                        taxAmount,
                        totalAmount,
                        paymentStatus,
                        lastActivity,
                        currency,
                        taxName,
                        country,
                        storageMb: realStorageBytes ? Math.round(realStorageBytes / (1024 * 1024)) : null,
                        bandwidthMb: realBandwidthBytes ? Math.round(realBandwidthBytes / (1024 * 1024)) : null,
                        tierName: activeLicense?.tier_name || 'BASIC',
                        maxOutlets: activeLicense?.max_outlets || 1,
                        maxTerminals: activeLicense?.max_terminals || 1,
                    },
                });
            }
            return res.json({ success: true, count: enrichedTenants.length, data: enrichedTenants });
        }
        catch (err) {
            console.error('getAllTenants error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 3. Toggle Client / Tenant Status (Remote Kill-Switch / Suspend / Activate)
     */
    static async updateTenantStatus(req, res) {
        try {
            const id = String(req.params.id);
            const { status, reason } = req.body; // 'ACTIVE', 'SUSPENDED', 'DEACTIVATED', 'MAINTENANCE'
            const tenant = await MasterTenant.findByPk(id);
            if (!tenant) {
                return res.status(404).json({ success: false, message: 'Tenant not found.' });
            }
            const previousStatus = tenant.status;
            tenant.status = status;
            await tenant.save();
            // If suspended or deactivated, set kill-switch on all child outlets
            const isKillSwitched = status === 'SUSPENDED' || status === 'DEACTIVATED';
            await MasterOutlet.update({
                is_active: status === 'ACTIVE',
                is_kill_switched: isKillSwitched,
                kill_switch_reason: reason || `Status set to ${status} by Control Plane.`,
            }, { where: { tenant_id: tenant.id } });
            // Broadcast remote kill switch in real-time to all connected POS clients
            (0, socketHub_service_1.broadcastRemoteKillSwitch)({
                tenantId: tenant.id,
                status,
                reason: reason || `Administrative update: ${status}`,
            });
            // Dispatch security / access notice email to registered email only if status actually changed
            if (previousStatus !== status) {
                controlPlaneNotification_service_1.default.notifyKillSwitchToggled(
                    tenant,
                    tenant.legal_name,
                    isKillSwitched,
                    reason || `Tenant status updated to ${status}.`
                ).catch((err) => console.error('[ASYNC NOTIFY KILL-SWITCH ERROR]', err.message));
            }
            return res.json({
                success: true,
                message: `Tenant ${tenant.legal_name} status updated to ${status}.`,
                data: tenant,
            });
        }
        catch (err) {
            console.error('updateTenantStatus error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 4. Granular Outlet-Wise Kill-Switch & Remote Lock
     */
    static async updateOutletStatus(req, res) {
        try {
            const outletId = Number(req.params.outletId);
            const { is_active, is_kill_switched, reason } = req.body;
            const outlet = await MasterOutlet.findByPk(outletId);
            if (!outlet) {
                return res.status(404).json({ success: false, message: 'Outlet not found.' });
            }
            if (typeof is_active === 'boolean')
                outlet.is_active = is_active;
            if (typeof is_kill_switched === 'boolean')
                outlet.is_kill_switched = is_kill_switched;
            if (reason)
                outlet.kill_switch_reason = reason;
            await outlet.save();
            // Broadcast to specific outlet socket room
            (0, socketHub_service_1.broadcastRemoteKillSwitch)({
                outletId: outlet.id,
                status: outlet.is_kill_switched ? 'KILL_SWITCHED' : (outlet.is_active ? 'ACTIVE' : 'INACTIVE'),
                reason: reason || 'Administrative action applied to outlet.',
            });
            // Dispatch security / access notice email to registered client
            MasterTenant.findByPk(outlet.tenant_id).then((tenant) => {
                if (tenant) {
                    controlPlaneNotification_service_1.default.notifyKillSwitchToggled(
                        tenant,
                        outlet.outlet_name,
                        Boolean(outlet.is_kill_switched),
                        outlet.kill_switch_reason || reason || 'Outlet status updated.'
                    ).catch((err) => console.error('[ASYNC NOTIFY OUTLET KILL-SWITCH ERROR]', err.message));
                }
            }).catch((e) => console.error('[FIND TENANT FOR OUTLET KILL-SWITCH ERROR]', e.message));
            return res.json({
                success: true,
                message: `Outlet ${outlet.outlet_name} updated successfully.`,
                data: outlet,
            });
        }
        catch (err) {
            console.error('updateOutletStatus error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 5. Dynamic License Quota Management (Increase Seats, Outlets, Validity)
     */
    static async modifyLicenseQuota(req, res) {
        try {
            const tenantId = String(req.params.tenantId);
            const { max_terminals, max_outlets, valid_till, extend_days, tier_name, warning_zone_days, grace_period_days, subscription_amount, tax_percentage, next_payment_date, payment_status, currency, tax_name, country, } = req.body;
            const tenant = await MasterTenant.findByPk(tenantId, {
                include: [{ model: MasterLicense, as: 'licenses' }],
            });
            if (!tenant) {
                return res.status(404).json({ success: false, message: 'Client record not found.' });
            }
            let license = (tenant.licenses && tenant.licenses[0]) || await MasterLicense.findOne({ where: { tenant_id: tenantId } });
            const curExpiry = license?.valid_till
                ? new Date(license.valid_till)
                : (tenant.license_end_date ? new Date(tenant.license_end_date) : new Date());
            const baseTime = curExpiry.getTime() > Date.now() ? curExpiry.getTime() : Date.now();
            let targetValidTill = null;
            if (extend_days !== undefined && Number(extend_days) > 0) {
                const days = Number(extend_days);
                if (days > 30) {
                    return res.status(400).json({
                        success: false,
                        message: 'Maximum allowable extension is 30 days from current expiry.',
                    });
                }
                targetValidTill = new Date(baseTime + days * 86400000);
            }
            else if (valid_till) {
                const parsed = new Date(valid_till);
                // Expiry can be extended up to max 30 days from baseTime (allow 12 hour margin for timezone offsets)
                const maxAllowed = new Date(baseTime + 30.5 * 86400000);
                if (parsed.getTime() > maxAllowed.getTime()) {
                    const maxDateStr = new Date(baseTime + 30 * 86400000).toISOString().split('T')[0];
                    return res.status(400).json({
                        success: false,
                        message: `Maximum allowable extension is 30 days from current expiry. Target date cannot exceed ${maxDateStr}.`,
                    });
                }
                targetValidTill = parsed;
            }
            // Due date and renew date: exactly 10 days before expiry date
            let autoDueDate = null;
            if (targetValidTill) {
                autoDueDate = new Date(targetValidTill.getTime() - 10 * 86400000);
            }
            else if (next_payment_date) {
                autoDueDate = new Date(next_payment_date);
            }
            if (!license) {
                license = await MasterLicense.create({
                    tenant_id: tenantId,
                    license_key: `LIC-${Date.now().toString(36).toUpperCase()}`,
                    tier_name: tier_name || 'ENTERPRISE',
                    max_outlets: max_outlets || 1,
                    max_terminals: max_terminals || 3,
                    valid_from: new Date(),
                    valid_till: targetValidTill || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
                    warning_zone_days: warning_zone_days || grace_period_days || 15,
                    grace_period_days: grace_period_days || warning_zone_days || 15,
                    subscription_amount: subscription_amount || 4999.00,
                    tax_percentage: tax_percentage || 18.00,
                    next_payment_date: autoDueDate,
                    payment_status: payment_status || 'PAID',
                    status: 'ACTIVE',
                });
            }
            else {
                if (max_terminals !== undefined)
                    license.max_terminals = max_terminals;
                if (max_outlets !== undefined)
                    license.max_outlets = max_outlets;
                if (targetValidTill) {
                    license.valid_till = targetValidTill;
                    license.next_payment_date = autoDueDate;
                }
                else if (next_payment_date !== undefined) {
                    license.next_payment_date = next_payment_date ? new Date(next_payment_date) : null;
                }
                if (tier_name)
                    license.tier_name = tier_name;
                if (warning_zone_days !== undefined)
                    license.warning_zone_days = warning_zone_days;
                if (grace_period_days !== undefined) {
                    license.grace_period_days = grace_period_days;
                    license.warning_zone_days = grace_period_days;
                }
                if (subscription_amount !== undefined)
                    license.subscription_amount = subscription_amount;
                if (tax_percentage !== undefined)
                    license.tax_percentage = tax_percentage;
                if (payment_status !== undefined)
                    license.payment_status = payment_status;
                license.status = 'ACTIVE';
                await license.save();
            }
            // Also update tenant license_end_date and metadata
            if (targetValidTill) {
                tenant.license_end_date = targetValidTill;
            }
            if (currency || tax_name || country) {
                const meta = tenant.custom_metadata || {};
                if (currency)
                    meta.currency = currency;
                if (tax_name)
                    meta.tax_name = tax_name;
                if (country)
                    meta.country = country;
                tenant.custom_metadata = meta;
            }
            await tenant.save();
            // Update latest invoice due_date and billing_period_end
            if (targetValidTill) {
                const latestInv = await MasterInvoice.findOne({
                    where: { tenant_id: tenantId },
                    order: [['created_at', 'DESC']],
                });
                if (latestInv) {
                    latestInv.billing_period_end = targetValidTill;
                    if (autoDueDate)
                        latestInv.due_date = autoDueDate;
                    await latestInv.save();
                }
            }
            // Invalidate license cache so client queries get latest validity immediately
            invalidateLicenseCache(tenant.client_code);
            invalidateLicenseCache();
            // Broadcast quota expansion to client POS terminals in real time
            (0, socketHub_service_1.broadcastQuotaUpdated)(tenantId, license);

            // On Extend Expiry or Customer Payment: Dispatch email notification to registered client
            if (targetValidTill) {
                const daysExtended = Math.ceil((targetValidTill.getTime() - baseTime) / 86400000);
                if (daysExtended > 0) {
                    if (payment_status === 'PAID') {
                        MasterInvoice.findOne({
                            where: { tenant_id: tenantId },
                            order: [['created_at', 'DESC']],
                        }).then((latestInv) => {
                            controlPlaneNotification_service_1.default.notifyPaymentReceivedAndLicenseExtended(
                                tenant,
                                license,
                                subscription_amount || license.subscription_amount,
                                daysExtended,
                                targetValidTill,
                                latestInv
                            ).catch((err) => console.error('[ASYNC NOTIFY PAYMENT EXTEND ERROR]', err.message));
                        }).catch((err) => console.error('[FIND INVOICE ERROR]', err.message));
                    } else {
                        controlPlaneNotification_service_1.default.notifyLicenseExpiryExtended(
                            tenant,
                            license,
                            daysExtended,
                            targetValidTill
                        ).catch((err) => console.error('[ASYNC NOTIFY EXTEND ERROR]', err.message));
                    }
                }
            }

            // On New Licenses Pricing / Quota Update: Dispatch email notification to registered client
            if (
                subscription_amount !== undefined ||
                tax_percentage !== undefined ||
                max_terminals !== undefined ||
                max_outlets !== undefined ||
                tier_name !== undefined
            ) {
                controlPlaneNotification_service_1.default.notifyLicensePricingUpdated(tenant, license).catch((err) =>
                    console.error('[ASYNC NOTIFY PRICING ERROR]', err.message)
                );
            }

            const daysLeft = targetValidTill
                ? Math.ceil((targetValidTill.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
                : 0;
            return res.json({
                success: true,
                message: 'License quota & subscription terms updated successfully.',
                data: license,
                valid_till: targetValidTill,
                next_payment_date: autoDueDate,
                daysLeft,
            });
        }
        catch (err) {
            console.error('modifyLicenseQuota error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 5b. Bulk Adjust Subscription Pricing (Amount Increase) - Does NOT extend licenses unless explicitly requested
     */
    static async bulkExtendSubscriptions(req, res) {
        try {
            const { tenant_ids, extend_days = 0, extend_validity = false, subscription_amount, amount_adjustment, amount_mode = 'SET_FIXED', // 'SET_FIXED', 'ADD_FIXED', 'PERCENT_INCREASE'
            tax_percentage, currency, tax_name, country, } = req.body;
            const whereClause = {};
            if (tenant_ids && tenant_ids !== 'ALL' && Array.isArray(tenant_ids) && tenant_ids.length > 0) {
                whereClause.tenant_id = { [sequelize_1.Op.in]: tenant_ids };
            }
            const licenses = await MasterLicense.findAll({ where: whereClause });
            for (const lic of licenses) {
                // ONLY extend license validity days if extend_validity is explicitly true and extend_days > 0
                if (extend_validity === true && Number(extend_days) > 0) {
                    const curDate = lic.valid_till ? new Date(lic.valid_till) : new Date();
                    const baseTime = curDate.getTime() > Date.now() ? curDate.getTime() : Date.now();
                    lic.valid_till = new Date(baseTime + Number(extend_days) * 86400000);
                    lic.next_payment_date = lic.valid_till;
                    lic.payment_status = 'PAID';
                }
                // Adjust subscription amount
                if (amount_mode === 'ADD_FIXED' && amount_adjustment !== undefined && amount_adjustment !== null) {
                    const curAmt = Number(lic.subscription_amount || 0);
                    lic.subscription_amount = Math.max(0, curAmt + Number(amount_adjustment));
                }
                else if (amount_mode === 'PERCENT_INCREASE' && amount_adjustment !== undefined && amount_adjustment !== null) {
                    const curAmt = Number(lic.subscription_amount || 0);
                    lic.subscription_amount = Math.round(curAmt * (1 + Number(amount_adjustment) / 100));
                }
                else if (subscription_amount !== undefined && subscription_amount !== null && String(subscription_amount).trim() !== '') {
                    lic.subscription_amount = Number(subscription_amount);
                }
                if (tax_percentage !== undefined && tax_percentage !== null && String(tax_percentage).trim() !== '') {
                    lic.tax_percentage = Number(tax_percentage);
                }
                lic.status = 'ACTIVE';
                await lic.save();
                if (currency || tax_name || country) {
                    const tenant = await MasterTenant.findByPk(lic.tenant_id);
                    if (tenant) {
                        const meta = tenant.custom_metadata || {};
                        if (currency)
                            meta.currency = currency;
                        if (tax_name)
                            meta.tax_name = tax_name;
                        if (country)
                            meta.country = country;
                        tenant.custom_metadata = meta;
                        await tenant.save();
                    }
                }
                (0, socketHub_service_1.broadcastQuotaUpdated)(lic.tenant_id, lic);

                // Async notifications on extend expiry or new pricing
                MasterTenant.findByPk(lic.tenant_id).then((t) => {
                    if (t) {
                        if (extend_validity === true && Number(extend_days) > 0) {
                            controlPlaneNotification_service_1.default.notifyLicenseExpiryExtended(
                                t,
                                lic,
                                Number(extend_days),
                                lic.valid_till
                            ).catch((e) => console.error('[ASYNC NOTIFY BULK EXTEND ERROR]', e.message));
                        }
                        if (subscription_amount !== undefined || amount_adjustment !== undefined || tax_percentage !== undefined) {
                            controlPlaneNotification_service_1.default.notifyLicensePricingUpdated(t, lic).catch((e) =>
                                console.error('[ASYNC NOTIFY BULK PRICING ERROR]', e.message)
                            );
                        }
                    }
                }).catch((e) => console.error('[FIND TENANT FOR BULK EXTEND ERROR]', e.message));
            }
            const daysMsg = (extend_validity === true && Number(extend_days) > 0) ? ` and extended validity by ${extend_days} days` : ' (license validity duration preserved)';
            invalidateLicenseCache();
            return res.json({
                success: true,
                message: `Successfully updated subscription pricing for ${licenses.length} client(s)${daysMsg}.`,
                updatedCount: licenses.length,
            });
        }
        catch (err) {
            console.error('bulkExtendSubscriptions error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 5c. Approve Payment & Auto-Extend License
     */
    static async approvePaymentAndExtend(req, res) {
        try {
            const tenantId = String(req.params.tenantId);
            const { amount, extend_days = 365 } = req.body;
            const license = await MasterLicense.findOne({ where: { tenant_id: tenantId } });
            if (!license) {
                return res.status(404).json({ success: false, message: 'License record not found.' });
            }
            const curDate = license.valid_till ? new Date(license.valid_till) : new Date();
            const baseTime = curDate.getTime() > Date.now() ? curDate.getTime() : Date.now();
            license.valid_till = new Date(baseTime + extend_days * 86400000);
            license.next_payment_date = license.valid_till;
            license.payment_status = 'PAID';
            license.last_payment_date = new Date();
            license.status = 'ACTIVE';
            await license.save();
            // Mark any open invoices as PAID
            await MasterInvoice.update({ status: 'PAID', paid_at: new Date() }, { where: { tenant_id: tenantId, status: { [sequelize_1.Op.ne]: 'PAID' } } });
            // Invalidate license cache so client software immediately sees renewed license
            invalidateLicenseCache();
            (0, socketHub_service_1.broadcastQuotaUpdated)(tenantId, license);

            // Notify client of payment receipt & license extension
            MasterTenant.findByPk(tenantId).then(async (t) => {
                if (t) {
                    const latestInv = await MasterInvoice.findOne({
                        where: { tenant_id: tenantId },
                        order: [['created_at', 'DESC']],
                    });
                    controlPlaneNotification_service_1.default.notifyPaymentReceivedAndLicenseExtended(
                        t,
                        license,
                        amount || license.subscription_amount,
                        extend_days,
                        license.valid_till,
                        latestInv
                    ).catch((e) => console.error('[ASYNC NOTIFY APPROVE PAYMENT ERROR]', e.message));
                }
            }).catch((e) => console.error('[FIND TENANT ERROR]', e.message));

            return res.json({
                success: true,
                message: `Payment of ₹${amount || license.subscription_amount} approved. License auto-extended to ${new Date(license.valid_till).toLocaleDateString()}.`,
                data: license,
            });
        }
        catch (err) {
            console.error('approvePaymentAndExtend error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 5d. Download Subscription Tax Invoice PDF
     */
    static async downloadInvoicePdf(req, res) {
        try {
            const { invoiceId, tenantId } = req.params;
            let invoice = null;
            let tenant = null;
            if (invoiceId) {
                invoice = await MasterInvoice.findByPk(String(invoiceId), {
                    include: [{ model: MasterTenant, as: 'tenant', include: [{ model: MasterLicense, as: 'licenses' }] }],
                });
                if (invoice)
                    tenant = invoice.tenant;
            }
            else if (tenantId) {
                tenant = await MasterTenant.findByPk(String(tenantId), {
                    include: [{ model: MasterLicense, as: 'licenses' }],
                });
                if (tenant) {
                    invoice = await MasterInvoice.findOne({
                        where: { tenant_id: String(tenantId) },
                        order: [['created_at', 'DESC']],
                    });
                }
            }
            if (!tenant) {
                return res.status(404).json({ success: false, message: 'Client record not found.' });
            }
            const activeLicense = (tenant.licenses || [])[0] || {};
            const meta = tenant.custom_metadata || {};
            const queryCurrency = req.query.currency ? String(req.query.currency).toUpperCase() : null;
            const currency = queryCurrency || meta.currency || (meta.country === 'USA' ? 'USD' : 'INR');
            const queryTaxName = req.query.tax_name ? String(req.query.tax_name) : null;
            const taxName = queryTaxName || meta.tax_name || (currency === 'USD' ? 'Sales Tax' : currency === 'INR' ? 'GST' : 'VAT');
            const queryCountry = req.query.country ? String(req.query.country) : null;
            const country = queryCountry || meta.country || (currency === 'USD' ? 'United States' : currency === 'INR' ? 'India' : 'International');
            const subtotal = Number(invoice ? invoice.subtotal : (activeLicense.subscription_amount || 4999.00));
            const taxRate = Number(invoice ? invoice.tax_rate : (activeLicense.tax_percentage || (currency === 'USD' ? 8.25 : 18.00)));
            const taxAmount = Number(invoice ? invoice.tax_amount : (subtotal * (taxRate / 100)));
            const totalAmount = Number(invoice ? invoice.total_amount : (subtotal + taxAmount));
            const invoiceNumber = invoice ? invoice.invoice_number : `INV-${tenant.client_code}-${Date.now().toString(36).toUpperCase()}`;
            const pdfBuffer = await (0, subscriptionInvoicePdf_service_1.generateSubscriptionInvoicePdf)({
                invoiceNumber,
                issueDate: invoice ? invoice.billing_period_start : (activeLicense.valid_from || new Date()),
                dueDate: invoice ? invoice.due_date : (activeLicense.next_payment_date || activeLicense.valid_till || new Date()),
                paymentStatus: (invoice?.status === 'PAID' || activeLicense.payment_status === 'PAID') ? 'PAID' : 'PENDING',
                paidAt: invoice?.paid_at,
                tenant: {
                    clientCode: tenant.client_code,
                    legalName: tenant.legal_name,
                    tradeName: tenant.trade_name,
                    contactEmail: tenant.contact_email,
                    contactPhone: tenant.contact_phone,
                    taxIdentifier: tenant.tax_identifier,
                    country,
                },
                license: {
                    tierName: activeLicense.tier_name || 'PROFESSIONAL',
                    maxTerminals: activeLicense.max_terminals || 3,
                    maxOutlets: activeLicense.max_outlets || 1,
                    validFrom: activeLicense.valid_from || new Date(),
                    validTill: activeLicense.valid_till || new Date(Date.now() + 365 * 86400000),
                    gracePeriodDays: activeLicense.grace_period_days || 15,
                },
                pricing: {
                    subtotal,
                    taxRate,
                    taxAmount,
                    totalAmount,
                    currency,
                    taxName,
                    country,
                },
            });
            res.setHeader('Content-Type', 'application/pdf');
            res.setHeader('Content-Disposition', `attachment; filename="${invoiceNumber}.pdf"`);
            res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
            res.setHeader('Pragma', 'no-cache');
            res.setHeader('Expires', '0');
            return res.send(pdfBuffer);
        }
        catch (err) {
            console.error('downloadInvoicePdf error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 5e. Export Renewals File (CSV) for This Month, Next Month, or All
     */
    static async exportRenewalsCsv(req, res) {
        try {
            const filter = String(req.query.filter || 'all').toLowerCase();
            const tenants = await MasterTenant.findAll({
                include: [
                    { model: MasterLicense, as: 'licenses' },
                    { model: MasterRelationshipManager, as: 'relationship_manager' }
                ],
                order: [['legal_name', 'ASC']]
            });
            const now = new Date();
            const currentYear = now.getFullYear();
            const currentMonth = now.getMonth();
            const nextMonthYear = currentMonth === 11 ? currentYear + 1 : currentYear;
            const nextMonth = currentMonth === 11 ? 0 : currentMonth + 1;
            const filtered = tenants.filter(t => {
                const lic = (t.licenses || [])[0];
                if (!lic)
                    return filter === 'all';
                const d = lic.next_payment_date ? new Date(lic.next_payment_date) : (lic.valid_till ? new Date(lic.valid_till) : null);
                if (!d || isNaN(d.getTime()))
                    return filter === 'all';
                if (filter === 'this_month') {
                    return d.getFullYear() === currentYear && d.getMonth() === currentMonth;
                }
                else if (filter === 'next_month') {
                    return d.getFullYear() === nextMonthYear && d.getMonth() === nextMonth;
                }
                return true;
            });
            const rows = [
                [
                    'Client Code',
                    'Business Legal Name',
                    'Email',
                    'Phone',
                    'Tax Identifier',
                    'Country',
                    'Currency',
                    'Tier',
                    'Max Outlets',
                    'Max Terminals',
                    'Start Date',
                    'Renewal Expiry Date',
                    'Next Payment Date',
                    'Grace Days',
                    'Subscription Amount',
                    'Tax Name',
                    'Tax Rate (%)',
                    'Total Amount Due',
                    'Payment Status',
                    'Relationship Manager'
                ].join(',')
            ];
            const escapeCsv = (str) => {
                if (str === null || str === undefined)
                    return '""';
                const s = String(str).replace(/"/g, '""');
                return `"${s}"`;
            };
            for (const t of filtered) {
                const plain = t.toJSON ? t.toJSON() : t;
                const lic = (plain.licenses || [])[0] || {};
                const meta = plain.custom_metadata || {};
                const currency = meta.currency || (meta.country === 'USA' ? 'USD' : 'INR');
                const taxName = meta.tax_name || (currency === 'USD' ? 'Sales Tax' : currency === 'INR' ? 'GST' : 'VAT');
                const country = meta.country || (currency === 'USD' ? 'United States' : currency === 'INR' ? 'India' : 'Global');
                const subtotal = Number(lic.subscription_amount || 4999.00);
                const taxRate = Number(lic.tax_percentage || 18.00);
                const total = (subtotal * (1 + taxRate / 100)).toFixed(2);
                const rmName = plain.relationship_manager?.full_name || plain.relationship_manager?.name || 'Unassigned';
                rows.push([
                    escapeCsv(plain.client_code),
                    escapeCsv(plain.legal_name),
                    escapeCsv(plain.contact_email),
                    escapeCsv(plain.contact_phone),
                    escapeCsv(plain.tax_identifier),
                    escapeCsv(country),
                    escapeCsv(currency),
                    escapeCsv(lic.tier_name || 'PROFESSIONAL'),
                    escapeCsv(lic.max_outlets || 1),
                    escapeCsv(lic.max_terminals || 3),
                    escapeCsv(lic.valid_from || plain.created_at),
                    escapeCsv(lic.valid_till || ''),
                    escapeCsv(lic.next_payment_date || lic.valid_till || ''),
                    escapeCsv(lic.grace_period_days || 15),
                    escapeCsv(subtotal.toFixed(2)),
                    escapeCsv(taxName),
                    escapeCsv(taxRate.toFixed(2)),
                    escapeCsv(total),
                    escapeCsv(lic.payment_status || 'PAID'),
                    escapeCsv(rmName)
                ].join(','));
            }
            const csvContent = rows.join('\r\n');
            const dateTag = now.toISOString().split('T')[0];
            const filename = `Famalth_Renewals_${filter}_${dateTag}.csv`;
            res.setHeader('Content-Type', 'text/csv; charset=utf-8');
            res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
            return res.send(csvContent);
        }
        catch (err) {
            console.error('exportRenewalsCsv error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 5e. Get Latest Invoice for Tenant
     */
    static async getLatestInvoice(req, res) {
        try {
            const tenantId = String(req.params.tenantId);
            const invoice = await MasterInvoice.findOne({
                where: { tenant_id: tenantId },
                order: [['created_at', 'DESC']],
            });
            return res.json({ success: true, data: invoice });
        }
        catch (err) {
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 5f. Announcements & Offers Management
     */
    static async createAnnouncement(req, res) {
        try {
            const { target_tenant_id, title, message, action_link, action_url, action_label, badge_text, type, discount_code } = req.body;
            if (!title || !message) {
                return res.status(400).json({ success: false, message: 'Title and message are required.' });
            }
            try { await MasterAnnouncement.sync({ alter: true }); } catch (_) {}
            const announcement = await MasterAnnouncement.create({
                target_tenant_id: target_tenant_id || null,
                title,
                message,
                action_link: action_link || action_url || null,
                action_label: action_label || 'Learn More',
                badge_text: badge_text || type || 'Special Offer',
                discount_code: discount_code || null,
                is_active: true,
            });
            return res.json({ success: true, message: 'Announcement / Offer published successfully.', data: announcement });
        }
        catch (err) {
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    static async getActiveAnnouncements(req, res) {
        try {
            try { await MasterAnnouncement.sync({ alter: true }); } catch (_) {}
            const { tenantId } = req.query;
            const whereClause = { is_active: true };
            if (tenantId) {
                whereClause[sequelize_1.Op.or] = [{ target_tenant_id: null }, { target_tenant_id: tenantId }];
            }
            const announcements = await MasterAnnouncement.findAll({
                where: whereClause,
                order: [['created_at', 'DESC']],
                limit: 10,
            });
            const mapped = announcements.map(a => {
                const p = a.toJSON ? a.toJSON() : a;
                return {
                    ...p,
                    action_url: p.action_link,
                    type: p.badge_text || 'OFFER',
                };
            });
            return res.json({ success: true, count: mapped.length, data: mapped });
        }
        catch (err) {
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 6. Real-World Dynamic Property Self-Registration Handshake (from POS terminal)
     */
    static async registerDynamicProperty(req, res) {
        try {
            const { property_name, legal_name, outlet_name, contact_email, contact_phone, tax_id, machine_id, local_ip, outlet_type, pin, } = req.body;
            if (!property_name || !contact_email) {
                return res.status(400).json({
                    success: false,
                    message: 'Property Name and Contact Email are mandatory for registration.',
                });
            }
            // Find default RM
            const defaultRm = await MasterRelationshipManager.findOne({ where: { is_active: true } });
            const clientCode = `CLI-${Date.now().toString(36).toUpperCase()}`;
            const outletCode = `OUT-${Date.now().toString(36).toUpperCase()}`;
            // Create Tenant
            const tenant = await MasterTenant.create({
                client_code: clientCode,
                legal_name: legal_name || property_name,
                trade_name: property_name,
                tax_identifier: tax_id || '',
                contact_email,
                contact_phone: contact_phone || '',
                rm_id: defaultRm?.id || null,
                status: 'ACTIVE',
                pin_hash: pin || null,
                custom_metadata: { machine_id, registered_via: 'DYNAMIC_POS_HANDSHAKE' },
            });
            // Create Outlet
            const outlet = await MasterOutlet.create({
                tenant_id: tenant.id,
                outlet_code: outletCode,
                outlet_name: outlet_name || `${property_name} Main`,
                outlet_type: outlet_type || 'RETAIL',
                hardware_machine_id: machine_id || '',
                ip_address: local_ip || '',
                is_active: true,
                last_ping_at: new Date(),
            });
            // Create 30-Day Evaluation License
            const license = await MasterLicense.create({
                tenant_id: tenant.id,
                license_key: `LIC-${clientCode}-${outletCode.substring(4)}`,
                tier_name: 'PROFESSIONAL',
                max_outlets: 1,
                max_terminals: 3,
                valid_from: new Date(),
                valid_till: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30-day evaluation
                warning_zone_days: 15,
                status: 'ACTIVE',
            });
            return res.status(201).json({
                success: true,
                message: 'Property registered successfully in Central Master Plane.',
                data: {
                    tenant_id: tenant.id,
                    client_code: tenant.client_code,
                    outlet_id: outlet.id,
                    outlet_code: outlet.outlet_code,
                    license_key: license.license_key,
                    valid_till: license.valid_till,
                    relationship_manager: defaultRm,
                },
            });
        }
        catch (err) {
            console.error('registerDynamicProperty error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 7. Assign Relationship Manager to Client
     */
    static async assignRelationshipManager(req, res) {
        try {
            const tenantId = String(req.params.tenantId);
            const { rm_id } = req.body;
            const tenant = await MasterTenant.findByPk(tenantId);
            if (!tenant) {
                return res.status(404).json({ success: false, message: 'Tenant not found.' });
            }
            const rm = await MasterRelationshipManager.findByPk(String(rm_id));
            if (!rm) {
                return res.status(404).json({ success: false, message: 'Relationship Manager not found.' });
            }
            const previousRmId = tenant.rm_id;
            tenant.rm_id = rm.id;
            await tenant.save();

            // On Assign RM: Dispatch introductory email to registered client only if RM actually changed
            if (previousRmId !== rm.id) {
                controlPlaneNotification_service_1.default.notifyRelationshipManagerAssigned(tenant, rm).catch((err) =>
                    console.error('[ASYNC NOTIFY RM ASSIGNED ERROR]', err.message)
                );
            }

            return res.json({
                success: true,
                message: `Assigned RM ${rm.full_name} to ${tenant.legal_name}.`,
                data: { tenant, relationship_manager: rm },
            });
        }
        catch (err) {
            console.error('assignRelationshipManager error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 8. List all Relationship Managers
     */
    static async getRelationshipManagers(req, res) {
        try {
            const rms = await MasterRelationshipManager.findAll({
                include: [{ model: MasterTenant, as: 'tenants', attributes: ['id', 'legal_name', 'client_code'] }],
            });
            return res.json({ success: true, data: rms });
        }
        catch (err) {
            console.error('getRelationshipManagers error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 9. Create New Relationship Manager (Includes Control Plane Operator Account Creation)
     */
    static async createRelationshipManager(req, res) {
        try {
            const { full_name, email, phone, whatsapp_number, designation, avatar_url, password } = req.body;
            if (!full_name || !email || !phone) {
                return res.status(400).json({ success: false, message: 'Full name, official email, and phone number are required.' });
            }
            const cleanEmail = String(email).trim().toLowerCase();
            if (!cleanEmail.includes('@')) {
                return res.status(400).json({ success: false, message: 'Please provide a valid email address.' });
            }
            // 1. Create or update Relationship Manager entry
            const rmCode = `RM-${Date.now().toString(36).toUpperCase()}`;
            let rm = await MasterRelationshipManager.findOne({ where: { email: cleanEmail } });
            if (rm) {
                await rm.update({
                    full_name,
                    phone,
                    whatsapp_number: whatsapp_number || phone,
                    designation: designation || 'Senior Account Specialist',
                    avatar_url: avatar_url || '',
                    is_active: true,
                });
            }
            else {
                rm = await MasterRelationshipManager.create({
                    rm_code: rmCode,
                    full_name,
                    email: cleanEmail,
                    phone,
                    whatsapp_number: whatsapp_number || phone,
                    designation: designation || 'Senior Account Specialist',
                    avatar_url: avatar_url || '',
                    is_active: true,
                });
            }
            // 2. Provision / link Master Staff Operator Login with role = 'RM'
            const loginPassword = (password && String(password).trim().length >= 6)
                ? String(password).trim()
                : Math.random().toString(36).slice(-8) + 'Aa1!';
            const salt = await bcryptjs_1.default.genSalt(10);
            const password_hash = await bcryptjs_1.default.hash(loginPassword, salt);
            let staffUser = await MasterStaffUser.findOne({ where: { email: cleanEmail } });
            const baseUsername = cleanEmail.split('@')[0].replace(/[^a-zA-Z0-9_]/g, '');
            if (staffUser) {
                await staffUser.update({
                    full_name,
                    phone,
                    password_hash,
                    role: 'RM',
                    permissions: ['tenants:read', 'support:read', 'support:write', 'rms:read'],
                    is_active: true,
                });
            }
            else {
                let usernameToUse = baseUsername || `rm_${Date.now().toString(36)}`;
                const userExists = await MasterStaffUser.findOne({ where: { username: usernameToUse } });
                if (userExists) {
                    usernameToUse = `${baseUsername}_rm`;
                }
                staffUser = await MasterStaffUser.create({
                    username: usernameToUse,
                    email: cleanEmail,
                    password_hash,
                    full_name,
                    role: 'RM',
                    permissions: ['tenants:read', 'support:read', 'support:write', 'rms:read'],
                    phone,
                    is_active: true,
                });
            }
            // 3. Dispatch credentials notification
            console.log(`[RM_ONBOARDING] Relationship Manager login credentials for ${cleanEmail}: Username: ${staffUser.username}, Password: ${loginPassword}`);
            try {
                await (0, emailService_1.sendOtpEmail)(cleanEmail, loginPassword, 'Famalth Enterprise - Relationship Manager Login Credentials');
            }
            catch (mailErr) {
                console.warn('[RM_ONBOARDING] Notice: Credentials email dispatch skipped/failed:', mailErr.message);
            }
            return res.status(201).json({
                success: true,
                message: `Relationship Manager onboarded successfully. Login operator account created for ${cleanEmail}.`,
                data: {
                    ...rm.toJSON(),
                    login_username: staffUser.username,
                    role: 'RM',
                },
            });
        }
        catch (err) {
            console.error('createRelationshipManager error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 10. POS License Warning & RM Profile Query Endpoint (Queried by POS terminal at launch)
     */
    static async getLicenseAndRMStatus(req, res) {
        try {
            const { tenant_id, outlet_code } = req.query;
            let tenant = null;
            let matchedOutlet = null;
            let resolvedOutletCode = outlet_code ? String(outlet_code).trim() : null;

            if (!resolvedOutletCode) {
                resolvedOutletCode = req.user?.outlet_code || req.user?.outletCode || null;
            }

            if (tenant_id) {
                tenant = await MasterTenant.findByPk(String(tenant_id), {
                    include: [
                        { model: MasterLicense, as: 'licenses' },
                        { model: MasterRelationshipManager, as: 'relationship_manager' },
                        { model: MasterOutlet, as: 'outlets' },
                    ],
                });
                if (tenant?.outlets && tenant.outlets.length > 0) {
                    matchedOutlet = tenant.outlets[0];
                    if (!resolvedOutletCode) {
                        resolvedOutletCode = matchedOutlet.outlet_code;
                    }
                }
            } else {
                // If no outlet_code query provided, inspect local database outlets table
                if (!resolvedOutletCode) {
                    try {
                        const localOutlet = await propertyDb_1.default.query(
                            'SELECT outlet_code FROM outlets WHERE is_active = true OR id = 1 ORDER BY id ASC LIMIT 1',
                            { type: (sequelize_1.QueryTypes && sequelize_1.QueryTypes.SELECT) || 'SELECT' }
                        );
                        if (localOutlet && localOutlet[0]?.outlet_code) {
                            resolvedOutletCode = String(localOutlet[0].outlet_code).trim();
                        }
                    } catch (e) {
                        // fallback gracefully
                    }
                }

                if (resolvedOutletCode) {
                    matchedOutlet = await MasterOutlet.findOne({
                        where: { outlet_code: resolvedOutletCode },
                        include: [
                            {
                                model: MasterTenant,
                                as: 'tenant',
                                include: [
                                    { model: MasterLicense, as: 'licenses' },
                                    { model: MasterRelationshipManager, as: 'relationship_manager' },
                                    { model: MasterOutlet, as: 'outlets' },
                                ],
                            },
                        ],
                    });

                    if (matchedOutlet?.tenant) {
                        tenant = matchedOutlet.tenant;
                    } else {
                        // Check if MasterTenant client_code matches resolvedOutletCode
                        tenant = await MasterTenant.findOne({
                            where: { client_code: resolvedOutletCode },
                            include: [
                                { model: MasterLicense, as: 'licenses' },
                                { model: MasterRelationshipManager, as: 'relationship_manager' },
                                { model: MasterOutlet, as: 'outlets' },
                            ],
                        });
                    }
                }

                // If still not found, fallback to the primary active master tenant
                if (!tenant) {
                    tenant = await MasterTenant.findOne({
                        include: [
                            { model: MasterLicense, as: 'licenses' },
                            { model: MasterRelationshipManager, as: 'relationship_manager' },
                            { model: MasterOutlet, as: 'outlets' },
                        ],
                        order: [['updated_at', 'DESC']],
                    });
                    if (tenant?.outlets && tenant.outlets.length > 0) {
                        matchedOutlet = tenant.outlets[0];
                        if (!resolvedOutletCode) {
                            resolvedOutletCode = matchedOutlet.outlet_code;
                        }
                    }
                }
            }

            if (!tenant) {
                return res.json({
                    success: true,
                    data: {
                        daysLeft: 0,
                        hasActiveLicense: false,
                        warningZone: false,
                        warningLevel: 'SAFE',
                        status: 'UNREGISTERED',
                        relationshipManager: null,
                        outletCode: resolvedOutletCode,
                    },
                });
            }

            const activeLicense = (tenant.licenses || [])[0];
            const hasRealLicense = Boolean(activeLicense && activeLicense.valid_till);
            let daysLeft = 0;
            let warningZone = false;
            let warningLevel = 'SAFE';

            if (hasRealLicense) {
                const diffMs = new Date(activeLicense.valid_till).getTime() - Date.now();
                daysLeft = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
                const threshold = activeLicense.grace_period_days || activeLicense.warning_zone_days || 15;
                if (daysLeft < 0) {
                    warningLevel = 'EXPIRED';
                    warningZone = true;
                }
                else if (daysLeft <= 3) {
                    warningLevel = 'CRITICAL_RED';
                    warningZone = true;
                }
                else if (daysLeft <= threshold) {
                    warningLevel = 'WARNING_AMBER';
                    warningZone = true;
                }
            }

            const subtotal = activeLicense?.subscription_amount != null ? Number(activeLicense.subscription_amount) : 0.00;
            const taxRate = activeLicense?.tax_percentage != null ? Number(activeLicense.tax_percentage) : 0.00;
            const totalAmount = Number((subtotal + (subtotal * (taxRate / 100))).toFixed(2));
            const paymentStatus = activeLicense?.payment_status || (hasRealLicense ? 'PAID' : 'UNASSIGNED');
            const isPendingPayment = paymentStatus === 'PENDING' || (hasRealLicense && daysLeft <= 10);

            // Relationship Manager: only return real data if explicitly assigned and not dummy
            let rmData = null;
            if (tenant.relationship_manager &&
                tenant.relationship_manager.rm_code !== 'RM-101' &&
                !tenant.relationship_manager.full_name?.toLowerCase().includes('amit')) {
                rmData = {
                    id: tenant.relationship_manager.id,
                    fullName: tenant.relationship_manager.full_name || tenant.relationship_manager.name,
                    phone: tenant.relationship_manager.phone,
                    whatsappNumber: tenant.relationship_manager.whatsapp_number || tenant.relationship_manager.phone,
                    email: tenant.relationship_manager.email,
                    designation: tenant.relationship_manager.designation || 'Key Account Manager',
                    rmCode: tenant.relationship_manager.rm_code,
                };
            }

            const finalOutletCode = resolvedOutletCode || matchedOutlet?.outlet_code || (tenant.outlets && tenant.outlets[0]?.outlet_code) || tenant.client_code;

            return res.json({
                success: true,
                data: {
                    tenantId: tenant.id,
                    tenant: { id: tenant.id, legal_name: tenant.legal_name, client_code: tenant.client_code },
                    clientCode: tenant.client_code,
                    outletCode: finalOutletCode,
                    legalName: tenant.legal_name,
                    contactEmail: tenant.contact_email,
                    contactPhone: tenant.contact_phone,
                    hasActiveLicense: hasRealLicense,
                    daysLeft,
                    warningZone,
                    warningLevel,
                    status: tenant.status,
                    softwareStartDate: activeLicense?.valid_from || tenant.created_at,
                    validTill: activeLicense?.valid_till || null,
                    gracePeriodDays: activeLicense?.grace_period_days || 0,
                    nextPaymentDate: activeLicense?.next_payment_date || activeLicense?.valid_till,
                    subscriptionAmount: subtotal,
                    taxPercentage: taxRate,
                    totalPaymentAmount: totalAmount,
                    paymentStatus,
                    isPendingPayment,
                    invoiceDownloadUrl: `/api/v1/control-plane/invoices/download/${tenant.id}`,
                    maxTerminals: activeLicense?.max_terminals || 1,
                    maxOutlets: activeLicense?.max_outlets || 1,
                    relationshipManager: rmData,
                },
            });
        }
        catch (err) {
            console.error('getLicenseAndRMStatus error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * List all Outlets with Tenant info for support and query targeting
     */
    static async getAllOutlets(req, res) {
        try {
            try {
                await ensureMasterDatabaseSync(propertyDb_1.default);
            } catch (_) {}
            const outlets = await MasterOutlet.findAll({
                include: [{ model: MasterTenant, as: 'tenant' }],
                order: [['id', 'ASC']],
            });
            const formatted = outlets.map((o) => ({
                id: o.id,
                outlet_code: o.outlet_code,
                outlet_name: o.outlet_name,
                outlet_type: o.outlet_type,
                city: o.city,
                tenant_id: o.tenant_id,
                tenant_name: o.tenant ? o.tenant.legal_name : 'Unknown Business',
                client_code: o.tenant ? o.tenant.client_code : (o.outlet_code || 'N/A'),
                is_active: o.is_active,
                is_kill_switched: o.is_kill_switched,
            }));
            return res.json({ success: true, data: formatted });
        }
        catch (err) {
            console.error('getAllOutlets error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
    /**
     * 12. Trigger Expiry & Renewal Email Notices manually
     */
    static async triggerExpiryAndRenewalNotices(req, res) {
        try {
            const result = await controlPlaneNotification_service_1.default.checkAndDispatchExpiryAndRenewalNotices(propertyDb_1.default);
            return res.json({
                success: true,
                message: `Dispatched ${result.renewalCount} renewal invoice(s) and ${result.expiredCount} expiry alert(s).`,
                data: result,
            });
        }
        catch (err) {
            console.error('triggerExpiryAndRenewalNotices error:', err);
            return res.status(500).json({ success: false, message: err.message });
        }
    }
}
exports.ControlPlaneController = ControlPlaneController;
exports.default = ControlPlaneController;
