
const bcrypt = require("bcryptjs");
const jwt = require('../../utils/jwt.util');
const audit = require('../../services/audit.service');
const { verifyLicenseOnline } = require('../public/licenseManager');
const { touchClient } = require("../../modules/sheetService");
const { internalCheckOutlet } = require("../public/outlet.controller");
const { sendOtpEmail } = require('../../modules/emailService');
const { resolveBusinessModule } = require('../../utils/moduleHelper');

const DEFAULT_ROLE_PERMISSIONS = {
    ADMIN: ['*'],
    STORE: [
        'ITEM_REQUEST', 'PURCHASE_ORDER', 'STOCK_IN', 'STOCK_OUT', 'RETURN', 'DAMAGE',
        'ITEM_MASTER', 'SUPPLIER_MASTER', 'STOCK_LOCATION',
        'STOCK_BALANCE', 'DAMAGE_SUMMARY', 'STOCK_IN_REPORT', 'STOCK_OUT_REPORT',
        'DAMAGE_REPORT', 'REQUEST_REPORT', 'PURCHASE_REPORT', 'RETURN_REPORT',
        'STOCK_TRANSFER', 'PRODUCT_ASSEMBLY', 'RETURN_ISSUE', 'SUPPLIER_RETURN',
        'STOCK_TRANSFER_REPORT', 'SUBMISSIONS_STATUS'
    ],
    RETAIL: [
        'RETAIL_SALES', 'REPRINT_SALES_BILL', 'RETAIL_SALES_REPORT', 'CLOSING_REPORT',
        'CUSTOMER_APP', 'RETAILER_CONSOLE', 'RIDER_PORTAL'
    ],
    ACCOUNTS: [
        'SUPPLIER_PAYMENT', 'REPORTS', 'STOCK_BALANCE', 'DAMAGE_SUMMARY', 'STOCK_IN_REPORT',
        'STOCK_OUT_REPORT', 'RETAIL_SALES_REPORT', 'CLOSING_REPORT', 'PURCHASE_REPORT',
        'RETURN_REPORT', 'REQUEST_REPORT', 'DAMAGE_REPORT',
        'SUPPLIER_RETURN_REFUND', 'PENDING_REFUNDS', 'CASH_LEDGER', 'STOCK_LEDGER_REPORT',
        'VENDOR_PAYMENT_REPORT', 'SUBSCRIPTION_REPORT', 'SCHEME_REPORT', 'SCHEME_ANALYSIS',
        'LOYALTY_REPORT', 'STORE_ANALYSIS', 'BRAND_ANALYSIS', 'SOURCE_ANALYSIS',
        'COMMISSION_REPORT', 'PAYMENT_ANALYSIS', 'AI_QUERY_ANALYTICS'
    ],
    HR: [
        'HR_EMPLOYEES', 'HR_ATTENDANCE', 'HR_PAYROLL', 'HR_MASTERS'
    ]
};

