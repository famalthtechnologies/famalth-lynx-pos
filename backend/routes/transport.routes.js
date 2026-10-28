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
var transport_routes_exports = {};
__export(transport_routes_exports, {
  default: () => transport_routes_default
});
module.exports = __toCommonJS(transport_routes_exports);
var import_express = require("express");
var import_transport = require("../controllers/inventory/transport.controller");
const auth = require("../middlewares/auth.middleware");
const router = (0, import_express.Router)();
router.use(auth);
router.get("/vehicles", import_transport.TransportController.listVehicles);
router.post("/vehicles", import_transport.TransportController.createVehicle);
router.put("/vehicles/:id", import_transport.TransportController.updateVehicle);
router.delete("/vehicles/:id", import_transport.TransportController.deleteVehicle);
router.get("/drivers", import_transport.TransportController.listDrivers);
router.post("/drivers", import_transport.TransportController.createDriver);
router.put("/drivers/:id", import_transport.TransportController.updateDriver);
router.delete("/drivers/:id", import_transport.TransportController.deleteDriver);
router.post("/assign-trip", import_transport.TransportController.assignTrip);
router.post("/verify-delivery", import_transport.TransportController.verifyDelivery);
router.post("/release-trip", import_transport.TransportController.releaseTrip);
router.get("/active-trips", import_transport.TransportController.getActiveTrips);
module.exports = router;
var transport_routes_default = router;
