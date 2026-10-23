"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StaffManagementController = void 0;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const crypto_1 = __importDefault(require("crypto"));
const sequelize_1 = require("sequelize");
const propertyDb_1 = __importDefault(require("../../db/propertyDb"));
const master_1 = __importDefault(require("../../models/master"));
const jwt_util_1 = require("../../utils/jwt.util");
const emailService_1 = require("../../modules/emailService");
const { MasterStaffUser, MasterReseller, MasterRelationshipManager } = (0, master_1.default)(propertyDb_1.default);
function maskEmail(email) {
    if (!email)
        return '';
    const [name, domain] = email.split('@');
    if (!name || !domain)
        return email;
    if (name.length <= 2)
        return `*@${domain}`;
    return `${name[0]}***${name[name.length - 1]}@${domain}`;
}
const controlPlaneLoginOtpStore = new Map();
const controlPlaneResetOtpStore = new Map();
const ownerSetupOtpStore = new Map();
class StaffManagementController {
    /**
     * 1. Master Staff Login (Completely Isolated from Merchant / Users table)
     */
    static async login(req, res) {
        try {
            const { username, password } = req.body;
            if (!username || !password) {
                return res.status(400).json({
                    success: false,
                    message: 'Username/Email and Password are required for Master Control Plane access.',
                });
            }
            const cleanIdentifier = String(username).trim().toLowerCase();
            // Look up staff strictly in master_staff_users
            const staff = await MasterStaffUser.findOne({
                where: {
                    [sequelize_1.Op.or]: [
                        { username: cleanIdentifier },
                        { email: cleanIdentifier },
                    ],
                },
            });
            if (!staff) {
                return res.status(401).json({
                    success: false,
                    error_code: 'INVALID_CREDENTIALS',
                    message: 'Invalid Control Plane username or credentials.',
                });
            }
            const staffIsActive = staff.get('is_active') ?? staff.dataValues?.is_active ?? staff.is_active;
            if (!staffIsActive) {
                return res.status(403).json({
                    success: false,
                    error_code: 'ACCOUNT_DEACTIVATED',
                    message: 'Your Master Control Plane operator account has been deactivated.',
                });
            }
            // Check password
            const staffPasswordHash = staff.get('password_hash') || staff.dataValues?.password_hash || staff.password_hash;
            const isMatch = await bcryptjs_1.default.compare(password, staffPasswordHash);
            if (!isMatch) {
                return res.status(401).json({
                    success: false,
                    error_code: 'INVALID_CREDENTIALS',
                    message: 'Invalid Control Plane username or credentials.',
                });
            }
            const staffId = staff.get('id') || staff.dataValues?.id || staff.id;
            const staffUsername = staff.get('username') || staff.dataValues?.username || staff.username;
            const staffEmail = staff.get('email') || staff.dataValues?.email || staff.email;
            const staffRole = staff.get('role') || staff.dataValues?.role || staff.role;
            const staffResellerId = staff.get('reseller_id') || staff.dataValues?.reseller_id || staff.reseller_id;
            const staffPermissions = staff.get('permissions') || staff.dataValues?.permissions || staff.permissions || [];
            const staffFullName = staff.get('full_name') || staff.dataValues?.full_name || staff.full_name;
            const staffPhone = staff.get('phone') || staff.dataValues?.phone || staff.phone;
            const staffAvatarUrl = staff.get('avatar_url') || staff.dataValues?.avatar_url || staff.avatar_url;
            // 2-Step Verification: Generate 6-digit OTP and send to operator's email
            const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
            const loginSessionToken = crypto_1.default.randomUUID();
            controlPlaneLoginOtpStore.set(loginSessionToken, {
                otp: otpCode,
                expiresAt: Date.now() + 600000, // 10 minutes
                lastSentAt: Date.now(),
                staffId,
                staffData: {
                    id: staffId,
                    username: staffUsername,
                    email: staffEmail,
                    full_name: staffFullName,
                    role: staffRole,
                    reseller_id: staffResellerId,
                    permissions: staffPermissions,
                    phone: staffPhone,
                    avatar_url: staffAvatarUrl,
                },
            });
            console.log(`🔑 [LOGIN 2FA OTP] Target: ${staffEmail} | Verification Code: ${otpCode}`);
            try {
                await (0, emailService_1.sendOtpEmail)(staffEmail, otpCode, 'Famalth Lynx Cloud Console - 2-Step Login Verification');
            }
            catch (err) {
                console.warn('[LOGIN 2FA] Warning sending OTP email:', err.message);
            }
            return res.json({
                success: true,
                requires_otp: true,
                login_session_token: loginSessionToken,
                masked_email: maskEmail(staffEmail),
                message: `2-Step verification code sent to ${maskEmail(staffEmail)}. Please enter the 6-digit code.`,
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Master Staff login failed: ' + error.message,
            });
        }
    }
    /**
     * 1.1 Verify Login 2FA OTP
     */
    static async verifyLoginOtp(req, res) {
        try {
            const { login_session_token, otp } = req.body;
            if (!login_session_token || !otp) {
                return res.status(400).json({
                    success: false,
                    message: 'Login session token and 6-digit OTP code are required.',
                });
            }
            const session = controlPlaneLoginOtpStore.get(login_session_token);
            if (!session) {
                return res.status(400).json({
                    success: false,
                    message: 'Login session expired or invalid. Please log in again.',
                });
            }
            if (Date.now() > session.expiresAt) {
                controlPlaneLoginOtpStore.delete(login_session_token);
                return res.status(400).json({
                    success: false,
                    message: 'Verification code has expired. Please request a new code.',
                });
            }
            if (session.otp !== String(otp).trim()) {
                return res.status(401).json({
                    success: false,
                    message: 'Invalid verification code. Please check your email.',
                });
            }
            // Valid OTP: delete session from store
            controlPlaneLoginOtpStore.delete(login_session_token);
            // Update last login in database
            await MasterStaffUser.update({ last_login_at: new Date() }, { where: { id: session.staffId } });
            const staff = session.staffData;
            const tokenPayload = {
                staff_id: staff.id,
                username: staff.username,
                email: staff.email,
                role: staff.role,
                reseller_id: staff.reseller_id,
                permissions: staff.permissions,
                is_control_plane: true,
            };
            const token = (0, jwt_util_1.sign)(tokenPayload, { expiresIn: '7d' });
            return res.json({
                success: true,
                message: 'Master Control Plane authenticated successfully.',
                data: {
                    token,
                    user: {
                        ...staff,
                        last_login_at: new Date(),
                    },
                },
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'OTP Verification failed: ' + error.message,
            });
        }
    }
    /**
     * 1.2 Resend Login 2FA OTP
     */
    static async resendLoginOtp(req, res) {
        try {
            const { login_session_token } = req.body;
            if (!login_session_token) {
                return res.status(400).json({
                    success: false,
                    message: 'Login session token is required.',
                });
            }
            const session = controlPlaneLoginOtpStore.get(login_session_token);
            if (!session) {
                return res.status(400).json({
                    success: false,
                    message: 'Session expired. Please log in again.',
                });
            }
            const timeSince = Date.now() - session.lastSentAt;
            if (timeSince < 45000) {
                const waitSecs = Math.ceil((45000 - timeSince) / 1000);
                return res.status(429).json({
                    success: false,
                    message: `Please wait ${waitSecs} seconds before requesting a new code.`,
                });
            }
            const newOtp = Math.floor(100000 + Math.random() * 900000).toString();
            session.otp = newOtp;
            session.expiresAt = Date.now() + 600000;
            session.lastSentAt = Date.now();
            console.log(`🔑 [RESEND LOGIN 2FA OTP] Target: ${session.staffData.email} | Code: ${newOtp}`);
            try {
                await (0, emailService_1.sendOtpEmail)(session.staffData.email, newOtp, 'Famalth Lynx Cloud Console - 2-Step Login Verification');
            }
            catch (err) {
                console.warn('[LOGIN 2FA] Warning sending OTP email:', err.message);
            }
            return res.json({
                success: true,
                message: `New verification code sent to ${maskEmail(session.staffData.email)}.`,
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Failed to resend code: ' + error.message,
            });
        }
    }
    /**
     * 1.1 Check Setup & Initialization Status
     */
    static async getSetupStatus(req, res) {
        try {
            const totalStaff = await MasterStaffUser.count();
            const defaultAdmin = await MasterStaffUser.findOne({
                where: {
                    username: 'admin',
                    email: 'admin@famalth.com',
                },
            });
            const needs_setup = totalStaff === 0 || !!defaultAdmin;
            const is_initialized = !needs_setup;
            return res.json({
                success: true,
                data: {
                    total_operators: totalStaff,
                    needs_setup,
                    is_initialized,
                    can_claim_default: !!defaultAdmin,
                },
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Status error: ' + error.message });
        }
    }
    /**
     * 1.2 Request OTP for Software Owner Initial Email Verification
     */
    static async requestOwnerSetupOtp(req, res) {
        try {
            const { email } = req.body;
            if (!email || !String(email).includes('@')) {
                return res.status(400).json({
                    success: false,
                    message: 'A valid email address is required for owner verification.',
                });
            }
            const totalStaff = await MasterStaffUser.count();
            const defaultAdmin = await MasterStaffUser.findOne({
                where: { username: 'admin', email: 'admin@famalth.com' },
            });
            if (totalStaff > 0 && !defaultAdmin) {
                return res.status(403).json({
                    success: false,
                    message: 'Master Control Plane has already been initialized. Public registration is closed for security.',
                });
            }
            const cleanEmail = String(email).trim().toLowerCase();
            // Check cooldown (60 seconds)
            const existing = ownerSetupOtpStore.get(cleanEmail);
            if (existing) {
                const timeSince = Date.now() - existing.lastSentAt;
                if (timeSince < 60000) {
                    const waitSecs = Math.ceil((60000 - timeSince) / 1000);
                    return res.status(429).json({
                        success: false,
                        message: `Please wait ${waitSecs} seconds before requesting another verification code.`,
                    });
                }
            }
            const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
            ownerSetupOtpStore.set(cleanEmail, {
                otp: otpCode,
                expiresAt: Date.now() + 600000, // 10 minutes
                lastSentAt: Date.now(),
            });
            console.log(`[OWNER_SETUP] Verification code for ${cleanEmail}: ${otpCode}`);
            try {
                await (0, emailService_1.sendOtpEmail)(cleanEmail, otpCode, 'Famalth Software Owner Email Verification');
            }
            catch (err) {
                console.warn('[OWNER_SETUP] Warning sending OTP email:', err.message);
            }
            return res.json({
                success: true,
                message: `Verification code sent to ${cleanEmail}. Please enter the 6-digit code.`,
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Failed to send verification code: ' + error.message });
        }
    }
    /**
     * 1.3 First-Time Master Owner Account Initialization (Air-Gapped Setup)
     * Allowed ONLY if totalStaff === 0 OR claiming default seed account
     */
    static async initializeMasterOwner(req, res) {
        try {
            const { full_name, username, email, phone, password, otp } = req.body;
            if (!full_name || !username || !email || !password) {
                return res.status(400).json({
                    success: false,
                    message: 'Full Name, Username, Registered Email, and Master Password are required.',
                });
            }
            if (!otp) {
                return res.status(400).json({
                    success: false,
                    message: '6-digit email verification code is required to verify ownership of this email address.',
                });
            }
            if (password.length < 8) {
                return res.status(400).json({
                    success: false,
                    message: 'Master password must be at least 8 characters long.',
                });
            }
            const totalStaff = await MasterStaffUser.count();
            const defaultAdmin = await MasterStaffUser.findOne({
                where: { username: 'admin', email: 'admin@famalth.com' },
            });
            // Prevent open registration if system is already initialized with real owner account
            if (totalStaff > 0 && !defaultAdmin) {
                return res.status(403).json({
                    success: false,
                    message: 'Master Control Plane has already been initialized. Public registration is closed for security.',
                });
            }
            const cleanUsername = String(username).trim().toLowerCase();
            const cleanEmail = String(email).trim().toLowerCase();
            // Verify OTP to prevent wrong/typo email registration
            const storedOtp = ownerSetupOtpStore.get(cleanEmail);
            if (!storedOtp) {
                return res.status(400).json({
                    success: false,
                    message: 'No verification code found for this email. Please click "Send Verification Code" first.',
                });
            }
            if (Date.now() > storedOtp.expiresAt) {
                ownerSetupOtpStore.delete(cleanEmail);
                return res.status(400).json({
                    success: false,
                    message: 'Verification code has expired. Please request a new code.',
                });
            }
            if (storedOtp.otp !== String(otp).trim()) {
                return res.status(401).json({
                    success: false,
                    message: 'Invalid verification code. Please check your email inbox.',
                });
            }
            ownerSetupOtpStore.delete(cleanEmail);
            const salt = await bcryptjs_1.default.genSalt(10);
            const password_hash = await bcryptjs_1.default.hash(password, salt);
            let rootStaff;
            if (defaultAdmin) {
                // Upgrade existing seed admin with real software owner data
                await defaultAdmin.update({
                    full_name: full_name.trim(),
                    username: cleanUsername,
                    email: cleanEmail,
                    phone: phone ? String(phone).trim() : null,
                    password_hash,
                    role: 'SUPER_ADMIN',
                    permissions: ['*'],
                    is_active: true,
                    last_login_at: new Date(),
                });
                rootStaff = defaultAdmin;
            }
            else {
                // Create fresh root Super Admin
                rootStaff = await MasterStaffUser.create({
                    full_name: full_name.trim(),
                    username: cleanUsername,
                    email: cleanEmail,
                    phone: phone ? String(phone).trim() : null,
                    password_hash,
                    role: 'SUPER_ADMIN',
                    permissions: ['*'],
                    is_active: true,
                    last_login_at: new Date(),
                });
            }
            // Generate JWT Token for immediate login
            const tokenPayload = {
                staff_id: rootStaff.id,
                username: rootStaff.username,
                email: rootStaff.email,
                role: 'SUPER_ADMIN',
                reseller_id: null,
                permissions: ['*'],
                is_control_plane: true,
            };
            const token = (0, jwt_util_1.sign)(tokenPayload, { expiresIn: '7d' });
            return res.status(201).json({
                success: true,
                message: 'Master Software Owner account successfully initialized. Welcome to Famalth Lynx!',
                data: {
                    token,
                    user: {
                        id: rootStaff.id,
                        username: rootStaff.username,
                        email: rootStaff.email,
                        full_name: rootStaff.full_name,
                        role: rootStaff.role,
                        phone: rootStaff.phone,
                        permissions: rootStaff.permissions,
                    },
                },
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Initialization failed: ' + error.message });
        }
    }
    /**
     * 2. Get Current Authenticated Staff Profile
     */
    static async getProfile(req, res) {
        try {
            const staffId = req.masterStaff?.staff_id;
            if (!staffId) {
                return res.status(401).json({ success: false, message: 'Unauthenticated.' });
            }
            const staff = await MasterStaffUser.findByPk(staffId, {
                attributes: { exclude: ['password_hash'] },
            });
            if (!staff) {
                return res.status(404).json({ success: false, message: 'Staff member not found.' });
            }
            return res.json({
                success: true,
                data: staff,
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Failed to retrieve profile: ' + error.message,
            });
        }
    }
    /**
     * 3. List Staff Members (Scoped by Reseller if calling user is RESELLER_ADMIN)
     */
    static async listStaff(req, res) {
        try {
            const callingRole = req.masterStaff?.role;
            const resellerId = req.masterStaff?.reseller_id;
            const whereClause = {};
            // If reseller admin, only show their staff
            if (callingRole === 'RESELLER_ADMIN' && resellerId) {
                whereClause.reseller_id = resellerId;
            }
            const staffMembers = await MasterStaffUser.findAll({
                where: whereClause,
                attributes: { exclude: ['password_hash'] },
                order: [['created_at', 'DESC']],
            });
            const resellers = await MasterReseller.findAll({
                attributes: ['id', 'reseller_code', 'company_name', 'allocated_license_credits'],
                where: { is_active: true },
            });
            return res.json({
                success: true,
                data: {
                    staff: staffMembers,
                    resellers,
                },
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Failed to list staff: ' + error.message,
            });
        }
    }
    /**
     * 4. Create New Master Staff / Operator / Reseller
     */
    static async createStaff(req, res) {
        try {
            const { username, email, password, full_name, role, reseller_id, permissions, phone, } = req.body;
            if (!username || !email || !password || !full_name) {
                return res.status(400).json({
                    success: false,
                    message: 'Username, Email, Password, and Full Name are required.',
                });
            }
            const cleanUsername = String(username).trim().toLowerCase();
            const cleanEmail = String(email).trim().toLowerCase();
            // Check unique
            const existing = await MasterStaffUser.findOne({
                where: {
                    [sequelize_1.Op.or]: [{ username: cleanUsername }, { email: cleanEmail }],
                },
            });
            if (existing) {
                return res.status(409).json({
                    success: false,
                    message: 'A staff user with this username or email already exists.',
                });
            }
            const salt = await bcryptjs_1.default.genSalt(10);
            const password_hash = await bcryptjs_1.default.hash(password, salt);
            const targetRole = role || 'SUPPORT_AGENT';
            const newStaff = await MasterStaffUser.create({
                username: cleanUsername,
                email: cleanEmail,
                password_hash,
                full_name,
                role: targetRole,
                reseller_id: reseller_id || null,
                permissions: permissions || (targetRole === 'SUPER_ADMIN' ? ['*'] : (targetRole === 'RM' ? ['tenants:read', 'support:read', 'support:write', 'rms:read'] : [])),
                phone: phone || null,
                is_active: true,
            });
            // If onboarded with role 'RM', synchronize with MasterRelationshipManager
            if (targetRole === 'RM') {
                const existingRm = await MasterRelationshipManager.findOne({ where: { email: cleanEmail } });
                if (existingRm) {
                    await existingRm.update({
                        full_name,
                        phone: phone || existingRm.phone,
                        is_active: true,
                    });
                }
                else {
                    const rmCode = `RM-${Date.now().toString(36).toUpperCase()}`;
                    await MasterRelationshipManager.create({
                        rm_code: rmCode,
                        full_name,
                        email: cleanEmail,
                        phone: phone || '',
                        whatsapp_number: phone || '',
                        designation: 'Account Relationship Specialist',
                        is_active: true,
                    });
                }
            }
            return res.status(201).json({
                success: true,
                message: 'Staff member onboarded successfully.',
                data: {
                    id: newStaff.id,
                    username: newStaff.username,
                    email: newStaff.email,
                    full_name: newStaff.full_name,
                    role: newStaff.role,
                    reseller_id: newStaff.reseller_id,
                    permissions: newStaff.permissions,
                    is_active: newStaff.is_active,
                },
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Failed to create staff member: ' + error.message,
            });
        }
    }
    /**
     * 5. Update Staff Role & Permissions
     */
    static async updateStaffRole(req, res) {
        try {
            const id = String(req.params.id);
            const { role, permissions, reseller_id, full_name, phone } = req.body;
            const staff = await MasterStaffUser.findByPk(id);
            if (!staff) {
                return res.status(404).json({ success: false, message: 'Staff user not found.' });
            }
            const updates = {};
            if (role)
                updates.role = role;
            if (permissions)
                updates.permissions = permissions;
            if (reseller_id !== undefined)
                updates.reseller_id = reseller_id;
            if (full_name)
                updates.full_name = full_name;
            if (phone !== undefined)
                updates.phone = phone;
            await staff.update(updates);
            return res.json({
                success: true,
                message: 'Staff profile updated successfully.',
                data: {
                    id: staff.id,
                    username: staff.username,
                    full_name: staff.full_name,
                    role: staff.role,
                    permissions: staff.permissions,
                    reseller_id: staff.reseller_id,
                },
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Failed to update staff: ' + error.message,
            });
        }
    }
    /**
     * 6. Toggle Staff Active Status (Deactivate / Reactivate Operator)
     */
    static async toggleStaffStatus(req, res) {
        try {
            const id = String(req.params.id);
            const { is_active } = req.body;
            const staff = await MasterStaffUser.findByPk(id);
            if (!staff) {
                return res.status(404).json({ success: false, message: 'Staff member not found.' });
            }
            // Prevent deactivating own account
            if (staff.id === req.masterStaff?.staff_id && is_active === false) {
                return res.status(400).json({
                    success: false,
                    message: 'You cannot deactivate your own active session.',
                });
            }
            await staff.update({ is_active: !!is_active });
            return res.json({
                success: true,
                message: `Staff status updated to ${is_active ? 'ACTIVE' : 'DEACTIVATED'}.`,
                data: { id: staff.id, is_active: staff.is_active },
            });
        }
        catch (error) {
            return res.status(500).json({
                success: false,
                message: 'Failed to toggle status: ' + error.message,
            });
        }
    }
    /**
     * 7. Recover Username by Email (Sends email with active usernames)
     */
    static async recoverUsername(req, res) {
        try {
            const { email } = req.body;
            if (!email) {
                return res.status(400).json({ success: false, message: 'Registered email address is required.' });
            }
            const cleanEmail = String(email).trim().toLowerCase();
            const staffList = await MasterStaffUser.findAll({
                where: { email: cleanEmail, is_active: true },
            });
            if (!staffList || staffList.length === 0) {
                return res.status(404).json({
                    success: false,
                    message: 'No registered Control Plane operator account found with this email.',
                });
            }
            const usernames = staffList
                .map((s) => (typeof s.get === 'function' ? s.get('username') : (s.dataValues?.username || s.username)))
                .filter((u) => u && String(u).trim().length > 0 && String(u).trim() !== 'undefined');
            try {
                await (0, emailService_1.sendUsernameRecoveryEmail)(cleanEmail, usernames, 'Famalth Enterprise Master Console');
            }
            catch (err) {
                console.warn('[ControlPlane] Warning sending recovery email:', err.message);
            }
            return res.json({
                success: true,
                message: `Recovery email sent to ${maskEmail(cleanEmail)}. Please check your inbox for active usernames.`,
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Recovery error: ' + error.message });
        }
    }
    /**
     * 8. Request OTP for Password Reset
     */
    static async requestPasswordResetOtp(req, res) {
        try {
            const { usernameOrEmail } = req.body;
            if (!usernameOrEmail) {
                return res.status(400).json({
                    success: false,
                    message: 'Operator Username or Registered Email is required.',
                });
            }
            const identifier = String(usernameOrEmail).trim().toLowerCase();
            const staff = await MasterStaffUser.findOne({
                where: {
                    [sequelize_1.Op.or]: [{ username: identifier }, { email: identifier }],
                    is_active: true,
                },
            });
            if (!staff) {
                return res.status(404).json({
                    success: false,
                    message: 'No active Control Plane operator account found with that identifier.',
                });
            }
            const staffEmail = staff.get('email') || staff.dataValues?.email || staff.email;
            const staffIdVal = staff.get('id') || staff.dataValues?.id || staff.id;
            const staffUsername = staff.get('username') || staff.dataValues?.username || staff.username;
            if (!staffEmail) {
                return res.status(400).json({
                    success: false,
                    message: 'This operator account has no email address configured for OTP verification.',
                });
            }
            // 2-minute cooldown
            const existing = controlPlaneResetOtpStore.get(staffIdVal);
            if (existing) {
                const timeSince = Date.now() - existing.issuedAt;
                if (timeSince < 120000) {
                    const waitSecs = Math.ceil((120000 - timeSince) / 1000);
                    return res.status(429).json({
                        success: false,
                        message: `Please wait ${waitSecs} seconds before requesting a new OTP.`,
                    });
                }
            }
            const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
            controlPlaneResetOtpStore.set(staffIdVal, {
                otp: otpCode,
                staffId: staffIdVal,
                expiresAt: Date.now() + 600000, // 10 minutes
                issuedAt: Date.now(),
            });
            try {
                await (0, emailService_1.sendOtpEmail)(staffEmail, otpCode, 'Famalth Control Plane Password Reset');
            }
            catch (err) {
                console.warn('[ControlPlane] Warning sending OTP email:', err.message);
            }
            return res.json({
                success: true,
                message: `OTP sent successfully to ${maskEmail(staffEmail)}. Please check your inbox.`,
                data: {
                    staffId: staffIdVal,
                    maskedEmail: maskEmail(staffEmail),
                    username: staffUsername,
                },
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Failed to request OTP: ' + error.message });
        }
    }
    /**
     * 9. Verify OTP & Reset Password
     */
    static async verifyAndResetPassword(req, res) {
        try {
            const { staffId, usernameOrEmail, otp, newPassword } = req.body;
            if (!newPassword || newPassword.length < 8) {
                return res.status(400).json({
                    success: false,
                    message: 'New password must be at least 8 characters long.',
                });
            }
            if (!otp) {
                return res.status(400).json({ success: false, message: 'OTP code is required.' });
            }
            let staff = null;
            if (staffId) {
                staff = await MasterStaffUser.findByPk(staffId);
            }
            else if (usernameOrEmail) {
                const identifier = String(usernameOrEmail).trim().toLowerCase();
                staff = await MasterStaffUser.findOne({
                    where: {
                        [sequelize_1.Op.or]: [{ username: identifier }, { email: identifier }],
                        is_active: true,
                    },
                });
            }
            if (!staff) {
                return res.status(404).json({ success: false, message: 'Operator account not found.' });
            }
            const staffIdVal = staff.get('id') || staff.dataValues?.id || staff.id;
            const stored = controlPlaneResetOtpStore.get(staffIdVal);
            if (!stored) {
                return res.status(400).json({
                    success: false,
                    message: 'No active password reset request found or OTP has expired. Please request a new OTP.',
                });
            }
            if (Date.now() > stored.expiresAt) {
                controlPlaneResetOtpStore.delete(staffIdVal);
                return res.status(400).json({
                    success: false,
                    message: 'This OTP has expired. Please request a new one.',
                });
            }
            if (stored.otp !== String(otp).trim()) {
                return res.status(401).json({ success: false, message: 'Invalid OTP code.' });
            }
            const salt = await bcryptjs_1.default.genSalt(10);
            const password_hash = await bcryptjs_1.default.hash(newPassword, salt);
            await staff.update({ password_hash });
            controlPlaneResetOtpStore.delete(staffIdVal);
            return res.json({
                success: true,
                message: 'Password has been reset successfully. You can now log in.',
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Reset password failed: ' + error.message });
        }
    }
    /**
     * 10. Authenticated Self-Service Password Change
     */
    static async changePassword(req, res) {
        try {
            const staffId = req.masterStaff?.staff_id;
            const { currentPassword, newPassword } = req.body;
            if (!currentPassword || !newPassword) {
                return res.status(400).json({
                    success: false,
                    message: 'Current password and new password are required.',
                });
            }
            if (newPassword.length < 8) {
                return res.status(400).json({
                    success: false,
                    message: 'New password must be at least 8 characters long.',
                });
            }
            const staff = await MasterStaffUser.findByPk(staffId);
            if (!staff) {
                return res.status(404).json({ success: false, message: 'Staff user not found.' });
            }
            const isMatch = await bcryptjs_1.default.compare(currentPassword, staff.password_hash);
            if (!isMatch) {
                return res.status(401).json({ success: false, message: 'Current password is incorrect.' });
            }
            const salt = await bcryptjs_1.default.genSalt(10);
            const password_hash = await bcryptjs_1.default.hash(newPassword, salt);
            await staff.update({ password_hash });
            return res.json({
                success: true,
                message: 'Password changed successfully.',
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Change password failed: ' + error.message });
        }
    }
    /**
     * 11. Admin Reset Staff Password (SUPER_ADMIN or RESELLER_ADMIN)
     */
    static async adminResetStaffPassword(req, res) {
        try {
            const id = String(req.params.id);
            const { newPassword } = req.body;
            if (!newPassword || newPassword.length < 8) {
                return res.status(400).json({
                    success: false,
                    message: 'New password must be at least 8 characters long.',
                });
            }
            const staff = await MasterStaffUser.findByPk(id);
            if (!staff) {
                return res.status(404).json({ success: false, message: 'Staff user not found.' });
            }
            const salt = await bcryptjs_1.default.genSalt(10);
            const password_hash = await bcryptjs_1.default.hash(newPassword, salt);
            await staff.update({ password_hash });
            return res.json({
                success: true,
                message: `Password for ${staff.username} has been reset successfully.`,
            });
        }
        catch (error) {
            return res.status(500).json({ success: false, message: 'Admin reset failed: ' + error.message });
        }
    }
}
exports.StaffManagementController = StaffManagementController;
exports.default = StaffManagementController;