exports.login = async (req, res, next) => {
    try {
        let licenseState = 'VALID';
        let daysRemaining = 999;

        const { username, password, role, outlet_code } = req.body;
        const db = req.propertyDb;


        if (!outlet_code) {
            return res.status(400).json({ success: false, message: 'Outlet code is required for login.' });
        }

        const currentOutlet = await db.models.outlets.findOne({
            where: {
                outlet_code: outlet_code,
                is_active: true
            }
        });

        if (!currentOutlet) {
            return res.status(401).json({ success: false, message: 'Invalid or inactive outlet code.' });
        }

        let user = await db.models.users.findOne({
            where: {
                username: username,
                outlet_id: currentOutlet.id
            }
        });
 
        if (!user) {
            if (username === 'admin') {
                user = await db.models.users.findOne({
                    where: {
                        username: `admin_${currentOutlet.outlet_code}`,
                        outlet_id: currentOutlet.id
                    }
                });
            } else if (username === `admin_${currentOutlet.outlet_code}`) {
                user = await db.models.users.findOne({
                    where: {
                        username: 'admin',
                        outlet_id: currentOutlet.id
                    }
                });
            }
        }

        if (!user || !user.is_active) {
            return res.status(401).json({ success: false, message: 'Invalid user for this outlet.' });
        }

        const isWaiterOrCaptain = (r: string) => {
            const clean = (r || '').toString().toUpperCase().trim();
            return clean === 'WAITER' || clean === 'CAPTAIN' || clean === 'CAPTION' || clean === 'STEWARD' || clean === 'SERVER';
        };

        const isRoleAuthorized = (userRole: string, requestedRole: string) => {
            const uRole = (userRole || '').toString().toUpperCase().trim();
            const reqRole = (requestedRole || '').toString().toUpperCase().trim();
            if (!reqRole) return true;
            if (uRole === reqRole) return true;
            if (isWaiterOrCaptain(reqRole) && (isWaiterOrCaptain(uRole) || uRole === 'MANAGER')) return true;
            return false;
        };

        if (role && !isRoleAuthorized(user.role, role)) {
            return res.status(403).json({
                success: false,
                message: `Access Denied: User '${user.username}' is assigned role '${user.role}', not '${role}'. Please select the '${user.role}' workstation role to sign in.`
            });
        }

        const ok = await bcrypt.compare(password, user.password_hash);
        if (!ok) {
            return res.status(401).json({ success: false, message: 'Wrong password.' });
        }

        const rawMaint = require('../../services/maintenance.service');
        const maintenanceService = rawMaint.default || rawMaint.maintenanceService || rawMaint;
        if (maintenanceService.isUnderMaintenance()) {
            const uRole = String(user.role || '').toUpperCase();
            if (uRole !== 'SUPER_ADMIN' && uRole !== 'ENTERPRISE_ADMIN') {
                const status = maintenanceService.getStatus();
                return res.status(503).json({
                    success: false,
                    maintenance: true,
                    title: status.title,
                    message: status.message,
                    remainingMinutes: status.remainingMinutes,
                    estimatedEndTime: status.estimatedEndTime
                });
            }
        }

        try {
            const licenseData = await verifyLicenseOnline(outlet_code);
            daysRemaining = licenseData.days_remaining;
            licenseState = licenseData.license_status;

            if (licenseState === 'EXPIRED') {
                return res.status(403).json({
                    success: false,
                    license_status: 'EXPIRED',
                    message: 'System license expired. Please renew to continue.'
                });
            }

        } catch (err) {
            console.warn(`[AUTH] Cloud license check bypassed: ${err.message}`);
        }

        let permissions = [];
        if (user.role === 'ADMIN') {
            permissions = ['*'];
        } else {
            const perms = await db.models.user_permissions.findAll({
                where: { user_id: user.id }
            });
            permissions = perms.map(p => p.perm_key);

            if (permissions.length === 0) {
                const defaultPerms = DEFAULT_ROLE_PERMISSIONS[user.role] || [];
                if (defaultPerms.length > 0) {
                    await db.models.user_permissions.bulkCreate(
                        defaultPerms.map(p => ({ user_id: user.id, perm_key: p }))
                    );
                    permissions = defaultPerms;
                }
            }
        }

        const token = jwt.sign({
            user_id: user.id,
            username: user.username,
            outlet_id: currentOutlet.id,
            role: user.role,
            outlet_code: currentOutlet.outlet_code,
            permissions
        });

        Promise.all([
            audit.log({
                req,
                module: 'AUTH',
                action: 'LOGIN',
                table: 'users',
                recordId: user.id,
                newData: { username: user.username },
                outlet_id: currentOutlet.id,
                user_id: user.id
            }).catch(() => {}),
            user.update({ last_login: new Date() }).catch(() => {})
        ]);

        touchClient(outlet_code).catch((err: any) =>
            console.warn(`[TOUCH] Background sync: ${err?.message || err}`)
        );

        const property = await db.models.property_info.findOne({
            where: { outlet_id: currentOutlet.id },
            attributes: ['property_name']
        }).catch(() => null);

        const ROLE_MAX_DISCOUNTS = {
            ADMIN: 100.0,
            MANAGER: 50.0,
            STORE: 20.0,
            RETAIL: 15.0,
            CASHIER: 10.0,
            ACCOUNTS: 25.0,
            HR: 10.0,
            WAITER: 5.0,
            CAPTAIN: 15.0,
            KDS: 0.0,
            MARKETING: 25.0
        };

        const resolvedMaxDiscount = (user.max_discount_percent !== null && user.max_discount_percent !== undefined)
            ? parseFloat(user.max_discount_percent)
            : (ROLE_MAX_DISCOUNTS[user.role] || 10.0);

        res.json({
            success: true,
            license_status: licenseState,
            days_remaining: daysRemaining,
            token,
            user: {
                id: user.id,
                username: user.username,
                name: user.full_name,
                role: user.role,
                mobile: user.mobile,
                max_discount_percent: resolvedMaxDiscount,
                outlet_id: currentOutlet.id,
                outlet_code: currentOutlet.outlet_code,
                outlet_name: currentOutlet.outlet_name || '',
                property_name: currentOutlet.outlet_name || property?.property_name || '',
                outlet_type: currentOutlet.outlet_type || '',
                business_module: resolveBusinessModule(currentOutlet.business_module, currentOutlet.outlet_type),
                speciality: user.speciality || '',
                qualification: user.qualification || '',
                consultation_fee: user.consultation_fee || 0,
                registration_no: user.registration_no || '',
                permissions
            }
        });

    } catch (error) {
        console.error('[AUTH ERROR]', error);
        res.status(500).json({ success: false, message: 'Internal server error during login' });
    }
};

