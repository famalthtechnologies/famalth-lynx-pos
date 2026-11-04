"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const transport_controller_1 = require("../controllers/inventory/transport.controller");
const auth = require('../middlewares/auth.middleware');
const router = (0, express_1.Router)();
router.use(auth);
// Vehicle endpoints
router.get('/vehicles', transport_controller_1.TransportController.listVehicles);
router.post('/vehicles', transport_controller_1.TransportController.createVehicle);
router.put('/vehicles/:id', transport_controller_1.TransportController.updateVehicle);
router.delete('/vehicles/:id', transport_controller_1.TransportController.deleteVehicle);
// Driver endpoints
router.get('/drivers', transport_controller_1.TransportController.listDrivers);
router.post('/drivers', transport_controller_1.TransportController.createDriver);
router.put('/drivers/:id', transport_controller_1.TransportController.updateDriver);
router.delete('/drivers/:id', transport_controller_1.TransportController.deleteDriver);
// Trip & Delivery Challan Logistics endpoints
router.post('/assign-trip', transport_controller_1.TransportController.assignTrip);
router.post('/verify-delivery', transport_controller_1.TransportController.verifyDelivery);
router.post('/release-trip', transport_controller_1.TransportController.releaseTrip);
router.get('/active-trips', transport_controller_1.TransportController.getActiveTrips);
module.exports = router;
exports.default = router;
