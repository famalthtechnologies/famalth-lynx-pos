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
var clinic_routes_exports = {};
__export(clinic_routes_exports, {
  default: () => clinic_routes_default
});
module.exports = __toCommonJS(clinic_routes_exports);
var import_express = __toESM(require("express"));
const router = import_express.default.Router();
const auth = require("../middlewares/auth.middleware");
const clinicCtrl = require("../controllers/clinic/clinic.controller");
router.use(auth);
router.get("/appointments", clinicCtrl.getAppointments);
router.post("/appointments", clinicCtrl.createAppointment);
router.patch("/appointments/:id/status", clinicCtrl.updateAppointmentStatus);
router.post("/appointments/:id/prescription", clinicCtrl.savePrescription);
router.post("/appointments/:id/send-to-billing", clinicCtrl.sendToBillingDraft);
router.post("/appointments/:id/accept-and-pay", clinicCtrl.acceptAndPayAppointment);
router.patch("/appointments/:id/billing-complete", clinicCtrl.completeAppointmentBilling);
router.get("/patient-history", clinicCtrl.getClinicPatientHistory);
router.get("/patient-credit", clinicCtrl.getPatientCreditStatus);
router.post("/patient-credit/settle", clinicCtrl.settlePatientCredit);
router.get("/clinical-tests", clinicCtrl.getClinicalTestsMaster);
router.post("/clinical-tests", clinicCtrl.saveClinicalTestMaster);
router.get("/doctors", clinicCtrl.getClinicDoctors);
router.post("/doctors", clinicCtrl.createClinicDoctor);
router.put("/doctors/:id", clinicCtrl.updateClinicDoctor);
router.delete("/doctors/:id", clinicCtrl.deleteClinicDoctor);
router.get("/medicines", clinicCtrl.getAvailableMedicines);
router.get("/analytics", clinicCtrl.getClinicAnalytics);
router.get("/operating-status", clinicCtrl.getClinicOperatingStatus);
router.post("/toggle-closed-today", clinicCtrl.toggleClinicClosedToday);
router.get("/subscriptions", clinicCtrl.getClinicSubscriptions);
router.post("/subscriptions", clinicCtrl.createClinicSubscription);
router.post("/subscriptions/:id/consume", clinicCtrl.consumeClinicSubscriptionSession);
router.get("/subscriptions/:id/ledger", clinicCtrl.getClinicSubscriptionLedger);
module.exports = router;
var clinic_routes_default = router;