// In-memory store for supplier OTPs: "outletCode_email" -> { otp, expiresAt }
const supplierOtpStore = new Map();

exports.requestSupplierOtp = async (req: any, res: any) => {
    try {
        let { outlet_code, email } = req.body;
        const db = req.propertyDb;

        if (!email || !email.toString().trim()) {
            return res.status(400).json({ success: false, message: 'Email address is required.' });
        }

        const normEmail = email.toString().trim().toLowerCase();
        let targetOutlet: any = null;

        // 1. Resolve outlet by outlet_code if provided
        if (outlet_code && outlet_code.toString().trim()) {
            targetOutlet = await db.models.outlets.findOne({
                where: {
                    outlet_code: outlet_code.toString().trim(),
                    is_active: true
                }
            }).catch(() => null);
        }

        // 2. Resolve outlet by contact_email matching the outlet
        if (!targetOutlet) {
            targetOutlet = await db.models.outlets.findOne({
                where: {
                    contact_email: normEmail,
                    is_active: true
                }
            }).catch(() => null);
        }

        // 3. Resolve outlet by matching user email
        if (!targetOutlet && db.models.users) {
            const userMatch = await db.models.users.findOne({
                where: {
                    contact_email: normEmail,
                    is_active: true
                }
            }).catch(() => null);
            if (userMatch && userMatch.outlet_id) {
                targetOutlet = await db.models.outlets.findByPk(userMatch.outlet_id).catch(() => null);
            }
        }

        // 4. Fallback to default or any active outlet
        if (!targetOutlet) {
            targetOutlet = await db.models.outlets.findOne({
                where: { is_active: true },
                order: [['id', 'ASC']]
            }).catch(() => null);
        }

        if (!targetOutlet) {
            return res.status(404).json({ success: false, message: 'No active business outlet found.' });
        }

        // Generate 6-digit OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Date.now() + 600000; // 10 minutes

        // Store OTP under multiple keys so verify succeeds regardless of outlet code parameter
        supplierOtpStore.set(`${targetOutlet.outlet_code}_${normEmail}`, { otp: otpCode, expiresAt, outlet_code: targetOutlet.outlet_code });
        supplierOtpStore.set(normEmail, { otp: otpCode, expiresAt, outlet_code: targetOutlet.outlet_code });
        if (outlet_code && outlet_code.toString().trim()) {
            supplierOtpStore.set(`${outlet_code.toString().trim()}_${normEmail}`, { otp: otpCode, expiresAt, outlet_code: targetOutlet.outlet_code });
        }

        console.log(`[SUPPLIER LOGIN OTP] Key sent to ${normEmail} for outlet ${targetOutlet.outlet_code}: ${otpCode}`);

        // Send OTP email (gracefully catch if mail transport is not configured)
        try {
            await sendOtpEmail(normEmail, otpCode, "Supplier Login Verification");
        } catch (mailErr) {
            console.warn('[SUPPLIER OTP EMAIL NOTICE] Could not send email, OTP logged to console:', mailErr);
        }

        return res.json({
            success: true,
            message: `Verification OTP has been sent to ${normEmail}.`,
            outlet_code: targetOutlet.outlet_code
        });
    } catch (error: any) {
        console.error('[OTP REQUEST ERROR]', error);
        return res.status(500).json({ success: false, message: 'Internal server error during OTP request.' });
    }
};

