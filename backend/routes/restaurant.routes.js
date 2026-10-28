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
var restaurant_routes_exports = {};
__export(restaurant_routes_exports, {
  default: () => restaurant_routes_default
});
module.exports = __toCommonJS(restaurant_routes_exports);
var import_express = __toESM(require("express"));
const router = import_express.default.Router();
const auth = require("../middlewares/auth.middleware");
const tableCtrl = require("../controllers/restaurant/table.controller");
const printerCtrl = require("../controllers/restaurant/printer.controller");
const emailCtrl = require("../controllers/restaurant/email.controller");
const kotCtrl = require("../controllers/restaurant/kot.controller");
const challanCtrl = require("../controllers/restaurant/challan.controller");
router.use(auth);
router.get("/floors", tableCtrl.listFloors);
router.post("/floors", tableCtrl.createFloor);
router.put("/floors/:id", tableCtrl.updateFloor);
router.delete("/floors/:id", tableCtrl.deleteFloor);
router.get("/dining-areas", tableCtrl.listDiningAreas);
router.post("/dining-areas", tableCtrl.createDiningArea);
router.put("/dining-areas/:id", tableCtrl.updateDiningArea);
router.delete("/dining-areas/:id", tableCtrl.deleteDiningArea);
router.get("/table-types", tableCtrl.listTableTypes);
router.post("/table-types", tableCtrl.createTableType);
router.put("/table-types/:id", tableCtrl.updateTableType);
router.delete("/table-types/:id", tableCtrl.deleteTableType);
router.get("/tables", tableCtrl.listTables);
router.post("/tables", tableCtrl.createTable);
router.post("/tables/import", tableCtrl.importTables);
router.put("/tables/:id", tableCtrl.updateTable);
router.delete("/tables/:id", tableCtrl.deleteTable);
router.put("/tables/:id/status", tableCtrl.updateTableStatus);
router.post("/tables/:id/assign-user", tableCtrl.assignTableUser);
router.get("/tables/:id/transactions", tableCtrl.getTableTransactions);
router.post("/tables/transfer", tableCtrl.transferTable);
router.post("/tables/merge", tableCtrl.mergeTables);
router.get("/reservations", tableCtrl.listReservations);
router.post("/reservations", tableCtrl.createReservation);
router.put("/reservations/:id/status", tableCtrl.updateReservationStatus);
router.get("/printers", printerCtrl.listPrinters);
router.post("/printers", printerCtrl.createPrinter);
router.put("/printers/:id", printerCtrl.updatePrinter);
router.delete("/printers/:id", printerCtrl.deletePrinter);
router.get("/kitchen-stations", printerCtrl.listKitchenStations);
router.post("/kitchen-stations", printerCtrl.createKitchenStation);
router.put("/kitchen-stations/:id", printerCtrl.updateKitchenStation);
router.delete("/kitchen-stations/:id", printerCtrl.deleteKitchenStation);
router.get("/email-configurations", emailCtrl.getEmailConfig);
router.post("/email-configurations", emailCtrl.saveEmailConfig);
router.post("/email-configurations/test", emailCtrl.testEmail);
router.get("/settings/smtp", emailCtrl.getEmailConfig);
router.post("/settings/smtp", emailCtrl.saveEmailConfig);
router.post("/settings/smtp/test", emailCtrl.testEmail);
router.get("/email-templates", emailCtrl.listTemplates);
router.post("/email-templates", emailCtrl.saveTemplate);
router.get("/kots/next-no", kotCtrl.getNextKotNo);
router.get("/kots", kotCtrl.listKots);
router.get("/kots/:id", kotCtrl.getKotDetails);
router.post("/kots", kotCtrl.createKot);
router.put("/kots/:id/status", kotCtrl.updateKotStatus);
router.put("/kots/items/:itemId/status", kotCtrl.updateKotItemStatus);
router.put("/kots/:id", kotCtrl.modifyKot);
router.post("/kots/:id/reprint", kotCtrl.reprintKot);
router.get("/challans", challanCtrl.listChallans);
router.get("/challans/:id", challanCtrl.getChallanDetails);
router.post("/challans", challanCtrl.createChallan);
router.put("/challans/:id/status", challanCtrl.updateChallanStatus);
const { TransportController } = require("../controllers/inventory/transport.controller");
router.post("/challans/assign-trip", TransportController.assignTrip);
router.post("/challans/verify-delivery", TransportController.verifyDelivery);
router.post("/challans/release-trip", TransportController.releaseTrip);
router.get("/challans/active-trips", TransportController.getActiveTrips);
router.get("/transport/vehicles", TransportController.listVehicles);
router.post("/transport/vehicles", TransportController.createVehicle);
router.put("/transport/vehicles/:id", TransportController.updateVehicle);
router.delete("/transport/vehicles/:id", TransportController.deleteVehicle);
router.get("/transport/drivers", TransportController.listDrivers);
router.post("/transport/drivers", TransportController.createDriver);
router.put("/transport/drivers/:id", TransportController.updateDriver);
router.delete("/transport/drivers/:id", TransportController.deleteDriver);
const diningCtrl = require("../controllers/restaurant/dining.controller");
router.get("/dining/waiter-calls", diningCtrl.getActiveWaiterCalls);
router.post("/dining/resolve-waiter-call", diningCtrl.resolveWaiterCall);
router.post("/tables/:id/assistance", diningCtrl.callTableWaiter);
router.post("/tables/assistance/resolve", diningCtrl.resolveWaiterCall);
module.exports = router;
var restaurant_routes_default = router;
