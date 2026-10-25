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
var public_routes_exports = {};
__export(public_routes_exports, {
  default: () => public_routes_default
});
module.exports = __toCommonJS(public_routes_exports);
var import_express = __toESM(require("express"));
const router = import_express.default.Router();
const ctrl = require("../controllers/public/propertyInfo.controller");
const {
  verifyOutletForRecovery,
  executeFullSystemRecovery,
  requestRecoveryOtp,
  verifyRecoveryOtp,
  verifyAndRecoverConfig,
  triggerAutoReinstall
} = require("../controllers/public/recoveryController");
const outletCtrl = require("../controllers/public/outlet.controller");
const { checkSystemUpdate } = require("../controllers/public/updateController");
const {
  requestPasswordResetOtp,
  resetPasswordWithOtp,
  recoverUsername
} = require("../modules/passwordRecoveryController");
const { requestSetupOtp, verifySetupOtp } = require("../modules/verificationController");
router.post("/outlet/check", outletCtrl.checkOutlet);
router.post("/outlet/heartbeat", outletCtrl.heartbeat);
router.post("/outlet", outletCtrl.createOutlet);
router.put("/outlet/module", outletCtrl.updateOutletModule);
router.post("/outlet/module", outletCtrl.updateOutletModule);
router.get("/property-info", ctrl.getPropertyInfo);
router.get("/outlets", async (req, res) => {
  try {
    const { getLinkedOutletIds } = require("../utils/outletScopeHelper");
    const sessionOutletId = req.user?.outlet_id || req.query?.outlet_id;
    let where = { is_active: true };
    if (sessionOutletId) {
      const linkedIds = await getLinkedOutletIds(req, sessionOutletId);
      if (linkedIds.length > 0) {
        const { Op } = require("sequelize");
        where.id = { [Op.in]: linkedIds };
      }
    }
    const outlets = await req.propertyDb.models.outlets.findAll({
      where,
      attributes: ["id", "outlet_code", "outlet_name", "parent_outlet_id", "is_master"],
      bypassOutletFilter: true
    });
    return res.json({ success: true, data: outlets });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});
router.post("/recovery/verify-pin", verifyOutletForRecovery);
router.post("/recovery/execute", executeFullSystemRecovery);
router.post("/recovery/request-otp", requestRecoveryOtp);
router.post("/recovery/verify-otp", verifyRecoveryOtp);
router.post("/system/check-update", checkSystemUpdate);
router.post("/emergency-reset/recover-username", recoverUsername);
router.post("/emergency-reset/request-otp", requestPasswordResetOtp);
router.post("/emergency-reset/verify-and-reset", resetPasswordWithOtp);
router.post("/setup/request-otp", requestSetupOtp);
router.post("/setup/verify-otp", verifySetupOtp);
router.post("/verify-and-download", verifyAndRecoverConfig);
router.post("/trigger-reinstall", triggerAutoReinstall);
const publicSalesCtrl = require("../controllers/public/publicSales.controller");
router.get("/sales/:id/pdf", publicSalesCtrl.getInvoicePdfPublic);
const taxGroupCtrl = require("../controllers/settings/taxGroup.controller");
router.get("/settings/tax-groups", taxGroupCtrl.getTaxGroups);
router.post("/settings/tax-groups", taxGroupCtrl.createTaxGroup);
router.put("/settings/tax-groups/:id", taxGroupCtrl.updateTaxGroup);
const migrationCtrl = require("../controllers/public/migration.controller");
router.get("/migration/ping", migrationCtrl.ping);
router.post("/migration/ping", migrationCtrl.ping);
router.post("/migration/export-bundle", migrationCtrl.exportBundle);
router.post("/migration/import-bundle", migrationCtrl.importBundle);
router.post("/migration/sync-online-to-offline", migrationCtrl.syncOnlineToOffline);
const diningCtrl = require("../controllers/restaurant/dining.controller");
router.get("/dining/tables", diningCtrl.getPublicDiningTables);
router.get("/dining/table-info", diningCtrl.getTableDiningInfo);
router.post("/dining/request-otp", diningCtrl.requestCustomerDiningOtp);
router.post("/dining/verify-otp", diningCtrl.verifyCustomerDiningOtp);
router.post("/dining/register-profile", diningCtrl.registerCustomerDiningProfile);
router.post("/dining/place-order", diningCtrl.placeCustomerDiningOrder);
router.post("/dining/pay-bill", diningCtrl.payCustomerDiningBill);
router.post("/dining/call-waiter", diningCtrl.callTableWaiter);
router.post("/dining/book-table", diningCtrl.bookTablePublic);
const clinicCtrl = require("../controllers/clinic/clinic.controller");
router.get("/clinic/cities", clinicCtrl.getPublicDoctorCities);
router.get("/clinic/specialities", clinicCtrl.getPublicSpecialities);
router.get("/clinic/doctors", clinicCtrl.getPublicDoctors);
router.post("/clinic/request-email-otp", clinicCtrl.requestPatientEmailOtp);
router.post("/clinic/verify-email-otp", clinicCtrl.verifyPatientEmailOtp);
router.post("/clinic/appointment", clinicCtrl.bookAppointmentPublic);
router.get("/clinic/patient-history", clinicCtrl.getPatientHistoryPublic);
router.post("/clinic/cancel-appointment", clinicCtrl.cancelAppointmentPublic);
router.get("/clinic/operating-status", clinicCtrl.getClinicOperatingStatusPublic);
router.get("/clinic/my-subscriptions", clinicCtrl.getPublicPatientSubscriptions);
const { renderCustomerQrPage } = require("../controllers/public/customerQr.controller");
router.get("/customer-qr", renderCustomerQrPage);
const { renderUnsubscribePage } = require("../controllers/public/unsubscribe.controller");
router.get("/unsubscribe", renderUnsubscribePage);
module.exports = router;
var public_routes_default = router;