exports.verifySupplierOtp = async (req: any, res: any) => {
    try {
        let { outlet_code, email, otp } = req.body;
        const db = req.propertyDb;

        if (!email || !otp) {
            return res.status(400).json({ success: false, message: 'Email and OTP are required.' });
        }

        const normEmail = email.toString().trim().toLowerCase();
        const cleanOtp = otp.toString().trim();

        // Check OTP record across possible keys
        const record = (outlet_code ? supplierOtpStore.get(`${outlet_code.toString().trim()}_${normEmail}`) : null) ||
                       supplierOtpStore.get(normEmail) ||
                       supplierOtpStore.get(`${outlet_code}_${normEmail}`);

        if (!record || record.otp !== cleanOtp || Date.now() > record.expiresAt) {
            return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
        }

        const resolvedOutletCode = record.outlet_code || outlet_code;
        supplierOtpStore.delete(normEmail);
        if (outlet_code) supplierOtpStore.delete(`${outlet_code}_${normEmail}`);
        if (record.outlet_code) supplierOtpStore.delete(`${record.outlet_code}_${normEmail}`);

        // Fetch the outlet
        let currentOutlet: any = null;
        if (resolvedOutletCode) {
            currentOutlet = await db.models.outlets.findOne({
                where: { outlet_code: resolvedOutletCode, is_active: true }
            }).catch(() => null);
        }
        if (!currentOutlet) {
            currentOutlet = await db.models.outlets.findOne({
                where: { is_active: true },
                order: [['id', 'ASC']]
            }).catch(() => null);
        }

        if (!currentOutlet) {
            return res.status(404).json({ success: false, message: 'Outlet no longer exists or is inactive.' });
        }

        // Find matching or manager user
        let user: any = await db.models.users.findOne({
            where: {
                contact_email: normEmail,
                is_active: true
            }
        }).catch(() => null);

        if (!user) {
            user = await db.models.users.findOne({
                where: {
                    outlet_id: currentOutlet.id,
                    is_active: true,
                    role: ['ADMIN', 'STORE', 'SUPPLIER', 'MANAGER']
                }
            }).catch(() => null);
        }

        if (!user) {
            user = await db.models.users.findOne({
                where: {
                    outlet_id: currentOutlet.id,
                    is_active: true
                }
            }).catch(() => null);
        }

        if (!user) {
            return res.status(404).json({ success: false, message: 'No active user found for this outlet.' });
        }

        // Generate login token
        const token = jwt.sign({
            user_id: user.id,
            outlet_id: currentOutlet.id,
            role: user.role,
            outlet_code: currentOutlet.outlet_code,
            business_module: resolveBusinessModule(currentOutlet.business_module, currentOutlet.outlet_type),
            permissions: ['*']
        });

        await user.update({ last_login: new Date() }).catch(() => {});

        const property = await db.models.property_info.findOne({
            where: { outlet_id: currentOutlet.id },
            attributes: ['property_name', 'logo_path']
        }).catch(() => null);

        await touchClient(currentOutlet.outlet_code).catch(() => {});

        return res.json({
            success: true,
            license_status: 'VALID',
            days_remaining: 999,
            token,
            user: {
                username: user.username,
                name: user.full_name || user.username,
                role: user.role,
                mobile: user.mobile,
                outlet_id: currentOutlet.id,
                outlet_code: currentOutlet.outlet_code,
                property_name: property?.property_name || currentOutlet.outlet_name,
                outlet_type: currentOutlet.outlet_type || '',
                business_module: resolveBusinessModule(currentOutlet.business_module, currentOutlet.outlet_type),
                permissions: ['*']
            }
        });
    } catch (error: any) {
        console.error('[OTP VERIFY ERROR]', error);
        return res.status(500).json({ success: false, message: 'Internal server error during OTP verification.' });
    }
};

