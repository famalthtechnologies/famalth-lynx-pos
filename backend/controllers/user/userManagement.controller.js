var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
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
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);
var stdin_exports = {};
__export(stdin_exports, {
  default: () => stdin_default
});
module.exports = __toCommonJS(stdin_exports);
const audit = require("../../services/audit.service");
const bcrypt = require("bcryptjs");
const { Op } = require("sequelize");
const ROLE_PERMISSIONS = {
  ADMIN: ["*"],
  MANAGER: [
    "ITEM_REQUEST",
    "PURCHASE_ORDER",
    "STOCK_IN",
    "STOCK_OUT",
    "RETURN",
    "DAMAGE",
    "ITEM_MASTER",
    "SUPPLIER_MASTER",
    "STOCK_LOCATION",
    "STOCK_BALANCE",
    "DAMAGE_SUMMARY",
    "STOCK_IN_REPORT",
    "STOCK_OUT_REPORT",
    "DAMAGE_REPORT",
    "REQUEST_REPORT",
    "PURCHASE_REPORT",
    "RETURN_REPORT",
    "STOCK_TRANSFER",
    "PRODUCT_ASSEMBLY",
    "RETURN_ISSUE",
    "SUPPLIER_RETURN",
    "STOCK_TRANSFER_REPORT",
    "SUBMISSIONS_STATUS",
    "RETAIL_SALES",
    "REPRINT_SALES_BILL",
    "MODIFY_SALES_BILL",
    "MODIFY_SALES_PAYMENT",
    "RETAIL_SALES_REPORT",
    "CLOSING_REPORT",
    "CUSTOMER_APP",
    "RETAILER_CONSOLE",
    "RIDER_PORTAL",
    "CASH_LEDGER"
  ],
  STORE: [
    "ITEM_REQUEST",
    "PURCHASE_ORDER",
    "STOCK_IN",
    "STOCK_OUT",
    "RETURN",
    "DAMAGE",
    "ITEM_MASTER",
    "SUPPLIER_MASTER",
    "STOCK_LOCATION",
    "STOCK_BALANCE",
    "DAMAGE_SUMMARY",
    "STOCK_IN_REPORT",
    "STOCK_OUT_REPORT",
    "DAMAGE_REPORT",
    "REQUEST_REPORT",
    "PURCHASE_REPORT",
    "RETURN_REPORT",
    "STOCK_TRANSFER",
    "PRODUCT_ASSEMBLY",
    "RETURN_ISSUE",
    "SUPPLIER_RETURN",
    "STOCK_TRANSFER_REPORT",
    "SUBMISSIONS_STATUS"
  ],
  RETAIL: [
    "RETAIL_SALES",
    "REPRINT_SALES_BILL",
    "RETAIL_SALES_REPORT",
    "CLOSING_REPORT",
    "CUSTOMER_APP",
    "RETAILER_CONSOLE",
    "RIDER_PORTAL"
  ],
  ACCOUNTS: [
    "SUPPLIER_PAYMENT",
    "REPORTS",
    "STOCK_BALANCE",
    "DAMAGE_SUMMARY",
    "STOCK_IN_REPORT",
    "STOCK_OUT_REPORT",
    "RETAIL_SALES_REPORT",
    "CLOSING_REPORT",
    "PURCHASE_REPORT",
    "RETURN_REPORT",
    "REQUEST_REPORT",
    "DAMAGE_REPORT",
    "SUPPLIER_RETURN_REFUND",
    "PENDING_REFUNDS",
    "CASH_LEDGER",
    "STOCK_LEDGER_REPORT",
    "VENDOR_PAYMENT_REPORT",
    "SUBSCRIPTION_REPORT",
    "SCHEME_REPORT",
    "SCHEME_ANALYSIS",
    "LOYALTY_REPORT",
    "STORE_ANALYSIS",
    "BRAND_ANALYSIS",
    "SOURCE_ANALYSIS",
    "COMMISSION_REPORT",
    "PAYMENT_ANALYSIS",
    "AI_QUERY_ANALYTICS"
  ],
  HR: [
    "HR_EMPLOYEES",
    "HR_ATTENDANCE",
    "HR_PAYROLL",
    "HR_MASTERS"
  ],
  WAITER: [
    "RETAIL_SALES"
  ],
  CAPTAIN: [
    "RETAIL_SALES"
  ],
  DOCTOR: [
    "CLINIC_MODULE",
    "DOCTOR_DESK",
    "PRESCRIBE_MEDICINE",
    "PATIENT_HISTORY"
  ],
  RECEPTIONIST: [
    "CLINIC_MODULE",
    "RECEPTION_DESK",
    "APPOINTMENT_BOOKING",
    "ACCEPT_PAY_APPOINTMENT"
  ],
  PHARMACIST: [
    "CLINIC_MODULE",
    "PHARMACY_DESK",
    "RETAIL_SALES",
    "REPRINT_SALES_BILL"
  ]
};
const ROLE_MAX_DISCOUNTS = {
  ADMIN: 100,
  MANAGER: 50,
  STORE: 20,
  RETAIL: 15,
  CASHIER: 10,
  ACCOUNTS: 25,
  HR: 10,
  WAITER: 5,
  CAPTAIN: 15,
  KDS: 0,
  MARKETING: 25,
  DOCTOR: 20,
  RECEPTIONIST: 10,
  PHARMACIST: 15
};
exports.listUsers = async (req, res) => {
  const outlet_id = req.user.outlet_id;
  const isAdmin = (req.user.role || "").toUpperCase() === "ADMIN";
  const users = await req.propertyDb.models.users.findAll({
    where: { outlet_id },
    attributes: { exclude: ["password_hash"] }
  });
  const sanitized = users.map((u) => {
    const userJson = u.toJSON ? u.toJSON() : { ...u };
    if (!isAdmin) {
      userJson.pin_code = userJson.pin_code ? "\u2022\u2022\u2022\u2022" : null;
    }
    return userJson;
  });
  res.json({ success: true, data: sanitized });
};
exports.checkUsernameAvailability = async (req, res) => {
  try {
    const { username } = req.body;
    const outlet_id = req.user.outlet_id;
    if (!username || !username.trim()) {
      return res.status(400).json({ success: false, message: "Username is required" });
    }
    const cleanUsername = username.trim();
    if (cleanUsername.includes(" ")) {
      return res.status(400).json({ success: false, message: "Username cannot contain spaces" });
    }
    if (cleanUsername.length < 3 || cleanUsername.length > 30) {
      return res.status(400).json({ success: false, message: "Username must be between 3 and 30 characters" });
    }
    const usernameRegex = /^[a-zA-Z0-9][a-zA-Z0-9_]*$/;
    if (!usernameRegex.test(cleanUsername)) {
      return res.status(400).json({
        success: false,
        message: "Username can only contain letters, numbers, and underscores, and must start with a letter or number"
      });
    }
    const existing = await req.propertyDb.models.users.findOne({
      where: { username: cleanUsername }
    });
    if (existing) {
      return res.json({
        success: true,
        available: false,
        message: `Username '${cleanUsername}' is already taken. Please choose a unique username.`
      });
    }
    return res.json({
      success: true,
      available: true,
      message: `Username '${cleanUsername}' is available.`
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
exports.createUser = async (req, res) => {
  const {
    username,
    full_name,
    mobile,
    role,
    permissions,
    password,
    contact_email,
    max_discount_percent,
    pin_code,
    show_in_quick_login,
    speciality,
    qualification,
    registration_no,
    experience_years,
    consultation_fee,
    whatsapp_no,
    doctor_city,
    doctor_bio,
    available_days,
    is_public_listed,
    public_display_options
  } = req.body;
  const outlet_id = req.user.outlet_id;
  if (!username || !username.trim()) {
    return res.status(400).json({
      success: false,
      message: "Username is required"
    });
  }
  const cleanUsername = username.trim();
  if (cleanUsername.includes(" ")) {
    return res.status(400).json({
      success: false,
      message: "Username cannot contain spaces"
    });
  }
  if (cleanUsername.length < 3 || cleanUsername.length > 30) {
    return res.status(400).json({
      success: false,
      message: "Username must be between 3 and 30 characters"
    });
  }
  const usernameRegex = /^[a-zA-Z0-9][a-zA-Z0-9_]*$/;
  if (!usernameRegex.test(cleanUsername)) {
    return res.status(400).json({
      success: false,
      message: "Username can only contain letters, numbers, and underscores (no spaces or special characters), and must start with a letter or number"
    });
  }
  const existing = await req.propertyDb.models.users.findOne({
    where: { username: cleanUsername }
  });
  if (existing) {
    return res.status(400).json({
      success: false,
      message: `Username '${cleanUsername}' is already taken. Please choose a unique username.`
    });
  }
  if (!password) {
    return res.status(400).json({
      success: false,
      message: "Password is required"
    });
  }
  if (password.includes(" ")) {
    return res.status(400).json({
      success: false,
      message: "Password cannot contain spaces"
    });
  }
  if (password.length < 4) {
    return res.status(400).json({
      success: false,
      message: "Password must be at least 4 characters"
    });
  }
  const hash = await bcrypt.hash(password, 10);
  const cleanPin = pin_code ? pin_code.toString().trim() : null;
  if (cleanPin) {
    const existingPinUser = await req.propertyDb.models.users.findOne({
      where: {
        outlet_id,
        pin_code: cleanPin,
        is_active: true
      }
    });
    if (existingPinUser) {
      return res.status(400).json({
        success: false,
        message: `PIN code '${cleanPin}' is already assigned to active user '${existingPinUser.full_name || existingPinUser.username}'. Each user must have a unique PIN code.`
      });
    }
  }
  const defaultRoleDisc = ROLE_MAX_DISCOUNTS[role] ?? 10;
  const finalMaxDiscount = max_discount_percent !== void 0 && max_discount_percent !== null ? max_discount_percent : defaultRoleDisc;
  const user = await req.propertyDb.models.users.create({
    outlet_id,
    username: cleanUsername,
    full_name,
    mobile,
    contact_email,
    role,
    max_discount_percent: finalMaxDiscount,
    password_hash: hash,
    pin_code: cleanPin,
    show_in_quick_login: show_in_quick_login !== void 0 ? Boolean(show_in_quick_login) : false,
    speciality: speciality ? speciality.trim() : role === "DOCTOR" ? "General Physician" : null,
    qualification: qualification ? qualification.trim() : role === "DOCTOR" ? "MBBS" : null,
    registration_no: registration_no ? registration_no.trim() : null,
    experience_years: experience_years ? Number(experience_years) : 0,
    consultation_fee: consultation_fee ? Number(consultation_fee) : 0,
    whatsapp_no: whatsapp_no ? whatsapp_no.trim() : null,
    doctor_city: doctor_city ? doctor_city.trim() : null,
    doctor_bio: doctor_bio ? doctor_bio.trim() : null,
    available_days: available_days || "Mon,Tue,Wed,Thu,Fri,Sat",
    is_public_listed: is_public_listed !== void 0 ? Boolean(is_public_listed) : true,
    public_display_options: public_display_options || {
      show_clinic_name: true,
      show_doctor_name: true,
      show_address: true,
      show_phone: true,
      show_whatsapp: true,
      show_email: true,
      show_fees: true
    },
    is_active: true
  });
  let permsToAssign = permissions;
  if (!permsToAssign || permsToAssign.length === 0) {
    permsToAssign = ROLE_PERMISSIONS[role] || [];
  }
  if (permsToAssign == null ? void 0 : permsToAssign.length) {
    await req.propertyDb.models.user_permissions.bulkCreate(
      permsToAssign.map((p) => ({
        user_id: user.id,
        perm_key: p
      }))
    );
  }
  res.json({
    success: true,
    message: "User created successfully"
  });
};
exports.changePassword = async (req, res) => {
  const { username } = req.params;
  const { oldPassword, newPassword } = req.body;
  try {
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ success: false, message: "Old and new passwords are required." });
    }
    if (newPassword.includes(" ")) {
      return res.status(400).json({ success: false, message: "New password cannot contain spaces." });
    }
    if (newPassword.length < 4) {
      return res.status(400).json({ success: false, message: "New password must be at least 4 characters." });
    }
    const user = await req.propertyDb.models.users.findOne({
      where: { username, is_active: true }
    });
    if (!user) {
      return res.status(404).json({ success: false, message: "User not found." });
    }
    const isMatch = await bcrypt.compare(oldPassword, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Incorrect current password." });
    }
    const newHash = await bcrypt.hash(newPassword, 10);
    await user.update({ password_hash: newHash });
    res.json({ success: true, message: "Password updated successfully." });
  } catch (error) {
    console.error(`[AUTH] Change Password Error: ${error.message}`);
    res.status(500).json({ success: false, message: "An error occurred while changing the password." });
  }
};
exports.updateUser = async (req, res) => {
  const {
    full_name,
    mobile,
    role,
    contact_email,
    max_discount_percent,
    pin_code,
    show_in_quick_login,
    speciality,
    qualification,
    registration_no,
    experience_years,
    consultation_fee,
    whatsapp_no,
    doctor_city,
    doctor_bio,
    available_days,
    is_public_listed,
    public_display_options
  } = req.body;
  const user = await req.propertyDb.models.users.findByPk(req.params.id);
  if (!user) {
    return res.status(404).json({ success: false });
  }
  const oldData = user.toJSON();
  const roleChanged = role && role !== oldData.role;
  const updatePayload = { full_name, mobile, role, contact_email };
  if (speciality !== void 0) updatePayload.speciality = speciality ? speciality.trim() : null;
  if (qualification !== void 0) updatePayload.qualification = qualification ? qualification.trim() : null;
  if (registration_no !== void 0) updatePayload.registration_no = registration_no ? registration_no.trim() : null;
  if (experience_years !== void 0) updatePayload.experience_years = Number(experience_years);
  if (consultation_fee !== void 0) updatePayload.consultation_fee = Number(consultation_fee);
  if (whatsapp_no !== void 0) updatePayload.whatsapp_no = whatsapp_no ? whatsapp_no.trim() : null;
  if (doctor_city !== void 0) updatePayload.doctor_city = doctor_city ? doctor_city.trim() : null;
  if (doctor_bio !== void 0) updatePayload.doctor_bio = doctor_bio ? doctor_bio.trim() : null;
  if (available_days !== void 0) updatePayload.available_days = available_days;
  if (is_public_listed !== void 0) updatePayload.is_public_listed = Boolean(is_public_listed);
  if (public_display_options !== void 0) updatePayload.public_display_options = public_display_options;
  if (max_discount_percent !== void 0) {
    updatePayload.max_discount_percent = max_discount_percent;
  }
  if (pin_code !== void 0) {
    const cleanPin = pin_code ? pin_code.toString().trim() : null;
    if (cleanPin) {
      const existingPinUser = await req.propertyDb.models.users.findOne({
        where: {
          outlet_id: user.outlet_id,
          pin_code: cleanPin,
          is_active: true,
          id: { [Op.ne]: user.id }
        }
      });
      if (existingPinUser) {
        return res.status(400).json({
          success: false,
          message: `PIN code '${cleanPin}' is already assigned to active user '${existingPinUser.full_name || existingPinUser.username}'. Each user must have a unique PIN code.`
        });
      }
    }
    updatePayload.pin_code = cleanPin;
  }
  if (show_in_quick_login !== void 0) {
    updatePayload.show_in_quick_login = Boolean(show_in_quick_login);
  }
  await user.update(updatePayload);
  if (roleChanged) {
    await req.propertyDb.models.user_permissions.destroy({
      where: { user_id: user.id }
    });
    const defaultPerms = ROLE_PERMISSIONS[role] || [];
    if (defaultPerms.length > 0) {
      await req.propertyDb.models.user_permissions.bulkCreate(
        defaultPerms.map((p) => ({ user_id: user.id, perm_key: p }))
      );
    }
  }
  await audit.log({
    req,
    module: "USER",
    action: "UPDATE",
    table: "users",
    recordId: user.id,
    old_data: {},
    new_data: user.toJSON(),
    outlet_id: req.user.outlet_id,
    user_id: req.user.id
  });
  res.json({ success: true });
};
exports.toggleStatus = async (req, res) => {
  const user = await req.propertyDb.models.users.findByPk(req.params.id);
  if (!user) {
    return res.status(404).json({ success: false });
  }
  const oldStatus = user.is_active;
  await user.update({ is_active: !user.is_active });
  await audit.log({
    req,
    module: "USER",
    action: user.is_active ? "ACTIVATE" : "DEACTIVATE",
    table: "users",
    recordId: user.id,
    old_data: { is_active: oldStatus },
    new_data: { is_active: user.is_active },
    outlet_id: req.user.outlet_id,
    user_id: req.user.id
  });
  res.json({ success: true });
};
exports.resetPassword = async (req, res) => {
  const { password } = req.body;
  if (!password) {
    return res.status(400).json({ success: false, message: "Password is required." });
  }
  if (password.includes(" ")) {
    return res.status(400).json({ success: false, message: "Password cannot contain spaces." });
  }
  if (password.length < 4) {
    return res.status(400).json({ success: false, message: "Password must be at least 4 characters." });
  }
  const user = await req.propertyDb.models.users.findByPk(req.params.id);
  if (!user) {
    return res.status(404).json({ success: false });
  }
  const hash = await bcrypt.hash(password, 10);
  await user.update({
    password_hash: hash
  });
  res.json({
    success: true,
    message: "Password reset successfully"
  });
};
exports.updatePermissions = async (req, res) => {
  const t = await req.propertyDb.transaction();
  try {
    const outlet_id = req.user.outlet_id;
    const user_id = req.params.id;
    const { permissions } = req.body;
    if (!Array.isArray(permissions)) {
      await t.rollback();
      return res.status(400).json({ success: false, step: "INVALID_PERMISSIONS" });
    }
    const user = await req.propertyDb.models.users.findOne({
      where: { id: user_id, outlet_id },
      transaction: t
    });
    if (!user) {
      await t.rollback();
      return res.status(404).json({ success: false, step: "USER_NOT_FOUND" });
    }
    const oldPerms = await req.propertyDb.models.user_permissions.findAll({
      where: { user_id },
      transaction: t
    });
    await req.propertyDb.models.user_permissions.destroy({
      where: { user_id },
      transaction: t
    });
    if (permissions.length) {
      await req.propertyDb.models.user_permissions.bulkCreate(
        permissions.map((p) => ({ user_id, perm_key: p })),
        { transaction: t }
      );
    }
    await audit.log({
      req,
      module: "USER",
      action: "UPDATE_PERMISSIONS",
      table: "user_permissions",
      recordId: user_id,
      old_data: oldPerms.map((p) => p.perm_key),
      new_data: permissions,
      outlet_id: req.user.outlet_id,
      user_id: req.user.id
    });
    await t.commit();
    return res.json({
      success: true,
      saved: true,
      permissions
    });
  } catch (err) {
    await t.rollback();
    console.error("UPDATE_PERMISSIONS FAILED AT:", err);
    return res.status(500).json({
      success: false,
      saved: false,
      error: err.message
    });
  }
};
exports.getPermissions = async (req, res) => {
  try {
    const outlet_id = req.user.outlet_id;
    const user_id = req.params.id;
    const user = await req.propertyDb.models.users.findOne({
      where: { id: user_id, outlet_id }
    });
    if (!user) {
      return res.status(404).json({ success: false });
    }
    const perms = await req.propertyDb.models.user_permissions.findAll({
      where: { user_id },
      attributes: ["perm_key"]
    });
    res.json({
      success: true,
      data: perms.map((p) => p.perm_key)
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
};
const activeSupervisorOtps = /* @__PURE__ */ new Map();
exports.getSupervisorPin = async (req, res) => {
  try {
    const outlet_id = req.user.outlet_id;
    const isAdmin = (req.user.role || "").toUpperCase() === "ADMIN";
    if (!isAdmin) {
      return res.status(403).json({ success: false, message: "Only Administrators can view supervisor PIN settings" });
    }
    const outlet = await req.propertyDb.models.outlets.findOne({ where: { id: outlet_id } });
    res.json({
      success: true,
      supervisor_pin: (outlet == null ? void 0 : outlet.supervisor_pin) || "1234",
      supervisor_pin_type: (outlet == null ? void 0 : outlet.supervisor_pin_type) || "STATIC"
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
exports.updateSupervisorPin = async (req, res) => {
  try {
    const outlet_id = req.user.outlet_id;
    const { supervisor_pin, supervisor_pin_type } = req.body;
    const pinType = supervisor_pin_type || "STATIC";
    const pin = supervisor_pin && supervisor_pin.trim() ? supervisor_pin.trim() : "1234";
    const outlet = await req.propertyDb.models.outlets.findOne({ where: { id: outlet_id } });
    if (outlet) {
      await outlet.update({
        supervisor_pin: pin,
        supervisor_pin_type: pinType
      });
    }
    res.json({ success: true, message: "Supervisor PIN updated successfully!" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
exports.verifySupervisorPin = async (req, res) => {
  var _a;
  try {
    const outlet_id = (_a = req.user) == null ? void 0 : _a.outlet_id;
    const { pin } = req.body;
    if (!pin) {
      return res.status(400).json({ success: false, authorized: false, message: "PIN is required" });
    }
    const inputPin = String(pin).trim();
    const outlet = outlet_id ? await req.propertyDb.models.outlets.findOne({ where: { id: outlet_id } }) : null;
    const configuredPin = (outlet == null ? void 0 : outlet.supervisor_pin) || "1234";
    const pinType = (outlet == null ? void 0 : outlet.supervisor_pin_type) || "STATIC";
    const isStaticMatch = pinType === "STATIC" && inputPin === configuredPin;
    const activeOtp = activeSupervisorOtps.get(outlet_id);
    const isOtpMatch = activeOtp && activeOtp.code === inputPin && Date.now() - activeOtp.timestamp < 10 * 60 * 1e3;
    if (isStaticMatch || isOtpMatch) {
      if (isOtpMatch) activeSupervisorOtps.delete(outlet_id);
      return res.json({ success: true, authorized: true, message: "Supervisor override authorized!" });
    }
    res.status(401).json({ success: false, authorized: false, message: "Invalid Supervisor PIN or OTP!" });
  } catch (err) {
    res.status(500).json({ success: false, authorized: false, message: err.message });
  }
};
exports.sendSupervisorOtp = async (req, res) => {
  var _a, _b;
  try {
    const outlet_id = (_a = req.user) == null ? void 0 : _a.outlet_id;
    const outlet = await req.propertyDb.models.outlets.findOne({ where: { id: outlet_id } });
    const targetEmail = (outlet == null ? void 0 : outlet.contact_email) || ((_b = req.user) == null ? void 0 : _b.contact_email);
    if (!targetEmail) {
      return res.status(400).json({ success: false, message: "No contact email found for this outlet." });
    }
    const otpCode = Math.floor(1e5 + Math.random() * 9e5).toString();
    activeSupervisorOtps.set(outlet_id, { code: otpCode, timestamp: Date.now() });
    const emailService = require("../../services/email.service");
    await emailService.sendMail({
      db: req.propertyDb,
      outlet_id,
      to: targetEmail,
      subject: "\u{1F6E1}\uFE0F Supervisor Override One-Time Passcode (OTP)",
      text: `Your Supervisor Override OTP code is ${otpCode}. Valid for 10 minutes.`,
      html: `<h3>Supervisor Override Authorization</h3><p>Your one-time supervisor override code is: <strong>${otpCode}</strong></p><p>Valid for 10 minutes.</p>`
    });
    res.json({ success: true, message: `Supervisor Override OTP sent to ${targetEmail}` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
exports.regenerateUserQrToken = async (req, res) => {
  try {
    const userId = req.params.id || req.body.user_id;
    const outletId = req.user.outlet_id;
    const crypto = require("crypto");
    const user = await req.propertyDb.models.users.findOne({
      where: { id: userId, outlet_id: outletId }
    });
    if (!user) {
      return res.status(404).json({ success: false, message: "Staff user not found" });
    }
    const newToken = `LYNX-STAFF-${user.id}-${crypto.randomBytes(12).toString("hex").toUpperCase()}`;
    await user.update({ login_qr_token: newToken });
    return res.json({
      success: true,
      message: "Staff login QR code regenerated successfully. Previous QR codes are now invalidated.",
      data: {
        user_id: user.id,
        username: user.username,
        full_name: user.full_name,
        role: user.role,
        login_qr_token: newToken
      }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
exports.getUserQrToken = async (req, res) => {
  try {
    const userId = req.params.id;
    const outletId = req.user.outlet_id;
    const crypto = require("crypto");
    const user = await req.propertyDb.models.users.findOne({
      where: { id: userId, outlet_id: outletId }
    });
    if (!user) {
      return res.status(404).json({ success: false, message: "Staff user not found" });
    }
    let token = user.login_qr_token;
    if (!token) {
      token = `LYNX-STAFF-${user.id}-${crypto.randomBytes(12).toString("hex").toUpperCase()}`;
      await user.update({ login_qr_token: token });
    }
    const outlet = await req.propertyDb.models.outlets.findByPk(outletId);
    return res.json({
      success: true,
      data: {
        user_id: user.id,
        username: user.username,
        full_name: user.full_name,
        role: user.role,
        outlet_name: (outlet == null ? void 0 : outlet.outlet_name) || "Store",
        outlet_code: (outlet == null ? void 0 : outlet.outlet_code) || "",
        login_qr_token: token
      }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
module.exports = exports;
var stdin_default = exports;