exports.switchOutlet = async (req, res) => {
    try {
        const db = req.propertyDb;
        const currentOutletId = req.user?.outlet_id;
        const targetRawId = req.body.target_outlet_id || req.body.outlet_id || req.body.target_outlet_code || req.body.outlet_code;

        if (!targetRawId) {
            return res.status(400).json({ success: false, message: 'Target outlet is required for switch' });
        }

        const allOutlets = await db.models.outlets.findAll({
            where: { is_active: true },
            bypassOutletFilter: true
        });

        let targetOutlet = null;
        if (typeof targetRawId === 'number' || !isNaN(Number(targetRawId))) {
            targetOutlet = allOutlets.find(o => o.id === Number(targetRawId));
        } else {
            targetOutlet = allOutlets.find(o => o.outlet_code === String(targetRawId).trim());
        }

        if (!targetOutlet) {
            return res.status(404).json({ success: false, message: 'Target outlet not found or inactive' });
        }

        const currentOutlet = allOutlets.find(o => o.id === Number(currentOutletId));

        const isLinked =
            allOutlets.length > 1 &&
            (
                Number(targetOutlet.id) === Number(currentOutletId) ||
                Number(targetOutlet.parent_outlet_id) === Number(currentOutletId) ||
                Number(currentOutlet?.parent_outlet_id) === Number(targetOutlet.id) ||
                (currentOutlet?.parent_outlet_id && Number(currentOutlet.parent_outlet_id) === Number(targetOutlet.parent_outlet_id)) ||
                currentOutlet?.is_master ||
                targetOutlet.is_master
            );

        if (!isLinked) {
            return res.status(403).json({ success: false, message: 'Direct login is only allowed for linked outlets' });
        }

        // Fetch full details of the currently authenticated user
        const currentUser = await db.models.users.findOne({
            where: { id: req.user.user_id || req.user.id },
            bypassOutletFilter: true
        });

        let targetUser = null;

        if (currentUser?.username) {
            targetUser = await db.models.users.findOne({
                where: {
                    username: currentUser.username,
                    outlet_id: targetOutlet.id,
                    is_active: true
                },
                bypassOutletFilter: true
            });
        }

        if (!targetUser) {
            targetUser = await db.models.users.findOne({
                where: {
                    outlet_id: targetOutlet.id,
                    is_active: true
                },
                order: [['role', 'ASC']],
                bypassOutletFilter: true
            });
        }

        if (!targetUser && currentUser) {
            targetUser = await db.models.users.create({
                outlet_id: targetOutlet.id,
                username: currentUser.username,
                password_hash: currentUser.password_hash,
                full_name: currentUser.full_name,
                mobile: currentUser.mobile,
                role: currentUser.role,
                is_active: true
            }, { bypassOutletFilter: true });
        }

        if (!targetUser) {
            return res.status(400).json({ success: false, message: 'No active user account found in target outlet' });
        }

        let permissions = [];
        if (targetUser.role === 'ADMIN') {
            permissions = ['*'];
        } else {
            const perms = await db.models.user_permissions.findAll({
                where: { user_id: targetUser.id },
                bypassOutletFilter: true
            });
            permissions = perms.map(p => p.perm_key);

            if (permissions.length === 0) {
                const defaultPerms = DEFAULT_ROLE_PERMISSIONS[targetUser.role] || [];
                if (defaultPerms.length > 0) {
                    try {
                        await db.models.user_permissions.bulkCreate(
                            defaultPerms.map(p => ({ user_id: targetUser.id, perm_key: p })),
                            { bypassOutletFilter: true }
                        );
                    } catch (_) {}
                    permissions = defaultPerms;
                }
            }
        }

        const token = jwt.sign({
            user_id: targetUser.id,
            username: targetUser.username,
            outlet_id: targetOutlet.id,
            role: targetUser.role,
            outlet_code: targetOutlet.outlet_code,
            permissions
        });

        try {
            await audit.log({
                req,
                module: 'AUTH',
                action: 'DIRECT_SWITCH_OUTLET',
                table: 'users',
                recordId: targetUser.id,
                newData: { username: targetUser.username, from_outlet: currentOutletId, to_outlet: targetOutlet.id },
                outlet_id: targetOutlet.id,
                user_id: targetUser.id
            });
        } catch (auditErr) {
            console.warn('[SWITCH OUTLET AUDIT WARN]', auditErr.message);
        }

        const property = await db.models.property_info.findOne({
            where: { outlet_id: targetOutlet.id },
            attributes: ['property_name'],
            bypassOutletFilter: true
        });

        return res.json({
            success: true,
            message: `Direct login to ${targetOutlet.outlet_name} successful`,
            token,
            user: {
                username: targetUser.username,
                name: targetUser.full_name,
                role: targetUser.role,
                mobile: targetUser.mobile,
                max_discount_percent: targetUser.max_discount_percent || 10.0,
                outlet_id: targetOutlet.id,
                outlet_code: targetOutlet.outlet_code,
                property_name: property?.property_name || targetOutlet.outlet_name,
                outlet_type: targetOutlet.outlet_type || '',
                business_module: resolveBusinessModule(targetOutlet.business_module, targetOutlet.outlet_type),
                permissions
            }
        });
    } catch (error) {
        console.error('[SWITCH OUTLET ERROR]', error);
        return res.status(500).json({ success: false, message: 'Failed to complete direct outlet login: ' + error.message });
    }
};

exports.pinLogin = async (req: any, res: any) => {
    try {
        const { pin, outlet_code, username, role } = req.body;
        const db = req.propertyDb;

        if (!outlet_code) {
            return res.status(400).json({ success: false, message: 'Outlet code is required.' });
        }
        if (!pin || !pin.toString().trim()) {
            return res.status(400).json({ success: false, message: 'PIN is required.' });
        }

        const currentOutlet = await db.models.outlets.findOne({
            where: {
                outlet_code: outlet_code,
                is_active: true
            }
        });

        if (!currentOutlet) {
            return res.status(401).json({ success: false, message: 'Invalid or inactive outlet code.' });
        }

        const cleanPin = pin.toString().trim();

        let user: any = null;
        if (username && username.trim()) {
            user = await db.models.users.findOne({
                where: {
                    username: username.trim(),
                    outlet_id: currentOutlet.id,
                    is_active: true
                }
            });
            if (user && user.pin_code !== cleanPin) {
                // Also support hashed pin comparison if hashed
                let pinOk = false;
                try {
                    pinOk = await bcrypt.compare(cleanPin, user.pin_code);
                } catch (_) {}
                if (!pinOk) {
                    return res.status(401).json({ success: false, message: 'Incorrect PIN.' });
                }
            }
        } else {
            // Find active user matching PIN in this outlet
            const users = await db.models.users.findAll({
                where: {
                    outlet_id: currentOutlet.id,
                    is_active: true
                }
            });

            const matchingUsers = [];
            for (const u of users) {
                if (u.pin_code === cleanPin) {
                    matchingUsers.push(u);
                } else if (u.pin_code) {
                    try {
                        if (await bcrypt.compare(cleanPin, u.pin_code)) {
                            matchingUsers.push(u);
                        }
                    } catch (_) {}
                }
            }

            if (matchingUsers.length === 0) {
                return res.status(401).json({ success: false, message: "Invalid PIN or user not found for this outlet." });
            }

            if (matchingUsers.length > 1) {
                let roleMatches = matchingUsers;
                if (role && role.toString().trim()) {
                    const reqRole = role.toString().trim().toUpperCase();
                    roleMatches = matchingUsers.filter(u => (u.role || "").toString().toUpperCase() === reqRole);
                }
                if (roleMatches.length === 1) {
                    user = roleMatches[0];
                } else {
                    const userNames = matchingUsers.map(u => u.full_name || u.username).join(", ");
                    return res.status(409).json({
                        success: false,
                        message: "Security Conflict: Multiple active users (" + userNames + ") share the same PIN code '" + cleanPin + "'. Please enter your username along with your PIN, or assign unique PINs in User Management."
                    });
                }
            } else {
                user = matchingUsers[0];
            }
        }

        if (!user) {
            return res.status(401).json({ success: false, message: 'Invalid PIN or user not found for this outlet.' });
        }

        const isWaiterOrCaptain = (r: string) => {
            const clean = (r || '').toString().toUpperCase().trim();
            return clean === 'WAITER' || clean === 'CAPTAIN' || clean === 'CAPTION' || clean === 'STEWARD' || clean === 'SERVER';
        };

        const isRoleAuthorized = (userRole: string, requestedRole: string) => {
            const uRole = (userRole || '').toString().toUpperCase().trim();
            const reqRole = (requestedRole || '').toString().toUpperCase().trim();
            if (!reqRole) return true;
            if (uRole === reqRole) return true;
            if (isWaiterOrCaptain(reqRole) && (isWaiterOrCaptain(uRole) || uRole === 'MANAGER')) return true;
            return false;
        };

        if (role && !isRoleAuthorized(user.role, role)) {
            return res.status(403).json({
                success: false,
                message: `Access Denied: User '${user.username || user.full_name}' is assigned role '${user.role}', not '${role}'. Please select the '${user.role}' workstation role to sign in.`
            });
        }

        const rawMaintPin = require('../../services/maintenance.service');
        const maintenanceServicePin = rawMaintPin.default || rawMaintPin.maintenanceService || rawMaintPin;
        if (maintenanceServicePin.isUnderMaintenance()) {
            const uRole = String(user.role || '').toUpperCase();
            if (uRole !== 'SUPER_ADMIN' && uRole !== 'ENTERPRISE_ADMIN') {
                const status = maintenanceServicePin.getStatus();
                return res.status(503).json({
                    success: false,
                    maintenance: true,
                    title: status.title,
                    message: status.message,
                    remainingMinutes: status.remainingMinutes,
                    estimatedEndTime: status.estimatedEndTime
                });
            }
        }

        let licenseState = 'VALID';
        let daysRemaining = 999;
        try {
            const licenseData: any = await verifyLicenseOnline(outlet_code);
            daysRemaining = licenseData.days_remaining;
            licenseState = licenseData.license_status;

            if (licenseState === 'EXPIRED') {
                return res.status(403).json({
                    success: false,
                    license_status: 'EXPIRED',
                    message: 'System license expired. Please renew to continue.'
                });
            }
        } catch (err: any) {
            console.warn(`[PIN AUTH] Cloud license check bypassed: ${err.message}`);
        }

        let permissions: any[] = [];
        if (user.role === 'ADMIN') {
            permissions = ['*'];
        } else {
            const perms = await db.models.user_permissions.findAll({
                where: { user_id: user.id }
            });
            permissions = perms.map((p: any) => p.perm_key);

            if (permissions.length === 0) {
                const defaultPerms = (DEFAULT_ROLE_PERMISSIONS as any)[user.role] || [];
                if (defaultPerms.length > 0) {
                    await db.models.user_permissions.bulkCreate(
                        defaultPerms.map((p: any) => ({ user_id: user.id, perm_key: p }))
                    );
                    permissions = defaultPerms;
                }
            }
        }

        const token = jwt.sign({
            user_id: user.id,
            username: user.username,
            outlet_id: currentOutlet.id,
            role: user.role,
            outlet_code: currentOutlet.outlet_code,
            permissions
        });

        try {
            await audit.log({
                req,
                module: 'AUTH',
                action: 'PIN_LOGIN',
                table: 'users',
                recordId: user.id,
                newData: { username: user.username },
                outlet_id: currentOutlet.id,
                user_id: user.id
            });
        } catch (_) {}

        await user.update({ last_login: new Date() });

        const property = await db.models.property_info.findOne({
            where: { outlet_id: currentOutlet.id },
            attributes: ['property_name']
        });

        return res.json({
            success: true,
            license_status: licenseState,
            days_remaining: daysRemaining,
            token,
            user: {
                id: user.id,
                username: user.username,
                name: user.full_name,
                role: user.role,
                mobile: user.mobile,
                max_discount_percent: user.max_discount_percent ? parseFloat(user.max_discount_percent) : 10.0,
                outlet_id: currentOutlet.id,
                outlet_code: currentOutlet.outlet_code,
                property_name: property?.property_name || currentOutlet.outlet_name,
                outlet_type: currentOutlet.outlet_type || '',
                business_module: resolveBusinessModule(currentOutlet.business_module, currentOutlet.outlet_type),
                speciality: user.speciality || '',
                qualification: user.qualification || '',
                consultation_fee: user.consultation_fee || 0,
                permissions
            }
        });
    } catch (error: any) {
        console.error('[PIN LOGIN ERROR]', error);
        return res.status(500).json({ success: false, message: 'PIN login failed: ' + error.message });
    }
};


exports.getQuickUsers = async (req, res) => {
    try {
        const { outlet_code, role } = req.query;
        if (!outlet_code) {
            return res.status(400).json({ success: false, message: 'outlet_code is required' });
        }
        const db = req.propertyDb;
        const currentOutlet = await db.models.outlets.findOne({
            where: { outlet_code, is_active: true }
        });
        if (!currentOutlet) {
            return res.status(404).json({ success: false, message: 'Outlet not found' });
        }

        const { Op } = require('sequelize');
        const whereClause: any = {
            outlet_id: currentOutlet.id,
            is_active: true,
            show_in_quick_login: true
        };

        if (role) {
            const reqRole = role.toString().toUpperCase().trim();
            if (['WAITER', 'CAPTAIN', 'CAPTION', 'STEWARD', 'SERVER'].includes(reqRole)) {
                whereClause.role = {
                    [Op.in]: ['WAITER', 'CAPTAIN', 'CAPTION', 'STEWARD', 'SERVER', 'MANAGER', 'ADMIN']
                };
            } else {
                whereClause.role = {
                    [Op.in]: [reqRole, 'ADMIN', 'MANAGER']
                };
            }
        }

        const users = await db.models.users.findAll({
            where: whereClause,
            attributes: ['id', 'username', 'full_name', 'role', 'pin_code', 'show_in_quick_login'],
            order: [['full_name', 'ASC'], ['username', 'ASC']]
        });

        const formatted = users.map((u: any) => ({
            id: u.id,
            username: u.username,
            full_name: u.full_name || u.username,
            role: u.role,
            has_pin: !!(u.pin_code && u.pin_code.toString().trim().length > 0)
        }));

        return res.json({ success: true, data: formatted });
    } catch (err: any) {
        console.error('[GET QUICK USERS ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

exports.loginWithQrToken = async (req: any, res: any) => {
    try {
        const { qr_token, outlet_code } = req.body;
        const db = req.propertyDb;

        if (!qr_token || !qr_token.toString().trim()) {
            return res.status(400).json({ success: false, message: 'QR token is required.' });
        }

        const cleanToken = qr_token.toString().trim();

        let whereClause: any = {
            login_qr_token: cleanToken,
            is_active: true
        };

        let currentOutlet: any = null;
        if (outlet_code && outlet_code.trim()) {
            currentOutlet = await db.models.outlets.findOne({
                where: { outlet_code: outlet_code.trim(), is_active: true }
            });
            if (currentOutlet) {
                whereClause.outlet_id = currentOutlet.id;
            }
        }

        const user = await db.models.users.findOne({
            where: whereClause,
            bypassOutletFilter: true
        });

        if (!user) {
            return res.status(401).json({ success: false, message: 'Invalid or expired QR code. Please ask your administrator to re-generate your QR badge.' });
        }

        if (!currentOutlet) {
            currentOutlet = await db.models.outlets.findByPk(user.outlet_id, { bypassOutletFilter: true });
        }

        if (!currentOutlet || !currentOutlet.is_active) {
            return res.status(401).json({ success: false, message: 'Outlet is inactive.' });
        }

        let permissions: any[] = [];
        if (user.role === 'ADMIN') {
            permissions = ['*'];
        } else {
            const roleObj = db.models.roles ? await db.models.roles.findOne({ where: { role_name: user.role } }).catch(() => null) : null;
            permissions = roleObj?.permissions || ['POS_ACCESS', 'REPORTS_VIEW'];
        }

        const token = jwt.sign({
            user_id: user.id,
            outlet_id: currentOutlet.id,
            role: user.role,
            outlet_code: currentOutlet.outlet_code,
            business_module: resolveBusinessModule(currentOutlet.business_module, currentOutlet.outlet_type),
            permissions
        });

        await user.update({ last_login: new Date() });

        const property = await db.models.property_info.findOne({
            where: { outlet_id: currentOutlet.id },
            attributes: ['property_name', 'logo_path']
        }).catch(() => null);

        return res.json({
            success: true,
            message: `Welcome, ${user.full_name || user.username}!`,
            token,
            license_status: 'VALID',
            days_remaining: 999,
            user: {
                id: user.id,
                username: user.username,
                name: user.full_name,
                role: user.role,
                outlet_id: currentOutlet.id,
                outlet_code: currentOutlet.outlet_code,
                outlet_name: currentOutlet.outlet_name,
                business_module: resolveBusinessModule(currentOutlet.business_module, currentOutlet.outlet_type),
                property_name: property?.property_name || currentOutlet.outlet_name,
                logo_path: property?.logo_path || null,
                permissions
            }
        });
    } catch (err: any) {
        console.error('[QR LOGIN ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

module.exports = exports;
export default exports;
